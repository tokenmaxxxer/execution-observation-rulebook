---
status: landed
issue: "#1"
files:
  - docs/reports/research/2026-07-25-qa-practice-landscape.md
---

## Intent

The QA rulebook has commands but no cycle. Before writing a state machine, research how QA engineers actually work so the states, transitions, and human gates come from practice rather than from guessing. The requester's framing that matters verbatim: coherence with the researched flow outranks preserving the current plugin boundaries.

## Constraints

- Research only; no plugin, hook, or command file is edited under this proposal.
- The six existing plugins may later be restructured or replaced — record that as an accepted possibility, do not act on it here.
- Findings must be traceable to named sources (standards bodies, practitioner literature, published team practices), and where a claim is contested between methodology camps, record it as contested rather than picking a winner.
- The output is a research report fixed to a point in time, not a living handbook.

## What will be done

Produce `docs/reports/research/2026-07-25-qa-practice-landscape.md` covering four axes:

1. Methodology lineages — formal/scripted process (ISTQB and successors), exploratory testing and session-based test management, risk-based testing. What each says about when testing starts, what artifacts it produces, and what it treats as done.
2. Judgment values of the role — the defect/intended-behavior boundary, severity vs priority as separate axes, reproducibility bar for filing, triage discipline, what practitioners consider a good vs a bad bug report.
3. Human gates in a real workflow — entry and exit criteria, triage meetings, who holds sign-off authority, release readiness decisions, and what evidence each gate demands.
4. The role under automation and AI — what shifted, what practitioners say did not shift, where automated agents currently fail QA judgment.

Each axis closes with an explicit mapping line: which candidate states, transitions, and human decision points it implies for the QA cycle.

## Out of scope

Writing the state machine itself. Editing any plugin, hook, command, or marketplace manifest. Benchmarks. The installer. Anything under `qa-workspace`.

## How I will know it worked

The report names, for each of the four axes, at least one concrete human decision point with the evidence a practitioner expects at that point — enough that the follow-up specification can be written from the report alone without returning to the sources.
