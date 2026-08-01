# issue-53 gate A+ closeout proposal (execution-observation, phase 1)

## Scope

Target: this repo (`execution-observation-rulebook`), issue #53, PR
against `main` from `issue-53/execution-observation`. Files this
proposal's design touches in phase 2 (not this session): `qa/hooks/
hooks.json`, `tests/deny-only-check.sh`, `README.md`,
`qa/plugins/eo-state/hooks/state.sh`,
`qa/plugins/eo-methodology-gate/hooks/methodology-gate.sh`,
`tests/run-gate-tests.sh`. No other role's directory, no core canon
repo (`tokenmaxxxer/tokenmaxxxer-core`), no `on-the-record` repo is
touched — both preconditions are read and referenced, never edited or
copied, per this repo's existing reference-not-copy convention
(already followed by issue-50's migration).

## Current-state survey reference

`docs/issue-53/reports/execution-observation/current-state-survey.md`
— confirms live (this session) all six items enumerated below, plus
reads core PR #75 and on-the-record PR #182 in full from their local
checkouts.

## Verdict-level plan (stated before any verdict-shaped language)

This section states what will be checked in phase 2, and against what
evidence, for each of the three levels. No verdict is rendered in this
document — the entries below describe future checks, not conclusions
already reached.

- **outcome** — will be checked against: `bash tests/run-gate-tests.sh`
  exits 0 including a new missing-core deny case; `qa/hooks/hooks.json`'s
  eo-state SessionStart hook fires without a path error (live session
  smoke test, or a script-level check that the resolved path exists);
  `tests/deny-only-check.sh`'s substance probe targets
  `docs/issue-<n>/reports/execution-observation.md` and still catches
  an empty record; `README.md` names the current repo, the current role
  (`execution-observation`), only files that exist in the tree, and all
  three `eo-*` plugins; `qa/plugins/eo-state/hooks/state.sh` and
  `qa/plugins/eo-methodology-gate/hooks/methodology-gate.sh` both source
  `gate-lib.sh` with the `||`-guard shape core #75 landed, and a
  compliance-style check (if run) finds no unguarded source line under
  `qa/`.
- **trajectory** — will be checked against: this proposal names the
  precondition PRs and their confirmed shapes before any phase-2 edit
  (this document, backed by the survey), the phase boundary is
  respected (no code/gate/test edits in this phase-1 session, only docs
  under this role's phase-1 write surfaces), the approval gate (contract
  v3 s19) is honored before any phase-2 write, and phase 2 edits only
  the files enumerated in Scope above.
- **step** — will be recorded per-artifact in the phase-2 record
  (`docs/issue-53/reports/execution-observation.md`), not here — this
  is a phase-1 proposal and intentionally contains no per-step
  pass/fail judgment.

## Design: fixes per confirmed defect

### 1. `qa/hooks/hooks.json` eo-state path (issue's "공통 외" item 1)

Change:

```
"${CLAUDE_PLUGIN_ROOT}/../plugins/eo-state/hooks/state.sh reset"
```

to:

```
"${CLAUDE_PLUGIN_ROOT}/plugins/eo-state/hooks/state.sh reset"
```

`CLAUDE_PLUGIN_ROOT` for this hooks.json resolves to `qa/`;
`plugins/eo-state/hooks/state.sh` is already a direct descendant of
`qa/` (confirmed present at that path in the survey) — dropping the
`../` is the minimal, conservative fix; no restructuring of the
`qa/plugins/` tree is proposed.

### 2. `tests/deny-only-check.sh` legacy record path (issue's "공통 외"
item 2)

Change `rec_rel="docs/issue-999/reports/qa.md"` to
`rec_rel="docs/issue-999/reports/execution-observation.md"`, matching
every other role-specific record path already in use across this repo
(`docs/handbooks/execution-observation-plugins.md`,
`qa/plugins/eo-methodology-gate/README.md`, and the issue-47/issue-50
record precedents). This file is the shared `tests/deny-only-check.sh`
copy (per its own header comment, "every rulebook copies this file
verbatim") — only the `rec_rel` value is role-specific and in scope;
the shared detection logic above it is untouched, keeping this fix
conservative and confined to the one line the issue names.

### 3. `README.md` resync (issue's "공통 외" item 3)

Rewrite `README.md` to: name the actual repo
(`execution-observation-rulebook`), describe the `execution-observation`
role (not `qa`) on contract v3, list only files that exist in the tree
today (`qa/hooks/directive.sh`, `qa/hooks/hooks.json`,
`qa/plugins/eo-directive/`, `qa/plugins/eo-methodology-gate/`,
`qa/plugins/eo-state/`, `qa/commands/`, `bench/`, `tests/`), drop the
three phantom filenames (`record-fields-gate.sh`, `trailer-gate.sh`,
`handbook-trigger-gate.sh` — confirmed absent from the tree), and add
a "What is here" line for each of the three `eo-*` plugins mirroring
`docs/handbooks/execution-observation-plugins.md`'s already-current
per-plugin descriptions (that handbook is confirmed up to date in the
survey and is the source of truth phase 2 should mirror, not
re-derive). Conservative bound: phase 2 rewrites `README.md` only;
`docs/handbooks/execution-observation-plugins.md` is not touched since
the survey found it already accurate.

### 4. Common-item gate-lib source guard (core #75 reference-applied)

`qa/plugins/eo-state/hooks/state.sh:23` and
`qa/plugins/eo-methodology-gate/hooks/methodology-gate.sh:20` change
from:

```
. "$CORE_ROOT/hooks/lib/gate-lib.sh"
```

to the guarded form core #75 landed across all seven core gates:

```
. "$CORE_ROOT/hooks/lib/gate-lib.sh" || { echo "<gate-name>: cannot source gate-lib.sh" >&2; exit 2; }
```

This is a direct reference-application of core #75's confirmed guard —
no new logic invented in this repo, matching the reference-not-copy
convention issue-50's migration already established for
`gate-lib.sh`/`gate-lib.py` itself.

### 5. Missing-core mandatory test case (requirement 3)

Phase 2 adds one case to `tests/run-gate-tests.sh` mirroring core #75's
`run-gate-lib-tests.sh` mandatory group 7 shape: invoke
`methodology-gate.sh` (and/or `state.sh`, whichever exposes a testable
entry point) with `CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent
path and no valid relative fallback, asserting exit 2 (deny), not exit
127 read as an accidental allow. This closes the gap the survey
confirms: the suite is green today (23/23) but green without exercising
the missing-core path core #75 made mandatory upstream.

