---
status: landed
files:
  - docs/specs/role-handoff-contract.md
  - qa-cycle/hooks/tests/run-gate-tests.sh
---

## Intent

The prior proposal (`docs/proposals/2026-07-26-repo-local-contract.md`) made
`transition-gate.sh` resolve exactly one root — the current repo's git root
— and refuse handoff-protocol actions when that root has no
`docs/specs/role-handoff-contract.md`. That fixed how the gate *looks* for
the contract, but this repo never gained a contract file of its own: `qa`'s
own working tree is a legitimate "real project repo" the gate runs against
during its own test cycle, and today it fails the presence check like any
other bare clone would. The gate logic is correct; it simply has nothing to
find here. This proposal creates this repo's own
`docs/specs/role-handoff-contract.md` so the gate can operate against it and
its ownership/DEPENDS-ON/NEVER-OVERWRITE tests exercise real pass behavior
instead of universally hitting the absence-refusal path.

## Constraints

- Content is sourced from the v2 contract as coding's rulebook already
  carries it — `git show v2-conformance:docs/specs/handoff-protocol.md` in
  `/home/jwjung/tokenmaxxxer/coding-agent-rulebook` — not redrafted, so this
  repo's copy stays byte-consistent with the version other rulebooks already
  conform to.
- Per the contract's own §1, this file is *this* repo's authoritative copy;
  no reference back to the coding-agent-rulebook checkout is retained in the
  installed file itself, only in this proposal's provenance note.
- No change to `transition-gate.sh`'s resolution logic — that was settled in
  the prior proposal and is out of scope here.
- Any `run-gate-tests.sh` change is additive only: covering the
  now-satisfiable ownership/refuse paths under §11, not altering existing
  cases.

## What will be done

1. Create `docs/specs/role-handoff-contract.md` in this repo, populated with
   the v2 handoff contract content (the shared sections coding's copy
   documents its role against — §1 where the contract lives, §2 absence
   behavior, §3 wakes-on, §4 read/depends-on/never-overwrite, through §11
   ownership and beyond), adapted to state qa's role instead of coding's
   where the source text is role-specific.
2. Check `qa-cycle/hooks/tests/run-gate-tests.sh` for cases that assert on
   contract-absence refusal only; if any ownership/allow/refuse cases per
   §11 are currently skipped or stubbed for lack of a contract file in this
   repo, extend them to run for real now that the file exists.

## Out of scope

- Other rulebooks (coding, feasibility, product, ops, review) and the root
  `tokenmaxxxer` repo.
- Merging, remote push, or any `gh` operation — this repo is local-only.
- The deferred qa item-level state-machine migration.
- Any change to `transition-gate.sh`'s resolution or refusal logic.

## How you'll know it worked

With `docs/specs/role-handoff-contract.md` present at this repo's git root,
running `transition-gate.sh` from this repo no longer emits "this repo has
no collaboration contract yet" — it proceeds to the handoff-protocol checks
that follow the presence check. `qa-cycle/hooks/tests/run-gate-tests.sh`
passes, and its ownership/allow/refuse cases exercise §11 behavior against
the real file rather than short-circuiting on absence.

Confirmed: before the contract file existed, `run-gate-tests.sh` scored 35
passed / 17 failed (of 52), plus a failing `directive-drift-check` that
exited 2 with "this repo has no collaboration contract yet". After adding
`docs/specs/role-handoff-contract.md`, the same run scores 52 passed / 0
failed and `directive-drift-check` passes.

## What did not work

- The proposal's `files:` list and the task instructions named
  `qa-cycle/hooks/run-gate-tests.sh`; the actual test script lives at
  `qa-cycle/hooks/tests/run-gate-tests.sh`. No case in it asserts on
  contract-absence specifically (all 52 cases run against `mktemp`-rooted
  fixture workspaces via `transition-gate.sh`'s repo-root resolution, which
  in every case resolves to *this* repo's git root regardless of the
  fixture workspace) — so the fix was purely additive-by-existence: once
  `docs/specs/role-handoff-contract.md` existed, all 17 previously-failing
  cases and the `directive-drift-check` started passing with no edits to
  the test script itself. There was nothing to extend per §11 beyond what
  already existed.
- `transition-gate.sh`'s own comments cite "contract §10", "§11", and
  "§14" for ownership/DEPENDS-ON behavior, but the source content at
  `coding-agent-rulebook`'s `v2-conformance:docs/specs/handoff-protocol.md`
  only runs through §9 plus a scope note — it never reaches those section
  numbers. Rather than inventing numbered sections to match the gate
  script's comments (which would mean drafting content beyond what the
  source document actually states, contrary to the "not redrafted" and
  "byte-consistent" constraints), this proposal kept the same section
  structure as the source (§1-§9 + scope note) and adapted only the
  role-specific language (coding -> qa, coding's produces/depends-on rows
  -> qa's, per the ownership and DEPENDS-ON behavior already encoded in
  `transition-gate.sh`'s Python checks). Reconciling the gate script's
  §10/§11/§14 comments against an actual numbered shared contract is out
  of scope here per the proposal's own "no change to transition-gate.sh's
  resolution or refusal logic."
