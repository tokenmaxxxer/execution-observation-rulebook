---
status: proposed
files:
  - qa-cycle/hooks/transition-gate.sh
  - qa-cycle/hooks/tests/directive-drift-check.sh
  - qa-cycle/hooks/tests/README.md
  - intake/hooks/directive.sh
  - testrun/hooks/directive.sh
  - bugreport/hooks/directive.sh
  - regress/hooks/directive.sh
  - stats/hooks/directive.sh
  - qa-cycle/hooks/directive.sh
  - signoff/hooks/directive.sh
---

# Mechanically check injected directives against the gate's transition table

## Intent

Give the repository a check that fails visibly when a `directive.sh` heredoc's prose diverges from what `transition-gate.sh` actually enforces, so the next gate edit surfaces stale directive prose as a build failure instead of waiting for a manually-dispatched warrant hunt to find it, as happened three times running. See issue #20 and `docs/reports/2026-08-03-hunt-directive-severity-sync.md`, whose after-proposal finding is the seed: nothing in the repo ties directive text to the gate's transition table, so the "clean" state any prose-sync fix asserts is silently revocable by the next edit to `transition-gate.sh`.

## Constraints that change what gets built

- Refusal stays the gate's default. This unit adds a check; it changes no allow/refuse decision in `transition-gate.sh`'s Python. The TRANSITIONS table gains a declaration alongside it, not a replacement of the logic that consults it.
- No enforcement behaviour changes as a side effect. The new check is a separate script the test harness runs, not a hook registered on any tool call — it cannot itself block a write.
- Directives stay readable prose. The per-transition marker line described below is one line per bullet, in a comment-adjacent form the agent already skims past in existing directives (e.g. the severity bullet in `testrun/hooks/directive.sh` already names the exact transition in prose); it must not turn a directive into a table or require restating the gate verbatim.

## What will be done

**Facts extracted, and how.** `transition-gate.sh`'s embedded Python already holds `TRANSITIONS` as a literal list of `(from, to, actor)` tuples (lines ~83–94) with a comment stating it is "encoded from `docs/specs/qa-cycle-state-machine.md`... a copy for runtime speed, not a re-derivation." That list is the single source the gate itself consults; the fix is to make it the single source the check consults too, by having the gate emit it on request rather than have a second script re-parse or re-derive it. Add a tiny dump mode: `transition-gate.sh --dump-transitions` prints the `TRANSITIONS` list as JSON (`[{"from":..., "to":..., "actor":...}, ...]`) and exits 0, doing nothing else — no state file, no token, no `QA_WORKSPACE` needed. This is the load-bearing choice: parsing the gate's Python from outside (regex over the source) would silently break the moment the list's formatting changed and could not be trusted to stay in sync with itself; asking the gate to state its own table as data means the check and the enforcement logic can never disagree about what the table says, only about whether directives match it.

