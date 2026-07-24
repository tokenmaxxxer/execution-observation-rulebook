# tokenmaxxxer / qa-agent-rulebook

*[한국어](README.ko.md)*

A Claude Code plugin marketplace: a stack that
makes an agent **behave like a QA engineer** — launch the real product,
exercise it, and leave evidence-backed records where the project already
keeps them (its own issue tracker, in its own templates and labels).

Function-first, not philosophy-first: each plugin maps to a piece of the
actual QA cycle — **profile → run → report** in v0.1, with design, regression,
and sign-off on the roadmap. It shares packaging with the sibling
[coding-agent-rulebook](https://github.com/tokenmaxxxer/coding-agent-rulebook)
(marketplace layout, thin hooks, kill switches, honest benchmark labeling),
not its thesis.

Two rules run through everything:

- **Verdicts require execution.** Pass/fail is only claimed about behavior
  actually exercised, and every verdict cites evidence — a command and its
  output, a screenshot, a log excerpt. Reading the code produces notes,
  never verdicts.
- **Report, don't fix.** A QA session never edits product code; findings
  become issues or run-record entries. The fix belongs to a dev session.

## Plugins

| Plugin | QA function | How |
|---|---|---|
| [intake](intake/) | Per-project profile: issue repo, issue templates, labels, app launch, test conventions, report language — discovered once by `/qa-init`, frozen into a committed `qa/intake.md` that every other plugin reads. `--check` doctors the environment. | command + `SessionStart` |
| [testrun](testrun/) | Execution: `/testrun` launches the app per the profile, runs the plan (`qa/plan.md`) or an ad-hoc smoke of the main flows, and writes a run record where every case's verdict points at its evidence. | command + thin directive |
| [bugreport](bugreport/) | Reporting: `/bug` files a reproduced defect to the project's tracker — its template, its labels, its language — after a duplicate search; standard form only as fallback. | command + thin directive |
| [stats](stats/) | Trust accounting: `/qa-stats` follows every issue filed from `qa/runs/` to its tracker outcome and reports acceptance rate, noise rate, duplicate conversions, and UNFILED reasons. Read-only. | command |
| [qa-agent-env](qa-agent-env/) | One-install bundle for the whole stack. | dependencies |

Roadmap (in order): **regress** (confirmed bug → automated regression test in
the project's own framework, committed only if it fails on the buggy commit
and passes stably on the fix; flaky detection; `git bisect` on regressions),
**testplan** (spec →
boundary/negative/state-transition cases + traceability), **signoff**
(plan-vs-run summary — decision material, not a verdict; `/qa-stats` already
carries its outcome-tracking half).

## The QA→dev loop

"Report, don't fix" has a second half: **the tracker is the handoff.** This
stack files issues; the sibling
[coding-agent-rulebook](https://github.com/tokenmaxxxer/coding-agent-rulebook)'s
dispatch plugin turns an issue into a PR that `Closes` it. QA sessions never
fix, dev sessions never file — the interface between the two stacks is the
project's issue tracker, and both ends of the exchange are recorded in git.

## The `qa/` directory contract

Everything the stack produces lives in the target project, committed, so a
session that dies resumes from disk and every user shares one state:

```
qa/
  intake.md        # the profile (env var NAMES only — never secrets)
  plan.md          # optional test plan (roadmap: /testplan writes it)
  runs/            # one record per run: case table, failures, issue URLs
  evidence/        # screenshots, outputs, logs cited by run records
```

## Install

The stack installs where the QA agent runs — not in every product repo. What
lives per project is knowledge, not software: one committed `qa/intake.md`
profile, read by whichever QA session visits.

**QA agent environment (primary path)** — a one-time user-scope install in
the environment that does the QA work:

```
/plugin marketplace add tokenmaxxxer/qa-agent-rulebook
/plugin install qa-agent-env@tokenmaxxxer-qa
```

Dev sessions on the product repos stay untouched — QA directives reach only
the environment that installed the stack. For a private marketplace repo, run
`gh auth setup-git` once so background marketplace updates can authenticate.
Headless runs (`claude -p "/testrun"`, without `--bare`) use the same install
— a scheduled smoke run files issues with the same discipline.

**Repo-scoped (optional)** — to pin the stack to a specific repo instead, so
every user who opens it gets it automatically (the boundary is repo access
plus folder trust), commit this to that repo's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "tokenmaxxxer-qa": {
      "source": { "source": "github", "repo": "tokenmaxxxer/qa-agent-rulebook" }
    }
  },
  "enabledPlugins": {
    "qa-agent-env@tokenmaxxxer-qa": true
  }
}
```

## Kill switches

`QA_INTAKE_OFF=1`, `QA_TESTRUN_OFF=1`, `QA_BUGREPORT_OFF=1` — each disables
its plugin's hook for the session. Only non-empty values other than
`0/false/no/off` count as off. stats ships no hook, so it needs no switch —
a command you don't invoke is off.

## Repo layout

- `.claude-plugin/marketplace.json` — the marketplace manifest.
- `intake/`, `testrun/`, `bugreport/`, `stats/`, `qa-agent-env/` — one
  directory per plugin, each with its own README.
- `bench/` — the seeded-bug evaluation harness: target apps, hidden answer
  keys, and the on/off protocol that measures the stack.
- `docs/design.md` — the design record: function-first lineup, the 3-layer
  deployment model, roadmap.

All plugins are unbenchmarked as of v0.1.0 — labeled as such, per house rule.
`bench/` is the harness meant to change that.
