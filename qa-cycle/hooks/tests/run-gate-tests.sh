#!/usr/bin/env bash
# Executes qa-cycle/hooks/transition-gate.sh as a real subprocess against
# real fixture files, one case at a time, and asserts on the observed exit
# code (and, where the gate emits a refusal message, that the message is
# non-empty). See qa-cycle/hooks/tests/README.md to run this.
#
# Fixtures live under this repo's own
# docs/reports/records/<subject>/qa/state.md tree — the gate has no external
# workspace concept anymore (docs/proposals/2026-07-27-qa-records-in-target-repo.md).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="${SCRIPT_DIR}/../transition-gate.sh"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# The gate now resolves its protection root from CLAUDE_PROJECT_DIR first
# (contract: docs/proposals/2026-07-26-gate-root-from-project-dir.md),
# falling back to the git top-level of cwd only when unset. Every existing
# case below predates that fallback distinction and was written assuming
# "cwd's git top-level" always resolves to this repo; exporting
# CLAUDE_PROJECT_DIR here keeps that true regardless of where this test
# script itself is invoked from, without changing any case's intent.
# Individual cases below that specifically exercise CLAUDE_PROJECT_DIR
# override or unset it via extra_env / GATE_ENV_CLEAR as needed.
export CLAUDE_PROJECT_DIR="$REPO_ROOT"

# `env` inherits the caller's environment, so a case that means "disabled"
# must actually remove QA_CYCLE_DISABLE — omitting it from env_args only
# leaves whatever the developer's shell exports. Cleared here and re-added
# per case, so a case's environment is what it declares. The gate no longer
# reads any workspace env var at all — every fixture path below lives under
# REPO_ROOT/docs/reports/records/<subject>/qa/.
GATE_ENV_CLEAR=(-u QA_CYCLE_DISABLE)

# bash 3.2 (macOS's /bin/bash) treats "${arr[@]}" on an *empty* array as a
# reference to an unbound variable under `set -u`, so every expansion of a
# possibly-empty array below uses the ${arr[@]+"${arr[@]}"} form: it expands
# to no words at all when the array is empty and to every element when it is
# not, on both 3.2 and 5.x. "${arr[@]:-}" is not a substitute — it expands to
# one empty argument, which `env` then tries to run as a command.
PASS_COUNT=0
FAIL_COUNT=0
RESULTS=()
LIVE_WORKSPACES=()

cleanup_all() {
  local ws
  for ws in "${LIVE_WORKSPACES[@]:-}"; do
    if [ -n "$ws" ] && [ -d "$ws" ]; then
      rm -rf "$ws"
    fi
  done
  # Belt-and-braces on top of LIVE_WORKSPACES: every subject new_workspace()
  # mints is named gate-test-*, and LIVE_WORKSPACES is populated from inside
  # a function invoked via command substitution (`ws="$(new_workspace)"`),
  # which runs in a subshell — appends made there never reach this
  # function's copy of the array. Sweep by the fixed naming convention too,
  # so a subject dir never survives this script writing it into this repo's
  # own docs/reports/records/ tree.
  rm -rf "${REPO_ROOT}"/docs/reports/records/gate-test-* 2>/dev/null || true
  return 0
}
trap cleanup_all EXIT

# --- fixture helpers --------------------------------------------------------

new_workspace() {
  # Mints a fresh, unique subject under this repo's own
  # docs/reports/records/ tree and returns docs/reports/records/<subject>/qa
  # — the gate now resolves everything against the repo root
  # (CLAUDE_PROJECT_DIR, exported once above), never an external workspace.
  local subject qa_dir
  subject="gate-test-$(date +%s)-$$-${RANDOM}-${#LIVE_WORKSPACES[@]}"
  qa_dir="${REPO_ROOT}/docs/reports/records/${subject}/qa"
  mkdir -p "$qa_dir"
  LIVE_WORKSPACES+=("${REPO_ROOT}/docs/reports/records/${subject}")
  echo "$qa_dir"
}

item_block() {
  # item_block <item-id> <state>
  local id="$1" state="$2"
  printf -- '---\nitem: %s\nstate: %s\nreproduction:\nevidence:\n---\n' "$id" "$state"
}

item_block_with_severity() {
  # item_block_with_severity <item-id> <state> <severity-lines-raw>
  # <severity-lines-raw> is inserted verbatim (may be zero, one, or two
  # `severity:` lines) so callers can construct the malformed-shape cases.
  local id="$1" state="$2" severity_lines="$3"
  printf -- '---\nitem: %s\nstate: %s\nreproduction: steps\nevidence:\n%s---\n' "$id" "$state" "$severity_lines"
}

item_block_with_priority() {
  # item_block_with_priority <item-id> <state> <priority-value-or-empty>
  local id="$1" state="$2" priority="$3"
  if [ -n "$priority" ]; then
    printf -- '---\nitem: %s\nstate: %s\nreproduction:\nevidence:\npriority: %s\n---\n' "$id" "$state" "$priority"
  else
    item_block "$id" "$state"
  fi
}

write_target() {
  # write_target <ws> <slug-unused> <label> <entry_point> [env_names]
  # slug is accepted for call-site compatibility but unused: ws IS the
  # subject's qa/ directory now, not a workspace root nested under
  # projects/<slug>/.
  local ws="$1" label="$3" entry_point="$4" env_names="${5:-}"
  local dir="${ws}"
  mkdir -p "$dir"
  {
    printf -- '---\n'
    printf 'label: %s\n' "$label"
    printf 'entry_point: %s\n' "$entry_point"
    printf 'env_names: %s\n' "$env_names"
    printf -- '---\n'
  } > "${dir}/target.md"
}

item_block_with_evidence() {
  # item_block_with_evidence <item-id> <state> <evidence-text>
  # Like item_block, but the evidence field carries the given text — used
  # to reference a declared target's label/entry_point in the write's own
  # run-record evidence.
  local id="$1" state="$2" evidence="$3"
  printf -- '---\nitem: %s\nstate: %s\nreproduction:\nevidence: %s\n---\n' "$id" "$state" "$evidence"
}

write_priority_token() {
  # write_priority_token <ws> <slug-unused> <item-id> <value> <phrase>
  local ws="$1" item="$3" value="$4" phrase="$5"
  local dir="${ws}/tokens"
  mkdir -p "$dir"
  {
    printf 'item: %s\n' "$item"
    printf 'field: priority\n'
    printf 'value: %s\n' "$value"
    printf 'phrase: %s\n' "$phrase"
  } > "${dir}/${item}.priority.token"
}

write_state() {
  # write_state <ws> <slug-unused> <content>
  local ws="$1" content="$3"
  local dir="${ws}"
  mkdir -p "$dir"
  printf '%s' "$content" > "${dir}/state.md"
}

write_token() {
  # write_token <ws> <slug-unused> <item-id> <transition> <phrase>
  local ws="$1" item="$3" transition="$4" phrase="$5"
  local dir="${ws}/tokens"
  mkdir -p "$dir"
  {
    printf 'item: %s\n' "$item"
    printf 'transition: %s\n' "$transition"
    printf 'phrase: %s\n' "$phrase"
  } > "${dir}/${item}.token"
}

write_consuming() {
  # write_consuming <ws> <slug-unused> <item-id> <transition> <phrase>
  local ws="$1" item="$3" transition="$4" phrase="$5"
  local dir="${ws}/tokens"
  mkdir -p "$dir"
  {
    printf 'item: %s\n' "$item"
    printf 'transition: %s\n' "$transition"
    printf 'phrase: %s\n' "$phrase"
  } > "${dir}/${item}.consuming"
}

