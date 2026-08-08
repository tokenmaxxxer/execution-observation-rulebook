---
files:
  - docs/design.md
  - docs/design.ko.md
  - docs/handbooks/execution-observation-plugins.md
  - execution-observation/plugins/eo-directive/hooks/directive-body.sh
  - execution-observation/plugins/eo-methodology-gate/hooks/methodology-gate.sh
  - tests/run-gate-tests.sh
  - execution-observation/README.md
  - docs/issue-63/reports/implementation/survey.md
  - docs/issue-63/proposals/implementation-proposal.md
---

# issue-63: align rulebook with landed execution-observation spec (marketplace #521)

## Request

Bring this rulebook's methodology docs, handbooks, and hooks/gates into
alignment with the execution-observation role spec landed upstream in
marketplace issue #521 (`tokenmaxxxer/on-the-record`,
`roles/specs/execution-observation.spec.json` +
`roles/execution-observation.json`): teach and enforce the same
deliverable shape the spec declares (EARL-style fields, five-value
`result` enum, `loop_state` names, worst-case recomputation rule) —
without duplicating any check the marketplace's own
`role-spec-reference-guard.sh` already covers, and without changing this
role's scope.

## Constraints

- No role scope change — this role still judges phase-1→phase-2
  soundness by reading artifacts, never re-executing; still never edits
  the observed artifact; still never files issues.
- No forked enforcement logic for reference-resolution or recomputation
  — those stay owned by the marketplace (`role-spec-reference-guard.sh`
  upstream; recomputation `checked_by: TBD` — not this repo's job yet).
- Write scope stays `docs/issue-<n>/reports/execution-observation.md`
  (unchanged, matches spec).
- Acceptance requires: (a) `grep -rl loop_state docs/ hooks/`
  outputs only files whose state names match the spec's list going
  forward; (b) the methodology doc names each of the spec's five
  required fields at least once; (c) `python3 -m pytest -q` still
  passes or the record states `unverifiable: no test suite present`.

## Rationale

**Chosen approach: layer the spec's vocabulary onto the existing
three-level verdict, rather than replacing the three-level verdict with
the spec's flat `result` enum.** The spec describes the deliverable's
*evidence shape* — a per-claim EARL-style judgment (`subject`, `test`,
`result` from a 5-value enum, `assertedBy`, `mode`) plus a recomputation
rule that derives one summary from those per-claim results. This
rulebook's `outcome`/`trajectory`/`step` verdict is a *summary
judgment structure* built on top of per-claim evidence, not a
competing way to express the same per-claim results — so the two
compose: `step`-level findings can each carry `subject`/`test`/`result`/
`assertedBy` fields, and `outcome` is exactly the kind of
worst-case-across-cited-results the spec's recomputation rule
describes.

**Alternative considered and rejected: replace the three-level verdict
wholesale with the spec's flat `result` enum**, dropping `outcome`/
`trajectory`/`step` and the blameless four-part shape. Rejected because
the issue is explicit — "No role scope change; alignment only" — and
the three-level verdict is this rulebook's own phase-2 judgment
structure, never claimed or referenced by the spec at all; the spec is
silent on how a role should structure its *summary* judgment, only on
the shape of the *evidence* backing it. Discarding a working,
gate-enforced methodology to match a spec that doesn't ask for its
removal would be a scope change disguised as alignment, and would throw
away the blameless-shape and independence-ordering checks the gate
already enforces with no replacement.

## What will be done

1. `docs/design.md` / `docs/design.ko.md`: add a short subsection naming
   the spec's five required fields (`subject`, `test`, `result`,
   `assertedBy`, `mode`) and the recomputation rule (worst-case across
   cited results, never a standalone summary), citing
   `roles/specs/execution-observation.spec.json` in `on-the-record` as
   the source of truth. State explicitly that this vocabulary applies
   at the `step`-level (each deficiency/finding cites `subject`/`test`/
   `result`/`assertedBy`), and that `outcome` is the spec's
   recomputation applied across a record's cited `step`-level results.
2. `docs/handbooks/execution-observation-plugins.md`: under
   `eo-methodology-gate`, add one paragraph pointing at the spec fields
   and `loop_state` names as the canonical vocabulary the gate's
   structural checks are meant to track, and note that reference-
   resolution enforcement lives upstream in
   `on-the-record/hooks/role-spec-reference-guard.sh`, referenced not
   forked.
3. `execution-observation/plugins/eo-directive/hooks/directive-body.sh`:
   in `produces`, rename each verdict level's evidence requirement to
   name `subject`/`test`/`result`/`assertedBy` explicitly instead of
   only "commit SHA, file:line, or PR comment URL"; state the
   recomputation rule for `outcome` in the same paragraph. In
   `hand_off`, replace the bare "update its loop_state at every
   transition" with the spec's actual state names
   (`running`/`collecting-evidence` in progress, `handed-off` terminal,
   `execution-not-possible` refusal, `environment-setup-failed` error).
4. `execution-observation/plugins/eo-methodology-gate/hooks/
   methodology-gate.sh`: no new checks added (per Constraints); only
   update comments/error strings that currently describe the verdict
   model in vocabulary inconsistent with the spec, so a reader of the
   gate's denial messages sees the same field names as the docs. If, on
   inspection while implementing, the gate hard-codes no state names
   (current survey found none), this file may end up comment-only or
   untouched — that is a legitimate outcome of this step, not a
   deviation.
5. `tests/run-gate-tests.sh`: update only fixture/comment text that
   currently uses vocabulary inconsistent with the spec; no new test
   cases for reference-resolution or recomputation (those stay
   unenforced here per Constraints).
6. `execution-observation/README.md`: update the "Record" paragraph to
   name the spec fields and `loop_state` states.

## Out of scope

- Rewriting `loop_state` values in already-closed per-issue records
  (issue-41/47/50/53/56/61) — those are historical and not part of this
  alignment's write set; only forward-looking docs/hooks change.
- Building reference-resolution or recomputation enforcement in this
  repo — both stay owned upstream (marketplace gate present/TBD
  respectively).
- Any change to this role's `write_scope`, `use_when`, or core
  responsibilities.
- Fixing the marketplace's own `roles/execution-observation.json`
  `produces` gloss (`pass/fail/blocked`, a 3-value gloss inconsistent
  with its own spec's 5-value enum) — that file lives in
  `tokenmaxxxer/on-the-record`, not this repo.

## How you'll know it worked

- `grep -c` for each of `subject`, `test`, `result`, `assertedBy`,
  `mode` against `docs/design.md` (or `docs/handbooks/
  execution-observation-plugins.md`) exits 0 (each found at least once).
- `grep -rl "loop_state" docs/ execution-observation/` restricted to
  files this proposal touches uses only the spec's five state names
  (`running`, `collecting-evidence`, `handed-off`,
  `execution-not-possible`, `environment-setup-failed`).
- `python3 -m pytest -q` exits 0, or the phase-2 record states
  `unverifiable: no test suite present` if none is discovered.
- `tests/run-gate-tests.sh` (this repo's actual gate test harness) still
  passes after any comment/string edits to `methodology-gate.sh`.
