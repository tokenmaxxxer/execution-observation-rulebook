# tokenmaxxxer / qa-agent-rulebook

*[한국어](README.ko.md)*

A Claude Code plugin marketplace: a stack that
makes an agent **behave like a QA engineer** — launch the real product,
exercise it, and leave evidence-backed records where the team already works
(the project's own issue tracker, in its own templates and labels).

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
| [qa-agent-env](qa-agent-env/) | One-install bundle for the whole stack. | dependencies |

Roadmap (in order): **testplan** (spec → boundary/negative/state-transition
cases + traceability), **regress** (confirmed bug → automated regression test
in the project's own framework; flaky detection; `git bisect` on regressions),
**signoff** (plan-vs-run summary — decision material, not a verdict).

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

**Company / team (primary path)** — commit this to the target project's
`.claude/settings.json`; every user who opens the repo gets the stack
automatically (the boundary is repo access plus folder trust, not team
membership), and one committed `/qa-init` profile makes every session file to
the same tracker the same way:

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

For a private marketplace repo, have each member run `gh auth setup-git` once
so background marketplace updates can authenticate. Headless/CI sessions
(`claude -p`, without `--bare`) load the same repo-scope plugins — a scheduled
smoke run files issues with the same discipline.

**Individual (user scope)** — from any Claude Code session:

```
/plugin marketplace add tokenmaxxxer/qa-agent-rulebook
/plugin install qa-agent-env@tokenmaxxxer-qa
```

## Kill switches

`QA_INTAKE_OFF=1`, `QA_TESTRUN_OFF=1`, `QA_BUGREPORT_OFF=1` — each disables
its plugin's hook for the session. Only non-empty values other than
`0/false/no/off` count as off.

## Repo layout

- `.claude-plugin/marketplace.json` — the marketplace manifest.
- `intake/`, `testrun/`, `bugreport/`, `qa-agent-env/` — one directory per
  plugin, each with its own README.
- `docs/design.md` — the design record: function-first lineup, the 3-layer
  deployment model, roadmap.

All plugins are unbenchmarked as of v0.1.0 — labeled as such, per house rule.
