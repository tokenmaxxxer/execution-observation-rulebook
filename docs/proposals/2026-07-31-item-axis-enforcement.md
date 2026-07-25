---
date: 2026-07-31
status: proposed
issue: "#12"
files:
  - qa-cycle/hooks/transition-gate.sh
  - signoff/hooks/capture-verdict.sh
  - qa-cycle/hooks/tests/run-gate-tests.sh
  - qa-cycle/hooks/tests/README.md
  - docs/handbooks/qa-cycle.md
  - qa-cycle/hooks/report-phase.sh
---

# Re-axe enforcement onto item state

## Intent

`docs/specs/qa-cycle-state-machine.md` (issue #10) now defines the QA cycle
on the per-feedback-item axis — 9 states, 11 transitions, 4 human-locked
rows — but the enforcement code, `qa-cycle/hooks/transition-gate.sh` and
`signoff/hooks/capture-verdict.sh`, still keys on the superseded per-project
`phase` vocabulary. This unit brings enforcement onto the item axis the spec
now uses, and, in the same pass, closes the token-consumption-timing defect
recorded in `docs/reports/2026-07-29-hunt-gate-execution-check.md`, since
both changes land in the same token-consumption code the gate rewrite
touches.

## Constraints

- Gate legality must be keyed on per-item state, read against the spec's
  11-row transition table, not a single project-wide `phase`.
- The human-actor check keys on the exact `(from, to)` pair per the spec's
  Actor column — not on the destination state alone, mirroring the existing
  gate's own reasoning for why a target-only set was wrong under the old
  table.
- A verdict token binds to both a specific item id and a specific
  `(from, to)` pair; a token minted for one item, or for one transition on
  an item, must never authorize another item or another transition.
- An item in `handed-off` refuses every transition attempt that lacks a
  human trigger — the interval is opaque by design (spec: "no transition out
  without a human trigger").
- Token consumption must not be able to strand a legitimate transition when
  the permitted write subsequently fails or is aborted. The mechanism is not
  prescribed here; the build chooses it and records the choice in
  `decisions/`.
- Refusal stays the default for malformed or unreadable input — never a
  silent allow.
- `QA_CYCLE_DISABLE` and the sibling per-plugin kill switches remain
  deliberate, unchanged operator overrides.
- Tokens are minted only from the user's own turn, never from file, issue,
  PR, or comment content.
- No secret values in state or token files — environment variable names
  only.
- No target-project code enters the workspace.
- Bug report bodies go to the target project's tracker, never into the
  qa-workspace state file.

## What will be done

- Rewrite `qa-cycle/hooks/transition-gate.sh`'s embedded transition table
  and legality/actor logic against the spec's 11-row item table, switch its
  state read/write from a project-level `phase` field to per-item state, add
  the `handed-off`-refuses-without-human-trigger check, and re-derive
  matching to be `(item id, from, to)`-scoped rather than
  `(project, from, to)`-scoped.
- Fix the consumption-timing defect in the same file: decouple "decide to
  allow" from "irrevocably destroy the token" so a subsequent write failure
  leaves a legitimate transition retryable, and record the chosen mechanism
  as a new file under `decisions/`.
- Update `signoff/hooks/capture-verdict.sh` to mint tokens shaped for
  `(item id, from, to)` instead of `(project, from, to)`, using the item
  states and verdict wording from the new spec.
- Extend `qa-cycle/hooks/tests/run-gate-tests.sh` (and its `README.md`) to
  exercise: item-keyed (not project-keyed) legality; a token minted for one
  item rejected against a different item; a token minted for one transition
  on an item rejected against a different transition on that same item; a
  `handed-off` transition refused with no human trigger; and the
  consumption-timing case the report identified — a hook-permitted write
  that does not land must not strand the transition, and the harness must
  actually exercise that path rather than assume it.
- Update `docs/handbooks/qa-cycle.md` to describe the new per-item state
  file shape and the new item-and-transition-bound token shape, replacing
  the current project-`phase`/project-scoped-token description throughout.
- Update `qa-cycle/hooks/report-phase.sh` — the SessionStart hook
  registered in `qa-cycle/hooks/hooks.json` — to read the new per-item
  `state.md` shape and report items by state at session start, instead of
  reading a single top-level project `phase` field. This file was added to
  the write set because `docs/reports/2026-07-31-hunt-item-axis-enforcement.md`
  found that, unrevised, it would read the old single-`phase:` field
  against the new per-item `state.md`, find nothing, and silently report
  zero projects in flight — exit 0, no error — even while items are stuck
  mid-cycle.

## Out of scope

- Any change to the spec itself (`docs/specs/qa-cycle-state-machine.md`) —
  it is the fixed target this unit enforces.
- The open questions the spec left unresolved (item identity across
  `parked-unreproducible → observed` re-entry, `stats` reporting format,
  what happens to a `re-verifying → reproducing` item mid-flight).
- Any other plugin's directive prose beyond the two hooks and the harness
  named above.
- Target-project code or tracker integration details.

## How we'll know it worked

The extended `run-gate-tests.sh` passes, including the new item-scoped
replay-rejection cases, the `handed-off`-without-human-trigger case, and a
case that actually simulates a hook-permitted write failing to land and
confirms the transition remains retryable afterward without a fresh
signoff. The handbook's documented state-file and token shapes match what
the rewritten hooks actually read and write. Manual replay of the
reproduction in `docs/reports/2026-07-29-hunt-gate-execution-check.md`
against the rewritten gate no longer strands the transition.