payload_write() {
  # payload_write <abs-file-path> <content>
  # Emits a JSON payload shaped like the PreToolUse event the gate reads.
  local path="$1" content="$2"
  python3 - "$path" "$content" <<'PY'
import json, sys
path, content = sys.argv[1], sys.argv[2]
print(json.dumps({
    "tool_name": "Write",
    "tool_input": {"file_path": path, "content": content},
}))
PY
}

payload_bash() {
  # payload_bash <command>
  # Emits a JSON payload shaped like a PreToolUse Bash event.
  local command="$1"
  python3 - "$command" <<'PY'
import json, sys
command = sys.argv[1]
print(json.dumps({
    "tool_name": "Bash",
    "tool_input": {"command": command},
}))
PY
}

# --- test runner -------------------------------------------------------------

run_case() {
  # run_case <name> <expected_exit> <ws-or-empty> <payload-or-empty> [extra_env...]
  local name="$1" expected="$2" ws="$3" payload="$4"
  shift 4
  local extra_env=("$@")

  local out err rc
  local env_args=()
  env_args+=("${extra_env[@]+"${extra_env[@]}"}")

  set +e
  err="$(printf '%s' "$payload" | env "${GATE_ENV_CLEAR[@]}" ${env_args[@]+"${env_args[@]}"} "$GATE" 2>&1 1>/tmp/gate-test-stdout.$$)"
  rc=$?
  set -e
  rm -f "/tmp/gate-test-stdout.$$"

  local status="ok"
  if [ "$rc" -ne "$expected" ]; then
    status="FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    PASS_COUNT=$((PASS_COUNT + 1))
  fi

  # Where refusal is expected (non-zero), the gate must emit a non-empty
  # message on stderr. Never assert on the message's text — only presence.
  local msg_note=""
  if [ "$expected" -ne 0 ]; then
    if [ -z "$err" ]; then
      status="FAIL"
      msg_note=" (refusal message was empty)"
    fi
  fi

  RESULTS+=("${name}|${expected}|${rc}|${status}${msg_note}")
  echo "case: ${name} | expected: ${expected} | observed: ${rc} | ${status}${msg_note}"
}

run_case_in_repo_root() {
  # run_case_in_repo_root <name> <expected_exit> <ws-or-empty> <payload-or-empty> [extra_env...]
  # Like run_case, but invokes the gate with cwd set to REPO_ROOT so its
  # internal `git rev-parse --show-toplevel` (and the records-tree root
  # derived from it) resolves against this repo, regardless of where this
  # test script itself was launched from. Needed for the Bash write-target
  # cases below, which reference docs/reports/records/ under REPO_ROOT.
  local name="$1" expected="$2" ws="$3" payload="$4"
  shift 4
  local extra_env=("$@")

  local err rc
  local env_args=()
  env_args+=("${extra_env[@]+"${extra_env[@]}"}")

  set +e
  err="$(cd "$REPO_ROOT" && printf '%s' "$payload" | env "${GATE_ENV_CLEAR[@]}" ${env_args[@]+"${env_args[@]}"} "$GATE" 2>&1 1>/tmp/gate-test-stdout.$$)"
  rc=$?
  set -e
  rm -f "/tmp/gate-test-stdout.$$"

  local status="ok"
  if [ "$rc" -ne "$expected" ]; then
    status="FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    PASS_COUNT=$((PASS_COUNT + 1))
  fi

  local msg_note=""
  if [ "$expected" -ne 0 ]; then
    if [ -z "$err" ]; then
      status="FAIL"
      msg_note=" (refusal message was empty)"
    fi
  fi

  RESULTS+=("${name}|${expected}|${rc}|${status}${msg_note}")
  echo "case: ${name} | expected: ${expected} | observed: ${rc} | ${status}${msg_note}"
}

run_case_argv() {
  # run_case_argv <name> <expected_exit> <ws-or-empty> <payload-or-empty> -- <gate-arg...>
  # Like run_case, but invokes the gate with explicit argv instead of none.
  # Used for the --dump-facts argument-handling and stdin-detection cases,
  # which need to control both argv and stdin independently.
  local name="$1" expected="$2" ws="$3" payload="$4"
  shift 4
  if [ "${1:-}" = "--" ]; then shift; fi
  local gate_args=("$@")

  local out err rc
  local env_args=()

  set +e
  err="$(printf '%s' "$payload" | env "${GATE_ENV_CLEAR[@]}" ${env_args[@]+"${env_args[@]}"} "$GATE" ${gate_args[@]+"${gate_args[@]}"} 2>&1 1>/tmp/gate-test-stdout.$$)"
  rc=$?
  set -e
  rm -f "/tmp/gate-test-stdout.$$"

  local status="ok" msg_note=""
  if [ "$rc" -ne "$expected" ]; then
    status="FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    PASS_COUNT=$((PASS_COUNT + 1))
  fi

  if [ "$expected" -ne 0 ]; then
    if [ -z "$err" ]; then
      status="FAIL"
      msg_note=" (refusal message was empty)"
    fi
  fi

  RESULTS+=("${name}|${expected}|${rc}|${status}${msg_note}")
  echo "case: ${name} | expected: ${expected} | observed: ${rc} | ${status}${msg_note}"
}

