#!/usr/bin/env bash
# Executes qa-cycle/hooks/transition-gate.sh as a real subprocess against
# real fixture files, one case at a time, and asserts on the observed exit
# code (and, where the gate emits a refusal message, that the message is
# non-empty). See qa-cycle/hooks/tests/README.md to run this.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="${SCRIPT_DIR}/../transition-gate.sh"

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
  return 0
}
trap cleanup_all EXIT

# --- fixture helpers --------------------------------------------------------

new_workspace() {
  local ws
  ws="$(mktemp -d "${TMPDIR:-/tmp}/gate-test.XXXXXX")"
  LIVE_WORKSPACES+=("$ws")
  echo "$ws"
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

write_priority_token() {
  # write_priority_token <ws> <slug> <item-id> <value> <phrase>
  local ws="$1" slug="$2" item="$3" value="$4" phrase="$5"
  local dir="${ws}/projects/${slug}/tokens"
  mkdir -p "$dir"
  {
    printf 'item: %s\n' "$item"
    printf 'field: priority\n'
    printf 'value: %s\n' "$value"
    printf 'phrase: %s\n' "$phrase"
  } > "${dir}/${item}.priority.token"
}

write_state() {
  # write_state <ws> <slug> <content>
  local ws="$1" slug="$2" content="$3"
  local dir="${ws}/projects/${slug}"
  mkdir -p "$dir"
  printf '%s' "$content" > "${dir}/state.md"
}

write_token() {
  # write_token <ws> <slug> <item-id> <transition> <phrase>
  local ws="$1" slug="$2" item="$3" transition="$4" phrase="$5"
  local dir="${ws}/projects/${slug}/tokens"
  mkdir -p "$dir"
  {
    printf 'item: %s\n' "$item"
    printf 'transition: %s\n' "$transition"
    printf 'phrase: %s\n' "$phrase"
  } > "${dir}/${item}.token"
}

write_consuming() {
  # write_consuming <ws> <slug> <item-id> <transition> <phrase>
  local ws="$1" slug="$2" item="$3" transition="$4" phrase="$5"
  local dir="${ws}/projects/${slug}/tokens"
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

# --- test runner -------------------------------------------------------------

run_case() {
  # run_case <name> <expected_exit> <ws-or-empty> <payload-or-empty> [extra_env...]
  local name="$1" expected="$2" ws="$3" payload="$4"
  shift 4
  local extra_env=("$@")

  local out err rc
  local env_args=()
  if [ -n "$ws" ]; then
    env_args+=("QA_WORKSPACE=${ws}")
  fi
  env_args+=("${extra_env[@]}")

  set +e
  err="$(printf '%s' "$payload" | env "${env_args[@]}" "$GATE" 2>&1 1>/tmp/gate-test-stdout.$$)"
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
payload="$(payload_write "${ws1}/projects/${slug}/state.md" "$(item_block BUG-1 reproducing)")"
run_case "valid-table-permitted-transition" 0 "$ws1" "$payload"
cleanup_ws "$ws1"

# =========================================================================
# Case 2: transition not permitted from current state -> expect refuse
# =========================================================================
ws2="$(new_workspace)"
slug="owner-repo"
write_state "$ws2" "$slug" "$(item_block BUG-1 observed)"
payload="$(payload_write "${ws2}/projects/${slug}/state.md" "$(item_block BUG-1 verified-fixed)")"
run_case "transition-not-permitted-from-current-state" 2 "$ws2" "$payload"
cleanup_ws "$ws2"

# =========================================================================
# Case 3: human-actor transition with no token -> expect refuse
# =========================================================================
ws3="$(new_workspace)"
slug="owner-repo"
write_state "$ws3" "$slug" "$(item_block BUG-1 reproduced)"
payload="$(payload_write "${ws3}/projects/${slug}/state.md" "$(item_block BUG-1 handed-off)")"
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
payload="$(payload_write "${ws4}/projects/${slug}/state.md" "$(item_block BUG-1 handed-off)")"
run_case "human-actor-transition-matching-token" 0 "$ws4" "$payload"
expect_file "human-actor-live-token-gone" "${ws4}/projects/${slug}/tokens/BUG-1.token" "absent"
expect_file "human-actor-consuming-marker-present" "${ws4}/projects/${slug}/tokens/BUG-1.consuming" "exists"

# =========================================================================
# Case 5: the same token replayed against the SAME still-unadvanced state
#         -> expect allow again (this is the consumption-timing fix: the
#            marker from case 4 still authorizes a retry of the identical
#            transition because state.md was never actually advanced here)
# =========================================================================
payload="$(payload_write "${ws4}/projects/${slug}/state.md" "$(item_block BUG-1 handed-off)")"
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
payload="$(payload_write "${ws7}/projects/${slug}/state.md" "$(item_block BUG-1 reproduced)")"
run_case "state-file-absent" 2 "$ws7" "$payload"
cleanup_ws "$ws7"

# =========================================================================
# Case 8: state file with no frontmatter block -> expect refuse
# =========================================================================
ws8="$(new_workspace)"
slug="owner-repo"
write_state "$ws8" "$slug" $'item: BUG-1\nstate: observed\nno frontmatter delimiters here\n'
payload="$(payload_write "${ws8}/projects/${slug}/state.md" "$(item_block BUG-1 reproducing)")"
run_case "state-file-no-frontmatter" 2 "$ws8" "$payload"
cleanup_ws "$ws8"

# =========================================================================
# Case 9: a write with no readable item/state block -> expect refuse
# =========================================================================
ws9="$(new_workspace)"
slug="owner-repo"
write_state "$ws9" "$slug" "$(item_block BUG-1 observed)"
payload="$(payload_write "${ws9}/projects/${slug}/state.md" $'item: BUG-1\nstate: reproducing\nno frontmatter here either\n')"
run_case "no-item-block-in-write-body" 2 "$ws9" "$payload"
cleanup_ws "$ws9"

# =========================================================================
# Case 10: QA_WORKSPACE unset -> expect refuse
# =========================================================================
payload="$(payload_write "/nonexistent/projects/owner-repo/state.md" "$(item_block BUG-1 reproducing)")"
run_case "qa-workspace-unset" 2 "" "$payload"

# =========================================================================
# Case 11: QA_CYCLE_DISABLE=1 -> expect allow (deliberate operator override)
# =========================================================================
ws11="$(new_workspace)"
slug="owner-repo"
write_state "$ws11" "$slug" "$(item_block BUG-1 observed)"
payload="$(payload_write "${ws11}/projects/${slug}/state.md" "$(item_block BUG-1 verified-fixed)")"
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
payload="$(payload_write "${ws12}/projects/${slug}/state.md" "$(item_block BUG-1 reproduced)$(item_block BUG-2 handed-off)")"
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
payload="$(payload_write "${ws13}/projects/${slug}/state.md" "$(item_block BUG-1 handed-off)")"
run_case "token-for-one-transition-rejected-for-another" 2 "$ws13" "$payload"
cleanup_ws "$ws13"

# =========================================================================
# Case 14: handed-off refuses a transition attempt with no human trigger
# =========================================================================
ws14="$(new_workspace)"
slug="owner-repo"
write_state "$ws14" "$slug" "$(item_block BUG-1 handed-off)"
payload="$(payload_write "${ws14}/projects/${slug}/state.md" "$(item_block BUG-1 re-verifying)")"
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

payload="$(payload_write "${ws15}/projects/${slug}/state.md" "$(item_block BUG-1 handed-off)")"
run_case "consumption-timing-first-allow-write-does-not-land" 0 "$ws15" "$payload"
# state.md deliberately left unadvanced here to model the write not landing.

payload="$(payload_write "${ws15}/projects/${slug}/state.md" "$(item_block BUG-1 handed-off)")"
run_case "consumption-timing-retry-still-allowed" 0 "$ws15" "$payload"

# Now actually land the write, simulating the retry succeeding this time.
write_state "$ws15" "$slug" "$(item_block BUG-1 handed-off)"

payload="$(payload_write "${ws15}/projects/${slug}/state.md" "$(item_block BUG-1 re-verifying)")"
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
payload="$(payload_write "${ws16}/projects/${slug}/state.md" "$(item_block "$evil_item" handed-off)")"
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
payload="$(payload_write "${ws17}/projects/${slug}/state.md" "$(item_block "-BUG-1" reproducing)")"
run_case "item-id-leading-hyphen-refused" 2 "$ws17" "$payload"
cleanup_ws "$ws17"

# =========================================================================
# Case 18: item id with characters outside the allow-list (a slash) ->
#          expect refuse.
# =========================================================================
ws18="$(new_workspace)"
slug="owner-repo"
write_state "$ws18" "$slug" "$(item_block "BUG/1" observed)"
payload="$(payload_write "${ws18}/projects/${slug}/state.md" "$(item_block "BUG/1" reproducing)")"
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
payload="$(payload_write "${ws19}/projects/${slug}/state.md" "$(item_block "$long_item" reproducing)")"
run_case "item-id-over-length-refused" 2 "$ws19" "$payload"
cleanup_ws "$ws19"

# =========================================================================
# Case 20: project identifier outside the allow-list. `os.path.realpath`
#          already collapses `..` segments before the project slug is ever
#          extracted, so a literal `..` traversal in the project segment of
#          file_path resolves to a path outside the workspace root entirely
#          and is refused earlier, as "not this gate's business" (exit 0,
#          covered by the workspace-containment check, not this case). What
#          the project-identifier allow-list additionally catches is a
#          slug that *is* a single, real path component under
#          projects/ — passing the earlier realpath containment check —
#          but contains characters outside the allow-list (here, a
#          semicolon). Same defense-in-depth the item id gets -> expect
#          refuse.
# =========================================================================
ws20="$(new_workspace)"
slug='owner;rm-repo'
write_state "$ws20" "$slug" "$(item_block BUG-1 observed)"
payload="$(payload_write "${ws20}/projects/${slug}/state.md" "$(item_block BUG-1 reproducing)")"
run_case "project-id-disallowed-characters-refused" 2 "$ws20" "$payload"
cleanup_ws "$ws20"

# =========================================================================
# Case 21: item missing `severity` attempting reproducing -> reproduced
#          -> expect refuse (the precondition from docs/specs/
#          qa-cycle-state-machine.md "Severity and priority").
# =========================================================================
ws21="$(new_workspace)"
slug="owner-repo"
write_state "$ws21" "$slug" "$(item_block BUG-1 reproducing)"
payload="$(payload_write "${ws21}/projects/${slug}/state.md" "$(item_block_with_severity BUG-1 reproduced "")")"
run_case "reproduced-missing-severity-refused" 2 "$ws21" "$payload"
cleanup_ws "$ws21"

# =========================================================================
# Case 22: `severity` outside the closed set -> expect refuse
# =========================================================================
ws22="$(new_workspace)"
slug="owner-repo"
write_state "$ws22" "$slug" "$(item_block BUG-1 reproducing)"
payload="$(payload_write "${ws22}/projects/${slug}/state.md" "$(item_block_with_severity BUG-1 reproduced $'severity: catastrophic\n')")"
run_case "reproduced-severity-outside-closed-set-refused" 2 "$ws22" "$payload"
cleanup_ws "$ws22"

# =========================================================================
# Case 23: two `severity` lines in one record -> expect refuse (zero or
#          multiple both mean "no severity", which refuses the precondition)
# =========================================================================
ws23="$(new_workspace)"
slug="owner-repo"
write_state "$ws23" "$slug" "$(item_block BUG-1 reproducing)"
payload="$(payload_write "${ws23}/projects/${slug}/state.md" "$(item_block_with_severity BUG-1 reproduced $'severity: major\nseverity: minor\n')")"
run_case "reproduced-two-severity-lines-refused" 2 "$ws23" "$payload"
cleanup_ws "$ws23"

# =========================================================================
# Case 24: valid severity present -> reproducing -> reproduced allowed
# =========================================================================
ws24="$(new_workspace)"
slug="owner-repo"
write_state "$ws24" "$slug" "$(item_block BUG-1 reproducing)"
payload="$(payload_write "${ws24}/projects/${slug}/state.md" "$(item_block_with_severity BUG-1 reproduced $'severity: major\n')")"
run_case "reproduced-valid-severity-allowed" 0 "$ws24" "$payload"
cleanup_ws "$ws24"

# =========================================================================
# Case 25: `priority` change with no token -> expect refuse
# =========================================================================
ws25="$(new_workspace)"
slug="owner-repo"
write_state "$ws25" "$slug" "$(item_block BUG-1 reproduced)"
payload="$(payload_write "${ws25}/projects/${slug}/state.md" "$(item_block_with_priority BUG-1 reproduced now)")"
run_case "priority-change-no-token-refused" 2 "$ws25" "$payload"
cleanup_ws "$ws25"

# =========================================================================
# Case 26: a priority token minted for a different item -> expect refuse
# =========================================================================
ws26="$(new_workspace)"
slug="owner-repo"
write_state "$ws26" "$slug" "$(item_block BUG-1 reproduced)$(item_block BUG-2 reproduced)"
write_priority_token "$ws26" "$slug" "BUG-2" "now" "item BUG-2 priority now"
payload="$(payload_write "${ws26}/projects/${slug}/state.md" "$(item_block_with_priority BUG-1 reproduced now)$(item_block BUG-2 reproduced)")"
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
payload="$(payload_write "${ws27}/projects/${slug}/state.md" "$(item_block_with_priority BUG-1 reproduced now)")"
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
payload="$(payload_write "${ws28}/projects/${slug}/state.md" "$forged_content")"
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
payload="$(payload_write "${ws29}/projects/${slug}/state.md" "$(item_block_with_priority BUG-1 reproduced now)")"
run_case "priority-token-first-use-allowed" 0 "$ws29" "$payload"
expect_file "priority-live-token-gone" "${ws29}/projects/${slug}/tokens/BUG-1.priority.token" "absent"
expect_file "priority-consuming-marker-present" "${ws29}/projects/${slug}/tokens/BUG-1.priority.consuming" "exists"

# Land the write for real (advance state.md), then finalize + attempt a
# second, different priority change with no fresh token -> must refuse.
write_state "$ws29" "$slug" "$(item_block_with_priority BUG-1 reproduced now)"
payload="$(payload_write "${ws29}/projects/${slug}/state.md" "$(item_block_with_priority BUG-1 reproduced next)")"
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
payload="$(payload_write "${ws30}/projects/${slug}/state.md" "$(item_block_with_priority BUG-1 reproduced now)")"
run_case "priority-consumption-timing-first-allow-write-does-not-land" 0 "$ws30" "$payload"
# state.md deliberately left unadvanced, modeling the permitted write failing.
payload="$(payload_write "${ws30}/projects/${slug}/state.md" "$(item_block_with_priority BUG-1 reproduced now)")"
run_case "priority-consumption-timing-retry-still-allowed" 0 "$ws30" "$payload"
cleanup_ws "$ws30"

# --- tally -------------------------------------------------------------------

echo ""
echo "=== tally: ${PASS_COUNT} passed, ${FAIL_COUNT} failed (of $((PASS_COUNT + FAIL_COUNT)) cases) ==="

if [ "$FAIL_COUNT" -ne 0 ]; then
  exit 1
fi
exit 0
