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

## before-landing — stance 0: assume the gate just touched is bypassable; find the bypass

Verdict: FINDING — `transition-gate.sh --dump-facts` unconditionally exits 0 without adjudicating the write even when a real hook payload is present on stdin, so any invocation that supplies `--dump-facts` as `$1` bypasses the transition/token check entirely regardless of the payload's content.

Kind: composition

Seed: `qa-cycle/hooks/transition-gate.sh` diff (new `--dump-facts` entry path); the comment above it claims "it ... reads no stdin — it is not reachable from, and shares no code path with, any write decision," which the reproduction below contradicts for any invocation shaped `<script> --dump-facts` with a payload piped on stdin.

### Reproduce
```
WS=/tmp/wsX; rm -rf "$WS"; mkdir -p "$WS/tokens"
cat > "$WS/state.md" <<'STATE'
---
item: I1
state: handed-off
---
STATE
payload='{"tool_input":{"file_path":"'"$WS"'/state.md","content":"---\nitem: I1\nstate: re-verifying\n---\n"}}'
printf '%s' "$payload" | QA_WORKSPACE="$WS" bash qa-cycle/hooks/transition-gate.sh --dump-facts
echo "exit=$?"
```

### Observed
The script prints the `{"transitions":..., "fields":...}` JSON dump and exits 0, ignoring the piped payload entirely — including a payload that attempts `handed-off -> re-verifying` (a human-actor, token-gated row) with no token present anywhere. No refusal, no token check, no item/state read.

### Expected
`handed-off -> re-verifying` with no verdict token should refuse (exit 2), per the gate's own "handed-off refuses every transition out without a human trigger, without exception" backstop — that logic is never reached because the `--dump-facts` check on `$1` short-circuits before adjudication runs, regardless of what (if anything) is on stdin. The entry point does not require stdin to be empty/absent to take the dump branch; it silently discards whatever is there and returns success. Any caller — a misconfigured hook wiring, a wrapper script, or an agent able to influence the invoking command line — that manages to pass `--dump-facts` as the first argument turns the gate into an unconditional allow for that invocation.
