#!/usr/bin/env bash
# Executes the real signoff/hooks/capture-verdict.sh as a subprocess, one
# case at a time, against a real temporary target repo it builds and tears
# down — docs/reports/records/<subject>/qa/state.md inside it, never an
# external workspace (docs/proposals/2026-07-27-qa-records-in-target-repo.md).
# It asserts on the observed exit code and on which token files the run left
# behind — never on the hook's source text.
#
# The hook's contract is that it never blocks: any exit status other than 0
# is a defect, and a UserPromptSubmit hook exiting 2 stops the user's prompt
# from reaching the agent at all. Cases 1-3 and 8 each reproduced a distinct
# way that contract was broken before 2026-07-26.
#
# Cases
#   1  no subject records at all           -> exit 0, no token
#   2  prompt names no item                -> exit 0, no token   (was: exit 1)
#   3  confirmed defect, no priority word  -> exit 0, F-1.token, clean stderr
#                                                                (was: exit 1, no token)
#   4  priority verdict alone              -> exit 0, F-1.priority.token
#   5  both verdicts in one turn           -> exit 0, both tokens
#   6  item id absent from state.md        -> exit 0, no token
#   7  bare assent ("ok")                  -> exit 0, no token
#   8  repo reached through a symlink       -> exit 0, F-1.token   (was: no token)
#   9  QA_SIGNOFF_DISABLE=1                -> exit 0, no token
#
# Run it:  signoff/hooks/tests/run-verdict-tests.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOK="${SCRIPT_DIR}/../capture-verdict.sh"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && cd .. && pwd -P)"

# Without these the hook exits 0 at its own dependency check, so every case
# below would pass for the wrong reason. Refuse to report a vacuous pass.
for dep in jq python3 git; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "missing: $dep — the hook exits 0 before reaching anything these cases test; not running." >&2
    exit 2
  }
done

PASS=0
FAIL=0
LIVE=()
cleanup() {
  local d
  for d in "${LIVE[@]:-}"; do
    [ -n "${d:-}" ] && [ -d "$d" ] && rm -rf "$d"
  done
  return 0
}
trap cleanup EXIT

# --- fixtures ---------------------------------------------------------------

new_repo() { # new_repo -> repo path, a real (empty-of-records) git work-tree
  local d
  d="$(mktemp -d)"
  LIVE+=("$d")
  d="$(cd "$d" && pwd -P)"
  git -C "$d" init -q
  mkdir -p "$d/docs/specs"
  # The gate/hook root-validity check requires this file to exist at the
  # resolved root (docs/specs/role-handoff-contract.md); a minimal stub is
  # enough for a fixture repo.
  printf 'stub for test fixture\n' > "$d/docs/specs/role-handoff-contract.md"
  printf '%s' "$d"
}

new_subject_state() { # new_subject_state <repo> <subject> -> writes state.md holding item F-1 in `reproduced`
  local repo="$1" subject="$2"
  local dir="$repo/docs/reports/records/$subject/qa"
  mkdir -p "$dir"
  printf -- '---\nitem: F-1\nstate: reproduced\n---\n' > "$dir/state.md"
}

# --- the check ---------------------------------------------------------------

