# Demo: the regress adoption gate, one full cycle (2026-07-24)

Graduation evidence for the regress plugin: bug → fix → `/regress` gate pass,
run against the bench target `todo-cli` with a throwaway QA workspace. Every
verdict below was actually executed.

## Setup

- Target: copy of `bench/targets/todo-cli/`, `git init`, committed as-shipped
  → **bug commit `d8b3aad`**.
- Bug: TC-6 (state-not-reflected). Reproduced: `add buy milk`, `done 1`,
  `list` → `[ ] 1. buy milk` (expected `[x]`). Run record written with
  `app: d8b3aad`, failure entry `UNFILED(no tracker — bench copy)` — the
  no-tracker argument path of `/regress`.
- Fix (dev role): `list` reads `item.get("done")` instead of
  `item.get("completed")` → **fix commit `dafddf4`**.

## Test

`regress_tc6_done_shown_in_list.py`, saved in the workspace under
`projects/todo-cli/regress/` — self-contained (stdlib `subprocess`), designed
to be copied into any checkout of the target and run there; resets
`todos.json` for a fresh state per run.

## The gate

| check | mechanism | result |
|---|---|---|
| 1. fails on bug commit | `git worktree add` @ `d8b3aad`, test copied in | **fail** — `AssertionError: done not reflected in list: '[ ] 1. buy milk\n'`, exit 1 ✓ |
| 2. passes on fix commit | worktree @ `dafddf4`, test copied in | **pass** ✓ |
| 3. stable, k=5 | check 2 repeated | 5/5 pass ✓ |

Adopted: run record appended with
`REGRESS-ADOPTED(regress/regress_tc6_done_shown_in_list.py) — gate:
fail@d8b3aad, pass@dafddf4 5/5.` Worktrees removed after each check.

## What this validates

The copy-into-worktree mechanism (the test exists only in the workspace, so
it must be copied regardless of which commit is checked out), the
run-record-failure argument path for tracker-less environments, and the gate
verdict itself. Not validated here: `REGRESS-BLOCKED` (env-prep failure needs
a target with dependencies — the roadmap web-ui/rest-api targets will cover
it) and flaky discard (needs a nondeterministic test to reject).
