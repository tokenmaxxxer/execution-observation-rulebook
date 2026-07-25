#!/usr/bin/env bash
# PreToolUse hook: the QA cycle gate.
#
# Reads the transition table below (encoded from
# docs/specs/qa-cycle-state-machine.md "Transition table" — that file is the
# source; this table is a copy for runtime speed, not a re-derivation) and
# the project's current phase from state.md. A write that would change
# state.md is allowed only when (current-phase -> attempted-phase) is a row
# in that table, and, for the four human-only transitions, only when a
# matching unconsumed verdict token sits next to state.md.
#
# Fails closed: unreadable/missing/malformed state or token, or an unset
# QA_WORKSPACE, all refuse (exit 2) rather than allow.
#
# Kill switch: export QA_CYCLE_DISABLE=1
set -euo pipefail

case "${QA_CYCLE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || { echo "qa-cycle: python3 not found; refusing rather than allowing an unchecked write." >&2; exit 2; }

if [ -z "${QA_WORKSPACE:-}" ]; then
  echo "qa-cycle: refused — QA_WORKSPACE is unset. The gate has no state file to read, so it cannot verify this write is a legal transition. Set QA_WORKSPACE to the QA workspace root." >&2
  exit 2
fi

payload="$(cat)"

QA_CYCLE_PAYLOAD="$payload" QA_CYCLE_WORKSPACE="$QA_WORKSPACE" python3 <<'PY'
import json
import os
import posixpath
import re
import sys

def allow():
    sys.exit(0)

def refuse(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)

# --- the transition table, from docs/specs/qa-cycle-state-machine.md -------
# (from, to, actor)  actor in {"agent", "human"}
TABLE = [
    ("(none)", "intake-scoping", "agent"),
    ("intake-scoping", "session-chartered", "agent"),
    ("session-chartered", "session-executed", "agent"),
    ("session-executed", "finding-triage", "agent"),
    ("finding-triage", "finding-triage", "agent"),          # needs-info
    ("finding-triage", "Confirmed-Defect", "human"),
    ("finding-triage", "closed-not-a-defect", "human"),
    ("Confirmed-Defect", "report-filed", "agent"),
    ("report-filed", "report-filed", "human"),               # severity set / priority set
    ("report-filed", "regression-gated", "agent"),
    ("regression-gated", "regression-gated", "agent"),       # adopted or discarded
    ("session-executed", "exit-readiness", "agent"),         # aggregate
    ("exit-readiness", "go-no-go", "agent"),
    ("go-no-go", "Go", "human"),
    ("go-no-go", "No-Go", "human"),
    ("No-Go", "Shipped-Under-Exception", "human"),
]

# Human-only transitions per the frozen contract: entry into these four
# phases is Actor=human AND requires a verdict token regardless of the
# `actor` column above for the *other* human rows (report-filed's
# severity/priority-set self-loop, and closed-not-a-defect) — see the
# ambiguity note in this worker's final report.
TOKEN_REQUIRED_TARGETS = {"Confirmed-Defect", "Go", "No-Go", "Shipped-Under-Exception"}

ALLOWED = {(f, t) for f, t, _ in TABLE}

try:
    event = json.loads(os.environ.get("QA_CYCLE_PAYLOAD", ""))
except ValueError:
    allow()
if not isinstance(event, dict):
    allow()

tool = event.get("tool_name") or ""
tool_input = event.get("tool_input")
if tool not in ("Write", "Edit") or not isinstance(tool_input, dict):
    allow()

path = tool_input.get("file_path")
if not isinstance(path, str) or not path:
    allow()

ws = os.environ.get("QA_CYCLE_WORKSPACE", "")
ws_real = posixpath.normpath(os.path.realpath(ws).replace("\\", "/"))
path_norm = path.replace("\\", "/")
path_abs = posixpath.normpath(path_norm if posixpath.isabs(path_norm) else posixpath.join(os.getcwd(), path_norm))
path_real = posixpath.normpath(os.path.realpath(path_abs).replace("\\", "/"))

# Only state.md writes are this gate's business, and only ones inside the
# workspace root — never trust a path by name alone.
if not (path_real == ws_real or path_real.startswith(ws_real + "/")):
    allow()

