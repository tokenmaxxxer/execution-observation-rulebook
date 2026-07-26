#!/usr/bin/env bash
# Parses every hook in this rulebook with bash 3.2 — the /bin/bash that every
# macOS ships, and therefore the interpreter these hooks actually run under
# for most users.
#
# Guards one specific failure. A quoted-delimiter heredoc nested inside
# `$( … )` is NOT literal to bash 3.2's parser: it keeps tracking quotes and
# parentheses inside the body while it looks for the closing paren. One
# apostrophe in an English possessive — "the gate's own sentinel" — or one
# unbalanced `(` in a comment is enough to make the whole file fail to parse.
#
# The consequence depends on the hook's event, and neither shape announces
# itself:
#   UserPromptSubmit  every prompt for this role is blocked
#   SessionStart      the hook never runs and says nothing, which is
#                     indistinguishable from "nothing to report" (measured
#                     2026-07-26: report-phase.sh, line 56)
#
# bash 5 (Homebrew, most Linux CI) parses all of it happily, which is why
# this pins /bin/bash rather than using $BASH: run under bash 5 it still
# passes every file and simply cannot see the defect.
set -uo pipefail

BASH32="${PARSE_CHECK_BASH:-/bin/bash}"
hooks_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)" || {
  echo "parse-check: cannot resolve the hooks directory" >&2
  exit 2
}

[ -x "$BASH32" ] || { echo "parse-check: $BASH32 is not executable" >&2; exit 2; }
"$BASH32" --version | head -1

fail=0
for f in "$hooks_dir"/*.sh "$hooks_dir"/tests/*.sh; do
  [ -f "$f" ] || continue
  if err="$("$BASH32" -n "$f" 2>&1)"; then
    printf 'ok    %s\n' "${f#"$hooks_dir"/}"
  else
    printf 'FAIL  %s\n%s\n' "${f#"$hooks_dir"/}" "$err"
    fail=1
  fi
done
exit "$fail"
