#!/usr/bin/env bash
# UserPromptSubmit hook: mints a single-use verdict token from an
# unambiguous human verdict found in the user's own turn — never from a
# file, issue, PR, comment, or tool result.
# Kill switch: export QA_SIGNOFF_DISABLE=1
#
# This hook never blocks. Malformed/unreadable input, no workspace, no
# project state, no identifiable item, or an ambiguous/absent verdict all
# mean: emit nothing, exit 0.
#
# state.md now holds one record per feedback item, not a single project
# `phase` (docs/handbooks/qa-cycle.md "The state file"). A verdict must
# therefore name which item it concerns; this hook requires the prompt to
# mention the item id explicitly (`item <id>`) so the token it mints can
# bind to both that item id and the exact (from, to) pair, per
# docs/specs/qa-cycle-state-machine.md "Human decision points".
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
ws="$(cd "$ws" 2>/dev/null && pwd -P)" || exit 0

command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

# Must be well-formed JSON with a non-empty string prompt field.
echo "$payload" | jq -e '.' >/dev/null 2>&1 || exit 0
prompt="$(echo "$payload" | jq -r '.prompt // empty' 2>/dev/null || true)"
[ -n "$prompt" ] || exit 0

slug=$(git remote get-url origin 2>/dev/null | sed -e 's#\.git/*$##' -e 's#/*$##' -e 's#.*[:/]\([^/]*\)/\([^/]*\)$#\1-\2#' || true)
[ -n "$slug" ] || slug=$(basename "$PWD")

# The project identifier is validated at the point it is read, by
# allow-list, before it is used in any path: ASCII letters, digits,
# hyphen, underscore only, length 1..128, never starting with a hyphen.
# Reject by pattern, never by stripping/sanitizing a bad value.
case "$slug" in
  -*) exit 0 ;;
esac
printf '%s' "$slug" | grep -qE '^[A-Za-z0-9_-]{1,128}$' || exit 0

