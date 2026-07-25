---
status: proposed
files:
  - docs/specs/qa-cycle-state-machine.md
  - docs/handbooks/qa-cycle.md
  - qa-cycle/hooks/transition-gate.sh
  - qa-cycle/hooks/report-phase.sh
  - qa-cycle/hooks/tests/run-gate-tests.sh
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

Mechanism for the priority lock: a lighter mechanism than a full verdict token suffices. Verdict tokens exist because they gate an irreversible *state* transition (e.g. `reproduced → handed-off`) that only fires once and changes what the item legally does next. Priority is not a state transition — it is a re-settable classification field that can change repeatedly over an item's life with no effect on the transition table. Reusing the token machinery (single-use, bound to one `(item, from, to)` pair) would be the wrong shape for a field meant to be revised freely. Instead, `transition-gate.sh` is extended with a second, narrower check, independent of the transition-table check: on any write to `state.md`, if the new content's `priority:` value for the changed item differs from the previously recorded value, the write is refused unless it also carries a `priority-set-by: human` marker — itself only ever written by a human-initiated path (the `/go-no-go` directive in `signoff`, mirroring how verdict phrases are captured today, but without minting a consumable token). This gives priority a human-attribution requirement without introducing single-use consumption semantics a re-settable field doesn't need. `severity`, being agent-set, requires no such marker; the gate simply requires it be present (non-empty, in the closed set) whenever an item enters `reproduced`.

Because the mechanism does not use the token/`.consuming` lifecycle, `signoff/hooks/capture-verdict.sh` is not touched — that hook's job is minting and reserving single-use verdict tokens for transition-table rows, and priority-setting is neither.

Required-for-transition question, settled: **severity is required to reach `reproduced`** — an item cannot enter `reproduced` with an empty `severity:` field; the gate refuses `reproducing → reproduced` if severity is unset, since `reproduced` is the state a human triages from and an unset severity there defeats the point. **Priority is NOT required to reach `handed-off`** — an item can be handed off with `priority` still empty; the human deciding to hand it off has already exercised judgment about it being worth fixing, and forcing a priority pick at that exact moment couples two decisions (is-this-a-defect, and where-does-it-rank) that a human may reasonably want to make at different times. Priority defaults to absent/`unscheduled` in reporting until set.

`report-phase.sh`'s session-start report is extended to sort items within each project by severity (most severe first) and to show `severity` and `priority` inline per item id, so the first thing a human sees at session start is which items are worst and which are already ranked — answering "what do I look at first" without opening `state.md`.

## Out of scope

- Any change to the transition table's states or rows — this is additive fields on the existing record, not a new axis of state.
- Renegotiating who owns priority in trackers generally; this proposal follows the research's default (human/engineering-owned) rather than the "jointly negotiated" contested alternative.
- A UI or dashboard beyond `report-phase.sh`'s text report.
- Retroactively backfilling severity/priority on items already in `reproduced` or later before this lands — existing items keep empty fields until next touched.

## How we'll know it worked

`state.md` item blocks carry `severity:` and `priority:` fields with closed-set values enforced by `transition-gate.sh`; an attempted `reproducing → reproduced` write with empty `severity` is refused; an agent-attempted `priority` change without a `priority-set-by: human` marker is refused; `qa-cycle/hooks/tests/run-gate-tests.sh` gains cases for both refusals plus one allow case per field; `report-phase.sh`'s output shows severity and priority per item, sorted by severity, on a workspace with two or more items in flight.