expect_file() {
  # expect_file <name> <path> <exists|absent>
  local name="$1" path="$2" want="$3"
  local have="absent"
  [ -e "$path" ] && have="exists"
  if [ "$have" = "$want" ]; then
    echo "case: ${name} | expected: ${want} | observed: ${have} | ok"
    RESULTS+=("${name}|${want}|${have}|ok")
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "case: ${name} | expected: ${want} | observed: ${have} | FAIL"
    RESULTS+=("${name}|${want}|${have}|FAIL")
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

cleanup_ws() {
  local ws="$1"
  [ -n "$ws" ] && [ -d "$ws" ] && rm -rf "$ws"
}

# =========================================================================
# Case 1: valid table-permitted transition (agent actor) -> expect allow
# =========================================================================
ws1="$(new_workspace)"
slug="owner-repo"
write_state "$ws1" "$slug" "$(item_block BUG-1 observed)"
write_target "$ws1" "$slug" "staging" "http://localhost:3000"
payload="$(payload_write "${ws1}/state.md" "$(item_block_with_evidence BUG-1 reproducing "ran against staging")")"
run_case "valid-table-permitted-transition" 0 "$ws1" "$payload"
cleanup_ws "$ws1"

# =========================================================================
# Case 2: transition not permitted from current state -> expect refuse
# =========================================================================
ws2="$(new_workspace)"
slug="owner-repo"
write_state "$ws2" "$slug" "$(item_block BUG-1 observed)"
payload="$(payload_write "${ws2}/state.md" "$(item_block BUG-1 verified-fixed)")"
run_case "transition-not-permitted-from-current-state" 2 "$ws2" "$payload"
cleanup_ws "$ws2"

# =========================================================================
# Case 3: human-actor transition with no token -> expect refuse
# =========================================================================
ws3="$(new_workspace)"
slug="owner-repo"
write_state "$ws3" "$slug" "$(item_block BUG-1 reproduced)"
payload="$(payload_write "${ws3}/state.md" "$(item_block BUG-1 handed-off)")"
run_case "human-actor-transition-no-token" 2 "$ws3" "$payload"
cleanup_ws "$ws3"

# =========================================================================
# Case 4: human-actor transition with a matching unconsumed token
#         -> expect allow AND the live token file is gone, replaced by a
#            consuming marker (the reserve-not-delete mechanism)
# =========================================================================
ws4="$(new_workspace)"
slug="owner-repo"
write_state "$ws4" "$slug" "$(item_block BUG-1 reproduced)"
write_token "$ws4" "$slug" "BUG-1" "reproduced -> handed-off" "yes, this is a genuine defect, hand it off"
payload="$(payload_write "${ws4}/state.md" "$(item_block BUG-1 handed-off)")"
run_case "human-actor-transition-matching-token" 0 "$ws4" "$payload"
expect_file "human-actor-live-token-gone" "${ws4}/tokens/BUG-1.token" "absent"
expect_file "human-actor-consuming-marker-present" "${ws4}/tokens/BUG-1.consuming" "exists"

# =========================================================================
# Case 5: the same token replayed against the SAME still-unadvanced state
#         -> expect allow again (this is the consumption-timing fix: the
#            marker from case 4 still authorizes a retry of the identical
#            transition because state.md was never actually advanced here)
# =========================================================================
payload="$(payload_write "${ws4}/state.md" "$(item_block BUG-1 handed-off)")"
run_case "consuming-marker-authorizes-retry-of-same-transition" 0 "$ws4" "$payload"
cleanup_ws "$ws4"

# =========================================================================
# Case 6: non-JSON stdin -> expect refuse
# =========================================================================
ws6="$(new_workspace)"
slug="owner-repo"
write_state "$ws6" "$slug" "$(item_block BUG-1 observed)"
run_case "non-json-stdin" 2 "$ws6" "this is not json at all {{{"
cleanup_ws "$ws6"

# =========================================================================
# Case 7: state file absent -> expect refuse
#         (absent state.md resolves the item to state "(none)"; attempting
#          a transition not legal from "(none)" surfaces the refusal)
# =========================================================================
ws7="$(new_workspace)"
slug="owner-repo"
mkdir -p "${ws7}/projects/${slug}"
payload="$(payload_write "${ws7}/state.md" "$(item_block BUG-1 reproduced)")"
run_case "state-file-absent" 2 "$ws7" "$payload"
cleanup_ws "$ws7"

# =========================================================================
# Case 8: state file with no frontmatter block -> expect refuse
# =========================================================================
ws8="$(new_workspace)"
slug="owner-repo"
write_state "$ws8" "$slug" $'item: BUG-1\nstate: observed\nno frontmatter delimiters here\n'
payload="$(payload_write "${ws8}/state.md" "$(item_block BUG-1 reproducing)")"
run_case "state-file-no-frontmatter" 2 "$ws8" "$payload"
cleanup_ws "$ws8"

# =========================================================================
# Case 9: a write with no readable item/state block -> expect refuse
# =========================================================================
ws9="$(new_workspace)"
slug="owner-repo"
write_state "$ws9" "$slug" "$(item_block BUG-1 observed)"
payload="$(payload_write "${ws9}/state.md" $'item: BUG-1\nstate: reproducing\nno frontmatter here either\n')"
run_case "no-item-block-in-write-body" 2 "$ws9" "$payload"
cleanup_ws "$ws9"

# =========================================================================
# Case 10: a state.md-shaped write entirely outside
# docs/reports/records/<subject>/qa/ -> expect allow (not_applicable: there
# is no external workspace concept anymore, so a write outside the owned
# record tree is simply not this gate's business).
# =========================================================================
payload="$(payload_write "/tmp/nonexistent-subject/state.md" "$(item_block BUG-1 reproducing)")"
run_case "state-md-outside-records-tree-not-applicable" 0 "" "$payload"

# =========================================================================
# Case 11: QA_CYCLE_DISABLE=1 -> expect allow (deliberate operator override)
# =========================================================================
ws11="$(new_workspace)"
slug="owner-repo"
write_state "$ws11" "$slug" "$(item_block BUG-1 observed)"
payload="$(payload_write "${ws11}/state.md" "$(item_block BUG-1 verified-fixed)")"
run_case "qa-cycle-disable-override" 0 "$ws11" "$payload" "QA_CYCLE_DISABLE=1"
cleanup_ws "$ws11"

# =========================================================================
# Case 12: a token minted for one ITEM is rejected against a different item
#          attempting the identical (from, to) pair
# =========================================================================
ws12="$(new_workspace)"
slug="owner-repo"
write_state "$ws12" "$slug" "$(item_block BUG-1 reproduced)$(item_block BUG-2 reproduced)"
write_token "$ws12" "$slug" "BUG-1" "reproduced -> handed-off" "confirmed defect, hand it off"
payload="$(payload_write "${ws12}/state.md" "$(item_block BUG-1 reproduced)$(item_block BUG-2 handed-off)")"
run_case "token-for-one-item-rejected-for-another" 2 "$ws12" "$payload"
cleanup_ws "$ws12"

# =========================================================================
# Case 13: a token minted for one TRANSITION on an item is rejected
#          against a different transition on that same item
# =========================================================================
ws13="$(new_workspace)"
slug="owner-repo"
write_state "$ws13" "$slug" "$(item_block BUG-1 reproduced)"
write_token "$ws13" "$slug" "BUG-1" "reproduced -> not-a-defect" "not a defect"
payload="$(payload_write "${ws13}/state.md" "$(item_block BUG-1 handed-off)")"
run_case "token-for-one-transition-rejected-for-another" 2 "$ws13" "$payload"
cleanup_ws "$ws13"

# =========================================================================
# Case 14: handed-off refuses a transition attempt with no human trigger
# =========================================================================
ws14="$(new_workspace)"
slug="owner-repo"
write_state "$ws14" "$slug" "$(item_block BUG-1 handed-off)"
payload="$(payload_write "${ws14}/state.md" "$(item_block BUG-1 re-verifying)")"
run_case "handed-off-refuses-without-human-token" 2 "$ws14" "$payload"
cleanup_ws "$ws14"

# =========================================================================
# Case 15: consumption-timing — a hook-permitted write that does not land
#          must not strand the transition (the core defect this unit
#          fixes, per docs/reports/2026-07-29-hunt-gate-execution-check.md)
#
# Sequence:
#   a. Item BUG-1 is `reproduced`; a matching token exists.
#   b. Gate call #1 allows reproduced -> handed-off. state.md is NOT
#      actually advanced afterward (simulating the permitted write failing
#      or being aborted downstream of the PreToolUse decision).
#   c. Gate call #2 retries the identical transition against the still-
#      unadvanced state.md -> must still allow (case 5 above already
#      covers the mechanism; this case additionally proves the item really
#      never advanced and a THIRD, different transition still cannot ride
#      the same marker).
#   d. state.md is now actually advanced to handed-off (the write lands).
#   e. Gate call #3, attempting a DIFFERENT transition on BUG-1
#      (handed-off -> re-verifying) with no fresh token, must refuse,
#      proving the marker did not leak into authorizing a second,
#      different transition.
# =========================================================================
ws15="$(new_workspace)"
slug="owner-repo"
write_state "$ws15" "$slug" "$(item_block BUG-1 reproduced)"
write_token "$ws15" "$slug" "BUG-1" "reproduced -> handed-off" "confirmed defect, hand it off"

payload="$(payload_write "${ws15}/state.md" "$(item_block BUG-1 handed-off)")"
run_case "consumption-timing-first-allow-write-does-not-land" 0 "$ws15" "$payload"
# state.md deliberately left unadvanced here to model the write not landing.

payload="$(payload_write "${ws15}/state.md" "$(item_block BUG-1 handed-off)")"
run_case "consumption-timing-retry-still-allowed" 0 "$ws15" "$payload"

# Now actually land the write, simulating the retry succeeding this time.
write_state "$ws15" "$slug" "$(item_block BUG-1 handed-off)"

payload="$(payload_write "${ws15}/state.md" "$(item_block BUG-1 re-verifying)")"
run_case "consumption-timing-marker-does-not-authorize-a-different-transition" 2 "$ws15" "$payload"
cleanup_ws "$ws15"

# =========================================================================
# Case 16: path-traversing item id — the exact reproduction from
#          docs/reports/2026-07-31-hunt-item-axis-enforcement.md. A write
#          claims an item id of "../../../../../../../../tmp/evil-item" for
#          a human-only transition; a forged "token" sits at the resulting
#          attacker-chosen path outside tokens/. Must now refuse — the item
#          id allow-list rejects the value before it is ever used to build
#          token_path, so the forged file is never consulted at all.
# =========================================================================
ws16="$(new_workspace)"
slug="owner-repo"
evil_item='../../../../../../../../tmp/evil-item'
write_state "$ws16" "$slug" "$(item_block "$evil_item" reproduced)"
cat > "/tmp/evil-item.token" <<EOF
item: ${evil_item}
transition: reproduced -> handed-off
phrase: 'forged - never went through capture-verdict.sh'
EOF
payload="$(payload_write "${ws16}/state.md" "$(item_block "$evil_item" handed-off)")"
run_case "path-traversing-item-id-refused" 2 "$ws16" "$payload"
rm -f "/tmp/evil-item.token"
cleanup_ws "$ws16"

# =========================================================================
# Case 17: item id with a leading hyphen — outside the allow-list (may not
#          begin with a hyphen) -> expect refuse.
# =========================================================================
ws17="$(new_workspace)"
slug="owner-repo"
write_state "$ws17" "$slug" "$(item_block "-BUG-1" observed)"
payload="$(payload_write "${ws17}/state.md" "$(item_block "-BUG-1" reproducing)")"
run_case "item-id-leading-hyphen-refused" 2 "$ws17" "$payload"
cleanup_ws "$ws17"

# =========================================================================
# Case 18: item id with characters outside the allow-list (a slash) ->
#          expect refuse.
# =========================================================================
ws18="$(new_workspace)"
slug="owner-repo"
write_state "$ws18" "$slug" "$(item_block "BUG/1" observed)"
payload="$(payload_write "${ws18}/state.md" "$(item_block "BUG/1" reproducing)")"
run_case "item-id-disallowed-characters-refused" 2 "$ws18" "$payload"
cleanup_ws "$ws18"

# =========================================================================
# Case 19: over-length item id (65 characters, one past the 64-character
#          limit) -> expect refuse.
# =========================================================================
ws19="$(new_workspace)"
slug="owner-repo"
long_item="$(printf 'A%.0s' $(seq 1 65))"
write_state "$ws19" "$slug" "$(item_block "$long_item" observed)"
payload="$(payload_write "${ws19}/state.md" "$(item_block "$long_item" reproducing)")"
run_case "item-id-over-length-refused" 2 "$ws19" "$payload"
cleanup_ws "$ws19"

# =========================================================================
# Case 20: subject read straight from a Write's own file_path, no separate
# "project identifier" allow-list step exists anymore now that state.md
# lives directly under docs/reports/records/<subject>/qa/state.md — the
# subject segment is whatever path component is there, already
# realpath-resolved and containment-checked against docs/reports/records/
# before use. A legal transition under an unusual-but-real subject name is
# still allowed -> expect allow (companion negative case in case 38 below
# proves the same subject cannot escape the records tree).
# =========================================================================
subject20="gate-test-unusual-subject-name"
qa_dir20="${REPO_ROOT}/docs/reports/records/${subject20}/qa"
mkdir -p "$qa_dir20"
LIVE_WORKSPACES+=("${REPO_ROOT}/docs/reports/records/${subject20}")
write_state "$qa_dir20" "unused" "$(item_block BUG-1 observed)"
write_target "$qa_dir20" "unused" "staging" "http://localhost:3000"
payload="$(payload_write "${qa_dir20}/state.md" "$(item_block_with_evidence BUG-1 reproducing "ran against staging")")"
run_case "unusual-subject-name-legal-transition-allowed" 0 "$qa_dir20" "$payload"
cleanup_ws "$qa_dir20"

# =========================================================================
# Case 21: item missing `severity` attempting reproducing -> reproduced
#          -> expect refuse (the precondition from docs/specs/
#          qa-cycle-state-machine.md "Severity and priority").
# =========================================================================
ws21="$(new_workspace)"
slug="owner-repo"
write_state "$ws21" "$slug" "$(item_block BUG-1 reproducing)"
payload="$(payload_write "${ws21}/state.md" "$(item_block_with_severity BUG-1 reproduced "")")"
run_case "reproduced-missing-severity-refused" 2 "$ws21" "$payload"
cleanup_ws "$ws21"

# =========================================================================
# Case 22: `severity` outside the closed set -> expect refuse
# =========================================================================
ws22="$(new_workspace)"
slug="owner-repo"
write_state "$ws22" "$slug" "$(item_block BUG-1 reproducing)"
payload="$(payload_write "${ws22}/state.md" "$(item_block_with_severity BUG-1 reproduced $'severity: catastrophic\n')")"
run_case "reproduced-severity-outside-closed-set-refused" 2 "$ws22" "$payload"
cleanup_ws "$ws22"

# =========================================================================
# Case 23: two `severity` lines in one record -> expect refuse (zero or
#          multiple both mean "no severity", which refuses the precondition)
# =========================================================================
ws23="$(new_workspace)"
slug="owner-repo"
write_state "$ws23" "$slug" "$(item_block BUG-1 reproducing)"
payload="$(payload_write "${ws23}/state.md" "$(item_block_with_severity BUG-1 reproduced $'severity: major\nseverity: minor\n')")"
run_case "reproduced-two-severity-lines-refused" 2 "$ws23" "$payload"
cleanup_ws "$ws23"

# =========================================================================
# Case 24: valid severity present -> reproducing -> reproduced allowed
# =========================================================================
ws24="$(new_workspace)"
slug="owner-repo"
write_state "$ws24" "$slug" "$(item_block BUG-1 reproducing)"
payload="$(payload_write "${ws24}/state.md" "$(item_block_with_severity BUG-1 reproduced $'severity: major\n')")"
run_case "reproduced-valid-severity-allowed" 0 "$ws24" "$payload"
cleanup_ws "$ws24"

# =========================================================================
# Case 25: `priority` change with no token -> expect refuse
# =========================================================================
ws25="$(new_workspace)"
slug="owner-repo"
write_state "$ws25" "$slug" "$(item_block BUG-1 reproduced)"
payload="$(payload_write "${ws25}/state.md" "$(item_block_with_priority BUG-1 reproduced now)")"
run_case "priority-change-no-token-refused" 2 "$ws25" "$payload"
cleanup_ws "$ws25"

# =========================================================================
# Case 26: a priority token minted for a different item -> expect refuse
# =========================================================================
ws26="$(new_workspace)"
slug="owner-repo"
write_state "$ws26" "$slug" "$(item_block BUG-1 reproduced)$(item_block BUG-2 reproduced)"
write_priority_token "$ws26" "$slug" "BUG-2" "now" "item BUG-2 priority now"
payload="$(payload_write "${ws26}/state.md" "$(item_block_with_priority BUG-1 reproduced now)$(item_block BUG-2 reproduced)")"
run_case "priority-token-for-different-item-refused" 2 "$ws26" "$payload"
cleanup_ws "$ws26"

# =========================================================================
# Case 27: a priority token minted for the same item but a different value
#          -> expect refuse
# =========================================================================
ws27="$(new_workspace)"
slug="owner-repo"
write_state "$ws27" "$slug" "$(item_block BUG-1 reproduced)"
write_priority_token "$ws27" "$slug" "BUG-1" "later" "item BUG-1 priority later"
payload="$(payload_write "${ws27}/state.md" "$(item_block_with_priority BUG-1 reproduced now)")"
run_case "priority-token-for-different-value-refused" 2 "$ws27" "$payload"
cleanup_ws "$ws27"

# =========================================================================
# Case 28: a forged `priority-set-by: human` marker with no token -> expect
#          refuse. This is the hunt's exact reproduction
#          (docs/reports/2026-08-02-hunt-severity-priority-axes.md): an
#          agent writes both the changed `priority:` value and a
#          self-authored `priority-set-by: human` line in the same Write
#          call, with no token anywhere. The marker must now play no part
#          in the decision — it must fail closed.
# =========================================================================
ws28="$(new_workspace)"
slug="owner-repo"
write_state "$ws28" "$slug" "$(item_block BUG-1 reproduced)"
forged_content="$(printf -- '---\nitem: BUG-1\nstate: reproduced\nreproduction:\nevidence:\npriority: now\npriority-set-by: human\n---\n')"
payload="$(payload_write "${ws28}/state.md" "$forged_content")"
run_case "forged-priority-set-by-marker-no-token-refused" 2 "$ws28" "$payload"
cleanup_ws "$ws28"

# =========================================================================
# Case 29: a valid priority token, consumed once, then replayed -> the
#          first attempt allows and reserves (consuming marker), the write
#          actually lands, and a second identical attempt with the token
#          already spent must refuse (single-use).
# =========================================================================
ws29="$(new_workspace)"
slug="owner-repo"
write_state "$ws29" "$slug" "$(item_block BUG-1 reproduced)"
write_priority_token "$ws29" "$slug" "BUG-1" "now" "item BUG-1 priority now"
payload="$(payload_write "${ws29}/state.md" "$(item_block_with_priority BUG-1 reproduced now)")"
run_case "priority-token-first-use-allowed" 0 "$ws29" "$payload"
expect_file "priority-live-token-gone" "${ws29}/tokens/BUG-1.priority.token" "absent"
expect_file "priority-consuming-marker-present" "${ws29}/tokens/BUG-1.priority.consuming" "exists"

# Land the write for real (advance state.md), then finalize + attempt a
# second, different priority change with no fresh token -> must refuse.
write_state "$ws29" "$slug" "$(item_block_with_priority BUG-1 reproduced now)"
payload="$(payload_write "${ws29}/state.md" "$(item_block_with_priority BUG-1 reproduced next)")"
run_case "priority-token-replay-for-new-value-refused" 2 "$ws29" "$payload"
cleanup_ws "$ws29"

# =========================================================================
# Case 30: a valid priority change whose underlying write fails must remain
#          completable without a fresh human token (reserve-then-finalize,
#          same discipline as the state-transition token).
# =========================================================================
ws30="$(new_workspace)"
slug="owner-repo"
write_state "$ws30" "$slug" "$(item_block BUG-1 reproduced)"
write_priority_token "$ws30" "$slug" "BUG-1" "now" "item BUG-1 priority now"
payload="$(payload_write "${ws30}/state.md" "$(item_block_with_priority BUG-1 reproduced now)")"
run_case "priority-consumption-timing-first-allow-write-does-not-land" 0 "$ws30" "$payload"
# state.md deliberately left unadvanced, modeling the permitted write failing.
payload="$(payload_write "${ws30}/state.md" "$(item_block_with_priority BUG-1 reproduced now)")"
run_case "priority-consumption-timing-retry-still-allowed" 0 "$ws30" "$payload"
cleanup_ws "$ws30"

# =========================================================================
# Case 31: --dump-facts with a token-gated human-only transition payload on
#          stdin (the hunt's exact reproduction: handed-off -> re-verifying,
#          no token present) -> expect refuse, not the JSON dump/allow.
# =========================================================================
ws31="$(new_workspace)"
slug="owner-repo"
write_state "$ws31" "$slug" "$(item_block BUG-1 handed-off)"
payload="$(payload_write "${ws31}/state.md" "$(item_block BUG-1 re-verifying)")"
run_case_argv "dump-facts-with-stdin-payload-refuses-hunt-repro" 2 "$ws31" "$payload" -- --dump-facts
cleanup_ws "$ws31"

# =========================================================================
# Case 32: --dump-facts with a second argument -> expect refuse
# =========================================================================
run_case_argv "dump-facts-with-extra-argument-refuses" 2 "" "" -- --dump-facts extra-arg

# =========================================================================
# Case 33: an unrecognized flag alone -> expect refuse
# =========================================================================
run_case_argv "unrecognized-flag-alone-refuses" 2 "" "" -- --bogus-flag

# =========================================================================
# Case 34: --dump-facts as a standalone call with no stdin payload
#          -> expect allow and still emits the facts (no argv, no ws needed)
# =========================================================================
run_case_argv "dump-facts-standalone-no-stdin-allows" 0 "" "" -- --dump-facts

# =========================================================================
# Case 35: observed -> reproducing with no target.md declared at all
#          -> expect refuse (docs/proposals/2026-08-05-target-declaration.md).
# =========================================================================
ws35="$(new_workspace)"
slug="owner-repo"
write_state "$ws35" "$slug" "$(item_block BUG-1 observed)"
payload="$(payload_write "${ws35}/state.md" "$(item_block_with_evidence BUG-1 reproducing "ran against staging")")"
run_case "target-absent-refused" 2 "$ws35" "$payload"
cleanup_ws "$ws35"

# =========================================================================
# Case 36: observed -> reproducing with target.md present but empty
#          (no frontmatter block at all) -> expect refuse.
# =========================================================================
ws36="$(new_workspace)"
slug="owner-repo"
write_state "$ws36" "$slug" "$(item_block BUG-1 observed)"
mkdir -p "${ws36}/projects/${slug}"
: > "${ws36}/target.md"
payload="$(payload_write "${ws36}/state.md" "$(item_block_with_evidence BUG-1 reproducing "ran against staging")")"
run_case "target-empty-refused" 2 "$ws36" "$payload"
cleanup_ws "$ws36"

# =========================================================================
# Case 37: observed -> reproducing with target.md present but malformed
#          (missing the required entry_point field) -> expect refuse.
# =========================================================================
ws37="$(new_workspace)"
slug="owner-repo"
write_state "$ws37" "$slug" "$(item_block BUG-1 observed)"
mkdir -p "${ws37}/projects/${slug}"
{
  printf -- '---\n'
  printf 'label: staging\n'
  printf 'env_names: API_KEY\n'
  printf -- '---\n'
} > "${ws37}/target.md"
payload="$(payload_write "${ws37}/state.md" "$(item_block_with_evidence BUG-1 reproducing "ran against staging")")"
run_case "target-missing-required-field-refused" 2 "$ws37" "$payload"
cleanup_ws "$ws37"

# =========================================================================
# Case 38: a `..`-traversing subject segment in the write's own file_path —
# os.path.realpath collapses it before the subject is ever extracted, so
# the resolved path lands outside docs/reports/records/ entirely -> expect
# allow (not_applicable: this is not a path this gate governs at all, the
# same "escapes the owned tree" outcome the old workspace-containment check
# produced for an escaping project id).
# =========================================================================
escaping_path38="${REPO_ROOT}/docs/reports/records/../../etc/passwd-style-escape/qa/state.md"
payload="$(payload_write "$escaping_path38" "$(item_block_with_evidence BUG-1 reproducing "ran against staging")")"
run_case "traversing-subject-segment-escapes-records-tree-not-applicable" 0 "" "$payload"

# =========================================================================
# Case 39: a valid target declaration, referenced by the write's own
#          run-record evidence -> expect allow.
# =========================================================================
ws39="$(new_workspace)"
slug="owner-repo"
write_state "$ws39" "$slug" "$(item_block BUG-1 observed)"
write_target "$ws39" "$slug" "staging" "http://localhost:3000" "API_KEY"
payload="$(payload_write "${ws39}/state.md" "$(item_block_with_evidence BUG-1 reproducing "reproduced against http://localhost:3000")")"
run_case "target-valid-declaration-allowed" 0 "$ws39" "$payload"
cleanup_ws "$ws39"

# =========================================================================
# Case 40: re-verifying -> reproducing with no target.md declared at all
#          -> expect refuse. The `target` precondition attaches to the
#          `reproducing` DESTINATION state, so every row landing an item in
#          `reproducing` carries it — not just observed -> reproducing.
#          Exact reproduction from
#          docs/reports/2026-08-05-hunt-target-declaration.md.
# =========================================================================
ws40="$(new_workspace)"
slug="owner-repo"
write_state "$ws40" "$slug" "$(item_block BUG-1 re-verifying)"
payload="$(payload_write "${ws40}/state.md" "$(item_block_with_evidence BUG-1 reproducing "ran against staging")")"
run_case "target-absent-refused-re-verifying-to-reproducing" 2 "$ws40" "$payload"
cleanup_ws "$ws40"

# =========================================================================
# Case 41: re-verifying -> reproducing WITH a valid target declaration,
#          referenced by the write's own run-record evidence -> expect
#          allow. Companion to case 40: the same row must still be legally
#          traversable once the precondition is satisfied.
# =========================================================================
ws41="$(new_workspace)"
slug="owner-repo"
write_state "$ws41" "$slug" "$(item_block BUG-1 re-verifying)"
write_target "$ws41" "$slug" "staging" "http://localhost:3000" "API_KEY"
payload="$(payload_write "${ws41}/state.md" "$(item_block_with_evidence BUG-1 reproducing "reproduced against http://localhost:3000")")"
run_case "target-valid-declaration-allowed-re-verifying-to-reproducing" 0 "$ws41" "$payload"
cleanup_ws "$ws41"

# =========================================================================
# Case 42: target.md contains a SECOND `---` block, but only once padding
#          pushes it past the gate's 64KB read cap -> expect refuse. Exact
#          reproduction of the before-landing hunt finding in
#          docs/reports/2026-08-05-hunt-target-declaration.md: a truncated
#          read must never turn a genuinely ambiguous (two-block) file into
#          an apparently well-formed one. Before the fix this observed
#          allow (exit 0); it must now refuse.
# =========================================================================
ws42="$(new_workspace)"
slug="owner-repo"
write_state "$ws42" "$slug" "$(item_block BUG-1 observed)"
mkdir -p "${ws42}/projects/${slug}"
python3 - "${ws42}/target.md" <<'PY'
import sys
path = sys.argv[1]
pad = "x" * 70000
content = ("---\nlabel: staging\nentry_point: http://localhost:3000\n---\n"
           + pad + "\n---\nlabel: decoy\nentry_point: decoy\n---\n")
with open(path, "w") as fh:
    fh.write(content)
PY
payload="$(payload_write "${ws42}/state.md" "$(item_block_with_evidence BUG-1 reproducing "reproduced against http://localhost:3000")")"
run_case "target-second-block-past-cap-refused" 2 "$ws42" "$payload"
cleanup_ws "$ws42"

# =========================================================================
# Case 43: target.md is otherwise well-formed (single block, valid label
#          and entry_point) but the file itself exceeds the gate's 64KB
#          read cap (e.g. a huge trailing comment/padding inside the same
#          block) -> expect refuse. An oversized declaration is an
#          unadjudicable input regardless of whether padding happens to
#          fall inside or outside the one block the gate can see.
# =========================================================================
ws43="$(new_workspace)"
slug="owner-repo"
write_state "$ws43" "$slug" "$(item_block BUG-1 observed)"
mkdir -p "${ws43}/projects/${slug}"
python3 - "${ws43}/target.md" <<'PY'
import sys
path = sys.argv[1]
pad = "x" * 70000
content = "---\nlabel: staging\nentry_point: http://localhost:3000\nenv_names: %s\n---\n" % pad
with open(path, "w") as fh:
    fh.write(content)
PY
payload="$(payload_write "${ws43}/state.md" "$(item_block_with_evidence BUG-1 reproducing "reproduced against http://localhost:3000")")"
run_case "target-oversized-otherwise-valid-refused" 2 "$ws43" "$payload"
cleanup_ws "$ws43"

# =========================================================================
# Case 44: a normal, well within the cap, valid target declaration must
#          still be allowed -> the cap+1 probe read must not disturb the
#          ordinary allow path. Companion to case 39, added alongside the
#          cap-boundary cases so the boundary fix is proven not to regress
#          the common case in the same block of the file.
# =========================================================================
ws44="$(new_workspace)"
slug="owner-repo"
write_state "$ws44" "$slug" "$(item_block BUG-1 observed)"
write_target "$ws44" "$slug" "staging" "http://localhost:3000" "API_KEY"
payload="$(payload_write "${ws44}/state.md" "$(item_block_with_evidence BUG-1 reproducing "reproduced against http://localhost:3000")")"
run_case "target-normal-valid-declaration-still-allowed" 0 "$ws44" "$payload"
cleanup_ws "$ws44"

# =========================================================================
# Case 45: write-target resolution is by TARGET PATH, not tool name
#          (docs/proposals/2026-07-26-fix-state-gate-writeop-bypass.md).
#          A Bash call that writes another role's owned record path via
#          `python3 -c "open(...).write(...)"` must refuse exactly as a
#          Write/Edit call targeting the same path would — the old
#          `if tool not in ("Write", "Edit"): skip` shape let this through.
# =========================================================================
other_role_record="${REPO_ROOT}/docs/reports/records/some-subject/coding.md"
payload="$(payload_bash "python3 -c \"open('${other_role_record}', 'w').write('x')\"")"
run_case_in_repo_root "bash-write-other-role-record-refused" 2 "" "$payload"

