---
date: 2026-08-05
proposal: docs/proposals/2026-08-05-target-declaration.md
issue: "#22"
---

# Target declaration: agent-writable, content-gated over token-locked

**Chosen:** `target.md` is agent-writable; `observed -> reproducing`
refuses only on the declaration's *content* being absent, empty,
malformed, or missing `label`/`entry_point` — enforced via the same
`requires` mechanism `severity` already uses on
`reproducing -> reproduced`, a row in `transition-gate.sh`'s `TABLE`, not
a second enforcement path.

**Over:** treating the target declaration like `priority` — a
human-set field requiring a single-use verdict token minted by
`signoff/hooks/capture-verdict.sh` before any write could change it.

**Why:** the target is a fact to be recorded once at the start of QA
work (what the user already started and is running), not a subjective
judgment call like `priority` or an is-this-a-defect verdict like the
four human-locked state transitions. Requiring a human token here would
duplicate machinery the gate doesn't need: a valid, non-empty
`entry_point` and `label`, referenced by the write's own evidence,
already anchors every later reproduction to the declared target. The
same split `intake.md` already uses (agent-discoverable, not
human-locked, no verdict token) applies unchanged. If a declaration is
wrong, the user says so and the agent rewrites the file — no token
consumption or re-minting involved.
