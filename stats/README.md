# stats

Trust accounting for the QA stack. `/qa-stats` walks `qa/runs/`, follows every
`Filed:` entry to its tracker outcome via `gh`, and reports the one number
that decides whether an AI QA agent is useful: **do humans act on what it
files?**

## Why this exists

A QA agent's failure mode is not "finds too little" — it is filing noise
until humans stop reading. The production signal that catches this is
acceptance: of the issues the tracker has decided (closed), how many were
fixed vs closed as not-planned. Run records already carry everything needed
(`Filed: <url>`, `DUP(<url>)`, `UNFILED(<reason>)`); this plugin is just the
harvester.

## What `/qa-stats` reports

- **acceptance rate** — fixed / decided (the trust number)
- **noise rate** — rejected (closed not-planned) / decided
- **DUP conversions** — reproductions added to existing issues instead of twins
- **UNFILED reasons** — histogram
- open backlog with median age; case totals (pass/fail/blocked) for context

Read-only: it never modifies runs, evidence, or issues. Requires `gh` auth
(same requirement `/qa-init --check` verifies).

No hook, so no kill switch — a command you don't invoke is off.

Unbenchmarked as of v0.1.0 — it is the measuring instrument; its own
correctness is checked by inspection against the run records it reads.
