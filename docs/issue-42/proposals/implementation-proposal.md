# issue-42 build proposal (implementation, phase 1)

files: `qa/hooks/trailer-gate.sh`, `qa/hooks/handbook-trigger-gate.sh`,
`qa/hooks/record-fields-gate.sh`, `qa/hooks/hooks.json`,
`qa/hooks/directive.sh`, `tests/stub-check.sh` (new),
`docs/issue-42/reports/implementation.md` (phase 2)

## Scout skip record
Skipped — mechanical conversion to an already-landed upstream canon
(core issue #63/#66); see survey.md for the full skip rationale.

## Request (paraphrased intent)
Core has landed a single canon for the warrant-hunter plugin and the
three role-agnostic gates, plus a shared `role-directive.sh` boilerplate
function. Point this repo at that canon instead of its own vendored
copies, in one batch, preserving every genuinely qa-specific bit of
behavior.

## Per work item, what phase 2 will do

1. **warrant-hunter copy** — nothing to do. Survey confirms no
   `agents/warrant-hunter.md` or hunt-cadence directive text exists in
   this repo. Record this as a no-op explicitly in the phase-2 record
   rather than silently skipping it.

2. **Gate copies** — delete `qa/hooks/trailer-gate.sh`,
   `qa/hooks/handbook-trigger-gate.sh`, `qa/hooks/record-fields-gate.sh`.
   Remove their three `PreToolUse` entries from `qa/hooks/hooks.json`,
   keeping only the `SessionStart` → `directive.sh` entry. Core's own
   `core/hooks/hooks.json` already registers all three gates globally
   (matcher `.*`), confirmed by direct inspection — no replacement
   registration is needed on qa's side.

3. **directive.sh stub** — replace `qa/hooks/directive.sh` with:
   ```sh
   #!/usr/bin/env bash
   . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
   you_decide="...YOU DECIDE paragraph, verbatim from today's directive..."
   use_when="...RESEARCH + CURRENT-STATE SURVEY + PROPOSAL paragraphs, verbatim..."
   produces="...EXECUTION JUDGMENT paragraph, verbatim..."
   hand_off="...RECORD REQUIREMENTS paragraph, verbatim..."
   core_role_directive "$you_decide" "$use_when" "$produces" "$hand_off"
   ```
   Every sentence of qa's current role body (YOU DECIDE, RESEARCH,
   CURRENT-STATE SURVEY, PROPOSAL, EXECUTION JUDGMENT, RECORD
   REQUIREMENTS — including the qa-specific record path, loop_state,
   and REGRESS-ADOPTED/DISCARDED/BLOCKED marker vocabulary) is preserved
   verbatim inside these four variables; only the trap/kill-switch/
   `CLAUDE_ROLE`-guard boilerplate that core factored out is dropped.
   `QA_CYCLE_OFF` continues to work unchanged — `core_role_directive`
   derives the same `<ROLE>_CYCLE_OFF` name from `CLAUDE_ROLE` generically.

4. **RECORD_FIELDS_TERMINAL_STATES** — set
   `RECORD_FIELDS_TERMINAL_STATES="verified-fixed not-a-defect wont-fix"`
   so core's canon `record-fields-gate.sh` keeps enforcing qa's actual
   terminal states instead of falling back to its own default
   (`"landed"`, which is not one of qa's states at all — silently
   adopting the default would make every qa record look permanently
   "open" to the gate). Phase 2 first confirms empirically (no
   precedent exists in any tokenmaxxxer rulebook yet, per survey) how
   Claude Code delivers an env var into a PreToolUse hook subprocess for
   a given plugin/session, then applies whichever mechanism actually
   works — most likely a project-level `.claude/settings.json` `env`
   block, since a `SessionStart` hook's own process env does not
   propagate to separately-spawned `PreToolUse` subprocesses.

5. **stub-check.sh** — add `tests/stub-check.sh` (core's canon copy, the
   same distribution pattern this repo already uses for
   `tests/parse-check.sh`), run it against `qa/hooks/`, and record the
   passing output in `docs/issue-42/reports/implementation.md`.

## Constraints
- Phase 1 only this session: survey + proposal, open the PR, stop. No
  edit to any `qa/hooks/*` file or `tests/` happens in this session
  (contract v3 s19); no APPROVE by any role.
- Sequencing constraint from the issue: this conversion must land before
  this repo's "rulebook maturation" phase 2 issue — noted for the human
  approver, not something phase 1 or 2 of this issue enforces itself.
- Preserve every qa-specific behavior: record path, loop_state
  vocabulary, terminal-state set, RECORD REQUIREMENTS enforcement
  clauses (landed via issue-38), REGRESS three-check gate wording, and
  `QA_CYCLE_OFF` kill-switch name.
- Output layout: docs under `docs/issue-42/` (this issue); rulebook
  edits under `qa/` and `tests/` — pre-existing repo layout, unaffected.

## Out of scope
- `agents/warrant-hunter.md` removal — does not exist in this repo (item
  1 is a no-op here).
- Any change to `qa/commands/*` (`/qa-init`, `/testrun`, `/regress`,
  `/qa-stats`) — untouched, no core canon claims this surface.
- `bench/` and its seeded-bug harness — explicitly "unchanged" per this
  repo's own README, untouched by this issue.
- Any file in `implementation-rulebook` or any other tokenmaxxxer repo —
  this issue's branch and tree cover only
  `execution-observation-rulebook`.

## How it'll be known to work
- `find qa/hooks -maxdepth 1 -name 'trailer-gate.sh' -o -name
  'handbook-trigger-gate.sh' -o -name 'record-fields-gate.sh'` returns
  nothing.
- `grep -c PreToolUse qa/hooks/hooks.json` shows the block gone (or
  reduced to none of the three retired matchers).
- `bash tests/stub-check.sh qa/hooks` (or the equivalent invocation core
  documents) exits 0 and its output is pasted into
  `docs/issue-42/reports/implementation.md`.
- `tests/parse-check.sh` still passes (stub `directive.sh` remains valid
  bash).
- `grep RECORD_FIELDS_TERMINAL_STATES qa/hooks/hooks.json` (or wherever
  phase 2's investigation lands it) shows qa's three terminal states.
