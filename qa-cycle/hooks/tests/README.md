# `transition-gate.sh` execution check

`run-gate-tests.sh` runs the real `qa-cycle/hooks/transition-gate.sh` as a
subprocess, once per case, against a real temporary `QA_WORKSPACE` it builds
and tears down. It asserts on the observed exit code (and, where a refusal
is expected, that the gate's stderr message is non-empty) — never on the
gate's source text.

The gate is keyed on the item axis: `state.md` holds one record per
feedback item (see `docs/handbooks/qa-cycle.md` "The state file"), and
verdict tokens live under `tokens/<item-id>.token`, one file per item.

## Run it

```sh
qa-cycle/hooks/tests/run-gate-tests.sh
```

One command. It prints a line per case (`case: <name> | expected: <code> |
observed: <code> | ok|FAIL`), then a final tally, and exits non-zero if any
case's observed exit code differed from expected. Every temporary workspace
it creates is removed on exit, including on failure — nothing is left under
`/tmp`, and nothing is ever written into a real `~/qa-workspace` checkout.

## Cases covered

1. Valid table-permitted transition (agent actor) — expect allow.
2. Transition not permitted from the current item state — expect refuse.
3. Human-actor transition with no token — expect refuse.
4. Human-actor transition with a matching unconsumed token — expect allow;
   the live `.token` file is gone afterward, replaced by a `.consuming`
   marker (the reserve-not-delete consumption mechanism — see
   `docs/decisions/2026-07-31-token-consumption-ordering.md`).
5. The same transition retried against the still-unadvanced state.md — the
   `.consuming` marker from case 4 authorizes the retry — expect allow
   again, without a fresh human verdict.
6. Non-JSON stdin — expect refuse.
7. State file absent — expect refuse. (An absent `state.md` resolves the
   item to state `(none)`; the case attempts a transition not legal from
   `(none)`, so the refusal is the table lookup, not a special "file
   missing" path.)
8. State file with no frontmatter block — expect refuse.
9. A write whose body has no readable `item:`/`state:` block — expect
   refuse (tests the attempted-state parse, distinct from case 8's
   current-state parse).
10. `QA_WORKSPACE` unset — expect refuse.
11. `QA_CYCLE_DISABLE=1` — expect allow (the deliberate operator override).
12. A token minted for one item id is rejected when a different item
    attempts the identical `(from, to)` pair — expect refuse.
13. A token minted for one `(from, to)` pair on an item is rejected when
    that same item attempts a different transition — expect refuse.
14. An item in `handed-off` refuses a transition attempt with no human
    trigger present — expect refuse.
15. Consumption-timing (the defect recorded in
    `docs/reports/2026-07-29-hunt-gate-execution-check.md`): a
    hook-permitted human-actor write that never lands (`state.md` is
    deliberately left unadvanced after the first allow) is retried and
    still allowed without a fresh token; once the write actually lands, a
    *different* transition attempted on the same item with no fresh token
    is refused — proving the reserved marker does not leak into
    authorizing a second, different transition.

## What this does not cover

This is an execution check of observed exit codes for the cases above, not
a full equivalence-class sweep of the gate's Python. It does not cover
multi-item batch writes beyond refusing them (case not enumerated
separately from the "ambiguous write" refusal path the gate takes for any
write that changes more than one item's state at once). See
`docs/reports/2026-07-31-gate-enforcement.md` for the results this produced
and what they mean.
