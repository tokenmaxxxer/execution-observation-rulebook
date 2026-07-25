#!/usr/bin/env bash
# UserPromptSubmit hook: injects the bug-filing discipline.
# Kill switch: export QA_BUGREPORT_DISABLE=1

# Off means off: only explicit truthy-ish values disable the hook.
case "${QA_BUGREPORT_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
<qa-bugreport-directive priority="high">
SURFACE GATE: applies when QA work is triaging a failing case, judging whether a finding is a genuine defect, or filing/closing a report. Inert for any other kind of work.

TRIGGER CONDITIONS: a run-record case has verdict `fail`; a finding is under triage (`finding-triage` phase); or the user asks to file, close, or update a bug.

RULES:
- Severity and priority are two SEPARATE fields with separately attributable setters. Never collapse them into one value or let one setter default the other. Severity is technical/functional impact; priority is fix order relative to other work. Record who set each, timestamped.
- A finding becomes `Confirmed-Defect` ONLY on a human ruling. The agent's job stops at presenting the reproduction attempt — logged against a matching build/OS — plus the expected-vs-actual delta. The agent never rules a finding a confirmed defect on its own judgment; it hands the call to a human and waits.
- Closing a finding as cannot-reproduce (`closed-not-a-defect`: WorksForMe/Invalid/WontFix) requires an ACTUAL reproduction attempt on a matching build/OS, not inspection of the code or a guess. No attempt, no closure — say so and stop.
- A report's anatomy, every time: title, numbered steps from a known starting state, expected versus actual behavior, environment (build/OS/config), and evidence (command+output, screenshot, or log excerpt).
- A confirmed bug never lives only in chat: file it via the /bug discipline, or record it in the run record as UNFILED with the reason. Chat scrolls away; the tracker is the record.
- File nothing you did not reproduce. Repro steps come from an actual reproduction in this session, and the report links its evidence.
- Search open issues for duplicates before filing; when a match exists, add the new evidence as a comment on it instead of filing a twin.
- The project's own issue template, labels, and language (per its profile in the QA workspace, projects/<slug>/intake.md) win over the stack's standard form. The standard form is only the fallback for projects that have none.

NEVER:
- rule a finding `Confirmed-Defect` or `closed-not-a-defect` without a human decision.
- collapse severity and priority into one field or one setter.
- close a finding as cannot-reproduce from inspection alone.
- write a bug report's body, title, or any of its content into `state.md` — bug reports go to the target project's own tracker only, never the state file. This plugin never writes the cycle's state file itself; it requests the transition and lets `qa-cycle` record it.

COMPOSITION: receives the cycle from `testrun` (a failing case entering `finding-triage`) and, once a human rules `Confirmed-Defect` and the defect is filed and fixed, hands off to `regress` (`report-filed -> regression-gated`).
</qa-bugreport-directive>
EOF
exit 0
