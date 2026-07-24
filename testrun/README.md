# testrun

The heart of the stack: QA that **runs the product**, not QA that reads the
code. `/testrun` launches the app per the intake profile, exercises it —
plan-driven when `qa/plan.md` exists, ad-hoc smoke of the main flows
otherwise — and leaves a run record where every verdict points at its
evidence.

## The two rules that define it

- **Verdicts require execution.** Pass/fail may only be claimed about behavior
  actually exercised in the session, and every verdict cites evidence: the
  command and its output, a screenshot, a log excerpt. Code reading produces
  notes, never verdicts.
- **Report, don't fix.** A QA session never edits product code. Findings
  become issues (via bugreport) or run-record entries; fixing belongs to a dev
  session. This keeps the QA record trustworthy — a tester who patches as they
  go is testing a product nobody else has.

Both are injected as a thin `UserPromptSubmit` directive, self-scoped to QA
work (running/verifying/reproducing) and inert for anything else, so the
plugin can stay enabled in a repo where dev work also happens.

## Artifacts

```
qa/
  runs/2026-07-24-smoke.md      # one record per run: case table + failures
  evidence/2026-07-24-smoke/    # screenshots, outputs, logs cited by the record
```

Run records are committed files, so an interrupted run resumes from disk and
any other user (or CI) can read exactly what was tested against which commit.

Kill switch: `QA_TESTRUN_OFF=1`.

Unbenchmarked as of v0.1.0.
