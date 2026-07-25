---
date: 2026-08-01
proposal: docs/proposals/2026-08-01-bootstrap-row-in-spec.md
issue: "#14"
---

# Item creation is agent-actor, not human-actor

**Chosen**: the `(none) → observed` transition — an agent creating the first record of a new feedback item — is agent-actor. No human trigger or verdict token is required to open an item.

**Over what**: requiring a human trigger to open an item, i.e. making item creation a fifth human-locked row alongside the four verdict rows.

**Why**: an agent that cannot open an item cannot report what it observed — gating creation on a human would block the QA agent from ever surfacing a new observation on its own. The lock belongs at the is-this-a-defect verdict (`reproduced → handed-off`/`not-a-defect`/`wont-fix`) and at `handed-off → re-verifying`, not at observation. The cost accepted: an agent can populate the workspace with items nobody asked for; nothing in this transition prevents that.