# run_case <name> <expected-exit> <expected-tokens> <prompt> [env=val ...]
#   <expected-tokens>: space-separated token filenames, or "-" for none.
#
# WANT_TRANSITION (optional, set per-case before the call) additionally pins the
# `transition:` line inside the minted token. Filenames alone cannot tell a
# `handed-off` token from a `not-a-defect` one — both are `<item>.token` — so a
# case about WHICH verdict was read is not actually pinned without this.
run_case() {
  local name="$1" want_exit="$2" want_tokens="$3" prompt="$4"
  shift 4
  local want_transition="${WANT_TRANSITION:-}"
  WANT_TRANSITION=""

  local repo subject
  repo="$(new_repo)"
  subject="F-1-subject"

  if [ "$name" = "no subject records at all" ]; then
    : # deliberately leave docs/reports/records/ absent entirely
  else
    new_subject_state "$repo" "$subject"
  fi

  # Case 8 hands the hook a project root that reaches the same repo through
  # a symlink — the shape every macOS `mktemp -d` and `/tmp` path already has.
  local repo_arg="$repo"
  if [ "$name" = "symlinked repo root" ]; then
    local link="${repo}-link"
    ln -s "$repo" "$link"
    LIVE+=("$link")
    repo_arg="$link"
  fi

  local err_file out_err rc
  err_file="$(mktemp)"
  LIVE+=("$err_file")
  ( cd "$repo" \
      && env "$@" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PROJECT_DIR="$repo_arg" \
         bash "$HOOK" >/dev/null 2>"$err_file" \
  ) < <(jq -nc --arg p "$prompt" '{hook_event_name:"UserPromptSubmit",prompt:$p}')
  rc=$?
  out_err="$(cat "$err_file")"

  local tokens_dir="$repo/docs/reports/records/$subject/qa/tokens"
  local got_tokens
  got_tokens="$(cd "$tokens_dir" 2>/dev/null && ls 2>/dev/null | sort | tr '\n' ' ')"
  got_tokens="$(echo "${got_tokens:-}" | xargs || true)"
  [ -n "$got_tokens" ] || got_tokens="-"
  local want_sorted
  want_sorted="$(echo "$want_tokens" | tr ' ' '\n' | sort | tr '\n' ' ' | xargs || true)"

  local verdict=ok
  [ "$rc" = "$want_exit" ] || verdict=FAIL
  [ "$got_tokens" = "$want_sorted" ] || verdict=FAIL
  if [ -n "$want_transition" ]; then
    local got_transition
    got_transition="$(grep -h '^transition:' "$tokens_dir"/*.token 2>/dev/null \
                      | head -1 | sed 's/^transition: //' || true)"
    if [ "$got_transition" != "$want_transition" ]; then
      verdict=FAIL
      name="$name (transition: want '$want_transition', got '${got_transition:-none}')"
    fi
  fi
  # Case 3 additionally pins that the hook writes nothing to stderr on a
  # clean mint: a malformed grep invocation used to leak an error there on
  # every single mint.
  if [ "$name" = "confirmed defect, no priority" ] && [ -n "$out_err" ]; then
    verdict=FAIL
    name="$name (stderr: $out_err)"
  fi

  printf 'case: %-34s | exit %s/%s | tokens %-34s | %s\n' \
    "$name" "$want_exit" "$rc" "$want_sorted -> $got_tokens" "$verdict"
  if [ "$verdict" = ok ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); fi
}

run_case "no subject records at all"     0 "-"                                   '/testrun:testrun'
run_case "prompt names no item"          0 "-"                                   'run the smoke tests please'
WANT_TRANSITION="reproduced -> handed-off" \
run_case "confirmed defect, no priority" 0 "F-1.token"                           'item F-1 confirmed defect'
run_case "priority verdict alone"        0 "F-1.priority.token"                  'item F-1 priority now'
run_case "both verdicts in one turn"     0 "F-1.token F-1.priority.token"        'item F-1 confirmed defect priority now'
run_case "item absent from state.md"     0 "-"                                   'item F-9 confirmed defect'
run_case "bare assent"                   0 "-"                                   'ok'
run_case "symlinked repo root"           0 "F-1.token"                           'item F-1 confirmed defect'
# A verdict must be ASSERTED, and a negated verdict is the negative verdict —
# not the positive one. Measured 2026-07-27 before the fix: all three of these
# minted `reproduced -> handed-off`, and the first wrote the human's refusal
# into the token's own `phrase:` field as its evidence.
WANT_TRANSITION="reproduced -> not-a-defect" \
run_case "negated defect verdict"        0 "F-1.token"                           'item F-1 - to be clear, this is NOT a confirmed defect. Leave it alone.'
run_case "question is not a verdict"     0 "-"                                   'Is item F-1 a confirmed defect? I am not sure yet, do not do anything.'
run_case "hedged verdict"                0 "-"                                   'item F-1 might be a confirmed defect, I think'
WANT_TRANSITION="reproduced -> not-a-defect" \
run_case "plain negative verdict"        0 "F-1.token"                           'item F-1 is not a defect'
run_case "kill switch"                   0 "-"                                   'item F-1 confirmed defect' QA_SIGNOFF_DISABLE=1

echo
echo "passed ${PASS}, failed ${FAIL}"
[ "$FAIL" -eq 0 ]
