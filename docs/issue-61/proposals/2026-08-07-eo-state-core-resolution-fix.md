---
status: proposed
files:
  - execution-observation/plugins/eo-state/hooks/state.sh
  - execution-observation/plugins/eo-methodology-gate/hooks/methodology-gate.sh
---

## Skip condition

Scout/survey skipped: this is a pure bugfix (scout-directive skip condition 1). The
defect, its cause, and the fix direction are already fully specified in issue #61,
and the fix is a like-for-like path-resolution correction against an existing
in-repo convention (`execution-observation/hooks/directive.sh:5`) — no product or
design decision is open.

## Request

`eo-state/hooks/state.sh` resolves its `core` directory via
`git rev-parse --show-toplevel`, which fails in an installed (non-git) plugin
cache; the sourcing of `gate-lib.sh` then fails and the script exits before ever
writing `.claude/.eo-read-marker`, silently. `eo-methodology-gate/hooks/methodology-gate.sh`
has the identical broken resolution pattern. The missing marker then makes
`methodology-gate.sh` deny all methodology-record writes with a message blaming
"no artifact read" rather than the actual cause. Fix the resolution, make the
marker write fail loudly instead of being absorbed, and make the deny message
distinguish the two causes.

## Constraints

- Must not regress the git-repo case (dev checkout), where the script currently works.
- Must follow the same `CLAUDE_PLUGIN_ROOT_CORE` convention already used by
  `execution-observation/hooks/directive.sh`.
- No new dependency, no schema change.

## Rationale

Considered keeping the `git rev-parse` fallback but adding a directory-existence
check on the resulting path (fail fast without changing the resolution formula).
Rejected: this still breaks in an installed cache with no git repo above the
plugin dir, and it papers over the point that every sibling script in this repo
already uses a plain relative path (`../../core`) that works identically in both
a git checkout and an installed cache — matching that convention removes the
divergence entirely instead of adding a second failure-detection layer on top of
a resolution method that doesn't need to exist in this form.

## What will be done

1. In `state.sh` and `methodology-gate.sh`, change the `CORE_ROOT` fallback from
   `$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel 2>/dev/null)/core`
   to a relative-path resolution matching `directive.sh`'s convention (`core` is a
   sibling of the `execution-observation` repo directory), still overridable by
   `CLAUDE_PLUGIN_ROOT_CORE`. The two scripts sit one directory level deeper than
   `directive.sh` (`plugins/<name>/hooks/` vs `hooks/`), so the climb is 4 levels,
   not 2: `$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../core" && pwd -P)`.
   (A hunt pass on the first draft of this proposal, recorded in
   `docs/reports/2026-08-07-hunt-eo-state-core-resolution-fix.md`, caught that
   copying `directive.sh`'s literal `../../core` formula without adjusting for
   this depth difference would still fail to resolve `core` in exactly the
   installed-plugin-cache scenario the fix targets.) If the resolved path does
   not contain `hooks/lib/gate-lib.sh`, the existing `|| { echo ...; exit 2; }`
   clause already reports failure — this fires loudly in both scripts today and
   continues to.
2. In `state.sh`'s `mark` case, make the marker write fail loudly: check the
   `mkdir -p` and the marker-file write for failure and, on failure, write a
   diagnostic to stderr (distinct from silently continuing as today via
   `2>/dev/null` on both operations without any surfaced error).
3. In `methodology-gate.sh`'s marker check (~line 262-264), distinguish two
   deny reasons: keep `eo-state-marker-missing` for the case where the marker
   file genuinely does not exist, and add a separate `eo-state-marker-unavailable`
   deny reason for the case where the marker directory (`.claude/`) exists but is
   not writable/inspectable (e.g. permission error), so the message no longer
   uniformly blames "no artifact read" for what may be a writer-side failure.

## Out of scope

- Any change to the substring-matching heuristic in `state.sh`'s `mark` case.
- Any change to other deny reasons in `methodology-gate.sh`.
- Renaming or restructuring the `eo-state` / `eo-methodology-gate` plugins.

## How you'll know it worked

- `bash -n` on both modified scripts passes.
- Running `state.sh mark` with `CLAUDE_PLUGIN_ROOT_CORE` unset, from a copy of the
  plugin directory outside any git repository, successfully sources `gate-lib.sh`
  and writes `.claude/.eo-read-marker` on a matching payload.
- Simulating a marker-write failure (e.g. read-only `.claude/` dir) produces a
  visible stderr diagnostic instead of a silent no-op.
- `methodology-gate.sh`'s deny message differentiates a missing marker from an
  unavailable one.
