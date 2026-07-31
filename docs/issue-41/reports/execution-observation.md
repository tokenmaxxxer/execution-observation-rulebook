# issue-41 execution-observation implementation record (phase 2)

loop_state: blocked

(Blocked on RECORD_FIELDS_TERMINAL_STATES delivery only — everything
else in this record is done; see "Next steps / open-finding resolution
path" below.)

## why

Phase 1 (`docs/issue-41/proposals/execution-observation-proposal.md`)
was approved via issue comment "APPROVE issue-41/execution-observation".
This session is the phase-2 delivery of that approved plan: reflect the
researched execution-observation phase-1/phase-2 norms — verdicts
require citation, three-level (outcome/trajectory/step) verdict,
independence statement, blameless single-finding anomaly shape — into
the actual plugin (`qa/hooks/directive.sh`'s role-directive text) and
into the record-fields terminal-state config
(`RECORD_FIELDS_TERMINAL_STATES`), following the exact mechanical
pattern issue-42 already used for the `qa` role's own conversion
(`docs/issue-42/reports/implementation.md`).

## upstream basis

- `docs/issue-41/proposals/execution-observation-proposal.md` section
  (d) "Plugin reflection plan" — the approved instructions this session
  implements item-by-item.
- `docs/issue-42/reports/implementation.md` — precedent for the
  mechanical shape (`$'...'` single-line ANSI-C-quoted variable
  assignments so `tests/stub-check.sh` and `tests/parse-check.sh`
  pass) and for the `RECORD_FIELDS_TERMINAL_STATES` delivery mechanism
  and its known sandbox-write-denial failure mode.

## Independence statement

This is NOT an ordinary execution-observation session auditing another
role's artifact. This session authored the plugin changes it describes
(`qa/hooks/directive.sh`) itself, per the approved proposal
`docs/issue-41/proposals/execution-observation-proposal.md`. The
independence norm encoded into the directive text this session wrote
("this role never edits the observed artifact") governs FUTURE
execution-observation sessions that audit OTHER roles' PRs/commits —
it does not and cannot apply reflexively to this bootstrapping session,
which is self-editing its own rulebook by design (the same pattern
issue-42 used when qa converted its own directive.sh). Stating this
plainly rather than falsely claiming independence from work performed
in this very session.

## What was done (timestamped trail, order of what was checked/done)

1. Read `docs/issue-41/proposals/execution-observation-proposal.md`
   (full file, sections (a)-(d) and constraints) — the approved plan
   this session implements verbatim.
2. Read `docs/issue-41/reports/execution-observation/survey.md` context
   (referenced via proposal; confirmed no warrant-hunter file exists,
   nothing to remove).
3. Read `docs/issue-42/reports/implementation.md` — the precedent this
   session mechanically follows (single-line `$'...'` ANSI-C-quoted
   variable bodies, same stub structure, same blocked-settings pattern).
4. Read `qa/hooks/directive.sh` (pre-edit state, qa-role text).
5. Edited `qa/hooks/directive.sh`: replaced the four variable bodies
   (`you_decide`, `use_when`, `produces`, `hand_off`) with
   execution-observation-role text per proposal (a)/(b) — verdicts-
   require-citation, no re-execution, no artifact edits, no issue
   filing, three-level (outcome/trajectory/step) verdict, blameless
   single-finding anomaly write-up, independence statement requirement,
   record-first-act-of-phase-2 requirement. Kept the `#!/usr/bin/env
   bash` header, SessionStart comment, `QA_CYCLE_OFF` kill-switch
   naming (derived generically by core's `role-directive.sh` from
   `CLAUDE_ROLE`, unchanged), the core source line, and the final
   `core_role_directive "$you_decide" "$use_when" "$produces"
   "$hand_off"` call structurally as-is.
6. Ran `bash -n qa/hooks/directive.sh` → syntax ok (no output = clean).
7. Ran `bash tests/parse-check.sh` →
   ```
   GNU bash, 버전 5.1.16(1)-release (x86_64-pc-linux-gnu)
   ok    directive.sh

   parse-check: 1 file(s) under /bin/bash
   ```
   exit 0.
8. Ran `bash tests/stub-check.sh qa/hooks` →
   ```
   stub-check: ok — no vendored 'trailer-gate.sh' under qa/hooks
   stub-check: ok — no vendored 'record-fields-gate.sh' under qa/hooks
   stub-check: ok — no vendored 'handbook-trigger-gate.sh' under qa/hooks
   stub-check: ok — no vendored 'parse-check.sh' under qa/hooks
   stub-check: ok — qa/hooks/directive.sh is a role-directive stub
   ```
   exit 0.
9. Attempted `RECORD_FIELDS_TERMINAL_STATES` delivery: checked
   `.claude/settings.json` — file does not exist in this working tree
   (`test -f .claude/settings.json` → NOEXIST; `ls -la .claude/` shows
   the path exposed as a device node, not a regular writable file, in
   this sandbox). Attempted `Write` of a fresh
   `{ "env": { "RECORD_FIELDS_TERMINAL_STATES":
   "confirmed-sound confirmed-deficient inconclusive" } }` to
   `.claude/settings.json` — **denied** by the sandbox permission system
   ("Permission to use Write has been denied"), same failure mode
   issue-42 hit (`docs/issue-42/reports/implementation.md`, "open
   findings").
10. Wrote this record (this file) as the required first act of phase 2
    documentation, per the directive text's own "write the record as
    the FIRST act of phase 2" rule.

## Three-level verdict (about this session's own plugin-reflection work)

- **Outcome**: The PR/issue ask — "reflect the approved execution-
  observation proposal into the plugin" — is landed for items 1
  (directive text) and 3/4 (no new gate needed; no warrant-hunter file
  to touch) of proposal section (d). Item 2
  (`RECORD_FIELDS_TERMINAL_STATES`) is NOT landed; blocked by sandbox
  write-permission denial, matching evidence in step 9 above and
  `docs/issue-42/reports/implementation.md`'s identical open finding.
- **Trajectory**: Sound. This session read the approved proposal in
  full before editing (step 1), read the precedent implementation
  record before mechanically following its pattern (step 3), made only
  the four variable-body edits the proposal's section (d) item 1
  specifies (no gate files touched, no warrant-hunter file touched,
  `qa/commands/*` and `bench/` untouched), and ran the exact
  verification commands the proposal's "phase 2 acceptance" section
  names (`tests/parse-check.sh`, `tests/stub-check.sh qa/hooks`) before
  declaring done on the parts that are done.
- **Step**: The one deficient artifact is `.claude/settings.json` — it
  does not exist and cannot be created in this sandboxed session, so
  `RECORD_FIELDS_TERMINAL_STATES` remains unset here. No other artifact
  is deficient: `qa/hooks/directive.sh` passes both structural checks
  (stub-check, parse-check) and a plain syntax check.

## Blameless anomaly write-up (RECORD_FIELDS_TERMINAL_STATES delivery)

- **Impact**: Core's `record-fields-gate.sh` reads
  `RF_TERMINAL="${RECORD_FIELDS_TERMINAL_STATES:-landed}"`. Without this
  project-level env var set, execution-observation records using this
  role's intended terminal vocabulary (`confirmed-sound`,
  `confirmed-deficient`, `inconclusive`) will not match the gate's
  fallback default (`landed`), so a real execution-observation record
  closing with one of this role's terminal states will read as
  permanently open to that gate.
- **Timeline**: Attempted once, this session, immediately after the
  directive.sh edit and verification passed (step 9 above). Denied on
  first attempt; not retried (same outcome expected — this is a sandbox
  permission boundary, not a transient failure).
- **Root cause**: The sandbox this session runs in does not grant write
  access to `.claude/settings.json` (or, per `ls -la .claude/`, exposes
  the path in a form — device-node-like listing — inconsistent with
  ordinary regular-file writes) for either creating or editing the
  file. This is identical to the root cause recorded in
  `docs/issue-42/reports/implementation.md`'s open findings for the
  equivalent qa-role env var, i.e. a repeat instance of the same
  environment constraint, not a new defect in this session's own work.
- **Action item**: see "Next steps / open-finding resolution path"
  below.

## Evidence-cited findings summary

- `qa/hooks/directive.sh` (this session's edit, verified clean): four
  variable bodies (`you_decide`, `use_when`, `produces`, `hand_off`)
  replaced with execution-observation text; verified via
  `bash -n qa/hooks/directive.sh` (clean), `bash tests/parse-check.sh`
  (exit 0, output above), `bash tests/stub-check.sh qa/hooks` (exit 0,
  all five checks `ok`, output above).
- `.claude/settings.json`: confirmed absent
  (`test -f .claude/settings.json` → NOEXIST) and write-denied on
  attempt (Write tool call this session → "Permission to use Write has
  been denied"). Cross-referenced against
  `docs/issue-42/reports/implementation.md` lines under "open
  findings," which document the identical denial for qa's equivalent
  env var in the same repo.
- No warrant-hunter file exists in this repo (per
  `docs/issue-41/reports/execution-observation/survey.md`, re-confirmed
  by this session finding no `agents/warrant-hunter.md` or hunt-cadence
  text) — nothing to reflect for proposal section (d) item 4.
- No new gate script added — core's trailer/handbook/record-fields
  gates are role-agnostic per issue-42's conversion
  (`docs/issue-42/reports/implementation.md`, "what was done" items
  1-2); this role's phase-2 record path
  (`docs/issue-<n>/reports/execution-observation.md`) requires no gate
  code change, per proposal section (d) item 3.

## Next steps / open-finding resolution path

A session or human with write access to `.claude/settings.json` in this
repo applies:
```json
{ "env": { "RECORD_FIELDS_TERMINAL_STATES": "confirmed-sound confirmed-deficient inconclusive" } }
```
(merged with any other existing keys in that file), then re-verifies
that `record-fields-gate.sh` accepts these terminal states on a real
execution-observation record instead of falling back to `"landed"`.
That is the resolution path for this record's only open finding. No
owner/deadline assigned by this session — per contract v3, assignment
is a human act via issue/PR, not this role's to declare. Everything
else in this record (directive.sh text, verification, no-new-gate, no
warrant-hunter file) is complete and verified above.

## Out of scope (unchanged, per proposal)

`qa/commands/*`, `bench/`, any file outside this repo, the `qa/` plugin
directory rename/README (template-mismatch issue, separately out of
scope).
