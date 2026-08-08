# issue-63 current-state survey

Subject: issue-63. Scope: align this rulebook (methodology docs, handbooks,
hooks/gates) with the landed execution-observation role spec, marketplace
issue #521 (`tokenmaxxxer/on-the-record`, `roles/specs/execution-observation.spec.json`
+ `roles/execution-observation.json`, read live via `gh api` this session).

## Landed spec (source of truth)

`roles/specs/execution-observation.spec.json` (source_standard: EARL 1.0):

- `required_fields`: `subject` (ref), `test` (ref), `result` (enum:
  `passed|failed|cantTell|inapplicable|untested`), `assertedBy` (string),
  `mode` (string, optional).
- `reference_resolution`: subject/test must each resolve to a repo path,
  commit sha, or a command actually run — no orphan refs. Checked by
  `on-the-record/hooks/role-spec-reference-guard.sh` (lives in the
  marketplace repo, not here).
- `recomputation`: overall verdict = worst-case across all cited test
  entries (`failed > cantTell > inapplicable > untested > passed`), never
  a standalone asserted summary. `checked_by: "TBD"` — explicitly marked
  out of scope for per-role enforcement in issue-521; not this rulebook's
  job to build that check yet.
- `write_scope`: `["docs/issue-<n>/reports/execution-observation.md"]` —
  unchanged from this rulebook's current write scope.
- `loop_state`: `progress: [running, collecting-evidence]`,
  `terminal: [handed-off]`, `refusal: [execution-not-possible]`,
  `error: [environment-setup-failed]`.
- `use_when.board_condition`: "an executable artifact landed on the
  branch AND no execution-observation record exists yet for this commit
  sha".

`roles/execution-observation.json` (updated alongside the spec) restates
`write_scope` and `loop_state` identically, and glosses `produces` as
"증거 인용된 claim별 pass/fail/blocked, run command/log reference, 버그
리포트(레코드로; 이슈는 사용자가)" — a three-value gloss (pass/fail/blocked)
that itself doesn't match the five-value spec enum; noted as a
marketplace-side inconsistency, not something this rulebook can or should
fix (out of this repo's write scope).

## This rulebook's current shape (mismatches)

Read this session: `execution-observation/README.md`,
`execution-observation/plugins/eo-directive/hooks/directive-body.sh`,
`execution-observation/plugins/eo-methodology-gate/hooks/methodology-gate.sh`,
`execution-observation/plugins/eo-state/hooks/state.sh`,
`docs/handbooks/execution-observation-plugins.md`, `docs/design.md`,
`docs/design.ko.md`, and `docs/issue-{41,47,50,53,56,61}` records.

1. **Field/verdict vocabulary drift.** The rulebook's whole methodology
   is a bespoke three-level verdict (`outcome` / `trajectory` / `step`,
   each `sound|deficient`) enforced by `eo-directive`'s directive text
   and mechanically checked by `eo-methodology-gate.sh`'s
   `LEVEL_MARK_RE` / `verdict_re`. None of `subject`, `test`, `result`,
   `assertedBy`, `mode`, or the `passed/failed/cantTell/inapplicable/
   untested` enum appear anywhere in `execution-observation/**` or
   `docs/handbooks/**`. `grep -rn "assertedBy|EARL|cantTell|
   role-spec-reference-guard"` across the repo returns nothing outside
   this issue's own new docs.
2. **`loop_state` vocabulary drift.** Landed spec states:
   progress = `running`, `collecting-evidence`; terminal = `handed-off`;
   refusal = `execution-not-possible`; error =
   `environment-setup-failed`. Existing records in this repo use
   `blocked` (issue-41), `landed` (issue-47/50/53), `phase-2-complete`
   (issue-56, and issue-61's implementation record) — none of which are
   in the spec's list. No doc or hook in this repo currently states or
   checks the spec's five state names at all; `eo-methodology-gate.sh`
   never inspects `loop_state` value, only its presence/absence isn't
   even checked structurally. (Historical per-issue records are not in
   this alignment's write set — rewriting closed issues' records is out
   of scope; the mismatch is that nothing *forward-looking* teaches or
   enforces the landed names yet.)
3. **Recomputation rule absent.** Nothing in this rulebook states
   "overall verdict = worst-case across cited results" — the closest
   existing idea is the three-level verdict's "step" level (which
   artifact is deficient), a different axis (locates blame) rather than
   the spec's recomputation rule (derives one summary value from cited
   per-claim results, never asserted standalone). `checked_by: TBD` in
   the spec means no enforcement hook is expected yet even upstream;
   this rulebook only needs to *teach* the rule in prose, matching the
   spec's own deferral on enforcement.
