---
status: approved
files:
  - qa-cycle/hooks/transition-gate.sh
  - qa-cycle/hooks/tests/directive-drift-check.sh
  - qa-cycle/hooks/tests/README.md
  - intake/hooks/directive.sh
  - testrun/hooks/directive.sh
  - bugreport/hooks/directive.sh
  - regress/hooks/directive.sh
  - stats/hooks/directive.sh
  - qa-cycle/hooks/directive.sh
  - signoff/hooks/directive.sh
---

# Mechanically check injected directives against the gate's enforced facts

## Intent

Give the repository a check that fails visibly when a `directive.sh` heredoc's prose diverges from what `transition-gate.sh` actually enforces, so the next gate edit surfaces stale directive prose as a build failure instead of waiting for a manually-dispatched warrant hunt. Three drifts have now been found this way: a missing `severity` precondition on `reproducing -> reproduced` (`docs/reports/2026-08-03-hunt-directive-severity-sync.md`), a wrong account of which of severity/priority is agent-set versus human-locked, and an unmentioned priority-token-minting path. None of these were transition-existence errors — every `(from, to, actor)` triple involved was and stayed correct in prose. All three lived one level below the transition: in the **preconditions** a transition requires, and in **field-level** rules (severity, priority) that sit beside the state machine but are not rows in it.

A first version of this proposal compared only transition existence — did a directive claim a row the table lacks, did a table row go unclaimed. `docs/reports/2026-08-04-hunt-directive-drift-check.md` found two fatal problems with that design: (1) by its own author's admission it would have caught none of the three drifts, since all three were precondition/field-level errors; (2) its completeness rule ("every actor-agent/human table row must be claimed by some directive") fails immediately against the current, believed-clean tree — the bootstrap `(none) -> observed` row, `parked-unreproducible -> observed`, and both `re-verifying` rows have no matching prose bullet anywhere today. A check that cannot catch the failures that already happened, and that is red on day one against a clean state, is not worth building. This rewrite lowers the comparison unit and fixes completeness so both problems are addressed.

## Constraints that change what gets built

- Refusal stays the gate's default. This unit adds a check; it changes no allow/refuse decision in `transition-gate.sh`'s Python.
- No enforcement behaviour changes as a side effect. The new check is a separate script the test harness runs, not a hook registered on any tool call — it cannot itself block a write.
- Directives stay readable prose. The per-claim marker described below is one line per bullet the agent already reads, in a comment-adjacent form; it must not turn a directive into a table or require restating the gate verbatim.
- The existing 38-case fixture harness (`run-gate-tests.sh` / `run-case`) is untouched — this check is a separate script, added as a final step, not folded into the fixture machinery.
- The check fails loudly (non-zero exit, naming the offending file and fact) rather than warning.

## What will be done

**Lower the comparison unit: enforced facts, not transition existence.** Per transition, the gate enforces more than "this pair is legal": it enforces *who* may trigger it and *what evidence must already be true*. Concretely, from reading `transition-gate.sh`:
- Every row has `(from, to, actor)` — already data, in `TABLE` (lines ~82–95).
- The row `reproducing -> reproduced` additionally requires a valid `severity:` (present, singular, in `SEVERITY_SET`) — currently enforced by code below `TABLE`, not in it.
- Every row with `actor: human` additionally requires a matching unconsumed verdict token bound to `(item id, from, to)` — also enforced by code below `TABLE`.
- `priority` is not a transition at all — it is a field. Changing it requires a matching unconsumed token bound to `(item id, "priority", new value)`, on every write, regardless of the item's state-machine transition. `severity` is the mirror case: field-set directly by the agent, closed-set, no token, no lock.

**Facts extracted, and how — the gate declares itself, restructured so the declaration cannot drift from the logic.** Today `TABLE` is a bare `(from, to, actor)` tuple list and the precondition logic lives separately as Python `if` statements the tuple list says nothing about. That gap is exactly what let precondition prose rot silently: nothing forces the fact "reproducing->reproduced needs severity" to live anywhere machine-readable. The fix restructures `TABLE` into the thing the gate's own decision logic consults for preconditions, not a second list beside it:

