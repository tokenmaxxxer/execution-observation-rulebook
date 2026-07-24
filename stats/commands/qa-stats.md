---
description: Trust accounting — follow every issue filed from the workspace's run records to its tracker outcome; report acceptance rate, noise rate, and backlog
argument-hint: "[--since YYYY-MM-DD] [--all]"
---

Report the QA stack's production signal. Scope: $ARGUMENTS

## 0. Read-only

This command never modifies run records, evidence, or issues. It only reads
run records from the QA workspace (`$QA_WORKSPACE`, default `~/qa-workspace`)
and queries the tracker.

## 1. Collect

Read every `<workspace>/projects/<slug>/runs/*.md` for the current project
(`<slug>` = `<owner>-<repo>` from the origin remote; with `--all`, every project in
`projects/` — report per project plus a total). If `--since` is given, keep
only records whose filename date is on or after it. From each record collect:

- case-table totals: pass / fail / blocked rows, for context
- from each **Failures** block, the `Filed:` entry, in three classes:
  - `<issue URL>` — a new issue this stack filed
  - `DUP(<issue URL>)` — reproduction added as a comment to an existing issue
  - `UNFILED(<reason>)` — confirmed failure, not filed; keep the reason

## 2. Resolve outcomes

For each unique issue URL (filed and DUP targets alike):
`gh issue view <url> --json state,stateReason,closedAt`. Classify:

- **fixed** — CLOSED with stateReason COMPLETED
- **rejected** — CLOSED with stateReason NOT_PLANNED (noise: judged not
  worth acting on, a duplicate we missed, or wrong)
- **open** — still OPEN; note age since the run that filed it

If `gh` cannot reach an issue (private repo, deleted), count it separately as
**unreachable** — never guess an outcome.

## 3. Report

One compact table plus the rates. Decided = fixed + rejected.

```
QA stats — <n> runs, <date range>

cases      run <n>   pass <n>   fail <n>   blocked <n>
filed      <n>   (+ <n> DUP conversions, <n> UNFILED)

outcomes   fixed <n>   rejected <n>   open <n> (median age <d>d)   unreachable <n>

acceptance rate   fixed / decided        = <x>%    <- the trust number
noise rate        rejected / decided     = <x>%
UNFILED reasons   <reason>: <n>, ...
```

Then two or three sentences of interpretation, no more:

- The acceptance rate is the number that says whether humans act on what
  this stack files. Falling acceptance or rising noise means filing discipline
  needs tightening (stricter reproduction, higher severity bar) — not more
  filing.
- If most decided issues are still open, say the sample is too small to judge
  and when to re-run.

## 4. Record nothing

Print the report; do not write it anywhere. When signoff lands (roadmap) it
will pull the same numbers into its plan-vs-run summary.
