#!/usr/bin/env bash
# SessionStart hook: one line of QA profile status, nothing else.
# Kill switch: export QA_INTAKE_OFF=1

# Off means off: only explicit truthy-ish values disable the hook; "0",
# "false", "no", "off" and empty all mean "not off" (lesson inherited from
# the coding stack's kill-switch bug).
case "${QA_INTAKE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

ws="${QA_WORKSPACE:-$HOME/qa-workspace}"
# <owner>-<repo> so acme/api and beta/api don't collide in projects/
slug=$(git remote get-url origin 2>/dev/null | sed -e 's#\.git/*$##' -e 's#/*$##' -e 's#.*[:/]\([^/]*\)/\([^/]*\)$#\1-\2#')
[ -n "$slug" ] || slug=$(basename "$PWD")
profile="$ws/projects/$slug/intake.md"

if [ -f "$profile" ]; then
  repo=$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$profile" | head -1)
  echo "qa-intake: profile $profile found${repo:+ (issues -> $repo)}."
else
  echo "qa-intake: no profile at $profile. QA plugins fall back to ad-hoc discovery; run /qa-init once to fix the issue tracker, templates, labels, and app launch method for every session."
fi
exit 0