# =========================================================================
# Case 46: a legal state transition written to the agent's own owned
#          record path (via the tool the content-shape checks understand)
#          -> expect allow. Companion positive case proving the fix does
#          not turn every write to an owned path into a refusal.
# =========================================================================
own_record="${REPO_ROOT}/docs/reports/records/some-subject-46/qa.md"
own_record_content=$'kind: qa-record\n'
payload="$(payload_write "$own_record" "$own_record_content")"
run_case_in_repo_root "bash-fix-companion-own-record-legal-write-allowed" 0 "" "$payload"

# =========================================================================
# Case 47: a Bash write whose exact target path cannot be confidently
#          extracted, but the command text targets the owned record tree
#          (docs/reports/records/) -> expect refuse (default-deny on an
#          indeterminate Bash write target within the owned record tree,
#          per the contract).
# =========================================================================
payload="$(payload_bash "some_var=\"${REPO_ROOT}/docs/reports/records/some-subject/qa.md\"; python3 - <<PYEOF
import os
target = os.environ.get('SOME_VAR_NOT_SET_HERE') or \"\$some_var\"
open(target, 'w').write('x')
PYEOF")"
run_case_in_repo_root "bash-indeterminate-target-in-records-tree-refused" 2 "" "$payload"

# =========================================================================
# Cases 48-54: path-reference default-deny (contract: docs/proposals/
# 2026-07-26-gate-nested-shell-default-deny.md). A Bash command referencing
# a path inside the owned record tree (docs/reports/records/<subject>/),
# self or foreign, is default-denied unless provably read-only. Each write
# idiom below targets a FOREIGN role's record slot -> expect refuse. A
# plain self-redirection to qa's own record with a legal (bootstrap) write
# is still allowed. All wrapped in sh -c/bash -c/eval or command
# substitution are refused regardless of idiom.
# =========================================================================
foreign_record="${REPO_ROOT}/docs/reports/records/other-subject/coding.md"

