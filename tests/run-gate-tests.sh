#!/usr/bin/env bash
# The surviving review gates, exercised as real subprocesses.
#
# record-fields-gate.sh and trailer-gate.sh no longer exist under
# qa/hooks/ — they are core canon hooks now (core/hooks/hooks.json fires
# them globally per issue-66/stub-check.sh's drift-recurrence contract).
# The dead cases that used to exercise the local copies of those two
# filenames are removed here rather than fixed (issue #50's audit finding
# is that the *test* referenced a nonexistent *file*, not that the file
# itself is a known-good deletion to fix).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

CORE_ROOT="$("$HERE/fetch-core.sh")" || { echo "run-gate-tests: cannot resolve core canon (gate-lib.sh) — see fetch-core.sh output above" >&2; exit 2; }
export CLAUDE_PLUGIN_ROOT_CORE="$CORE_ROOT"

pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

EOGATE="$HERE/../qa/plugins/eo-methodology-gate/hooks/methodology-gate.sh"

# eogate <want> <name> <file> <content> [marker]
# Write-tool convenience wrapper over eogate_raw, used by every case that
# only needs to exercise the "full document replaces the file" path.
eogate() {
  want="$1" name="$2" file="$3" content="$4" marker="${5:-}"
  payload="$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": sys.argv[1], "content": sys.argv[2]}, "cwd": sys.argv[3]}))
' "$file" "$content" "PLACEHOLDER")"
  eogate_raw "$want" "$name" "$file" "$payload" "$marker" ""
}

