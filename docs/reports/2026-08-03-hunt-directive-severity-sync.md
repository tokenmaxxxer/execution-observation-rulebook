---
proposal: docs/proposals/2026-08-03-directive-severity-sync.md
---

# Hunt record — directive-severity-sync

## after-proposal — stance 3: assume the rule as written cannot hold; find the state nothing maintains

Note: `.warrant-hunt.count` in the repo root is stuck at 4 (contents: `4`); this run is being dispatched by hand-cycled rotation with stance 3 assigned manually rather than by an advancing counter. Recording as instructed.

Verdict: FINDING — the proposal's "clean" scan result for the four untouched directives and `go-no-go.md`, and the fixed prose it is about to write into the three stale ones, are both point-in-time assertions that nothing in the repository re-checks; there is no lint, test, or CI step anywhere that ties any `directive.sh` heredoc's prose to `transition-gate.sh`'s actual transition table, so the next edit to the gate (or to `capture-verdict.sh`) can silently strand these same seven-plus files again with zero signal, exactly as happened to get here.
Kind: silent-failure
Seed: docs/proposals/2026-08-03-directive-severity-sync.md (commit 2a59bfe7d22a85274c69594a974ea9a61412a53a)

### Reproduce
```
cd qa-agent-rulebook
# Nothing outside directive.sh itself ever mentions directive.sh:
grep -rl "directive.sh" --include='*.sh' . | grep -v '/directive.sh$'
# -> empty: no script reads or validates directive.sh content

# The 38-case harness the proposal cites as "still passes, proves nothing broke"
# never touches directive.sh at all:
grep -n "directive" qa-cycle/hooks/tests/run-gate-tests.sh
# -> no matches

# No CI, no lint, no consistency-checking tooling exists in the repo:
find . -iname '*lint*' -o -iname '*consisten*' -o -iname '*sync*check*'
find . -path '*/.github/*'
# -> both empty
```

### Observed
Grepping for any consumer of `directive.sh` besides the file defining itself returns nothing; the transition-gate test harness (`run-gate-tests.sh`) never mentions "directive" at all; there is no CI workflow directory and no lint/consistency script in the repository. The proposal's own "How you will know it worked" section is three `grep` commands against the directive files themselves plus "harness still passes" — none of which can detect a directive drifting out of sync with the gate, only that this proposal's specific edits landed as typed. The proposal explicitly rules out building any such check ("No enforcement changes... no new checks, no new tests").

### Expected
For a claim like "directive prose agrees with the landed gate contract" to hold over time, something durable — a test that parses both `transition-gate.sh`'s transition table and each `directive.sh`'s claimed transitions/preconditions and diffs them, or at minimum a CI step that fails when the gate changes without a corresponding directive-review commit — would need to exist. None does. The mechanism that catches drift today is exactly what the seed names: a human (or dispatched hunt) manually rediscovering it after the fact, as happened for `testrun/hooks/directive.sh` via `docs/reports/2026-08-02-hunt-severity-priority-axes.md` and is now happening again for the other two files this same unit fixes. This proposal fixes the current instance of the drift but adds no mechanism that would surface the next one, so the "clean" and "fixed" states it asserts are both silently revocable by any future edit to `transition-gate.sh` or `capture-verdict.sh`.

## before-landing — stance 1: assume this change and another plugin's rule cancel each other; find the pair

Verdict: NO FINDING
Seed: git diff main...sync/directive-severity (testrun/hooks/directive.sh, bugreport/hooks/directive.sh, signoff/hooks/directive.sh prose edits)

Checked concretely, with no contradiction reproduced in any pair:
- testrun's new severity precondition on `reproducing -> reproduced` ("record it before attempting the transition, not after") vs bugreport's "Severity ... agent-set ... no lock — set it directly when filing": severity has no lock, so setting it earlier (per testrun, required to reach `reproduced` at all) and re-touching it later at filing time (per bugreport) are both legal under the gate — `block_severity`/the closed-set check has no single-writer or single-write restriction. Constructed no write that one directive permits and the gate/other directive refuses.
- bugreport's and signoff's priority-token descriptions (`item <id> priority <value>` turn, token bound to item id + `priority` field + new value, `priority-set-by: human` marker descriptive-only) match `capture-verdict.sh` and `transition-gate.sh` verbatim in mechanism; no divergence between the two plugins' prose.
- qa-cycle's own directive says nothing about priority/severity at all (silent, not contradictory) — `state.md`/gate-authority claims in qa-cycle's directive do not overlap with the field-level claims added to testrun/bugreport/signoff.
- The gate's one-item-per-write rule caps at one *item*, not one axis (`transition-gate.sh` comment: "these are independent axes and either alone, or both together on the same item, is a legal shape for one write") — so a same-turn human verdict that mints both a state-transition token and a priority token for the same item (`capture-verdict.sh`'s state-detection and priority-detection run independently, both can fire) composes cleanly into one write; no refusal, no silent override.
- intake never creates/requires severity at item creation and makes no severity claim, so there's nothing for testrun's severity requirement to contradict there.

No pair found where one directive's newly-written prose tells the agent to do something the gate or a sibling directive then silently blocks or overrides.
