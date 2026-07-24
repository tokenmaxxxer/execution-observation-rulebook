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
- EVERY VERDICT CARRIES EVIDENCE: the command run and its output, a screenshot path, or a log excerpt. Store artifacts in the QA workspace under projects/<slug>/evidence/ and cite them from the run record.
- REPORT, DON'T FIX. A QA session does not edit the target project at all — findings become issues (/bug) or entries in the run record; the fix belongs to a dev session. Every QA artifact lives in the QA workspace ($QA_WORKSPACE, default ~/qa-workspace), never in the target repo.
- FOLLOW THE PROFILE. If the workspace has projects/<slug>/intake.md for this project, it decides how the app launches, which environment to test, and where issues go. Without it, discover ad hoc and say so in one line — do not silently invent a configuration.
</qa-testrun-directive>
EOF
exit 0
