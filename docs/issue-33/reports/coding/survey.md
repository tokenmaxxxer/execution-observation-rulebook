# issue-33 current-state survey (coding, phase 1)

## Scope of the grep
`grep -rliE "wakes|WAKES-ON" .` (excluding `.git`) across the whole repo,
which hosts one live rulebook plugin (`qa/`) plus generic `docs/`. Hits:

- `qa/hooks/directive.sh` — live rulebook (SessionStart directive for the
  `qa` role). In scope.
- `docs/proposals/2026-07-27-repo-local-contract-file.md` — dated,
  already-merged proposal record. Historical decision record, not live
  rulebook; out of scope (rewriting a dated proposal falsifies history).
- `docs/proposals/2026-07-26-contract-v2-conformance.md` — same: dated,
  historical proposal describing contract-v2→v3 migration reasoning
  (includes worked WAKES-ON examples as illustration of past state). Out
  of scope for the same reason.

No `coding`-specific rulebook file exists in this repo (only the `qa`
plugin is defined here; `find -iname '*coding*'` returns nothing). This
session's `[coding]` role directive is supplied by tooling outside this
repo's tree, so there is no coding rulebook file to edit here.

## The one write-set candidate: `qa/hooks/directive.sh`

Single WAKES-ON mention, lines 58-65:

```
YOUR RECORD IS THE BOARD (do not skip this): WAKES-ON reads
docs/issue-<n>/reports/qa.md ONLY — research files, surveys, and
proposals wake no one. The record is execution-surface material, so:
write it as your FIRST act of phase 2, and update its loop_state at
every transition. Ending phase 2 without your record committed on the
branch means the board never saw your work and no downstream role can
ever be woken by it. (Measured: a phase-1-only issue left the board
empty and machine wake-up dead.)
```

This paragraph mixes two things:
1. **This role's own record state/format** — record is the sole
   phase-2 artifact that matters, write it first, keep loop_state
   current. Keep.
2. **A routing restatement** — "WAKES-ON reads
   docs/issue-<n>/reports/qa.md ONLY" and "no downstream role can ever
   be woken by it" name which file/role is summoned. Per issue-33 (wake-
   routing ownership migration step 3), routing canon now lives at
   on-the-record `docs/specs/wake-routing.md`; this rulebook must carry
   nothing that states which role a state summons. Strip/repoint.

No other file in `qa/` (`README.md`, `commands/`) contains "wakes" or
"WAKES-ON" per the same grep.

## Write set for phase 2

- `qa/hooks/directive.sh` — reword the WAKES-ON paragraph to keep the
  role's own record-first / loop_state obligation, drop the "reads
  ...ONLY" / "downstream role woken" routing claims, and repoint routing
  authority to the on-the-record `docs/specs/wake-routing.md` doc by
  name (no other role name stated).

No other files change. No tests, deps, or env vars are touched (this is
a prose-only rulebook edit inside a heredoc `cat <<'DIRECTIVE'` block —
`tests/parse-check.sh` and `tests/deny-only-check.sh` should still be run
in phase 2 as a sanity check that the heredoc still parses).
