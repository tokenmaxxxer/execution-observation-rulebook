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

write_state() {
  # write_state <ws> <slug> <content>
  local ws="$1" slug="$2" content="$3"
  local dir="${ws}/projects/${slug}"
  mkdir -p "$dir"
  printf '%s' "$content" > "${dir}/state.md"
}

write_token() {
  # write_token <ws> <slug> <transition> <project> <phrase>
  local ws="$1" slug="$2" transition="$3" project="$4" phrase="$5"
  local dir="${ws}/projects/${slug}"
  mkdir -p "$dir"
  {
    printf 'transition: %s\n' "$transition"
    printf 'project: %s\n' "$project"
    printf 'phrase: %s\n' "$phrase"
  } > "${dir}/.verdict-token"
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

cleanup_ws() {
  local ws="$1"
  [ -n "$ws" ] && [ -d "$ws" ] && rm -rf "$ws"
}

# =========================================================================
# Case 1: valid table-permitted transition (agent actor) -> expect allow
# =========================================================================
ws1="$(new_workspace)"
slug="owner-repo"
write_state "$ws1" "$slug" $'---\nphase: intake-scoping\n---\n'
payload="$(payload_write "${ws1}/projects/${slug}/state.md" $'---\nphase: session-chartered\n---\n')"
run_case "valid-table-permitted-transition" 0 "$ws1" "$payload"
cleanup_ws "$ws1"

# =========================================================================
# Case 2: transition not permitted from current phase -> expect refuse
# =========================================================================
ws2="$(new_workspace)"
slug="owner-repo"
write_state "$ws2" "$slug" $'---\nphase: intake-scoping\n---\n'
payload="$(payload_write "${ws2}/projects/${slug}/state.md" $'---\nphase: Go\n---\n')"
run_case "transition-not-permitted-from-current-phase" 2 "$ws2" "$payload"
cleanup_ws "$ws2"

# =========================================================================
# Case 3: human-actor transition with no token -> expect refuse
# =========================================================================
ws3="$(new_workspace)"
slug="owner-repo"
write_state "$ws3" "$slug" $'---\nphase: finding-triage\n---\n'
payload="$(payload_write "${ws3}/projects/${slug}/state.md" $'---\nphase: Confirmed-Defect\n---\n')"
run_case "human-actor-transition-no-token" 2 "$ws3" "$payload"
cleanup_ws "$ws3"

# =========================================================================
# Case 4: human-actor transition with a matching unconsumed token
#         -> expect allow AND the token file is gone afterward
# =========================================================================
ws4="$(new_workspace)"
slug="owner-repo"
write_state "$ws4" "$slug" $'---\nphase: finding-triage\n---\n'
write_token "$ws4" "$slug" "finding-triage -> Confirmed-Defect" "$slug" "yes, this is a genuine defect"
payload="$(payload_write "${ws4}/projects/${slug}/state.md" $'---\nphase: Confirmed-Defect\n---\n')"
run_case "human-actor-transition-matching-token" 0 "$ws4" "$payload"
token_path="${ws4}/projects/${slug}/.verdict-token"
if [ -e "$token_path" ]; then
  echo "case: human-actor-token-consumed | expected: token absent | observed: token still present | FAIL"
  RESULTS+=("human-actor-token-consumed|absent|present|FAIL")
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "case: human-actor-token-consumed | expected: token absent | observed: token absent | ok"
  RESULTS+=("human-actor-token-consumed|absent|absent|ok")
  PASS_COUNT=$((PASS_COUNT + 1))
fi

# =========================================================================
# Case 5: the same token replayed -> expect refuse
#         (case 4 already consumed the token in ws4; reuse the same
#          workspace/state to attempt the identical transition again)
# =========================================================================
payload="$(payload_write "${ws4}/projects/${slug}/state.md" $'---\nphase: Confirmed-Defect\n---\n')"
run_case "token-replayed" 2 "$ws4" "$payload"
cleanup_ws "$ws4"

# =========================================================================
# Case 6: non-JSON stdin -> expect refuse
# =========================================================================
ws6="$(new_workspace)"
slug="owner-repo"
write_state "$ws6" "$slug" $'---\nphase: intake-scoping\n---\n'
run_case "non-json-stdin" 2 "$ws6" "this is not json at all {{{"
cleanup_ws "$ws6"

# =========================================================================
# Case 7: state file absent -> expect refuse
#         (absent state.md resolves to phase "(none)"; attempting a
#          transition not legal from "(none)" surfaces the refusal)
# =========================================================================
ws7="$(new_workspace)"
slug="owner-repo"
mkdir -p "${ws7}/projects/${slug}"
payload="$(payload_write "${ws7}/projects/${slug}/state.md" $'---\nphase: session-executed\n---\n')"
run_case "state-file-absent" 2 "$ws7" "$payload"
cleanup_ws "$ws7"

# =========================================================================
# Case 8: state file with no frontmatter block -> expect refuse
# =========================================================================
ws8="$(new_workspace)"
slug="owner-repo"
write_state "$ws8" "$slug" $'phase: intake-scoping\nno frontmatter delimiters here\n'
payload="$(payload_write "${ws8}/projects/${slug}/state.md" $'---\nphase: session-chartered\n---\n')"
run_case "state-file-no-frontmatter" 2 "$ws8" "$payload"
cleanup_ws "$ws8"

# =========================================================================
# Case 9: a `phase:` line in the write body with no frontmatter block
#         -> expect refuse
# =========================================================================
ws9="$(new_workspace)"
slug="owner-repo"
write_state "$ws9" "$slug" $'---\nphase: intake-scoping\n---\n'
payload="$(payload_write "${ws9}/projects/${slug}/state.md" $'phase: session-chartered\nno frontmatter here either\n')"
run_case "phase-line-no-frontmatter-in-body" 2 "$ws9" "$payload"
cleanup_ws "$ws9"

# =========================================================================
# Case 10: QA_WORKSPACE unset -> expect refuse
# =========================================================================
payload="$(payload_write "/nonexistent/projects/owner-repo/state.md" $'---\nphase: session-chartered\n---\n')"
run_case "qa-workspace-unset" 2 "" "$payload"

# =========================================================================
# Case 11: QA_CYCLE_DISABLE=1 -> expect allow (deliberate operator override)
# =========================================================================
ws11="$(new_workspace)"
slug="owner-repo"
write_state "$ws11" "$slug" $'---\nphase: intake-scoping\n---\n'
payload="$(payload_write "${ws11}/projects/${slug}/state.md" $'---\nphase: Go\n---\n')"
run_case "qa-cycle-disable-override" 0 "$ws11" "$payload" "QA_CYCLE_DISABLE=1"
cleanup_ws "$ws11"

# --- tally -------------------------------------------------------------------

echo ""
echo "=== tally: ${PASS_COUNT} passed, ${FAIL_COUNT} failed (of $((PASS_COUNT + FAIL_COUNT)) cases) ==="

if [ "$FAIL_COUNT" -ne 0 ]; then
  exit 1
fi
exit 0