**What a directive must carry.** Each `<qa-*-directive>` bullet that claims ownership of a transition already names it in prose (e.g. "`observed -> reproducing`, triggered by..."). Add one machine-findable marker per such bullet, on its own line immediately after the bullet's transition claim:
```
<!-- gate-transition: observed -> reproducing (actor: agent) -->
```
This is an HTML comment, invisible in rendered form and skippable in a skim, carrying exactly the `(from, to, actor)` triple the bullet's prose already asserts in words. It is a restatement of the one fact the check needs to compare, not a second copy of the gate's evidence requirements or preconditions — the prose around it keeps stating those in full. Directives that own no transition (`stats`, `qa-cycle`'s own directive, which states the whole table narratively rather than per-row) carry no markers and are exempt from the per-marker check but are still scanned for the "false claim" case below.

**What counts as divergence, concretely:**
1. **A directive names a transition the table does not have** (wrong `from`/`to` pair, or wrong `actor`). Caught: the check builds the marker set from all seven directives and diffs it against the table's set; any marker triple absent from `--dump-transitions` output is a hard failure naming the file and the bad triple.
2. **A directive is silent about a transition it is responsible for.** Caught, partially: the check also builds an ownership map from `COMPOSITION`/`RULES` prose is not machine-readable, so instead ownership is declared the same way — a directive that intends to own a table row must carry that row's marker, full stop. The check verifies every table row with `actor: agent`-or-`human` that is NOT covered by any directive's marker set, and fails listing orphaned rows. This catches "no directive mentions this row at all," which is the shape of drift that would have let a table row go completely undocumented; it does not catch "a directive should own this row instead of the one that currently claims it" (an ownership *dispute* rather than a gap) — that requires human judgment about plugin boundaries, which this check does not have.
3. **A directive states evidence for a transition that omits a precondition the gate enforces** — e.g. testrun's `reproducing -> reproduced` bullet not mentioning the `severity` precondition. **Not caught.** The gate's severity/priority preconditions (the closed-set check, the token-binding rules) live in Python logic beneath the `TRANSITIONS` tuple list, not in the tuple list itself, and turning every precondition into a comparably-dumpable fact would mean re-deriving the gate's control flow as data — exactly the brittleness this proposal's introduction rules out building. This is a real, named gap: the check verifies a directive's *transition claims* against the table, not its *evidence claims* against the gate's precondition logic.

**Where it runs.** A new standalone script, `qa-cycle/hooks/tests/directive-drift-check.sh`, callable directly and also invoked as a new final step of `qa-cycle/hooks/tests/run-gate-tests.sh` (not folded into the existing 38 fixture-driven cases — this check is comparing static text, not exercising the gate against payloads, and keeping it a separate script keeps `run-case`'s fixture-and-exit-code machinery untouched). It runs `transition-gate.sh --dump-transitions`, extracts every `<!-- gate-transition: ... -->` marker from all seven `directive.sh` files via a plain grep/regex (no interpretation of surrounding prose), computes the two diffs above, and on any divergence prints the offending file, the bad or missing triple, and exits 1 — loud failure, not a warning, and `run-gate-tests.sh`'s own exit code will reflect it since it is added before the final tally.

## Out of scope

This check cannot verify that a directive's prose is good advice, accurate about *why* a transition is gated, or complete about its evidence requirements — only that the transition triples it claims to own exist in the table and that no table row goes completely unclaimed. A green check is not a correctness claim about directive quality.

**Would it have caught this session's three drifts?**
- `testrun/hooks/directive.sh` missing the severity precondition (the seed of `2026-08-03-directive-severity-sync.md`): **not caught** — this is exactly the evidence-precondition gap named above; the `reproducing -> reproduced` marker would be present and correct, the missing severity bullet is precondition prose the check does not compare.
- `bugreport/hooks/directive.sh`'s severity/priority setter-symmetry error (implying priority changes are just "recorded," not token-gated): **not caught** — same reason; this is prose about a field's write rules, not about a `(from, to, actor)` transition triple.
- `signoff/hooks/directive.sh` never mentioning that `capture-verdict.sh` also mints priority tokens: **not caught** — priority is not a state-machine transition at all (it is a field, not a `from -> to` row in `TRANSITIONS`), so it is structurally outside what this check's transition-triple comparison can see.

Stated plainly: this check would have caught none of the three drifts already found this session, because all three were precondition/field-level prose errors, not transition-existence or transition-silence errors. It is still worth building because it closes a different, real gap — a directive claiming a transition the gate does not have, or a table row no directive claims at all, which today has zero mechanical coverage and would currently only surface by luck or a hunt with the right stance. The honest framing for the next reader: this is a floor under one narrow, verifiable claim, not a substitute for the kind of hunt that found the three drifts above.

## How you will know it worked

- `qa-cycle/hooks/transition-gate.sh --dump-transitions` runs standalone (no `QA_WORKSPACE`, no stdin payload) and prints the 11-row table (plus the bootstrap row) as JSON.
- `qa-cycle/hooks/tests/directive-drift-check.sh` run against the current, believed-clean repo state exits 0.
- A synthetic negative test (temporarily inserting `<!-- gate-transition: reproduced -> deleted (actor: agent) -->` into a directive, or deleting a marker for a currently-claimed row) makes the script exit 1 with the bad/missing triple named in its output; this is checked by hand during review, not landed as a permanent fixture, since the fixture would itself need directives to carry a deliberately-wrong marker.
- `qa-cycle/hooks/tests/run-gate-tests.sh`'s tally step still reports pass/fail and now additionally reflects the drift check's exit code.
