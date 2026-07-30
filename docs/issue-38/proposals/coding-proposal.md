# issue-38 build proposal (coding, phase 1)

files: `qa/hooks/directive.sh`

## Scout skip record
Skipped — the issue supplies the reference wording verbatim (ux-design-
rulebook `ux-design/hooks/directive.sh` RECORD FORMAT section, post
issue-12 state); no design decision is open.

## Request (paraphrased intent)
This repo's `qa` role directive has a RECORD REQUIREMENTS section that
already names the record's location and phase-2-first/loop_state
obligations, but lacks the strong-form enforcement clause and its
measured-evidence citation already present in the sibling
feasibility/verify/reflect/ux-design directives' RECORD sections. Add
those two clauses; change nothing else about the section.

## Constraints
- Phase 1 only this session: survey + proposal, open the PR, stop. No
  edit to `qa/hooks/directive.sh` happens in this session (contract v3
  s19); no APPROVE by any role (s19).
- Wording-strength alignment only — the existing role-specific record
  fields (file path `docs/issue-<n>/reports/qa.md`, "sole phase-2
  artifact" framing, first-act-of-phase-2 instruction, loop_state-
  current instruction) stay unchanged, per the issue.
- Output layout: docs under `docs/` (this issue), rulebook edit under
  `qa/` — pre-existing repo layout, unaffected.

## What will be done (phase 2, after human APPROVE)
In `qa/hooks/directive.sh`, RECORD REQUIREMENTS paragraph (lines
58-65): keep every existing sentence, and append the two strong-form
clauses in the style of the cited sibling directives:

- An enforcement clause: "Ending phase 2 without your record committed
  on the branch means the record was never written."
- Its measured-evidence citation: "(Measured: a phase-1-only issue left
  the record empty.)"

Sanity check in phase 2: re-run `tests/parse-check.sh` (heredoc still
parses as valid bash) since the edit is inside a `cat <<'DIRECTIVE'`
block.

## Out of scope
- Any other section of `qa/hooks/directive.sh` (YOU DECIDE, RESEARCH,
  CURRENT-STATE SURVEY, PROPOSAL, EXECUTION JUDGMENT) — untouched.
- Any file outside `qa/hooks/directive.sh` — this repo has no other
  live role-directive file.
- Defining a `coding`-role directive in this repo — none exists here;
  out of scope per issue-33's prior survey finding.

## How it'll be known to work
- `grep -n "Ending phase 2 without your record committed" qa/hooks/directive.sh`
  shows the new enforcement sentence in the RECORD REQUIREMENTS
  section.
- `grep -n "Measured:" qa/hooks/directive.sh` shows the new
  parenthetical citation.
- `tests/parse-check.sh` still passes (heredoc integrity unchanged).
