#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): enforces contract
# section 11's static, role-permanent owned-path table for the qa role.
# Generalizes coding's warrant/scope-gate.sh write-set shape to §11's
# static table instead of a per-proposal freeze.
#
# qa owns, under docs/reports/records/<subject>/: qa.md and qa/** only.
# A Write/Edit reaching another role's file under the same subject
# (product.md, coding.md, verify.md, ...) is refused, citing §11.
# Paths outside the records tree (the §21 grants for docs/decisions/,
# docs/reports/, docs/specs/ and the shared-write docs/handbooks/) are not
# role-exclusive and pass through this gate (the doc-bucket gate governs
# those); this gate only refuses writes into ANOTHER role's exclusive
# records file.
#
# Modeled on the FAIL-CLOSED reference ops-cycle/state-gate.sh: every
# malformed/missing-input branch DENIES (exit 2), never exits 0 silently.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "qa-cycle: path-ownership-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat 2>/dev/null || true)"

set +e
QA_PAYLOAD="$payload" QA_CPD="${CLAUDE_PROJECT_DIR:-}" python3 <<'PY'
import json, os, posixpath, re, sys, subprocess

# --- fail-closed on ANY internal error (frozen contract: gates DENY on error) ---
# Any uncaught exception in the judge below (e.g. os.path.realpath on a
# null-byte/undecodable path raising ValueError, which would otherwise exit 1
# = fail-OPEN for a PreToolUse hook) becomes exit 2 (DENY). allow()/deny() raise
# SystemExit, which does NOT pass through this hook, so the exact allow(0)/
# deny(2) verdict paths are preserved unchanged.
def _qa_fail_closed_excepthook(_t, _e, _tb):
    sys.stderr.write("qa-cycle: refused — fail-closed: internal error: %s\n" % (_e,))
    try:
        sys.stderr.flush()
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _qa_fail_closed_excepthook

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

if tool not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    allow()
path = tool_input.get("file_path") or tool_input.get("notebook_path")
if not isinstance(path, str) or not path:
    deny("no usable file_path/notebook_path in tool_input; the gate cannot judge a write it cannot identify")

def plausible_root(p):
    return bool(p) and os.path.isdir(p) and (
        os.path.exists(posixpath.join(p, ".git"))
        or os.path.isfile(posixpath.join(p, "docs/specs/role-handoff-contract.md"))
    )

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
    deny("no project root could be determined; the gate will not judge a write without knowing the repo root")
root = posixpath.normpath(root.replace("\\", "/"))

absu = norm if posixpath.isabs(norm) else posixpath.join(root, norm)
absu = posixpath.normpath(absu)
resolved = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
# A symlink resolving outside the repo is not this gate's business, but the
# intended in-repo target still is — judge by the pre-realpath in-repo path
# too, so a link cannot smuggle a write into another role's record.
for candidate in (resolved, absu):
    if not (candidate == root or candidate.startswith(root + "/")):
        continue
    rel = candidate[len(root):].lstrip("/")
    m = re.match(r'^docs/reports/records/([^/]+)/(.+)$', rel)
    if not m:
        continue
    subject, remainder = m.group(1), m.group(2)
    # qa owns exactly qa.md and anything under qa/ for the subject.
    if remainder == "qa.md" or remainder.startswith("qa/"):
        continue
    # Another role's exclusive file under this subject.
    owner = remainder.split("/", 1)[0]
    owner = owner[:-3] if owner.endswith(".md") else owner
    deny("'%s' is owned by role '%s' per contract §11 (records/<subject>/<role>.md), "
         "not by qa (qa owns only <subject>/qa.md and <subject>/qa/**). Report the "
         "conflict; do not overwrite or merge into another role's record." % (rel, owner))

allow()
PY
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "qa-cycle: refused — fail-closed: internal error (path-ownership-gate.sh judge exited $rc)." >&2
  exit 2
fi
exit "$rc"
