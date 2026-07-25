---
proposal: docs/proposals/2026-08-04-directive-drift-check.md
---

# Hunt record — directive-drift-check

## after-proposal — stance 3: assume the rule as written cannot hold; find the state nothing maintains

Verdict: FINDING — the proposal's "orphaned row" completeness check (case 2) requires every actor-agent/human TABLE row to be covered by a marker, but several current TABLE rows have no corresponding "from -> to" bullet anywhere in the current, believed-clean directive prose, so the check as specified would fail on day one against the state the proposal's own acceptance criterion calls clean.
Kind: design-error
Seed: docs/proposals/2026-08-04-directive-drift-check.md (commit 8c3c041318e615946537b0a4fd5eb5ea56224d4b)

### Reproduce
```
cd qa-agent-rulebook
sed -n '82,95p' qa-cycle/hooks/transition-gate.sh   # TABLE literal
grep -n "(none)\|-> observed" intake/hooks/directive.sh qa-cycle/hooks/directive.sh
grep -n "parked-unreproducible" testrun/hooks/directive.sh bugreport/hooks/directive.sh regress/hooks/directive.sh
grep -n "re-verifying\|verified-fixed" testrun/hooks/directive.sh regress/hooks/directive.sh signoff/hooks/directive.sh
```

### Observed
`TABLE` (qa-cycle/hooks/transition-gate.sh:82-95) has these actor-agent/human rows with no matching "from -> to" bullet in any current directive.sh:
- `("(none)", "observed", "agent")` — the bootstrap row: no directive (not even `intake`, which owns item creation) states this triple as a transition claim.
- `("parked-unreproducible", "observed", "agent")` — `testrun` explicitly enumerates the other three rows it owns from `reproducing` (`observed->reproducing`, `reproducing->reproduced`, `reproducing->observed`, `reproducing->parked-unreproducible`) but never states `parked-unreproducible -> observed` anywhere.
- `("re-verifying", "verified-fixed", "agent")` and `("re-verifying", "reproducing", "agent")` — `regress` only says "the `re-verifying` re-run" and "before treating the item as `verified-fixed`" in prose; neither row is ever written as an explicit `from -> to` pair, and the discard-and-retry row (`re-verifying -> reproducing`) is not mentioned at all in any directive.

Per the proposal's own spec for divergence case 2: "the check verifies every table row with `actor: agent`-or-`human` that is NOT covered by any directive's marker set, and fails listing orphaned rows." Since these rows carry no prose to attach a marker to today, a straightforward implementation fails on the current repo the moment it is built and run — contradicting the proposal's stated "how you will know it worked" criterion: "`directive-drift-check.sh` run against the current, believed-clean repo state exits 0."

### Expected
Either the proposal should note (as it did for the precondition gap) that the orphaned-row check cannot pass against the current directives without first adding prose+markers for the bootstrap and no-marker rows, or the ownership-completeness rule needs a documented exemption analogous to `stats`'s exemption — otherwise landing this proposal as scoped produces an immediately-red check, which is the opposite of the "green means something real" state the proposal argues for.