```python
TABLE = [
    {"from": "(none)", "to": "observed", "actor": "agent", "requires": []},
    {"from": "observed", "to": "reproducing", "actor": "agent", "requires": []},
    {"from": "reproducing", "to": "reproduced", "actor": "agent", "requires": ["severity"]},
    {"from": "reproducing", "to": "observed", "actor": "agent", "requires": []},
    {"from": "reproducing", "to": "parked-unreproducible", "actor": "agent", "requires": []},
    {"from": "parked-unreproducible", "to": "observed", "actor": "agent", "requires": []},
    {"from": "reproduced", "to": "handed-off", "actor": "human", "requires": ["token"]},
    {"from": "reproduced", "to": "not-a-defect", "actor": "human", "requires": ["token"]},
    {"from": "reproduced", "to": "wont-fix", "actor": "human", "requires": ["token"]},
    {"from": "handed-off", "to": "re-verifying", "actor": "human", "requires": ["token"]},
    {"from": "re-verifying", "to": "verified-fixed", "actor": "agent", "requires": []},
    {"from": "re-verifying", "to": "reproducing", "actor": "agent", "requires": []},
]
FIELDS = [
    {"field": "severity", "actor": "agent", "requires": ["closed-set:critical,major,minor,trivial"]},
    {"field": "priority", "actor": "human", "requires": ["token", "closed-set:now,next,later,someday"]},
]
```
`"token"` in `requires` means: the code path for that row/field must look up a verdict token before it reaches `allow()`; every place `TABLE`/`FIELDS` is read for a decision (the actor check, the severity check, the token check) reads these structures directly — the `human`-actor branch iterates `row["requires"]` rather than hard-coding "if actor == human, check token," so a row cannot end up enforced-as-human without also carrying `"token"` in its declared requirements, and vice versa. This is the load-bearing change from the previous draft: preconditions move from being logic the tuple list is silent about, to being data the tuple list states and the logic reads. Add `transition-gate.sh --dump-facts`, which prints `{"transitions": TABLE, "fields": FIELDS}` as JSON and exits 0, doing nothing else — no state file, no token, no `QA_WORKSPACE` needed.

Parsing the gate's Python from outside (regex over source) was rejected for the same reason as before: it can silently desync from the logic it claims to describe. Restructuring `TABLE`/`FIELDS` to be both the data the gate's own `if` statements branch on *and* the data `--dump-facts` prints closes that gap structurally rather than by discipline.

**What a directive must carry — a claim, not a copy.** Each bullet that already asserts a transition or field rule in prose gets one machine-findable marker line immediately after it, stating the same fact the prose asserts, in the same vocabulary as `--dump-facts`:
```
<!-- gate-claim: transition observed->reproducing actor=agent requires=none -->
<!-- gate-claim: transition reproducing->reproduced actor=agent requires=severity -->
<!-- gate-claim: field priority actor=human requires=token,closed-set -->
```
One line per bullet, HTML-comment invisible in rendered form, stating exactly the four things the check can compare: subject (transition or field), actor, and requirement set. It restates a fact the prose already asserts in words; it is not a parallel spec of *why*, and directives keep stating rationale, evidence artifacts, and workflow in full prose around it.

**Coverage declarations — what fixes completeness.** The prior draft's fatal flaw was requiring every table row to be claimed by someone, which is false today (four rows have no owning bullet at all). The fix: a directive does not implicitly promise to cover the whole table by existing — it says, once, near the top of its rules section, which subjects it takes responsibility for:
```
<!-- gate-covers: reproducing->reproduced, reproducing->observed, reproducing->parked-unreproducible, observed->reproducing -->
```
Completeness is then checked only against what is *declared*, not against the full table: for every subject in a directive's `gate-covers` list, exactly one matching `gate-claim` marker with correct facts must exist; a declared-but-unclaimed subject fails. A table row nobody declares is not a failure — it is printed as an informational "undeclared" line in the check's output, a deliberate, visible fact about today's coverage rather than an instant red build. This is the mechanism the reader should extend if bootstrap/`parked-unreproducible->observed`/`re-verifying` rows are ever meant to be someone's declared responsibility; until then, this proposal does not force prose to be written just to satisfy the checker.

**What counts as divergence, concretely, now:**
1. A `gate-claim` names a subject `--dump-facts` does not have, or names one with a different actor or requirement set than declared. Hard failure, naming file, subject, and the mismatch.
2. A subject in a directive's own `gate-covers` list has no matching `gate-claim`. Hard failure — a directive said it owns this and then didn't state it.
3. A table/field subject appears in no directive's `gate-covers` at all. Reported, not failed.

**Where it runs.** `qa-cycle/hooks/tests/directive-drift-check.sh`, callable directly and invoked as a final step of `run-gate-tests.sh`, exactly as before: runs `transition-gate.sh --dump-facts`, extracts `gate-covers` and `gate-claim` markers from all seven `directive.sh` files by plain grep (no prose interpretation), computes the three checks above, and exits 1 with named specifics on any hard failure.

## Would it have caught the three drifts?

