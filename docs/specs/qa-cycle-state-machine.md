---
date: 2026-07-30
proposal: docs/proposals/2026-07-30-item-axis-state-machine.md
issue: "#10"
supersedes: docs/specs/qa-cycle-state-machine.md (2026-07-26 revision, proposal docs/proposals/2026-07-26-qa-cycle-state-machine.md)
---

# QA Item State Machine

## Grounding

The prior revision of this spec tracked one `phase` per project. That axis does not fit the QA agent's actual product: the QA agent never writes code, never observes the coding agent's internal state, and its unit of output is one feedback item — one observation that may or may not turn out to be a defect worth handing to a separate coding agent — not the project as a whole. This revision re-keys the state machine onto that item. See [docs/proposals/2026-07-30-item-axis-state-machine.md](../proposals/2026-07-30-item-axis-state-machine.md) and issue #10.

## States

- `(none)` — pre-existence marker: no record of this item id exists yet. Not a state any item record ever carries; it appears only as the `From` of the bootstrap transition below.
- `observed` — an observation exists; not yet reproduced.
- `reproducing` — an attempt to reproduce it is underway.
- `reproduced` — reproduced with a recorded procedure; awaiting the human's is-this-a-defect verdict.
- `handed-off` — the human declared it a defect AND handed it to the coding agent. Opaque interval: no transition out without a human trigger.
- `re-verifying` — the human said a fix landed; the recorded reproduction procedure is being re-run against it.
- `verified-fixed` — terminal. Re-verification passed.
- `not-a-defect` — terminal. The human declined to call it a defect.
- `parked-unreproducible` — terminal-but-revivable. Reproduction failed or information was insufficient. A new observation re-enters it to `observed`.
- `wont-fix` — terminal. Accepted as a defect, deliberately not being fixed.

## Transition table

| From | To | Trigger | Required evidence | Actor |
|---|---|---|---|---|
| `(none)` | `observed` | agent creates the first record of a new item | the observation text | agent |
| `observed` | `reproducing` | agent begins reproduction | the observation text, plus a target declaration | agent |
| `reproducing` | `reproduced` | reproduction succeeded | the reproduction procedure, recorded on the item | agent |
| `reproducing` | `observed` | information insufficient to attempt | what was missing | agent |
| `reproducing` | `parked-unreproducible` | reproduction attempted and failed | what was tried and how it failed | agent |
| `parked-unreproducible` | `observed` | a new observation arrives for the same item | the new observation text | agent |
| `reproduced` | `handed-off` | human declares it a defect and hands it over | verdict token + the reproduction procedure | human |
| `reproduced` | `not-a-defect` | human declines to call it a defect | verdict token | human |
| `reproduced` | `wont-fix` | human accepts it as a defect but declines a fix | verdict token | human |
| `handed-off` | `re-verifying` | human says a fix landed | verdict token + the item's recorded reproduction procedure | human |
| `re-verifying` | `verified-fixed` | re-run of the recorded procedure no longer shows the problem | the re-run result | agent |
| `re-verifying` | `reproducing` | re-run still shows the problem | the re-run result, plus a target declaration | agent |

This table has 12 rows and is exhaustive: no other transition is legal. `(none)` is not a state an item ever records — it is the pre-existence marker for "this item id has no prior block" and only ever appears as a `From`. The graph is non-linear by design — `reproducing → observed`, `reproducing → parked-unreproducible`, `parked-unreproducible → observed`, and `re-verifying → reproducing` are backward edges, and they are normal transitions, not error paths.

## Human decision points

Item creation is NOT human-locked: an agent brings a new feedback item into existence unaided, writing the first record itself on `(none) → observed` with no human trigger required. Human-locked transitions are exactly the four rows marked `Actor: human` above:

- **`reproduced → handed-off`** — is this a genuine defect, and is it now being handed to the coding agent. Evidence: a verdict token bound to this item and this transition, plus the reproduction procedure the coding agent will work from.
- **`reproduced → not-a-defect`** — the human declines to call the observation a defect. Evidence: a verdict token bound to this item and this transition.
- **`reproduced → wont-fix`** — the human accepts it as a defect but deliberately declines a fix. Evidence: a verdict token bound to this item and this transition.
- **`handed-off → re-verifying`** — the human asserts a fix has landed in the target project. Evidence: a verdict token bound to this item and this transition, plus the item's recorded reproduction procedure (without it, `re-verifying` cannot be entered — there is nothing to re-run).