proj_dir="$ws/projects/$slug"
# Independently of the allow-list above: resolve the path built from the
# project identifier to a real path, then containment-check it against the
# workspace root — resolve first, then check; a check before resolution
# proves nothing. (The directory must already exist for this hook to have
# anything to do, so resolving it here is safe.)
proj_dir_real="$(cd "$proj_dir" 2>/dev/null && pwd -P)" || exit 0
case "$proj_dir_real" in
  "$ws") ;;
  "$ws"/*) ;;
  *) exit 0 ;;
esac
proj_dir="$proj_dir_real"
state_file="$proj_dir/state.md"
[ -f "$state_file" ] || exit 0

# --- identify the item this turn concerns ------------------------------
# Required, explicit form: "item <id>" (case-insensitive). No item id, no
# mint — this hook never guesses which item a bare "confirmed defect"
# refers to.
raw_item="$(echo "$prompt" | grep -ioE '\bitem[[:space:]]+[A-Za-z0-9_-]+' | head -1 | sed -E 's/^[Ii][Tt][Ee][Mm][[:space:]]+//' || true)"
[ -n "$raw_item" ] || exit 0

# The item id is validated at the point it is read, by allow-list, before
# it is used in any path or any comparison — the same discipline as
# transition-gate.sh applies when it reads item ids out of state.md: ASCII
# letters, digits, hyphen, underscore only, length 1..64, never starting
# with a hyphen. Reject by pattern; never try to sanitize a bad value.
# This is what stops a forged "item ../../../../tmp/evil-item" turn from
# ever producing a token file outside tokens/.
case "$raw_item" in
  -*) exit 0 ;;
esac
printf '%s' "$raw_item" | grep -qE '^[A-Za-z0-9_-]{1,64}$' || exit 0
item_id="$raw_item"

# Current state of that item, read the same way the gate reads it: the
# single `state:` key inside the one block whose `item:` key matches.
phase="$(python3 - "$state_file" "$item_id" <<'PY' 2>/dev/null || true
import re, sys
path, item_id = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8-sig") as fh:
        text = fh.read(1 << 20)
except OSError:
    sys.exit(0)
BLOCK_RE = re.compile(r"^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*\r?\n?", re.M | re.S)
ITEM_KEY = re.compile(r"^item:\s*(.*?)\s*(?:#.*)?$", re.M)
STATE_KEY = re.compile(r"^state:\s*(.*?)\s*(?:#.*)?$", re.M)
matches = []
for m in BLOCK_RE.finditer(text):
    block = m.group(1)
    items = ITEM_KEY.findall(block)
    states = STATE_KEY.findall(block)
    if len(items) == 1 and items[0].strip() == item_id:
        if len(states) == 1 and states[0].strip():
            matches.append(states[0].strip())
        else:
            matches.append(None)
if len(matches) == 1 and matches[0]:
    print(matches[0])
PY
)"
[ -n "$phase" ] || exit 0

# --- Unambiguous verdict detection -----------------------------------
# A verdict must (a) name the target transition's destination state in
# recognizable, unambiguous wording, and (b) not be a bare "ok"/"sounds
# good"/thumbs-up style assent. We require an explicit verdict keyword
# tied to explicit reasoning/scope words, not just the bare word.

# Only an ASSERTED sentence can carry a verdict. A question is not a verdict
# and neither is a hedge, but the greps below match a keyword anywhere in the
# prompt, so both used to mint one. Measured 2026-07-27:
#
#   "Is item 42 a confirmed defect? I am not sure yet, do not do anything."
#     -> minted transition: reproduced -> handed-off
#
# Interrogative and hedging sentences are dropped before matching. `speech`
# replaces `$prompt` in every detection grep below, the priority one included.
SPEECH_PY='
import re, sys
text = sys.stdin.read()
DROP = re.compile(
    u"(?i)\\b(not sure|unsure|unclear|no idea|maybe|might be|may be|i think|"
    u"i wonder|could be|should we|shall we|do you|did anyone|has anyone)\\b"
    u"|\\?\\s*$"
    u"|확실치|확실하지|모르겠|인가요|일까요|아닌가")
keep = [s for s in re.split(u"(?<=[.!?\\n])\\s+", text)
        if s.strip() and not DROP.search(s.strip())]
sys.stdout.write(u"\n".join(keep))
'
speech="$(printf '%s' "$prompt" | python3 -c "$SPEECH_PY" 2>/dev/null || printf '%s' "$prompt")"

to=""
case "$phase" in
  reproduced)
    # The NEGATIVE readings are tested FIRST, and their pattern now covers the
    # qualified forms. `confirmed[- ]defect` is a substring of "not a confirmed
    # defect", so with the affirmative branch first a human saying the opposite
    # of a defect verdict minted the defect verdict -- and the refusal was
    # written into the token's own `phrase:` field as its evidence. Measured
    # 2026-07-27:
    #
    #   "item 42 - to be clear, this is NOT a confirmed defect. Leave it alone."
    #     -> minted transition: reproduced -> handed-off
    #
    # Read correctly, that sentence IS a verdict -- `not-a-defect` -- which is
    # what it mints now.
    if echo "$speech" | grep -qiE '\b(not (a |an )?(real |genuine |confirmed |actual )?(defect|bug)|declin(e|ing) to call (this|it) a defect|no defect here)\b'; then
      to="not-a-defect"
    elif echo "$speech" | grep -qiE "\b(won'?t[- ]fix|wont[- ]fix|accept(ing)? (this |it )?as a defect but (not|declin\w*) fix)\b"; then
      to="wont-fix"
    elif echo "$speech" | grep -qiE '\b(confirmed[- ]defect|confirm(ing)? (this|it) (as )?a defect|this is (a real|a genuine|a) defect|ruling this a defect|hand(ing)? (this|it) (off|over))\b'; then
      to="handed-off"
    fi
    ;;
  handed-off)
    if echo "$speech" | grep -qiE '\b(fix (has )?landed|the fix is in|fix (is )?merged|re-?verify|re-?run the (reproduction|repro))\b'; then
      to="re-verifying"
    fi
    ;;
esac

# --- priority verdict detection ----------------------------------------
# priority is human-set (docs/specs/qa-cycle-state-machine.md "Severity and
# priority") and is NOT a state transition, so it is checked independently
# of the `to`/`phase` state-transition machinery above — a priority verdict
# can be given regardless of the item's current state. Required, explicit
# form tied to the item already identified above: an explicit `priority`
# keyword followed by one of the closed-set values. No bare value alone
# (e.g. a stray "now" in unrelated prose) ever counts.
priority_value=""
if echo "$speech" | grep -qiE '\bitem[[:space:]]+'"$item_id"'\b'; then
  priority_value="$(echo "$speech" | grep -ioE 'priority[[:space:]:]+(now|next|later|someday)\b' | tail -1 | grep -ioE '(now|next|later|someday)$' | tr 'A-Z' 'a-z' || true)"
fi

if [ -z "$to" ] && [ -z "$priority_value" ]; then
  exit 0
fi

# Reject vague assent even when a keyword coincidentally appears standalone.
if echo "$prompt" | grep -qiE '^\s*(ok|okay|sure|sounds good|yep|yes|k|👍|fine)\s*[.!]?\s*$'; then
  exit 0
fi

tokens_dir="$proj_dir/tokens"
mkdir -p "$tokens_dir"

# Belt-and-braces on top of the item id allow-list above: resolve the
# tokens directory to a real path before writing anything under it.
tokens_dir_real="$(cd "$tokens_dir" 2>/dev/null && pwd -P)" || exit 0
case "$tokens_dir_real" in
  "$proj_dir_real"/tokens) ;;
  *) exit 0 ;;
esac

mint_token() {
  # mint_token <file-suffix-glob-ok> <extra-yaml-lines...>
  # Extracts and sanitizes the load-bearing phrase, refuses to mint on
  # anything credential/secret/internal-URL shaped, then writes the token
  # file atomically. Shared by both the state-transition token and the
  # priority verdict token — the same scan runs before either is minted.
  local token_file="$1"
  shift
  local phrase
  phrase="$(echo "$prompt" | grep -iE '.' | grep -m1 -iE \
    '(confirmed[- ]defect|defect|not a bug|won.?t.?fix|hand(ing)? (this|it) (off|over)|fix (has )?landed|re-?verify|priority)' || true)"
  [ -n "$phrase" ] || phrase="$prompt"
  phrase="$(echo "$phrase" | cut -c1-300 | tr -d '\r')"

  if echo "$phrase" | grep -qiE '(api[_-]?key|secret|password|passwd|token=|bearer |authorization:|-----BEGIN |https?://[^ ]*@|https?://(localhost|127\.|10\.|192\.168\.|internal[.-]|intranet[.-]))'; then
    echo "qa-signoff: the wording carrying this verdict looks sensitive (credential/key/internal-URL shaped); minting no token. State the verdict again without that content." >&2
    return 1
  fi

  case "$token_file" in
    "$tokens_dir_real"/*) ;;
    *) return 1 ;;
  esac

  local tmp
  tmp="$(mktemp "${tokens_dir}/.token.XXXXXX")"
  {
    for line in "$@"; do
      printf '%s\n' "$line"
    done
    esc="${phrase//\'/\'\'}"
    printf "phrase: '%s'\n" "$esc"
  } > "$tmp"
  mv -f "$tmp" "$token_file"
  return 0
}

# --- mint the state-transition token, if a transition verdict was found -
if [ -n "$to" ]; then
  transition="$phase -> $to"
  token_file="$tokens_dir/${item_id}.token"
  case "$token_file" in
    "$tokens_dir_real"/*.token) ;;
    *) token_file="" ;;
  esac
  if [ -n "$token_file" ]; then
    mint_token "$token_file" \
      "item: $item_id" \
      "transition: $transition" || true
  fi
fi

# --- mint the priority verdict token, if a priority verdict was found ---
# Bound to (item id, field name, new value), stored at a path distinct
# from the state-transition token so the two never collide or get
# consumed by each other's check.
if [ -n "$priority_value" ]; then
  priority_token_file="$tokens_dir/${item_id}.priority.token"
  case "$priority_token_file" in
    "$tokens_dir_real"/*.priority.token) ;;
    *) priority_token_file="" ;;
  esac
  if [ -n "$priority_token_file" ]; then
    mint_token "$priority_token_file" \
      "item: $item_id" \
      "field: priority" \
      "value: $priority_value" || true
  fi
fi

exit 0
