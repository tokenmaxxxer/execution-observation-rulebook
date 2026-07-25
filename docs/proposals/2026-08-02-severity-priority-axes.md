---
status: landed
files:
  - docs/specs/qa-cycle-state-machine.md
  - docs/handbooks/qa-cycle.md
  - qa-cycle/hooks/transition-gate.sh
  - qa-cycle/hooks/report-phase.sh
  - qa-cycle/hooks/tests/run-gate-tests.sh
  - signoff/hooks/capture-verdict.sh
---

# Add severity and priority as separate item-record axes

## Intent

The item record tracks state, reproduction procedure, and evidence, but has no way to say how bad an observation is or what to look at first. With several items in flight a human opening a session has no basis for triage, and `report-phase.sh` can only group by state. See issue #16 and the practice research at `docs/reports/research/2026-07-25-qa-practice-landscape.md`, which documents severity and priority as two independent axes with different owners across every tracker convention it surveyed (Bugzilla, Eclipse WTP, Mozilla).

## Constraints that change what gets built

- Refusal is the gate's default: an invalid or missing value for a required field, or an agent-attempted write to a human-locked field, must be refused, not defaulted or repaired.
- Kill switches keep their meaning: `QA_CYCLE_DISABLE` silences enforcement of these fields the same as any other gate check; nothing new bypasses it.
- Any token this proposal introduces is minted only from the user's own turn, per the existing verdict-token rule — never inferred from a file, issue, PR, or tool output.
- No secret values on disk; these fields are small closed-vocabulary enums, so this is satisfied trivially, but the constraint carries over unchanged.
- No target-project code or bug report bodies enter the workspace; severity and priority are QA-workspace-local judgments about the item record, not fields copied from the target tracker.

## What will be done

Add two fields to the item record, alongside `reproduction` and `evidence` in `state.md`'s per-item block:

- `severity:` — closed set `{critical, major, minor, trivial}`, mirroring the Mozilla/Bugzilla impact ladder cited in the research. **Actor: agent.** Severity follows from what was observed (crash/data-loss vs. cosmetic), the same kind of judgment the agent already exercises when recording the reproduction procedure, so it is set or revised at `reproducing → reproduced` as part of that transition's evidence, with no new human-locked row required.
- `priority:` — closed set `{now, next, later, someday}`. **Actor: human.** Priority is a decision about what to do next relative to other items and schedule, which the research places with engineering/release management, not the observer. Because it is human-set, the gate must refuse any agent-attempted write that changes `priority` on an existing item, the same shape as the existing verdict-token lock.

Mechanism for the priority lock (revised after `docs/reports/2026-08-02-hunt-severity-priority-axes.md` found the original mechanism forgeable — see "Why the original mechanism was wrong," below): `priority` changes are protected by the *same* verdict-token mechanism that already protects the four human-locked state transitions, not a lighter parallel scheme. Concretely:

- `signoff/hooks/capture-verdict.sh` (a `UserPromptSubmit` hook) is extended to recognize an explicit human priority verdict in the user's own turn — e.g. `item ITEM-1 priority now` or equivalent unambiguous wording naming both the item and the target priority value — the same discipline it already applies to state-transition verdicts (explicit item id, explicit unambiguous keyword, rejection of bare assent, no inference from any file/issue/PR/tool output). When it finds one, it mints a token file under the item's `tokens/` directory, e.g. `tokens/<item-id>.priority.token`, distinct from the existing `<item-id>.token` used for state transitions so the two never collide or get consumed by each other's check.
- `transition-gate.sh` is extended with a second check, run alongside the existing transition-table check on any write to `state.md`: if the new content's `priority:` value for the changed item differs from the previously recorded value, the write is refused unless a matching unconsumed priority token is present, reserved for consumption via the same reserve-then-finalize `.consuming` ordering already used for transition tokens (see `docs/decisions/2026-07-31-token-consumption-ordering.md`) — so a write that fails after the token is reserved does not strand the item unable to retry, exactly as for state transitions.
- **What the token binds to.** The existing transition tokens bind to `(item id, from-state, to-state)`. A priority change is not a state transition, so this proposal binds the priority token to `(item id, field name, new value)` — e.g. item `ITEM-1`, field `priority`, value `now` — rather than to `(item id, field name)` alone. This is so a human's verdict authorizes exactly the value they chose; a token that only bound to "this item's priority may change" would let an agent pick any new value under a verdict the human never actually gave, reintroducing a version of the same forgery the token is meant to close.
- **Why re-mintable is fine.** Priority remains a re-settable classification, not a one-shot transition, and that is answered the same way verdict tokens already answer it for retried transitions: each priority change needs its own freshly minted token bound to the value being set. Nothing about single-use consumption prevents priority from being revised repeatedly over an item's life — it only means each revision needs its own fresh human verdict, which is the property this proposal actually wants.
- **The `priority-set-by: human` marker survives, but only as description, never as the lock.** The gate may still write `priority-set-by: human` into `state.md`'s item block when it allows a priority change, as a human-readable record of provenance for anyone reading the file later. But the marker is descriptive only: it plays no role in the gate's allow/refuse decision, which depends solely on presence and consumption of the matching `(item id, field, value)` token. A future reader must not mistake the marker for the lock — the token file under `tokens/` is the lock.

