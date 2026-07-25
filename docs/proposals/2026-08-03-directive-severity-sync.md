---
status: landed
files:
  - testrun/hooks/directive.sh
  - bugreport/hooks/directive.sh
  - signoff/hooks/directive.sh
---

# Sync injected directive prose to the landed severity/priority gate

## Intent

Bring every plugin's injected directive prose into agreement with the severity/priority contract `qa-cycle/hooks/transition-gate.sh` now enforces, so an agent following a directive never attempts a write the gate is guaranteed to refuse. See issue #18 and `docs/reports/2026-08-02-hunt-severity-priority-axes.md`, whose before-landing finding is the seed: `testrun/hooks/directive.sh` describes `reproducing -> reproduced`'s required evidence without the severity precondition the gate added for that exact row.

## Constraints that change what gets built

- The gate is authoritative; directives are being brought into line with it, never the reverse. This unit changes no enforcement, no hook registration, and no control flow.
- The write set is not fixed to `testrun` by the hunt report's framing — it is whatever a directive-by-directive scan against the landed contract (`docs/specs/qa-cycle-state-machine.md` "Severity and priority", `docs/handbooks/qa-cycle.md`, and `transition-gate.sh` itself) actually finds stale, no more and no less.
- Fixes are prose edits inside `<qa-*-directive>` heredocs only.

## What will be done

A scan of all seven plugin directives plus `signoff/commands/go-no-go.md` against the landed gate found three stale files:

- **`testrun/hooks/directive.sh`** — the `reproducing -> reproduced` bullet under "RULES" will gain the severity precondition: exactly one `severity:` line, valid, required before that transition is legal, matching the gate's refusal wording.
- **`bugreport/hooks/directive.sh`** — the severity/priority rule currently reads "two SEPARATE fields with separately attributable setters... Record who set each, timestamped," which does not say severity is agent-set (no lock) while priority is human-set and requires a verdict token minted by `signoff/hooks/capture-verdict.sh`. It will be rewritten to state that asymmetry explicitly, so the directive stops implying an agent may just note down who set priority.
- **`signoff/hooks/directive.sh`** — its SURFACE GATE and RULES scope the whole directive to the four state-transition verdicts and never mention that `capture-verdict.sh` also mints the priority verdict token from an ordinary prompt naming `item <id> priority <value>`. It will gain a line stating that this same hook captures priority verdicts too, and that a priority change requires a token the same way the four transitions do.

Plugins scanned and found clean, with no write needed: `intake/hooks/directive.sh` (mentions neither severity, priority, nor the affected transition's evidence), `regress/hooks/directive.sh` (its transitions carry no severity/priority precondition), `stats/hooks/directive.sh` (read-only, no transition evidence claims), `qa-cycle/hooks/directive.sh` (its transition list is unchanged; severity/priority are explicitly not table axes per the spec, so its silence on them is correct, not stale), and `signoff/commands/go-no-go.md` (correctly scoped to presenting evidence for the four state-transition verdicts; priority verdicts need no evidence bundle, so its silence there is not an omission).

## Out of scope

No enforcement changes: nothing under `qa-cycle/hooks/` or `signoff/hooks/` that decides allow or refuse is touched — `transition-gate.sh` and `capture-verdict.sh` are read-only inputs this unit checks prose against, not files it edits. No hook registration, no new checks, no new tests, no changes to `docs/specs/` or `docs/handbooks/` (they already state the landed contract correctly; only the directives were out of sync).

## How you will know it worked

- `grep -n severity testrun/hooks/directive.sh` matches inside the `reproducing -> reproduced` bullet, stating the same precondition the gate refuses on: exactly one valid `severity:` line required.
- `bugreport/hooks/directive.sh` states plainly that severity needs no token and priority does, naming `signoff/hooks/capture-verdict.sh` as the sole minter of the priority token.
- `signoff/hooks/directive.sh` states that the same hook mints priority verdict tokens, not only the four state-transition tokens.
- The existing 38-case harness (`qa-cycle/hooks/tests/run-gate-tests.sh`) still passes unmodified and untouched, since no enforcement logic changed — a prose-only unit cannot legitimately change its pass count.
