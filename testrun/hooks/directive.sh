#!/usr/bin/env bash
# UserPromptSubmit hook: injects the QA execution discipline.
# Kill switch: export QA_TESTRUN_DISABLE=1

# Off means off: only explicit truthy-ish values disable the hook.
case "${QA_TESTRUN_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
<qa-testrun-directive priority="high">
SURFACE GATE: applies when the work at hand is QA execution — launching the product, running a test plan or ad-hoc smoke, chartering or closing a session, or triaging a failure surfaced from one. Inert for any other kind of work.

TRIGGER CONDITIONS:
- `/testrun` is invoked with a scope argument.
- a session is already chartered and cases remain to run or the timebox is still open.
- a case just verdicted `fail` and needs to be handed to triage.

RULES:
- `testrun` owns three spans of the QA cycle per the spec's ownership map:
  - `intake-scoping -> session-chartered`, triggered by `/testrun` invoked with a scope argument. Required evidence: a run-record header recording the scope and that the app is up (health check or landing page reached).
  - `session-chartered -> session-executed`, triggered by all chartered cases having run or the session timing out. Required evidence: the run-record case table — one row per case with a verdict (pass/fail/blocked) and evidence (command+output, screenshot, or log excerpt).
  - `session-executed -> finding-triage`, triggered by a case verdict of `fail`. Required evidence: that failing case's evidence entry, carried into the triage record.
- `testrun` never writes the cycle's state file (`state.md`) itself. It requests each transition above; `qa-cycle`'s `PreToolUse` gate is the sole authority that decides whether the write is permitted and the sole writer of `state.md`.
- SESSION DISCIPLINE (the evidence the gate will demand for testrun's transitions):
  - CHARTER BEFORE SESSION. Before executing anything, write the charter: scope, mission, and app-up confirmation, into the run record's header. A session with no charter has nothing for `session-chartered` to point at.
  - TIME-BOXED SESSION. Every charter names a timebox (explicit duration, or "until the case list is exhausted"). Running past it without a verdict per remaining case is itself a `blocked` verdict, not silence.
  - SESSION SHEET. The run record is the session sheet: it must carry a time breakdown (charter time vs. execution time, or start/end), free-form notes on what was observed, and an issues section listing every failure with its evidence pointer. This is the artifact `finding-triage` and `exit-readiness` both read from — an incomplete sheet blocks both.
  - VERDICTS REQUIRE EXECUTION. Never state pass or fail about behavior not actually exercised this session. Code reading produces notes, never verdicts.
  - REPORT, DON'T FIX. A QA session never edits the target project. Findings become issues (via `bugreport`) or run-record entries.
  - FOLLOW THE PROFILE. If `projects/<slug>/intake.md` exists, it decides app launch, environment, and where issues go. Without it, discover ad hoc and say so in one line.

NEVER:
- write or edit `state.md` directly — request the transition and let `qa-cycle`'s gate decide.
- claim a `pass`/`fail` verdict for anything not actually run this session.
- edit the target project's code.
- close a session without a session sheet (time breakdown, notes, issues) backing every verdict.

COMPOSITION: `testrun` receives the cycle from `intake` (`intake-scoping`, via `intake.md`) and hands off to the triage/bugreport layer once a case fails (`finding-triage`, feeding `bugreport`'s filing flow) and to `stats`/`exit-readiness` accounting once all planned coverage is run. `qa-cycle` is the spine every transition request passes through.
</qa-testrun-directive>
EOF
exit 0
