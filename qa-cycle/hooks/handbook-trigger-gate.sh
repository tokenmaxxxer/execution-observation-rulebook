#!/usr/bin/env bash
# --- fail-closed trap (must stay the first executable statement) ---
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Bash matching `git commit`): contract §21 handbook-trigger
# half. When a commit's staged file set introduces or changes an operational
# surface (env-var example, config/dependency manifest, migration, or a
# run/setup/deploy script) but no staged file touches docs/handbooks/*.md,
# the commit is refused — the handbook must be updated in the same unit of
# work (§21 write-time maintenance / same-turn-sync).
#
# It enforces STRUCTURE only: a handbook file was touched alongside the
# surface change. It never derives or writes the handbook itself.
#
# Fires only on `git commit`; any other Bash command passes through. Reads
# the staged set via `git diff --cached --name-only`.
#
# Modeled on the FAIL-CLOSED reference ops-cycle/state-gate.sh: malformed
# payload, an unreadable staged set, or a missing git repo DENIES (exit 2),
# never exits 0 silently.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "qa-cycle: handbook-trigger-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat 2>/dev/null || true)"

set +e
QA_PAYLOAD="$payload" QA_CPD="${CLAUDE_PROJECT_DIR:-}" python3 <<'PY'
import json, os, posixpath, re, shlex, sys, subprocess

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
    deny("the tool-call payload is not valid JSON; the gate cannot judge a commit it cannot parse")
if not isinstance(event, dict):
    deny("the tool-call payload is not a JSON object; the gate cannot judge a commit it cannot parse")

tool = event.get("tool_name")
tool_input = event.get("tool_input")
if tool != "Bash":
    allow()
if not isinstance(tool_input, dict):
    deny("tool_input is missing or not a JSON object; the gate cannot judge a commit it cannot parse")
command = tool_input.get("command")
if not isinstance(command, str) or not command.strip():
    deny("the Bash command is missing or not a string; the gate cannot judge a commit it cannot read")

GIT_GLOBAL_OPTS_WITH_ARG = {
    "-C", "-c", "--git-dir", "--work-tree", "--namespace",
    "--exec-path", "--super-prefix", "--config-env",
}

def is_git_commit_invocation(cmd):
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        # cmd could not be tokenized (e.g. an unterminated quote); do not
        # fail open. Fall back to a conservative heuristic over the raw
        # string: if it looks like it could be a git commit, treat it as
        # one so enforcement still applies.
        matched = re.search(r'(?:^|\s)git\b.*?\bcommit\b', cmd, re.DOTALL) is not None
        print("qa-cycle: warning — commit command could not be tokenized "
              "(shlex parse failure); falling back to a conservative "
              "regex heuristic to detect a possible commit (matched=%s)."
              % matched, file=sys.stderr)
        return matched
    for i, tok in enumerate(tokens):
        if tok != "git":
            continue
        j = i + 1
        while j < len(tokens):
            t = tokens[j]
            if t == "commit":
                return True
            if not t.startswith("-"):
                break
            if "=" in t:
                j += 1
                continue
            base = t
            if base in GIT_GLOBAL_OPTS_WITH_ARG:
                j += 2
                continue
            j += 1
    return False

# Only our business when this is a `git commit`.
if not is_git_commit_invocation(command):
    allow()

def plausible_root(p):
    return bool(p) and os.path.isdir(p) and (
        os.path.exists(posixpath.join(p, ".git"))
        or os.path.isfile(posixpath.join(p, "docs/specs/role-handoff-contract.md"))
    )

def git_toplevel(start):
    try:
        out = subprocess.run(["git", "-C", start, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True)
        if out.returncode == 0:
            return out.stdout.strip()
    except Exception:
        return ""
    return ""

cpd = os.environ.get("QA_CPD", "")
root = ""
if plausible_root(cpd):
    root = posixpath.normpath(os.path.realpath(cpd).replace("\\", "/"))
if not root:
    root = git_toplevel(os.getcwd())
if not root:
    deny("no git project root could be determined for this commit; refusing rather than guessing")
root = posixpath.normpath(root.replace("\\", "/"))

try:
    res = subprocess.run(["git", "-C", root, "diff", "--cached", "--name-only"],
                         capture_output=True, text=True)
except Exception:
    deny("could not read the staged file set (git diff --cached failed); refusing fail-closed")
if res.returncode != 0:
    deny("could not read the staged file set (git diff --cached exited %d); refusing fail-closed"
         % res.returncode)

staged = [ln.strip() for ln in res.stdout.splitlines() if ln.strip()]
if not staged:
    # Nothing staged: no surface change to gate. (An --amend/-a path is out
    # of this gate's structural scope; the trailer gate still applies.)
    allow()

MANIFESTS = {
    "package.json", "pyproject.toml", "requirements.txt", "pipfile",
    "go.mod", "cargo.toml", "pom.xml", "build.gradle", "gemfile",
    "dockerfile", "docker-compose.yml", "docker-compose.yaml",
}
SCRIPT_NAMES = {"setup.sh", "install.sh", "run.sh", "deploy.sh", "entrypoint.sh"}

def is_op_surface(p):
    pl = p.lower()
    base = posixpath.basename(pl)
    if base in MANIFESTS or base in SCRIPT_NAMES:
        return True
    if base.endswith(".env.example") or base == ".env.example" or base.endswith(".env"):
        return True
    if "/migrations/" in pl or pl.startswith("migrations/"):
        return True
    if pl.startswith(".github/workflows/") or "/.github/workflows/" in pl:
        return True
    return False

def is_handbook(p):
    pl = p.replace("\\", "/")
    return pl.startswith("docs/handbooks/") and pl.endswith(".md")

surfaces = [p for p in staged if is_op_surface(p)]
handbooks = [p for p in staged if is_handbook(p)]

if surfaces and not handbooks:
    deny("this commit changes operational surface (%s) but does not touch any "
         "docs/handbooks/<component>.md. Per contract §21, update the component's handbook "
         "in the same unit of work that changes its operational surface (same-turn-sync)."
         % ", ".join(surfaces[:5]))

allow()
PY
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "qa-cycle: refused — fail-closed: internal error (handbook-trigger-gate.sh judge exited $rc)." >&2
  exit 2
fi
exit "$rc"
