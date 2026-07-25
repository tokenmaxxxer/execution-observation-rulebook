#!/usr/bin/env bash
# SessionStart hook: reports the current phase of any project in flight
# under QA_WORKSPACE. Silent when there is none — this only surfaces state
# that already exists, it never creates any.
#
# Kill switch: export QA_CYCLE_DISABLE=1
set -euo pipefail

case "${QA_CYCLE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

ws="${QA_WORKSPACE:-}"
[ -n "$ws" ] || exit 0
[ -d "$ws/projects" ] || exit 0

found=0
for dir in "$ws"/projects/*/; do
  [ -d "$dir" ] || continue
  slug="$(basename "$dir")"
  state="$dir/state.md"
  [ -f "$state" ] || continue
  phase="$(sed -n 's/^phase:[[:space:]]*//p' "$state" | head -1 | sed 's/[[:space:]]*#.*$//')"
  [ -n "$phase" ] || continue
  if [ "$found" -eq 0 ]; then
    echo "qa-cycle: projects in flight —"
    found=1
  fi
  echo "  $slug: $phase (state: $state)"
done

exit 0