### 6. Matcher/code coverage re-confirmation (requirement 2)

Phase 2 re-confirms, file-by-file, that every `hooks.json` matcher in
`qa/hooks/` and each `qa/plugins/*/hooks/hooks.json` names exactly the
tool set the corresponding script's code branches on — no advertised-
but-unreached branch, no reached-but-unadvertised branch. The survey's
spot-check (`eo-methodology-gate`: matcher and code agree) is not yet
extended to `eo-state`'s `PostToolUse` `Read|Bash` matcher against
`state.sh`'s own tool-name handling; phase 2 closes that specific gap
before any suite-green claim is made for requirement 2.

## Non-goals (explicit)

- No new plugin is added; the existing three-plugin set (`eo-directive`,
  `eo-methodology-gate`, `eo-state`) is fixed in place, not
  restructured.
- No re-derivation of `gate-lib.sh`/`gate-lib.py` guard logic in this
  repo — the `||`-guard text is copied verbatim from core #75's landed
  shape, sourced (not vendored) gate-lib itself is unchanged.
- No reintroduction of `record-fields-gate.sh`/`trailer-gate.sh`/
  `handbook-trigger-gate.sh` under `qa/hooks/` — the phantom README
  entries are removed, not backfilled with new scripts; if a real gap
  exists behind any of those three names, that is a distinct future
  issue's scope, not this closeout's.
- No change to `docs/handbooks/execution-observation-plugins.md` — the
  survey found it already accurate; only `README.md` is stale.
- No edit to core canon (`tokenmaxxxer/tokenmaxxxer-core`) or
  `on-the-record` — both preconditions are treated as already landed
  and are read-only inputs to this proposal.
