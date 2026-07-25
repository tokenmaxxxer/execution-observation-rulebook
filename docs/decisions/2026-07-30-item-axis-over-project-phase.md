---
date: 2026-07-30
status: decided
---

# Item axis over project phase

**Chosen:** state attaches to one feedback item — one observation that may or may not turn out to be a defect — with its own state (`observed` through the terminal states), not to the project as a whole.

**Over:** a single per-project `phase` field (the prior spec's model), where the whole project moves through `intake-scoping → ... → Go/No-Go` as one unit.

**Why:** the QA agent's product is feedback items handed to a separate coding agent, not code, and a project accumulates many items in flight at once — one `finding-triage`, another already `handed-off`, another `parked-unreproducible` — none of which a single project-wide phase can represent simultaneously. A per-project phase also cannot express `parked-unreproducible`'s re-entry (a new observation reviving one specific item) without conflating it with every other item's state. Per-item state lets each observation carry its own reproduction procedure and verdict history independently, which is also what makes `handed-off → re-verifying` possible at all: re-verification needs the specific item's recorded procedure, not a project-wide snapshot.

**Evidence base:** `docs/proposals/2026-07-30-item-axis-state-machine.md`, issue #10.
