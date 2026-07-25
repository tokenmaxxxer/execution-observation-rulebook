#!/usr/bin/env bash
# UserPromptSubmit hook: injects the regression-gating discipline.
# Kill switch: export QA_REGRESS_DISABLE=1

# Off means off: only explicit truthy-ish values disable the hook.
case "${QA_REGRESS_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
<qa-regress-directive priority="high">
SURFACE GATE: applies once a human says a fix landed for a handed-off item — a bug commit and a fix commit both exist. Inert for any other kind of work.

TRIGGER CONDITIONS: an item enters `re-verifying` (`handed-off -> re-verifying`, human trigger); or the user invokes `/regress` against an issue URL or run-record failure reference.

RULES:
- The three-check adoption gate is not a manual-only step: it now runs automatically on the `re-verifying` re-run, not only when a human types `/regress`. Whenever a handed-off item's fix commit becomes resolvable, run the gate before treating the item as `verified-fixed`.
- The gate requires, in order, as its evidence: (1) the test FAILS on the bug commit — a pass here means it detects nothing; (2) the test PASSES on the fix commit; (3) the test is STABLE — it passes all k=5 repeats on the fix commit. A test that is flaky at birth is discarded, not quarantined.
- If the environment cannot be prepared at some commit, that is BLOCKED, not a failed check — record `REGRESS-BLOCKED(<reason>)` and stop; the test is neither adopted nor condemned.
- Adopt only on all three checks passing: keep the test under `<project-dir>/regress/`, append `REGRESS-ADOPTED(<test path>)` to the run-record failure entry. Any check failing: discard — delete the test file, append `REGRESS-DISCARDED(passed-on-bug-commit | failed-on-fix | flaky <n>/<k>)`.
- The per-check pass/fail log for all three checks is the required evidence for this transition; it must exist before the transition is treated as complete.

NEVER:
- adopt a test without all three checks having actually run and passed in this session.
- treat a passing test on the bug commit as anything but a reason to discard.
- write the test's content, the gate log, or any regression-test material into `state.md` — those live under `<project-dir>/regress/` and the run record. This plugin never writes the cycle's state file itself; it requests the transition and lets `qa-cycle` record it.

COMPOSITION: receives the cycle from `bugreport`/`signoff` (a handed-off item whose fix commit is now known and re-verification triggered, `handed-off -> re-verifying`) and hands off to `stats`/`testrun` (the adopted test runs on every future `/testrun`, feeding readiness accounting).
</qa-regress-directive>
EOF
exit 0
