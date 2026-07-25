---
description: Present exit-readiness evidence and ask the named human for a Go/No-Go verdict
argument-hint: "[optional: readiness bundle or run slug to review]"
---

Present exit-readiness for review: $ARGUMENTS

This command shows a human the evidence the spec requires and asks for
their verdict. It never performs the state transition itself — that only
happens through `qa-cycle`'s gate, once `signoff`'s `capture-verdict.sh`
hook has minted a token from the human's own, unambiguous reply.

## 0. Precondition — current phase

Read `$QA_WORKSPACE/projects/<slug>/state.md`. This command is only
meaningful from `exit-readiness` (heading toward `go-no-go` -> `Go`/`No-Go`)
or from `No-Go` (heading toward `Shipped-Under-Exception`). If the phase is
something else, say so and stop — do not improvise a review out of turn.

## 1. Assemble the evidence bundle

- The exit-readiness stats report (pass/fail/open-severity counts) from
  `stats`.
- The list of planned cases, with each executed or deferred-with-reason.
- Any open exceptions or known-unresolved findings.
- If reviewing a `No-Go` override: the original No-Go's blocking reason.

Present this bundle in full. Do not summarize away an open severity or a
deferred case — the human is deciding on what's actually there.

## 2. Ask for the verdict, explicitly

Ask the human directly: does this evidence meet exit criteria (`Go`), does
it not (`No-Go`), or — if already `No-Go` — is it being deliberately
overridden (`Shipped-Under-Exception`, which additionally needs a reason
code, a named approver distinct from the No-Go issuer, and a follow-up
ticket reference)?

Do not accept or act on a vague reply ("looks fine," "ok," a thumbs-up). If
the reply is ambiguous, ask again naming the specific verdict word needed.

## 3. Stop

Once the human states their verdict unambiguously in their own reply,
`capture-verdict.sh` mints the token on that same turn. This command's job
ends here: it does not write `state.md`, and it does not attempt the
transition. The next tool call that performs the write is gated by
`qa-cycle`, which consumes the token.
