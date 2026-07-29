# issue-33 coding record

loop_state: landed
code_under_review: (see PR #34 diff, branch issue-33/coding)

## why
Operator decision 2026-07-30 (wake-routing ownership migration step 3):
routing canon (which record state summons which role) now lives at
on-the-record `docs/specs/wake-routing.md`; this rulebook must contain
nothing about which role wakes next. Issue #33 asked to audit every
WAKES-ON/wake mention in this repo's rulebook files and strip or
repoint anything naming which role a state summons, keeping only this
role's own record states/format. Upstream basis:
docs/issue-33/proposals/coding-proposal.md, approved via
`APPROVE issue-33/coding` (single-account mode, contract v3 s19) per
this session's invocation.

## upstream basis
docs/issue-33/proposals/coding-proposal.md (approved), applied on top
of commit d8d0677 (phase-1 survey + proposal).

## what was done
Applied the approved proposal exactly: reworded the "YOUR RECORD IS THE
BOARD" paragraph in `qa/hooks/directive.sh` (previously lines 58-65).

- Kept: record is the sole phase-2 artifact that matters; write it as
  the first act of phase 2; keep loop_state current at every
  transition; a record never committed to the branch means the work
  never reached the board.
- Dropped: "WAKES-ON reads docs/issue-<n>/reports/qa.md ONLY" and "no
  downstream role can ever be woken by it" — routing claims naming
  which file/role a state summons.
- Repointed: added a pointer to `docs/specs/wake-routing.md` by
  filename only, for the actual wake-routing rule — no role name
  restated in this rulebook.

## Confirmation run (no-mock: actually executed)
- `grep -n -i "wakes" qa/hooks/directive.sh` → no output: no remaining
  role/file routing claim in the file.
- `bash tests/parse-check.sh` → `ok directive.sh` (and the other 3
  hooks), exit 0. Heredoc integrity unchanged.

## What did not work
(none — single mechanical edit, applied and verified in one pass)

## Hunt cadence
Scout/hunt not applicable this phase: this was a scope-frozen, single-
paragraph mechanical reword with no design surface (see
docs/issue-33/proposals/coding-proposal.md's scout-skip record). No
warrant-hunter dispatch — nothing to probe beyond the parse-check
already run.

## Out of scope (unchanged from proposal)
- Historical dated proposal docs, left untouched.
- Any file outside `qa/hooks/directive.sh`.
- `docs/specs/wake-routing.md` itself — lives in the on-the-record
  repo.

## closed_checks
- name: parse-check, code_sha: (branch head after this commit)
- name: wakes-grep-clean, code_sha: (branch head after this commit)

## open findings
None outstanding. No blocking finding was addressed to this role prior
to this commit; this record is terminal (loop_state: landed).
