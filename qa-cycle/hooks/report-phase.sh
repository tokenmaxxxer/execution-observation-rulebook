#!/usr/bin/env bash
# SessionStart hook: reports feedback items in flight under QA_WORKSPACE.
# Silent when there is none — this only surfaces state that already
# exists, it never creates any.
#
# state.md holds one record per feedback item (docs/handbooks/qa-cycle.md
# "The state file"), not a single project-wide `phase`; this hook reads
# every item block, per project.
#
# Per docs/proposals/2026-08-02-severity-priority-axes.md, the report is
# grouped so a human opening a session can tell what to look at first:
# priority is the primary ordering (now, next, later, someday, in that
# order), severity orders items within a priority group (critical, major,
# minor, trivial, in that order), and items carrying no priority at all —
# which is a legal, unlocked state per the spec — are surfaced in their own
# leading group rather than hidden or silently dropped from the report.
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

# The parser below is read into a variable by a heredoc at TOP LEVEL, then
# passed to `python3 -c`, rather than being written as
# `report="$(python3 - "$state" <<'PY' … PY)"`. Under bash 3.2 — the
# /bin/bash every macOS ships — a quoted-delimiter heredoc nested inside
# `$( … )` is NOT treated as literal while the closing paren is scanned for:
# the parser still tracks quotes and parentheses inside the body. The single
# apostrophe in "the spec's ... rule" in the body below was enough to make
# this whole file fail to parse, so this SessionStart hook never ran at all and
# every in-flight item stayed unreported — a silence indistinguishable from
# "there is nothing in flight". `bash -n` catches a regression;
# hooks/tests/parse-check.sh runs it.
IFS='' read -r -d '' PY_SRC <<'PY' || true
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
SEVERITY_KEY = re.compile(r"^severity:\s*(.*?)\s*(?:#.*)?$", re.M)
PRIORITY_KEY = re.compile(r"^priority:\s*(.*?)\s*(?:#.*)?$", re.M)

# Ordering: priority is the primary axis, severity secondary within it.
# "no priority" gets its own leading group rather than being hidden — an
# item without a priority is still surfaced, per the spec's "priority is
# NOT required" rule.
PRIORITY_ORDER = ["now", "next", "later", "someday"]
NO_PRIORITY = "(no priority)"
SEVERITY_ORDER = ["critical", "major", "minor", "trivial"]
NO_SEVERITY = "(no severity)"


def rank(value, order, fallback_label):
    if value in order:
        return (0, order.index(value), value)
    # Unset, empty, or malformed (e.g. two conflicting lines) — surfaced,
    # never dropped, but sorted after every valid closed-set value.
    return (1, 0, fallback_label)


items = []
for m in BLOCK_RE.finditer(text):
    block = m.group(1)
    ids = ITEM_KEY.findall(block)
    states = STATE_KEY.findall(block)
    if len(ids) != 1 or len(states) != 1:
        continue
    item_id = ids[0].strip()
    state = states[0].strip()
    if not item_id or not state:
        continue

    severities = SEVERITY_KEY.findall(block)
    severity = severities[0].strip() if len(severities) == 1 and severities[0].strip() else ""
    priorities = PRIORITY_KEY.findall(block)
    priority = priorities[0].strip() if len(priorities) == 1 and priorities[0].strip() else ""

    items.append((item_id, state, severity, priority))

items.sort(key=lambda t: (
    rank(t[3], PRIORITY_ORDER, NO_PRIORITY),
    rank(t[2], SEVERITY_ORDER, NO_SEVERITY),
    t[0],
))

by_group = {}
group_order = []
for item_id, state, severity, priority in items:
    priority_label = priority if priority in PRIORITY_ORDER else NO_PRIORITY
    severity_label = severity if severity in SEVERITY_ORDER else NO_SEVERITY
    group = "priority: %s / severity: %s" % (priority_label, severity_label)
    if group not in by_group:
        by_group[group] = []
        group_order.append(group)
    by_group[group].append("%s (state: %s)" % (item_id, state))

for group in group_order:
    print("%s: %s" % (group, ", ".join(by_group[group])))
PY

found=0
for dir in "$ws"/projects/*/; do
  [ -d "$dir" ] || continue
  slug="$(basename "$dir")"
  state="$dir/state.md"
  [ -f "$state" ] || continue

  report="$(python3 -c "$PY_SRC" "$state")"
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
