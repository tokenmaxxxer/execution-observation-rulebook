# `transition-gate.sh` execution check

`run-gate-tests.sh` runs the real `qa-cycle/hooks/transition-gate.sh` as a
subprocess, once per case, against a real temporary `QA_WORKSPACE` it builds
and tears down. It asserts on the observed exit code (and, where a refusal
is expected, that the gate's stderr message is non-empty) — never on the
gate's source text.

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
2. Transition not permitted from the current phase — expect refuse.
3. Human-actor transition with no token — expect refuse.
4. Human-actor transition with a matching unconsumed token — expect allow,
   and the token file is gone afterward.
5. The same token replayed — expect refuse.
6. Non-JSON stdin — expect refuse.
7. State file absent — expect refuse. (Absent `state.md` resolves to phase
   `(none)`; the case attempts a transition not legal from `(none)` so the
   refusal is the table lookup, not a special "file missing" path.)
8. State file with no frontmatter block — expect refuse.
9. A `phase:` line in the write's body with no frontmatter block — expect
   refuse (tests the attempted-phase parse, distinct from case 8's
   current-phase parse).
10. `QA_WORKSPACE` unset — expect refuse.
11. `QA_CYCLE_DISABLE=1` — expect allow (the deliberate operator override).

## What this does not cover

This is an execution check of observed exit codes for the cases above, not
a full equivalence-class sweep of the gate's Python. See
`docs/reports/2026-07-29-gate-execution.md` for the results this produced
and what they mean.
