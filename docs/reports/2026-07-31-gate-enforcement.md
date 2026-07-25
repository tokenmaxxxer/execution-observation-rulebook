---
proposal: docs/proposals/2026-07-31-item-axis-enforcement.md
---

# Gate enforcement — item-axis rewrite, harness run record

## What was run

```sh
qa-cycle/hooks/tests/run-gate-tests.sh
```

Run against the rewritten `qa-cycle/hooks/transition-gate.sh` (item-keyed
legality, item-and-transition-bound tokens, reserve-then-finalize
consumption) on branch `enforce/item-axis`, after the harness itself was
extended from 11 to 19 cases: the original 11 re-expressed on the item axis
(project-`phase` fixtures replaced with per-item `---item:`/`state:` blocks
and per-item `tokens/<item>.token` files), plus 8 new cases —
`human-actor-live-token-gone` / `human-actor-consuming-marker-present`
(the reserve step is observable on disk), the retry case
(`consuming-marker-authorizes-retry-of-same-transition`), item-scoped and
transition-scoped replay rejection (cases 12–13), `handed-off`-without-a-
human-trigger (case 14), and the three-step consumption-timing sequence
(case 15) that reproduces
`docs/reports/2026-07-29-hunt-gate-execution-check.md`'s finding end to
end: allow a human-actor write, leave `state.md` unadvanced to model the
write not landing, retry the identical transition and confirm it is still
allowed, then land the write and confirm a *different* subsequent
transition on the same item is refused without a fresh token.

## What came back

```
case: valid-table-permitted-transition | expected: 0 | observed: 0 | ok
case: transition-not-permitted-from-current-state | expected: 2 | observed: 2 | ok
case: human-actor-transition-no-token | expected: 2 | observed: 2 | ok
case: human-actor-transition-matching-token | expected: 0 | observed: 0 | ok
case: human-actor-live-token-gone | expected: absent | observed: absent | ok
case: human-actor-consuming-marker-present | expected: exists | observed: exists | ok
case: consuming-marker-authorizes-retry-of-same-transition | expected: 0 | observed: 0 | ok
case: non-json-stdin | expected: 2 | observed: 2 | ok
case: state-file-absent | expected: 2 | observed: 2 | ok
case: state-file-no-frontmatter | expected: 2 | observed: 2 | ok
case: no-item-block-in-write-body | expected: 2 | observed: 2 | ok
case: qa-workspace-unset | expected: 2 | observed: 2 | ok
case: qa-cycle-disable-override | expected: 0 | observed: 0 | ok
case: token-for-one-item-rejected-for-another | expected: 2 | observed: 2 | ok
case: token-for-one-transition-rejected-for-another | expected: 2 | observed: 2 | ok
case: handed-off-refuses-without-human-token | expected: 2 | observed: 2 | ok
case: consumption-timing-first-allow-write-does-not-land | expected: 0 | observed: 0 | ok
case: consumption-timing-retry-still-allowed | expected: 0 | observed: 0 | ok
case: consumption-timing-marker-does-not-authorize-a-different-transition | expected: 2 | observed: 2 | ok

=== tally: 19 passed, 0 failed (of 19 cases) ===
```

Harness process exit code: `0` (all 19 cases passed on the first run; no
fix-and-rerun cycle was needed for the harness itself — the case-15 sequence
matched the reserve-then-finalize design in
`docs/decisions/2026-07-31-token-consumption-ordering.md` on the first
implementation).

## Observed exit codes, gate script directly

Spot-checked outside the harness by replaying
`docs/reports/2026-07-29-hunt-gate-execution-check.md`'s reproduction
against the rewritten gate (item-axis fixtures substituted for the old
project-`phase` ones): first allow call exits `0` and moves the token to
`tokens/BUG-1.consuming` without touching `state.md`; the immediate retry
against the still-`reproduced` item also exits `0` (previously this
retry exited `2`, the defect); a subsequent different transition attempted
on the same item after the marker's authorized write actually lands exits
`2`, confirming the marker does not outlive the transition it authorized.
