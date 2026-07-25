---
status: proposed
files:
  - docs/specs/qa-cycle-state-machine.md
---

# Re-axis the QA cycle state machine to the feedback item

## Intent

The current state machine (docs/specs/qa-cycle-state-machine.md) tracks one `phase` per project, but the QA agent's product is feedback handed to a separate coding agent, not code itself. State should attach to one feedback item — one observation or candidate defect — not to the project as a whole. See issue #10.

## Constraints that change what gets built

- The item axis is non-linear by design: backward edges (failed/insufficient reproduction back to observation; a human declining to confirm a defect back to observation or to a closed end; a failed re-verification back to reproduction) are normal transitions, not error paths to be designed away.
- There are four terminal states, not one, and they are not interchangeable: confirmed-and-fix-verified, closed-as-not-a-defect, parked-as-unreproducible, and won't-fix. Parked is explicitly re-enterable — a new observation can revive it, so it cannot be modeled as a dead end.
- The coding agent is opaque: this system never observes its internal state. Both handoff to the coding agent and "fix landed, re-verify" arrive only as a human trigger. While an item sits in the handed-off state, no transition on it is permitted absent that trigger.
- Four kinds of transitions are human-locked: (1) confirm-defect, (2) hand off to coding agent, (3) fix landed / begin re-verification, (4) close item. Each requires a single-use verdict token minted only from the user's own turn (matching the existing signoff mechanism), and each token must bind to a specific item and a specific transition — not merely the project — so a verdict cannot be replayed against a different item.
- Re-verification depends on the original reproduction procedure, so the item record must carry the reproduction steps alongside its current state, not just a phase name.

## What will be done

Rewrite docs/specs/qa-cycle-state-machine.md so its primary state/transition table is keyed on the feedback item rather than the project: define the item's states (including the four terminal states and the handed-off state), its transitions (including the backward edges above), the four human-locked transitions and their verdict-token binding (item + transition), and the item record's required fields (state, reproduction steps, terminal-state variant where applicable). Add a decision record under docs/decisions/ capturing the axis change itself — why per-item replaces per-project as the unit of state — as a discrete architectural decision distinct from the spec content.

## Explicitly out of scope

- Any change to qa-cycle/hooks/transition-gate.sh, to how signoff tokens are minted, or to the on-disk state file layout the hooks read. These implement the current per-project axis and are left as-is; a follow-up unit updates them to the new axis. Landing this spec while that code still enforces the old axis leaves spec and code temporarily divergent — that gap is real and is exactly what the follow-up unit closes, not a defect of this unit.
- The token-consumption-timing defect already recorded in docs/reports/2026-07-29-hunt-gate-execution-check.md. Unrelated to the axis change; not touched here.

## How this will be known to have worked

The rewritten spec is reviewable against every constraint above: an item's state and reproduction steps can be traced through at least one full backward-edge cycle (e.g., handoff → re-verify fails → back to reproduction) without leaving the item's own record; all four terminal states are distinct and parked-as-unreproducible has a defined re-entry transition; each of the four human-locked transitions names its verdict-token binding as item+transition; and the decision record states the per-item-vs-per-project choice and its rationale independently of the spec prose.
