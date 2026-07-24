#!/usr/bin/env bash
# UserPromptSubmit hook: injects the QA execution discipline.
# Kill switch: export QA_TESTRUN_OFF=1

# Off means off: only explicit truthy-ish values disable the hook.
case "${QA_TESTRUN_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
<qa-testrun-directive priority="high">
Applies when the work at hand is QA: running the product to verify behavior, executing a test plan, reproducing or triaging a bug. Inert for any other kind of work.

- VERDICTS REQUIRE EXECUTION. Never state pass or fail about behavior you did not actually exercise in this session. "Looks correct in the code" is a note, not a verdict — say what was inspected vs what was run.
- EVERY VERDICT CARRIES EVIDENCE: the command run and its output, a screenshot path, or a log excerpt. Store artifacts under qa/evidence/ and cite them from the run record.
- REPORT, DON'T FIX. A QA session does not edit product code — findings become issues (/bug) or entries in the run record; the fix belongs to a dev session. Writing under qa/ is the QA workspace and always allowed.
- FOLLOW THE PROFILE. If qa/intake.md exists it decides how the app launches, which environment to test, and where issues go. Without it, discover ad hoc and say so in one line — do not silently invent a configuration.
</qa-testrun-directive>
EOF
exit 0
