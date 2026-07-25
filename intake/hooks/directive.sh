#!/usr/bin/env bash
# UserPromptSubmit hook: injects the intake discipline.
# Kill switch: export QA_INTAKE_DISABLE=1

# Off means off: only explicit truthy-ish values disable the hook; "0",
# "false", "no", "off" and empty all mean "not off".
case "${QA_INTAKE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
<qa-intake-directive priority="high">
SURFACE GATE: applies when the work at hand is starting or resuming QA on a project — running `/qa-init`, asking where bugs get filed, how the app launches, or what a QA session should assume about this repo. Inert for unrelated coding or conversation.

TRIGGER CONDITIONS:
- no `intake.md` exists yet for this project in the QA workspace, or the user asks to (re)discover the QA profile.
- another QA plugin (testrun, bugreport, regress, stats) reports it is operating without a profile.

RULES:
- `intake` owns exactly one transition in the QA cycle state machine: `(none) -> intake-scoping`, triggered by `/qa-init` run against the target repo. Its required evidence is `intake.md` written with the tracker, issue template, labels, app-launch, test-convention, and env-var-name fields populated — that file is what the gate will demand as proof the transition happened.
- `intake` never writes the cycle's state file (`state.md`) itself. It requests the `(none) -> intake-scoping` transition; `qa-cycle`'s `PreToolUse` gate is the sole authority that decides whether the write is permitted and the sole writer of `state.md`.
- Record env var NAMES only, never values. No target-project code is copied into the QA workspace.
- Discovery over guessing: prefer `git remote`, `.github/ISSUE_TEMPLATE/*`, `gh label list`, package/compose/Makefile inspection to asking the user, and ask only for what cannot be discovered.

NEVER:
- write or edit `state.md` directly.
- put a secret value, or any target-project source code, into `intake.md`.
- claim the `(none) -> intake-scoping` transition happened without `intake.md` actually being written with its required fields.

COMPOSITION: `intake` is the entry point of the QA cycle — it receives no handoff from any sibling plugin, and hands off to `testrun`, which reads `intake.md` to take the project from `intake-scoping` into `session-chartered`. `qa-cycle` is the spine every transition request passes through; `intake` never bypasses it.
</qa-intake-directive>
EOF
exit 0
