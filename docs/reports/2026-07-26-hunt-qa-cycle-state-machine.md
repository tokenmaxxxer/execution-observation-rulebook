---
proposal: docs/proposals/2026-07-26-qa-cycle-state-machine.md
---

# Hunt record — qa-cycle-state-machine

## before-landing — stance 0 (index count=0 mod 5): plain design error
Note: no rotation list was provided in this dispatch and no prior
`.warrant-hunt.count` existed; treated as count=0, stance = plain design
error (state/transition names must resolve against something the spec
actually defines).

Verdict: FINDING — the paired decision record names states the spec it encodes never defines
Kind: design-error
Seed: commit 67d6b85, `docs/decisions/2026-07-26-human-gate-over-pipeline-gate.md` alongside `docs/specs/qa-cycle-state-machine.md`

### Reproduce
```
grep -n "Confirmed-Defect\|\`Go\`" docs/decisions/2026-07-26-human-gate-over-pipeline-gate.md
grep -n "^\- \`\|| \`" docs/specs/qa-cycle-state-machine.md | grep -i "go\|report-filed\|confirmed"
```

### Observed
The decision record's binding clause reads:

> No transition into `Go` or `Confirmed-Defect` may be taken by an agent alone.

But `docs/specs/qa-cycle-state-machine.md` — the very spec this decision is
supposed to bind — defines no state or transition named `Go` or
`Confirmed-Defect`. The spec's actual vocabulary is `report-filed` (not
`Confirmed-Defect`) and `go-no-go`, whose Go/No-Go/Shipped-Under-Exception
outcomes are only prose annotations inside one state's transitions
(`go-no-go` (No-Go) → `go-no-go` (Shipped-Under-Exception)), never a
first-class `Go` state or transition target. There is no table row, no
state, and no transition literally named `Go`.

### Expected
A decision record adopted the same day as, and cross-referenced from, the
spec it constrains should use the spec's own state/transition names, so
"no transition into X may be taken by an agent alone" is mechanically
checkable against the transition table. As written, an implementer or
future auditor cannot map the decision's prohibition onto any row of the
Transition table — the rule names a target that does not exist in the
artifact it governs.
