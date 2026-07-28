# tokenmaxxxer / qa-agent-rulebook

The `qa` role on contract v3. A qa session is spawned with two plugin
sets installed: this marketplace's `qa` plugin, and the
[tokenmaxxxer-core](https://github.com/tokenmaxxxer/tokenmaxxxer-core)
plugins (`core`, `terse`, `freelunch`, `scout`). Core owns the interaction
protocol — issue in, two-phase PR out (research/survey/proposal → human
review Approve → execution), branch `issue-<n>/qa`, record at
`docs/issue-<n>/reports/qa.md`. This rulebook owns only what is
qa-specific.

## What `qa` decides

What the running system actually does — by launching and exercising it.
Two rules run through everything: **verdicts require execution** (pass/
fail is only claimed about behavior actually exercised, with cited
evidence), and **report, don't fix** (a qa session never edits the
target; findings return in the qa record through the PR).

**qa never files issues.** Under v3 issues are user-authored only: a
confirmed defect goes into the record as a full bug report (steps,
expected-vs-actual, environment, evidence) on qa's PR; the human judges
it there and files the issue themselves if valid — which then enters the
backlog as a new requirement.

## What is here

    qa/hooks/directive.sh          SessionStart — the four facets: discovery-
                                   over-guessing research, charter + app-up
                                   survey, test-plan proposal with the bug-
                                   report anatomy, and the evidence-cited-
                                   verdict judgment bar (incl. the regress
                                   three-check gate and severity-yours/
                                   priority-human asymmetry)
    qa/hooks/record-fields-gate.sh s20 minimum content on the record
    qa/hooks/trailer-gate.sh       commits staging docs/issue-<n>/** carry
                                   `Subject: issue-<n>`
    qa/hooks/handbook-trigger-gate.sh  s21 same-turn handbook sync
    qa/commands/                   /qa-init (target discovery), /testrun
                                   (charter + session sheet), /regress
                                   (three-check adoption), /qa-stats
                                   (PR-outcome trust accounting)
    bench/                         seeded-bug evaluation harness (development
                                   instrument; unchanged)
    tests/                         repo-level checks (never installed)

Retired: the signoff plugin (verdict tokens — human verdicts are PR/issue
acts now), the item-axis state machine, bugreport's `gh issue create`
path, and the intake/testrun/regress/stats plugin shells (their commands
fold into `qa/commands/`).

## Record vocabulary

Item states: `observed, reproducing, reproduced, parked-unreproducible,
handed-off, not-a-defect, wont-fix, re-verifying, verified-fixed`
(terminal: `verified-fixed`/`not-a-defect`/`wont-fix`). Verdicts
`pass|fail|blocked` (evidence-cited); `severity: critical|major|minor|
trivial` (qa's call); `priority: now|next|later|someday` (the human's,
via PR/issue acts). Markers: `UNFILED(<reason>)`, `REGRESS-ADOPTED(<path>)`,
`REGRESS-DISCARDED(...)`, `REGRESS-BLOCKED(<reason>)`. Evidence lives
under `docs/issue-<n>/reports/qa/**` (core R5 role subtree).

## Install

    claude plugin marketplace add tokenmaxxxer/qa-agent-rulebook
    claude plugin install qa@tokenmaxxxer-qa

Kill switch: `QA_CYCLE_OFF=1`.

## Run the checks

    /bin/bash tests/parse-check.sh
    /bin/bash tests/run-gate-tests.sh
    /bin/bash tests/deny-only-check.sh
