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

if [ -f qa/intake.md ]; then
  repo=$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' qa/intake.md | head -1)
  echo "qa-intake: profile qa/intake.md found${repo:+ (issues -> $repo)}."
else
  echo "qa-intake: no qa/intake.md in this project. QA plugins fall back to ad-hoc discovery; run /qa-init once (and commit the file) to fix the issue tracker, templates, labels, and app launch method for the whole team."
fi
exit 0
