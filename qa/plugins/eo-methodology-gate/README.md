# eo-methodology-gate

Mechanical `PreToolUse` verification that a written execution-observation
proposal or record actually contains the elements `eo-directive` requires.
Path-scoped to this role's own two write surfaces only; every other path
is out of scope for this gate and is allowed through untouched.

## What it ships

- `hooks/methodology-gate.sh` — `PreToolUse` on `Write|Edit|MultiEdit`.
  Reconstructs the post-write content of the target file (full content for
  `Write`; simulated replacement against on-disk content for `Edit`/
  `MultiEdit`) and checks it against one of two required-element lists,
  depending on which write surface it targets:
  - **Proposal surface** (`docs/issue-<n>/proposals/*execution-observation*.md`):
    requires a `## Scope` heading, an issue/PR number, a current-state-survey
    path reference, a stated verdict-level plan, and a plugin-list section —
    and prohibits any premature verdict language (phase-1 proposals must not
    yet render a verdict).
  - **Record surface** (`docs/issue-<n>/reports/execution-observation.md`):
    requires an independence statement to appear before any verdict
    language, all three verdict levels (outcome/trajectory/step), the
    four-part blameless shape whenever a deficiency is claimed, and
    `eo-state`'s per-session read marker to be present on disk.
  Any other path is not this gate's business and is allowed through
  (`sys.exit(0)`).

## Fail-closed

A `trap ... EXIT` guard is the first executable statement. Any internal
error (unparseable payload, unresolvable content, unexpected exception)
denies (`exit 2`) rather than allowing a write it could not judge.

## Kill switch

`EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF=1` disables the gate. Unset,
empty, `0`, `false`, `no`, `off` all mean "not disabled" (the gate runs).