4. **Reference-resolution rule under-specified locally.** The spec's
   "subject and test must each resolve to a repo path, commit sha, or a
   command actually run" is checked upstream by
   `on-the-record/hooks/role-spec-reference-guard.sh` (a marketplace-side
   gate, outside this repo). This rulebook's own citation rule
   (`eo-directive`'s "VERDICTS REQUIRE CITATION" — commit SHA, file:line,
   or PR comment URL) is compatible in spirit but doesn't name
   `subject`/`test` as the two ref fields being resolved, so a reader
   can't map the rulebook's citation rule onto the spec's two named
   fields by name.
5. **No duplicated-logic risk found for reference-resolution or
   recomputation**: `eo-methodology-gate.sh` currently enforces only
   this rulebook's own bespoke structural markers (verdict-level
   headings, plugin-list section, blameless four-part shape,
   independence-ordering, `eo-state` marker file) — it does not
   reimplement anything `role-spec-reference-guard.sh` already does
   upstream, so requirement 3 ("don't fork gate logic the marketplace
   gate already covers") is about *not adding* new resolution-checking
   logic here, not about removing existing logic (there is none to
   remove).

## Write set this alignment will touch

- `docs/design.md`, `docs/design.ko.md` — the two methodology docs that
  describe execution-observation's verdict/evidence model; each must
  name the spec's five required fields and the recomputation rule at
  least once (acceptance check #2).
- `docs/handbooks/execution-observation-plugins.md` — plugin-set
  handbook; add the spec's field/state vocabulary as the canonical
  reference alongside the existing plugin descriptions.
- `execution-observation/plugins/eo-directive/hooks/directive-body.sh` —
  the `produces`/`use_when`/`hand_off` directive text; align verdict and
  `loop_state` language to the spec's names (three-level verdict itself
  is not spec scope-changing — see Rationale — but the vocabulary it's
  expressed in must match).
- `execution-observation/plugins/eo-methodology-gate/hooks/
  methodology-gate.sh` and its test fixtures in `tests/run-gate-tests.sh`
  — only if the gate's structural checks reference vocabulary that
  contradicts the spec (e.g. any hard-coded state name); no new
  reference-resolution or recomputation enforcement is added here per
  requirement 3.
- `execution-observation/README.md` — one-paragraph description of the
  record; align field/state naming.

No `src/`, no dependency manifest, no `.env.example`, no migration — this
is a documentation/hook-vocabulary alignment with no new external
dependency or runtime surface.

## Alternatives considered while surveying

- **Fork `role-spec-reference-guard.sh`'s logic into this repo's own
  gate** so `eo-methodology-gate.sh` enforces reference-resolution
  itself. Rejected: requirement 3 explicitly says "no duplicated rule
  logic where the marketplace gate already covers it — reference, don't
  fork"; the marketplace repo, not this rulebook, owns that gate.
- **Replace the three-level verdict (outcome/trajectory/step) with the
  spec's flat `result` enum wholesale**, discarding the existing
  methodology. Considered because it would remove the vocabulary
  mismatch entirely. Rejected for the proposal (see its Rationale): the
  issue says "no role scope change; alignment only", and the three-level
  verdict is this rulebook's own phase-2 judgment structure, not
  something the spec claims to replace — the spec describes the
  *deliverable's evidence shape* (EARL-style per-claim results), which
  is compatible with, not a replacement for, a three-level summary
  judgment built on top of per-claim results.
