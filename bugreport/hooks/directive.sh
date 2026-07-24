#!/usr/bin/env bash
# UserPromptSubmit hook: injects the bug-filing discipline.
# Kill switch: export QA_BUGREPORT_OFF=1

# Off means off: only explicit truthy-ish values disable the hook.
case "${QA_BUGREPORT_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
<qa-bugreport-directive priority="high">
Applies when QA work confirms a defect. Inert for any other kind of work.

- A confirmed bug never lives only in chat: file it via the /bug discipline, or record it in the run record as UNFILED with the reason. Chat scrolls away; the tracker is the record.
- File nothing you did not reproduce. Repro steps come from an actual reproduction in this session, and the report links its evidence.
- Search open issues for duplicates before filing; when a match exists, add the new evidence as a comment on it instead of filing a twin.
- The project's own issue template, labels, and language (per its profile in the QA workspace, projects/<slug>/intake.md) win over the stack's standard form. The standard form is only the fallback for projects that have none.
</qa-bugreport-directive>
EOF
exit 0
