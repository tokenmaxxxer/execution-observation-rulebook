# issue-47 plugin-set proposal (execution-observation, phase 1)

**Revision note (this session):** rewritten in response to the
approver's "요구 정정" feedback on PR #48. Prior revision proposed a
single deepened directive + one new `methodology-gate.sh` inside the
existing monolithic `qa` plugin. That shape is rejected. This revision
restructures the same adopted methodology (unchanged in substance —
still `docs/issue-41/proposals/execution-observation-proposal.md`
section (d), still the same scout brief) as a **plugin set**: each
independently-adoptable piece of the methodology becomes its own
self-contained plugin, mirroring how core's own marketplace
(`tokenmaxxxer-core`) does not ship one monolithic "core" plugin but a
set — `core`, `terse`, `freelunch`, `scout`, `warrant` — each with its
own `.claude-plugin/plugin.json`, its own `README.md`, its own
`hooks/`, each owning exactly one methodology, each composed together
by every role rulebook that enables them. This proposal applies that
same shape to this rulebook's own methodology-specific plugins, instead
of folding everything into the existing single `qa` plugin.

## Scope

Target: this repo (`tokenmaxxxer-qa`, PR #48, issue #47) only. No other
role's directory, no core canon repo, no sibling rulebook repo is
touched. The norm source is unchanged:
`docs/issue-41/proposals/execution-observation-proposal.md` section
(d), as already reflected into `qa/hooks/directive.sh` by issue-41
phase 2 — this issue does not re-derive new methodology, it mechanizes
the methodology already adopted, but does so as a composed plugin set
rather than a single deepened gate.

## Current-state survey reference

`docs/issue-47/reports/execution-observation/survey.md` — directive
text exists and is non-trivial but unchecked; no `PreToolUse` gate is
registered by this repo's plugin; `run-gate-tests.sh` exercises only
generic core gates with stale field names; no state tracking exists;
this repo's `.claude-plugin/marketplace.json` currently registers a
single plugin, `qa`, bundling commands, directive, and (proposed)
enforcement together undifferentiated.

## Scout brief

`docs/issue-47/reports/execution-observation/scout-brief.md` — parallel
2-angle sweep (pricing-rulebook's `methodology-gate.sh`,
implementation-rulebook's `hunt-guard.sh`/`hunt-state.sh`), 1 sweep + 1
deepening stage, saturated. Adopted: fail-closed trap, kill-switch
off-spelling rule, python3 JSON-heredoc judge, path-scoped regex to
this role's own write surfaces, reconstructed post-write content,
named-missing-elements denial, real-subprocess gate tests. Adopted
scoped-down: a single per-session read-marker instead of a lock/cap
pair (this role has no concurrent-dispatch problem to bound). This
revision keeps every one of those adoptions; it only changes which
plugin boundary each one lives inside, per the corrected requirement
that a rulebook holds "여러 개" plugins, not one.

## Why a plugin set, not one deepened gate (design rationale)

The rejected shape treated "execution-observation enforcement" as a
single unit: one directive, one gate script, one state file, all
folded into the pre-existing `qa` plugin. That collapses three
methodologically distinct concerns — (a) what judgment criteria apply
per phase/facet, (b) what a written artifact must mechanically contain,
(c) what order artifacts must be produced in — into one undifferentiated
blob, the same anti-pattern core's own marketplace explicitly avoids by
keeping `scout` (research protocol), `warrant` (work-unit/approval
protocol), and `freelunch` (parallel-execution protocol) as three
separate plugins even though all three govern the same kind of session.

Each of the three concerns below is independently adoptable (a rulebook
could in principle take the directive without the gate, or the gate
without the state tracker) and each is self-contained enough to carry
its own hooks, its own manifest, and its own tests — the same bar
`freelunch` and `scout` clear in `tokenmaxxxer-core`. That
independent-adoptability is the test this proposal applies to decide
plugin boundaries, not file-count convenience.

## Plugin 목록 (plugin list — required section)

Three new plugins, each living under this repo at
`qa/plugins/<name>/`, each with its own `.claude-plugin/plugin.json`
(mirroring `scout/.claude-plugin/plugin.json`'s shape: `name`,
`description`, `author`), each registered as its own entry in
`.claude-plugin/marketplace.json` alongside the existing `qa` entry
(the existing `qa` plugin is not deleted — it keeps commands and the
role-directive sourcing stub; these three plugins are additive and
narrower).

| # | Plugin name | Owned methodology | Components | Composes into |
|---|---|---|---|---|
| 1 | `eo-directive` | Per-facet phase-1/phase-2 judgment criteria and prohibitions for the execution-observation methodology (issue-41 section (d), deepened) | `hooks/directive-body.sh` (sourced by `qa/hooks/directive.sh`'s `SessionStart` entry — this plugin supplies the four variable bodies' *content*, not a new hook registration), own `.claude-plugin/plugin.json`, own `README.md` stating which facet belongs to which phase | **Phase-1 norm**: sole contributor — the phase-1 (proposal) norm is "the RESEARCH / CURRENT-STATE SURVEY / PROPOSAL judgment criteria from this plugin are followed," nothing else composes into it. **Phase-2 norm**: contributes the `produces`/`hand_off` judgment criteria that `eo-methodology-gate` mechanically checks — this plugin states the rule in prose, `eo-methodology-gate` is the mechanical half of the same rule (no daylight between the two, by design). |
| 2 | `eo-methodology-gate` | Mechanical verification that a written proposal or record actually contains the required elements | `hooks/methodology-gate.sh` (new `PreToolUse` entry, structurally modeled on `pricing-rulebook`'s `methodology-gate.sh` per the scout brief — referenced, not copied), own `hooks.json`, own `.claude-plugin/plugin.json`, own test cases appended to `tests/run-gate-tests.sh` | **Phase-1 norm**: contributes the proposal-surface check (Scope heading + issue/PR number, survey-path reference, verdict-level plan present, verdict language absent — the phase-1 prohibition from `eo-directive` mechanically enforced). **Phase-2 norm**: contributes the record-surface check (independence-statement-before-verdict ordering, all three verdict levels, four-part blameless shape when a deficiency is claimed) — but the record-surface check additionally *depends on* `eo-state`'s marker (see below), making phase-2's norm a three-plugin composition, not a two-plugin one. |
| 3 | `eo-state` | Ordering/state tracking: a phase-2 record must not be written before this session has read at least one artifact of the observed target | `hooks/state.sh` (sourced by both `qa/hooks/directive.sh`'s `SessionStart`, to clear stale markers, and `eo-methodology-gate`'s `PreToolUse`, to check the marker — a cross-plugin dependency, stated explicitly rather than left implicit), a narrow `PostToolUse` matcher (`Read\|Bash`) that sets the marker, own `.claude-plugin/plugin.json` | **Phase-1 norm**: no contribution — phase-1 (the proposal) has no order dependency on artifacts-read-this-session in the way phase-2 does (RESEARCH's "read this session" criterion is `eo-directive`'s prose check, not a gate-enforced one, since a proposal can be revised before a record is ever written). **Phase-2 norm**: contributes the marker-exists check that `eo-methodology-gate`'s record-surface check consumes as one more required element — phase-2's full norm is `eo-directive` (criteria) + `eo-methodology-gate` (mechanical check of artifact shape) + `eo-state` (mechanical check of read-before-write ordering), composed together, not any one alone. |

**Composition summary (the design's actual body, per the correction):**

- **Phase-1 norm (기획서/proposal) = `eo-directive` alone**, checked
  lightly by `eo-methodology-gate`'s proposal-surface branch. A
  proposal is well-formed when it follows `eo-directive`'s RESEARCH /
  CURRENT-STATE SURVEY / PROPOSAL criteria, and `eo-methodology-gate`
  is the one plugin that also touches this surface, as a shallow
  structural check (Scope + survey reference + verdict-level plan
  named + no premature verdict language) — it does not need
  `eo-state`, because nothing about proposal-writing has a
  read-before-write order dependency beyond what `eo-directive`
  already states in prose.
- **Phase-2 norm (산출물/record) = `eo-directive` + `eo-methodology-gate`
  + `eo-state`, all three composed.** `eo-directive` states the
  criteria (citation-per-verdict, three levels, independence-before-
  verdict ordering, blameless shape), `eo-methodology-gate` mechanically
  checks the record's *content* shape against those criteria, and
  `eo-state` mechanically checks the *ordering precondition*
  (something was read this session) that gates whether the record write
  is even attempted. Removing any one of the three changes what "a
  correct phase-2 record" means: without `eo-directive` there is no
  criteria to check; without `eo-methodology-gate` the criteria are
  unenforced prose; without `eo-state` a record could be written with
  zero artifacts read and nothing would object.

This table and the two composition statements above are the artifact
the approver's feedback asked this proposal to carry as its core
content — "어떤 플러그인들이 조합되어 그 규범이 성립하는지가 설계의
본체."

## (1) `eo-directive` — per-facet stages, judgment criteria, prohibitions

Bodies supplied by this plugin (sourced into the existing
`qa/hooks/directive.sh` four-variable call signature — no new variable,
no new hook registration point; the deepening is content supplied by a
separate, independently-versioned plugin, not a structural change to
how `directive.sh` is invoked):

**`you_decide` (unchanged in substance; tightens "never re-execute"
into an explicit prohibition list):**
- Prohibited: re-running the observed role's code, opening its src/
  files to judge quality by reading code the observed role didn't ship
  as evidence (only the artifacts the observed role actually produced —
  diff, commits, its own record — are admissible), editing anything
  under the observed role's `src/`/`test/`/`docs/issue-<n>/` paths
  outside this role's own report path, filing an issue.

**`use_when` (phase 1 — RESEARCH / CURRENT-STATE SURVEY / PROPOSAL),
judgment criteria added per stage:**
- RESEARCH passes when: the observed role's actual PR number, commit
  SHAs, and its own record file have all been read this session (not
  assumed from the issue text). Fails when a claim about what the
  observed role did has no corresponding read this session.
- CURRENT-STATE SURVEY passes when: scope names the specific
  role/session/issue/PR number being observed (not "recent work" or a
  role name alone) and states which artifacts were read to write it.
  Fails when scope is stated in general terms with no PR/issue number.
- PROPOSAL passes when: it names which of the three verdict levels
  (outcome/trajectory/step) will be checked and against what evidence
  each will draw on, before any verdict language appears. Fails when
  the proposal already renders a verdict (verdicts belong to phase 2
  only, per the observed-target's own phase gate).

**`produces` (phase 2 — EXECUTION JUDGMENT), judgment criteria and
prohibitions per required element (mirrors `eo-methodology-gate`'s own
check list, so the directive states in prose exactly what the gate
enforces mechanically — no daylight between the two plugins):**
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

## (2) `eo-methodology-gate` — mechanical verification, two write surfaces

New plugin `qa/plugins/eo-methodology-gate/`, its `hooks/methodology-gate.sh`
structurally modeled on `pricing-rulebook/pricing/hooks/methodology-gate.sh`
(referenced, not copied — this repo has no vendored copy of that file
and none will be added; only the shape below is reused, rewritten for
this role's own field names and write-surface paths):

- Fail-closed `trap` on `EXIT` as the first executable statement (core
  canon idiom).
- Kill switch `EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF`, off-spelling
  rule (`""/0/false/no/off` only).
- Targets exactly two write-surface path patterns, matched by regex
  against the resolved project-root-relative path:
  - `docs/issue-[0-9]+/proposals/.*execution-observation.*\.md` (phase-1
    proposals — checked against `eo-directive`'s phase-1 criteria only)
  - `docs/issue-[0-9]+/reports/execution-observation\.md` (phase-2
    record — checked against `eo-directive`'s phase-2 criteria plus
    `eo-state`'s marker)
  Any other path: `sys.exit(0)` (not this gate's business).
- Reconstructs post-write content for `Write`/`Edit`/`MultiEdit` the
  same way the reference does (full content for Write; simulated
  replacement against current-disk content for Edit/MultiEdit; denies
  with a specific message if the resulting content can't be determined
  from the tool input).
- Required-element checks, distinct per write-surface pattern:
  - **Proposal surface** requires: a `## Scope` heading naming an issue
    or PR number pattern (`#\d+` or `issue-\d+`), a reference to a
    current-state-survey path
    (`docs/issue-<n>/reports/execution-observation`), a stated
    verdict-level plan (text containing at least two of
    `outcome`/`trajectory`/`step`), and — new in this revision — a
    `플러그인 목록`/`plugin list` section naming at least the plugins
    this proposal itself introduces (self-application: this very
    document must satisfy that once the gate exists in phase 2).
  - **Record surface** requires: an independence-statement marker
    (case-insensitive `independence statement` heading or phrase)
    appearing before the first occurrence of verdict language
    (`outcome:`/`trajectory:`/`step:`/`sound`/`deficient` — ordering
    checked by string index, not just presence), all three of
    `outcome`/`trajectory`/`step` present, — only when a deficiency is
    claimed (text contains `deficient` or `finding`) — all four of
    `impact`/`timeline`/`root cause`/`action item` present, and
    `eo-state`'s marker file present (see plugin 3).
  - Missing elements are collected into a list and named explicitly in
    the denial message, with a pointer to the owning plugin (`eo-directive`
    for a criteria-shaped miss, `eo-state` for a marker-shaped miss) as
    the norms source — mirrors pricing's actionable-denial pattern.
- Registered in this plugin's own `hooks.json` as a `PreToolUse` entry
  matching `Write|Edit|MultiEdit` — a separate manifest from `qa`'s
  existing `hooks.json` (which keeps only the `SessionStart` entry),
  since each plugin owns its own hook registration.

**Why per-surface field lists instead of one shared list (unchanged
rationale from prior revision):** a phase-1 proposal cannot yet contain
verdict language (`eo-directive`'s own prohibition) — a single shared
check list would either wrongly demand verdict-shaped text in phase 1
or wrongly skip checking independence-before-verdict ordering in phase
2. The two surfaces check different things because the phase gate
makes them substantively different documents.

## (3) `eo-state` — ordering constraint plugin

New plugin `qa/plugins/eo-state/`. The one order constraint this
methodology has: a phase-2 record must not be written before this
session has read at least one artifact of the observed target
(research-before-verdict, `eo-directive`'s RESEARCH facet). Scout
brief's adopted-scoped-down shape: a single per-session marker file,
not a lock/cap pair (no concurrency to bound here).

- `hooks/state.sh`, sourced by `qa`'s existing `directive.sh`
  (`SessionStart`, to clear any stale marker at session start — mirrors
  `hunt-state.sh`'s SessionStart-clears-state convention) and by
  `eo-methodology-gate`'s `PreToolUse` hook (to check it) — this
  cross-plugin sourcing dependency (two other plugins each source one
  file from this plugin) is stated explicitly as the composition
  contract between the three plugins, not left implicit.
- Marker path: `${CLAUDE_PROJECT_DIR:-.}/.claude/.eo-read-marker`
  (project-local, git-ignored).
- Own narrow `PostToolUse` matcher (`Read|Bash`): writes the marker only
  when the read/command target plausibly touches another role's
  artifact path (`docs/issue-<n>/reports/`, `docs/issue-<n>/proposals/`,
  or a `gh api`/`gh pr` command) — a best-effort signal, not a strict
  prover; false positives are accepted, false negatives are the failure
  mode this plugin accepts as a known limitation, stated rather than
  hidden.
- Own `.claude-plugin/plugin.json`, own registration in
  `.claude-plugin/marketplace.json`.

**Known limitation, stated rather than hidden:** this is a
weaker-than-perfect ordering proof (a `Read` of an unrelated file also
sets the marker if its path happens to match the regex loosely). It is
adopted anyway because it converts a purely prose-only "never assume"
instruction into a mechanically-checked minimum bar without a full
provenance-tracking system disproportionate to this role's actual risk
— the same proportionality judgment `hunt-guard.sh`'s own comments make
explicit about its fourth (unenforceable) limit.

## (4) Gate tests

Appended to `tests/run-gate-tests.sh` (same harness already in this
repo — real subprocess invocation, synthetic PreToolUse JSON piped over
stdin, tempdir `git init`, assert exit 0/2), tagged by which plugin's
gate is under test (`eo-methodology-gate` for all cases below; `eo-state`
is exercised only through `eo-methodology-gate`'s marker check, since it
has no `PreToolUse` gate of its own):

- `allow` — proposal write containing `## Scope`, an issue number, a
  survey-path reference, a plugin-list section, and two of the three
  verdict-level words.
- `deny` — proposal write missing the survey-path reference.
- `deny` — proposal write missing the plugin-list section (new case
  this revision, enforcing this proposal's own required section going
  forward).
- `deny` — proposal write already containing verdict language (`step:
  deficient`) — phase-1 prohibition case.
- `allow` — record write with independence statement before verdict
  language, all three levels, no deficiency claimed, marker present.
- `deny` — record write with verdict language appearing before the
  independence statement (ordering violation, not just presence).
- `deny` — record write claiming `deficient` with only 3 of the 4
  blameless-shape elements present.
- `allow` — foreign path (`docs/issue-9/reports/qa.md`) — confirms
  scope precision, gate stays out of another role's write surface.
- `deny` — record write with no prior marker file in the tempdir
  (`eo-state`'s contribution to the phase-2 composition); `allow` the
  same content once a marker file is pre-seeded in the tempdir before
  the gate runs.

## (5) Agents / checklist

Not needed for any of the three plugins. The methodology has no
repeated multi-step procedure distinct from what a single session
already does linearly (survey → scout when applicable → observe →
verdict → record); the state-tracking marker in `eo-state` is the only
"procedural order" element this methodology has, and it is covered by a
gate plus a single sourced helper script, not a standing checklist
document or an `agents/` file in any of the three plugins.

## Marketplace registration (phase 2 plan)

`.claude-plugin/marketplace.json` gains three new entries alongside
the existing `qa` entry, each pointing at `./qa/plugins/<name>` and
carrying a one-methodology description, matching the granularity
`tokenmaxxxer-core`'s own marketplace.json uses for `core`/`terse`/
`freelunch`/`scout`/`warrant`:

```json
{
  "name": "eo-directive",
  "source": "./qa/plugins/eo-directive",
  "description": "Per-facet phase-1/phase-2 judgment criteria and prohibitions for the execution-observation methodology: what counts as a valid citation, what disqualifies a scope statement, what a proposal may not yet say, what a record must say and in what order."
},
{
  "name": "eo-methodology-gate",
  "source": "./qa/plugins/eo-methodology-gate",
  "description": "Mechanical PreToolUse verification that a written execution-observation proposal or record actually contains the elements eo-directive requires, fail-closed, path-scoped to this role's own write surfaces only."
},
{
  "name": "eo-state",
  "source": "./qa/plugins/eo-state",
  "description": "Session-scoped marker enforcing that a phase-2 execution-observation record is never written before at least one artifact of the observed target has been read this session."
}
```

The existing `qa` plugin entry is unchanged (still owns `commands/` and
the `directive.sh`/`hooks.json` sourcing stub); it is the plugin that
composes the other three in by sourcing their files, not a container
that absorbs their content.

## Constraints (unchanged from contract v3 / prior sessions in this repo)

- Phase 1 only this session: research + survey + scout + this
  proposal, open/update the PR, stop. No creation of
  `qa/plugins/eo-directive/`, `qa/plugins/eo-methodology-gate/`,
  `qa/plugins/eo-state/`, no edit to `qa/hooks/*`,
  `.claude-plugin/marketplace.json`, or `tests/run-gate-tests.sh` in
  this session.
- No APPROVE by any role, including self.
- Canon scripts referenced, never copied — confirmed again this
  session (`docs/decisions/` "core canon-scripts.md" constraint;
  `pricing-rulebook`'s `methodology-gate.sh` is read and its shape
  described, not fetched into this repo as a file).
- Role boundary / `write_scope` unchanged: only `qa/*` and
  `docs/issue-47/` are touched by this proposal's plan; no other role's
  directory.

## Out of scope

- Actually creating any of the three plugin directories, their
  `.claude-plugin/plugin.json` files, `hooks/*.sh`, editing
  `.claude-plugin/marketplace.json`, or appending to
  `run-gate-tests.sh` — phase 2, after human APPROVE.
- Resolving the pre-existing `RECORD_FIELDS_TERMINAL_STATES` open
  finding from issue-41 — unrelated blocked item, not this issue's ask;
  phase 2 must simply not assume it is set.
- Renaming the `qa/` plugin directory or the `qa` plugin entry itself
  (template-mismatch, out of scope per issue-41's precedent) — this
  proposal adds sibling plugins under `qa/plugins/`, it does not rename
  or restructure the existing `qa` plugin.
- Fetching or vendoring any file from `pricing-rulebook`,
  `implementation-rulebook`, or `tokenmaxxxer-core` — reference only.

## How it'll be known to work (phase 2 acceptance)

- Three new directories exist: `qa/plugins/eo-directive/`,
  `qa/plugins/eo-methodology-gate/`, `qa/plugins/eo-state/`, each with
  its own `.claude-plugin/plugin.json` (name/description/author,
  matching `scout/.claude-plugin/plugin.json`'s shape) and, where
  applicable, its own `hooks/` and `hooks.json`.
- `.claude-plugin/marketplace.json` lists four plugins total (`qa` plus
  the three new ones), each with a description naming exactly one
  methodology, matching this proposal's plugin-list table.
- `qa/hooks/directive.sh`'s four bodies are sourced from
  `eo-directive`'s file and contain the per-facet judgment criteria
  from section (1), still passing `bash -n` and
  `tests/parse-check.sh`.
- `eo-methodology-gate/hooks/methodology-gate.sh` exists, passes
  `bash -n`, and `tests/stub-check.sh qa/hooks` still passes.
- `eo-methodology-gate`'s own `hooks.json` registers the new
  `PreToolUse` entry; `tests/run-gate-tests.sh` passes with the new
  cases from section (4) included, `[ "$fail" -eq 0 ]` at the end.
- `eo-state/hooks/state.sh` exists and is sourced by both
  `qa/hooks/directive.sh` and `eo-methodology-gate/hooks/methodology-gate.sh`,
  confirmed by grep for the source line in both files.
- A manual dry run: writing a synthetic incomplete proposal/record
  through `eo-methodology-gate`'s script directly is denied with a
  message naming the specific missing element(s) and which owning
  plugin's norm was unmet; a complete one is allowed.
