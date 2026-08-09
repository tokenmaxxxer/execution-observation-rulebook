# Survey — issue #67: adopt test-env resolution convention

## Skip condition check
Neither scout skip condition applies cleanly: this is not a pure bugfix
(it's a convention adoption with a design choice: how to realize a
Python reference module's contract inside a bash-only test runner), and
the spec (on-the-record's test-env-resolution.md) leaves that
realization choice open — it explicitly says adoption is "separate work
per repo." Scouting is the field itself: on-the-record's own doc plus
this repo's current scripts, both read below. No web/product scouting
applies — this is a single-source internal convention with no external
market analog.

## The convention (tokenmaxxxer/on-the-record, docs/specs/test-env-resolution.md, issue #551)
Resolution order: `$CLAUDE_PLUGIN_ROOT_CORE` (if it contains a non-empty
`hooks/lib/gate-lib.sh`) → caller-supplied sibling-checkout candidates →
**SKIP** (not failure): stderr message `SKIP: core plugin unreachable —
unverifiable outside spawn env`, exit code `75` (`EX_TEMPFAIL`), which
must not collide with a gate's own 0/1/2 exits.

Reference implementation is a Python module
(`gates/test_env_resolve.py` in on-the-record) with a `resolve_core()`
function and a CLI wrapper. The doc's own "Adoption per consumer shape"
names two shapes: a bash test runner should invoke the module as
`python3 -m gates.test_env_resolve <candidates...>` and branch on exit
code; a pytest suite should `import` it directly. Nothing in the doc
requires vendoring or reimplementing the Python source — the CLI-wrapper
path is explicitly how a bash consumer is expected to adopt it — but
on-the-record is a separate repo/package, not installable as a Python
module from this repo without a new dependency. Out of scope of the
convention doc: "adopting this convention inside the 23 rulebook repos'
own gate-test scripts... is separate work per repo."

## This repo's current state
- `tests/fetch-core.sh`: resolves core via `CLAUDE_PLUGIN_ROOT_CORE` →
  `../core` sibling → a network-fetched shallow clone cached under
  `$TMPDIR`. When none resolve, it prints a diagnostic to stderr and
  exits **1** — the same code space a real script failure would use, so
  a caller cannot mechanically distinguish "environment unreachable"
  from "core is broken." This is the exact ambiguity issue #551 exists
  to remove.
- `tests/run-gate-tests.sh`: calls `fetch-core.sh`, and on non-zero exit
  prints its own diagnostic and calls `exit 2` — colliding with the
  gate-under-test's own `deny` exit code (2), compounding the ambiguity.
  It then runs ~20 `eogate`/`eogate_raw`/`eogate_edit_file` assertion
  cases against `eo-methodology-gate/hooks/methodology-gate.sh`, all of
  which require a resolved `CLAUDE_PLUGIN_ROOT_CORE`.
- `tests/` also contains `deny-only-check.sh`, `parse-check.sh`, and
  `stub-check.sh` (missed by an initial `find -iname '*test*'` sweep,
  since none of those filenames contain "test" — caught by the
  after-proposal warrant hunt). None of the three resolve
  `CLAUDE_PLUGIN_ROOT_CORE` or call `fetch-core.sh`, so none are a core-
  resolution consumer this issue's convention applies to; they stay out
  of the write set.
- The network-fetch fallback (step 3 of the current script) is exactly
  the "repo-local extension a consumer MAY layer on top of step 2's
  candidate list" the convention doc calls out — it is allowed to stay,
  but only as an extra candidate-resolution attempt before the SKIP
  branch, never as a reason to skip emitting SKIP when the network is
  also unavailable.
- `docs/handbooks/execution-observation-plugins.md`'s "## Tests" section
  documents `fetch-core.sh`'s current three-tier resolution and
  `run-gate-tests.sh`'s exit-2-on-unresolved behavior — both go stale
  once the SKIP contract lands and need a doctrine-ladder update in the
  same commit (this is a changed script behavior/convention, per the
  doctrine ladder in the implementation role's directive).

## Alternatives for realizing the contract in bash (the actual design decision)
1. **Add a Python dependency on on-the-record's `gates` package** and
   shell out to `python3 -m gates.test_env_resolve` as the doc's bash
   example literally shows. Rejected: on-the-record is not published as
   an installable package (no PyPI entry, no version pin), so this would
   require vendoring or a git-based pip install of another rulebook repo
   at test time — a new external network dependency at exactly the
   moment (env resolution) the convention exists to make robust to
   network/environment unavailability. Adds a Python runtime dependency
   to a repo whose test runner is otherwise pure bash.
2. **Reimplement the resolution order + SKIP contract natively in
   `fetch-core.sh`** (env var → sibling/cached-clone candidates → SKIP
   with message on stderr + exit 75), and teach `run-gate-tests.sh` to
   read that exit code and skip the run instead of failing it. This
   matches the convention's stated order and SKIP contract exactly,
   needs no new dependency, and keeps the existing network-fetch
   fallback as an allowed pre-SKIP candidate step. Chosen — see
   proposal Rationale.

## Write-set implications
- `tests/fetch-core.sh` — replace exit-1-on-unresolved with the SKIP
  contract (message + exit 75); network fallback becomes a candidate
  step, not the final answer.
- `tests/run-gate-tests.sh` — branch on `fetch-core.sh`'s exit code:
  `75` → print the SKIP message and exit 75 itself (propagate skip,
  never mask it as pass); anything else non-zero → keep failing loudly
  (a genuine defect, per the issue's "empty state" requirement not to
  mask a real failure with SKIP); `0` → proceed exactly as today, all
  assertions unchanged.
- `docs/handbooks/execution-observation-plugins.md` — update the
  "## Tests" paragraph to describe the SKIP contract instead of the
  stale exit-2 behavior (doctrine-ladder placement: convention/behavior
  change to the component's handbook, same commit).
- No new dependency, no new env var, no migration — no manifest file
  needs touching.
