---
date: 2026-07-26
proposal: docs/proposals/2026-07-26-qa-cycle-state-machine.md
issue: "#3"
---

# QA Cycle State Machine

## Grounding

This spec derives from [docs/reports/research/2026-07-25-qa-practice-landscape.md](../reports/research/2026-07-25-qa-practice-landscape.md), specifically the "Implies for the QA cycle" candidate lists in each of its four sections (methodology lineages; judgment values of the QA role; human gates in a real QA workflow; the QA role under automation and AI). Those four lists overlap and sometimes conflict; this spec reconciles them into one coherent state/transition set rather than concatenating all four. Anything below not traceable to a claim in the research report is marked `[invented]` inline.

## States

- `intake-scoping` — the project's QA profile (tracker, templates, labels, app launch, test conventions) has been discovered and written; nothing has been tested yet.
- `session-chartered` — a QA run has a mission/scope and the target app is up; mirrors SBTM's charter-before-session discipline.
- `session-executed` — the chartered cases (regression suite, plan, or ad-hoc smoke) have been run to completion or timebox, with a verdict recorded per case.
- `finding-triage` — a failure from a session is under judgment: is it reproducible, is it actually a defect (the oracle problem), and does it have enough detail to act on.
- `report-filed` — a confirmed defect has been filed to the target project's own tracker, with severity and priority as two separately set fields.
- `regression-gated` — a fixed, filed defect is being turned into a regression test, gated on the three-check proof (fails on bug commit, passes on fix commit, stable across repeats).
- `exit-readiness` — planned coverage is accounted for (executed/deferred with reason) and a report of pass/fail/open-severity counts exists.
- `go-no-go` — a named human has reviewed the exit-readiness evidence and recorded Go, No-Go, or Shipped-Under-Exception.

## Transition table

| From | To | Trigger | Required evidence | Actor |
|---|---|---|---|---|
| (none) | `intake-scoping` | `/qa-init` run against the target repo | `intake.md` written with tracker/template/labels/app-launch/test-convention fields | agent |
| `intake-scoping` | `session-chartered` | `/testrun` invoked with a scope argument | run record header recording the scope and the app being up (health check or landing page reached) | agent |
| `session-chartered` | `session-executed` | all chartered cases run or the session timeboxed out | run record case table: one row per case with verdict (pass/fail/blocked) and evidence (command+output, screenshot, or log excerpt) | agent |
| `session-executed` | `finding-triage` | a case verdict is `fail` | the failing case's evidence entry, carried into the triage record | agent |
| `finding-triage` | `finding-triage` (needs-info) | reproduction steps, environment, or evidence are missing/ambiguous | a needinfo note naming the missing field(s) | agent |
| `finding-triage` | `report-filed` | the reporter judges the finding a genuine defect | a reproduction attempt logged against a matching build/OS, plus a human defect-confirmation record naming who made the call | human |
| `finding-triage` | `closed-not-a-defect` | the finding is judged not a defect, or not reproducible after a real attempt | a reproduction attempt logged against a matching build/OS, plus a human rationale (WorksForMe / Invalid / WontFix) | human |
| `report-filed` | `report-filed` (severity set) | severity is assigned | a severity value plus the identity of who set it, timestamped | human |
| `report-filed` | `report-filed` (priority set) | priority is assigned | a priority value plus the identity of who set it, timestamped — separately attributable from the severity setter | human |
| `report-filed` | `regression-gated` | the filed issue closes as fixed | a bug commit and a fix commit resolved from the issue/PR | agent |
| `regression-gated` | `regression-gated` (adopted or discarded) | the three-check gate runs (fails on bug commit, passes on fix commit, stable across k=5 repeats) | the per-check pass/fail log for all three checks | agent |
| `session-executed` (aggregate) | `exit-readiness` | planned coverage is fully accounted for | run records covering all planned cases (executed or deferred-with-reason) plus a stats report of pass/fail/open-severity counts | agent |
| `exit-readiness` | `go-no-go` | a readiness review is held | a named sign-off identity attesting to the evidence bundle (not a bare approval) | human |
| `go-no-go` (No-Go) | `go-no-go` (Shipped-Under-Exception) | a No-Go is deliberately overridden | a reason code, a named approver distinct from the No-Go issuer, and a follow-up ticket | human |

