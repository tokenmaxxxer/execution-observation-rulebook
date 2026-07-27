# `transition-gate.sh` execution check

`run-gate-tests.sh` runs the real `qa-cycle/hooks/transition-gate.sh` as a
subprocess, once per case, against real fixture files it builds and tears
down under this repo's own `docs/reports/records/<subject>/qa/` tree (the
gate has no external workspace concept anymore — see
`docs/proposals/2026-07-27-qa-records-in-target-repo.md`). It asserts on
the observed exit code (and, where a refusal is expected, that the gate's
stderr message is non-empty) — never on the gate's source text.

The gate is keyed on the item axis: `state.md` holds one record per
feedback item (see `docs/handbooks/qa-cycle.md` "The state file"), and
verdict tokens live under `tokens/<item-id>.token`, one file per item.

## Run it

```sh
qa-cycle/hooks/tests/run-gate-tests.sh
```

One command. It prints a line per case (`case: <name> | expected: <code> |
observed: <code> | ok|FAIL`), then a final tally, and exits non-zero if any
case's observed exit code differed from expected. Every subject directory
it creates under `docs/reports/records/` (named `gate-test-*`) is removed
on exit, including on failure — nothing is left in this repo's own working
tree.

Each case runs with `QA_CYCLE_DISABLE` cleared from the inherited
environment and re-added only if the case declares it, so a case testing
the kill switch really controls it — `env` passes the caller's environment
through otherwise.

## Interpreters

The case runner works on bash 3.2 — macOS's `/bin/bash`, the last GPLv2
release — as well as on 4.x/5.x.

`directive-drift-check.sh` does not: it needs associative arrays, so it
needs bash 4+. Under 3.2 it names the missing interpreter and exits **3**,
distinct from the 1 it uses for drift found. `run-gate-tests.sh` reports
that as `DID NOT RUN` and does not count it as a failure — a permanently
red tally on macOS would bury the case results that are real. **Did not run
is not passed**: on a machine without bash 4+, the drift check has told you
nothing.

## Cases covered

The numbered list below is the original set and has not been extended as
cases were added; the runner currently executes 86. Its tally line is the
authority on the count, not this list.

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
10. A state.md-shaped write entirely outside
    `docs/reports/records/<subject>/qa/` — expect allow (not this gate's
    business; there is no external workspace fallback anymore).
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
16. Path-traversing item id — the exact reproduction recorded in
    `docs/reports/2026-07-31-hunt-item-axis-enforcement.md`: an item id of
    `../../../../../../../../tmp/evil-item` with a forged "token" planted
    at the resulting attacker-chosen path outside `tokens/` — expect
    refuse. The item id allow-list rejects the value before it is ever
    used to build `token_path`, so the forged file is never opened.
17. Item id with a leading hyphen — outside the allow-list (may not begin
    with a hyphen) — expect refuse.
18. Item id containing a character outside the allow-list (a slash) —
    expect refuse.
19. Over-length item id (65 characters, one past the 64-character limit)
    — expect refuse.
20. Project identifier containing a character outside the allow-list (a
    semicolon), in a slug that is itself a real, single path component
    under `projects/` so it passes the earlier workspace-realpath
    containment check — expect refuse. (A literal `..` traversal in the
    project segment of `file_path` is caught earlier still, by the
    existing workspace-containment check on the resolved real path, before
    a project slug is ever extracted — this case tests the
    defense-in-depth allow-list on top of that.)

## What this does not cover

This is an execution check of observed exit codes for the cases above, not
a full equivalence-class sweep of the gate's Python. It does not cover
multi-item batch writes beyond refusing them (case not enumerated
separately from the "ambiguous write" refusal path the gate takes for any
write that changes more than one item's state at once). See
`docs/reports/2026-07-31-gate-enforcement.md` for the results this produced
and what they mean.

## `directive-drift-check.sh`

A separate script, run as the final step of `run-gate-tests.sh` (and
runnable standalone), that checks a different thing than the exit-code cases
above: not the gate's observed exit codes, but whether the seven
`*/hooks/directive.sh` files' prose still matches what the gate enforces.

It runs `transition-gate.sh --dump-facts` (a read-only flag that prints the
gate's own `TABLE`/`FIELDS` structures as JSON — the same structures its
decision logic branches on, not a second description of them), extracts
`gate-covers` and `gate-claim` HTML-comment markers from each directive by
plain grep, and compares:

1. Every `gate-claim` against `--dump-facts` — a claimed subject the gate
   doesn't have, or a claimed actor/`requires` that doesn't match, is a
   hard failure naming the file and the mismatch.
2. Every subject a directive's own `gate-covers` line declares must have a
   matching `gate-claim` in that same file — a declared-but-unclaimed
   subject is a hard failure.
3. Every transition/field the gate enforces that no directive's
   `gate-covers` mentions at all — printed as an informational line, never
   a failure. Run today, this lists exactly four rows no directive
   currently claims responsibility for: the bootstrap `(none)->observed`
   row, `parked-unreproducible->observed`, and both `re-verifying` rows.

A marker that doesn't parse (malformed `gate-claim`/`gate-covers` shape) is
also a hard failure — never silently skipped, same refuse-by-default
reasoning the gate itself uses.

Run it standalone:

```sh
qa-cycle/hooks/tests/directive-drift-check.sh
```

See `docs/proposals/2026-08-04-directive-drift-check.md` for the design
and what this check deliberately cannot catch (a directive quietly
dropping a `gate-covers` declaration it used to make; whether a
directive's prose is good advice).
