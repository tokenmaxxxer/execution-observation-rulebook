# issue-38 current-state survey (coding, phase 1)

## Scout skip record
Skipped — reference wording is given verbatim in the issue
(ux-design-rulebook `ux-design/hooks/directive.sh` RECORD FORMAT
section, post issue-12 state); no design decision is open.

## The only live rulebook file in this repo
`qa/hooks/directive.sh` is the sole role directive defined in this
repo (`find -iname '*directive*'` under the repo tree returns only this
file plus unrelated dated docs/reports). No `coding`-role directive
file exists here — this session's own `[coding]` role directive is
supplied by tooling outside this repo's tree (confirmed by issue-33's
survey, still true). So "the role directive" the issue means is this
repo's own role: `qa`.

## Current RECORD section (lines 58-65)
```
RECORD REQUIREMENTS (do not skip this): docs/issue-<n>/reports/qa.md is
the sole phase-2 artifact that matters — research files, surveys, and
proposals are not it. Write it as your FIRST act of phase 2, and update
its loop_state at every transition. The record must be committed on the
branch — an uncommitted record counts as not written.
```

This already has: file location, "sole phase-2 artifact" framing,
first-act-of-phase-2 instruction, loop_state-current instruction, and
one enforcement sentence ("an uncommitted record counts as not
written"). What it lacks, per the issue, are the two strong-form
clauses present in feasibility/verify/reflect/ux-design's RECORD
sections:

1. An explicit "ending phase 2 without your record committed on the
   branch means X" enforcement clause (the closest existing sentence
   already gestures at this but doesn't use that exact framing).
2. A parenthetical measured-evidence citation, e.g.
   `(Measured: a phase-1-only issue left the record empty.)`.

Cross-repo comparison of the four cited sibling directives'
RECORD sections confirms the pattern (each pairs an "ending phase 2
without your record committed... means <record-state>" sentence with a
`(Measured: ...)` parenthetical) — wording differs per role but the two
clauses are present in all four.

## Write set for phase 2
- `qa/hooks/directive.sh` — reword the RECORD REQUIREMENTS paragraph
  (lines 58-65) to add the enforcement clause and its measured-evidence
  citation, keeping the existing role-specific fields (file path,
  "sole phase-2 artifact", first-act-of-phase-2, loop_state) unchanged
  per the issue's instruction that this is a wording-strength
  alignment, not a format change.

No other files change. No tests, deps, or env vars are touched (prose-
only edit inside a `cat <<'DIRECTIVE'` heredoc) — `tests/parse-check.sh`
should be re-run in phase 2 as a sanity check that the heredoc still
parses.
