---
status: approved
files:
  - docs/specs/qa-cycle-state-machine.md
  - intake/hooks/directive.sh
  - testrun/hooks/directive.sh
  - bugreport/hooks/directive.sh
  - regress/hooks/directive.sh
  - stats/hooks/directive.sh
  - qa-cycle/hooks/directive.sh
  - signoff/hooks/directive.sh
  - signoff/commands/go-no-go.md
---

# Re-axis the QA cycle state machine to the feedback item

## Intent

The current state machine (docs/specs/qa-cycle-state-machine.md) tracks one `phase` per project, but the QA agent's product is feedback handed to a separate coding agent, not code itself. State should attach to one feedback item — one observation or candidate defect — not to the project as a whole. See issue #10.

## Constraints that change what gets built

- The item axis is non-linear by design: backward edges (failed/insufficient reproduction back to observation; a human declining to confirm a defect back to observation or to a closed end; a failed re-verification back to reproduction) are normal transitions, not error paths to be designed away.
- There are four terminal states, not one, and they are not interchangeable: confirmed-and-fix-verified, closed-as-not-a-defect, parked-as-unreproducible, and won't-fix. Parked is explicitly re-enterable — a new observation can revive it, so it cannot be modeled as a dead end.
- The coding agent is opaque: this system never observes its internal state. Both handoff to the coding agent and "fix landed, re-verify" arrive only as a human trigger. While an item sits in the handed-off state, no transition on it is permitted absent that trigger.
- Four kinds of transitions are human-locked: (1) confirm-defect, (2) hand off to coding agent, (3) fix landed / begin re-verification, (4) close item. Each requires a single-use verdict token minted only from the user's own turn (matching the existing signoff mechanism), and each token must bind to a specific item and a specific transition — not merely the project — so a verdict cannot be replayed against a different item.
- Re-verification depends on the original reproduction procedure, so the item record must carry the reproduction steps alongside its current state, not just a phase name.

## What will be done

Rewrite docs/specs/qa-cycle-state-machine.md so its primary state/transition table is keyed on the feedback item rather than the project: define the item's states (including the four terminal states and the handed-off state), its transitions (including the backward edges above), the four human-locked transitions and their verdict-token binding (item + transition), and the item record's required fields (state, reproduction steps, terminal-state variant where applicable). Add a decision record under docs/decisions/ capturing the axis change itself — why per-item replaces per-project as the unit of state — as a discrete architectural decision distinct from the spec content.

Also reword the directive text in `intake/hooks/directive.sh`, `testrun/hooks/directive.sh`, `bugreport/hooks/directive.sh`, `regress/hooks/directive.sh`, `stats/hooks/directive.sh`, `qa-cycle/hooks/directive.sh`, `signoff/hooks/directive.sh`, and `signoff/commands/go-no-go.md` onto the new item-axis state vocabulary — each of these currently names old per-project phases (`intake-scoping`, `session-chartered`, `session-executed`, `finding-triage`, `Confirmed-Defect`, `closed-not-a-defect`, `report-filed`, `regression-gated`, `exit-readiness`, `go-no-go`, `Go`, `No-Go`, `Shipped-Under-Exception`) verbatim in prose. This edit is vocabulary-only: it swaps the old state names for the new item-axis names wherever they appear in directive or command text. It does not change what any directive enforces, does not change hook registration, and does not change any hook's control flow.

## Explicitly out of scope

- Any change to qa-cycle/hooks/transition-gate.sh's transition-table logic, to how signoff tokens are minted (including signoff/hooks/capture-verdict.sh's phase-keyed verdict detection), or to the on-disk state file layout the hooks read. These implement the current per-project axis and are left as-is; a follow-up unit updates them to the new axis. Landing this spec while that code still enforces the old axis leaves spec and code temporarily divergent — that gap is real and is exactly what the follow-up unit closes, not a defect of this unit. The directive-file wording edits added to this proposal's write set (above) do not extend to these files: they are prose-only edits to hook/command directive text, not to gate logic, token-minting logic, or the state-file layout, and none of the listed directive files perform any of those three things.
- The token-consumption-timing defect already recorded in docs/reports/2026-07-29-hunt-gate-execution-check.md. Unrelated to the axis change; not touched here.

## Why the write set grew

`docs/reports/2026-07-30-hunt-item-axis-state-machine.md` found that `bugreport/hooks/directive.sh` hardcodes the per-project phase vocabulary this rewrite retires, and that it was covered by neither the write set nor the out-of-scope list — an omission that would ship a directive quoting state names that no longer exist. Grepping every plugin hooks/commands file (`qa-cycle/`, `signoff/`, `intake/`, `testrun/`, `bugreport/`, `regress/`, `stats/`) for the same phase vocabulary found seven more directive/command files with the identical problem; those are now listed in `files:` above alongside `bugreport/hooks/directive.sh`. `qa-cycle/hooks/transition-gate.sh` and `signoff/hooks/capture-verdict.sh` also hardcode the vocabulary but do so as gate/token-minting logic, not directive prose, so they remain covered by the existing "Explicitly out of scope" exclusions rather than added to the write set.

## How this will be known to have worked

The rewritten spec is reviewable against every constraint above: an item's state and reproduction steps can be traced through at least one full backward-edge cycle (e.g., handoff → re-verify fails → back to reproduction) without leaving the item's own record; all four terminal states are distinct and parked-as-unreproducible has a defined re-entry transition; each of the four human-locked transitions names its verdict-token binding as item+transition; and the decision record states the per-item-vs-per-project choice and its rationale independently of the spec prose.

## What did not work

- The frozen contract does not name which plugin owns each item-axis transition; the ownership map had to be inferred from the old spec's map and each plugin's existing directive prose rather than being handed down. Flagged as an inference, not a verbatim carryover.
- `bugreport/hooks/directive.sh`'s old `closed-not-a-defect` bullet conflated "not reproducible" (WorksForMe/Invalid) with "reproduced but not a defect" (Invalid/WontFix judgment). The new vocabulary splits these across `parked-unreproducible` (testrun-owned) and `not-a-defect`/`wont-fix` (bugreport-owned, human-locked). Reworded the bullet to only cover the latter and pointed the former at `parked-unreproducible`.

