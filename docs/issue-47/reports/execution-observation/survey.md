# issue-47 current-state survey (execution-observation, phase 1)

## What exists today

- `qa/hooks/directive.sh` — role-directive stub sourcing core's
  `role-directive.sh`. Four variable bodies (`you_decide`, `use_when`,
  `produces`, `hand_off`) carry the execution-observation methodology
  adopted in issue-41 (verdicts-require-citation, three-level
  outcome/trajectory/step verdict, independence statement, blameless
  single-finding anomaly shape, record-first-act-of-phase-2). This is
  the "directive" half of the issue's ask; it is prose only — nothing
  machine-checks that a written record actually contains these
  elements.
- `qa/hooks/hooks.json` — registers only `SessionStart` →
  `directive.sh`. No `PreToolUse` gate is registered by this plugin
  (issue-42 removed the vendored trailer/handbook/record-fields gates
  in favor of core's role-agnostic global registration — confirmed via
  `grep -c PreToolUse qa/hooks/hooks.json` = 0 in `docs/issue-42/reports/implementation.md`).
- `tests/parse-check.sh`, `tests/stub-check.sh`, `tests/deny-only-check.sh`,
  `tests/run-gate-tests.sh` at repo root (272 lines total, `wc -l`).
  `run-gate-tests.sh` currently exercises only core's generic
  `record-fields-gate.sh` (with `qa`'s old field vocabulary, now stale
  — see gap below) and `trailer-gate.sh`, both by real subprocess
  invocation with synthetic PreToolUse payloads. No test in this repo
  exercises anything specific to the execution-observation methodology
  (three-level verdict, citation, independence statement).
- No `agents/` directory and no warrant-hunter file anywhere in this
  repo (re-confirmed this session, same finding as issue-41's survey
  and issue-42's implementation record).
- `docs/issue-41/proposals/execution-observation-proposal.md` section
  (d) is the adopted methodology-source document this issue's directive
  says to convert into enforcement: it names four items — directive
  text (done, issue-41 phase 2), `RECORD_FIELDS_TERMINAL_STATES`
  (attempted, blocked by sandbox write denial — still unresolved per
  `docs/issue-41/reports/execution-observation.md`'s "Next steps"), no
  new gate (stated at the time, before this issue asked for one), no
  warrant-hunter (n/a).

## Gaps this issue's ask targets

1. **Directive depth.** The current four variable bodies are already
   non-trivial (issue-41 raised them above one-line-summary), but they
   do not separately spell out phase-1 vs phase-2 judgment criteria
   *per facet* the way the issue asks ("단계·판단 기준·금지사항,
   facet별 실행 가능한 수준"). E.g. "what counts as a valid citation"
   and "what disqualifies a scope statement" are not stated as
   checkable criteria, only as goals.
2. **No mechanical produces-gate.** Nothing in this repo checks that a
   written `docs/issue-<n>/reports/execution-observation.md` (or a
   phase-1 proposal) actually contains: a citation per finding, all
   three verdict levels, an independence statement, or the blameless
   anomaly shape when a deficiency is claimed. A record could omit all
   of these and nothing in the plugin would refuse the write.
   `pricing-rulebook`'s `methodology-gate.sh` is the referenced
   sibling pattern for exactly this class of check (see
   `docs/issue-47/reports/execution-observation/scout-brief.md`).
3. **No ordering/state enforcement.** The adopted methodology has an
   implicit order (survey/read artifacts → verdict → record), but nothing
   tracks whether the artifacts were actually read before a verdict was
   written in the same session. `implementation-rulebook`'s
   `coding/hooks/hunt-state.sh` + `hunt-guard.sh` is the sibling
   pattern for state-tracked ordering (see scout-brief).
4. **No gate tests for this role's methodology.** `run-gate-tests.sh`
   only exercises the generic gates with `qa`'s stale terminal
   vocabulary; nothing exercises a methodology-specific pass/deny case
   for execution-observation.
5. **`RECORD_FIELDS_TERMINAL_STATES` still unset** — a pre-existing
   open finding from issue-41, not this issue's ask to fix directly,
   but relevant context: any new gate built here must not assume that
   env var is populated.

## Constraint reconfirmed

`docs/decisions/` "core canon-scripts.md" (referenced by the issue) —
core canon scripts (`role-directive.sh`, the three role-agnostic gates)
are sourced/referenced, never vendored into this repo. Confirmed no
copy exists here (`find . -iname '*gate*.sh'` under this repo returns
only `tests/run-gate-tests.sh`, a test harness, not a vendored gate).
