---
status: approved
files:
  - README.md
  - README.ko.md
  - docs/design.md
  - docs/design.ko.md
  - docs/handbooks/qa-cycle.md
  - docs/specs/qa-cycle-state-machine.md
  - intake/README.md
  - intake/commands/qa-init.md
  - intake/hooks/session-start.sh
  - qa-cycle/README.md
  - qa-cycle/hooks/directive.sh
  - qa-cycle/hooks/report-phase.sh
  - qa-cycle/hooks/transition-gate.sh
  - qa-cycle/hooks/tests/README.md
  - qa-cycle/hooks/tests/run-gate-tests.sh
  - bench/README.md
  - bugreport/commands/bug.md
  - regress/commands/regress.md
  - signoff/README.md
  - signoff/commands/go-no-go.md
  - signoff/hooks/capture-verdict.sh
  - signoff/hooks/tests/run-verdict-tests.sh
  - stats/commands/qa-stats.md
  - stats/hooks/directive.sh
  - testrun/README.md
  - testrun/commands/testrun.md
---

# QA's durable records live in the target repo; `$QA_WORKSPACE` is removed entirely

## Intent

The user directed that QA's durable records of what was requested and what
was produced must live in the TARGET repo — the shared board record at
`docs/reports/records/<subject>/qa.md` and its `qa/**` subtree — the same
place all seven other role rulebooks write their records, per
`docs/specs/role-handoff-contract.md` §10 and §11, and that the
`$QA_WORKSPACE` mechanism must be removed entirely rather than kept around in
any demoted or optional form. Today that is not what
this repo's own rulebook text and hooks say. `docs/specs/qa-cycle-state-machine.md`
line 137 states plainly: "All state lives under
`$QA_WORKSPACE/projects/<owner>-<repo>/`... **never in the target repo**."
`docs/handbooks/qa-cycle.md`'s `QA_WORKSPACE` section calls it "the root
directory where all QA-cycle state lives... never the target project's own
repository," and its gate (`qa-cycle/hooks/transition-gate.sh`) refuses any
write (exit 2) when `$QA_WORKSPACE` is unset — i.e. the gate treats the
external workspace as the only legitimate place for state to exist at all.
`intake/README.md`, `intake/hooks/session-start.sh`, and the `bench`,
`bugreport`, `regress`, `signoff`, `stats`, `testrun` command/README/hook
files repeat the same pattern: `intake.md`, `plan.md`, `runs/`, and evidence
files are all written under `$QA_WORKSPACE/projects/<slug>/`, a private,
host-local, uncommitted tree outside the repo a reader is looking at. A
reader who clones or opens the target repo — including another role
onboarding blind per the contract's Gate B — cannot see any of it.

This is not a new observation invented for this proposal:
`docs/specs/role-handoff-contract.md` §10 already states the intended end
state in its own voice — "qa's evidence moves in-repo... That exception is
abolished... now lives entirely inside the work repo, under qa's own record
area (`docs/reports/records/<subject>/qa/**`, alongside `qa.md` itself)" —
and `docs/proposals/2026-07-26-contract-v2-conformance.md` (status:
approved) already commissioned bringing this rulebook into conformance with
that contract text. What remains, and what this proposal commissions, is
finishing that conformance specifically for the primary-record-store
question: this repo's rulebook prose and its hooks still name
`$QA_WORKSPACE` as the sole authoritative location and still gate on its
presence, in direct contradiction of the contract they claim to follow.

## Constraints

- `role-handoff-contract.md`'s v2 board schema (§4 READ vs DEPENDS-ON,
  §9 subject minting, §10 blackboard-in-repo, §11 path ownership table)
  stays authoritative and unmodified by this work; this proposal brings qa
  into line with it, not the reverse.
- Bug reports still go to the target project's own issue tracker, not into
  `qa.md` or the `qa/**` subtree — only qa's own record of what was
  requested/observed/produced moves in-repo, not a duplicate of the
  tracker's content.
- Per-role path ownership (§11) is unchanged: qa continues to own exactly
  `docs/reports/records/<subject>/qa.md` and
  `docs/reports/records/<subject>/qa/**`, and must not write to any path
  another role's row in §11 assigns to it.

## What will be done

- Repoint the sole record store named throughout this rulebook's docs and
  hooks from `$QA_WORKSPACE/projects/<owner>-<repo>/` to the target repo's
  own record area: `docs/reports/records/<subject>/qa.md` for the
  top-level record, and `docs/reports/records/<subject>/qa/**` for
  `intake.md`, `plan.md`, `runs/`, `state.md`, tokens, and other evidence
  currently under `$QA_WORKSPACE/projects/<slug>/`. This is a full move,
  not a copy: `$QA_WORKSPACE` is not retained as a secondary or fallback
  store for any of this data.