rel = path_real[len(ws_real) + 1:]
parts = rel.split("/")
if len(parts) != 3 or parts[0] != "projects" or parts[2] != "state.md":
    allow()
slug = parts[1]
project_dir = posixpath.join(ws_real, "projects", slug)
state_path = posixpath.join(project_dir, "state.md")
token_path = posixpath.join(project_dir, ".verdict-token")

FRONTMATTER = re.compile(r"^---\n(.*?)\n---", re.S)
PHASE = re.compile(r"^phase:\s*(.+?)\s*(?:#.*)?$", re.M)


def read_frontmatter(text):
    m = FRONTMATTER.match(text)
    return m.group(1) if m else None


def current_phase():
    if not os.path.exists(state_path):
        return "(none)"
    try:
        with open(state_path, encoding="utf-8-sig") as fh:
            text = fh.read(65536)
    except (OSError, UnicodeDecodeError):
        refuse("qa-cycle: refused — %s exists but could not be read. Fix or remove it before attempting a transition." % state_path)
    block = read_frontmatter(text)
    if block is None:
        refuse("qa-cycle: refused — %s has no readable YAML frontmatter. The current phase cannot be established, so no write is permitted." % state_path)
    m = PHASE.search(block)
    if not m:
        refuse("qa-cycle: refused — %s has no `phase:` field. The current phase cannot be established, so no write is permitted." % state_path)
    return m.group(1)


def attempted_phase():
    content = None
    if tool == "Write":
        content = tool_input.get("content")
    else:  # Edit
        content = tool_input.get("new_string")
    if not isinstance(content, str):
        refuse("qa-cycle: refused — could not read the new content of this write, so the attempted phase cannot be determined.")
    block = read_frontmatter(content) if content.lstrip().startswith("---") else content
    m = PHASE.search(block if block is not None else content)
    if not m:
        refuse("qa-cycle: refused — the write does not carry a readable `phase:` field. Every write to state.md must state the phase it transitions to.")
    return m.group(1)


cur = current_phase()
new = attempted_phase()

def legal_from(phase):
    return sorted({t for f, t, _ in TABLE if f == phase})


if (cur, new) not in ALLOWED:
    legal = legal_from(cur)
    refuse(
        "qa-cycle: refused — %s -> %s is not a transition docs/specs/qa-cycle-state-machine.md permits.\n"
        "Current phase: %s. Transitions legal from here: %s."
        % (cur, new, cur, ", ".join(legal) if legal else "(none)")
    )

if new in TOKEN_REQUIRED_TARGETS:
    if not os.path.exists(token_path):
        refuse(
            "qa-cycle: refused — %s -> %s is a human-only transition and no verdict token is present at %s.\n"
            "A person must decide this and state the verdict in their own turn (signoff mints the token from that "
            "turn); the evidence needed is exactly what docs/specs/qa-cycle-state-machine.md requires for this "
            "transition." % (cur, new, token_path)
        )
    try:
        with open(token_path, encoding="utf-8-sig") as fh:
            ttext = fh.read(8192)
    except (OSError, UnicodeDecodeError):
        refuse("qa-cycle: refused — %s could not be read. A token that cannot be verified is treated as absent." % token_path)
    tm = re.search(r"^transition:\s*(.+?)\s*(?:#.*)?$", ttext, re.M)
    pm = re.search(r"^project:\s*(.+?)\s*(?:#.*)?$", ttext, re.M)
    if not tm or not pm:
        refuse("qa-cycle: refused — %s is malformed (missing transition or project field). Treated as absent." % token_path)
    want = "%s -> %s" % (cur, new)
    if tm.group(1).strip() != want or pm.group(1).strip() != slug:
        refuse(
            "qa-cycle: refused — the token at %s authorizes a different transition or project, so it does not "
            "cover %s for %s. Treated as absent; a fresh, matching verdict is required." % (token_path, want, slug)
        )
    # Consumed by the same operation that performs the transition: delete it
    # now, before the write this permission decision is gating is allowed
    # through.
    try:
        os.remove(token_path)
    except OSError:
        refuse("qa-cycle: refused — the verdict token at %s could not be consumed. Refusing rather than allowing a write whose token would remain reusable." % token_path)

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "qa-cycle: %s -> %s is a transition the spec permits from the current phase." % (cur, new),
}}))
sys.exit(0)
PY

exit $?
