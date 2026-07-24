# bugreport

Bug filing as a discipline: a confirmed defect becomes a tracker issue the
project can actually triage — in *that project's* template, labels, and
language — and nothing gets filed that wasn't reproduced.

## What `/bug` does

1. Refuses to file anything not actually reproduced (a run-record failure
   with evidence counts; a hunch does not).
2. Reads the filing rules from `qa/intake.md`: which repo, which template,
   which labels, which language.
3. Searches open issues first; a duplicate gets the new evidence as a
   comment, not a twin issue.
4. Follows the project's issue template verbatim when one exists; otherwise
   uses the stack's standard form (repro steps, expected vs actual,
   environment, evidence, severity).
5. Files via `gh issue create` and writes the issue URL back into the run
   record that produced the failure.

A thin `UserPromptSubmit` directive keeps the discipline active outside the
command too: a bug confirmed during any QA work either gets filed or is
recorded as `UNFILED(<reason>)` in the run record — it never lives only in
chat.

## Severity fallback

For projects with no scheme of their own: `sev:critical` (data loss / no
workaround), `sev:high` (main flow broken, workaround exists), `sev:medium`,
`sev:low`. A project's own labels always win.

Kill switch: `QA_BUGREPORT_OFF=1`.

Unbenchmarked as of v0.1.0.
