# execution-observation

The execution-observation role on contract v3 (`docs/specs/role-handoff-contract.md`
§19): judge whether an observed role's phase-1→phase-2 execution was sound
by reading its actual artifacts (PR diff, commits, its own record) — never
by re-executing the observed task. Every verdict cites evidence (a commit
SHA, `file:line`, or PR comment URL). This role never edits the observed
artifact and never files issues; confirmed deficiencies return as findings
in its own record via its own PR, and the user files the issue if valid.

## What it ships

- `hooks/directive.sh` — `UserPromptSubmit`. States the core lifecycle
  directive for this role (you_decide/use_when/produces/hand_off), deepened
  per-facet by `eo-directive`.
- `hooks/hooks.json` — wires `directive.sh` and `eo-state`'s session reset
  to `SessionStart`.
- `plugins/eo-directive` — per-facet phase-1/phase-2 judgment criteria:
  what counts as a valid citation, what disqualifies a scope statement,
  what a proposal may not yet say, what a record must say and in what
  order.
- `plugins/eo-methodology-gate` — mechanical `PreToolUse` verification
  that a written execution-observation proposal or record actually
  contains the elements `eo-directive` requires, fail-closed, scoped to
  this role's own write surfaces only.
- `plugins/eo-state` — session-scoped marker enforcing that a phase-2
  record is never written before at least one artifact of the observed
  target has been read this session.

## Record

`docs/issue-<n>/reports/execution-observation.md`, phase-gated per contract
v3 §19: written as the first act of phase 2, updating `loop_state` at
every transition. Phase-1 output (current-state survey, proposal) lives
under `docs/issue-<n>/reports/execution-observation/` and
`docs/issue-<n>/proposals/`.