payload="$(payload_bash "python3 -c \"open('${foreign_record}', 'w').write('x')\"")"
run_case_in_repo_root "path-ref-deny-foreign-open-write" 2 "" "$payload"

payload="$(payload_bash "python3 -c \"import pathlib; pathlib.Path('${foreign_record}').write_text('x')\"")"
run_case_in_repo_root "path-ref-deny-foreign-write-text" 2 "" "$payload"

payload="$(payload_bash "python3 -c \"import pathlib; pathlib.Path('${foreign_record}').write_bytes(b'x')\"")"
run_case_in_repo_root "path-ref-deny-foreign-write-bytes" 2 "" "$payload"

payload="$(payload_bash "python3 -c \"import os; os.write(open('${foreign_record}','w').fileno(), b'x')\"")"
run_case_in_repo_root "path-ref-deny-foreign-os-write" 2 "" "$payload"

payload="$(payload_bash "sh -c \"cat ${foreign_record}\"")"
run_case_in_repo_root "path-ref-deny-foreign-sh-c-wrap" 2 "" "$payload"

payload="$(payload_bash "bash -c \"cat ${foreign_record}\"")"
run_case_in_repo_root "path-ref-deny-foreign-bash-c-wrap" 2 "" "$payload"

payload="$(payload_bash "eval \"cat ${foreign_record}\"")"
run_case_in_repo_root "path-ref-deny-foreign-eval-wrap" 2 "" "$payload"

