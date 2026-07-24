# bench — seeded-bug evaluation harness

The house rule says a policy that loses its ablation gets removed. That rule
is unenforceable without an instrument. This directory is the instrument: a
corpus of small target apps with **seeded bugs**, an answer key the agent
never sees, and a protocol that measures whether the stack actually changes
QA behavior.

`/qa-stats` is the *production* signal (do humans act on what we file);
bench is the *development* signal (does a change to the stack catch more,
file less noise, keep evidence discipline). Change a directive, run bench,
keep or revert.

## Layout

```
bench/
  targets/<name>/     # a self-contained buggy app — this is ALL the agent may see
  answers/<name>.json # the seeded-bug key — never enters the run environment
```

The separation is the hiding mechanism: a run copies `targets/<name>/` (and
nothing else) to a fresh temp directory. `answers/` stays behind.

## Protocol

Two arms per target, N repetitions each (start with N=3):

- **on** — stack installed; run headless: `claude -p "/testrun"` in the copy,
  with `QA_WORKSPACE` pointed at a fresh temp workspace for that run.
- **off** — no stack; run headless with the bare prompt: `"QA this app: run
  it, try the main flows and obvious failure paths, write findings to
  qa/runs/ with evidence."`

Per run, before scoring: `git -C <copy> status` style check — collect the
run record and evidence (on arm: from the temp workspace; off arm: from the
copy's `qa/`), and **any modification to the copy** (on arm: any write at all
violates the workspace contract; off arm: writes outside `qa/`).

Bench copies have no tracker configured, so the `/bug` path lands on
`UNFILED(no tracker)` — scoring reads run records, not real issues.

## Metrics

| metric | how |
|---|---|
| **detection rate** | failures in the run record matching answer-key entries / seeded bugs. Adjudication: a finding counts when it names the trigger behavior and the wrong outcome of that key entry; variants of one root cause count once (the key marks these). Manual for now — the key is small. |
| **false-finding rate** | reported failures matching no key entry / all reported failures. (A real unseeded bug found = fix the target or add it to the key; don't punish the agent.) |
| **evidence discipline** | verdict rows citing an evidence path or inline command+output / all verdict rows — mechanically greppable in the run record. |
| **product-write violations** | runs that modified any product file (outside `qa/`) — should be **zero**. |

## The gate trigger (recorded decision)

The design record defers the "report, don't fix" `PreToolUse` gate until
drift is observed. Bench is the observation device: **if any bench run shows
a product-write violation, that is the drift — implement the gate.** Until
then the thin directive stands.

## Targets

| target | seeded | status |
|---|---|---|
| [todo-cli](targets/todo-cli/) | 6 bugs (crash on bad input, missing validation, corrupt-state crash, off-by-one, silent data loss, state not reflected) | ready |
| web-ui | — | roadmap: exercises the browser-automation path |
| rest-api | — | roadmap: exercises the curl path |

Honest label: no bench numbers have been produced yet — the stack stays
"Unbenchmarked" until the first on/off comparison is run and written up.
