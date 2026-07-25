---
date: 2026-07-31
proposal: docs/proposals/2026-07-31-item-axis-enforcement.md
---

# Token consumption ordering: reserve-then-finalize, not delete-on-allow

`docs/reports/2026-07-29-hunt-gate-execution-check.md` found that deleting
the verdict token the instant the gate decides to allow strands a
legitimate transition whenever the permitted write fails or is aborted
downstream: the token is gone, `state.md` never advanced, and only a fresh
human signoff can unblock it.

**Chosen:** on allow, move the token from `tokens/<item>.token` to
`tokens/<item>.consuming` instead of deleting it. The *next* gate
invocation touching that item finalizes it (deletes it) once the item's
recorded state actually equals the marker's `to` — proof the write landed
— and otherwise treats a retry of the *identical* `(item, from, to)` as
still authorized by the marker, while the live `.token` slot stays empty so
no *different* transition can be minted from the same reservation.

**Rejected alternative:** defer consumption to a `PostToolUse` companion
hook that deletes the token only after observing the write succeed. This is
the more obviously "correct" ordering, but it requires a second hook
registration per tool call and depends on `PostToolUse` firing reliably
after every abort path (denied-by-another-hook, tool error, user
interrupt) — none of which this plugin stack currently guarantees, and
getting it wrong reintroduces silent double-spend risk instead of silent
stranding. The chosen mechanism needs no second hook and self-heals from
state.md alone, which the gate already trusts as ground truth.

**Rejected alternative:** never consume until periodic reconciliation
against state.md history. Rejected as needless complexity — the reserve
marker already IS the reconciliation record, checked lazily on the next
relevant call rather than on a schedule.
