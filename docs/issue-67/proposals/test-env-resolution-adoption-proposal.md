---
status: proposed
files:
  - tests/fetch-core.sh
  - tests/run-gate-tests.sh
  - docs/handbooks/execution-observation-plugins.md
---

## Request
Adopt the canonical test-env resolution convention landed at
on-the-record's `docs/specs/test-env-resolution.md` (issue #551) into
this rulebook's gate-test scripts: outside the spawn environment (no
`CLAUDE_PLUGIN_ROOT_CORE`, no reachable core checkout), tests should
SKIP with an explicit message and a distinct exit code instead of
failing misleadingly — without weakening any assertion that runs when
core is actually reachable.

## Constraints
- Must implement the convention's exact resolution order: env var →
  caller-supplied sibling candidates → SKIP (never silently pass or
  fail on unresolved core).
- SKIP must use the convention's exit code 75 (`EX_TEMPFAIL`) and
  stderr message shape, distinct from a gate's own pass(0)/fail(1)/
  deny(2) exits — `run-gate-tests.sh` currently uses exit 2 on
  unresolved core, which collides with the gate's own deny code.
- No assertion inside `run-gate-tests.sh`'s ~20 `eogate*` cases may
  change when core resolves successfully — issue #67's acceptance
  explicitly requires previously-passing assertions to stay unchanged.
- A real script defect (not an environment problem) must still surface
  as a loud failure, never masked as SKIP — issue #67's stated empty
  state.
- Scripts must reference the convention doc (`grep`-able), per the
  issue's acceptance check.
- No new runtime dependency, no new env var beyond the existing
  `CLAUDE_PLUGIN_ROOT_CORE`.

## Rationale
Two ways to realize the convention in this repo were considered:

1. **Shell out to on-the-record's Python `gates.test_env_resolve`
   module**, as the convention doc's own "bash test runner" adoption
   example literally shows (`python3 -m gates.test_env_resolve
   <candidates...>`). Rejected: on-the-record is not published as an
   installable package (no PyPI entry, no pinned version) — using it
   would mean vendoring another rulebook repo's source or a git-based
   `pip install` at test time, adding a Python runtime dependency to a
   test runner that is otherwise pure bash, and introducing a new
   network dependency at exactly the moment (environment resolution)
   the convention exists to make robust to network/environment
   unavailability.
2. **Reimplement the resolution order and SKIP contract natively in
   `tests/fetch-core.sh`** (bash), keeping the existing network-fetch
   fallback as an allowed extra candidate step ahead of the final SKIP
   branch — the convention doc explicitly permits a caller-layered
   candidate extension on top of step 2. Chosen: matches the
   convention's order and SKIP contract exactly, needs no new
   dependency, and is a minimal, localized change to the two scripts
   that already own core resolution.

## What will be done
- `tests/fetch-core.sh`: keep the existing three-tier candidate
  resolution (`CLAUDE_PLUGIN_ROOT_CORE` → `../core` sibling →
  network-fetched cached clone) as candidate steps, but replace the
  final `exit 1` on total non-resolution with the convention's SKIP
  contract: print `SKIP: core plugin unreachable — unverifiable outside
  spawn env` to stderr and `exit 75`. Add a comment referencing
  on-the-record's `docs/specs/test-env-resolution.md` (issue #551) as
  the source of the order and the SKIP contract.
- `tests/run-gate-tests.sh`: branch on `fetch-core.sh`'s exit code
  explicitly — `75` prints the same SKIP message and exits 75 itself
  (propagating skip rather than masking or failing); any other non-zero
  exit keeps today's loud-failure behavior (`exit 2` retained only for
  that genuine-defect case, no longer for the SKIP case); `0` proceeds
  exactly as today with all `eogate*` assertions unchanged. Add a
  comment referencing the convention doc.
- `docs/handbooks/execution-observation-plugins.md`: update the
  "## Tests" paragraph to describe the SKIP contract (exit 75, distinct
  from the gate's own 0/1/2) in place of the stale "exits non-zero"
  description, so the handbook doesn't go stale the moment this lands.

## Out of scope
- Adopting a Python dependency on on-the-record's `gates` package (see
  Rationale, alternative 1 — rejected).
- Changing any `eogate*`/`eogate_raw`/`eogate_edit_file` assertion logic
  or expected verdicts — only the unresolved-core path changes.
- `tests/stub-check.sh`, referenced by the handbook but absent from the
  current tree — pre-existing handbook staleness unrelated to this
  issue, not touched here.
- Any other repo's adoption of the convention — out of scope per the
  convention doc itself ("separate work per repo").

## How you'll know it worked
- On a plain checkout with `CLAUDE_PLUGIN_ROOT_CORE` unset and no `core`
  sibling and no network (or `TOKENMAXXXER_CORE_CACHE` pointed at an
  empty dir): `tests/fetch-core.sh` exits 75 with the SKIP message on
  stderr; `tests/run-gate-tests.sh` exits 75 too, not 2 and not the
  prior misleading failure.
- With `CLAUDE_PLUGIN_ROOT_CORE` pointed at a real core checkout: all
  ~20 `eogate*` cases in `run-gate-tests.sh` pass exactly as before
  (unchanged pass/fail counts).
- `grep -rl test-env-resolution tests/` matches both scripts.
- With `CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent path (the
  existing missing-core mandatory case inside the gate assertions
  themselves, not the runner's own resolution) — unaffected, still
  denies via the gate's own guarded-source logic.
