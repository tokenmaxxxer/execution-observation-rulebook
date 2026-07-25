---
status: approved
issue: 3
files:
  - docs/specs/qa-cycle-state-machine.md
  - docs/decisions/2026-07-26-human-gate-over-pipeline-gate.md
---

## Intent

Turn the landed research into a specified QA cycle: states, legal transitions, required evidence per transition, and which transitions are human decisions. The spec is the thing hooks and gates get built from in a later unit; nothing is enforced yet.

## Constraints

- Every state and transition traces to a claim in `docs/reports/research/2026-07-25-qa-practice-landscape.md`; anything invented beyond it is marked as such.
- Human-gate model over pipeline-gate model, settled in advance (see the decision record in the write set). Where the research recorded the dispute, the spec cites it and states which side this project took.
- Session state persists in the external `qa-workspace` repo under `projects/<owner>-<repo>/`; the spec names the on-disk shape but writes no code and touches no file in that repo.
- Plugin boundaries are not protected: the spec assigns an owner to each transition and calls out where the current six plugins do not line up.
- Severity and priority stay two separate fields with separately attributable setters, per the research.

## What will be done

Write `docs/specs/qa-cycle-state-machine.md` covering:

1. The cycle states and the one-line meaning of each.
2. The transition table: from-state, to-state, trigger, required evidence, actor (agent / human / either).
3. The human decision points, each with what a person is actually deciding and what evidence they are shown.
4. The persisted session-state shape under `qa-workspace/projects/<owner>-<repo>/`, and what is written at each transition.
5. Ownership map: which plugin owns which transitions today, and which transitions have no owner or a mismatched one.

Also write `docs/decisions/2026-07-26-human-gate-over-pipeline-gate.md`: chosen, over what, why, three to ten lines, linking to the research report.

## Out of scope

Hooks, commands, plugin manifests, the installer, benchmarks. Any edit to plugin directories. Any write into the qa-workspace repository. Implementation of the state machine.

## How I will know it worked

A reader can take the transition table alone and say, for any given transition, what must be true to take it, what evidence proves it, and whether an agent may take it without a human — with no return to the research report.
