#!/usr/bin/env bash
# --- fail-closed trap (must stay the first executable statement) ---
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): refuses writes under
# docs/ that would land outside the six doctrine buckets — contract §21's
# bucket half. Replicates coding's doctrine/placement-gate.sh in shape for
# the qa rulebook (today only coding enforced §21's bucket membership).
#
# Scope is docs/ and nothing else; outside docs/ this gate is silent. Inside
# docs/ every file is governed regardless of extension. Exceptions:
# docs/README.md, a dot-dir/vendored tree that ALREADY exists, and whatever
# DOCTRINE_ALLOW lists.
#
# FAIL-CLOSED (per ops-cycle/state-gate.sh reference): missing python3 or a
# payload this gate cannot parse/understand is refused, never silently let
# through. Only genuinely-determined out-of-scope writes still allow.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "qa-cycle: refused — doc-bucket-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat 2>/dev/null || true)"

set +e
QA_PAYLOAD="$payload" QA_CPD="${CLAUDE_PROJECT_DIR:-}" python3 <<'PY'
import json, os, posixpath, sys

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

BUCKETS = ("decisions", "handbooks", "reports", "specs", "proposals", "_assets")
SKIP_DIRS = (
    "node_modules", "vendor", "dist", "build", "target", "out",
    "venv", ".venv", "site-packages", "coverage",
)

def allow():
    sys.exit(0)

def deny(msg):
    sys.stderr.write("qa-cycle: refused — " + msg + "\n")
    sys.exit(2)

try:
    event = json.loads(os.environ.get("QA_PAYLOAD", "") or "{}")
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

normalized = path.replace("\\", "/")
root = (os.environ.get("QA_CPD") or os.getcwd()).replace("\\", "/")
absolute = posixpath.normpath(normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized))
root = posixpath.normpath(root)

if absolute != root and not absolute.startswith(root + "/"):
    allow()

resolved = posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
real_root = posixpath.normpath(os.path.realpath(root).replace("\\", "/"))
if absolute != resolved:
    if resolved != real_root and not resolved.startswith(real_root + "/"):
        allow()
    absolute, root = resolved, real_root

relative = absolute[len(root) + 1:]
segments = [s for s in relative.split("/") if s not in ("", ".")]
if not segments:
    allow()

directories, name = segments[:-1], segments[-1]
if "docs" not in directories:
    allow()

for extra in (os.environ.get("DOCTRINE_ALLOW") or "").split(","):
    extra = extra.strip().strip("/")
    if extra and (extra in directories or relative == extra or relative.startswith(extra + "/")):
        allow()

if directories[-1] == "docs" and name == "README.md":
    allow()

scaffolding = None
for i, directory in enumerate(directories):
    if directory == "docs" or "docs" not in directories[:i]:
        continue
    if directory in BUCKETS:
        allow()
    if directory in SKIP_DIRS or directory.startswith("."):
        if os.path.isdir(posixpath.join(root, *directories[:i + 1])):
            allow()
        scaffolding = "/".join(directories[:i + 1])
    break

buckets = ", ".join(b + "/" for b in BUCKETS)
if scaffolding:
    reason = (
        "`%s` would create `%s`, a new directory under docs/ that is not one of the six "
        "buckets. Doc-site tooling already on disk is left alone, but new structure under "
        "docs/ is not invented here." % (relative, scaffolding)
    )
else:
    reason = (
        "`%s` is under docs/ but not in one of the six buckets. Every file under docs/ "
        "belongs to a bucket — images and attachments go in _assets/." % relative
    )

sys.stderr.write(
    "qa-cycle: refused — %s\n"
    "The buckets are: %s.\n"
    "Classify by lifetime, not topic: undecided -> proposals/; invalidated by a code change -> specs/; "
    "kept current from now on -> handbooks/; why a hard-to-reverse choice was made -> decisions/; "
    "an observation fixed to a point in time -> reports/ (research under reports/research/).\n"
    "Create the bucket if it does not exist yet, then write there. Only docs/README.md may sit at the "
    "top of docs/; paths in DOCTRINE_ALLOW are exempt.\n"
    % (reason, buckets)
)
sys.exit(2)
PY
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "qa-cycle: refused — fail-closed: internal error (doc-bucket-gate.sh judge exited $rc)." >&2
  exit 2
fi
exit "$rc"
