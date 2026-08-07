---
code_under_review:
  - execution-observation/plugins/eo-state/hooks/state.sh
  - execution-observation/plugins/eo-methodology-gate/hooks/methodology-gate.sh
loop_state: phase-2-complete
---

# Implementation record — issue #61

Proposal: docs/issue-61/proposals/2026-08-07-eo-state-core-resolution-fix.md

## What was done

1. `state.sh` and `methodology-gate.sh`: replaced the `git rev-parse
   --show-toplevel` `CORE_ROOT` fallback with a relative-path climb
   (`../../../../core`, 4 levels from `plugins/<name>/hooks/`), matching
   `directive.sh`'s convention, still overridable by
   `CLAUDE_PLUGIN_ROOT_CORE`.
2. `state.sh`'s `mark` case: made the marker write fail loudly (stderr
   diagnostic) if `mkdir -p` or the marker-file write fails, instead of
   absorbing via `2>/dev/null`.
3. `methodology-gate.sh`: distinguished `eo-state-marker-missing` (file
   does not exist) from a new `eo-state-marker-unavailable` (marker
   directory exists but is not inspectable) deny reason.

## Why

Per the proposal: the installed-plugin-cache case is not a git repo, so
`git rev-parse --show-toplevel` fails, `CORE_ROOT` resolves to `/core`,
sourcing `gate-lib.sh` fails, and `state.sh` exits before ever writing
the marker — silently. `methodology-gate.sh` then denies every
methodology-record write, blaming "no artifact read" for what is
actually a writer-side resolution failure.

## Verification

Setup: `<scratch>/gitcase` = copy of `execution-observation/` plus a
copy of the real `core` plugin (from `/tmp/tokenmaxxxer-core-canon-cache/core`)
as a sibling directory, with `git init` run inside `gitcase/execution-observation`
so it is a real git checkout. `<scratch>/nongitcase` = an identical
`execution-observation` + sibling `core` copy with **no** `.git`
anywhere above it, simulating an installed (non-git) plugin cache. Both
also got a `docs/specs/role-handoff-contract.md` stub so
`methodology-gate.sh`'s own project-root plausibility check (unrelated,
pre-existing logic) would accept the directory as a project root.

### Environment 1 — real git checkout (observed)

```
$ echo '{"tool_input":{"file_path":"docs/issue-61/reports/foo.md"}}' \
    | CLAUDE_PROJECT_DIR="$SCRATCH/gitcase" bash "$SCRATCH/gitcase/execution-observation/plugins/eo-state/hooks/state.sh" mark
exit=0
$ cat "$SCRATCH/gitcase/.claude/.eo-read-marker"
1786068564
```
Marker file present, containing a unix timestamp. The git-checkout path
is not regressed by the relative-path resolution change.

### Environment 2 — non-git installed plugin cache (observed)

```
$ echo '{"tool_input":{"file_path":"docs/issue-61/reports/foo.md"}}' \
    | CLAUDE_PROJECT_DIR="$SCRATCH/nongitcase" bash "$SCRATCH/nongitcase/execution-observation/plugins/eo-state/hooks/state.sh" mark
exit=0
$ cat "$SCRATCH/nongitcase/.claude/.eo-read-marker"
1786068564
```
`gate-lib.sh` sourced successfully (no "cannot source gate-lib.sh" error
on stderr) and the marker was written — this is the scenario that was
previously silent (script exited before ever reaching the marker
write). Both environments produced the same successful outcome, as
required.

### Marker-write-failure path (observed)

Made `nongitcase/.claude/` mode 555 (read-only) and re-ran `state.sh
mark`:
```
.../state.sh: 줄 58: .../.claude/.eo-read-marker: 허가 거부
state.sh: mark: failed to write marker at .../.claude/.eo-read-marker
exit=0
```
A visible stderr diagnostic is now produced instead of a silent no-op
(exit code stays 0 by design — this is a PostToolUse hook, not a gate;
the proposal's acceptance criterion is a reported failure, not a
non-zero exit).

### Methodology gate — marker missing vs. present vs. unavailable (observed)

No marker (`nongitcase/.claude` removed):
```
eo: refused — ... eo-state: eo-state-marker-missing (.claude/.eo-read-marker not present — no artifact of the observed target has been read this session).
exit=2
```

Marker present (`date +%s > nongitcase/.claude/.eo-read-marker`), same
write payload:
```
eo: refused — execution-observation methodology write to docs/issue-61/reports/execution-observation.md is missing required element(s): eo-directive: missing-verdict-level(s): outcome, trajectory, step.
exit=2
```
The `eo-state-marker-missing` reason is gone from the deny list once the
marker exists — the gate stops denying on marker grounds, confirming
the fix. (The remaining denial is the pre-existing, unrelated
`eo-directive: missing-verdict-level(s)` check on the record's content —
out of scope for this issue.)

Marker directory present but inspection-blocked (`chmod 000
nongitcase/.claude`):
```
eo: refused — ... eo-state: eo-state-marker-unavailable (.claude/ exists but is not inspectable — this may be a marker-write failure, not an unread artifact).
exit=2
```
Confirms the deny message now distinguishes "no artifact read" from
"marker unavailable", per the acceptance criterion.

## What did not work

None.

## Doc placement

- No new env var, config key, dependency, or migration introduced —
  `CLAUDE_PLUGIN_ROOT_CORE` is an existing convention, not new.
- No public signature or wire-format change; no decision record required.

## Open findings

None.

## Open finding resolution path

N/A — no open findings.

## Next steps

None — PR #62 delivery ready for review.
