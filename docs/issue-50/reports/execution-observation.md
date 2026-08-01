# issue-50 A+ remediation record (execution-observation, phase 2)

## Scope

Target issue #50 (`## 2026-08-01 실물 코드 감사 결과 (등급: B-)`), phase 2 of
`docs/issue-50/proposals/execution-observation-proposal.md` (phase 1, PR
#51, merged). Approval: the single-account-mode issue comment "APPROVE
issue-50/execution-observation" from `JiwonJung94`, an account listed in
`docs/specs/approvers.md` and the same account that authored PR #51.

## Independence statement

This record covers work this same session performed (implementing the
already-approved proposal), not a review of another role's independently-
authored artifact — there is no second party's artifact being judged
here. What follows is a delivery report against the proposal's own
phase-2 plan and the issue's four-item requirement list, not a verdict on
someone else's work.

## What was done

- **Reference adoption**: `qa/plugins/eo-methodology-gate/hooks/
  methodology-gate.sh` and `qa/plugins/eo-state/hooks/state.sh` now source
  core's `hooks/lib/gate-lib.sh` (bash) and load `gate-lib.py` via
  `importlib` (Python payload), per `docs/handbooks/gate-house-standard.md`
  (core issue #72, confirmed landed this session via `gh api` against
  `tokenmaxxxer/tokenmaxxxer-core`). No gate-lib logic is re-derived
  locally (`docs/handbooks/canon-scripts.md`'s reference-not-copy rule);
  `tests/fetch-core.sh` resolves a checkout for tests to reference
  (`CLAUDE_PLUGIN_ROOT_CORE`, a local `core` sibling, or a cached shallow
  clone under `$TMPDIR`) without ever vendoring a copy into this repo.
- **Defects fixed by construction**, all four migrated to `gate_*` calls
  instead of hand-patched independently: kill-switch
  default-open-on-unrecognized-value (now `gate_kill_switch_active`, only
  a recognized on-spelling disables); `Edit`/`MultiEdit` reconstruction
  always-first-occurrence, `replace_all` ignored (now
  `gate_reconstruct_write`); malformed-JSON silent pass-through at the
  target-extraction stage (now `gate_parse_json_or_deny`, deny instead);
  absolute/relative/`./`-prefixed path matching via a hand-rolled
  bash+python mix (now `gate_normalize_path`).
- **Semantic checks upgraded** from bare substring to structural position:
  the verdict-level-plan and plugin-list checks now require a heading-
  matched section (`##`/`###` split) whose body carries the actual
  adjacency marker (`\b(outcome|trajectory|step)\s*[:—-]`) or an actual
  markdown list item, not a stray mention anywhere in the document; the
  record's independence-ordering, three-verdict-level, and blameless-shape
  checks widened the same way (marker-adjacency instead of bare `"sound"`/
  `"outcome:"` substrings; blameless components must appear as a heading
  or bold-labeled line within the triggering section or the five lines
  following the deficiency/finding mention).
- **Mandatory test cases added** to `tests/run-gate-tests.sh` (single-file
  convention, per the proposal's own stated preference): `Edit` with
  `replace_all` against a multiply-occurring match (both true and false,
  the false case demonstrating the old bug would have wrongly allowed a
  write that still carries a forbidden phrase), `MultiEdit` with mixed
  `replace_all` true/false in one call, malformed JSON (truncated,
  non-object, empty), kill-switch typo-stays-active vs.
  recognized-on-value-disables, and absolute/`./`-prefixed `file_path`
  resolving to the same verdict as the relative-path fixture — plus three
  structural-vs-mention semantic cases (proposal mention-only-no-structure,
  record bare-"sound"-in-prose, record blameless-incomplete-vs-complete).
  The 7 dead `record-fields-gate.sh`/`trailer-gate.sh` cases (2 already
  `true ||`-disabled) are removed, not fixed — those files are core canon
  hooks now, not this repo's own script (confirmed by `tests/stub-check.sh`
  passing clean this session).
- **`.warrant-hunt.count`** (unowned root residue, no script in this repo
  produced or consumed it) removed.
- **README/handbook resync**: `qa/plugins/eo-methodology-gate/README.md`
  and `docs/handbooks/execution-observation-plugins.md` updated to
  describe the post-migration shape (gate-lib sourcing, upgraded
  structural checks, the corrected kill-switch default, the mandatory
  test cases).

## Verdict-level plan

outcome: sound — `tests/run-gate-tests.sh` exits 0 at 23/23 (0 failures,
the prior 7/17 exit-127 fully gone since the dead cases are removed
rather than papered over); `tests/parse-check.sh qa` and
`tests/stub-check.sh qa` both pass clean; `compliance-check.sh
qa/plugins/eo-methodology-gate` (run this session against a real,
network-fetched checkout of `tokenmaxxxer-core`) reports `ok` with zero
violations — no hand-rolled `*_OFF` case statement and no bare
`.replace(old, new[, 1])` call remain in `methodology-gate.sh`.

trajectory: sound — the migration is reference-only end to end: the
adopted library was named before any code changed (phase-1 proposal),
the approval gate (contract v3 s19) was honored before this write, and
every fix traces to a named `gate_*` function rather than a locally
re-derived patch, so this repo does not regrow the shape
`gate-house-standard.md` exists to stop rulebooks re-deriving.

step: sound — every requirement in the issue's four-item list has a
traceable artifact: (1) all four named defects fixed via `gate_*`
migration, verified by `compliance-check.sh` output above; (2) the five
proposal checks and two record checks all moved to
heading/adjacency/list-item structural matching, verified by the new
mention-only/bare-word test cases denying where the old substring check
would have allowed; (3) all six mandatory case groups present and green
in the same `run-gate-tests.sh` run; (4) both README and handbook text
now describe the landed code, and `.warrant-hunt.count` is gone.

## Blameless shape (the four defects this migration fixed)

### impact

The kill-switch default-open-on-unrecognized-value bug meant a typo in
`EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF` or
`EXECUTION_OBSERVATION_STATE_OFF` silently disabled the corresponding
gate — a methodology write could bypass the required-elements check
entirely with no visible signal. The `replace_all`-ignored bug meant an
`Edit`/`MultiEdit` call using `replace_all: true` against a
multiply-occurring string was judged only on its first-occurrence
outcome, so a write that left a forbidden phrase (e.g. a second, unfixed
`step: deficient`) could still pass. Both were live defects in this
repo's own gates, not hypothetical.

### timeline

Found in the 2026-08-01 code audit (issue #50, grade B-). Root-caused and
scoped in this role's phase-1 survey/proposal (same date, PR #51, merged).
Fixed in this phase-2 session (2026-08-01), following core issue #72's
prerequisite landing of `gate-lib.sh`/`gate-lib.py` and
`gate-house-standard.md`.

### root cause

Both defects trace to hand-rolled, independently-derived logic: this
repo's kill-switch case statement and reconstruction logic were written
before `gate-house-standard.md` existed, each re-deriving a shape that
core's own canon had already gotten wrong in the same way (per
`gate-house-standard.md`'s own "two bugs this issue fixed" section) —
the same defect class, independently reintroduced downstream, is exactly
what a shared library exists to stop happening.

### action item

Migrate every rulebook gate onto `gate-lib.sh`/`gate-lib.py` instead of
hand-rolling the trap/kill-switch/path-normalize/reconstruct machinery —
done in this session for `eo-methodology-gate` and `eo-state`, the only
two plugins in this repo that carried any of that logic
(`eo-directive` carries neither and is unchanged, per the phase-1
proposal's own non-goals).

## Why

Issue #50's A+ remediation asked for the audited defects fixed
(kill-switch, path matching, fail-closed, `replace_all`), the semantic
checks tightened, mandatory test cases added, and README/handbook resync
— explicitly by referencing core issue #72's now-landed gate-house
standard library rather than re-deriving fixes independently. Every
design choice in this session traces to the already-approved phase-1
proposal; no new methodology was invented and no scope was added beyond
the issue's four-item list.

## Upstream basis

Commit d2f957b (PR #51, merged) for the approved phase-1 proposal;
`docs/issue-50/proposals/execution-observation-proposal.md`'s design
sections for the exact adoption/upgrade/test/resync plan implemented
here; core issue #72 / `docs/handbooks/gate-house-standard.md` for the
adopted library, read this session via `gh api` against
`tokenmaxxxer/tokenmaxxxer-core`.

loop_state: landed

## Open findings

None. The dead `record-fields-gate.sh`/`trailer-gate.sh` test cases are
removed rather than reintroduced, per the proposal's explicit non-goal —
re-adding either gate is a distinct decision for its own issue, not a
gap in this one.

## Evidence

- `docs/issue-50/proposals/execution-observation-proposal.md` and
  `docs/issue-50/reports/execution-observation/survey.md` (this session's
  read, confirming the audit's live 7/17 exit-127 and the two named bug
  classes before any code changed).
- `tokenmaxxxer/tokenmaxxxer-core`'s `core/hooks/lib/gate-lib.sh`,
  `core/hooks/lib/gate-lib.py`, `docs/handbooks/gate-house-standard.md`,
  and `core/hooks/tests/compliance-check.sh` (`gh api` reads this session,
  confirming core issue #72 landed before adoption).
- This session's own file writes/edits: `qa/plugins/eo-methodology-gate/
  hooks/methodology-gate.sh`, `qa/plugins/eo-state/hooks/state.sh`,
  `tests/run-gate-tests.sh`, `tests/fetch-core.sh` (new),
  `qa/plugins/eo-methodology-gate/README.md`,
  `docs/handbooks/execution-observation-plugins.md`, `.gitignore`
  (`/core/` added), `.warrant-hunt.count` (removed) — all read back after
  edit this session.
- Test runs this session: `bash tests/run-gate-tests.sh` (23/23 pass, 0
  fail), `bash tests/parse-check.sh qa` (4/4 files parse clean under
  bash 3.2), `bash tests/stub-check.sh qa` (all checks ok), and core's
  `compliance-check.sh qa/plugins/eo-methodology-gate` (ok, zero
  violations) — run against a real network-fetched checkout of
  `tokenmaxxxer-core` cached under `$TMPDIR`.