payload="$(payload_bash "echo \"\$(cat ${foreign_record})\"")"
run_case_in_repo_root "path-ref-deny-foreign-command-substitution-wrap" 2 "" "$payload"

# Plain read of a foreign record (no write idiom, no nesting, no command
# substitution, read-only command) -> not this gate's business -> allow.
payload="$(payload_bash "cat ${foreign_record}")"
run_case_in_repo_root "path-ref-allow-foreign-plain-read" 0 "" "$payload"

# Own record, plain redirection, legal bootstrap write -> still allowed.
own_bash_record="${REPO_ROOT}/docs/reports/records/own-subject-bash/qa.md"
payload="$(payload_bash "printf -- 'kind: qa-record\n' > ${own_bash_record}")"
run_case_in_repo_root "path-ref-allow-own-record-plain-redirect-legal-write" 0 "" "$payload"

# =========================================================================
# Case 58a: a write to any other file under qa's own owned record area —
# intake.md, plan.md, runs/**, evidence, tokens/**, target.md — that is NOT
# state.md is unconditionally allowed once ownership is confirmed. Per the
# proposal (docs/proposals/2026-07-27-qa-records-in-target-repo.md): all QA
# records (intake, plan, runs, evidence, regression, stats) live under
# docs/reports/records/<subject>/qa/** in the target repo now, and only
# state.md gets the item-level transition machine — everything else in
# qa/** is qa's own record, allow()d directly.
# =========================================================================
own_intake_record="${REPO_ROOT}/docs/reports/records/own-subject-intake/qa/intake.md"
payload="$(payload_write "$own_intake_record" $'---\nissues:\n  repo: acme/api\n---\n')"
run_case "qa-owned-non-state-file-write-allowed" 0 "" "$payload"

