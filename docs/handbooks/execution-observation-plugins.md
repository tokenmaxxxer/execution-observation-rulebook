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
  current-state-survey path reference, a verdict-level-plan section
  (heading matching `verdict-level`/`plan`, with >=2 of
  outcome/trajectory/step each adjacent to a `:`/`—`/`-` marker inside
  that section's body — not just mentioned anywhere in the document),
  and a plugin-list section (heading matching 플러그인 목록/plugin
  list/plugin 목록, with an actual markdown list item under it); denies
  if premature verdict language (`outcome: sound`, etc.) already
  appears.
- `docs/issue-<n>/reports/execution-observation.md` (phase-2 record) —
  requires the independence statement to appear before any verdict
  marker (ordering, not just presence), all three verdict levels
  present as markers (`outcome:`, not a bare "outcome" mention), the
  four-part blameless shape (heading or bold-labeled line, within the
  triggering section or the five lines after it) when a
  deficiency/finding is claimed, and `eo-state`'s marker file present
  on disk.

Any other path is out of scope for this gate (`sys.exit(0)`).

The spec fields (`subject`/`test`/`result`/`assertedBy`/`mode`) and the
`loop_state` state names (`running`/`collecting-evidence`/`handed-off`/
`execution-not-possible`/`environment-setup-failed`) that
`roles/specs/execution-observation.spec.json` (`tokenmaxxxer/on-the-record`)
declares are the canonical vocabulary this gate's structural checks track
— `outcome`/`trajectory`/`step` markers stay this gate's own structural
check, but the evidence a `step`-level finding cites is expected in that
per-claim shape. Reference-resolution enforcement (whether a cited
`assertedBy`/source actually resolves) lives upstream in
`on-the-record/hooks/role-spec-reference-guard.sh`, referenced here, never
forked into this gate.

Migrated onto the gate-house standard library (core issue-72,
`docs/handbooks/gate-house-standard.md`): sources `core/hooks/lib/
gate-lib.sh` and loads `gate-lib.py` via `importlib`, replacing the
former hand-rolled trap/kill-switch/path-normalize/reconstruction
logic with `gate_trap_fail_closed`, `gate_kill_switch_active`,
`gate_normalize_path`, `gate_parse_json_or_deny`, and
`gate_reconstruct_write` — reference only, never copied
(`docs/handbooks/canon-scripts.md`). This closed four confirmed
defects: the kill switch previously disabled on any unrecognized
value (now only a recognized on-spelling disables it); `Edit`/
`MultiEdit` reconstruction previously always replaced only the first
occurrence, ignoring `replace_all`; a malformed-JSON payload at the
target-extraction stage previously passed through silently instead of
denying; and absolute/`./`-prefixed `file_path` values were normalized
by a hand-rolled bash+python mix instead of the shared, tested
`gate_normalize_path`.

## `eo-state`

`hooks/state.sh`, exposing `eo_state_marker_path()` and two subcommands
when invoked directly: `reset` (removes the marker; run at
`SessionStart` from both `qa/hooks/hooks.json` and this plugin's own
`hooks.json`) and `mark` (run from a `PostToolUse` `Read|Bash` matcher;
best-effort — sets the marker when the tool payload plausibly touches
another role's artifact path or a `gh api`/`gh pr` command). Marker
path: `<git-toplevel>/.claude/.eo-read-marker`. No `PreToolUse` gate of
its own — `eo-methodology-gate` is the only plugin that reads the
marker's existence. Its own kill switch (`EXECUTION_OBSERVATION_STATE_OFF`)
is likewise migrated to `gate_lib.gate_kill_switch_active`; it has no
reconstruction/path-normalize logic to migrate (not a `PreToolUse` gate).

## Install

`install.sh` at the repo root registers the `tokenmaxxxer-execution-observation`
marketplace (source `tokenmaxxxer/execution-observation-rulebook`) and
installs/updates the `execution-observation` bundle plus each `eo-*`
plugin explicitly, at user scope. It is a plain rename target: its
`MARKET`/`BUNDLE`/`GITHUB_REPO` variables and closing-banner text must be
kept in sync with the marketplace/plugin names above whenever either
changes — issue #56 found `install.sh` still carrying the old `qa`/
`tokenmaxxxer-qa` names after the `qa/` → `execution-observation/`
directory rename, since the two are not otherwise coupled by anything
that would fail loudly.

## Tests

`tests/run-gate-tests.sh` resolves a core canon checkout via
`tests/fetch-core.sh` (a real plugin install via `CLAUDE_PLUGIN_ROOT_CORE`,
a local `core` sibling checkout, or a cached shallow clone under `$TMPDIR`
— never vendored into this repo) and exports it as
`CLAUDE_PLUGIN_ROOT_CORE` so `eo-methodology-gate`/`eo-state` can source
the real `gate-lib.sh`. It carries the `eo-*` cases (real subprocess
invocation of `eo-methodology-gate/hooks/methodology-gate.sh`, synthetic
`PreToolUse` JSON on stdin, tempdir `git init`): proposal
complete/missing-survey/missing-plugin-list/premature-verdict/mention-
only-no-structure, record complete/order-violation/blameless-incomplete/
blameless-complete/no-marker/with-marker/bare-sound-prose, a foreign-path
allow, and the issue's six mandatory case groups — `Edit` with
`replace_all` against a multiply-occurring match, `MultiEdit` with mixed
`replace_all` true/false in one call, malformed JSON (truncated,
non-object, empty), a kill-switch typo staying active vs. a recognized
on-value disabling it, absolute/`./`-prefixed `file_path` resolving to
the same verdict as the relative-path fixture, and (issue-53) a
missing-core case — `CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent
path with no valid relative fallback — asserting the guarded
`gate-lib.sh` source line denies (exit 2), mirroring core #75's own
mandatory group 7. The dead `record-fields-gate.sh`/`trailer-gate.sh`
cases (7, 2 already `true ||`-disabled) that exercised files no longer
present in this repo (core canon now, per `tests/stub-check.sh`) are
removed rather than fixed.

Both `state.sh` and `methodology-gate.sh` source `gate-lib.sh` with the
`||`-guarded form core #75 landed (`. ".../gate-lib.sh" || { echo
"<gate>: cannot source gate-lib.sh" >&2; exit 2; }`), verified clean by
core #75's own `compliance-check.sh` (issue-53).
