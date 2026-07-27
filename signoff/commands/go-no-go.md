---
description: Present a feedback item's evidence and ask the named human for a hand-off/not-a-defect/wont-fix/re-verify verdict
argument-hint: "[optional: item id or run slug to review]"
---

Present item evidence for review: $ARGUMENTS

This command shows a human the evidence the spec requires and asks for
their verdict on one feedback item. It never performs the state transition
itself — that only happens through `qa-cycle`'s gate, once `signoff`'s
`capture-verdict.sh` hook has minted a token from the human's own,
unambiguous reply.

## 0. Precondition — current item state

Read `docs/reports/records/<subject>/qa/state.md` for the item under review.
This command is only meaningful from `reproduced` (heading toward
`handed-off` / `not-a-defect` / `wont-fix`) or from `handed-off` (heading
toward `re-verifying`). If the item's state is something else, say so and
stop — do not improvise a review out of turn.

## 1. Assemble the evidence bundle

- The item's recorded reproduction procedure and evidence.
- The reproducing/reproduced run-record entries backing it.
- Any prior verdict already recorded on this item.
- If reviewing a `handed-off` item: the original hand-off's evidence and
  the coding agent's reported fix.

Present this bundle in full. Do not summarize away an open severity or a
deferred case — the human is deciding on what's actually there.

## 2. Ask for the verdict, explicitly

Ask the human directly, naming the item: is this a genuine defect to hand
off (`handed-off`), not a defect (`not-a-defect`), accepted but not being
fixed (`wont-fix`) — or, if already `handed-off`, has a fix landed and
should re-verification begin (`re-verifying`)?

Do not accept or act on a vague reply ("looks fine," "ok," a thumbs-up). If
the reply is ambiguous, ask again naming the specific verdict word needed.

## 3. Stop

Once the human states their verdict unambiguously in their own reply,
`capture-verdict.sh` mints the token on that same turn. This command's job
ends here: it does not write `state.md`, and it does not attempt the
transition. The next tool call that performs the write is gated by
`qa-cycle`, which consumes the token.
