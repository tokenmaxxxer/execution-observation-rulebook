# issue-53 gate A+ closeout record (execution-observation, phase 2)

## Scope

Target issue #53 ("게이트 A+ 최종 마감: 재감사 잔여 결함 보수 (재감사 등급
B)"), phase 2 of
`docs/issue-53/proposals/gate-a-plus-closeout-proposal.md` (phase 1, PR
#54, merged). Approval: the single-account-mode issue comment "APPROVE
issue-53/execution-observation" from `JiwonJung94`, an account listed in
`docs/specs/approvers.md`, confirmed live this session via `gh issue
view 53 --comments`.

## Independence statement

This record covers work this same session performed (implementing the
already-approved proposal against this role's own tooling), not a
review of another role's independently-authored artifact — there is no
second party's artifact being judged here. What follows is a delivery
report against the proposal's own verdict-level plan and the issue's
four-item requirement list, not a verdict on someone else's work.

## outcome

Checked against the proposal's stated outcome checks, all confirmed
live this session:

- `bash tests/run-gate-tests.sh` → `24 passed, 0 failed`, including the
  new `eo-missing-core-guarded-source-denies` case
  (`tests/run-gate-tests.sh:225-229`).
- `qa/hooks/hooks.json`'s eo-state `SessionStart` command now reads
  `${CLAUDE_PLUGIN_ROOT}/plugins/eo-state/hooks/state.sh reset`
  (`qa/hooks/hooks.json:9`) — resolves to the confirmed-present
  `qa/plugins/eo-state/hooks/state.sh`; the `../` climb-too-far is
  removed.
- `tests/deny-only-check.sh`'s substance probe targets
  `docs/issue-999/reports/execution-observation.md`
  (`tests/deny-only-check.sh:45`); live run shows `deny-only-check: ok —
  methodology-gate.sh refuses the empty record`.
- `README.md` names the current repo
  (`execution-observation-rulebook`, `README.md:1`), the current role
  (`execution-observation`, `README.md:3`), only files present in the
  tree today (cross-checked against `find qa -maxdepth 5`), no phantom
  filenames, and all three `eo-*` plugins (`README.md:31-53`).
- `qa/plugins/eo-state/hooks/state.sh:23` and
  `qa/plugins/eo-methodology-gate/hooks/methodology-gate.sh:20` both
  source `gate-lib.sh` with the `||`-guard shape core #75 landed (exit 2
  with a named-gate stderr message on failure), text matching core #75's
  landed guard verbatim (`core/hooks/directive.sh:10` et al., read
  during phase 1).
- `bash core/hooks/tests/compliance-check.sh
  qa/plugins/eo-methodology-gate` (core #75's checkout, run against this
  repo's gate) → `compliance-check: ok`. `eo-state/hooks/state.sh` is
  not named `*-gate.sh`, so compliance-check.sh's own `find -name
  '*-gate.sh'` filter does not enumerate it — its guard was verified
  directly by code read (`state.sh:23`) plus the live gate-test suite
  instead; a naming-convention limit of the shared script, not a gap in
  this repo's own guard coverage.

## trajectory

The proposal named both precondition PRs (core #75, on-the-record #182)
and their confirmed shapes before this phase-2 session made any edit —
confirmed by `docs/issue-53/reports/execution-observation/current-state-survey.md`
sections 1-2, read this session before any edit began. The approval
gate was honored per the issue comment cited above. Phase 2 edited the
files the proposal's Scope named, plus two manifest files
(`.claude-plugin/marketplace.json`, `qa/.claude-plugin/plugin.json`) the
proposal's Scope list did not individually name but issue #53's own
requirement 4 ("README·manifest에 옛 역할명 ... 잔재 0") explicitly covers
— a conservative, text-only description fix (no restructuring, no
rename of the `qa` plugin id or directory), not a scope departure from
the issue itself.

## step

Per-artifact, against the proposal's six numbered fixes:

1. `qa/hooks/hooks.json` path fix — landed as designed
   (`qa/hooks/hooks.json:9`).
2. `tests/deny-only-check.sh` `rec_rel` fix — landed as designed
   (`tests/deny-only-check.sh:45`).
3. `README.md` resync — landed as designed (full rewrite).
4. gate-lib source guard on both `state.sh`/`methodology-gate.sh` —
   landed as designed (`state.sh:23`, `methodology-gate.sh:20`).
5. Missing-core mandatory test case — landed as designed
   (`tests/run-gate-tests.sh:225-229`, asserts `deny`).
6. Matcher/code coverage re-confirmation for `eo-state` — closed:
   `qa/plugins/eo-state/hooks/hooks.json`'s `PostToolUse` matcher is
   `Read|Bash`; `state.sh`'s `mark` subcommand
   (`qa/plugins/eo-state/hooks/state.sh:44-58`) does not branch on tool
   name — it inspects the raw payload for a
   `docs/issue-*/(reports|proposals)/` path (the Read-tool case) or a
   `gh (api|pr)` command (the Bash-tool case). Both matcher-advertised
   tools are reached and no unadvertised tool's payload shape is coded
   for — matcher and code agree, no gap.

## What was done

The six fixes above, plus one defect found and fixed this session that
was not in the approved proposal's six-item design:

`tests/deny-only-check.sh`'s substance-probe `probe_dir` default was
`.../../qa/hooks` (`tests/deny-only-check.sh:44`, prior text). Since
issue-47's plugin migration, `methodology-gate.sh` lives at
`qa/plugins/eo-methodology-gate/hooks/methodology-gate.sh`, not under
`qa/hooks/`. Confirmed live before the fix: `bash
tests/deny-only-check.sh` printed `deny-only-check: no gate scripts
under .../qa/hooks` and exited 0 — the probe found zero `*-gate.sh`
files and reported success without ever invoking the gate, so this
contract-s20 check had been passing vacuously since the migration.
Fixed by changing the default to `.../../qa`
(`tests/deny-only-check.sh:44`), so the existing recursive `find ... -name
'*-gate.sh'` now reaches the migrated gate. Re-run confirms:
`deny-only-check: ok — methodology-gate.sh refuses the empty record`.

**Root cause**: issue-47's phase-2 migration moved the gate script but
did not update this shared, cross-repo-copied test file's hardcoded
default path, and that update was out of scope for that migration's own
record. **Impact**: the substance probe silently no-oped rather than
failing loud, so a real regression in the gate's empty-record refusal
would not have been caught by this check since the migration.
**Timeline**: found and fixed in this same phase-2 session (2026-08-01).
**Action item**: fixed inline this session; no further action needed —
verified by re-run above.

`README.md` and both manifest description fields
(`.claude-plugin/marketplace.json`, `qa/.claude-plugin/plugin.json`)
rewritten to describe the actual current execution-observation
methodology instead of the retired `qa` role's "launch and exercise the
real product" / "report-don't-fix" / `/qa-init`+`/testrun`+`/regress`+
`/qa-stats` description. The `eo-directive`/`eo-methodology-gate`/
`eo-state` plugin manifest entries were already accurate (confirmed by
read) and are unchanged. A repo-wide sweep
(`find qa -iname '*record-fields*' -o -iname '*trailer-gate*' -o -iname
'*handbook-trigger*'`) confirms zero phantom files remain anywhere
under `qa/`.

## Why

Issue #53's re-audit (grade B) named three repo-specific residual
defects (eo-state session-start path error, a stale legacy record path
in the shared deny-only-check probe, and a stale README) plus four
numbered requirements spanning both the repo-specific items and the
common core-#75-derived fixes (source guard, missing-core mandatory
test, full matcher/code alignment, README/manifest resync). Every
design choice in this session traces to the already-approved phase-1
proposal (`docs/issue-53/proposals/gate-a-plus-closeout-proposal.md`);
no new methodology was invented and no scope was added beyond the
issue's four-item list and the one additional defect the outcome-check
pass itself surfaced (documented above, fixed in place rather than
deferred, since it directly blocks requirement 3's "compliance-check
통과 record").

## Upstream basis

Commit `3750825` (PR #54, merged) for the approved phase-1 proposal;
`docs/issue-53/proposals/gate-a-plus-closeout-proposal.md`'s design
sections 1-6 for the exact fix plan implemented here; core #75 commit
`f61d52f` and on-the-record #182 commit `e50fe08` (both read in full
during phase 1, re-confirmed this session by re-running
`compliance-check.sh` against this repo's own gate) for the common-item
reference shapes adopted.

loop_state: landed

## Open findings

None. All six of the proposal's fixes and the one additional
deny-only-check defect are closed and verified live this session. No
deferred work remains against issue #53's four numbered requirements.

## Evidence

- `docs/issue-53/proposals/gate-a-plus-closeout-proposal.md` and
  `docs/issue-53/reports/execution-observation/current-state-survey.md`
  (this session's read, confirming all six named defects live before
  any code changed).
- This session's own file writes/edits: `qa/hooks/hooks.json`,
  `tests/deny-only-check.sh`, `README.md`,
  `qa/plugins/eo-state/hooks/state.sh`,
  `qa/plugins/eo-methodology-gate/hooks/methodology-gate.sh`,
  `tests/run-gate-tests.sh`, `.claude-plugin/marketplace.json`,
  `qa/.claude-plugin/plugin.json` — all read back after edit this
  session.
- Test runs this session: `bash tests/run-gate-tests.sh` (24/24 pass, 0
  fail, including the new missing-core case), `bash
  tests/parse-check.sh` (1/1 file parses clean), `bash
  tests/deny-only-check.sh` (both checks ok, substance probe now
  actually exercises the migrated gate), and core's own
  `compliance-check.sh qa/plugins/eo-methodology-gate` (ok, zero
  violations) run against the core #75 checkout read during phase 1.