# eogate_raw <want> <name> <file> <payload-json-with-cwd-placeholder> [marker] [extra-env]
# <payload-json-with-cwd-placeholder> must contain the literal string
# "PLACEHOLDER" where the tempdir's own path belongs (substituted after the
# tempdir is created, since only this function knows it).
eogate_raw() {
  want="$1" name="$2" file="$3" payload_tmpl="$4" marker="${5:-}" extra_env="${6:-}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  [ -n "$file" ] && mkdir -p "$td/$(dirname "$file")"
  if [ "$marker" = "marker" ]; then
    mkdir -p "$td/.claude"; : > "$td/.claude/.eo-read-marker"
  fi
  payload="${payload_tmpl//PLACEHOLDER/$td}"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" $extra_env /bin/bash "$EOGATE" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

# eogate_edit_file <want> <name> <file> <on-disk-content> <edit-json-with-cwd-placeholder> [marker]
# Seeds $file with <on-disk-content> before invoking the gate with an
# Edit/MultiEdit tool_input built by the caller (must already be full JSON,
# containing the literal "PLACEHOLDER" token for cwd).
eogate_edit_file() {
  want="$1" name="$2" file="$3" on_disk="$4" payload_tmpl="$5" marker="${6:-}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$file")"
  printf '%s' "$on_disk" > "$td/$file"
  if [ "$marker" = "marker" ]; then
    mkdir -p "$td/.claude"; : > "$td/.claude/.eo-read-marker"
  fi
  payload="${payload_tmpl//PLACEHOLDER/$td}"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$EOGATE" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

PROPOSAL=docs/issue-47/proposals/execution-observation-proposal.md
RECORD=docs/issue-47/reports/execution-observation.md

PROPOSAL_GOOD='## Scope
Target issue #47.
See docs/issue-47/reports/execution-observation/survey.md for the survey.
## Verdict-level plan
outcome: reviewed will be checked.
trajectory: reviewed will be checked.
## Plugin 목록
- eo-directive
- eo-methodology-gate'
eogate allow eo-proposal-complete "$PROPOSAL" "$PROPOSAL_GOOD"

PROPOSAL_NO_SURVEY='## Scope
Target issue #47.
## Verdict-level plan
outcome: reviewed. trajectory: reviewed.
## Plugin 목록
- eo-directive'
eogate deny eo-proposal-no-survey "$PROPOSAL" "$PROPOSAL_NO_SURVEY"

PROPOSAL_NO_PLUGINLIST='## Scope
Target issue #47.
See docs/issue-47/reports/execution-observation/survey.md for the survey.
## Verdict-level plan
outcome: reviewed. trajectory: reviewed.
## Plugin 목록
no list here, just prose about outcome and trajectory.'
eogate deny eo-proposal-no-pluginlist "$PROPOSAL" "$PROPOSAL_NO_PLUGINLIST"

PROPOSAL_VERDICT='## Scope
Target issue #47.
See docs/issue-47/reports/execution-observation/survey.md for the survey.
## Verdict-level plan
outcome: reviewed. trajectory: reviewed.
## Plugin 목록
- eo-directive
step: deficient already rendered.'
eogate deny eo-proposal-premature-verdict "$PROPOSAL" "$PROPOSAL_VERDICT"

# Structural-vs-mention semantic case (mandatory case 6): a document that
# only mentions the plan words in prose, with no plan-shaped section and no
# adjacency marker, must now deny where the old bare-substring check would
# have allowed it (>=2 of outcome/trajectory/step appearing anywhere).
PROPOSAL_MENTION_ONLY='## Scope
Target issue #47.
See docs/issue-47/reports/execution-observation/survey.md for the survey.
## Plugin 목록
- eo-directive
The outcome of the prior trajectory was fine, no plan section at all.'
eogate deny eo-proposal-mention-only-no-structure "$PROPOSAL" "$PROPOSAL_MENTION_ONLY"

RECORD_GOOD='Independence statement: this record is written independently.
outcome: reviewed. trajectory: reviewed. step: reviewed. All sound.'
eogate allow eo-record-complete "$RECORD" "$RECORD_GOOD" marker

RECORD_ORDER_BAD='outcome: sound already stated here.
Independence statement follows only now.
trajectory: reviewed. step: reviewed.'
eogate deny eo-record-order-violation "$RECORD" "$RECORD_ORDER_BAD" marker

RECORD_BLAMELESS_INCOMPLETE='Independence statement: written first.
outcome: deficient. trajectory: deficient. step: deficient.
impact: high. timeline: today.'
eogate deny eo-record-blameless-incomplete "$RECORD" "$RECORD_BLAMELESS_INCOMPLETE" marker

RECORD_BLAMELESS_COMPLETE='Independence statement: written first.
outcome: deficient. trajectory: deficient. step: deficient.

### impact
high, affected 3 plugins.
### timeline
found today, fixed today.
### root cause
kill-switch default bug.
### action item
migrate to gate-lib.'
eogate allow eo-record-blameless-complete "$RECORD" "$RECORD_BLAMELESS_COMPLETE" marker

eogate allow eo-foreign-path "docs/issue-9/reports/qa.md" "arbitrary content, no structure at all"

RECORD_NO_MARKER='Independence statement: written first.
outcome: reviewed. trajectory: reviewed. step: reviewed. All sound, no deficiency.'
eogate deny eo-record-no-marker "$RECORD" "$RECORD_NO_MARKER"
eogate allow eo-record-with-marker "$RECORD" "$RECORD_NO_MARKER" marker

# A bare mention of "sound" in ordinary prose, with no verdict-marker shape
# at all, must not satisfy the record's verdict-level-presence check (the
# old bare-substring "sound" check false-positived on any sentence
# containing that word).
RECORD_BARE_SOUND_PROSE='Independence statement: written first.
This design sounds reasonable, but no outcome/trajectory/step markers appear.'
eogate deny eo-record-bare-sound-prose "$RECORD" "$RECORD_BARE_SOUND_PROSE" marker

# --- mandatory case 1: Edit with replace_all against a multiply-occurring
# old_string — a proposal with the premature-verdict phrase "step:
# deficient" occurring TWICE. replace_all:true must clear both occurrences
# (allow); replace_all:false clears only the first, leaving the second to
# still trip the prohibition (deny) — the old always-first-occurrence
# behavior would have wrongly allowed this.
PROPOSAL_DOUBLE_BAD_PHRASE='## Scope
Target issue #47.
See docs/issue-47/reports/execution-observation/survey.md for the survey.
## Verdict-level plan
outcome: reviewed. trajectory: reviewed.
## Plugin 목록
- eo-directive
step: deficient noted once.
step: deficient noted twice.'
EDIT_REPLACE_ALL_TRUE="$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1], "old_string": "step: deficient", "new_string": "step: reviewed", "replace_all": True}, "cwd": "PLACEHOLDER"}))
' "$PROPOSAL")"
eogate_edit_file allow eo-edit-replace-all-true "$PROPOSAL" "$PROPOSAL_DOUBLE_BAD_PHRASE" "$EDIT_REPLACE_ALL_TRUE"

EDIT_REPLACE_ALL_FALSE="$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1], "old_string": "step: deficient", "new_string": "step: reviewed", "replace_all": False}, "cwd": "PLACEHOLDER"}))
' "$PROPOSAL")"
eogate_edit_file deny eo-edit-replace-all-false-second-occurrence-still-bad "$PROPOSAL" "$PROPOSAL_DOUBLE_BAD_PHRASE" "$EDIT_REPLACE_ALL_FALSE"

# --- mandatory case 2: MultiEdit with mixed replace_all true/false in one
# call, per-edit independence ------------------------------------------------
RECORD_MULTI_BASE='Independence statement: written first.
outcome: OLD. trajectory: OLD. step: PENDING.'
MULTIEDIT_MIXED="$(python3 -c '
import json, sys
edits = [
    {"old_string": "OLD", "new_string": "reviewed", "replace_all": True},
    {"old_string": "PENDING", "new_string": "reviewed", "replace_all": False},
]
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": sys.argv[1], "edits": edits}, "cwd": "PLACEHOLDER"}))
' "$RECORD")"
eogate_edit_file allow eo-multiedit-mixed-replace-all "$RECORD" "$RECORD_MULTI_BASE" "$MULTIEDIT_MIXED" marker

# --- mandatory case 3: malformed JSON (truncated, non-object, empty) must
# deny (fail-closed), never silently pass through ---------------------------
eogate_raw deny eo-malformed-json-truncated "$RECORD" '{"tool_name":"Write","tool_inp' "" ""
eogate_raw deny eo-malformed-json-non-object "$RECORD" '"just a string"' "" ""
eogate_raw deny eo-malformed-json-empty "$RECORD" '' "" ""

# --- mandatory case 4: kill switch set to an unrecognized value (a typo)
# must leave the gate ACTIVE (the confirmed default-open bug this migration
# reverses) -------------------------------------------------------------------
eogate_raw deny eo-kill-switch-typo-stays-active "$RECORD" \
  "$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":""},"cwd":"PLACEHOLDER"}))' "$RECORD")" \
  "" "EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF=totally-off-i-swear"
eogate_raw allow eo-kill-switch-recognized-on-value-disables "$RECORD" \
  "$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":""},"cwd":"PLACEHOLDER"}))' "$RECORD")" \
  "" "EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF=true"

# --- mandatory case 5: absolute file_path (and a ./-prefixed variant) must
# resolve to the same verdict as the equivalent relative-path fixture -------
ABS_PAYLOAD_TMPL="$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": "PLACEHOLDER/" + sys.argv[1], "content": sys.argv[2]}, "cwd": "PLACEHOLDER"}))
' "$RECORD" "$RECORD_NO_MARKER")"
eogate_raw deny eo-absolute-path-same-verdict-as-relative "$RECORD" "$ABS_PAYLOAD_TMPL" ""

DOTSLASH_PAYLOAD_TMPL="$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": "./" + sys.argv[1], "content": sys.argv[2]}, "cwd": "PLACEHOLDER"}))
' "$RECORD" "$RECORD_NO_MARKER")"
eogate_raw deny eo-dotslash-path-same-verdict-as-relative "$RECORD" "$DOTSLASH_PAYLOAD_TMPL" ""

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
