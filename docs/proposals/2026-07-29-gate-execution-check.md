---
status: landed
issue: "#8"
files:
  - qa-cycle/hooks/tests/run-gate-tests.sh
  - qa-cycle/hooks/tests/README.md
  - docs/reports/2026-07-29-gate-execution.md
---

# Execute the transition gate against real payloads

## Intent

The gate that enforces the QA cycle (`qa-cycle/hooks/transition-gate.sh`) has
never been executed. Run it against real payloads, cover the refusal paths
it claims, and leave both a repeatable check and a recorded result. The
point is observed exit codes, not another reading of the source.

## Constraints

- Every case asserts on the actual exit code and, where the gate emits one,
  the refusal message's presence — not on the script's text.
- Cases cover at minimum: valid transition permitted by the table (expect
  allow); transition not permitted from the current phase (expect refuse);
  human-actor transition with no token (expect refuse); human-actor
  transition with a matching unconsumed token (expect allow, token
  consumed); the same token replayed (expect refuse); non-JSON stdin
  (expect refuse); state file absent (expect refuse); state file with no
  frontmatter block (expect refuse); a `phase:` line in the body but no
  frontmatter (expect refuse); `QA_WORKSPACE` unset (expect refuse);
  `QA_CYCLE_DISABLE=1` (expect allow — the deliberate operator override).
- Fixtures are real files in a temporary workspace the check creates and
  removes; nothing is stubbed and no state is written into the real
  qa-workspace repository.
- The check is runnable by one command and reports which cases passed and
  which failed.
- If a case fails, that is the finding — record it in the report and stop.
  Do not fix the gate under this proposal.
- No secret values in any fixture; environment variable names only.

## What will be done

Write the executable check and its fixtures at
`qa-cycle/hooks/tests/run-gate-tests.sh` (a single bash script that builds a
temp `QA_WORKSPACE` per case, pipes a real JSON payload into
`transition-gate.sh`, and asserts on exit code and stderr) plus a short
`qa-cycle/hooks/tests/README.md` explaining how to run it. This location is
chosen because the repo has no existing unit-test convention for hook
scripts — `bench/` is a separate, already-named instrument for measuring
the plugin stack's *effectiveness* against seeded bugs (on/off detection
rate), not for verifying a single hook's exit-code behavior, and its
protocol (headless `claude -p` runs, answer-key adjudication) doesn't fit a
fast, deterministic gate check. Colocating the check under the owning
plugin's `hooks/` directory keeps it next to the script it exercises rather
than inventing a new top-level convention. Run it. Write
`docs/reports/2026-07-29-gate-execution.md` recording what was run, the
per-case results, and what they mean — the report names the observed
outcome for every case, including failures.

## Out of scope

Changing the gate, the transition table, or any plugin behavior.
Effectiveness benchmarks. Anything in the qa-workspace repository.

## How I will know it worked

The check runs from one command and prints a per-case pass/fail. The report
states, for each listed case, the exit code observed rather than the exit
code expected by design. Anyone changing the gate later can re-run it and
see the same list.

## What did not work

Nothing. All 12 assertions (11 named cases plus the token-file-removed
assertion on case 4) matched their expected exit code / observed state on
the run recorded in
[docs/reports/2026-07-29-gate-execution.md](../reports/2026-07-29-gate-execution.md).
No expectation broke, so there is nothing to log here.