# =========================================================================
# Cases 55-58: gate-protection root resolution from CLAUDE_PROJECT_DIR
# (contract: docs/proposals/2026-07-26-gate-root-from-project-dir.md).
# =========================================================================

# Case 55: CLAUDE_PROJECT_DIR points at an unrelated, empty directory (no
# docs/specs/role-handoff-contract.md, not itself a git work-tree top-level)
# while a Write targets this repo's real owned record tree -> expect refuse.
# The root is INDETERMINATE and this must be a default-deny, not a silent
# allow from "not this gate's business".
unrelated_root="$(mktemp -d "${TMPDIR:-/tmp}/gate-test-unrelated.XXXXXX")"
LIVE_WORKSPACES+=("$unrelated_root")
real_owned_target="${REPO_ROOT}/docs/reports/records/root-resolution-subject/qa.md"
payload="$(payload_write "$real_owned_target" $'kind: qa-record\n')"
run_case "project-dir-unrelated-empty-dir-real-target-refused" 2 "" "$payload" "CLAUDE_PROJECT_DIR=${unrelated_root}"

# Case 56: CLAUDE_PROJECT_DIR correctly points at this repo -> a legal write
# to the agent's own record path under it is still enforced (allowed).
own_record_56="${REPO_ROOT}/docs/reports/records/root-resolution-subject-56/qa.md"
payload="$(payload_write "$own_record_56" $'kind: qa-record\n')"
run_case "project-dir-correct-enforces-normally-allowed" 0 "" "$payload" "CLAUDE_PROJECT_DIR=${REPO_ROOT}"

# Case 57: CLAUDE_PROJECT_DIR correctly points at this repo -> a write to
# another role's record path under it is still refused.
other_role_57="${REPO_ROOT}/docs/reports/records/root-resolution-subject-57/coding.md"
payload="$(payload_write "$other_role_57" $'kind: build-record\n')"
run_case "project-dir-correct-enforces-normally-refused" 2 "" "$payload" "CLAUDE_PROJECT_DIR=${REPO_ROOT}"

# Case 58: CLAUDE_PROJECT_DIR unset -> falls back to the git top-level of
# cwd. Invoked with cwd set to REPO_ROOT so the fallback resolves this repo;
# a write to another role's record path is still refused under the
# fallback-resolved root, proving the fallback enforces exactly as the
# explicit CLAUDE_PROJECT_DIR path does.
other_role_58="${REPO_ROOT}/docs/reports/records/root-resolution-subject-58/coding.md"
payload="$(payload_write "$other_role_58" $'kind: build-record\n')"
run_case_in_repo_root "project-dir-unset-git-toplevel-fallback-enforces" 2 "" "$payload" "CLAUDE_PROJECT_DIR="

# =========================================================================
# Cases 59+: fail-closed-on-internal-error (frozen contract:
# docs/proposals/2026-07-26-gates-fail-closed-on-internal-error.md).
#
# Every gate SCRIPT must resolve to exit 2 (DENY) on ANY internal error,
# because a PreToolUse hook BLOCKS only on exit 2 and treats every other
# non-zero exit as NON-BLOCKING (fail-OPEN). The two crash-inducing payloads
# are the ones named in the contract:
#   (a) a null byte in tool_input.file_path ( ) — makes os.path.realpath
#       raise an uncaught ValueError, which without the hardening exits 1
#       (fail-OPEN); the python excepthook + the shell rc-mapping both turn
#       it into exit 2.
#   (b) malformed (non-JSON) stdin — the parse-failure DENY path, asserted
#       here for every gate so a regression that made any of them fall
#       through on unparseable input would be caught.
# =========================================================================
GATES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

payload_nullbyte_write() {
  # A Write payload whose file_path carries an embedded NUL. Relative so it
  # joins the repo root and is reached by the gate's realpath() rather than
  # short-circuited as out-of-scope.
  python3 <<'PY'
import json
print(json.dumps({
    "tool_name": "Write",
    "tool_input": {
        "file_path": "docs/reports/records/crash-null/" + chr(0) + "/qa.md",
        "content": "kind: qa-record\n",
    },
}))
PY
}

MALFORMED_PAYLOAD='{ this is definitely : not valid json '

