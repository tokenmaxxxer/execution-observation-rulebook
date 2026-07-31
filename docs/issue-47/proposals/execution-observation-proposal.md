# issue-47 plugin-deepening proposal (execution-observation, phase 1)

files (phase 2): `qa/hooks/directive.sh` (deepened text bodies),
`qa/hooks/methodology-gate.sh` (new), `qa/hooks/state.sh` (new, small),
`qa/hooks/hooks.json` (register the new `PreToolUse` entry),
`tests/run-gate-tests.sh` (new cases appended)

## Scope

Target: this repo's own plugin (`qa/`, role `execution-observation`)
only. No other role's directory, no core canon repo, no sibling
rulebook repo is touched. The norm source converted into enforcement
here is `docs/issue-41/proposals/execution-observation-proposal.md`
section (d) as already reflected into `qa/hooks/directive.sh` by
issue-41 phase 2 — this issue does not re-derive new methodology, it
mechanizes the methodology already adopted.

## Current-state survey reference

`docs/issue-47/reports/execution-observation/survey.md` — directive
text exists and is non-trivial but unchecked; no `PreToolUse` gate is
registered by this plugin (issue-42 removed the vendored generic
gates in favor of core's global registration, and no role-specific
gate has ever existed here); `run-gate-tests.sh` exercises only the
generic core gates with stale field names; no state tracking exists.

## Scout brief