- Remove the `$QA_WORKSPACE` mechanism entirely: the environment variable
  itself, every reference to it in prose and hooks, and any hook logic keyed
  on its presence or value are deleted, not demoted or kept as an optional
  fallback. `qa-cycle/hooks/transition-gate.sh` stops exiting 2 on unset
  `$QA_WORKSPACE` because it stops checking `$QA_WORKSPACE` at all; its
  precondition check moves to the in-repo `qa/**` subtree instead. Any
  transient execution scratch space a role needs mid-session (e.g. a
  working file it doesn't intend to commit) uses the session's own temp
  directory, never a durable side repo or host-local path that outlives the
  session.
- Update the directive/hook text that currently instructs agents to resolve
  `$QA_WORKSPACE` and write there (`intake/hooks/session-start.sh`,
  `qa-cycle/hooks/directive.sh`, `qa-cycle/hooks/report-phase.sh`,
  `signoff/hooks/capture-verdict.sh`, `stats/hooks/directive.sh`) to resolve
  and write under the target repo's `docs/reports/records/<subject>/qa/**`
  instead, consistent with how the other seven roles' rulebooks already
  resolve their own record paths.
- Update the prose files (`README.md`, `README.ko.md`, `docs/design.md`,
  `docs/design.ko.md`, `docs/handbooks/qa-cycle.md`,
  `docs/specs/qa-cycle-state-machine.md`, and the per-plugin `README.md`/
  command docs listed above) to describe the target-repo record area as the
  primary store, matching `role-handoff-contract.md` §10's own description
  rather than contradicting it.

## Out of scope

- What happens to the existing `qa-workspace` repo's contents, or whether
  that repo itself is deleted. Removing the `$QA_WORKSPACE` mechanism from
  this rulebook (env var, references, hook logic) does not migrate or
  delete any data currently sitting in a live `$QA_WORKSPACE` tree; that is
  a separate human decision, not covered by this proposal.
- Any other role's rulebook. The other seven roles already write to
  `docs/reports/records/<subject>/<role>.md` per §11 and are not touched.
- Re-litigating `role-handoff-contract.md` itself, or any part of
  `2026-07-26-contract-v2-conformance.md` not related to the primary
  record store (e.g. the ACCEPTS/READ-vs-DEPENDS-ON change is a separate
  concern already covered by that proposal).

## Success

- No reference to `$QA_WORKSPACE` remains anywhere in this repo — not the
  environment variable, not its resolution logic, not prose describing it,
  not as an optional or non-authoritative fallback. `grep -ri
  QA_WORKSPACE` over the repo returns nothing.
- All QA records — intake, plan, runs, evidence, regression, and stats —
  live exclusively under the target repo's
  `docs/reports/records/<subject>/qa.md` and `docs/reports/records/<subject>/qa/**`
  subtree; no hook or doc names any other durable, host-local, or side-repo
  location for them.
- Any transient execution scratch a role needs mid-session uses the
  session's own temp directory, never a durable side repo.
- A fresh QA round conducted from a clean checkout of only the target repo
  — with no `$QA_WORKSPACE` directory or environment variable present
  anywhere on the host — produces `intake.md`, `plan.md`, `runs/`, and
  evidence files entirely under that target repo's
  `docs/reports/records/<subject>/qa/**`, and the round completes without
  any gate failure attributable to a missing external workspace, because no
  gate checks for one.
- Blind-onboarding Gate B (another role, or a fresh qa session, opening only
  the target repo with no prior context) can locate and read qa's full
  record — what was requested and what was produced — from the target repo
  alone, with no access to any external host path required.
- The gate test suite (`qa-cycle/hooks/tests/run-gate-tests.sh`) is updated
  to match: no case asserts exit-2 on unset `$QA_WORKSPACE`, and no case
  references `$QA_WORKSPACE` at all.

## What did not work

- `run-gate-tests.sh`'s `new_workspace()`/`LIVE_WORKSPACES` cleanup relied on a function mutating an array from inside a `$(...)` command substitution (a subshell); the mutation never reached the caller, so per-test subject directories under `docs/reports/records/` were not cleaned up by the trap. Fixed by also sweeping `docs/reports/records/gate-test-*` unconditionally in `cleanup_all`, independent of array tracking.
- `signoff/hooks/capture-verdict.sh`'s first `CLAUDE_PROJECT_DIR`-through-a-symlink test case failed: `records_root` was built from the unresolved (possibly symlinked) `repo_root`, while `proj_dir_real` was resolved via `pwd -P` (symlink-free) — the two were compared as prefix/suffix and never matched, so no token was minted. Fixed by resolving `repo_root` itself via `pwd -P` immediately after determining it, before building any path from it.
