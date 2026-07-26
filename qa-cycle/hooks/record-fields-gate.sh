#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): enforces contract
# section 20's per-role record minimum content on writes reaching qa's own
# record file docs/reports/records/<subject>/qa.md.
#
# Peer to transition-gate.sh (never an edit to it): transition-gate.sh
# validates the state transition; this gate validates that the resulting
# record carries the section-20 minimum content. It reads the SAME proposed
# content transition-gate.sh reads (Write.content, Edit old/new applied to
# the on-disk file) — no new content-read mechanism.
#
# Required at every point the record is read (section 20):
#   - what was done       (a "what was done" marker/section)
#   - the concrete basis  (an upstream commit sha or record path marker)
#   - the record's own current loop_state / state field
# Additionally, whenever the record is left in a NON-terminal state (work
# open), section 20 items 4-5 require:
#   - a next-steps backlog        (a "next steps" marker/section)
#   - an open-finding resolution  (a "resolution" marker/section)
#
# Modeled on the FAIL-CLOSED reference ops-cycle/state-gate.sh: every
# malformed/missing-input branch DENIES (exit 2), never exits 0 silently.
# Kill switch is deliberately absent (a gate that can be silently switched
# off is not a gate).
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "qa-cycle: record-fields-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat 2>/dev/null || true)"

QA_PAYLOAD="$payload" QA_CPD="${CLAUDE_PROJECT_DIR:-}" python3 <<'PY'
import json, os, posixpath, re, sys, subprocess

def deny(msg):
    sys.stderr.write("qa-cycle: refused — " + msg + "\n")
    sys.exit(2)

def allow():
    sys.exit(0)

raw = os.environ.get("QA_PAYLOAD", "")
try:
    event = json.loads(raw) if raw else {}
except ValueError:
    deny("the tool-call payload is not valid JSON; the gate cannot judge a write it cannot parse")
if not isinstance(event, dict):
    deny("the tool-call payload is not a JSON object; the gate cannot judge a write it cannot parse")

tool = event.get("tool_name")
tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse")

def plausible_root(p):
    return bool(p) and os.path.isdir(p) and (
        os.path.exists(posixpath.join(p, ".git"))
        or os.path.isfile(posixpath.join(p, "docs/specs/role-handoff-contract.md"))
    )

if tool not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    allow()
path = tool_input.get("file_path") or tool_input.get("notebook_path")
if not isinstance(path, str) or not path:
    deny("no usable file_path/notebook_path in tool_input; the gate cannot judge a write it cannot identify")

def git_toplevel(start):
    try:
        d = start if os.path.isdir(start) else os.path.dirname(start) or "."
        out = subprocess.run(["git", "-C", d, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True)
        if out.returncode == 0:
            return out.stdout.strip()
    except Exception:
        return ""
    return ""

norm = path.replace("\\", "/")
cpd = os.environ.get("QA_CPD", "")
root = ""
if plausible_root(cpd):
    root = posixpath.normpath(os.path.realpath(cpd).replace("\\", "/"))
    absu = norm if posixpath.isabs(norm) else posixpath.join(root, norm)
    absu = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
    if not (absu == root or absu.startswith(root + "/")):
        root = ""
if not root:
    root = git_toplevel(norm if posixpath.isabs(norm) else os.getcwd())
if not root:
    root = git_toplevel(os.getcwd())
if not root:
    deny("no project root could be determined; the gate will not judge a record write without knowing the repo root")
root = posixpath.normpath(root.replace("\\", "/"))

absu = norm if posixpath.isabs(norm) else posixpath.join(root, norm)
absu = posixpath.normpath(absu)
resolved = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
if not (resolved == root or resolved.startswith(root + "/")):
    allow()
rel = resolved[len(root):].lstrip("/")

if not re.match(r'^docs/reports/records/[^/]+/qa\.md$', rel):
    allow()

def read_current():
    try:
        with open(resolved, encoding="utf-8-sig") as fh:
            return fh.read(1 << 20)
    except OSError:
        return None

new_text = None
if tool == "Write":
    c = tool_input.get("content")
    if isinstance(c, str):
        new_text = c
elif tool == "Edit":
    o, n = tool_input.get("old_string"), tool_input.get("new_string")
    cur = read_current()
    if isinstance(o, str) and isinstance(n, str) and cur is not None and o in cur:
        new_text = cur.replace(o, n, 1)
elif tool == "MultiEdit":
    edits = tool_input.get("edits")
    cur = read_current()
    if isinstance(edits, list) and cur is not None:
        ok = True
        for e in edits:
            if not isinstance(e, dict):
                ok = False; break
            o, n = e.get("old_string"), e.get("new_string")
            if not isinstance(o, str) or not isinstance(n, str) or o not in cur:
                ok = False; break
            cur = cur.replace(o, n, 1)
        if ok:
            new_text = cur

if new_text is None:
    deny("this write targets qa's record (%s) but the gate cannot reconstruct the "
         "resulting content from the tool input given (tool=%r); write the full record "
         "content explicitly so section-20 fields can be checked." % (rel, tool))

low = new_text.lower()

m_state = re.search(r'^\s*(?:loop_state|state)\s*:\s*([^\r\n#]+)', new_text, re.M | re.I)
state_val = m_state.group(1).strip().lower() if m_state else None

missing = []
if state_val is None:
    missing.append("current loop_state/state field")
if not re.search(r'what\s+was\s+done', low):
    missing.append("a 'what was done' section")
if not (re.search(r'\bupstream\b', low) or re.search(r'\bbasis\b', low)
        or re.search(r'\bcommit\s+sha\b', low) or re.search(r'\brecord\s+path\b', low)):
    missing.append("the concrete basis (upstream commit sha or record path)")

TERMINAL = {"verified-fixed", "not-a-defect", "wont-fix"}
open_work = state_val is not None and state_val not in TERMINAL
if open_work:
    if not re.search(r'next[\s\-_]?steps', low):
        missing.append("a next-steps backlog (record left in non-terminal state)")
    if not re.search(r'resolution', low):
        missing.append("an open-finding resolution path (record left in non-terminal state)")

if missing:
    deny("qa record %s is missing required section(s): %s. Per contract section 20 every "
         "role record must state what was done and the concrete upstream basis, carry its "
         "own current loop_state, and — while work is open — a next-steps backlog and an "
         "open-finding resolution path." % (rel, ", ".join(missing)))

allow()
PY
