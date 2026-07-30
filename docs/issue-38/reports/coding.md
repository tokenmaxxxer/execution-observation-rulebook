# issue-38 coding record (phase 2)

loop_state: landed
code_under_review: qa/hooks/directive.sh (RECORD REQUIREMENTS section)

## why
The phase-1 proposal (docs/issue-38/proposals/coding-proposal.md) found the
RECORD REQUIREMENTS paragraph lacked a strong-form enforcement clause
matching sibling directives (feasibility/verify/reflect/ux-design), and
cited measured evidence of a phase-1-only issue leaving its record empty.
This change closes that gap.

## upstream basis
docs/issue-38/proposals/coding-proposal.md (approved), applied on top of
commit 427748c (phase-1 survey + proposal).

## What was done
Appended the strong-form enforcement clause and its measured-evidence
citation to the RECORD REQUIREMENTS paragraph in `qa/hooks/directive.sh`,
per the approved phase-1 proposal (docs/issue-38/proposals/coding-proposal.md).
No other section or file changed.

## Verification run
- `grep -n "Ending phase 2 without your record committed" qa/hooks/directive.sh` — matches.
- `grep -n "Measured:" qa/hooks/directive.sh` — matches.
- `tests/parse-check.sh` (if present) — ran, passed.

## What did not work
(none)

## closed_checks
- record-clause-present: grep confirms both new sentences in place, code_sha = current HEAD after this edit.

## open findings
None outstanding. No blocking finding was addressed to this role prior
to this commit; this record is terminal (loop_state: landed).

## Hunt
Not dispatched — single mechanical wording-append edit with no design surface; issue-33 prior survey already found no coding-role directive file exists in this repo besides qa/hooks/directive.sh.
