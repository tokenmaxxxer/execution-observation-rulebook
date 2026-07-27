# signoff

The human sign-off discipline for the QA cycle: `Go`, `No-Go`,
`Shipped-Under-Exception`, and `Confirmed-Defect` are verdicts a named human
makes, never an agent alone (`docs/decisions/2026-07-26-human-gate-over-pipeline-gate.md`).
`signoff` neither owns nor writes the QA cycle's state file — that belongs
solely to `qa-cycle`. It does two things:

1. **Presents the evidence and asks** (`/go-no-go`) — shows the
   exit-readiness bundle (or, for triage, the reproduction evidence) and
   asks the human for their verdict. It never performs the transition
   itself.
2. **Captures the verdict as a token** (`hooks/capture-verdict.sh`, a
   `UserPromptSubmit` hook) — reads the user's own turn (never a file,
   issue, PR, comment, or tool result) and, only on an unambiguous verdict
   that names what's being decided, mints a single-use token at
   `docs/reports/records/<subject>/qa/tokens/<item-id>.token` in the target
   repo. Vague assent ("ok," "sounds good," a thumbs-up) produces no token.

## How an unambiguous verdict is recognized

The hook reads the project's current `phase` from `state.md` and only
looks for the verdict wording legal from that phase:

- `finding-triage` -> looks for explicit defect-confirmation language
  ("confirmed defect," "this is a defect," "ruling this a defect").
- `go-no-go` -> looks for explicit `No-Go`, or `Go` paired with a
  ship/release/clear word (bare "go" alone is never enough — too easy to
  say by accident).
- `No-Go` -> looks for explicit override language ("shipped under
  exception," "override the no-go").

A message matching only a common short-assent pattern ("ok," "sure,"
"yep," a thumbs-up emoji, alone) is rejected even if it happens to contain
a matched keyword elsewhere. The matched sentence is stored verbatim as
the token's `phrase`, after a check for credential-, key-, secret-, or
internal-URL-shaped substrings — if the load-bearing wording itself looks
sensitive, no token is minted and the hook says why instead.

## Token shape

```yaml
item: <item-id>
transition: <state> -> <state>   # exactly one transition this token authorizes
phrase: '<verbatim, sanitized wording from the user's own turn>'
```

Single use: the same `qa-cycle` gate operation that permits the write also
deletes the token. A token whose `item` or `transition` doesn't match
the attempted write is treated by the gate as absent — reusing it, or
using it for a different item or subject, does nothing.

## Kill switch

`QA_SIGNOFF_DISABLE=1` disables both hooks (`directive.sh` and
`capture-verdict.sh`); unset or any other value means active.

## Composition

- Hands its minted token to `qa-cycle`'s `PreToolUse` gate
  (`qa-cycle/hooks/transition-gate.sh`), the only reader/consumer of it.
- Reads readiness evidence produced by `stats`, `testrun`, and
  `bugreport`'s run records; presents it via `/go-no-go`.
- Never writes `state.md` directly — only `qa-cycle` does.

Unbenchmarked as of v0.1.0.
