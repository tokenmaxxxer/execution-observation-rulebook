---
proposal: docs/proposals/2026-08-01-bootstrap-row-in-spec.md
---

# Hunt record — bootstrap-row-in-spec

## after-proposal — stance 1: assume this change and another plugin's rule cancel each other; find the pair

Note: `.warrant-hunt.count` was stuck at 4 and did not advance between dispatches, which would have repeated a stance already probed three times; per the last manual rotation (0), this dispatch used 1.

Verdict: NO FINDING
Seed: commit 91e12c7b24d77df40441114034f68e1fe6ace5d3 (docs/proposals/2026-08-01-bootstrap-row-in-spec.md), compared against qa-cycle/hooks/directive.sh and the six sibling per-turn directives (intake, testrun, bugreport, regress, stats, signoff).

Read all seven directive.sh files. qa-cycle's own directive already states "Four transitions are human-only by construction: reproduced -> handed-off, reproduced -> not-a-defect, reproduced -> wont-fix, handed-off -> re-verifying" — matching the proposal's "only the four verdict rows are human-locked" verbatim. No sibling directive claims ownership of, or tells the agent to wait for a human before, the (none) -> observed bootstrap: intake's directive only builds the QA profile (intake.md) and explicitly says it "requests item transitions on the plugins that own them," never claiming to create items itself or requiring a human step first; testrun claims observed -> reproducing onward but not the bootstrap; bugreport/regress/stats/signoff only reference the four human-locked rows already named in qa-cycle's directive. No directive text instructs the agent to wait for a human before recording an observation, and none assumes items only come into existence through a human-initiated intake step. Found no pair of directives, or directive-vs-spec pairing, whose instructions cancel.

## before-landing — stance 3: assume the rule as written cannot hold; find the state nothing maintains

Note: `.warrant-hunt.count` was stuck at 4 across dispatches; per instructions this hunt used index 3 (the last two manual rotations having used 0 and 1).

Verdict: FINDING — the handbook still asserts the pre-diff fact ("11-row table, since the spec does not model item creation as a transition") that this diff made false in the spec it describes, and nothing keeps the two in sync.
Kind: plain-design-error
Seed: git diff main...spec/bootstrap-row (docs/specs/qa-cycle-state-machine.md bootstrap-row addition; docs/handbooks/qa-cycle.md not touched by this diff)

### Reproduce
```
grep -n "11-row" docs/handbooks/qa-cycle.md
grep -n "This table has 12 rows" docs/specs/qa-cycle-state-machine.md
```

### Observed
`docs/handbooks/qa-cycle.md:207-209` reads:

> An item absent from `state.md` altogether resolves to the well-defined starting state `(none)`, from which only the bootstrap transition into `observed` (item creation) is legal — this single row is an addition beyond the spec's 11-row table, since the spec does not model item creation as a transition.

`docs/specs/qa-cycle-state-machine.md:44` (as landed by this diff) reads:

> This table has 12 rows and is exhaustive: no other transition is legal. `(none)` is not a state an item ever records — it is the pre-existence marker for "this item id has no prior block" ...

The handbook's premise — "the spec does not model item creation as a transition," "11-row table" — is exactly what this diff overturned: the spec now has 12 rows and does model `(none) -> observed` as a transition, in its own table, not as a gate-only addition "beyond" it. The handbook was not updated, so the two documents that describe the same fact (how many rows the spec's transition table has, and whether item creation is one of them) now disagree with each other. Nothing — no test, no code, no cross-reference — keeps the handbook's characterization of the spec in sync with the spec itself; it is state the repository asserts but does not maintain.

### Expected
Either the handbook's description of the bootstrap row should have been updated in this same change (since the diff's own proposal text explicitly says the spec's row count changes from 11 to 12 and that item creation is now modeled), or the spec change should not claim the table is now self-contained/exhaustive while a sibling document still describes the old, contradictory shape.
