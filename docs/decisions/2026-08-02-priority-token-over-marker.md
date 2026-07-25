---
date: 2026-08-02
proposal: docs/proposals/2026-08-02-severity-priority-axes.md
issue: "#16"
---

# Priority verdict token over an attribution marker

**Chosen:** `priority` changes are authorized by a single-use verdict
token bound to `(item id, field name, new value)`, minted by
`signoff/hooks/capture-verdict.sh` from the user's own turn, under the
same reserve-then-finalize discipline as the existing state-transition
token.

**Over:** an attribution marker (`priority-set-by: human`) written
directly into `state.md`'s own content as the sole authorization — no
token, no separate file, no involvement of `capture-verdict.sh`.

**Why:** the marker approach was the proposal's original design, and
`docs/reports/2026-08-02-hunt-severity-priority-axes.md` found it
self-attesting: the marker lived inside the exact `Write` call it was
supposed to gate, so an agent could write the changed `priority:` value
and the `priority-set-by: human` line together and satisfy a faithful
implementation of the check. The lock sat in the file it was meant to
gate, giving the locked actor (the agent) the means to satisfy its own
lock. Provenance has to originate outside the file under attack, exactly
as the existing token mechanism already guarantees for the four
human-locked state transitions — so priority reuses that mechanism rather
than inventing a lighter one.
