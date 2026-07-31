# issue-42 implementation record (phase 2)

loop_state: done

## why
Core landed a single canon for the warrant-hunter plugin, the three
role-agnostic gates (trailer/record-fields/handbook-trigger), and a
shared `role-directive.sh` boilerplate function (core issue #63/#66).
This repo (`execution-observation-rulebook`, plugin `qa`) still vendored
its own copies of the three gates and duplicated the trap/kill-switch/
`CLAUDE_ROLE`-guard boilerplate in `qa/hooks/directive.sh`. issue-42
converts this repo to reference core canon instead, per the approved
proposal (`docs/issue-42/proposals/implementation-proposal.md`).

## upstream basis
Fetched directly from `tokenmaxxxer-core` via `gh api
repos/tokenmaxxxer/tokenmaxxxer-core/contents/...`:
- `core/hooks/hooks.json` — confirms all three gates already registered
  globally (`PreToolUse` matcher `.*`), so qa's own registration can be
  dropped with no replacement.
- `core/hooks/lib/role-directive.sh` — the `core_role_directive
  <you_decide> <use_when> <produces> <hand_off>` function qa's stub now
  sources and calls.
- `core/hooks/tests/stub-check.sh` — core's canon drift-recurrence
  checker, copied into `tests/stub-check.sh` verbatim, the same
  distribution pattern this repo already uses for `tests/parse-check.sh`.
- `core/hooks/record-fields-gate.sh` — confirms the exact env-var read
  (`RF_TERMINAL="${RECORD_FIELDS_TERMINAL_STATES:-landed}"`) that item 4
  below targets.

## what was done
1. **warrant-hunter copy** — no-op, confirmed again at phase 2 (still no
   `agents/warrant-hunter.md` or hunt-cadence text anywhere in this repo).
2. **Gate copies** — deleted `qa/hooks/trailer-gate.sh`,
   `qa/hooks/handbook-trigger-gate.sh`, `qa/hooks/record-fields-gate.sh`.
   Removed their three `PreToolUse` entries from `qa/hooks/hooks.json`;
   only the `SessionStart` → `directive.sh` entry remains, matching
   core's own global registration above.
3. **directive.sh stub** — replaced with the stub form: sources
   `core/hooks/lib/role-directive.sh`, assigns qa's four role-unique
   bodies (YOU DECIDE; RESEARCH+CURRENT-STATE SURVEY+PROPOSAL; EXECUTION
   JUDGMENT; RECORD REQUIREMENTS — verbatim text, unabbreviated) as
   single-line `$'...'` (ANSI-C quoted) variables so each stays on one
   physical line, then calls `core_role_directive`. The first draft used
   multi-line double-quoted assignments and failed `stub-check.sh`'s
   structural check (continuation lines don't match its `VAR=` line
   pattern) — switched to `$'...\n...'` so every physical line is either
   a comment, the source line, a plain `VAR=...` assignment, or the
   `core_role_directive` call. `QA_CYCLE_OFF` continues to work
   unchanged (`core_role_directive` derives `QA_CYCLE_OFF` from
   `CLAUDE_ROLE=qa` generically via `tr`).
4. **RECORD_FIELDS_TERMINAL_STATES** — **blocked**, not delivered this
   session (see open findings below).
5. **stub-check.sh** — added `tests/stub-check.sh` (core's canon copy)
   and ran it against `qa/hooks/`, passing:
   ```
   $ bash tests/stub-check.sh qa/hooks
   stub-check: ok — no vendored 'trailer-gate.sh' under qa/hooks
   stub-check: ok — no vendored 'record-fields-gate.sh' under qa/hooks
   stub-check: ok — no vendored 'handbook-trigger-gate.sh' under qa/hooks
   stub-check: ok — no vendored 'parse-check.sh' under qa/hooks
   stub-check: ok — qa/hooks/directive.sh is a role-directive stub
   $ echo $?
   0
   ```
   `tests/parse-check.sh` still passes (`directive.sh` reported `ok`,
   `bash -n qa/hooks/directive.sh` clean).

### Verification commands run
- `find qa/hooks -maxdepth 1 -name 'trailer-gate.sh' -o -name
  'handbook-trigger-gate.sh' -o -name 'record-fields-gate.sh'` — empty.
- `grep -c PreToolUse qa/hooks/hooks.json` — 0 (block removed entirely).
- `bash tests/stub-check.sh qa/hooks` — exit 0.
- `bash tests/parse-check.sh` — exit 0.
- `bash -n qa/hooks/directive.sh` — syntax ok.

### Out of scope (unchanged, per proposal)
`qa/commands/*`, `bench/`, any file outside this repo.

## open findings
**RECORD_FIELDS_TERMINAL_STATES delivery is blocked, not resolved.** The
intended mechanism (per proposal, confirmed against core's
`record-fields-gate.sh` source) is a project-level `.claude/settings.json`
`env` block:
```json
{ "env": { "RECORD_FIELDS_TERMINAL_STATES": "verified-fixed not-a-defect wont-fix" } }
```
This session's sandbox explicitly denies writes to both
`.claude/settings.json` and `.claude/settings.local.json` in this repo
path — attempted via the Write tool, got a permission-request error
with no user available to grant it in this headless run. The value is
**not configured anywhere** as of this record. Until a session with
write access applies the snippet above, core's canon
`record-fields-gate.sh` falls back to its default `"landed"`, which is
not one of qa's terminal states (`verified-fixed`, `not-a-defect`,
`wont-fix`) — qa records will read as permanently open to that gate.

## next steps / resolution path
A session or human with write access to `.claude/settings.json` in this
repo applies the `env` block above (or whatever mechanism Claude Code
actually documents for delivering plugin/project env vars to `PreToolUse`
hook subprocesses, if that differs), then re-runs a write against qa's
record to confirm `record-fields-gate.sh` accepts qa's terminal states
instead of falling back to `"landed"`. That is the open-finding
resolution path for item 4; everything else in this issue (items 1, 2,
3, 5) is complete and verified above.
