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

# root resolution: CLAUDE_PROJECT_DIR when set, otherwise cwd's git
# top-level — same rule as qa-cycle's gate. No external workspace, no env
# var: this hook only ever looks inside the target repo it is installed
# into.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  repo_root="${CLAUDE_PROJECT_DIR%/}"
elif command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
  repo_root="$(git rev-parse --show-toplevel)"
else
  repo_root="$PWD"
fi
records_root="$repo_root/docs/reports/records"

found=0
if [ -d "$records_root" ]; then
  for profile in "$records_root"/*/qa/intake.md; do
    [ -f "$profile" ] || continue
    found=1
    repo=$(sed -n 's/^[[:space:]]*repo:[[:space:]]*//p' "$profile" | head -1)
    echo "qa-intake: profile $profile found${repo:+ (issues -> $repo)}."
  done
fi

if [ "$found" -eq 0 ]; then
  echo "qa-intake: no profile at docs/reports/records/<subject>/qa/intake.md. QA plugins fall back to ad-hoc discovery; run /qa-init once to fix the issue tracker, templates, labels, and app launch method for every session."
fi
exit 0
