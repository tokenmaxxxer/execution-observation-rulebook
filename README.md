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

## The QA record contract

Everything the stack produces lives **in the target repo itself**, under
qa's own record area, per `docs/specs/role-handoff-contract.md` §10 — one
subject directory per piece of work. A session that dies resumes from disk,
and every other role (or a fresh QA session) can read qa's full record from
a clean checkout of the target repo alone, with no external host path
required:

```
docs/reports/records/<subject>/
  qa.md                  # the blackboard record: verdict, pointer, common header
  qa/
    intake.md            # the profile (env var NAMES only — never secrets)
    plan.md               # optional test plan (roadmap: /testplan writes it)
    state.md              # per-item state machine (docs/handbooks/qa-cycle.md)
    tokens/                # verdict tokens, minted by signoff from the user's own turn
    runs/                 # one record per run: case table, failures, issue URLs
    evidence/              # screenshots, outputs, logs cited by run records
    regress/               # adopted regression tests, run by /testrun every run
```

The two things that stay project-side by design remain unchanged by this:
**bug reports** go to each project's own tracker (the tracker is the QA→dev
handoff, so it must be where the devs look), and an adopted regression test
*may* additionally be PR'd upstream when a project wants it in its own CI.
Transient execution scratch a session needs mid-run (a working file it does
not intend to keep) uses a session temp directory (`mktemp -d`), never a
durable side repo or host-local path that outlives the session.

## Install

The stack installs into the target repo (or the environment that runs QA
against it) like any other plugin — there is no separate external workspace
repo to provision or point an env var at anymore.

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

**WAKES-ON.** qa wakes on any commit touching `src/` or `tests/` in the
running system (contract §3, qa's row). This replaces the old ACCEPTS
framing entirely — v2 has no accept/refuse-at-handoff moment for qa to gate
on; there is no single moment at which qa is handed a parcel and must decide
whether to take it.

**READ / DEPENDS-ON / NEVER-OVERWRITE** (contract §4, §11).

- READ is broad and unconditional: qa may open any board record, including
  `feasibility-record`, `hypothesis`, `build-proposal`, `review-record`, and
  `ops-record`, as advisory context — for example, `feasibility-record`'s
  `measurement_design`. This is a **reversal** of the previous text, which
  read "qa... uniformly refuses `hypothesis`, `build-proposal`,
  `feasibility-record`, `review-record`, and `ops-state` if any is handed
  over as if it were required input" — that was a read-ban in practice, and
  v2 explicitly is not one.
- DEPENDS-ON is empty for qa. The direct-observation principle survives, but
  as the *reason* DEPENDS-ON is empty, not as a read ban: a qa verdict must
  be built from direct observation of the running system, never cited as
  resting on another role's record, even though qa may read that record.
- NEVER-OVERWRITE: qa writes only `docs/reports/records/<subject>/qa.md` and
  `docs/reports/records/<subject>/qa/**`. An existing record already at a
  path qa does not own under `docs/reports/records/`: refuse and report the
  conflict — path and whose territory it falls in — never overwrite or merge
  into it silently.

**Blackboard record spec** (§7, §2's `qa-record` row).

| kind | path | required fields beyond common header |
|---|---|---|
| `qa-record` | `docs/reports/records/<subject>/qa.md` plus `docs/reports/records/<subject>/qa/**` | `loop_state:` (`observed,reproducing,reproduced,handed-off,re-verifying,verified-fixed,not-a-defect,wont-fix`), plus the common header including `handoff_status` |

The two former output kinds, `qa-state` and `qa-evidence`, collapse into
this single `qa-record` kind — §2 defines one row per role, not two.

**The external, host-local, uncommitted workspace mechanism (formerly keyed
by an environment variable) is abolished entirely** — not just for the blackboard record, but as a mechanism: the
environment variable, every hook reference to it, and the gate logic that
used to refuse writes when it was unset are all gone. Intake profile, plan,
per-item state machine, verdict tokens, run records, evidence, and
regression tests all live in-repo now, under
`docs/reports/records/<subject>/qa/**` alongside `qa.md` itself, per
contract §10: "v1 kept qa's bulk evidence (intake profile, run logs,
regression history) in [the former external workspace mechanism], an
external, host-local, uncommitted tree, with only a thin pointer record left
inside the repo. That exception is abolished." `qa-cycle/`'s `intake/`, `testrun/`, `bugreport/`, `regress/`,
`signoff/`, and `stats/` plugins all resolve and write these paths against
the target repo's own `docs/reports/records/<subject>/qa/` tree now — see
`docs/proposals/2026-07-27-qa-records-in-target-repo.md`, which finished the
conformance that `docs/proposals/2026-07-26-contract-v2-conformance.md`
deferred as a follow-on.

**Finding back-edge** (§5). qa produces `finding` blocks
`addressed_to: coding` for defects it finds. §3's WAKES-ON table gives
coding, not qa, the row that wakes on a `finding addressed_to` it. qa's own
WAKES-ON row is exclusively the `src/`/`tests/` commit trigger above — qa
does not also wake on findings addressed to it.

**Cycle termination** (§6, qa↔coding). A `finding` from qa produces a
`finding-response` from coding; coding's fix produces a new commit; that
commit wakes qa again (§3). The cycle terminates only when a qa wake
produces a `verified-fixed` write with no new `finding`, or a genuinely new
`finding`. Per §6: "a wake that reproduces an already-filed, unresolved
finding without adding new information is not a new board change... and
does not re-open the cycle" — this is what keeps qa↔coding from
ping-ponging forever.

**Loop-termination rule** (§6, general form). A wake is consumed only by
writing the resulting record entry; writing nothing does not consume it.

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
