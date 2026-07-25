#!/usr/bin/env bash
# Executes the real signoff/hooks/capture-verdict.sh as a subprocess, one
# case at a time, against a real temporary QA_WORKSPACE and a real git
# repository it builds and tears down. It asserts on the observed exit code
# and on which token files the run left behind — never on the hook's source
# text.
#
# The hook's contract is that it never blocks: any exit status other than 0
# is a defect, and a UserPromptSubmit hook exiting 2 stops the user's prompt
# from reaching the agent at all. Cases 1-3 and 8 each reproduced a distinct
# way that contract was broken before 2026-07-26.
#
# Cases
#   1  no origin remote                    -> exit 0, no token   (was: exit 2)
#   2  prompt names no item                -> exit 0, no token   (was: exit 1)
#   3  confirmed defect, no priority word  -> exit 0, F-1.token, clean stderr
#                                                                (was: exit 1, no token)
#   4  priority verdict alone              -> exit 0, F-1.priority.token
#   5  both verdicts in one turn           -> exit 0, both tokens
#   6  item id absent from state.md        -> exit 0, no token
#   7  bare assent ("ok")                  -> exit 0, no token
#   8  workspace reached through a symlink -> exit 0, F-1.token   (was: no token)
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

new_repo() { # new_repo <origin|no-origin> -> repo path
  local d
  d="$(mktemp -d)"
  LIVE+=("$d")
  d="$(cd "$d" && pwd -P)"
  git -C "$d" init -q
  if [ "$1" = origin ]; then
    git -C "$d" remote add origin https://github.com/acme/widget.git
  fi
  printf '%s' "$d"
}

new_workspace() { # new_workspace <slug> -> workspace path, holding item F-1 in `reproduced`
  local ws="$1" slug="$2"
  mkdir -p "$ws/projects/$slug"
  printf -- '---\nitem: F-1\nstate: reproduced\n---\n' > "$ws/projects/$slug/state.md"
}

# --- the check ---------------------------------------------------------------

# run_case <name> <origin|no-origin> <expected-exit> <expected-tokens> <prompt> [env=val ...]
#   <expected-tokens>: space-separated token filenames, or "-" for none.
run_case() {
  local name="$1" origin="$2" want_exit="$3" want_tokens="$4" prompt="$5"
  shift 5

  local repo ws slug
  repo="$(new_repo "$origin")"
  ws="$(mktemp -d)"
  LIVE+=("$ws")
  ws="$(cd "$ws" && pwd -P)"
  if [ "$origin" = origin ]; then slug=acme-widget; else slug="$(basename "$repo")"; fi
  new_workspace "$ws" "$slug"

  # Case 8 hands the hook a path that reaches the same workspace through a
  # symlink — the shape every macOS `mktemp -d` and `/tmp` path already has.
  local ws_arg="$ws"
  if [ "$name" = "symlinked workspace" ]; then
    local link="${ws}-link"
    ln -s "$ws" "$link"
    LIVE+=("$link")
    ws_arg="$link"
  fi

  local err_file out_err rc
  err_file="$(mktemp)"
  LIVE+=("$err_file")
  ( cd "$repo" \
      && env "$@" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" QA_WORKSPACE="$ws_arg" \
         bash "$HOOK" >/dev/null 2>"$err_file" \
  ) < <(jq -nc --arg p "$prompt" '{hook_event_name:"UserPromptSubmit",prompt:$p}')
  rc=$?
  out_err="$(cat "$err_file")"

  local got_tokens
  got_tokens="$(cd "$ws/projects/$slug/tokens" 2>/dev/null && ls 2>/dev/null | sort | tr '\n' ' ')"
  got_tokens="$(echo "${got_tokens:-}" | xargs || true)"
  [ -n "$got_tokens" ] || got_tokens="-"
  local want_sorted
  want_sorted="$(echo "$want_tokens" | tr ' ' '\n' | sort | tr '\n' ' ' | xargs || true)"

  local verdict=ok
  [ "$rc" = "$want_exit" ] || verdict=FAIL
  [ "$got_tokens" = "$want_sorted" ] || verdict=FAIL
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

run_case "no origin remote"              no-origin 0 "-"                                   '/testrun:testrun'
run_case "prompt names no item"          origin    0 "-"                                   'run the smoke tests please'
run_case "confirmed defect, no priority" origin    0 "F-1.token"                           'item F-1 confirmed defect'
run_case "priority verdict alone"        origin    0 "F-1.priority.token"                  'item F-1 priority now'
run_case "both verdicts in one turn"     origin    0 "F-1.token F-1.priority.token"        'item F-1 confirmed defect priority now'
run_case "item absent from state.md"     origin    0 "-"                                   'item F-9 confirmed defect'
run_case "bare assent"                   origin    0 "-"                                   'ok'
run_case "symlinked workspace"           origin    0 "F-1.token"                           'item F-1 confirmed defect'
run_case "kill switch"                   origin    0 "-"                                   'item F-1 confirmed defect' QA_SIGNOFF_DISABLE=1

echo
echo "passed ${PASS}, failed ${FAIL}"
[ "$FAIL" -eq 0 ]
