# tokenmaxxxer / execution-observation-rulebook

The `execution-observation` role on contract v3. An
execution-observation session is spawned with two plugin sets
installed: this marketplace's `qa` plugin set (owning `qa/commands/`
and the `qa/hooks/directive.sh`/`hooks.json` sourcing stub, plus the
three `eo-*` plugins below), and the
[tokenmaxxxer-core](https://github.com/tokenmaxxxer/tokenmaxxxer-core)
plugins (`core`, `terse`, `freelunch`, `scout`). Core owns the
interaction protocol — issue in, two-phase PR out (research/survey/
proposal → human review Approve → execution), branch
`issue-<n>/execution-observation`, record at
`docs/issue-<n>/reports/execution-observation.md`. This rulebook owns
only what is execution-observation-specific.

## What `execution-observation` decides

Whether an observed role's phase-1→phase-2 execution was sound — by
reading its actual artifacts (PR diff, commits, its own record), never
by re-executing the observed task. One rule runs through everything:
**verdicts require citation** (never state a verdict about an artifact
not read this session; every claim names its source — commit SHA,
file:line, or PR comment URL).

**execution-observation never edits the observed artifact and never
files issues.** It never touches the observed role's `src/`, `test/`,
or record. Under v3 issues are user-authored only: a confirmed
deficiency goes into this role's own record (finding + evidence) on
its own PR; the human judges it there and files the issue themselves
if valid.

## What is here

    qa/hooks/directive.sh          SessionStart — installs the
                                   role-directive body via eo-directive
    qa/hooks/hooks.json            wires directive.sh and eo-state's
                                   session reset
    qa/plugins/eo-directive/       phase-gated role-directive body:
                                   research/current-state-survey/
                                   proposal facets for phase 1, the
                                   three-level (outcome/trajectory/
                                   step) verdict-judgment facet for
                                   phase 2
    qa/plugins/eo-methodology-gate/  PreToolUse gate (Write|Edit|
                                   MultiEdit) on this role's own write
                                   surfaces — phase-1 proposal
                                   completeness and phase-2 record
                                   independence-statement-before-
                                   verdict ordering plus blameless
                                   finding shape
    qa/plugins/eo-state/           session-scoped marker
                                   (`.claude/.eo-read-marker`) recording
                                   that at least one observed-role
                                   artifact has plausibly been read
                                   this session; consumed by
                                   eo-methodology-gate, produced here
    qa/commands/                   role-specific slash commands
    bench/                         seeded-bug evaluation harness
                                   (development instrument; unchanged)
    tests/                         repo-level checks (never installed)

See `docs/handbooks/execution-observation-plugins.md` for the full
per-plugin detail (gate-house standard library adoption, kill-switch
migration, test-case inventory).

## Install

    claude plugin marketplace add tokenmaxxxer/execution-observation-rulebook
    claude plugin install qa@tokenmaxxxer-execution-observation

Kill switches: `EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF=1`,
`EXECUTION_OBSERVATION_STATE_OFF=1`.

## Run the checks

    /bin/bash tests/parse-check.sh
    /bin/bash tests/run-gate-tests.sh
    /bin/bash tests/deny-only-check.sh
