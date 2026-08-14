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
every transition using the state names
`roles/specs/execution-observation.spec.json` (`tokenmaxxxer/on-the-record`)
declares — `running`/`collecting-evidence` in progress, `handed-off`
terminal, `execution-not-possible` refusal, `environment-setup-failed`
error. Each `step`-level finding in the record cites the spec's per-claim
fields (`subject`, `test`, `result`, `assertedBy`, `mode`); `outcome` is
the spec's worst-case recomputation across a record's cited `step`-level
results, never a standalone summary. Phase-1 output (current-state
survey, proposal) lives under
`docs/issue-<n>/reports/execution-observation/` and
`docs/issue-<n>/proposals/`.

Two admissibility rules narrow what a citation is allowed to support:
a `file:line` is evidence only when the line sits inside a hunk the
observed PR's diff actually changed (a line merely in a changed file,
outside any changed hunk, is context and must be logged as such, never
cited as a finding's basis); and the per-claim `mode` field records how
the citation was obtained — `read`, `command`, or `asserted` — where an
`asserted` citation (the observed role's own record, unverified here)
can only support `cantTell`/`untested`, never `passed`/`failed` — and
its verdict sentence must say so inline ("unverified, per the observed
role's own record"), not rely on a reader cross-referencing the `mode`
field. The trajectory verdict is likewise three named pass/fail/not-
applicable checks (scouted-when-required, surveyed-before-proposing,
approved-by-human), never one holistic call. The current-state survey
itself reads the observed PR's diff and commits before the observed
role's own record narrative, so its scope statement is built from the
artifact rather than anchored on that role's self-framing.
