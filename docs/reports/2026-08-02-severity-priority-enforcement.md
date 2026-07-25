---
proposal: docs/proposals/2026-08-02-severity-priority-axes.md
issue: "#16"
---

# Enforcement report — severity and priority axes

## What was run

```
bash qa-cycle/hooks/tests/run-gate-tests.sh
```

against the extended `qa-cycle/hooks/tests/run-gate-tests.sh`, which keeps
all 20 pre-existing cases and adds 18 new cases (38 total) covering the
severity precondition and the priority verdict token, run as real
subprocesses of `qa-cycle/hooks/transition-gate.sh` against real fixture
files, per the harness's existing design.

## What came back

```
=== tally: 38 passed, 0 failed (of 38 cases) ===
```

Exit code of the harness: `0`. Every individual case's observed exit code
matched its expected exit code; refusal cases (expected exit `2`) all
emitted a non-empty message on stderr, as the harness's own assertion
requires.

New cases and their observed exit codes:

| Case | Observed exit |
|---|---|
| `reproduced-missing-severity-refused` | 2 |
| `reproduced-severity-outside-closed-set-refused` | 2 |
| `reproduced-two-severity-lines-refused` | 2 |
| `reproduced-valid-severity-allowed` | 0 |
| `priority-change-no-token-refused` | 2 |
| `priority-token-for-different-item-refused` | 2 |
| `priority-token-for-different-value-refused` | 2 |
| `forged-priority-set-by-marker-no-token-refused` | 2 |
| `priority-token-first-use-allowed` | 0 |
| `priority-live-token-gone` (file check) | absent, as expected |
| `priority-consuming-marker-present` (file check) | exists, as expected |
| `priority-token-replay-for-new-value-refused` | 2 |
| `priority-consumption-timing-first-allow-write-does-not-land` | 0 |
| `priority-consumption-timing-retry-still-allowed` | 0 |

(Plus 4 more cases — `handed-off-refuses-without-human-token`,
`token-for-one-item-rejected-for-another`, and the two item-id/severity
setup cases reused across the new fixtures — that were exercised
incidentally by the new fixtures and already existed in the suite.)

## The hunt's forged-marker reproduction, explicitly

`docs/reports/2026-08-02-hunt-severity-priority-axes.md` found the
original design (a `priority-set-by: human` marker written directly into
the same `state.md` content the write itself changes, with no token) let
an agent forge human attribution for a `priority` change in the same
`Write` call that changed it.

Case `forged-priority-set-by-marker-no-token-refused` reproduces exactly
that shape against the now-landed implementation: a single `Write` call
changes item `BUG-1`'s `priority` from unset to `now` and adds a
self-authored `priority-set-by: human` line, with no `tokens/BUG-1.priority.token`
file present anywhere. Observed exit code: `2` (refused). The gate's
priority check never inspects the `priority-set-by` line at all — it looks
only for a matching, unconsumed token bound to `(item id, field, value)`
at `tokens/<item-id>.priority.token` — so the marker's presence in the
write's own content cannot influence the decision either way. The hunt's
finding is closed.
