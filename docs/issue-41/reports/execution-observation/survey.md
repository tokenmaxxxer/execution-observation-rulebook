# issue-41 current-state survey (execution-observation, phase 1)

## What this repo actually contains today
`origin` is `tokenmaxxxer/execution-observation-rulebook`, but the tree
is still the unmodified `qa-agent-rulebook` template: README title,
`qa/` plugin, and `qa/hooks/directive.sh` all describe the **qa** role
(launch-and-exercise, pass/fail verdicts), not execution-observation.
`find . -iname '*directive*'` finds exactly one live role directive,
`qa/hooks/directive.sh`; no `execution-observation`-specific plugin,
directive, or command exists anywhere in the tree. This matches how
prior "rulebook maturation" issues in this template state (issue-33/35/
38, run under a `coding` session role) proceeded: research + propose
against whatever directive file is live, without first fixing the
template mismatch — that mismatch is out of scope for issue-41, which
only asks for phase-1 norms + a reflection plan.

## Core-provided plumbing already in place (per issue-42's PR #44, merged)
- `qa/hooks/directive.sh` is a thin stub delegating to core's
  `core_role_directive` (`role-directive.sh`), taking four verbatim
  text blocks: `you_decide`, `use_when`, `produces`, `hand_off`.
- Three role-agnostic gates are registered globally by core (not
  vendored here): trailer gate (`Subject: issue-<n>` on
  `docs/issue-<n>/**` commits), handbook-trigger gate, and
  `record-fields-gate.sh` (s20 minimum record content), the last
  configurable per role via `RECORD_FIELDS_TERMINAL_STATES`.
- `docs/specs/approvers.md` lists `JiwonJung94` as the sole approver.

## What execution-observation lacks, concretely
1. No role directive text (YOU DECIDE / RESEARCH / CURRENT-STATE
   SURVEY / PROPOSAL / EXECUTION JUDGMENT / RECORD REQUIREMENTS) framed
   for observing *other roles'* execution sessions rather than testing
   a target app.
2. No required-field set for what an execution-observation phase-2
   record (`docs/issue-<n>/reports/execution-observation.md`) must
   contain — qa's record vocabulary (item states, pass/fail/blocked,
   severity/priority) is test-specific and does not fit an audit-of-
   execution deliverable.
3. No evidence/verdict vocabulary distinguishing outcome-level,
   trajectory-level, and step-level judgments (see scout-brief.md) —
   qa's directive judges only pass/fail/blocked against a target app.
4. `RECORD_FIELDS_TERMINAL_STATES` is unset for this role; core's
   default (`landed`) does not fit any vocabulary this role would use.

## warrant-hunter constraint (per issue text)
No `agents/warrant-hunter.md` or hunt-cadence text exists in this repo
(confirmed by issue-42's survey, still true) — nothing to convert to a
reference here. The issue's instruction to reference core canon rather
than copy applies going forward: phase 2 of this issue must not vendor
a warrant-hunter copy into this repo.

## Write surfaces phase 2 will touch (per the proposal)
- A new role-directive body (still delivered through
  `qa/hooks/directive.sh`'s existing `core_role_directive` stub
  mechanism, since that is the only wired SessionStart hook — renaming
  the plugin/directory is a template-fix concern, out of scope here)
  updated in place with execution-observation-specific `you_decide`/
  `use_when`/`produces`/`hand_off` text.
- `RECORD_FIELDS_TERMINAL_STATES` set for this role's own terminal
  vocabulary.
- No new gate script needed — core's existing `record-fields-gate.sh`
  and trailer/handbook gates are role-agnostic per issue-42; this
  role's requirements slot into their existing configuration surface.

## Gaps this survey aims scout at
Thin/unknown surfaces going into the sweep: (a) what methodology this
domain expects for *observing execution* (not testing), (b) what a
credible observation/audit deliverable must contain, (c) how outcome-
only verdicts fail compared to established practice. scout-brief.md
covers these.