run_gate_crash() {
  # run_gate_crash <name> <gate-abs-path> <expected_exit> <payload> [extra_env...]
  # Runs an arbitrary gate script as a real subprocess with cwd=REPO_ROOT and
  # CLAUDE_PROJECT_DIR=REPO_ROOT, asserting on the observed exit code.
  local name="$1" gate="$2" expected="$3" payload="$4"
  shift 4
  local extra_env=("$@")
  local err rc
  set +e
  err="$(cd "$REPO_ROOT" && printf '%s' "$payload" \
    | env "${GATE_ENV_CLEAR[@]}" "CLAUDE_PROJECT_DIR=${REPO_ROOT}" \
        ${extra_env[@]+"${extra_env[@]}"} "$gate" 2>&1 1>/dev/null)"
  rc=$?
  set -e
  local status="ok"
  if [ "$rc" -ne "$expected" ]; then
    status="FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
  local msg_note=""
  if [ "$expected" -ne 0 ] && [ -z "$err" ]; then
    status="FAIL"
    msg_note=" (fail-closed message was empty)"
  fi
  RESULTS+=("${name}|${expected}|${rc}|${status}${msg_note}")
  echo "case: ${name} | expected: ${expected} | observed: ${rc} | ${status}${msg_note}"
}

nb_payload="$(payload_nullbyte_write)"

# Write-shaped gates: a null-byte file_path must DENY (exit 2) via the new
# hardening (an uncaught realpath ValueError would otherwise fail OPEN).
run_gate_crash "failclosed-transition-gate-nullbyte-path"      "${GATES_DIR}/transition-gate.sh"      2 "$nb_payload"
run_gate_crash "failclosed-doc-bucket-gate-nullbyte-path"      "${GATES_DIR}/doc-bucket-gate.sh"      2 "$nb_payload"
run_gate_crash "failclosed-path-ownership-gate-nullbyte-path"  "${GATES_DIR}/path-ownership-gate.sh"  2 "$nb_payload"
run_gate_crash "failclosed-record-fields-gate-nullbyte-path"   "${GATES_DIR}/record-fields-gate.sh"   2 "$nb_payload"

# Every gate (write-shaped and the git-commit gates alike): malformed JSON on
# stdin must DENY (exit 2), never fall through.
run_gate_crash "failclosed-transition-gate-malformed-json"     "${GATES_DIR}/transition-gate.sh"      2 "$MALFORMED_PAYLOAD"
run_gate_crash "failclosed-doc-bucket-gate-malformed-json"     "${GATES_DIR}/doc-bucket-gate.sh"      2 "$MALFORMED_PAYLOAD"
run_gate_crash "failclosed-path-ownership-gate-malformed-json" "${GATES_DIR}/path-ownership-gate.sh"  2 "$MALFORMED_PAYLOAD"
run_gate_crash "failclosed-record-fields-gate-malformed-json"  "${GATES_DIR}/record-fields-gate.sh"   2 "$MALFORMED_PAYLOAD"
run_gate_crash "failclosed-handbook-trigger-gate-malformed-json" "${GATES_DIR}/handbook-trigger-gate.sh" 2 "$MALFORMED_PAYLOAD"
run_gate_crash "failclosed-trailer-gate-malformed-json"        "${GATES_DIR}/trailer-gate.sh"         2 "$MALFORMED_PAYLOAD"

# --- pre-logic abort (trap-at-top fail-closed) -------------------------------
# The class the top-of-file EXIT trap closes: a gate that ABORTS for any reason
# BEFORE its verdict logic runs — a failed `source`, a `set -euo pipefail`
# abort, an unbound var — would exit non-2, which a PreToolUse hook treats as
# NON-BLOCKING (fail-OPEN). The trap installed as the FIRST executable
# statement (above set/source) must convert any such non-0-non-2 exit into
# exit 2 (DENY). We prove it per-gate: take the REAL gate, inject a poison
# `false` immediately after its first `set -euo pipefail` (a pre-verdict-logic
# abort under `set -e`, rc=1), run the injected copy, and assert exit 2.
run_gate_prelogic_abort() {
  # run_gate_prelogic_abort <name> <gate-abs-path>
  local name="$1" gate="$2"
  local tmp rc err injected=0
  tmp="$(mktemp "${TMPDIR:-/tmp}/prelogic-gate.XXXXXX.sh")"
  # Insert `false` on the line after the first `set -euo pipefail`. awk keeps
  # the trap and shebang exactly as shipped; the injection sits below `set -e`
  # so it aborts the script before any verdict logic can run.
  awk '
    { print }
    !done && /^set -euo pipefail/ { print "false  # injected pre-logic abort"; done=1 }
  ' "$gate" > "$tmp"
  if grep -q "injected pre-logic abort" "$tmp"; then injected=1; fi
  chmod +x "$tmp"
  set +e
  err="$(cd "$REPO_ROOT" && printf '%s' "$nb_payload" \
    | env "${GATE_ENV_CLEAR[@]}" "CLAUDE_PROJECT_DIR=${REPO_ROOT}" "$tmp" 2>&1 1>/dev/null)"
  rc=$?
  set -e
  rm -f "$tmp"
  local status="ok"
  if [ "$injected" -ne 1 ]; then
    status="FAIL (no set -euo pipefail anchor to inject after)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  elif [ "$rc" -ne 2 ]; then
    status="FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
  RESULTS+=("${name}|2|${rc}|${status}")
  echo "case: ${name} | expected: 2 | observed: ${rc} | ${status}"
}

run_gate_prelogic_abort "failclosed-transition-gate-prelogic-abort"       "${GATES_DIR}/transition-gate.sh"
run_gate_prelogic_abort "failclosed-doc-bucket-gate-prelogic-abort"       "${GATES_DIR}/doc-bucket-gate.sh"
run_gate_prelogic_abort "failclosed-path-ownership-gate-prelogic-abort"   "${GATES_DIR}/path-ownership-gate.sh"
run_gate_prelogic_abort "failclosed-record-fields-gate-prelogic-abort"    "${GATES_DIR}/record-fields-gate.sh"
run_gate_prelogic_abort "failclosed-handbook-trigger-gate-prelogic-abort" "${GATES_DIR}/handbook-trigger-gate.sh"
run_gate_prelogic_abort "failclosed-trailer-gate-prelogic-abort"          "${GATES_DIR}/trailer-gate.sh"

# --- tally -------------------------------------------------------------------

echo ""
echo "=== tally: ${PASS_COUNT} passed, ${FAIL_COUNT} failed (of $((PASS_COUNT + FAIL_COUNT)) cases) ==="

# --- final step: directive-drift-check ---------------------------------
# Separate script, separate mechanism (compares directive markers against
# transition-gate.sh --dump-facts) — not folded into the run_case fixture
# machinery above. See docs/proposals/2026-08-04-directive-drift-check.md.
echo ""
echo "=== directive-drift-check ==="
drift_rc=0
"${SCRIPT_DIR}/directive-drift-check.sh" || drift_rc=$?
if [ "$drift_rc" -eq 3 ]; then
  # Exit 3 is "could not run here", not "ran and found drift". Reported
  # loudly and separately, and deliberately not counted as a failure: a
  # permanently red tally on macOS would bury the 52 gate cases that do run.
  echo "=== directive-drift-check: DID NOT RUN — see the message above ==="
elif [ "$drift_rc" -ne 0 ]; then
  echo "=== directive-drift-check: FAILED (exit ${drift_rc}) ==="
else
  echo "=== directive-drift-check: passed ==="
fi

if [ "$FAIL_COUNT" -ne 0 ] || { [ "$drift_rc" -ne 0 ] && [ "$drift_rc" -ne 3 ]; }; then
  exit 1
fi
exit 0
