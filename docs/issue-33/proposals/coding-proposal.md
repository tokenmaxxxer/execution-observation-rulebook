# issue-33 build proposal (coding, phase 1)

files: `qa/hooks/directive.sh`

## Scout skip record
Skipped — spec leaves no design decision open. This is a mechanical
routing-reference removal per an already-made operator decision (wake-
routing ownership migration step 3); there is no product-shaped or
best-in-class field to survey.

## Request (paraphrased intent)
Wake-routing ownership has moved to the on-the-record repo's
`docs/specs/wake-routing.md`. This repo's rulebook (the `qa` plugin) must
stop restating which role a record state summons. Keep only this role's
own record states/format; strip or repoint anything naming which role a
state wakes.

## Constraints
- Phase 1 only this session: survey + proposal, open the PR, stop. No
  edits to `qa/hooks/directive.sh` happen in this session (contract v3
  s19); no APPROVE by any role (s19).
- Output layout: code under `src/`, tests under `test/`, docs under
  `docs/` — this change touches neither `src/` nor `test/` (`qa/` is the
  plugin tree, not `src/`; pre-existing repo layout, unaffected by this
  issue).
- Do not touch `docs/proposals/2026-07-27-*.md` or
  `docs/proposals/2026-07-26-*.md` — dated historical decision records,
  not live rulebook; rewriting them would falsify the record of what was
  decided when.

## What will be done (phase 2, after human APPROVE)
In `qa/hooks/directive.sh`, reword the "YOUR RECORD IS THE BOARD"
paragraph (lines 58-65):

- Keep: record is the sole phase-2 artifact that matters; write it as
  the first act of phase 2; keep `loop_state` current at every
  transition; a record never committed to the branch means the work
  never reached the board.
- Drop: "WAKES-ON reads docs/issue-<n>/reports/qa.md ONLY" and "no
  downstream role can ever be woken by it" — these name which file/role
  a state summons, which is routing canon, not role format.
- Repoint: point readers to on-the-record `docs/specs/wake-routing.md`
  for the actual wake-routing rule, by filename only — no role name
  stated in this rulebook.

Sanity check in phase 2: re-run `tests/parse-check.sh` (heredoc still
parses as valid bash) since the edit is inside a `cat <<'DIRECTIVE'`
block.

## Out of scope
- `docs/proposals/2026-07-26-contract-v2-conformance.md` and
  `docs/proposals/2026-07-27-repo-local-contract-file.md` — historical
  proposals, left untouched.
- Any file outside `qa/hooks/directive.sh` — grep found no other
  WAKES-ON mention in live rulebook files.
- Creating or editing `docs/specs/wake-routing.md` itself — that file
  lives in the on-the-record repo per the issue, not here.

## How it'll be known to work
- `grep -n -i "wakes" qa/hooks/directive.sh` shows no remaining claim of
  which role/file a state wakes — only a pointer to
  `docs/specs/wake-routing.md` and this role's own record-first
  obligation.
- `tests/parse-check.sh` still passes (heredoc integrity unchanged).