- **Missing `severity` precondition on `reproducing -> reproduced` (testrun).** Caught, going forward. `reproducing->reproduced` is in `TABLE` with `requires: ["severity"]`; if `testrun`'s `gate-covers` includes that subject (it must, since it owns the row) and its `gate-claim` omits `requires=severity` or states `requires=none`, that is a fact mismatch against `--dump-facts` — divergence case 1, hard failure. This is exactly the class of error already found.
- **Severity/priority setter-symmetry error (bugreport implying priority is merely "recorded").** Caught. `priority` is now a declared `FIELDS` subject with `actor=human, requires=token,closed-set`. If `bugreport`'s field-level claim for `priority` states `actor=agent` or drops `requires=token`, that mismatches `--dump-facts` directly — this was previously invisible because priority was not a state-machine row at all and so structurally outside the old check's transition-triple comparison; making fields first-class subjects is what closes this.
- **Signoff never mentioning that `capture-verdict.sh` also mints priority tokens.** Caught only if `signoff` declares `priority` in its own `gate-covers` (it should — minting the priority token is a fact signoff's directive states). If it declares coverage and the claim is silently dropped, that is divergence case 2 (declared-but-unclaimed), a hard failure. If a future edit removes `priority` from `signoff`'s `gate-covers` *and* deletes the claim in the same stroke, the check degrades to divergence case 3 (reported, not failed) — a directive can always opt out of a coverage promise it once made, and this check cannot force a directive to keep declaring something it stops declaring. That residual gap is named here rather than glossed over: this check catches silent claim/fact drift under an existing coverage promise; it does not catch a directive quietly renouncing a promise it used to make. Two of three drifts are caught outright; the third is caught in the shape it actually occurred (a stale claim under a standing coverage declaration) and named as gapped in the adjacent case (a withdrawn declaration).

## What is deliberately out of scope

- This check compares structured claims (`gate-claim`, `gate-covers`) against declared enforcement (`--dump-facts`). It cannot judge whether a directive's surrounding prose is good advice, correctly explains *why* a precondition exists, or is otherwise well-written — a green check is not a correctness claim about directive quality.
- It cannot catch a directive that quietly stops declaring coverage of something it used to own (see the signoff case above) — that is an ownership *withdrawal*, not a claim/fact mismatch, and requires the same kind of human judgment as an ownership *dispute* between two directives, which this check also does not adjudicate.
- The earlier transition-existence-only design (comparing `(from, to, actor)` triples with a "every table row must be claimed" completeness rule) was considered and rejected: it demonstrably would have caught none of the three drifts this repository actually suffered, since all three were precondition/field-level, not transition-existence errors, and its completeness rule fails on day one against the current clean tree (the bootstrap, `parked-unreproducible -> observed`, and both `re-verifying` rows have no owning prose today). Do not re-propose that shape without first solving both problems it could not solve.

## How you will know it worked

- `transition-gate.sh --dump-facts` runs standalone (no `QA_WORKSPACE`, no stdin) and prints `TABLE`/`FIELDS` as JSON, sourced from the same structures the gate's decision logic branches on.
- `directive-drift-check.sh` run against the current, unmodified tree exits 0 — no directive's existing claims mismatch `--dump-facts`, and undeclared table rows are printed as informational lines, not failures.
- Three regression fixtures, one per drift already found, each demonstrating the check now fails when the drift is reintroduced:
  - reintroducing testrun's missing-severity bug (deleting `requires=severity` from its `gate-claim` for `reproducing->reproduced`, or from the prose+marker pair) makes the check exit 1 naming that subject and the mismatch.
  - reintroducing bugreport's setter-symmetry bug (changing its `priority` field claim to `actor=agent` or dropping `requires=token`) makes the check exit 1 naming `field priority`.
  - removing signoff's `priority` `gate-claim` while its `gate-covers` still lists `priority` makes the check exit 1 as declared-but-unclaimed; removing it from both simultaneously is confirmed, by hand during review, to degrade to an informational line rather than a failure — this is the named residual gap, not a silent one.
- `run-gate-tests.sh`'s existing 38 fixture cases still pass, byte-for-byte unchanged, and its tally step now additionally reflects the drift check's exit code.

## What did not work

- No directive prose was found to be wrong against the landed gate during this build. All seven directives' existing bullets about transitions, severity, and priority already matched what `transition-gate.sh` enforces (severity/priority setter-symmetry was already fixed by the prior `2026-08-03-directive-severity-sync` proposal). Markers restate what the prose already says; no fourth drift was found or silently patched.
- First draft of the drift-check's `gate-claim` `requires=` comparison intended to compare the gate's `FIELDS` requirements verbatim (e.g. `requires=closed-set:critical,major,minor,trivial`), which would have forced every directive claiming `severity`/`priority` to restate the full closed-set contents in the marker — a second list mirroring the real one, the exact drift this unit exists to prevent. Fixed by normalizing both sides to the token before `:` (`closed-set`), so the marker states the FACT of a closed set without re-enumerating it; the enumeration itself is compared nowhere but inside the gate.
- The `--dump-facts` flag was initially sketched as a second, standalone Python heredoc appended to the bash script (its own `TABLE`/`FIELDS` copy) so it could run before `QA_WORKSPACE` is required. Rejected immediately on the same second-list-drift reasoning as above: two heredocs would mean two `TABLE`s to keep in sync by hand. Landed instead as an early-exit branch inside the single existing heredoc, gated on `QA_CYCLE_DUMP_FACTS`, reading the same `TABLE`/`FIELDS` objects the decision logic below it reads — the bash wrapper only decides whether to require `QA_WORKSPACE`/stdin, never which facts to print.
