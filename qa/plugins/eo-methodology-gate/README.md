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

Both required-element lists are checked structurally (heading, list-item, or
labeled-line position), not by bare substring: a verdict-level-plan section
requires each level word to appear adjacent to a `:`/`—`/`-` marker inside a
heading-matched section, a plugin-list heading must have an actual markdown
list item under it, and the record's blameless-shape check (gated on a
deficiency/finding mention) requires its four components to appear as a
heading or bold-labeled line within the triggering section or the five lines
following the mention — a document that only *mentions* these words in prose
no longer passes.

## Gate-lib

Sources `core/hooks/lib/gate-lib.sh` (bash) and loads `gate-lib.py` via
`importlib` (Python payload) — the gate-house standard library (core
issue-72, `docs/handbooks/gate-house-standard.md`) — instead of hand-rolling
the trap/kill-switch/path-normalize/reconstruct machinery. Reference only,
never copied (`docs/handbooks/canon-scripts.md`). Resolves the core plugin
root the same way `qa/hooks/directive.sh` does: `CLAUDE_PLUGIN_ROOT_CORE` if
set, else a `core` checkout sibling to this repo's own root.

## Fail-closed

`gate_trap_fail_closed` installs the one canonical `trap ... EXIT` guard as
the first executable statement (after sourcing gate-lib.sh). Any internal
error (unparseable payload, unresolvable content, unexpected exception)
denies (`exit 2`) rather than allowing a write it could not judge. Malformed
JSON (truncated, non-object top level, empty payload) denies via
`gate_lib.gate_parse_json_or_deny` rather than passing through.

Path matching (absolute, relative, and `./`-prefixed `file_path`) is
normalized via `gate_lib.gate_normalize_path` to the same root-relative tail
regardless of the input form. `Edit`/`MultiEdit` content reconstruction goes
through `gate_lib.gate_reconstruct_write`, which honors each edit's own
`replace_all` flag independently — the old hand-rolled reconstruction always
replaced only the first occurrence, ignoring `replace_all`.

## Kill switch

`EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF=1` disables the gate via
`gate_lib.gate_kill_switch_active`: only a recognized on-spelling
(`1`/`true`/`yes`/`on`, case-insensitive) disables it. Unset, empty, a
recognized off-spelling, **or any unrecognized value (including a typo)**
all mean "not disabled" (the gate stays active) — the fixed convention that
reverses the confirmed bug where any unrecognized value silently disabled
the gate.
