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

## Revision 2 — closing the truncated-read bypass (before-landing hunt)

The before-landing hunt in `docs/reports/2026-08-05-hunt-target-declaration.md`
found a second, independent defect: `qa-cycle/hooks/transition-gate.sh` read
`target.md` capped at `fh.read(1 << 16)` (64KB) and then judged well-formedness
by counting `---` blocks (`len(target_blocks) != 1`) over that capped prefix,
not the whole file. A `target.md` with two `---` blocks is correctly refused
as ambiguous when the file is small; padding the first block past 65536 bytes
pushes the second block outside what the gate ever reads, so the same
genuinely ambiguous file was silently allowed once it got large enough. The
frozen rule for this revision: a truncated read is never a verdict — if a
file the gate must adjudicate exceeds the cap the gate reads, that is an
unadjudicable input and the gate refuses, on every branch, rather than
judging structure from a prefix.

### Audit of every read the gate performs on a verdict-deciding file

- `current_state_text()` (`qa-cycle/hooks/transition-gate.sh`, state.md read,
  was `fh.read(1 << 20)`): **changed**. `item_state_from_text` counts blocks
  matching an item id and refuses on ambiguity (`len(matches) != 1`) the same
  way the target check does — this is the same bug class, just on state.md
  instead of target.md, and a state.md padded past 1MB with a second block
  for the same item could have flipped that ambiguity check the same way.
  Now reads `cap + 1` bytes and refuses if the extra byte materializes.
- `target_text` read (`target.md`, was `fh.read(1 << 16)`): **changed** — this
  is the hunt's exact finding. Now reads `cap + 1` bytes and refuses if the
  extra byte materializes, before `parse_blocks`/`len(target_blocks) != 1` is
  ever evaluated.
- `read_token_file` (`<item>.token` / `<item>.consuming`, `fh.read(8192)`) and
  `read_priority_token_file` (`<item>.priority.token` / `.priority.consuming`,
  `fh.read(8192)`): **audited, not changed**. Neither derives its verdict from
  a count of matches over the file — each uses `re.search` (first match only)
  to pull a single `item:`/`transition:` (or `field:`/`value:`) line. A token
  file with two conflicting `item:` lines is not treated as ambiguous at any
  size, small or truncated: the first match always wins, so there is no
  small-file-refuses / large-file-allows divergence for the cap to introduce.
  Token files are also minted only by `signoff/hooks/capture-verdict.sh`, not
  attacker-shaped input reachable through this gate's own write path. No
  count-based well-formedness check exists here for a truncation to defeat,
  so this pair is left as-is.

### Fix applied

Both changed reads now request `cap + 1` bytes instead of `cap`. If the
returned text is longer than `cap`, the extra byte proves the file exceeds
what the gate can adjudicate, and the gate refuses with a message naming the
cap — never falling through to block-counting or field-parsing on a prefix.

### Harness cases added

Appended to `qa-cycle/hooks/tests/run-gate-tests.sh`, all existing cases kept
unchanged:

- `target-second-block-past-cap-refused` (case 42): exact hunt shape — a
  first block padded past 65536 bytes, then a second `---` block — now
  refuses (was exit 0 before this revision's fix, per the hunt's Observed
  section).
- `target-oversized-otherwise-valid-refused` (case 43): a single,
  structurally valid block whose own content (a padded `env_names` line)
  pushes the file past the cap — refuses, because size alone makes the file
  unadjudicable regardless of where the padding sits.
- `target-normal-valid-declaration-still-allowed` (case 44): an ordinary,
  well-under-the-cap valid declaration — still allowed, proving the `cap + 1`
  probe read does not disturb the common path.

### Run output

```
=== tally: 52 passed, 0 failed (of 52 cases) ===

=== directive-drift-check ===

directive-drift-check: undeclared subjects (informational, not a failure):
  - transition (none)->observed
  - transition parked-unreproducible->observed
  - transition re-verifying->verified-fixed
  - transition re-verifying->reproducing

directive-drift-check: passed — no directive claim mismatches the gate's declared facts.
=== directive-drift-check: passed ===
```

Exit code: `0`. All 52 cases pass (49 from before this revision + 3 new),
the drift check still passes with the same informational (not failing)
undeclared-subject list as before — this revision touches only the target/
state read caps, not the transition table or any directive marker, so no
drift was introduced.

### The before-landing hunt's reproduction, re-run against the fixed gate

Re-running `docs/reports/2026-08-05-hunt-target-declaration.md`'s
before-landing reproduction exactly (`WS=/tmp/ws-repro`, `item1` moving
`observed -> reproducing`, `target.md` padded to ~70KB with a first valid
block and a second `decoy` block past the 64KB cap) now refuses:

```
qa-cycle: refused — item item1: /tmp/ws-repro-verify/projects/myproj/target.md exceeds the 65536-byte cap this gate reads. An oversized declaration is an unadjudicable input; refusing rather than judging block structure from a truncated prefix.
```

Observed exit code: `2` (was `0`, "EXIT: 0", before this revision's fix — see
the hunt record's before-landing "Observed" section).

## Revised tally (revision 2)

| Run | Cases | Pass | Fail | Exit |
|---|---|---|---|---|
| `run-gate-tests.sh` (full suite, includes drift check) | 52 fixture cases + drift check | 52 | 0 | 0 |
| Hunt's before-landing reproduction, re-run | 1 | n/a | n/a | 2 (refuse, was 0) |
| Hunt reproduction, re-verifying -> reproducing, no target.md | 1 manual repro | — | — | 2 (refused, was 0) |
