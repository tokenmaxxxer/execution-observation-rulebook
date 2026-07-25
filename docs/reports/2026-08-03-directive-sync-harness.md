---
status: final
---

# Harness run for the directive severity/priority sync

## What was run

`bash qa-cycle/hooks/tests/run-gate-tests.sh`, once, unmodified, after the three prose-only edits to `testrun/hooks/directive.sh`, `bugreport/hooks/directive.sh`, and `signoff/hooks/directive.sh` in `docs/proposals/2026-08-03-directive-severity-sync.md`.

## Result

```
=== tally: 38 passed, 0 failed (of 38 cases) ===
```

Exit code: `0`.

## What this does and does not confirm

This harness exercises `qa-cycle/hooks/transition-gate.sh` (and its interaction with `signoff/hooks/capture-verdict.sh` token minting) directly via constructed hook payloads. It does not read, parse, or execute any `directive.sh` file's injected prose in any way — the directive heredocs are not inputs to any test case here.

A full, unmodified 38/38 pass therefore confirms only that this unit changed no enforcement, no hook registration, and no control flow, exactly as intended for a prose-only sync. It says nothing about whether the directive prose is now accurate, complete, or in agreement with the gate — that claim rests entirely on the manual read-the-code-then-edit-the-prose work recorded in the proposal, not on this harness run. This limitation is deliberate to record: a passing harness is expected and required, but it is not evidence of correctness for this unit's actual deliverable.
