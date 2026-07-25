#!/usr/bin/env bash
# SessionStart hook: reports feedback items in flight under QA_WORKSPACE,
# grouped by their current per-item state. Silent when there is none — this
# only surfaces state that already exists, it never creates any.
#
# state.md holds one record per feedback item (docs/handbooks/qa-cycle.md
# "The state file"), not a single project-wide `phase`; this hook reads
# every item block and groups by state, per project.
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

command -v python3 >/dev/null 2>&1 || exit 0

found=0
for dir in "$ws"/projects/*/; do
  [ -d "$dir" ] || continue
  slug="$(basename "$dir")"
  state="$dir/state.md"
  [ -f "$state" ] || continue

  report="$(python3 - "$state" <<'PY'
import re, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8-sig") as fh:
        text = fh.read(1 << 20)
except OSError:
    sys.exit(0)

BLOCK_RE = re.compile(r"^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*\r?\n?", re.M | re.S)
ITEM_KEY = re.compile(r"^item:\s*(.*?)\s*(?:#.*)?$", re.M)
STATE_KEY = re.compile(r"^state:\s*(.*?)\s*(?:#.*)?$", re.M)

by_state = {}
for m in BLOCK_RE.finditer(text):
    block = m.group(1)
    items = ITEM_KEY.findall(block)
    states = STATE_KEY.findall(block)
    if len(items) != 1 or len(states) != 1:
        continue
    item_id = items[0].strip()
    state = states[0].strip()
    if not item_id or not state:
        continue
    by_state.setdefault(state, []).append(item_id)

for state in sorted(by_state):
    ids = ", ".join(sorted(by_state[state]))
    print("%s: %s" % (state, ids))
PY
)"
  [ -n "$report" ] || continue

  if [ "$found" -eq 0 ]; then
    echo "qa-cycle: projects in flight —"
    found=1
  fi
  echo "  $slug (state: $state):"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    echo "    $line"
  done <<< "$report"
done

exit 0
