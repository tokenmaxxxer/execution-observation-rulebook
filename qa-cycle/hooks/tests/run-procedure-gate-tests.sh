#!/usr/bin/env bash
# Executes each of the five §-procedure gates as a real subprocess against
# real fixture files, asserting a crafted VIOLATION is refused (exit 2) and
# a COMPLIANT case passes (exit 0). Separate from run-gate-tests.sh, which
# covers transition-gate.sh.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASS=0
FAIL=0

# Build a throwaway git repo that looks like a real project root.
REPO="$(mktemp -d "${TMPDIR:-/tmp}/qa-proc-gate.XXXXXX")"
trap 'rm -rf "$REPO"' EXIT
git -C "$REPO" init -q
git -C "$REPO" config user.email test@example.com
git -C "$REPO" config user.name test
mkdir -p "$REPO/docs/specs"
echo "# contract" > "$REPO/docs/specs/role-handoff-contract.md"

run_gate() { # run_gate <gate.sh> <payload-json> ; sets RC
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$REPO" "${HOOKS_DIR}/$1" >/dev/null 2>&1
  RC=$?
}

expect() { # expect <label> <want-rc> <got-rc>
  if [ "$2" -eq "$3" ]; then
    echo "PASS: $1 (rc=$3)"; PASS=$((PASS+1))
  else
    echo "FAIL: $1 (want rc=$2 got rc=$3)"; FAIL=$((FAIL+1))
  fi
}

j() { python3 -c 'import json,sys; print(json.dumps(json.loads(sys.stdin.read())))'; }

# ---- record-fields-gate.sh ----
QA_MD="$REPO/docs/reports/records/subj/qa.md"
mkdir -p "$(dirname "$QA_MD")"
BAD_PAYLOAD=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"just a note, nothing else"}}' "$QA_MD" | j)
run_gate record-fields-gate.sh "$BAD_PAYLOAD"
expect "record-fields REFUSES record missing required sections" 2 "$RC"
GOOD_CONTENT='---\nstate: verified-fixed\n---\n## What was done\nRe-ran the suite.\nWhy: chose A over B because faster.\nupstream: commit sha abc123 / record path docs/reports/records/subj/coding.md\n'
GOOD_PAYLOAD=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2].encode().decode("unicode_escape")}}))' "$QA_MD" "$GOOD_CONTENT")
run_gate record-fields-gate.sh "$GOOD_PAYLOAD"
expect "record-fields PASSES compliant terminal-state record" 0 "$RC"

# ---- path-ownership-gate.sh ----
OTHER="$REPO/docs/reports/records/subj/product.md"
BAD=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$OTHER" | j)
run_gate path-ownership-gate.sh "$BAD"
expect "path-ownership REFUSES write into another role's record" 2 "$RC"
OWN=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$QA_MD" | j)
run_gate path-ownership-gate.sh "$OWN"
expect "path-ownership PASSES write into qa's own record" 0 "$RC"

# ---- doc-bucket-gate.sh ----
STRAY="$REPO/docs/random/foo.md"
BAD=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$STRAY" | j)
run_gate doc-bucket-gate.sh "$BAD"
expect "doc-bucket REFUSES doc outside the six buckets" 2 "$RC"
INBUCKET="$REPO/docs/reports/foo.md"
OK=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$INBUCKET" | j)
run_gate doc-bucket-gate.sh "$OK"
expect "doc-bucket PASSES doc inside a bucket" 0 "$RC"

# ---- handbook-trigger-gate.sh ----
echo '{}' > "$REPO/package.json"
git -C "$REPO" add package.json
CMT=$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m msg"}}' | j)
run_gate handbook-trigger-gate.sh "$CMT"
expect "handbook-trigger REFUSES op-surface change with no handbook touched" 2 "$RC"
mkdir -p "$REPO/docs/handbooks"
echo "# hb" > "$REPO/docs/handbooks/pkg.md"
git -C "$REPO" add docs/handbooks/pkg.md
run_gate handbook-trigger-gate.sh "$CMT"
expect "handbook-trigger PASSES op-surface change with handbook touched" 0 "$RC"

