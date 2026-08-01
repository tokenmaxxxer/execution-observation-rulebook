# issue-53 current-state survey (execution-observation, phase 1)

Scope: issue #53 ("게이트 A+ 최종 마감: 재감사 잔여 결함 보수 (재감사 등급 B)"),
role execution-observation, this session, branch
`issue-53/execution-observation` in `tokenmaxxxer/execution-observation-rulebook`.
Phase 1 only — research + survey + proposal; no code, gate, or test edits
in this session, no PR opened.

## Skip record: best-in-class scouting

Not run. Issue #53 is closeout of a re-audit's named residual defects
(gate B) against two already-landed precondition PRs in sibling repos —
the fix shape is dictated by the issue body and by core's already-landed
canon, not an open design space needing comparison against sibling
rulebooks. `docs/issue-47/reports/execution-observation/scout-brief.md`
and `docs/issue-50/reports/execution-observation/scout-brief.md` are the
precedent for when scouting applies (introducing a new gate, adopting a
new library shape); this issue instead applies an already-adopted
library's already-landed fix and repairs known-stale docs/paths, so no
new scout-brief.md is written for this issue.

## 1. Core precondition: PR #75 (`tokenmaxxxer/tokenmaxxxer-core`)

Read live this session from the core repo's local checkout at
`/home/jwjung/.tokenmaxxxer/work/tokenmaxxxer-core-issue-75-implementation`
(remote `https://github.com/tokenmaxxxer/tokenmaxxxer-core.git`).

