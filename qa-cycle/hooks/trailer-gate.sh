#!/usr/bin/env bash
# PreToolUse hook (Bash matching `git commit`): contract §13 trailer
# requirement. When a commit lands qa's own record for an IN-PROGRESS unit
# (a staged docs/reports/records/<subject>/qa.md whose on-disk loop_state is
# non-terminal, or any staged file under that subject's qa/ area) the commit
# message must carry the machine-checkable trailer identifying subject and
# kind. qa's declared trailer keys are `Subject:` and `Kind:`.
#
# It enforces STRUCTURE only: the trailer lines are present. It never
# decides subject/kind values.
#
# Fires only on `git commit`; any other Bash command passes through.
#
# Modeled on the FAIL-CLOSED reference ops-cycle/state-gate.sh: malformed
# payload, an unparseable command, an unreadable staged set or record, or a
# commit message the gate cannot extract while a trailer is required all
# DENY (exit 2), never exit 0 silently.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "qa-cycle: trailer-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
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

if not re.search(r'\bgit\b(?:\s+-{1,2}\S+)*\s+commit\b', command):
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

# --- staged set -------------------------------------------------------
try:
    res = subprocess.run(["git", "-C", root, "diff", "--cached", "--name-only"],
                         capture_output=True, text=True)
except Exception:
    deny("could not read the staged file set (git diff --cached failed); refusing fail-closed")
if res.returncode != 0:
    deny("could not read the staged file set (git diff --cached exited %d); refusing fail-closed"
         % res.returncode)
staged = [ln.strip() for ln in res.stdout.splitlines() if ln.strip()]

# --- is an in-progress qa unit being landed? --------------------------
TERMINAL = {"verified-fixed", "not-a-defect", "wont-fix"}
QA_MD_RE = re.compile(r'^docs/reports/records/([^/]+)/qa\.md$')
QA_SUB_RE = re.compile(r'^docs/reports/records/([^/]+)/qa/.+')

def record_state(rel):
    p = posixpath.join(root, rel)
    try:
        with open(p, encoding="utf-8-sig") as fh:
            text = fh.read(1 << 20)
    except OSError:
        deny("staged qa record %s cannot be read to determine whether the unit is in "
             "progress; refusing fail-closed" % rel)
    m = re.search(r'^\s*(?:loop_state|state)\s*:\s*([^\r\n#]+)', text, re.M | re.I)
    if not m:
        # A qa record with no state field is malformed for §13's purposes;
        # treat as in-progress (fail-closed toward requiring the trailer).
        return None
    return m.group(1).strip().lower()

trailer_required = False
for rel in staged:
    if QA_SUB_RE.match(rel):
        trailer_required = True
        break
    if QA_MD_RE.match(rel):
        st = record_state(rel)
        if st is None or st not in TERMINAL:
            trailer_required = True
            break

if not trailer_required:
    allow()

# --- extract the commit message --------------------------------------
try:
    tokens = shlex.split(command)
except ValueError:
    deny("the git commit command could not be tokenized to read its message; a qa unit is "
         "in progress and §13 requires a Subject:/Kind: trailer that cannot be verified — "
         "refusing fail-closed")

msgs = []
i = 0
n = len(tokens)
found_commit = False
while i < n:
    t = tokens[i]
    if t == "commit":
        found_commit = True
    if t in ("-m", "--message"):
        if i + 1 < n:
            msgs.append(tokens[i + 1])
            i += 2
            continue
    elif t.startswith("--message="):
        msgs.append(t[len("--message="):])
    elif t.startswith("-m") and len(t) > 2:
        msgs.append(t[2:])
    elif t in ("-F", "--file"):
        if i + 1 < n:
            fpath = tokens[i + 1]
            fp = fpath if posixpath.isabs(fpath) else posixpath.join(root, fpath)
            try:
                with open(fp, encoding="utf-8") as fh:
                    msgs.append(fh.read())
            except OSError:
                deny("commit message file %r could not be read; §13 trailer cannot be "
                     "verified for an in-progress qa unit — refusing fail-closed" % fpath)
            i += 2
            continue
    elif t.startswith("--file="):
        fpath = t[len("--file="):]
        fp = fpath if posixpath.isabs(fpath) else posixpath.join(root, fpath)
        try:
            with open(fp, encoding="utf-8") as fh:
                msgs.append(fh.read())
        except OSError:
            deny("commit message file %r could not be read; §13 trailer cannot be verified "
                 "for an in-progress qa unit — refusing fail-closed" % fpath)
    i += 1

if not found_commit:
    # regex matched `git commit` but tokenization disagrees — cannot trust
    # our own parse of a commit that requires a trailer.
    deny("could not locate the commit subcommand while a qa unit is in progress; §13 "
         "trailer cannot be verified — refusing fail-closed")

if not msgs:
    deny("this commit lands an in-progress qa unit but carries no inspectable commit "
         "message (no -m/-F); §13 requires a Subject:/Kind: trailer. Provide the message "
         "inline (-m) so the trailer can be verified.")

message = "\n".join(msgs)
has_subject = re.search(r'(?im)^\s*Subject\s*:\s*\S', message) is not None
has_kind = re.search(r'(?im)^\s*Kind\s*:\s*\S', message) is not None

if not (has_subject and has_kind):
    miss = []
    if not has_subject: miss.append("Subject:")
    if not has_kind: miss.append("Kind:")
    deny("this commit lands an in-progress qa unit but its message is missing the §13 "
         "trailer key(s): %s. qa's declared trailer identifies subject and kind; add a "
         "`Subject: <subject>` and `Kind: qa-record` trailer." % ", ".join(miss))

allow()
PY
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "qa-cycle: refused — fail-closed: internal error (trailer-gate.sh judge exited $rc)." >&2
  exit 2
fi
exit "$rc"
