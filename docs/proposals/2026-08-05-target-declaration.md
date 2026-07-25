---
status: approved
files:
  - docs/specs/qa-cycle-state-machine.md
  - qa-cycle/hooks/transition-gate.sh
  - testrun/hooks/directive.sh
  - docs/handbooks/qa-cycle.md
  - qa-cycle/hooks/tests/run-gate-tests.sh
  - qa-cycle/hooks/tests/directive-drift-check.sh
---

## Intent

The QA cycle exercises an already-running target that the user starts and owns — the rulebook never starts, deploys, or manages it, and that stays out of scope permanently. But the target is never *declared* anywhere. `testrun/hooks/directive.sh` already requires "app is up" as evidence for `observed -> reproducing`, and `qa-cycle`'s gate lets that transition through, yet nothing records what the target actually is, so nothing checks a reproduction was run against the target the user meant. This proposal adds that declaration and wires the gate to require it.

## Constraints

- No secret VALUE is ever written to the declaration or any state file — environment variable NAMES only, matching the rule `intake.md` and `state.md` already follow.
- The declaration path is built from a runtime project id, so it gets the same two-part treatment every other gate-checked path gets: allow-list validation of the id, then independent resolve-then-contain prefix checking against the workspace root.
- A new precondition on an existing transition table row is a spec-level design change, not a code-only change — it must land in `docs/specs/qa-cycle-state-machine.md` before the gate enforces it.
- The `requires` mechanism already exists (`severity` on `reproducing -> reproduced`); this reuses it rather than inventing a second enforcement path.
- `testrun/hooks/directive.sh`'s `gate-covers`/`gate-claim` markers for `observed -> reproducing` must stay in sync with whatever the gate actually enforces, or `directive-drift-check.sh` fails by design.

## What will be done

1. **Where it lives.** One file per project: `<QA_WORKSPACE>/projects/<owner>-<repo>/target.md`, sibling to that project's existing `state.md` and `intake.md`, under the same workspace root `transition-gate.sh` already resolves and prefix-checks.

2. **What it contains.** A single frontmatter-shaped block:
   ```yaml
   ---
   label:            # human label for the target, e.g. "staging"
   entry_point:      # base URL or launch command
   env_names:        # names only, comma- or line-separated; never values
   ---
   ```

3. **Who writes it.** Agent-writable; the gate holds transitions to the declaration's *content*, not to who authored the write — the same split `intake.md` already uses (agent-discoverable, not human-locked, no verdict token). Justification: the target is a fact to be recorded once at the start of QA work, not a subjective judgment call like `priority`; adding a second token type here would duplicate machinery the gate doesn't need, since requiring the file to exist with a valid, non-empty `entry_point` already anchors every later reproduction to it. If the user needs to correct a wrong declaration, they say so and the agent rewrites the file — the same discipline `intake.md` already follows.

4. **What the gate enforces.** Add `"target"` to the `requires` list on the `observed -> reproducing` row (currently `[]`) in `qa-cycle/hooks/transition-gate.sh`'s `TABLE`, exactly the way `severity` already gates `reproducing -> reproduced`. When present, the gate refuses `observed -> reproducing` unless: `target.md` exists for the project, resolves and stays contained under the workspace root, and parses to exactly one non-empty `entry_point` and one non-empty `label`; and the attempted `state.md` write's run-record evidence references the declared target (e.g. by label or entry point appearing in the write). Path resolution for `target.md` reuses the same `PROJECT_ID_RE` allow-list and resolve-then-contain check already applied to `state_path`/`tokens_dir`.

5. **Spec update.** `docs/specs/qa-cycle-state-machine.md`'s transition table row for `observed -> reproducing` gets "target declaration" added to its "Required evidence" cell, with a short new subsection (parallel to "Severity and priority") stating the precondition, its actor (agent-set, no token), and pointing at this proposal and issue #22.

6. **Directive sync.** `testrun/hooks/directive.sh`'s `observed -> reproducing` bullet and its `<!-- gate-claim: transition observed->reproducing actor=agent requires=none -->` marker are updated to `requires=target`, and the prose gains one line: if `projects/<slug>/target.md` doesn't exist yet, the agent writes it (label + entry point + env var names, no values) before attempting the transition.

7. **Handbook update.** `docs/handbooks/qa-cycle.md` gets a new subsection describing `target.md`'s path, shape, the "names only, never values" rule, and its id/path-validation treatment — the same treatment already documented for `state.md` and the token files.

8. **Test harness.** `qa-cycle/hooks/tests/run-gate-tests.sh` gets new fixture cases: `observed -> reproducing` refused when `target.md` is absent, refused when present but malformed (missing/empty `entry_point`), and allowed when present and valid and referenced. `qa-cycle/hooks/tests/directive-drift-check.sh` needs no logic change (it already reads `TABLE`/`FIELDS` generically via `--dump-facts`), but is included in the write set because the updated marker in `testrun/hooks/directive.sh` must be run through it to confirm no drift.

## Out of scope

Starting, deploying, stopping, or otherwise managing the target — the user owns that permanently. Any new verdict-token type. Multi-target-per-project support. Editing the declaration's content-validation rules beyond "non-empty label and entry point, names-only env vars." Any decision record, spec edit, or report beyond what's listed above — those are the build's output.

## How I will know it worked

`observed -> reproducing` is refused for a project with no `target.md`, refused for a malformed one, and allowed once a valid declaration exists and the run-record evidence names it. `directive-drift-check.sh` passes with the updated marker. A reader of any item's run-record can, without opening a second file, follow to `target.md` and see exactly what the reproduction ran against.

## What did not work

- No edit made during this build was written and then reverted — the first full `run-gate-tests.sh` run after implementation passed all 47 cases with no fixup cycle.
- The one place expectation nearly diverged from reality: Case 1 (`valid-table-permitted-transition`, the harness's oldest fixture) exercises `observed -> reproducing` with no target declared at all — which the new precondition now refuses. Caught before running the harness, by re-reading the fixture against the new `requires` row, rather than assuming "keep every existing case" meant "touch nothing in existing fixtures." Its setup was extended with a valid `target.md` and evidence referencing it so the case still tests what it always meant to test (a legal transition is allowed), instead of failing for a reason unrelated to what it was written to check.
- A pre-existing hunt finding in this tree (`docs/reports/2026-08-05-hunt-target-declaration.md`) flags that `re-verifying -> reproducing` — a second row that also lands an item in `reproducing` — carries no `target` precondition and is unaffected by this build. The proposal's item 4 and write set name only the `observed -> reproducing` row, so extending the precondition there was left out rather than widening the frozen scope; see `docs/reports/2026-08-05-target-declaration-run.md` "Known gap outside this build's frozen scope."
- Attaching the precondition to a single row (`observed -> reproducing`) rather than to `reproducing` as a destination state left a second entry into `reproducing` unguarded: this expectation did not hold and was corrected in the revision recorded in `docs/reports/2026-08-05-target-declaration-run.md` ("Revision — closing the `re-verifying -> reproducing` gap").