## Human decision points

- **Is-this-a-defect (the oracle-problem call).** The `finding-triage → report-filed` / `finding-triage → closed-not-a-defect` transitions. What is being decided: whether an observed behavior counts as a defect against the product's intent, when no written spec settles it mechanically. Evidence shown: the reproduction steps and output/screenshot, the expected-vs-actual delta, and (if one exists) the spec or prior-issue precedent. **The research reports that AI agents demonstrably fail this judgment** — under no clear success signal, agents produce false positives and inflate severity of minor findings (Irregular's web-security-agent evaluation, cited in "The QA role under automation and AI"). This spec therefore forbids an agent from taking either transition alone; both require the human actor.
- **Severity assignment.** The `report-filed` (severity set) transition. What is being decided: technical/functional impact (blocker..trivial), independent of scheduling. Evidence shown: the reproduction evidence and the affected scope (all users vs. narrow configuration). Forbidden for an agent alone, for the same demonstrated-failure reason above.
- **Priority assignment.** The `report-filed` (priority set) transition. What is being decided: fix order relative to other open work, weighing severity against schedule/business context/workaround availability. Evidence shown: the severity value, current backlog, and workaround status. Set by a separately attributable actor from severity (per the research's convention that the same severity can carry different priority under different shipping constraints).
- **Close-as-cannot-reproduce vs. keep chasing.** The `finding-triage → closed-not-a-defect` transition when the reason is non-reproduction. What is being decided: whether a failed reproduction attempt means the bug is false, or means the environment/build didn't match the original report. Evidence shown: the reproduction attempt's build/OS versus the original report's build/OS, and reporter credibility/history if available.
- **Exit-criteria-met attestation.** The `session-executed → exit-readiness` aggregate step, and specifically declaring it done. What is being decided: whether planned coverage and open-severity counts actually satisfy exit criteria, not whether the numbers merely exist. Evidence shown: the stats report (pass/fail/open-severity counts) and the list of deferred cases with reasons.
- **Go/no-go.** The `exit-readiness → go-no-go` transition. What is being decided: whether to ship, given the readiness evidence. Evidence shown: the full evidence bundle behind exit-readiness, plus any open exceptions. A No-Go override into Shipped-Under-Exception is its own explicit, escalated human decision (distinct approver from the one who issued the No-Go), never a silent equivalent to Go.

## Persisted session state

All state lives under `$QA_WORKSPACE/projects/<owner>-<repo>/` (default workspace root `~/qa-workspace` if `$QA_WORKSPACE` is unset), never in the target repo, and never as a copy of target code. Per the research and the existing plugins' own stated policy: env vars are recorded by name only, never by value.

- `intake.md` — written at `intake-scoping`. A reader can reconstruct: tracker repo, issue template path, labels, app launch/stop/ready commands, test framework and directory, env var names (unset values), and report language. This is the profile every later transition reads.
- `runs/<YYYY-MM-DD>-<slug>.md` — written across `session-chartered` through `session-executed`. A reader can reconstruct: the scope, the app version/commit tested, the full case table (verdict + evidence per case), and a `Filed:` line per failure (issue URL, `DUP(<url>)`, or `UNFILED(<reason>)`). This is the sole source `stats` and `regress` read from.
- `evidence/<run-slug>/` — written during `session-executed`. Holds the screenshots/log excerpts referenced from the run record; a reader can reconstruct what was actually observed, not just the verdict.
- Filed issues themselves live in the **target project's own tracker**, not in qa-workspace — `report-filed` and the severity/priority-set transitions write to `gh issue`, and the run record only stores the resulting URL. This matches the research's tracker-of-record convention (Bugzilla/Mozilla triage) and the existing `bugreport` plugin's behavior.
- `regress/<test-file>` — written at `regression-gated`. A reader can reconstruct which issue the test targets (from its name) and which commit it was proven against (from the gate log it was adopted with) — but the gate log itself is `[invented]`: the research and the current `regress` plugin describe the three checks but not a persisted log file distinct from the run record; this spec assumes one is needed so `exit-readiness` and audits don't have to replay the gate.
- Exit-readiness and go-no-go records — `[invented]`: no current plugin writes a dedicated file for these. This spec assumes a `readiness/<YYYY-MM-DD>-<slug>.md` recording the stats-report snapshot used, the sign-off identity, and the Go/No-Go/Shipped-Under-Exception verdict with (for the exception case) reason code, approver, and follow-up ticket. A reader can reconstruct the entire readiness decision from this file without re-deriving it from every run record.

## Ownership map

| Transition | Owning plugin today |
|---|---|
| `(none) → intake-scoping` | `intake` |
| `intake-scoping → session-chartered` | `testrun` |
| `session-chartered → session-executed` | `testrun` |
| `session-executed → finding-triage` | `testrun` (surfaces the failure; no dedicated triage step) |
| `finding-triage → finding-triage` (needs-info) | **no owner** |
| `finding-triage → report-filed` (is-this-a-defect = yes) | **no owner** — `bugreport` requires the argument to already be "reproduced," but does not itself run or record the oracle-problem judgment call; it composes and files, it doesn't decide |
| `finding-triage → closed-not-a-defect` | **no owner** — no plugin models WorksForMe/Invalid/WontFix at all |
| `report-filed` (severity set) | `bugreport` sets severity mechanically (project scheme or `sev:` fallback) as part of composing the issue — **mismatched owner**: this spec requires a human-attributed severity decision, but the plugin currently treats it as a template-fill step with no recorded human setter |
| `report-filed` (priority set) | **no owner** — no plugin sets or records priority at all |
| `report-filed → regression-gated` | `regress` |
| `regression-gated` (three-check gate) | `regress` |
| `session-executed (aggregate) → exit-readiness` | `stats` produces the pass/fail/filed/outcome numbers `exit-readiness` needs, but `stats` is explicitly read-only and never declares exit criteria met — **mismatched owner**: the attestation itself has no owner |
| `exit-readiness → go-no-go` | **no owner** — no plugin holds or records a sign-off identity |
| `go-no-go → Shipped-Under-Exception` | **no owner** |
| environment/doctor checks (`--check`) | `intake`, `qa-agent-env` (meta-plugin, bundles the other five, contains no transition logic of its own) |

The current six-plugin decomposition covers intake, execution, filing-composition, trust accounting (read-only), and regression-gating well. It has **no plugin at all** for the triage/judgment layer (needs-info, is-this-a-defect, closed-not-a-defect, priority) or the readiness/sign-off layer (exit-readiness attestation, go/no-go, exception shipping) — both are exactly the human-gated transitions this spec requires evidence and an attributable actor for. Per the proposal, plugin boundaries are not protected, so this is stated as a gap to fill, not a boundary to preserve: a future unit either extends `bugreport`/`stats` to record these attributions or introduces a new plugin for the triage and readiness layers.

## Open questions

- Whether severity should ever be reporter/agent-set as an initial good-faith estimate before human confirmation, versus only ever set by a human from the start — the research records this as contested (Bugzilla/Mozilla self-assignment convention vs. the view that reporters systematically overrate their own bugs) and this spec does not settle it; it only requires that whatever value ships as severity carries a human-attributed setter.
- How strict the "must reproduce to be actionable" bar should be, and how long a needinfo waits before `Incomplete` — the research notes Mozilla itself has no fixed universal timeout and leaves this to triager judgment; this spec does not fix a timeout.
- Whether priority is engineering-owned or jointly negotiated with QA/product in a triage meeting — the research records both conventions in practice; this spec only fixes that priority's setter must be separately attributable from severity's, not who that setter is.
- Whether the pyramid-shape and shift-left disputes in the research bear on this spec at all — they inform test-writing practice inside `session-executed` and `regression-gated` but this spec does not take a position on suite composition.

Note: the human-gate-vs-pipeline-gate dispute recorded in the research report's "Human gates in a real QA workflow" section is **not** open here — it is settled by [docs/decisions/2026-07-26-human-gate-over-pipeline-gate.md](../decisions/2026-07-26-human-gate-over-pipeline-gate.md), which chose the human-gate model.
