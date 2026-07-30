# issue-35 coding record

loop_state: landed
code_under_review: (see PR diff, branch issue-35/coding)

## why
Issue #35: rulebook text (`qa/hooks/directive.sh`) still carried
routing-side vocabulary — "YOUR RECORD IS THE BOARD", "never reached
the board", a pointer to `docs/specs/wake-routing.md`. The wake
mechanism and who reads a record to route to the next role is
on-the-record's canon, not this rulebook's business. Upstream basis:
docs/issue-35/proposals/coding-proposal.md, approved via
`APPROVE issue-35/coding` (single-account mode, contract v3 s19) per
this session's invocation.

## upstream basis
docs/issue-35/proposals/coding-proposal.md (approved), applied on top
of commit ea02607 (phase-1 survey + proposal).

## what was done
Applied the approved proposal exactly: reworded the "YOUR RECORD IS THE
BOARD" paragraph in `qa/hooks/directive.sh` (previously lines 58-65) to
a pure record-format requirement.

- Kept: record is the sole phase-2 artifact that matters; write it as
  the first act of phase 2; keep loop_state current at every
  transition; must be committed on the branch.
- Dropped entirely: "YOUR RECORD IS THE BOARD" heading/framing, "never
  reached the board", "board empty", and the pointer to
  `docs/specs/wake-routing.md` — no mention of wake, waking,
  board-as-routing, WAKES-ON, downstream roles, or where routing canon
  lives.

## Confirmation run (no-mock: actually executed)
- `grep -niE "wake|WAKES-ON|downstream" qa/hooks/directive.sh` → no
  output.
- `grep -n "board" qa/hooks/directive.sh` → no output.
- `bash tests/parse-check.sh` → all 4 hooks `ok`, exit 0. Heredoc
  integrity unchanged.

## What did not work
(none — single mechanical edit, applied and verified in one pass)

## Hunt cadence
Scout/hunt not applicable this phase: scope-frozen, single-paragraph
mechanical vocabulary strip with no design surface (see proposal's
scout-skip record). No warrant-hunter dispatch needed beyond the
parse-check already run.

## Out of scope (unchanged from proposal)
- `docs/issue-33/`, `docs/proposals/`, `docs/reports/`,
  `docs/decisions/` — historical, untouched.
- `qa/README.md` — no routing vocabulary present.
- Any file outside `qa/hooks/directive.sh`.
- Creating/editing/referencing `docs/specs/wake-routing.md`.

## closed_checks
- name: wake-grep-clean, code_sha: (branch head after this commit)
- name: board-grep-clean, code_sha: (branch head after this commit)
- name: parse-check, code_sha: (branch head after this commit)

## open findings
None outstanding. No blocking finding was addressed to this role prior
to this commit; this record is terminal (loop_state: landed).
