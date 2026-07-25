---
date: 2026-07-25
proposal: docs/proposals/2026-07-29-gate-execution-check.md
issue: "#8"
---

# Gate execution check: results

## Command run

```sh
qa-cycle/hooks/tests/run-gate-tests.sh
```

This runs the real `qa-cycle/hooks/transition-gate.sh` as a subprocess,
once per case, against a real temporary `QA_WORKSPACE` (via `mktemp -d`)
built and torn down by the check itself. No qa-workspace checkout was
touched; nothing is stubbed. Full captured output below.

## Captured output

```
case: valid-table-permitted-transition | expected: 0 | observed: 0 | ok
case: transition-not-permitted-from-current-phase | expected: 2 | observed: 2 | ok
case: human-actor-transition-no-token | expected: 2 | observed: 2 | ok
case: human-actor-transition-matching-token | expected: 0 | observed: 0 | ok
case: human-actor-token-consumed | expected: token absent | observed: token absent | ok
case: token-replayed | expected: 2 | observed: 2 | ok
case: non-json-stdin | expected: 2 | observed: 2 | ok
case: state-file-absent | expected: 2 | observed: 2 | ok
case: state-file-no-frontmatter | expected: 2 | observed: 2 | ok
case: phase-line-no-frontmatter-in-body | expected: 2 | observed: 2 | ok
case: qa-workspace-unset | expected: 2 | observed: 2 | ok
case: qa-cycle-disable-override | expected: 0 | observed: 0 | ok

=== tally: 12 passed, 0 failed (of 12 cases) ===
```

Script exit code: `0`.

## Per-case results

| # | Case | Expected exit | Observed exit | Result |
|---|---|---|---|---|
| 1 | Valid table-permitted transition (`intake-scoping -> session-chartered`, agent actor) | 0 | 0 | pass |
| 2 | Transition not permitted from current phase (`intake-scoping -> Go`) | 2 | 2 | pass |
| 3 | Human-actor transition (`finding-triage -> Confirmed-Defect`) with no token | 2 | 2 | pass |
| 4 | Human-actor transition with a matching unconsumed token | 0 | 0 | pass |
| 4b | Token file gone after the allowed human-actor transition | token absent | token absent | pass |
| 5 | The same token replayed against the same transition | 2 | 2 | pass |
| 6 | Non-JSON stdin | 2 | 2 | pass |
| 7 | State file absent (resolves to phase `(none)`; attempted transition not legal from `(none)`) | 2 | 2 | pass |
| 8 | State file with no frontmatter block (current-phase parse) | 2 | 2 | pass |
| 9 | `phase:` line in the write body, no frontmatter block (attempted-phase parse) | 2 | 2 | pass |
| 10 | `QA_WORKSPACE` unset | 2 | 2 | pass |
| 11 | `QA_CYCLE_DISABLE=1` (deliberate operator override) | 0 | 0 | pass |

12 of 12 cases (counting the token-consumption assertion separately from
case 4's exit-code assertion) matched their expected outcome. No case
failed.

## What this means

Every refusal path the proposal named as a minimum — an illegal transition,
a missing human-actor token, a replayed token, non-JSON stdin, a missing
state file, a state file without frontmatter, a write whose new content
lacks frontmatter, and an unset `QA_WORKSPACE` — was exercised against the
real script and observed to exit `2`, with a non-empty message on stderr in
every refusal case. The one allow path exercised by table lookup alone
(case 1), the one allow path gated on a real consumed token (case 4, plus
the token-file-removed assertion), and the deliberate `QA_CYCLE_DISABLE=1`
override (case 11) were all observed to exit `0`.

This is the first time this gate has actually been executed rather than
only read. On this run, its behavior matched what the source and the
handbook claimed for all eleven named cases plus the token-consumption
assertion. This check does not cover every input the gate's Python
handles (e.g. it does not exhaustively vary path normalization, malformed
`tool_input` shapes, or non-`state.md` paths) — see
`qa-cycle/hooks/tests/README.md` for what is and is not covered. No case
failed, so there is nothing to report as a finding requiring a follow-up
unit; if a future case fails on re-run (e.g. after the gate changes), this
proposal's discipline is: record the failure here and in the proposal's
"What did not work" section, and do not fix the gate under this proposal.