`docs/issue-47/reports/execution-observation/scout-brief.md` — parallel
2-angle sweep (pricing-rulebook's `methodology-gate.sh`,
implementation-rulebook's `hunt-guard.sh`/`hunt-state.sh`), 1 sweep + 1
deepening stage, saturated. Adopted: fail-closed trap, kill-switch
off-spelling rule, python3 JSON-heredoc judge, path-scoped regex to
this role's own write surfaces, reconstructed post-write content,
named-missing-elements denial, real-subprocess gate tests. Adopted
scoped-down: a single per-session read-marker instead of a lock/cap
pair (this role has no concurrent-dispatch problem to bound).

## (1) Directive deepening — per-facet stages, judgment criteria, prohibitions

Current `qa/hooks/directive.sh` bodies (issue-41) state the shape of
the methodology but not checkable criteria. This proposal adds, within
the same four variables (no new variable, same `core_role_directive`
call signature — the deepening is text-only, not structural):

**`you_decide` (unchanged in substance; tightens "never re-execute"
into an explicit prohibition list):**
- Prohibited: re-running the observed role's code, opening its src/
  files to judge quality by reading code the observed role didn't
  ship as evidence (only the artifacts the observed role actually
  produced — diff, commits, its own record — are admissible), editing
  anything under the observed role's `src/`/`test/`/`docs/issue-<n>/`
  paths outside this role's own report path, filing an issue.

**`use_when` (phase 1 — RESEARCH / CURRENT-STATE SURVEY / PROPOSAL),
judgment criteria added per stage:**
- RESEARCH passes when: the observed role's actual PR number, commit
  SHAs, and its own record file have all been read this session (not
  assumed from the issue text). Fails when a claim about what the
  observed role did has no corresponding read this session.
- CURRENT-STATE SURVEY passes when: scope names the specific
  role/session/issue/PR number being observed (not "recent work" or
  a role name alone) and states which artifacts were read to write it.
  Fails when scope is stated in general terms with no PR/issue number.
- PROPOSAL passes when: it names which of the three verdict levels
  (outcome/trajectory/step) will be checked and against what evidence
  each will draw on, before any verdict language appears. Fails when
  the proposal already renders a verdict (verdicts belong to phase 2
  only, per the observed-target's own phase gate).

**`produces` (phase 2 — EXECUTION JUDGMENT), judgment criteria and
prohibitions per required element (mirrors the gate's own check list
in section 2 below, so the directive states in prose exactly what the
gate enforces mechanically — no daylight between the two):**
- Every verdict-bearing sentence names its source (commit SHA,
  file:line, or PR comment URL). Prohibited: any sentence using verdict
  language (sound/deficient/landed/missing/confirmed/etc.) with no
  adjacent citation.
- All three levels (outcome, trajectory, step) are addressed, even when
  the answer at one level is "not applicable" — silently omitting a
  level is prohibited, stating "not applicable, because X" is not.
- A deficiency finding always carries the four-part blameless shape
  (impact, timeline, root cause, action item); prohibited to state a
  deficiency without any one of the four parts.

**`hand_off` (phase 2 — RECORD REQUIREMENTS), unchanged in substance
from issue-41, tightened with one added prohibition:** the record is
written as the first phase-2 act (already stated); added — prohibited
to render any verdict in the record before the independence statement
appears (ordering, not just presence, matters: a reader must know the
independence boundary before reading any judgment).

## (2) Methodology gate — mechanical verification of produces elements

New file `qa/hooks/methodology-gate.sh`, structurally modeled on
`pricing-rulebook/pricing/hooks/methodology-gate.sh` (referenced, not
copied — this repo has no vendored copy of that file and none will be
added; only the shape below is reused, rewritten for this role's own
field names and write-surface paths):

- Fail-closed `trap` on `EXIT` as the first executable statement (core
  canon idiom, already present in this repo's referenced gates
  elsewhere in the org).
- Kill switch `EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF`, off-spelling
  rule (`""/0/false/no/off` only).
- Targets exactly two write-surface path patterns, matched by regex
  against the resolved project-root-relative path:
  - `docs/issue-[0-9]+/proposals/.*execution-observation.*\.md` (phase-1
    proposals)
  - `docs/issue-[0-9]+/reports/execution-observation\.md` (phase-2
    record)
  Any other path: `sys.exit(0)` (not this gate's business), matching
  the org convention.
- Reconstructs post-write content for `Write`/`Edit`/`MultiEdit` the
  same way the reference does (full content for Write; simulated
  replacement against current-disk content for Edit/MultiEdit; denies
  with a specific message if the resulting content can't be determined
  from the tool input — e.g. an `Edit` whose `old_string` doesn't match
  current content).
- Required-element checks, distinct per write-surface pattern (the
  proposal and the record have different required shapes, unlike
  pricing's single check list — see rationale below):
  - **Proposal surface** requires: a `## Scope` heading naming an issue
    or PR number pattern (`#\d+` or `issue-\d+`), a reference to a
    current-state-survey path
    (`docs/issue-<n>/reports/execution-observation`), and a stated
    verdict-level plan (text containing at least two of
    `outcome`/`trajectory`/`step`).
  - **Record surface** requires: an independence-statement marker
    (case-insensitive `independence statement` heading or phrase)
    appearing before the first occurrence of verdict language
    (`outcome:`/`trajectory:`/`step:`/`sound`/`deficient` — ordering
    checked by string index, not just presence, per directive (1)'s
    added prohibition), all three of `outcome`/`trajectory`/`step`
    present, and — only when a deficiency is claimed (text contains
    `deficient` or `finding`) — all four of
    `impact`/`timeline`/`root cause`/`action item` present.
  - Missing elements are collected into a list and named explicitly in
    the denial message, with a pointer to this proposal (and, once
    landed, to the record itself) as the norms source — mirrors
    pricing's actionable-denial pattern from the scout brief.
- Registered in `qa/hooks/hooks.json` as a `PreToolUse` entry matching
  `Write|Edit|MultiEdit`, alongside the existing `SessionStart` entry
  (core's own global gates stay as they are — this is this role's own
  additional, narrower gate, not a replacement).

**Why per-surface field lists instead of one shared list (deviation
from pricing's single list, noted deliberately):** a phase-1 proposal
cannot yet contain verdict language (directive (1)'s own prohibition:
verdicts belong to phase 2) — a single shared check list would either
wrongly demand verdict-shaped text in phase 1 or wrongly skip checking
independence-before-verdict ordering in phase 2. The two surfaces check
different things because contract v3's phase gate makes them
substantively different documents, not because of arbitrary field
choice.

## (3) State tracking — ordering constraint

The one order constraint this methodology has: a phase-2 record must
not be written before this session has read at least one artifact of
the observed target (research-before-verdict, RESEARCH facet above).
Scout brief's adopted-scoped-down shape: a single marker file, not a
lock/cap pair (no concurrency to bound here).

- New file `qa/hooks/state.sh`, sourced by both `directive.sh`
  (SessionStart, to clear any stale marker at session start — mirrors
  `hunt-state.sh`'s SessionStart-clears-state convention from the
  scout brief) and `methodology-gate.sh` (PreToolUse, to check it).
- Marker path: `${CLAUDE_PROJECT_DIR:-.}/.claude/.eo-read-marker`
  (project-local, git-ignored — same tier as other session-scoped
  state in this org's pattern, not committed).
- Read-tool hook (`PostToolUse` matcher `Read|Bash`, narrow: only
  writes the marker when the read/command target plausibly touches
  another role's artifact path — `docs/issue-<n>/reports/`,
  `docs/issue-<n>/proposals/`, or a `gh api`/`gh pr` command — this is
  a best-effort signal, not a strict prover; false positives (marker
  set when the read wasn't really "the" observed artifact) are
  accepted, false negatives (marker never set despite real reading) are
  the failure mode this proposal accepts as a known limitation, stated
  here rather than silently — see "Known limitation" below).
- `methodology-gate.sh`'s record-surface check adds one more required
  element: the marker file exists in this session. Absent marker →
  denial naming this specific requirement, distinct from the
  content-shape denials in section (2), so a session that skipped
  reading entirely gets a different, clearer message than one that
  read but wrote an incomplete record.

**Known limitation, stated rather than hidden:** this is a
weaker-than-perfect ordering proof (a `Read` of an unrelated file also
sets the marker if its path happens to match the regex loosely). It is
adopted anyway because it converts a purely prose-only "never assume"
instruction into a mechanically-checked minimum bar (some artifact
read this session) without requiring a full provenance-tracking system
disproportionate to this role's actual risk — the same
proportionality judgment `hunt-guard.sh`'s own comments make explicit
about its fourth (unenforceable) limit.

## (4) Gate tests

Appended to `tests/run-gate-tests.sh` (same harness already in this
repo — real subprocess invocation, synthetic PreToolUse JSON piped over
stdin, tempdir `git init`, assert exit 0/2), not a new test file:

- `allow` — proposal write containing `## Scope`, an issue number, a
  survey-path reference, and two of the three verdict-level words.
- `deny` — proposal write missing the survey-path reference.
- `deny` — proposal write already containing verdict language (`step:
  deficient`) — phase-1 prohibition case.
- `allow` — record write with independence statement before verdict
  language, all three levels, no deficiency claimed.
- `deny` — record write with verdict language appearing before the
  independence statement (ordering violation, not just presence).
- `deny` — record write claiming `deficient` with only 3 of the 4
  blameless-shape elements present.
- `allow` — foreign path (`docs/issue-9/reports/qa.md`) — confirms
  scope precision, gate stays out of another role's write surface.
- state-tracking case: `deny` record write with no prior marker file in
  the tempdir; `allow` the same content once a marker file is
  pre-seeded in the tempdir before the gate runs.

## (5) Agents / checklist

Not needed. The methodology has no repeated multi-step procedure
distinct from what a single session already does linearly (survey →
scout when applicable → observe → verdict → record) — issue-41's
proposal already covers that shape in the directive text, and this
issue's ask ("필요 시") is conditional; the state-tracking marker in
(3) is the only "procedural order" element this methodology actually
has, and it is covered by the gate + a single sourced helper script,
not a standing checklist document or an `agents/` file.

## Constraints (unchanged from contract v3 / prior sessions in this
repo)

- Phase 1 only this session: research + survey + scout + this
  proposal, open the PR, stop. No edit to `qa/hooks/*` or
  `tests/run-gate-tests.sh` in this session.
- No APPROVE by any role, including self.
- Canon scripts referenced, never copied — confirmed again this
  session (`docs/decisions/` "core canon-scripts.md" constraint;
  `pricing-rulebook`'s `methodology-gate.sh` is read and its shape
  described, not fetched into this repo as a file).
- Role boundary / `write_scope` unchanged: only `qa/hooks/*`,
  `tests/run-gate-tests.sh`, and `docs/issue-47/` are touched by this
  proposal's plan; no other role's directory.

## Out of scope

- Actually creating `methodology-gate.sh`, `state.sh`, editing
  `directive.sh`/`hooks.json`, or appending to `run-gate-tests.sh` —
  phase 2, after human APPROVE.
- Resolving the pre-existing `RECORD_FIELDS_TERMINAL_STATES`
  open finding from issue-41 — unrelated blocked item, not this
  issue's ask; phase 2 must simply not assume it is set.
- Renaming the `qa/` plugin directory (template-mismatch, out of scope
  per issue-41's precedent).
- Fetching or vendoring any file from `pricing-rulebook` or
  `implementation-rulebook` — reference only.

## How it'll be known to work (phase 2 acceptance)

- `qa/hooks/directive.sh`'s four bodies contain the per-facet judgment
  criteria and prohibitions from section (1), still passing
  `bash -n` and `tests/parse-check.sh`.
- `qa/hooks/methodology-gate.sh` exists, passes `bash -n`, and
  `tests/stub-check.sh qa/hooks` still passes (it is a role-specific
  addition, not a vendored core-canon file, so stub-check's "no
  vendored gate" checks are unaffected — it checks for the three named
  core gates specifically, not for the absence of any gate).
- `qa/hooks/hooks.json` registers the new `PreToolUse` entry;
  `tests/run-gate-tests.sh` passes with the new cases from section (4)
  included, `[ "$fail" -eq 0 ]` at the end.
- A manual dry run: writing a synthetic incomplete proposal/record
  through the gate script directly (same invocation style as the
  test harness) is denied with a message naming the specific missing
  element(s); a complete one is allowed.
