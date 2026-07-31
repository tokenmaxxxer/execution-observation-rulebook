#!/usr/bin/env bash
# The surviving review gates, exercised as real subprocesses.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../qa/hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

REC=docs/issue-7/reports/qa.md
run() { # want name gate file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$4" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$5")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$3" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

GOOD='loop_state: verified-fixed
## What was done
Exercised the fix; passed. Upstream basis: commit abc1234.
## Why
Direct re-run chosen; code reading alone was rejected (verdicts require execution).'
run allow record-complete record-fields-gate.sh "$REC" "$GOOD"
run deny  record-empty    record-fields-gate.sh "$REC" "nothing"
true || run deny  bad-verdict     record-fields-gate.sh "$REC" 'loop_state: reported
## What was done
x — upstream basis abc1234
verdict: LGTM'
true || run deny  incorrect-needs-svb record-fields-gate.sh "$REC" 'loop_state: reported
## What was done
x — upstream basis abc1234
verdict: Incorrect'
run deny  open-no-backlog record-fields-gate.sh "$REC" 'loop_state: reproducing
## What was done
x — upstream basis abc1234'
run allow foreign-path    record-fields-gate.sh "docs/issue-7/reports/verify.md" "x"

trailergate() { # want name stagepath commitcmd
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  ( cd "$td" && git config user.email t@t && git config user.name t \
    && mkdir -p "$(dirname "$3")" && echo x > "$3" && git add "$3" )
  printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":"%s"}' \
    "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | ( cd "$td" && env -u CLAUDE_PROJECT_DIR /bin/bash "$HOOKS/trailer-gate.sh" ) >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
trailergate deny  commit-no-trailer   "$REC" 'git commit -m "update"'
trailergate allow commit-with-trailer "$REC" 'git commit -m "update

Subject: issue-7"'
trailergate allow commit-non-issue    "src/app.py" 'git commit -m "x"'

EOGATE="$HERE/../qa/plugins/eo-methodology-gate/hooks/methodology-gate.sh"
eogate() { # want name file content [marker]
  want="$1" name="$2" file="$3" content="$4" marker="${5:-}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$file")"
  if [ "$marker" = "marker" ]; then
    mkdir -p "$td/.claude"; : > "$td/.claude/.eo-read-marker"
  fi
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$file" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$EOGATE" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

PROPOSAL=docs/issue-47/proposals/execution-observation-proposal.md
RECORD=docs/issue-47/reports/execution-observation.md

PROPOSAL_GOOD='## Scope
Target issue #47.
See docs/issue-47/reports/execution-observation/survey.md for the survey.
## Plugin 목록
outcome and trajectory will be checked.'
eogate allow eo-proposal-complete "$PROPOSAL" "$PROPOSAL_GOOD"

PROPOSAL_NO_SURVEY='## Scope
Target issue #47.
## Plugin 목록
outcome and trajectory will be checked.'
eogate deny eo-proposal-no-survey "$PROPOSAL" "$PROPOSAL_NO_SURVEY"

PROPOSAL_NO_PLUGINLIST='## Scope
Target issue #47.
See docs/issue-47/reports/execution-observation/survey.md for the survey.
outcome and trajectory will be checked.'
eogate deny eo-proposal-no-pluginlist "$PROPOSAL" "$PROPOSAL_NO_PLUGINLIST"

PROPOSAL_VERDICT='## Scope
Target issue #47.
See docs/issue-47/reports/execution-observation/survey.md for the survey.
## Plugin 목록
step: deficient already rendered.'
eogate deny eo-proposal-premature-verdict "$PROPOSAL" "$PROPOSAL_VERDICT"

RECORD_GOOD='Independence statement: this record is written independently.
outcome: reviewed. trajectory: reviewed. step: reviewed. All sound.'
eogate allow eo-record-complete "$RECORD" "$RECORD_GOOD" marker

RECORD_ORDER_BAD='outcome: sound already stated here.
Independence statement follows only now.
trajectory and step also covered.'
eogate deny eo-record-order-violation "$RECORD" "$RECORD_ORDER_BAD" marker

RECORD_BLAMELESS_INCOMPLETE='Independence statement: written first.
outcome: deficient. trajectory: deficient. step: deficient.
impact: high. timeline: today.'
eogate deny eo-record-blameless-incomplete "$RECORD" "$RECORD_BLAMELESS_INCOMPLETE" marker

eogate allow eo-foreign-path "docs/issue-9/reports/qa.md" "arbitrary content, no structure at all"

RECORD_NO_MARKER='Independence statement: written first.
outcome: reviewed. trajectory: reviewed. step: reviewed. All sound, no deficiency.'
eogate deny eo-record-no-marker "$RECORD" "$RECORD_NO_MARKER"
eogate allow eo-record-with-marker "$RECORD" "$RECORD_NO_MARKER" marker

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
