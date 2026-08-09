---
code_under_review: pending
type: refactor
breaking: false
verdict: pending
loop_state: committing
---

# Implementation record — issue #67: adopt test-env resolution convention

## What was done
Adopted tokenmaxxxer/on-the-record's canonical test-env resolution
convention (`docs/specs/test-env-resolution.md`, issue #551) into this
rulebook's gate-test scripts, per the approved phase-1 proposal
(`docs/issue-67/proposals/test-env-resolution-adoption-proposal.md`):

- `tests/fetch-core.sh`: kept the existing three-tier candidate
  resolution (`CLAUDE_PLUGIN_ROOT_CORE` → `../core` sibling →
  network-fetched cached clone) as candidate steps, but replaced the
  final `exit 1` on total non-resolution with the convention's SKIP
  contract — `SKIP: core plugin unreachable — unverifiable outside spawn
  env` on stderr, `exit 75` (`EX_TEMPFAIL`). Added a comment referencing
  the convention doc.
- `tests/run-gate-tests.sh`: branches on `fetch-core.sh`'s exit code
  explicitly — `75` propagates the same SKIP message and exit 75 itself
  (never masked as pass, never conflated with the runner's own
  `exit 2`); any other non-zero exit keeps the prior loud-failure
  behavior (`exit 2`, now reserved for a genuine resolution defect); `0`
  proceeds exactly as before, all 24 `eogate*` assertions unchanged.
  Added a comment referencing the convention doc.
- `docs/handbooks/execution-observation-plugins.md`: updated the
  "## Tests" paragraph to describe the SKIP contract (exit 75, distinct
  from the gate's own 0/1/2 exits) in place of the stale "exits
  non-zero" description.

## Why
`upstream: docs/issue-67/proposals/test-env-resolution-adoption-proposal.md`

Issue #67's acceptance requires: outside the spawn env, every test
script SKIPs with the convention's SKIP contract instead of failing
misleadingly; with core reachable, all previously-passing assertions
stay unchanged; scripts reference the convention doc; and a real script
defect (not env) still surfaces loudly, never masked as SKIP. The
approved proposal's Rationale rejected shelling out to on-the-record's
Python `gates.test_env_resolve` module (would add a Python runtime
dependency and a new network dependency at the exact moment — env
resolution — the convention exists to make robust to network/env
unavailability) in favor of reimplementing the resolution order and
SKIP contract natively in bash, which needed no new dependency and kept
the existing network-fetch fallback as an allowed pre-SKIP candidate
step.

## Verification run
Ran directly in this session (not a mock, not narrated):
- `bash tests/run-gate-tests.sh` with `CLAUDE_PLUGIN_ROOT_CORE` resolving
  to a real core checkout already present in this environment: all 24
  `eo-*` assertions passed (`== 24 passed, 0 failed ==`) — unchanged
  from before this change.
- Isolated the SKIP path by copying `tests/fetch-core.sh` (and
  `tests/run-gate-tests.sh`) into a scratch dir with `CLAUDE_PLUGIN_ROOT_CORE`
  unset, no `../core` sibling present, `TOKENMAXXXER_CORE_CACHE` pointed
  at an empty dir, and the clone URL substituted with a nonexistent repo
  to force network non-resolution without touching the real remote:
  `fetch-core.sh` printed `SKIP: core plugin unreachable — unverifiable
  outside spawn env` to stderr and exited 75; `run-gate-tests.sh`
  propagated the same message and exit 75 (not 2, not the prior
  misleading failure).
- `grep -rl test-env-resolution tests/` matched both
  `tests/fetch-core.sh` and `tests/run-gate-tests.sh`.

## What did not work
None.

## Doctrine ladder
- Script/convention behavior change → component handbook, same commit:
  - [x] `docs/handbooks/execution-observation-plugins.md` "## Tests"
    section updated to describe the SKIP contract.

## Open findings
None open. The after-proposal warrant hunt (recorded under
`docs/issue-67/reports/`) surfaced no unresolved finding blocking this
build.

## Next steps
Commit this record together with the code changes, push the branch, and
open/update the PR against `main` with a body containing `Closes #67`.
Once merged, a follow-up pass (out of session) should update this
record's `loop_state` to `landed` and `code_under_review` to the merge
commit sha.

## Resolution path
No open findings to resolve; this section is present to satisfy the
non-terminal loop_state requirement.

## type / breaking / verdict
- type: refactor (test-runner behavior change, no product code touched)
- breaking: false (SKIP replaces an ambiguous failure exit; no
  previously-passing assertion changed)
- verdict: pending human PR review
