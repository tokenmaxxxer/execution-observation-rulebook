# issue-50 current-state survey (execution-observation, phase 1)

Read this session: issue #50 body, `tests/run-gate-tests.sh` (executed
live), `qa/plugins/eo-methodology-gate/hooks/methodology-gate.sh`,
`qa/plugins/eo-state/hooks/state.sh`,
`qa/plugins/eo-directive/hooks/directive-body.sh`,
`docs/handbooks/execution-observation-plugins.md`,
`qa/plugins/eo-methodology-gate/README.md`, `git status --short` on repo
root. Core canon (separate repo `tokenmaxxxer/tokenmaxxxer-core`, issue
#72, landed): `core/hooks/lib/gate-lib.sh`, `core/hooks/lib/gate-lib.py`,
`docs/handbooks/gate-house-standard.md`, fetched via `gh api`.

## 1. Test suite: 7/17 exit-127 (confirmed live)

`bash tests/run-gate-tests.sh` run this session:

```
FAIL   record-complete       want=allow got=exit-127
FAIL   record-empty          want=deny  got=exit-127
FAIL   open-no-backlog       want=deny  got=exit-127
FAIL   foreign-path          want=allow got=exit-127
FAIL   commit-no-trailer     want=deny  got=exit-127
FAIL   commit-with-trailer   want=allow got=exit-127
FAIL   commit-non-issue      want=allow got=exit-127
== 10 passed, 7 failed ==
```

Root cause: the first 7 cases (`tests/run-gate-tests.sh:26-45`) invoke
`$HOOKS/record-fields-gate.sh` and `$HOOKS/trailer-gate.sh` under
`qa/hooks/`. Neither file exists in this tree
(`find . -iname '*-gate.sh'` under `qa/hooks/` returns nothing for those
two names) — `/bin/bash "$HOOKS/record-fields-gate.sh"` exits 127
(command not found) before the gate's own exit-2/0 protocol ever runs.
These are dead references to gates from an earlier repo shape; the
10 `eo-*` cases (`tests/run-gate-tests.sh:78-118`) are the only ones
exercising code that currently exists (`eo-methodology-gate`) and all
10 pass.

## 2. `.warrant-hunt.count` root residue (confirmed live)

`git status --short` at repo root shows `./.warrant-hunt.count` as an
untracked file, alongside unrelated dotfiles from the execution
environment (`.bashrc`, `.gitconfig`, etc. — not repo state). It is not
referenced by any script under `qa/`, `tests/`, or `.claude/` in this
tree (`grep -r warrant-hunt` finds no producer/consumer here) — a
leftover artifact from a `warrant` plugin hunt-counter mechanism that
either never belonged in this repo's root or was never cleaned up by
whatever wrote it. Confirmed present, not owned by any current script
in this repo.

## 3. Two disabled test cases (confirmed live)

`tests/run-gate-tests.sh:26,30` — `bad-verdict` and
`incorrect-needs-svb` are prefixed `true ||`, unconditionally skipping
the `run` call. Both target the same nonexistent
`record-fields-gate.sh`, so they are doubly dead: disabled, and even if
re-enabled would also exit-127 against a file that does not exist.

## 4. Semantic checks are substring-only today

`methodology-gate.sh`'s `missing` list (lines ~150-210) checks presence
via `"## Scope" in new_text`, `has_any(*needles)` (plain substring),
and one ordering check (`independence statement` index vs. earliest
verdict-marker index). Every check except the ordering one is a bare
substring/regex-anywhere test: a proposal that mentions "outcome",
"trajectory", "step" anywhere — including inside an unrelated sentence,
a code block, or a quoted example — satisfies `level_count >= 2` with
no requirement that the words appear as an actual verdict-level plan
under a plan-shaped heading. Same for the plugin-list check
(`has_any("플러그인 목록", "plugin list", "plugin 목록")`) and the
blameless-shape check (`has_any("deficient","finding")` gating
`absent_blameless` on four more bare substrings). Issue #50 requirement
2 names this directly: "채택 방법론의 판단이 '단어 언급'으로 통과되지
않게" — word-mention must stop being sufficient.

## 5. Gate does not use the now-landed gate-house standard

`methodology-gate.sh` hand-rolls: its own `__fc` trap (lines 2-3,
structurally identical to `gate_trap_fail_closed` but not sourcing it),
its own kill-switch case statement (lines 15-17) using the **old**
`""|0|false|no|off) ;; *) exit 0 ;; esac` shape — the exact
default-open-on-unrecognized-value bug `gate-house-standard.md`
documents as bug class 1 (any value other than a recognized
off-spelling, including a typo, currently disables this gate), its own
`_under`/path-normalize logic (lines 40-47, bash+python mixed, not
`gate_normalize_path`), and its own Edit/MultiEdit reconstruction
(lines ~120-140) that mirrors the exact `replace_all`-ignored bug class
2 the standard's own `record-fields-gate.sh` had:
`text.replace(old, new, 1)` always, `replace_all` field never read, and
no `NotebookEdit` handling at all. `gate-lib.sh` /
`gate-lib.py` (issue #72, landed in `tokenmaxxxer-core`) exist
specifically to replace all of the above via `gate_trap_fail_closed`,
`gate_kill_switch_active`, `gate_normalize_path`,
`gate_reconstruct_write` — referenced, never vendored-copy
(`docs/handbooks/canon-scripts.md` convention this repo's own
`methodology-gate.sh` header already states it follows for
pricing-rulebook; the same non-copy rule applies to core canon).

## 6. README ghost-file / accuracy gap

`qa/plugins/eo-methodology-gate/README.md` documents current behavior
accurately as of today's code (substring checks, old kill-switch
shape) — so once the semantic checks and kill-switch move to
`gate-lib`, the README will need to be re-synchronized in the same
phase-2 pass (issue #50 requirement 4). No currently-nonexistent file
is *named* in the README today, but it will drift the moment the gate
logic changes, and `docs/handbooks/execution-observation-plugins.md`
(the handbook, not README) also restates the old-shape check list and
needs the same pass.

## 7. Kill switch inconsistency across the three eo-* plugins

`eo-methodology-gate` and `eo-state` each hand-roll the same
old-shape kill-switch case statement independently (own copy in each
file) — two independent hand-rollings of the exact bug class
`gate-house-standard.md` names, not just one.

## Write-surface summary for phase 2 (not yet touched this phase)

- `qa/plugins/eo-methodology-gate/hooks/methodology-gate.sh` — migrate
  to `gate-lib.sh`/`gate-lib.py`, upgrade semantic checks.
- `qa/plugins/eo-state/hooks/state.sh` — migrate kill-switch to
  `gate_kill_switch_active`.
- `tests/run-gate-tests.sh` — remove the 7 dead `record-fields-gate.sh`/
  `trailer-gate.sh` cases (2 already dead-disabled), add the mandatory
  Edit/MultiEdit/replace_all/malformed-JSON/kill-switch/absolute-path
  cases named by the issue and by `gate-house-standard.md`'s six-case
  harness.
- `.warrant-hunt.count` at repo root — remove (unowned residue).
- `qa/plugins/eo-methodology-gate/README.md`,
  `docs/handbooks/execution-observation-plugins.md` — re-sync to the
  post-migration shape.
