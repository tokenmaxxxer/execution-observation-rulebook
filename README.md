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
- **Report, don't fix.** A QA session never edits the target project;
  findings become issues or run-record entries. The fix belongs to a dev
  session.

## Plugins

| Plugin | QA function | How |
|---|---|---|
| [intake](intake/) | Per-project profile: issue repo, issue templates, labels, app launch, test conventions, report language — discovered once by `/qa-init`, frozen into the workspace's `projects/<slug>/intake.md` that every other plugin reads. `--check` doctors the environment. | command + `SessionStart` |
| [testrun](testrun/) | Execution: `/testrun` launches the app per the profile, runs the regression suite + plan (or an ad-hoc smoke of the main flows), and writes a run record where every case's verdict points at its evidence. | command + thin directive |
| [bugreport](bugreport/) | Reporting: `/bug` files a reproduced defect to the project's tracker — its template, its labels, its language — after a duplicate search; standard form only as fallback. | command + thin directive |
| [stats](stats/) | Trust accounting: `/qa-stats` follows every issue filed from the workspace's run records to its tracker outcome and reports acceptance rate, noise rate, duplicate conversions, and UNFILED reasons. Read-only. | command |
| [regress](regress/) | Regression: `/regress` turns a confirmed bug into a test adopted only through the gate — fails on the bug commit, passes stably (k=5) on the fix; anything less is discarded. Adopted tests run on every `/testrun`. | command |
| [qa-agent-env](qa-agent-env/) | One-install bundle for the whole stack. | dependencies |

Roadmap (in order): **testplan** (spec →
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

## The QA workspace contract

Everything the stack produces lives in **one central private repo** — the QA
workspace — one directory per target project. Target repos get nothing
committed (so projects the agent has no write access to are still testable),
and a session that dies resumes from disk:

```
$QA_WORKSPACE/            # default ~/qa-workspace (auto-created + git init)
  projects/<slug>/        # <slug> = <owner>-<repo> from the target's origin remote
    intake.md             # the profile (env var NAMES only — never secrets)
    plan.md               # optional test plan (roadmap: /testplan writes it)
    runs/                 # one record per run: case table, failures, issue URLs
    evidence/             # screenshots, outputs, logs cited by run records
    regress/              # adopted regression tests, run by /testrun every run
```

The two things that stay project-side by design: **bug reports** go to each
project's own tracker (the tracker is the QA→dev handoff, so it must be where
the devs look), and an adopted regression test *may* additionally be PR'd
upstream when a project wants it in its own CI.

## Install

The stack installs where the QA agent runs — not in every product repo. What
accumulates is knowledge, not software, and it accumulates in the QA
workspace repo (set `QA_WORKSPACE`, or let `~/qa-workspace` be created on
first use), read by whichever QA session visits a project.

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

## Handoff protocol

The authoritative contract is the work repo's own
`docs/specs/role-handoff-contract.md` — not a copy pinned to any SHA in this
or any other repo. This section describes only how the qa role behaves
against whatever contract the work repo carries; `qa-cycle/hooks/transition-gate.sh`
resolves that repo's git root and refuses handoff-protocol actions if that
file is absent there, rather than proceeding without one.

**ACCEPTS.** None. qa works from direct observation of the running system,
not from other roles' records. It uniformly refuses `hypothesis`,
`build-proposal`, `feasibility-record`, `review-record`, and `ops-state` if
any is handed over as if it were required input.

**WHERE UPSTREAM LIVES.** Not applicable — qa accepts no upstream kind, so
there is no pointer for it to resolve.

**PRODUCES.**

| kind | path | required fields beyond common header |
|---|---|---|
| `qa-state` | `docs/reports/records/<subject>/qa.md` (in-repo pointer) | role status (`observed,reproducing,reproduced,handed-off,re-verifying,verified-fixed,not-a-defect,wont-fix`), `path:` pointer into `$QA_WORKSPACE`, plus the common header including `handoff_status` |
| `qa-evidence` | `$QA_WORKSPACE/projects/<owner>-<repo>/**` (out-of-repo, section 6 exception) | intake profile, bug reports, regression records, run stats — as defined by this rulebook's own templates |

**STOPS.**

- Upstream stale at role entry: applies only if qa is ever handed a pointer
  despite accepting nothing — the check still exists as a backstop.
- An existing record already at a path qa does not own under
  `docs/reports/records/`: refuse and report the conflict — path and whose
  territory it falls in — never overwrite or merge into it silently.
- Input carrying `handoff_status: provisional` that qa is not permitted to
  consume as final: moot in the common case since qa accepts no kind, but
  stated for the edge case of a stray handoff.

## Kill switches

`QA_INTAKE_OFF=1`, `QA_TESTRUN_OFF=1`, `QA_BUGREPORT_OFF=1` — each disables
its plugin's hook for the session. Only non-empty values other than
`0/false/no/off` count as off. stats ships no hook, so it needs no switch —
a command you don't invoke is off.

## Repo layout

- `.claude-plugin/marketplace.json` — the marketplace manifest.
- `intake/`, `testrun/`, `bugreport/`, `stats/`, `regress/`, `qa-agent-env/`
  — one directory per plugin, each with its own README.
- `bench/` — the seeded-bug evaluation harness: target apps, hidden answer
  keys, and the on/off protocol that measures the stack.
- `docs/design.md` — the design record: function-first lineup, the 3-layer
  deployment model, roadmap.

All plugins are unbenchmarked as of v0.1.0 — labeled as such, per house rule.
`bench/` is the harness meant to change that.
