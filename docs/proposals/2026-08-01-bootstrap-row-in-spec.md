---
status: approved
files:
  - docs/specs/qa-cycle-state-machine.md
  - docs/decisions/2026-08-01-item-creation-is-agent-actor.md
---

# Add the item-creation bootstrap row to the spec's transition table

## Intent

`qa-cycle/hooks/transition-gate.sh` already enforces a 12th transition — item creation — that the spec's 11-row transition table does not define. The spec must be extended to match the landed gate behavior. See issue #14.

## Constraints that change what gets built

- The code is authoritative here; the spec is what's behind. The row is added to match the gate as it actually behaves, not designed fresh.
- The gate's bootstrap row is `("(none)", "observed", "agent")`: an item with no prior record transitions to `observed` when an agent writes its first block, with the observation text as required evidence. The actor is agent, not human — so an agent can bring a new feedback item into existence unaided; only the later verdict rows (`reproduced → handed-off`, `reproduced → not-a-defect`, `reproduced → wont-fix`, `handed-off → re-verifying`) are human-locked. This is a real choice worth recording, not an incidental detail, so it gets a short decision record alongside the spec edit.

## What will be done

- Add a `(none)` → `observed` row to the transition table in docs/specs/qa-cycle-state-machine.md, with trigger "agent creates the first record of a new item," evidence "the observation text," actor "agent."
- Update the table's framing text (currently "11-row"/"exhaustive" language) so it reflects 12 rows including bootstrap, and add `(none)` to the states list as the pre-existence marker the table now references.
- Write a short decision record settling the agent-actor-vs-human-actor question for item creation, since the gate already made this call and it should be recorded rather than left implicit.

## Out of scope

- Any change to transition-gate.sh or other hook behavior — the gate already does this; only the spec catches up.
- The severity/priority axis — a separate future unit per the open questions in the current spec.

## How we'll know it worked

The transition table in docs/specs/qa-cycle-state-machine.md has 12 rows, the bootstrap row's (trigger, evidence, actor) matches the gate's TABLE entry verbatim, and a decision record exists stating item creation is agent-actor with its one-sentence reasoning.
