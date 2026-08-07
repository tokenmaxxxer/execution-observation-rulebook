---
proposal: docs/issue-61/proposals/2026-08-07-eo-state-core-resolution-fix.md
---

# Hunt record — eo-state-core-resolution-fix

## after-proposal — stance 0: assume the gate just touched is bypassable — find the bypass

Verdict: FINDING — the proposed relative-path fix copies directive.sh's `../../core`
formula verbatim into scripts one directory level deeper, so it resolves to the
wrong `core` location and would still fail to source gate-lib.sh in exactly the
installed-cache case the fix targets.
Kind: design-error
Seed: docs/issue-61/proposals/2026-08-07-eo-state-core-resolution-fix.md (planned
edits to execution-observation/plugins/eo-state/hooks/state.sh and
execution-observation/plugins/eo-methodology-gate/hooks/methodology-gate.sh)
cap_seconds: 60
tier: default/docs-only
diff_stat_lines: 1 file changed (proposal doc only, no code diff yet)
started_at: 2026-08-07T00:00:00Z
ended_at: 2026-08-07T00:01:00Z

### Reproduce
```
python3 - <<'PY'
import os
d1 = os.path.normpath(os.path.join("execution-observation/hooks", "../../core"))
d2 = os.path.normpath(os.path.join("execution-observation/plugins/eo-methodology-gate/hooks", "../../core"))
d3 = os.path.normpath(os.path.join("execution-observation/plugins/eo-state/hooks", "../../core"))
print("directive.sh core ->", d1)
print("methodology-gate.sh core (proposed) ->", d2)
print("state.sh core (proposed) ->", d3)
PY
```

### Observed
```
directive.sh core -> core                                    # i.e. <repo-root-parent>/core, sibling of execution-observation/
methodology-gate.sh core (proposed) -> execution-observation/plugins/core
state.sh core (proposed) -> execution-observation/plugins/core
```
`execution-observation/hooks/directive.sh` sits one directory deeper than
`execution-observation/plugins/<name>/hooks/*.sh` (the latter are nested inside
`plugins/<name>/`). The proposal's "What will be done" step 1 says to copy
directive.sh's exact fallback string `$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)`
into state.sh and methodology-gate.sh unchanged. Because those two scripts are
one path segment deeper than directive.sh, the same two-`..` climb lands one
directory too shallow: it resolves to a `core/` sibling of `plugins/` instead of
the `core/` sibling of `execution-observation/` that directive.sh actually finds
(and that the constraint "must follow the same … convention already used by
directive.sh" implies should be the same physical directory). In the exact
target scenario the proposal exists to fix — an installed plugin cache with no
git repo and no `CLAUDE_PLUGIN_ROOT_CORE` override — the fixed scripts would look
in the wrong location, fail to source `gate-lib.sh`, and hit the same
`exit 2` deny path as today, so the stated fix does not actually repair the
installed-cache case for these two scripts even though it does for directive.sh.

### Expected
The relative fallback in state.sh/methodology-gate.sh needs one more `..` segment
than directive.sh's (`../../../core`, or equivalently a fallback anchored the
same way directive.sh's `core` sibling is defined) to land on the same `core`
directory directive.sh finds, given their extra `plugins/<name>/` nesting level.
The proposal as written directs implementers to paste directive.sh's formula
unchanged, which reproduces the bug it's meant to fix for one level less of
nesting than these two scripts actually have.
