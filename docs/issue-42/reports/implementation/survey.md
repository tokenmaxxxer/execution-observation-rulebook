# issue-42 current-state survey (implementation, phase 1)

## Scout skip record
Skipped — this is a mechanical reference-conversion of existing files
against an already-landed upstream canon (core issue #63/#66); no
product-facing design decision is open. (scout-directive skip condition:
"spec literally leaves no design decision open" — the only open
question, RECORD_FIELDS_TERMINAL_STATES delivery, is a plumbing detail
resolved by reading core's own gate source, not a field survey.)

## What this repo actually is
`execution-observation-rulebook` ships exactly one plugin, `qa`
(`qa/.claude-plugin/plugin.json`). Its role directive fires when
`CLAUDE_ROLE=qa`. README already states the split: core (from
`tokenmaxxxer-core`) owns the interaction protocol; this rulebook owns
only what is qa-specific.

## Per work item

### 1. warrant-hunter copy
`find . -iname '*warrant*'` and `grep -rl warrant .` (excluding `.git`)
turn up no `agents/warrant-hunter.md` and no hunt-cadence directive text
anywhere in `qa/hooks/directive.sh` or elsewhere in this repo. The only
warrant-hunt artifact present is `.warrant-hunt.count`, a tracked state
counter (`git log` shows it introduced by `d60ceec`, "Restructure for
contract v3: one qa plugin") — core's own warrant plugin's runtime state,
not a vendored copy of the hunter agent itself. **There is nothing to
remove for item 1 in this repo.** (Contrast: `implementation-rulebook`'s
`coding/agents/warrant-hunter.md` does exist — a different repo, out of
this issue's scope.)

### 2. gate copies
`qa/hooks/trailer-gate.sh`, `qa/hooks/handbook-trigger-gate.sh`,
`qa/hooks/record-fields-gate.sh` are vendored copies, registered in
`qa/hooks/hooks.json`'s `PreToolUse` block (matchers `Write|Edit|
MultiEdit|NotebookEdit` and `Bash`). Diffed against
`tokenmaxxxer-core`'s current `core/hooks/{trailer,handbook-trigger,
record-fields}-gate.sh` (fetched via `gh api repos/tokenmaxxxer/
tokenmaxxxer-core/contents/core/hooks/...`):

- `trailer-gate.sh` / `handbook-trigger-gate.sh`: pure role-token
  substitution (qa's copy hardcodes `qa:`/`QA_CYCLE_OFF` where core's
  canon copy derives the same strings from `$CLAUDE_ROLE` at runtime).
  No qa-specific behavior is lost by deleting these two files.
- `record-fields-gate.sh`: same substitution pattern PLUS one genuine
  semantic difference — qa's copy hardcodes
  `TERMINAL = {"verified-fixed", "not-a-defect", "wont-fix"}"` where
  core's canon copy reads `RECORD_FIELDS_TERMINAL_STATES` from the
  environment (default `"landed"`, per core's own comment: "the
  terminal-states divergence looks like genuine per-role semantics ...
  kept as configuration ... rather than silently collapsed"). This is
  exactly the case core issue #66 anticipated and item 4 below exists
  for.

`tokenmaxxxer-core`'s own `core/hooks/hooks.json` registers all three
gates globally (`PreToolUse` matcher `.*`), fired for every plugin
install regardless of which rulebook is active — confirmed by reading
`core/hooks/hooks.json` directly. Once qa's local copies and their
`hooks.json` entries are removed, core's own registration covers qa's
session with no further wiring needed on qa's side.

`core/hooks/tests/stub-check.sh` (issue-66 item 4, already written
upstream) exists precisely to catch a re-vendored copy of any of these
three filenames reappearing under a rulebook's `hooks/` tree — this is
the check item 5 asks to run.

### 3. directive.sh stub
`core/hooks/lib/role-directive.sh` ships `core_role_directive
<you_decide> <use_when> <produces> <hand_off>`, sourced from a
rulebook's own `directive.sh`. It reads `CLAUDE_ROLE`, handles the
`<ROLE>_CYCLE_OFF` kill switch generically, and appends a generic
`RECORD: docs/issue-<n>/reports/<role>.md, phase-gated per contract v3
s19` line itself.

qa's current `qa/hooks/directive.sh` (73 lines) duplicates that same
trap/kill-switch/`CLAUDE_ROLE` guard boilerplate (issue-66's own survey
counted 38/40 such vendored copies with only role-token drift) and then
prints a much longer role body: YOU DECIDE, RESEARCH, CURRENT-STATE
SURVEY, PROPOSAL, EXECUTION JUDGMENT, and a RECORD REQUIREMENTS
paragraph richer than the generic line (file path plus loop_state /
first-act-of-phase-2 / commit-on-branch instructions, landed via
issue-38).

`core/hooks/tests/stub-check.sh`'s structural check for `directive.sh`
requires exactly: a source line for `role-directive.sh`, one call to
`core_role_directive`, plain variable assignments, comments, and the
shebang — nothing else. It does not cap the *length* of the four
argument strings, only the file's *shape*. qa's whole role body (YOU
DECIDE through EXECUTION JUDGMENT) fits inside the four parameters as
plain multi-line string values assigned to variables before the call;
nothing in the stub shape forces content loss.

### 4. RECORD_FIELDS_TERMINAL_STATES
qa's terminal `loop_state` set (`verified-fixed`, `not-a-defect`,
`wont-fix`, per this repo's own README "Record vocabulary" section)
differs from core's default (`landed`). Core's canon
`record-fields-gate.sh` reads this from the `RECORD_FIELDS_TERMINAL_STATES`
environment variable (space-separated), confirmed both in the gate's own
source comment and in core's test harness
(`core/hooks/tests/run-role-gates-tests.sh` sets it inline as
`RECORD_FIELDS_TERMINAL_STATES="landed scope-proposed"` ahead of
invoking the gate directly).

Open question carried into the proposal: this repo has no writable
`.claude/settings.json` reachable from this session to confirm whether
Claude Code applies a plugin- or project-level `env` block to hook
subprocess environments, or whether the value must be exported by
`directive.sh` itself relying on Claude Code re-using that SessionStart
hook's env for later PreToolUse invocations in the same session. No
other tokenmaxxxer rulebook has migrated to core canon yet (checked all
`tokenmaxxxer` org repos; `implementation-rulebook`'s `coding/hooks/`
still vendors its own copies), so there is no working precedent to copy
verbatim — phase 2 must verify the actual delivery mechanism
empirically rather than assume one.

### 5. stub-check.sh
`core/hooks/tests/stub-check.sh` is distributed by core "the way
parse-check.sh already is" (per its own header) — this repo's
`tests/parse-check.sh` is the existing precedent for how a core test
script lands in a rulebook (dropped in, run from `tests/`). Not yet
present in this repo; phase 2 adds it and records a passing run.

## Write set for phase 2
- `qa/hooks/trailer-gate.sh` — delete
- `qa/hooks/handbook-trigger-gate.sh` — delete
- `qa/hooks/record-fields-gate.sh` — delete
- `qa/hooks/hooks.json` — drop the three now-core-owned `PreToolUse`
  entries; keep the `SessionStart` entry for `directive.sh`; add whatever
  `RECORD_FIELDS_TERMINAL_STATES` delivery phase 2's investigation
  confirms
- `qa/hooks/directive.sh` — replace with the stub form (source
  `core/hooks/lib/role-directive.sh`, four role-unique variables, one
  `core_role_directive` call)
- `tests/stub-check.sh` — add (core's canon copy)
- `docs/issue-42/reports/implementation.md` — phase-2 record, including
  the `stub-check.sh` pass evidence item 5 asks for

No `src/`/`test/` changes (this repo has neither directory — it is
itself a rulebook, not a target codebase).
