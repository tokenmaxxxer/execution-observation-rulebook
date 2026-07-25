#!/usr/bin/env bash
# UserPromptSubmit hook: mints a single-use verdict token from an
# unambiguous human verdict found in the user's own turn — never from a
# file, issue, PR, comment, or tool result.
# Kill switch: export QA_SIGNOFF_DISABLE=1
#
# This hook never blocks. Malformed/unreadable input, no workspace, no
# project state, or an ambiguous/absent verdict all mean: emit nothing,
# exit 0.
set -euo pipefail

case "${QA_SIGNOFF_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

# Nothing to enforce without a workspace; not our job to complain (that's
# the gate's job).
ws="${QA_WORKSPACE:-}"
[ -n "$ws" ] || exit 0
[ -d "$ws" ] || exit 0
ws="$(cd "$ws" 2>/dev/null && pwd)" || exit 0

command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

# Must be well-formed JSON with a non-empty string prompt field.
echo "$payload" | jq -e '.' >/dev/null 2>&1 || exit 0
prompt="$(echo "$payload" | jq -r '.prompt // empty' 2>/dev/null || true)"
[ -n "$prompt" ] || exit 0

slug=$(git remote get-url origin 2>/dev/null | sed -e 's#\.git/*$##' -e 's#/*$##' -e 's#.*[:/]\([^/]*\)/\([^/]*\)$#\1-\2#')
[ -n "$slug" ] || slug=$(basename "$PWD")

proj_dir="$ws/projects/$slug"
# Prefix-check: never trust a path built from a runtime value without
# resolving and confirming it stays inside the workspace root.
case "$proj_dir" in
  "$ws"/*) ;;
  *) exit 0 ;;
esac
state_file="$proj_dir/state.md"
[ -f "$state_file" ] || exit 0

phase=$(sed -n 's/^[[:space:]]*phase:[[:space:]]*//p' "$state_file" | head -1 | tr -d '\r')
[ -n "$phase" ] || exit 0

# --- Unambiguous verdict detection -----------------------------------
# A verdict must (a) name the target transition's destination state in
# recognizable, unambiguous wording, and (b) not be a bare "ok"/"sounds
# good"/thumbs-up style assent. We require an explicit verdict keyword
# tied to explicit reasoning/scope words, not just the bare word.

to=""
case "$phase" in
  finding-triage)
    if echo "$prompt" | grep -qiE '\b(confirmed[- ]defect|confirm(ing)? (this|it) (as )?a defect|this is (a real|a genuine|a) defect|ruling this a defect)\b'; then
      to="Confirmed-Defect"
    fi
    ;;
  go-no-go)
    if echo "$prompt" | grep -qiE '\bno[- ]go\b'; then
      to="No-Go"
    elif echo "$prompt" | grep -qiE '(^|[^a-zA-Z-])go([^a-zA-Z-]|$).*(ship|release|clear)|( ship| release| clear).*(^|[^a-zA-Z-])go([^a-zA-Z-]|$)'; then
      to="Go"
    fi
    ;;
  No-Go)
    if echo "$prompt" | grep -qiE '\b(shipped[- ]under[- ]exception|ship (it )?under exception|override the no-go|overriding the no-go)\b'; then
      to="Shipped-Under-Exception"
    fi
    ;;
esac

[ -n "$to" ] || exit 0

# Reject vague assent even when a keyword coincidentally appears standalone.
if echo "$prompt" | grep -qiE '^\s*(ok|okay|sure|sounds good|yep|yes|k|👍|fine)\s*[.!]?\s*$'; then
  exit 0
fi

# --- Extract and sanitize the load-bearing phrase ---------------------
# Take the sentence/line containing the verdict as the phrase.
phrase="$(echo "$prompt" | grep -iE '.' | grep -miE 1 -E \
  '(confirmed[- ]defect|defect|no[- ]go|shipped[- ]under[- ]exception|override|\bgo\b)' || true)"
[ -n "$phrase" ] || phrase="$prompt"

# Trim to a reasonable length.
phrase="$(echo "$phrase" | cut -c1-300 | tr -d '\r')"

# Refuse to mint if the load-bearing wording looks sensitive: credentials,
# API keys/tokens, internal URLs, or other secret-shaped substrings.
if echo "$phrase" | grep -qiE '(api[_-]?key|secret|password|passwd|token=|bearer |authorization:|-----BEGIN |https?://[^ ]*@|https?://(localhost|127\.|10\.|192\.168\.|internal[.-]|intranet[.-]))'; then
  echo "qa-signoff: the wording carrying this verdict looks sensitive (credential/key/internal-URL shaped); minting no token. State the verdict again without that content." >&2
  exit 0
fi

transition="$phase -> $to"
token_file="$proj_dir/.verdict-token"

tmp="$(mktemp "${proj_dir}/.verdict-token.XXXXXX")"
{
  printf 'transition: %s\n' "$transition"
  printf 'project: %s\n' "$slug"
  # YAML single-quoted scalar; escape embedded single quotes by doubling.
  esc="${phrase//\'/\'\'}"
  printf "phrase: '%s'\n" "$esc"
} > "$tmp"
mv -f "$tmp" "$token_file"

exit 0
