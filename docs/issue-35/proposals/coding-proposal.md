# issue-35 build proposal (coding, phase 1)

files: `qa/hooks/directive.sh`

## Scout skip record
Skipped — spec leaves no design decision open. See
`docs/issue-35/reports/coding/survey.md`.

## Request (paraphrased intent, secrets stripped)
`qa/hooks/directive.sh` still frames the record obligation as a routing
device ("YOUR RECORD IS THE BOARD", "never reached the board", a
pointer to `docs/specs/wake-routing.md`). Routing — the wake mechanism,
who reads a record, board-as-routing-device — is on-the-record's canon,
not this rulebook's business. Restate the same obligation purely as a
record-format requirement: path, when to write it, what to keep
current, and that it must be committed on the branch. Drop every
mention of wake/waking/board-as-routing/WAKES-ON/downstream roles and
the pointer to `docs/specs/wake-routing.md`.

## Constraints
- Phase 1 only this session: survey + proposal, open the PR, stop. No
  edits to `qa/hooks/directive.sh` happen in this session (contract v3
  s19); no APPROVE by any role (s19).
- Historical docs untouched: `docs/issue-33/**`, `docs/proposals/**`,
  `docs/reports/**`, `docs/decisions/**` keep their routing vocabulary
  as-is — they are dated records of what was decided/found when, not
  live rulebook.
- `qa/README.md:23` ("blackboard record (`qa.md`)") is unaffected — it
  names the record file, not a routing mechanism, and carries no
  wake/board-as-routing/downstream/wake-routing.md language.
- Output layout: docs under `docs/` only — this change touches neither
  `src/` nor `test/`.

## What will be done (phase 2, after human APPROVE)
In `qa/hooks/directive.sh`, replace the "YOUR RECORD IS THE BOARD"
paragraph (lines 58-65) with a record-format-only restatement:

- State the path (`docs/issue-<n>/reports/qa.md`) and that it is the
  sole phase-2 artifact that matters (research files, surveys, and
  proposals are not it).
- State it must be written as the first act of phase 2.
- State `loop_state` must be kept current at every transition.
- State the record must be committed on the branch — an uncommitted
  record counts as not written.
- Drop entirely: "YOUR RECORD IS THE BOARD" heading/framing, "never
  reached the board", "board empty", and the pointer to
  `docs/specs/wake-routing.md` — no mention of wake, waking,
  board-as-routing, WAKES-ON, downstream roles, or where routing canon
  lives.

Sanity check in phase 2: re-run `tests/parse-check.sh` (heredoc still
parses as valid bash) since the edit is inside a `cat <<'DIRECTIVE'`
block.

## Out of scope
- Any file under `docs/issue-33/`, `docs/proposals/`, `docs/reports/`,
  `docs/decisions/` — historical, left untouched.
- `qa/README.md` — no routing vocabulary present, no change needed.
- Any file outside `qa/hooks/directive.sh` — the sweep (see survey.md)
  found no other live rulebook file with wake/WAKES-ON/board-as-
  routing/downstream vocabulary.
- Creating, editing, or referencing `docs/specs/wake-routing.md` — that
  file is on-the-record's canon; this rulebook no longer names it at
  all, not even as a pointer.

## How it'll be known to work
- `grep -niE "wake|WAKES-ON|downstream" qa/hooks/directive.sh` returns
  no output.
- `grep -n "board" qa/hooks/directive.sh` returns no output.
- `tests/parse-check.sh` still passes (heredoc integrity unchanged).