# reproduce and close the git -C / git -c commit-detection bypass
git -C "$REPO" reset -q
git -C "$REPO" add package.json
CMT_DASH_C=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"git -C %s commit -m msg" % sys.argv[1]}}))' "$REPO")
run_gate handbook-trigger-gate.sh "$CMT_DASH_C"
expect "handbook-trigger REFUSES 'git -C <dir> commit' op-surface change with no handbook touched" 2 "$RC"
CMT_DASH_c=$(printf '{"tool_name":"Bash","tool_input":{"command":"git -c a=b commit -m msg"}}' | j)
run_gate handbook-trigger-gate.sh "$CMT_DASH_c"
expect "handbook-trigger REFUSES 'git -c a=b commit' op-surface change with no handbook touched" 2 "$RC"
git -C "$REPO" add docs/handbooks/pkg.md
run_gate handbook-trigger-gate.sh "$CMT_DASH_C"
expect "handbook-trigger PASSES 'git -C <dir> commit' op-surface change with handbook touched" 0 "$RC"
STATUS_DASH_C=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"git -C %s status" % sys.argv[1]}}))' "$REPO")
run_gate handbook-trigger-gate.sh "$STATUS_DASH_C"
expect "handbook-trigger ignores non-commit 'git -C <dir> status'" 0 "$RC"
LOG_CMD=$(printf '{"tool_name":"Bash","tool_input":{"command":"git log"}}' | j)
run_gate handbook-trigger-gate.sh "$LOG_CMD"
expect "handbook-trigger ignores non-commit 'git log'" 0 "$RC"

# ---- trailer-gate.sh ----
# reset index, stage an in-progress qa record
git -C "$REPO" reset -q
printf -- '---\nstate: observed\n---\nwork\n' > "$QA_MD"
git -C "$REPO" add docs/reports/records/subj/qa.md
NOTRAILER=$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m \\"land qa record\\""}}' | j)
run_gate trailer-gate.sh "$NOTRAILER"
expect "trailer-gate REFUSES in-progress qa commit lacking Subject:/Kind:" 2 "$RC"
WITHTRAILER=$(python3 -c 'import json; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"git commit -m \"land qa record\n\nSubject: subj\nKind: qa-record\""}}))')
run_gate trailer-gate.sh "$WITHTRAILER"
expect "trailer-gate PASSES in-progress qa commit with Subject:/Kind:" 0 "$RC"

# reproduce and close the git -C / git -c commit-detection bypass
NOTRAILER_DASH_C=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"git -C %s commit -m \"land qa record\"" % sys.argv[1]}}))' "$REPO")
run_gate trailer-gate.sh "$NOTRAILER_DASH_C"
expect "trailer-gate REFUSES 'git -C <dir> commit' lacking Subject:/Kind: (bypass closed)" 2 "$RC"
NOTRAILER_DASH_c=$(printf '{"tool_name":"Bash","tool_input":{"command":"git -c a=b commit -m \\"land qa record\\""}}' | j)
run_gate trailer-gate.sh "$NOTRAILER_DASH_c"
expect "trailer-gate REFUSES 'git -c a=b commit' lacking Subject:/Kind:" 2 "$RC"
WITHTRAILER_DASH_C=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"git -C %s commit -m \"land qa record\n\nSubject: subj\nKind: qa-record\"" % sys.argv[1]}}))' "$REPO")
run_gate trailer-gate.sh "$WITHTRAILER_DASH_C"
expect "trailer-gate PASSES 'git -C <dir> commit' with Subject:/Kind:" 0 "$RC"
STATUS_DASH_C2=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"git -C %s status" % sys.argv[1]}}))' "$REPO")
run_gate trailer-gate.sh "$STATUS_DASH_C2"
expect "trailer-gate ignores non-commit 'git -C <dir> status'" 0 "$RC"
LOG_CMD2=$(printf '{"tool_name":"Bash","tool_input":{"command":"git log"}}' | j)
run_gate trailer-gate.sh "$LOG_CMD2"
expect "trailer-gate ignores non-commit 'git log'" 0 "$RC"

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
