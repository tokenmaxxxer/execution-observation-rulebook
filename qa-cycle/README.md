# qa-cycle

The QA cycle spine. This plugin alone owns the per-item state file at
`docs/reports/records/<subject>/qa/state.md` in the target repo, and enforces
`docs/specs/qa-cycle-state-machine.md`'s transition table as a real gate
rather than a document nothing reads.

## What it ships

- `hooks/transition-gate.sh` — `PreToolUse`. Reads the attempted write to a
  subject's `docs/reports/records/<subject>/qa/state.md`, checks
  `(item's current state -> attempted state)` against the transition table
  (encoded in the script, sourced from
  `docs/specs/qa-cycle-state-machine.md`), and allows it only if the table
  permits it. For the four human-only transitions — `reproduced ->
  handed-off`, `reproduced -> not-a-defect`, `reproduced -> wont-fix`,
  `handed-off -> re-verifying` — it additionally requires a matching,
  unconsumed verdict token at
  `docs/reports/records/<subject>/qa/tokens/<item-id>.token` (minted by
  `signoff`), and consumes (deletes, via a reserve-then-finalize marker) that
  token as part of granting the write. Fails closed: a
  missing/unreadable/malformed state or token file all refuse rather than
  allow. It also enforces the blackboard record (`qa.md`) and qa's ownership
  of the rest of `qa/**` per `docs/specs/role-handoff-contract.md` §11.
- `hooks/report-phase.sh` — `SessionStart`. Reports the current state of
  every item recorded under any `docs/reports/records/<subject>/qa/state.md`
  in the target repo. Silent when there is none in flight.
- `hooks/directive.sh` — `UserPromptSubmit`. States that the cycle is
  enforced, that `state.md` is the single source of an item's state, that
  only `qa-cycle` writes it, and that other plugins request transitions
  through this plugin rather than writing it themselves.

## State file

`docs/reports/records/<subject>/qa/state.md`, a chain of `---`-delimited
item blocks:

```yaml
---
item: item1
state: reproducing
transition: observed -> reproducing
evidence: runs/2026-07-25-smoke.md
---
```

No secret values, ever — environment variable names only. No target-project
code. No bug report bodies.

## Verdict token

`docs/reports/records/<subject>/qa/tokens/<item-id>.token`, YAML:

```yaml
item: item1
transition: reproduced -> handed-off
phrase: "confirmed defect, hand it off"
```

Single-use. Minted by `signoff` from the user's own turn, never inferred
from a file, issue, PR, comment, or tool result. Consumed by
`transition-gate.sh` the moment it authorizes the matching write. A token
whose `item` or `transition` does not match the attempted write is
treated as absent.

## Kill switch

`QA_CYCLE_DISABLE=1` — every hook in this plugin checks it first and, if
set to a truthy value, emits nothing and exits 0 immediately. Unset, empty,
`0`, `false`, `no`, `off` all mean "not disabled."