- Deliver commit: `f61d52feb95dc32b820f79b025bac6dbe94be3a7`
  ("deliver(implementation): gate-lib source guard + gate_bash_write_targets
  py parity (issue-75)")
- Propose commit: `24eb5edb` (PR #76, phase-1 proposal for issue-75)
- Files changed (`git show --stat f61d52f`): `core/hooks/approval-gate.sh`,
  `core/hooks/board-gate.sh`, `core/hooks/directive.sh`,
  `core/hooks/gh-guard.sh`, `core/hooks/handbook-trigger-gate.sh`,
  `core/hooks/lib/gate-lib.py`, `core/hooks/lib/gate-lib.sh`,
  `core/hooks/record-fields-gate.sh`, `core/hooks/tests/compliance-check.sh`,
  `core/hooks/tests/run-gate-lib-tests.sh`, `core/hooks/trailer-gate.sh`,
  `docs/handbooks/gate-house-standard.md`,
  `docs/issue-75/reports/implementation.md`.

Confirmed canon shapes read in full (`git show f61d52f -- <path>`):

- **Mandatory `||`-guarded source line.** Every core gate now sources
  `gate-lib.sh` as `. ".../gate-lib.sh" || { echo "<gate>: cannot source
  gate-lib.sh" >&2; exit 2; }`. Rationale in `gate-lib.sh`'s own updated
  header comment: an unguarded source that fails when core is unreachable
  runs no code, including no `gate_*` function definitions, after which
  every `gate_kill_switch_active ... || { exit 0; }` call site reads the
  resulting "command not found" (exit 127) as the kill switch being off —
  a silent fail-open, not a crash.
- **`compliance-check.sh` detection rule** (new grep block): flags any
  file that sources `gate-lib.sh"$` without an `|| ` guard on the same
  line.
- **`gate_bash_write_targets` ported to `gate-lib.py`** — same
  `[A-Za-z0-9_./~$-]+` token-scan regex as the sh version's
  `grep -oE '[[:alnum:]_./~$-]+'`, parity-tested (sh/py token sets
  asserted equal for the same command string).
- **`run-gate-lib-tests.sh` mandatory group 7: missing-core.**
  `CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent path, no valid
  relative fallback → the guarded source line must deny (exit 2), not
  fall through as an allow. The harness itself now fails if this group
  is not exercised (seven-group `MANDATORY GROUP MISSING` check, up from
  six).

## 2. On-the-record precondition: PR #182 (`tokenmaxxxer/on-the-record`)

Read live this session from the local checkout at
`/home/jwjung/.tokenmaxxxer/work/on-the-record-issue-182-implementation`
(remote `https://github.com/tokenmaxxxer/on-the-record.git`).

- Deliver commit: `e50fe08fa7e79c513777ac761a0c458f24d34dd3`
  ("issue-182: phase 2 — inject CLAUDE_PLUGIN_ROOT_CORE into role
  sessions")
- Propose commit: `677aa32` (phase 1)
- Files changed: `docs/issue-182/reports/implementation.md`, `spawn.py`
  (+15), `test_spawn.py` (+19).
- Confirmed shape: `spawn_cmd()` now reuses the already-resolved core
  entry in `core_plugins` to set `CLAUDE_PLUGIN_ROOT_CORE`, identical to
  the path passed via `--plugin-dir`; a missing core entry warns on
  stderr instead of silently falling through to an unresolvable relative
  fallback (the exact fail-open path core #75's guard defends against on
  the gate side).

Both preconditions are landed on their respective repos' default
branches per the commits above (not re-verified against a live `main`
ref in this session beyond reading the commit that lands them; no
attempt made to re-run either repo's own test suite, out of scope for
this repo's own survey).

## 3. This repo's current state (`execution-observation-rulebook`,
`issue-53/execution-observation`, starting point `a9a66af`)

### 3a. `qa/hooks/hooks.json` — eo-state path error (confirmed live)

```
"command": "${CLAUDE_PLUGIN_ROOT}/../plugins/eo-state/hooks/state.sh reset"
```

`qa/hooks/hooks.json` lives at `qa/hooks/`; `CLAUDE_PLUGIN_ROOT` for that
plugin resolves to `qa/`. `plugins/eo-state/hooks/state.sh` (confirmed
present at `qa/plugins/eo-state/hooks/state.sh` via `find`) is a
**sibling** of `hooks/` under `qa/`, not a sibling of `qa/` itself — the
`../` climbs one directory too far, resolving outside `qa/` entirely to
a nonexistent path. This fires every `SessionStart`, matching the
issue's "매 세션 에러" — the correct relative path from
`${CLAUDE_PLUGIN_ROOT}` (`qa/`) is `plugins/eo-state/hooks/state.sh`
(no `../`).

### 3b. `tests/deny-only-check.sh` — legacy `qa.md` record path

`tests/deny-only-check.sh:45` hardcodes
`rec_rel="docs/issue-999/reports/qa.md"` for its substance probe (empty
record must be refused). Every other role-specific record path in this
repo — `docs/handbooks/execution-observation-plugins.md`,
`qa/plugins/eo-methodology-gate/README.md`,
`docs/issue-47/reports/execution-observation.md`,
`docs/issue-50/reports/execution-observation.md` — uses
`docs/issue-<n>/reports/execution-observation.md`. `qa.md` is a name
from before the role was renamed to `execution-observation`; the probe
still writes to a path no current gate is scoped to check (confirmed:
`grep -rn "reports/qa.md"` under `qa/` finds no gate reference to that
filename — the probe's payload target no longer matches what
`eo-methodology-gate` is scoped to react to for a record write).

### 3c. `README.md` — stale qa-era document (confirmed live)

Full read this session. `README.md` (repo root) still: names the repo
title `qa-agent-rulebook` (old repo name; actual repo is
`execution-observation-rulebook`), describes "The `qa` role on contract
v3" (role is `execution-observation`), documents a "What is here" file
list of `qa/hooks/directive.sh`, `qa/hooks/record-fields-gate.sh`,
`qa/hooks/trailer-gate.sh`, `qa/hooks/handbook-trigger-gate.sh`,
`qa/commands/` — of which `record-fields-gate.sh`, `trailer-gate.sh`,
and `handbook-trigger-gate.sh` do not exist anywhere in this tree
(confirmed: `find qa -iname '*record-fields*' -o -iname '*trailer-gate*'
-o -iname '*handbook-trigger*'` returns nothing), and never mentions any
of the three plugins that are the actual current shape
(`eo-directive`, `eo-methodology-gate`, `eo-state`, confirmed present
under `qa/plugins/`). This is the issue's named "README가 qa 시절
전체(옛 레포명·삭제 파일 문서화·eo 플러그인 무언급)" — confirmed on all
three counts: old repo name, phantom deleted-file documentation, and
zero mention of the eo plugin set.

### 3d. Common-item defect check against core #75's canon (this repo's
own hooks)

`grep -rn 'gate-lib\.sh"' qa/` finds two source sites:
`qa/plugins/eo-state/hooks/state.sh:23` and
`qa/plugins/eo-methodology-gate/hooks/methodology-gate.sh:20`. Both read:

```
. "$CORE_ROOT/hooks/lib/gate-lib.sh"
```

with no `||` guard on the same line — the exact fail-open shape core
#75's `compliance-check.sh` rule now flags and its mandatory group 7
test now exercises. This repo's own gates predate core #75 (issue-50's
migration, which added the reference-adoption of `gate-lib.sh`, landed
before core #75's guard fix existed) and have not yet picked up the
guard. This is the "공통 외" item's common-item counterpart: issue #53's
"공통 항목은 core #75의 확정 가드/규칙을 참조 적용" applies directly
here.

### 3e. Test suite status (live run this session)

`bash tests/run-gate-tests.sh` → `23 passed, 0 failed`, all green (full
output tail: `ok` lines for every `eo-*` case, ending `== 23 passed, 0
failed ==`). No dead references remain (issue-50's remediation removed
them) — but `grep -l "missing-core\|CLAUDE_PLUGIN_ROOT_CORE"
tests/*.sh` finds no case in this suite that exercises a
`CLAUDE_PLUGIN_ROOT_CORE`-pointed-nowhere denial, matching core #75's
new mandatory group 7 shape. This confirms the issue's requirement 3
gap: the suite is green today, but green without the missing-core case
core #75 made mandatory upstream.

### 3f. Matcher-to-code coverage (requirement 2 spot-check)

`qa/plugins/eo-methodology-gate/hooks/hooks.json` matcher:
`Write|Edit|MultiEdit`. `methodology-gate.sh:110`:
`if tool in ("Write", "Edit", "MultiEdit"):` — matcher and code agree,
no Bash-tool branch advertised or coded on this plugin. `qa/plugins/
eo-state/hooks/hooks.json` `PostToolUse` matcher: `Read|Bash`; `state.sh
mark` is the target — not independently verified line-by-line against
matcher coverage in this pass (flagged for phase-2 to re-confirm
against `state.sh`'s own tool-name handling, since the issue requires
matcher/code coverage to be "완전 정합" — fully aligned — not spot-
checked).

## Summary of confirmed defects (feeds the proposal)

1. `qa/hooks/hooks.json`: `../plugins/eo-state/...` → wrong path,
   fires every session.
2. `tests/deny-only-check.sh:45`: `qa.md` legacy record filename.
3. `README.md`: old repo name, phantom file list, no eo-plugin mention.
4. `qa/plugins/eo-state/hooks/state.sh:23` and
   `qa/plugins/eo-methodology-gate/hooks/methodology-gate.sh:20`:
   unguarded `gate-lib.sh` source (core #75 common-item fix not yet
   applied here).
5. `tests/run-gate-tests.sh`: no missing-core deny case (core #75
   mandatory group 7 not yet mirrored here).
6. `eo-state`'s `PostToolUse` matcher vs `state.sh` code: not yet
   re-confirmed for full alignment (flagged, not yet closed).