Each verdict token is single-use and binds to BOTH a specific item id AND a specific (from, to) pair, so a token minted for one item, or for one transition on an item, can never be replayed against another item or another transition. Tokens are minted only from the user's own turn — never inferred from a file, an issue, a PR, a comment, or any tool output.

While an item sits in `handed-off`, the coding agent's progress is invisible to this system by design — nothing observes it. Only the `handed-off → re-verifying` human trigger moves the item out.

## Severity and priority

Two additional fields live on the item record, alongside state, reproduction,
and evidence. Both are closed-set enums; neither participates in the
transition table's states or rows — they are properties an item carries
while it moves through the table, not axes of the table itself. See
[docs/proposals/2026-08-02-severity-priority-axes.md](../proposals/2026-08-02-severity-priority-axes.md)
and issue #16.

- **`severity`** — one of `critical`, `major`, `minor`, `trivial`. **Actor:
  agent.** Severity is what was observed (crash/data-loss vs. cosmetic), the
  same kind of judgment the agent already exercises recording the
  reproduction procedure. It is set or revised as part of the
  `reproducing -> reproduced` transition's evidence.
  **Precondition, stated explicitly:** an item cannot enter `reproduced`
  without a valid `severity` already present in the attempted write — the
  gate refuses `reproducing -> reproduced` whenever `severity` is absent,
  empty, outside the closed set, or declared more than once in the item's
  block (exactly one `severity:` line is required; zero or multiple both
  mean "no severity," which refuses). No other transition requires
  `severity`.
- **`priority`** — one of `now`, `next`, `later`, `someday`. **Actor:
  human.** Priority ranks an item against other items and schedule, a
  decision distinct from whether it is a genuine defect. It is NOT required
  for `handed-off` or any other transition — an item may sit without a
  priority indefinitely. Because it is human-set, any write that changes an
  item's recorded `priority` value requires a priority verdict token bound
  to `(item id, field name, new value)`, minted only by
  `signoff/hooks/capture-verdict.sh` from the user's own turn, per the same
  discipline as the four human-locked state transitions above. This token
  is distinct from the state-transition token and does not gate any row in
  the transition table above — it gates the `priority` field itself,
  independently of what transition (if any) the same write also attempts.

## Target declaration

The QA cycle exercises an already-running target that the user starts,
deploys, and stops — the rulebook never manages it, and that stays out of
scope permanently. But without a recorded declaration of what the target
actually is, nothing checks a reproduction was run against the target the
user meant. See
[docs/proposals/2026-08-05-target-declaration.md](../proposals/2026-08-05-target-declaration.md)
and issue #22.

**Precondition, stated explicitly:** an item cannot enter `reproducing`
without a valid target declaration already on disk for the project. This
attaches to `reproducing` as a DESTINATION STATE, not to a single row: every
row in the transition table above whose `To` is `reproducing` carries it —
today that is both `observed -> reproducing` and `re-verifying ->
reproducing`. The gate refuses either transition whenever
`<QA_WORKSPACE>/projects/<owner>-<repo>/target.md` is absent, unreadable,
malformed, or missing a required field (a single non-empty `label` and a
single non-empty `entry_point`), and whenever the attempted write's own
run-record evidence does not reference the declared target (by label or
entry point). This reuses the same `requires` mechanism `severity` already
uses on `reproducing -> reproduced` — a `requires` entry on each row in
`transition-gate.sh`'s `TABLE` whose `to` is `reproducing`, not a second,
bespoke enforcement path and not a per-row special case a future row into
`reproducing` could silently miss: any further row landing an item in
`reproducing` gets the same `requires: ["target"]` treatment.

- **Actor: agent, content-gated, not token-locked.** `target.md` is
  agent-writable — the gate holds the transition to the declaration's
  *content*, not to who authored the write, the same split `intake.md`
  already uses (agent-discoverable, not human-locked, no verdict token).
  The target is a fact to be recorded once at the start of QA work, not a
  subjective judgment call like `priority`.
- **Path:** `<QA_WORKSPACE>/projects/<owner>-<repo>/target.md`, sibling to
  that project's `state.md` and `intake.md`, under the same workspace root
  `transition-gate.sh` already resolves and prefix-checks. Path resolution
  reuses the same `PROJECT_ID_RE` allow-list and independent
  resolve-then-contain check already applied to `state_path`/`tokens_dir`.
