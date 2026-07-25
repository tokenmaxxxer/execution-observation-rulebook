#!/usr/bin/env bash
# PreToolUse hook: the QA cycle gate.
#
# Reads the transition table below (encoded from
# docs/specs/qa-cycle-state-machine.md "Transition table" — that file is the
# source; this table is a copy for runtime speed, not a re-derivation) and
# the project's current phase from state.md. A write that would change
# state.md is allowed only when (current-phase -> attempted-phase) is a row
# in that table, and, for every row the table marks Actor: human, only when
# a matching unconsumed verdict token sits next to state.md.
#
# Fails closed: refusal is the default outcome of this script. Every path
# that is not an affirmative match against the transition table — unreadable
# stdin, a malformed payload, a missing/malformed state file, an unset
# QA_WORKSPACE, a missing or mismatched verdict token — exits 2. Allow
# (exit 0) is reached only via the single explicit success path at the
# bottom of the embedded Python, after the attempted (from -> to) has been
# matched against the table and, for human-actor rows, after a matching
# unconsumed token has been found and consumed.
#
# Kill switch: export QA_CYCLE_DISABLE=1 — this is a deliberate operator
# override (an explicit opt-out someone set on purpose), not an instance of
# the silent-allow bug this file otherwise closes. It intentionally exits 0
# before any of the refuse-by-default logic below runs.
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

def not_applicable():
    # This PreToolUse call is not a write this gate governs at all (wrong
    # tool, or a path outside the workspace's state.md shape). That is not
    # the same thing as a parse failure or an unexpected shape on a write
    # this gate *does* govern — those refuse, below. This is the only
    # function in this script that exits 0 other than the single explicit
    # allow() at the bottom, and it is reached only once we know the event
    # parsed cleanly as the expected top-level shape.
    sys.exit(0)

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

# Every row the spec's table marks Actor: human requires a matching
# unconsumed verdict token — not only entry into Confirmed-Defect, Go,
# No-Go, and Shipped-Under-Exception. Keyed by the exact (from, to) pair,
# not by the target phase alone: `report-filed` is the target of both an
# agent row (Confirmed-Defect -> report-filed) and a human row
# (report-filed -> report-filed, the severity/priority-set self-loop), so a
# target-only set would either wrongly gate the agent row or wrongly skip
# the human one.
ACTOR_OF = {(f, t): a for f, t, a in TABLE}

ALLOWED = set(ACTOR_OF)

try:
    event = json.loads(os.environ.get("QA_CYCLE_PAYLOAD", ""))
except ValueError:
    refuse("qa-cycle: refused — the hook payload on stdin could not be parsed as JSON. Refusing rather than allowing a write this gate cannot inspect.")
if not isinstance(event, dict):
    refuse("qa-cycle: refused — the hook payload did not parse to a JSON object. Refusing rather than allowing a write this gate cannot inspect.")

tool = event.get("tool_name") or ""
tool_input = event.get("tool_input")
if tool not in ("Write", "Edit"):
    # Not a write-shaped tool call at all; this gate has nothing to say
    # about it. Distinct from the malformed-shape refusals above and below.
    not_applicable()
if not isinstance(tool_input, dict):
    refuse("qa-cycle: refused — a %s call arrived with no readable tool_input. Refusing rather than allowing an uninspectable write." % tool)

path = tool_input.get("file_path")
if not isinstance(path, str) or not path:
    refuse("qa-cycle: refused — a %s call arrived with no readable file_path. Refusing rather than allowing an uninspectable write." % tool)

ws = os.environ.get("QA_CYCLE_WORKSPACE", "")
ws_real = posixpath.normpath(os.path.realpath(ws).replace("\\", "/"))
path_norm = path.replace("\\", "/")
path_abs = posixpath.normpath(path_norm if posixpath.isabs(path_norm) else posixpath.join(os.getcwd(), path_norm))
path_real = posixpath.normpath(os.path.realpath(path_abs).replace("\\", "/"))

# Only state.md writes are this gate's business, and only ones inside the
# workspace root — never trust a path by name alone.
if not (path_real == ws_real or path_real.startswith(ws_real + "/")):
    not_applicable()

rel = path_real[len(ws_real) + 1:]
parts = rel.split("/")
if len(parts) != 3 or parts[0] != "projects" or parts[2] != "state.md":
    not_applicable()
slug = parts[1]
project_dir = posixpath.join(ws_real, "projects", slug)
state_path = posixpath.join(project_dir, "state.md")
token_path = posixpath.join(project_dir, ".verdict-token")

# Frontmatter is recognized ONLY as a block opened by a `---` line at the
# very start of the content (position 0, via \A) and closed by a `---` line
# later on. Content whose first line is not `---`, or that never closes the
# block, has no frontmatter at all — a `phase:` line elsewhere in the body
# must never be read as though it were inside one.
FRONTMATTER = re.compile(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|\Z)", re.S)
PHASE = re.compile(r"^phase:\s*(.*?)\s*(?:#.*)?$", re.M)


def read_frontmatter(text):
    m = FRONTMATTER.match(text)
    return m.group(1) if m else None


def read_phase_from_block(block):
    """Return the single phase value declared inside a frontmatter block, or
    None if the block has no `phase:` key, an empty value, or more than one
    `phase:` key — all of which are refusals, never a silently-picked value."""
    matches = PHASE.findall(block)
    if len(matches) != 1:
        return None
    value = matches[0].strip()
    if not value:
        return None
    return value


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
        refuse("qa-cycle: refused — %s has no readable YAML frontmatter (a `---`-delimited block at the very start of the file). The current phase cannot be established, so no write is permitted." % state_path)
    phase = read_phase_from_block(block)
    if phase is None:
        refuse("qa-cycle: refused — %s does not declare exactly one non-empty `phase:` key inside its frontmatter. The current phase cannot be established, so no write is permitted." % state_path)
    return phase


def attempted_phase():
    content = None
    if tool == "Write":
        content = tool_input.get("content")
    else:  # Edit
        content = tool_input.get("new_string")
    if not isinstance(content, str):
        refuse("qa-cycle: refused — could not read the new content of this write, so the attempted phase cannot be determined.")
    block = read_frontmatter(content)
    if block is None:
        refuse("qa-cycle: refused — the write does not declare a phase in valid frontmatter (a `---`-delimited block at the very start of the content). A `phase:` line elsewhere in the body does not count.")
    phase = read_phase_from_block(block)
    if phase is None:
        refuse("qa-cycle: refused — the write does not declare a phase in valid frontmatter: its frontmatter block must contain exactly one non-empty `phase:` key.")
    return phase


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

if ACTOR_OF[(cur, new)] == "human":
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
