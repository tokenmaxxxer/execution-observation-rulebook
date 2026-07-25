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

## Revision — closing the `re-verifying -> reproducing` gap

The "Known gap outside this build's frozen scope" section above is now
closed. The user asked, in this same PR, for the hunt's finding to be
fixed rather than left as a follow-up: the `target` precondition attaches
to `reproducing` as a DESTINATION STATE, not to a single row, so every row
in `qa-cycle/hooks/transition-gate.sh`'s `TABLE` whose `to` is
`reproducing` now carries `"requires": ["target"]`. Today that is exactly
two rows: `observed -> reproducing` (already covered) and
`re-verifying -> reproducing` (the row the hunt found unguarded). No
further row into `reproducing` exists in the 12-row table.

### What was run

```
$ bash qa-cycle/hooks/tests/run-gate-tests.sh
...
case: target-absent-refused-re-verifying-to-reproducing | expected: 2 | observed: 2 | ok
case: target-valid-declaration-allowed-re-verifying-to-reproducing | expected: 0 | observed: 0 | ok

=== tally: 49 passed, 0 failed (of 49 cases) ===

=== directive-drift-check ===

directive-drift-check: undeclared subjects (informational, not a failure):
  - transition (none)->observed
  - transition parked-unreproducible->observed
  - transition re-verifying->verified-fixed
  - transition re-verifying->reproducing

directive-drift-check: passed — no directive claim mismatches the gate's declared facts.
=== directive-drift-check: passed ===
```

Exit code: `0`. Two new cases were added (40, 41): case 40 reproduces the
hunt exactly — `re-verifying -> reproducing` with no `target.md` anywhere
in the workspace — and now refuses. Case 41 is its companion: the same
transition with a valid target declaration referenced by the write's own
evidence still allows. Every one of the 47 pre-existing cases (including
the earlier revision's Case 1 fixup) passes unchanged, so no further
fixture needed correction — no existing case exercised
`re-verifying -> reproducing` before this revision.

`re-verifying -> reproducing` still shows as an "undeclared subject" in
the drift check's informational report, exactly as it did before this
revision (no directive's `gate-covers` names it, on either side of this
change) — this is informational, not a hard failure, and the drift check
still exits `0`.

### The hunt's reproduction, re-run against the fixed gate

Re-running `docs/reports/2026-08-05-hunt-target-declaration.md`'s exact
reproduction (`WS=/tmp/target-hunt-ws`, `BUG-1` moving
`re-verifying -> reproducing` with no `target.md` anywhere in the
workspace) now refuses:

```
qa-cycle: refused — item BUG-1: re-verifying -> reproducing requires a target declaration at /tmp/target-hunt-ws/projects/acme-app/target.md and none is present. The agent writes target.md (label, entry_point, env_names — names only, never values) before attempting this transition.
```

Observed exit code: `2` (was `0` before this revision).

## Revised tally

| Run | Cases | Pass | Fail | Exit |
|---|---|---|---|---|
| `run-gate-tests.sh` (full suite, includes drift check) | 49 fixture cases + drift check | 49 | 0 | 0 |
| `directive-drift-check.sh` (standalone) | 3 divergence checks, 4 undeclared reports | n/a | 0 | 0 |
| Hunt reproduction, re-verifying -> reproducing, no target.md | 1 manual repro | — | — | 2 (refused, was 0) |
