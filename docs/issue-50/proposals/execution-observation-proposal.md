# issue-50 A+ remediation proposal (execution-observation, phase 1)

## Scope

Target: this repo (`execution-observation-rulebook`), issue #50, PR
against `main` from `issue-50/execution-observation`. Files touched by
this proposal's design (phase 2 only, not this session): `qa/plugins/
eo-methodology-gate/hooks/methodology-gate.sh`, `qa/plugins/eo-state/
hooks/state.sh`, `tests/run-gate-tests.sh`, repo-root
`.warrant-hunt.count`, `qa/plugins/eo-methodology-gate/README.md`,
`docs/handbooks/execution-observation-plugins.md`. No other role's
directory, no core canon repo (`tokenmaxxxer/tokenmaxxxer-core`), no
sibling rulebook repo is touched — core canon is read and referenced,
never edited or copied, per `docs/handbooks/canon-scripts.md`'s
reference-not-copy rule, already the convention `methodology-gate.sh`'s
own header states for its pricing-rulebook lineage.

## Current-state survey reference

`docs/issue-50/reports/execution-observation/survey.md` — confirms live
(this session, `bash tests/run-gate-tests.sh`) the issue's 7/17
exit-127 (dead references to nonexistent `record-fields-gate.sh`/
`trailer-gate.sh`), the 2 `true ||`-disabled cases (both targeting the
same nonexistent file — doubly dead), `.warrant-hunt.count` as unowned
root residue (`git status --short`), and reads `methodology-gate.sh` in
full to confirm the substring-only semantic checks and the pre-gate-lib
hand-rolled trap/kill-switch/reconstruct logic, including the exact
kill-switch default-open-on-unrecognized-value bug and the exact
`replace_all`-ignored / no-`NotebookEdit` bug that `gate-house-
standard.md` (core issue #72, landed) names as the two confirmed bug
classes it fixed.

## Scout brief

`docs/issue-50/reports/execution-observation/scout-brief.md` — the
prerequisite named exactly one adoption target
(`core/hooks/lib/gate-lib.sh` / `gate-lib.py`, `docs/handbooks/gate-
house-standard.md`, core issue #72), read in full this session via `gh
api` against `tokenmaxxxer/tokenmaxxxer-core`. That reading is this
proposal's primary scout input; a supplementary single-angle look at
pricing-rulebook's own post-migration `methodology-gate.sh` shape
(same lineage `methodology-gate.sh`'s header already cites) rounds out
what a migrated call site looks like in practice.

## Verdict-level plan (stated before any verdict-shaped language)

- **outcome** — checked against: `tests/run-gate-tests.sh` exits 0
  (17/17 including the added mandatory cases), `qa/plugins/eo-*`
  gates source `gate-lib.sh`/`gate-lib.py` with no hand-rolled
  trap/kill-switch/reconstruct/path-normalize logic remaining,
  `compliance-check.sh` (once phase-2 code lands) run clean against
  `qa/plugins/*/hooks/`, README/handbook text matches the landed code.
- **trajectory** — checked against: this proposal names the adopted
  reference before design (this section), the phase boundary is
  respected (no code changes in this session, only docs under this
  role's phase-1 write surfaces), the approval gate (contract v3 s19)
  is honored before any phase-2 write.
- **step** — will be recorded per-artifact in the phase-2 record
  (`docs/issue-50/reports/execution-observation.md`), not here — this
  is a phase-1 proposal.

## Plugin list (unchanged set, migrated in place)

- `eo-directive` — unchanged by this issue; no gate logic, no kill
  switch of its own.
- `eo-methodology-gate` — migrates its hand-rolled trap, kill-switch,
  path-normalize, and Edit/MultiEdit reconstruction to `gate_trap_fail_
  closed`, `gate_kill_switch_active`, `gate_normalize_path`,
  `gate_reconstruct_write`; semantic checks upgraded per below.
- `eo-state` — migrates its hand-rolled kill-switch case statement to
  `gate_kill_switch_active`; no other change (it is not a `PreToolUse`
  gate and has no reconstruction/path-normalize logic to migrate).

## Design: reference adoption (requirement 1 — fixes the audit
defects by construction, not by patching each symptom)

Rather than hand-patch `methodology-gate.sh`'s kill-switch case
statement and reconstruction logic independently (which would leave
this repo re-deriving the same shapes `gate-house-standard.md` exists
specifically to stop re-deriving), both `eo-methodology-gate` and
`eo-state` source `gate-lib.sh` and (for `methodology-gate.sh`'s Python
payload) load `gate-lib.py` via the documented `importlib` pattern:

```
. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF:-}" || { trap - EXIT; exit 0; }
```

and, in the heredoc Python payload:

```python
import importlib.util, os
_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)
ev = gate_lib.gate_parse_json_or_deny(raw, deny)
rel = gate_lib.gate_normalize_path(root, path)
new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
```

This is the mechanical fix for every named defect except the semantic
ones:

- **path matching (absolute-path normalization)** — `gate_normalize_
  path` replaces the hand-rolled `_under`/`resolve()` bash+python mix;
  its contract already covers absolute, relative, and `./`-prefixed
  inputs (survey section 5), which is exactly the case class the issue
  names ("경로 매칭(절대경로 정규화)").
- **fail-closed (trap-at-top)** — `gate_trap_fail_closed` is the one
  canonical trap; called as the literal first statement, before `set
  -uo pipefail`, matching the library's own stated contract (a syntax
  error on the next line must still be caught).
- **malformed-JSON deny** — `gate_parse_json_or_deny` replaces the
  gate's own ad hoc `try: json.loads(...) except Exception: sys.exit(0)`
  pattern (note: today's code silently *passes through* — `sys.exit(0)`
  — on a JSON parse failure inside the `_target` extraction at the top
  of the script, which is itself a fail-open gap the survey did not
  previously name explicitly; `gate_parse_json_or_deny` denies instead,
  closing it).
- **kill switch unrecognized value = active** — `gate_kill_switch_
  active` is the fixed convention (only `1`/`true`/`yes`/`on`,
  case-insensitive, disables; every other value, including a typo,
  stays active) — directly reverses the exact bug class both `eo-
  methodology-gate` and `eo-state`'s current case statements carry.
- **Edit/MultiEdit/replace_all full reconstruction** — `gate_
  reconstruct_write` replaces the gate's own `.replace(o, n, 1)` (always
  first-occurrence, `replace_all` never read) and adds `NotebookEdit`
  handling this gate never had.
- **deny reason to stderr** — `gate_deny` is stderr-only exit-2, same
  contract the gate's own `deny()` already followed; migrating just
  removes the now-duplicate local definition in favor of the shared
  one.

## Design: semantic-check upgrade (requirement 2 — substring to
section/adjacency/structure)

Each of `methodology-gate.sh`'s five proposal checks and the record's
level/blameless checks moves from a bare `in`/`has_any` test to a
check scoped to the actual structural unit the methodology requires,
using only the stdlib `re` already imported (no new dependency):

- **`## Scope` heading** — already structural (a literal heading
  match); unchanged, kept as the one check that was already correct.
- **Verdict-level plan (proposal)** — today: `>=2` of
  outcome/trajectory/step appear *anywhere* in the whole document,
  satisfied by e.g. a stray sentence like "the outcome of the prior
  issue's trajectory was..." with no plan shape at all. Upgraded: parse
  the document into `##`/`###`-delimited sections (split on
  `^#{2,3}\s`, `re.MULTILINE`); require a section whose heading matches
  `verdict.level|verdict-level|plan` (case-insensitive) to exist, and
  within that section's body specifically (not the whole document)
  count `>=2` of the three level words, each appearing adjacent to a
  colon or dash marker (`re.search(r'\b(outcome|trajectory|step)\s*[:—-]', section_body, re.I)`)
  — i.e. the words must appear in list/plan position, not prose
  mention.
- **Plugin-list section** — today: `has_any("플러그인 목록", "plugin
  list", "plugin 목록")` anywhere. Upgraded: same heading-section
  parse; require a section heading matching the same needles, and
  require its body to contain at least one markdown list item
  (`^\s*[-*]\s+\S`, `re.MULTILINE`) — a heading with no list under it
  no longer passes, and the words no longer need to be a heading
  specifically but the match must anchor to a heading line
  (`^#{2,3}.*`) rather than anywhere in the body.
- **Premature-verdict prohibition (proposal)** — today already
  adjacency-shaped (`"outcome: sound"` etc. as literal 2-word phrases);
  generalize the separator to match the level-plan check's own marker
  set (`\b(outcome|trajectory|step)\s*[:—-]\s*(sound|deficient)\b`,
  `re.I`) so a proposal cannot dodge the prohibition by using an em
  dash or extra whitespace where the plan check now requires exactly
  that shape to *pass* elsewhere.
- **Independence-before-verdict ordering (record)** — today already
  adjacency/ordering-shaped (index comparison); unchanged in mechanism,
  but the verdict-marker search widens to the same
  `\b(outcome|trajectory|step)\s*[:—-]` pattern instead of the bare
  substrings `"outcome:"`/`"sound"`/`"deficient"` (today's bare `"sound"`
  substring false-positives on any English sentence containing the word
  "sound" with no verdict shape at all — e.g. "this design sounds
  reasonable").
- **Three verdict levels present (record)** — today: bare substring
  per level anywhere. Upgraded: same adjacency pattern
  (`\b(outcome|trajectory|step)\s*[:—-]`) per level, required to appear
  at least once each — closes the same false-positive class as above
  (a record that merely discusses "the outcome" in prose without ever
  stating a verdict for it currently passes; it will not after this
  change).
- **Blameless shape (record, gated on deficiency/finding claim)** —
  today: bare substring per component anywhere in the document.
  Upgraded: parse sections again; once a `deficient`/`finding` trigger
  is detected (kept as a document-wide substring gate — a trigger
  check is intentionally permissive, only the *shape* check tightens),
  require the four components (`impact`, `timeline`, `root cause`,
  `action item`) to each appear as a heading or a bold/labeled line
  within a bounded window (the same section, or the 5 lines
  immediately following the deficiency/finding mention) rather than
  anywhere in a possibly-unrelated part of the document — implemented
  as: for each deficiency/finding mention's line index, scan the
  containing section's body for the four component labels, matched
  against `^#{2,4}.*label|^\s*\*\*label` (heading or bold-label line
  start) instead of bare substring.

Net effect: every upgraded check requires the matched text to occupy a
structural position (heading, list-item, label-line, or a fixed
adjacency window to a trigger) instead of appearing anywhere in the
document — directly answering the issue's "채택 방법론의 판단이 '단어
언급'으로 통과되지 않게" requirement without inventing a new parser;
`re` with `re.MULTILINE` plus a simple `##`/`###` section splitter is
sufficient for markdown documents this gate already fully controls the
shape of (they are written by this same role's own directive).

## Design: mandatory test cases (requirement 3)

Phase 2 test work adds, to `tests/run-gate-tests.sh` (or a new
`tests/run-gate-lib-tests.sh` companion mirroring `gate-house-
standard.md`'s six-case harness, whichever the phase-2 implementation
finds cleaner given this repo's existing single-file test convention):

1. **Edit with `replace_all: true` against a multiply-occurring
   `old_string`** — asserts `gate_reconstruct_write` output, not the
   old always-first-occurrence behavior.
2. **MultiEdit with mixed `replace_all: true`/`false` edits in one
   call** — same, per-edit independence.
3. **Malformed JSON** (truncated, non-object top level, empty payload)
   — asserts deny (fail-closed on unparseable input), replacing/
   extending the existing `record-empty`-shaped case now targeting a
   payload-level defect instead of a content-level one.
4. **Kill switch set to an unrecognized value** (e.g. a typo) — asserts
   the gate stays **active** (opposite of today's confirmed bug).
5. **Absolute `file_path`** matching the same scope a relative-path
   fixture already matches, plus a `./`-prefixed variant — both must
   resolve to the same allow/deny verdict as the relative case.
6. **A structural-vs-mention semantic case per upgraded check** —
   a document that mentions "outcome"/"trajectory"/"step" only in
   prose (no plan-shaped section, no adjacency marker) must now deny
   where the old substring check would have allowed; a document with
   the actual plan-shaped section must still allow. Same construction
   for the plugin-list-heading-with-no-list-body case and the
   bare-"sound"-in-prose record case.

The existing 7 dead `record-fields-gate.sh`/`trailer-gate.sh` cases
(2 already `true ||`-disabled) are removed rather than fixed — no
script has been proposed to reintroduce a `record-fields-gate.sh`
under `qa/hooks/`; if either dead reference in fact still names a
requirement, that is a distinct decision for its own issue, not this
one, since re-adding a gate is design scope this issue's audit finding
did not request (the finding is that the *test* references a
nonexistent *file*, not that the file itself is a known-good deletion
to fix).

## Design: README/handbook resync (requirement 4)

Phase 2 updates `qa/plugins/eo-methodology-gate/README.md` and
`docs/handbooks/execution-observation-plugins.md` to describe the
post-migration shape (gate-lib sourcing, upgraded structural checks,
the corrected kill-switch default) once the code lands — not before,
so the docs never describe code that does not yet exist. `.warrant-
hunt.count` at repo root is removed in the same phase-2 pass as an
unowned residue file (survey section 2 confirms no script in this repo
produces or consumes it).

## Non-goals (explicit)

- No new plugin is added; the existing three-plugin set (`eo-
  directive`, `eo-methodology-gate`, `eo-state`) is migrated in place.
- No change to `eo-directive`'s directive text/body — it names no
  kill switch and does not hand-roll trap/reconstruct logic.
- No re-derivation of `gate-lib.sh`/`gate-lib.py` logic in this repo —
  sourced only, per the reference-not-copy convention; a vendored copy
  would itself be exactly the defect class `stub-check.sh`-equivalent
  tooling (`canon-manifest.txt`) exists to catch.
- No reintroduction of `record-fields-gate.sh`/`trailer-gate.sh` — see
  above.
