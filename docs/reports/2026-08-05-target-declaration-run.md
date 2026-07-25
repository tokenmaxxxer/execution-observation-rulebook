---
proposal: docs/proposals/2026-08-05-target-declaration.md
---

# Run record — target-declaration

Records the actual runs performed to close out
`docs/proposals/2026-08-05-target-declaration.md` (issue #22).

## What the gate now enforces

`qa-cycle/hooks/transition-gate.sh`'s `TABLE` row for
`observed -> reproducing` carries `"requires": ["target"]`, the same
`requires`-driven mechanism `severity` already uses on
`reproducing -> reproduced`. When present, the gate:

1. Resolves `<QA_WORKSPACE>/projects/<slug>/target.md` from the already
   allow-list-validated project slug, then independently
   resolve-then-contain checks the resulting path against the workspace
   root before opening it (the same two-part treatment `state_path` and
   `tokens_dir` already get).
2. Refuses if the file is absent, unreadable, or not exactly one
   well-formed `---`-delimited block.
3. Refuses if the block does not carry exactly one non-empty `label:` and
   exactly one non-empty `entry_point:` line.
4. Refuses if the attempted write's own item block does not reference the
   declared `label` or `entry_point` anywhere in its text.
5. Only once all four hold does the transition proceed to the normal
   table-match / token logic below it.

Every branch refuses (exit 2) by default; there is no fall-through path
from a malformed or absent declaration to allow.

## Harness run

```
$ bash qa-cycle/hooks/tests/run-gate-tests.sh
...
case: valid-table-permitted-transition | expected: 0 | observed: 0 | ok
...
case: target-absent-refused | expected: 2 | observed: 2 | ok
case: target-empty-refused | expected: 2 | observed: 2 | ok
case: target-missing-required-field-refused | expected: 2 | observed: 2 | ok
case: target-project-id-disallowed-characters-refused | expected: 2 | observed: 2 | ok
case: target-valid-declaration-allowed | expected: 0 | observed: 0 | ok

=== tally: 47 passed, 0 failed (of 47 cases) ===

=== directive-drift-check ===

directive-drift-check: undeclared subjects (informational, not a failure):
  - transition (none)->observed
  - transition parked-unreproducible->observed
  - transition re-verifying->verified-fixed
  - transition re-verifying->reproducing

directive-drift-check: passed — no directive claim mismatches the gate's declared facts.
=== directive-drift-check: passed ===
```

Exit code: `0`. All 42 pre-existing fixture cases (through case 34) pass
unchanged in outcome; case 1 (`valid-table-permitted-transition`)'s
fixture was extended with a valid `target.md` and evidence referencing it
so its intent — "a legal transition is allowed" — still holds under the
new precondition (see "What did not work" in the proposal for the one
fixture that needed changing versus the many that didn't). Five new cases
(35-39) cover: target absent, target present but empty, target present
but missing `entry_point`, a crafted project id (`owner;rm-repo`)
attempting to escape the workspace root via the target path, and a valid
declaration referenced by the write's own evidence.

## `directive-drift-check.sh`, standalone

```
$ qa-cycle/hooks/tests/directive-drift-check.sh
...
directive-drift-check: passed — no directive claim mismatches the gate's declared facts.
```

Exit code: `0`. `testrun/hooks/directive.sh`'s `gate-claim` for
`observed->reproducing` now reads `requires=target`, matching
`--dump-facts`'s `{"from": "observed", "to": "reproducing", "actor":
"agent", "requires": ["target"]}` row exactly (normalized to `target`),
so no divergence is reported for this subject.

## Known gap outside this build's frozen scope

`docs/reports/2026-08-05-hunt-target-declaration.md` (pre-existing in
this tree, not authored as part of this build) identifies that
`re-verifying -> reproducing` — a second, pre-existing row landing an
item in the same `reproducing` state — carries no `target` precondition
and is untouched by this proposal, which scopes the precondition to the
`observed -> reproducing` row only. An item can reach `reproducing` via
that second row without `target.md` ever existing. The proposal's write
set and item 4 explicitly name only the `observed -> reproducing` row;
extending the precondition to `re-verifying -> reproducing` is a design
decision outside what was approved here and is left as a follow-up.

## Tally

| Run | Cases | Pass | Fail | Exit |
|---|---|---|---|---|
| `run-gate-tests.sh` (full suite, includes drift check) | 47 fixture cases + drift check | 47 | 0 | 0 |
| `directive-drift-check.sh` (standalone) | 3 divergence checks, 4 undeclared reports | n/a | 0 | 0 |