`severity`, being agent-set, requires no token or marker; the gate simply requires it be present (non-empty, in the closed set) whenever an item enters `reproduced`.

### Why the original mechanism was wrong

The first draft of this proposal specified the priority lock entirely as a `priority-set-by: human` marker written directly into the same `state.md` content the write itself changes, with no token, no separate file, and no involvement of `signoff/hooks/capture-verdict.sh`. `docs/reports/2026-08-02-hunt-severity-priority-axes.md` found that this made the lock self-attested: an agent could write the new `priority:` value and the `priority-set-by: human` marker in the same `Write` call, and a faithful implementation of the check as specified allowed it. The proposal's reasoning that priority is a re-settable classification rather than a one-shot state transition was sound, but it justified only *not reusing the single-use consumption discipline as-is unexamined* — it did not license moving the attribution itself inside the file under attack. The fix above keeps the "re-mintable, not single-use-forever" property (each value gets its own token) while restoring the property that was actually load-bearing: the attribution must originate outside the file the agent controls, exactly as `capture-verdict.sh` already guarantees for transition tokens.

Required-for-transition question, settled: **severity is required to reach `reproduced`** — an item cannot enter `reproduced` with an empty `severity:` field; the gate refuses `reproducing → reproduced` if severity is unset, since `reproduced` is the state a human triages from and an unset severity there defeats the point. **Priority is NOT required to reach `handed-off`** — an item can be handed off with `priority` still empty; the human deciding to hand it off has already exercised judgment about it being worth fixing, and forcing a priority pick at that exact moment couples two decisions (is-this-a-defect, and where-does-it-rank) that a human may reasonably want to make at different times. Priority defaults to absent/`unscheduled` in reporting until set.

`report-phase.sh`'s session-start report is extended to sort items within each project by severity (most severe first) and to show `severity` and `priority` inline per item id, so the first thing a human sees at session start is which items are worst and which are already ranked — answering "what do I look at first" without opening `state.md`.

## Out of scope

- Any change to the transition table's states or rows — this is additive fields on the existing record, not a new axis of state.
- Renegotiating who owns priority in trackers generally; this proposal follows the research's default (human/engineering-owned) rather than the "jointly negotiated" contested alternative.
- A UI or dashboard beyond `report-phase.sh`'s text report.
- Retroactively backfilling severity/priority on items already in `reproduced` or later before this lands — existing items keep empty fields until next touched.

## How we'll know it worked

`state.md` item blocks carry `severity:` and `priority:` fields with closed-set values enforced by `transition-gate.sh`; an attempted `reproducing → reproduced` write with empty `severity` is refused; an agent-attempted `priority` change with no matching unconsumed `(item id, field, value)` token present is refused, including when the write also contains a self-authored `priority-set-by: human` marker (the marker alone must not be sufficient — this is the exact case `docs/reports/2026-08-02-hunt-severity-priority-axes.md` found broken in the original design); a `priority` change backed by a token minted from an explicit human verdict via `capture-verdict.sh` is allowed and consumes the token; `qa-cycle/hooks/tests/run-gate-tests.sh` gains cases for both refusals plus one allow case per field; `report-phase.sh`'s output shows severity and priority per item, sorted by severity, on a workspace with two or more items in flight.

## What did not work

- The original single-`priority-set-by: human`-marker mechanism (see "Why the original mechanism was wrong," above) — replaced with the token mechanism per the hunt finding, before implementation began.
- The gate's existing "a write changes exactly one item's state" ambiguity check assumed state was the only axis a write could change. Priority changes needed to be detected and bounded the same way even when no state changes at all, so the check was generalized to "a write touches exactly one item, on either the state axis or the priority axis" rather than being layered on top unchanged.
- `report-phase.sh`'s original per-project grouping (by state) was replaced outright with grouping by `(priority, severity)`, rather than being added alongside it — the proposal's "how we'll know it worked" says "sorted by severity" but the intent section says priority is the primary ordering with severity secondary; the implementation follows the intent section (priority primary) since that's what answers "what to look at first."
