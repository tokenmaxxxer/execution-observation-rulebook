# execution-observation plugin set handbook

Current state of the three plugins issue-47 added under `qa/plugins/`,
composed alongside the pre-existing `qa` plugin (unchanged: still owns
`commands/` and the `directive.sh`/`hooks.json` sourcing stub).

## `eo-directive`

Supplies the four role-directive body variables (`you_decide`,
`use_when`, `produces`, `hand_off`) as an executable subprocess,
`hooks/directive-body.sh <name>`, invoked from `qa/hooks/directive.sh`
via command substitution (`VAR="$(...)"`), one call per variable — not
a `source` line, so `qa/hooks/directive.sh` stays inside
`tests/stub-check.sh`'s structural stub cap (that check whitelists only
a `role-directive.sh` source line, plain `VAR=` assignments, and the
final `core_role_directive` call). No hook of its own; no independent
kill switch beyond `QA_CYCLE_OFF`, which already gates
`qa/hooks/directive.sh`.

## `eo-methodology-gate`

`hooks/methodology-gate.sh`, a `PreToolUse` gate on `Write|Edit|MultiEdit`
(own `hooks.json`), fail-closed, kill switch
`EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF`. Path-scoped to two write
surfaces only:

- `docs/issue-<n>/proposals/*execution-observation*.md` (phase-1
  proposals) — requires `## Scope`, an issue/PR number, a
  current-state-survey path reference, a two-of-three verdict-level
  mention, and a plugin-list section; denies if premature verdict
  language (`outcome: sound`, etc.) already appears.
- `docs/issue-<n>/reports/execution-observation.md` (phase-2 record) —
  requires the independence statement to appear before any verdict
  language (ordering, not just presence), all three verdict levels
  present, the four-part blameless shape when a deficiency/finding is
  claimed, and `eo-state`'s marker file present on disk.

Any other path is out of scope for this gate (`sys.exit(0)`).

## `eo-state`

`hooks/state.sh`, exposing `eo_state_marker_path()` and two subcommands
when invoked directly: `reset` (removes the marker; run at
`SessionStart` from both `qa/hooks/hooks.json` and this plugin's own
`hooks.json`) and `mark` (run from a `PostToolUse` `Read|Bash` matcher;
best-effort — sets the marker when the tool payload plausibly touches
another role's artifact path or a `gh api`/`gh pr` command). Marker
path: `<git-toplevel>/.claude/.eo-read-marker`. No `PreToolUse` gate of
its own — `eo-methodology-gate` is the only plugin that reads the
marker's existence.

## Tests

`tests/run-gate-tests.sh` carries 10 `eo-*` cases (real subprocess
invocation of `eo-methodology-gate/hooks/methodology-gate.sh`, synthetic
`PreToolUse` JSON on stdin, tempdir `git init`): proposal
complete/missing-survey/missing-plugin-list/premature-verdict, record
complete/order-violation/blameless-incomplete/no-marker/with-marker, and
a foreign-path allow confirming the gate stays out of other roles' write
surfaces.