- **Shape:** a single frontmatter-shaped block —
  `label`, `entry_point`, `env_names` (names only, never values, per the
  rule `intake.md` and `state.md` already follow).

## Persisted item state

All state lives under `$QA_WORKSPACE/projects/<owner>-<repo>/` (default workspace root `~/qa-workspace` if `$QA_WORKSPACE` is unset), never in the target repo, and never as a copy of target code. Per the existing plugins' policy: env vars are recorded by name only, never by value.

- Each feedback item's record carries, at minimum: item id, current state, the reproduction procedure once recorded (this is what makes `re-verifying` reachable at all — without it the state is unreachable in practice), the evidence for the most recent transition, `severity` (agent-set, required to reach `reproduced`, see "Severity and priority" above), and `priority` (human-set, optional, token-gated when changed). It carries no bug report body and no target-project code; those live in the target project's own tracker.
- `intake.md` — a reader can reconstruct: tracker repo, issue template path, labels, app launch/stop/ready commands, test framework and directory, env var names (unset values), and report language. Every item record reads this profile.
- `runs/<YYYY-MM-DD>-<slug>.md` — the session record a `reproducing`/`reproduced` attempt is logged against; carries the app version/commit under test and the evidence pointers items cite.
- `evidence/<item-id>/` — holds the screenshots/log excerpts a reproduction procedure references; a reader can reconstruct what was actually observed, not just the verdict.
- Filed defects themselves live in the **target project's own tracker**, not in qa-workspace — the `handed-off` transition's evidence points at whatever the target project uses to track the handoff (e.g. an issue URL), but the qa-workspace item record never duplicates the defect's body or code.

## Ownership map

| Transition | Owning plugin today |
|---|---|
| `observed → reproducing` | `testrun` |
| `reproducing → reproduced` | `testrun` |
| `reproducing → observed` | `testrun` |
| `reproducing → parked-unreproducible` | `testrun` |
| `parked-unreproducible → observed` | `intake`/`testrun` (whichever surfaces the new observation) |
| `reproduced → handed-off` | `bugreport` (composes and requests; human via `signoff` mints the token) |
| `reproduced → not-a-defect` | `bugreport` (requests; human via `signoff` mints the token) |
| `reproduced → wont-fix` | `bugreport` (requests; human via `signoff` mints the token) |
| `handed-off → re-verifying` | `signoff` (human trigger) |
| `re-verifying → verified-fixed` | `regress`/`testrun` (re-run) |
| `re-verifying → reproducing` | `regress`/`testrun` (re-run) |
| `stats` | reads item records across all states; owns no transition |
| gate authority over every write above | `qa-cycle` |

Note: `qa-cycle/hooks/transition-gate.sh` and `signoff/hooks/capture-verdict.sh` are **not yet updated** to this item axis — they still enforce the prior per-project phase vocabulary (see [docs/decisions/2026-07-30-item-axis-over-project-phase.md](../decisions/2026-07-30-item-axis-over-project-phase.md) and the proposal's out-of-scope section). Until a follow-up unit updates them, directive prose and gate/token logic speak different vocabularies; the gate remains the sole writer of state and sole authority on legality regardless of which vocabulary its table is keyed on.

## Open questions

- Whether an item's identity persists across `parked-unreproducible → observed` re-entry (same item id, new observation appended) versus spawning a new item that references the parked one — this revision assumes same item id (re-entry, not a new item) but does not settle how the record represents "which observation is current" when several have accumulated.
- Whether `wont-fix` and `not-a-defect` need distinguishable downstream handling by `stats` (a won't-fix is a defect, a not-a-defect is not) — this revision keeps them as separate terminal states so the distinction is at least representable, but does not specify a stats report format.
- How `re-verifying → reproducing` interacts with a coding agent that has already moved on to other work — this revision only requires the re-run result as evidence; it does not model whether the item automatically re-enters `handed-off`-bound territory or waits for a fresh human hand-off.
- The severity/priority questions from the prior revision are now settled by [docs/proposals/2026-08-02-severity-priority-axes.md](../proposals/2026-08-02-severity-priority-axes.md) — see "Severity and priority" above.
- Whether the gate/token code update (transition-gate.sh, capture-verdict.sh) should be a single follow-up unit or split by concern — left open for that follow-up's own scoping.

Note: the human-gate-vs-pipeline-gate dispute is not reopened here — it remains settled by [docs/decisions/2026-07-26-human-gate-over-pipeline-gate.md](../decisions/2026-07-26-human-gate-over-pipeline-gate.md).
