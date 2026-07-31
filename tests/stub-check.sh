#!/usr/bin/env bash
# Drift-recurrence detector (issue-66 item 4).
#
# The four role-agnostic gates (trailer-gate.sh, record-fields-gate.sh,
# handbook-trigger-gate.sh) plus parse-check.sh are now registered as core
# canon hooks (core/hooks/hooks.json fires them for every plugin install —
# issue-66's approver decision). A rulebook no longer needs its OWN copy of
# any of these four files or its own hooks.json entry for them at all: core
# already fires them globally. Once a rulebook's vendored copy is removed
# (the per-rulebook follow-up issue-66 tracks but does not execute), the
# presence of any of these filenames back under a rulebook's own hooks/ tree
# is itself the drift signal — a locally-reintroduced copy is exactly the
# shape that produced today's 38/40-unique-hash drift (issue-66 survey).
#
# directive.sh is different: every role still needs its own small file (the
# four role-unique values), so its check is structural, not
# absence-based — it must be the "source core/hooks/lib/role-directive.sh,
# set four values, call core_role_directive" form, nothing else. A stub
# that has grown a local copy of the boilerplate this promotion factored out
# (the trap/kill-switch/guard/opening-closing lines) fails this check.
#
# Distributed to every rulebook the way parse-check.sh already is (per
# parse-check.sh's own header) — dropped alongside it and run from the same
# harness. Every rulebook copies this file verbatim and runs it over its own
# hooks/ tree.
#
# Usage: stub-check.sh [hooks-dir]
set -uo pipefail

dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)}"
[ -d "$dir" ] || { echo "stub-check: no such directory: $dir" >&2; exit 2; }
rc=0

CANON_GATES="trailer-gate.sh record-fields-gate.sh handbook-trigger-gate.sh parse-check.sh"

for name in $CANON_GATES; do
  # -mindepth 1 -maxdepth 3: a rulebook's own hooks/ (depth 1) or hooks/tests/
  # (depth 2, where parse-check.sh's rulebook copy lives today) — not core's
  # own repo tree, which this script is never run against directly (core is
  # canon by definition and is excluded by callers pointing $dir at a
  # rulebook's plugin root, not at this repo).
  hits="$(find "$dir" -maxdepth 3 -name "$name" -type f 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    echo "stub-check: FAIL — vendored copy of core canon file '$name' found:" >&2
    printf '%s\n' "$hits" >&2
    echo "  This file is now a core hook (core/hooks/hooks.json), fired for" >&2
    echo "  every plugin install. A local copy is drift, not a stub — delete" >&2
    echo "  it and drop the file's own hooks.json entry, if any (issue-66)." >&2
    rc=1
  else
    echo "stub-check: ok — no vendored '$name' under $dir"
  fi
done

# --- directive.sh: structural check, not absence-based ---------------------
directive_hits="$(find "$dir" -maxdepth 3 -name 'directive.sh' -type f 2>/dev/null || true)"
if [ -z "$directive_hits" ]; then
  echo "stub-check: ok — no directive.sh under $dir (nothing to check)"
else
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    fail_reason=""
    grep -qE 'role-directive\.sh["'"'"']?[[:space:]]*$|role-directive\.sh"' "$f" \
      || fail_reason="does not source core/hooks/lib/role-directive.sh"
    if [ -z "$fail_reason" ]; then
      grep -q 'core_role_directive' "$f" \
        || fail_reason="never calls core_role_directive"
    fi
    if [ -z "$fail_reason" ]; then
      # Structural cap: every non-blank/non-comment/non-shebang line in a
      # real stub is either the source line, a plain variable assignment,
      # or the one core_role_directive call. Anything else (a case
      # statement, a guard test, a raw echo/cat, control flow) is exactly
      # the boilerplate this promotion factored out regrowing locally.
      other="$(grep -vE '^[[:space:]]*(#.*)?$|^#!|role-directive\.sh|core_role_directive|^[A-Za-z_][A-Za-z0-9_]*=' "$f" 2>/dev/null || true)"
      if [ -n "$other" ]; then
        fail_reason="has non-stub line(s), looks like regrown boilerplate: $(printf '%s' "$other" | head -1)"
      fi
    fi
    if [ -n "$fail_reason" ]; then
      echo "stub-check: FAIL — $f: $fail_reason" >&2
      rc=1
    else
      echo "stub-check: ok — $f is a role-directive stub"
    fi
  done <<< "$directive_hits"
fi

exit "$rc"
