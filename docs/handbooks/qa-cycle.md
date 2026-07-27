# QA cycle enforcement handbook

This handbook documents the runtime layer that makes the QA cycle binding:
the per-item state file, the single-use verdict token, the kill switches,
qa's record area in the target repo, and the gate's refusal behavior. The transition table itself
— which item state can move to which, on what trigger, with what evidence,
by which actor — is not restated here; it lives in
[`docs/specs/qa-cycle-state-machine.md`](../specs/qa-cycle-state-machine.md)
and that document is the sole authority on it.

Enforcement is keyed on the **item axis**: `state.md` no longer carries a
single project-wide `phase`. It carries one record per feedback item.

## The state file

Path: `docs/reports/records/<subject>/qa/state.md`, in the target repo
itself.

One file per subject, owned exclusively by the `qa-cycle` plugin — no other
plugin writes it. It is a chain of independent, `---`-delimited blocks, one
per feedback item, each its own frontmatter-shaped document:

```yaml
---
item:             # stable id for this feedback item, unique within the subject
state:            # current item state, exactly one name from the spec's States section
reproduction:     # the reproduction procedure, once recorded (empty until then)
evidence:         # relative path(s) under qa/ proving the most recent transition
transition:       # the transition just taken, written `from -> to`
severity:         # one of critical, major, minor, trivial. Agent-set. See below.
priority:         # one of now, next, later, someday. Human-set, optional. See below.
---
```

### `severity` and `priority`

Two fields added by
[docs/proposals/2026-08-02-severity-priority-axes.md](../proposals/2026-08-02-severity-priority-axes.md)
(issue #16); the full contract lives in
[`docs/specs/qa-cycle-state-machine.md`](../specs/qa-cycle-state-machine.md)
"Severity and priority" — this section covers only how the runtime layer
enforces and surfaces them.

- **`severity`** — closed set `{critical, major, minor, trivial}`,
  agent-set. Required to reach `reproduced`: the gate refuses
  `reproducing -> reproduced` unless the attempted write's item block
  carries exactly one `severity:` line whose value is in the closed set.
  Zero lines, more than one line, an empty value, or a value outside the
  set are all treated the same way — "no severity" — and all refuse. No
  other transition requires it, and no token is involved; severity needs
  no human verdict, only the agent's own judgment recorded alongside the
  reproduction procedure.
- **`priority`** — closed set `{now, next, later, someday}`, human-set.
  NOT required for `handed-off` or any other transition — an item may sit
  without a priority indefinitely, and this is a legal, unlocked state,
  not an omission the gate flags.

#### The priority verdict token

Any write that changes an item's recorded `priority` value (including
setting it for the first time) is checked by `transition-gate.sh`
independently of, and in addition to, whatever state-transition check the
same write may also be attempting. It requires a matching, unconsumed
priority token:

- **Path:** `docs/reports/records/<subject>/qa/tokens/<item-id>.priority.token`
  — a distinct file from `<item-id>.token` (the state-transition token), so
  neither can be consumed by the other's check.
- **Minted by:** `signoff/hooks/capture-verdict.sh`, from the user's own
  turn only — never inferred from a file, an issue, a PR, a comment, or a
  tool result. The turn must name the item explicitly (`item <id>`, the
  same discipline as state-transition verdicts) and an explicit `priority`
  keyword followed by one of the closed-set values (e.g. `item BUG-1
  priority now`). Before minting anything, the hook runs the same
  credential/secret/internal-URL scan over the load-bearing phrase that it
  already runs before minting a state-transition token — a phrase that
  looks credential-, key-, or internal-URL-shaped mints no token, for
  either kind.
- **Shape:**
  ```yaml
  item:             # the item id this token authorizes
  field: priority
  value:            # the exact priority value this token authorizes
  phrase:           # the verbatim NON-SENSITIVE phrase from the user's own turn
  ```
- **Bound to:** `(item id, field name, new value)` — not `(item id, field
  name)` alone. A token authorizes setting `priority` to exactly the value
  the human named; it does not authorize any other value, even for the
  same item.
- **Lifetime:** single-use, consumed under the same reserve-then-finalize
  `.consuming` ordering as the state-transition token (moved to
  `<item-id>.priority.consuming` on allow, finalized/deleted once the
  write actually lands, and available to re-authorize an identical retry
  if the permitted write fails or is aborted before landing). Re-mintable:
  each priority change needs its own freshly minted token — single-use
  consumption does not prevent priority from being revised repeatedly over
  an item's life, it only means each revision needs its own fresh human
  verdict.
- **`priority-set-by: human` marker:** the gate may still write this line
  into `state.md`'s item block when it allows a priority change, as a
  human-readable provenance note for anyone reading the file later. It is
  **descriptive only** — it plays no part in the allow/refuse decision,
  which depends solely on presence and consumption of the matching
  `(item id, field, value)` token. A write carrying this marker with no
  matching token present is refused exactly as if the marker were absent;
  see
  [`docs/reports/2026-08-02-hunt-severity-priority-axes.md`](../reports/2026-08-02-hunt-severity-priority-axes.md)
  for the reproduction that made this explicit, and
  [`docs/decisions/2026-08-02-priority-token-over-marker.md`](../decisions/2026-08-02-priority-token-over-marker.md)
  for why the marker alone was rejected as the lock.

#### `report-phase.sh`'s session-start report

The session-start report now groups items primarily by `priority` (`now`,
`next`, `later`, `someday`, in that order), then by `severity` within each
priority group (`critical`, `major`, `minor`, `trivial`, in that order), so
the first thing a human sees is what to look at first. Items carrying no
priority at all are surfaced in their own leading `(no priority)` group —
not hidden — since lacking a priority is a legal, unlocked item state, not
an error.

This encoding was chosen over one project-wide YAML document with a nested
list because it is append-friendly: recording a new item, or updating one
item's block, never requires rewriting or reparsing every other item's
block, and a reader (human or grep) can find one item's current record by
searching for its `item:` line without parsing YAML at all.

Each block is recognized only when it opens with a `---` line at the start
of a line and closes with a later `---` line — never a bare `item:`/`state:`
pair floating outside a block. A block that does not declare exactly one
non-empty `item:` and exactly one non-empty `state:` is ambiguous and
contributes no state for that item; if it is the item a write is attempting
to transition, the gate refuses.

It never holds a secret value (environment variable names only, the same
rule `intake.md` already follows) and never holds a copy of target-project
code or a bug report body — bug reports go to the target project's own
tracker via `bugreport`, and only the resulting issue URL is ever referenced
from qa's own record files, as the `evidence:` field of the `handed-off`
transition.

A single write (`Write` or `Edit` call touching `state.md`) may change
exactly one item's recorded state. A write that leaves every item's state
unchanged, or that changes more than one item's state at once, is refused
as having no transition (or an ambiguous one) for the gate to authorize —
each transition is its own write.

## The target declaration

Path: `docs/reports/records/<subject>/qa/target.md`, sibling to that
subject's `state.md` and `intake.md`. The full contract — precondition,
actor, path validation — lives in
[`docs/specs/qa-cycle-state-machine.md`](../specs/qa-cycle-state-machine.md)
"Target declaration"; this section covers only the file's shape and what
breaks without it.

```yaml
---
label:            # human label for the target, e.g. "staging"
entry_point:      # base URL or launch command
env_names:        # names only, comma- or line-separated; never values
---
```

Agent-writable, content-gated, not token-locked — the gate checks what the
file says, not who wrote it. If it doesn't exist yet when an item is about
to move `observed -> reproducing`, the agent writes it (label, entry point,
env var names — never values) before attempting the transition. If the
user needs to correct a wrong declaration, they say so and the agent
rewrites the file, the same discipline `intake.md` already follows.

Without a valid declaration, `observed -> reproducing` refuses outright:
absent, unreadable, or malformed `target.md` (missing or empty `label` or
`entry_point`) all refuse, as does a write whose own run-record evidence
does not reference the declared target by label or entry point. No secret
value is ever written here — environment variable names only, the same
rule `state.md` and `intake.md` already follow.

## Item id and subject shape

`transition-gate.sh` reads an item id out of untrusted input — the `item:`
field of a write's proposed `state.md` content — and uses it to build
filesystem paths (the token file, the consuming marker). `signoff`'s
verdict-capture hook reads an item id the same way out of the prompt text
of a human turn. An unvalidated value here is a path-traversal escape: see
[`docs/reports/2026-07-31-hunt-item-axis-enforcement.md`](../reports/2026-07-31-hunt-item-axis-enforcement.md)
for the reproduction where an item id of
`../../../../../../../../tmp/evil-item` made the gate accept a verdict
token the agent forged itself, at a path of its own choosing, bypassing
`capture-verdict.sh` entirely.

The subject itself is not a separately-typed value the way the item id is:
it is read directly off the write's own `file_path` (the path component
between `docs/reports/records/` and `/qa/...`), which has already been
resolved to its real, absolute path and prefix-checked against
`docs/reports/records/` before that component is ever extracted — a
traversing subject segment (`..`) is collapsed away by that resolution
before it could name anything, and a value that survives resolution is
already contained.

The gate applies two independent checks to the item id, in this order,
before it is used in any path or any comparison:

1. **Allow-list.** An item id is ASCII letters, digits, hyphen, and
   underscore only, length 1..64, and may not begin with a hyphen.
   Anything outside this shape is not a valid id — it is rejected by
   pattern, never repaired or stripped down to something that fits.
2. **Resolve, then contain.** Independently of the allow-list, every path
   built from the item id (the token file, the consuming marker) is
   resolved to its real, absolute path and prefix-checked against the
   item's `tokens/` directory before it is opened. The check runs after
   resolution, never before: a containment check against an unresolved
   path proves nothing.

Either check failing is a refusal: `transition-gate.sh` exits 2 without
echoing the offending value into its message; `capture-verdict.sh` (which
never blocks, per its own design) mints no token and exits 0. Neither hook
falls through to an allow/mint path on an invalid id.

## The verdict token

Path: `docs/reports/records/<subject>/qa/tokens/<item-id>.token`, one
file per item with a live, unconsumed token.

Minted only by `signoff`'s verdict-capture hook, from the user's own turn —
never inferred from a file, an issue, a PR, a comment, or a tool result. The
user's turn must name the item explicitly (`item <id>`); the hook does not
guess which item a bare verdict concerns. YAML shape:

```yaml
item:             # the item id this token authorizes
transition:       # the single transition this token authorizes, `from -> to`
phrase:           # the verbatim NON-SENSITIVE phrase from the user's own turn constituting the verdict
```

A token authorizes exactly one transition on exactly one item — never a
class of transitions, and never a class of items. A token whose `item` or
`transition` field does not match the write actually being attempted is
treated as absent, the same as no token existing at all. Vague assent from
the user produces no token.

### Consumption is reserve-then-finalize, not delete-on-allow

A token is single-use, but "single-use" is enforced across two steps rather
than one delete-on-allow step, to close the token-consumption-timing defect
recorded in
[`docs/reports/2026-07-29-hunt-gate-execution-check.md`](../reports/2026-07-29-hunt-gate-execution-check.md).
See
[`docs/decisions/2026-07-31-token-consumption-ordering.md`](../decisions/2026-07-31-token-consumption-ordering.md)
for the full reasoning; in short:

1. When the gate allows a human-actor transition, it does not delete
   `tokens/<item-id>.token`. It moves it to
   `tokens/<item-id>.consuming`, recording the same `item`/`transition`.
2. On the gate's *next* invocation touching that item, it checks the
   `.consuming` marker (if any) first: if the item's current recorded state
   already equals the marker's `to` — i.e. the write the marker authorized
   actually landed — the marker is deleted (finalized; truly spent).
3. If instead the item's current state still equals the marker's `from` —
   the permitted write never landed — and the exact same transition is
   attempted again, the marker itself re-authorizes that retry, with no
   fresh human verdict required.
4. A *different* transition attempted on that item while the marker is
   still pending cannot use it: the live `.token` file is already gone
   (moved to `.consuming` in step 1), so a different `(from, to)` finds no
   token at all and is refused, exactly as if no verdict had ever been
   given.

This means a legitimate human-authorized transition whose underlying write
fails or is aborted after the gate's allow decision remains completable on
retry without a fresh signoff, while the same reservation can never be
stretched to cover a second, different transition.

## Kill switches

Every plugin in the QA stack checks its own switch first, before doing
anything else. Unset or empty means the plugin is active (the default);
setting the variable to `1` makes that plugin's hooks emit nothing and exit
0 immediately — an intentional silent no-op, not a refusal.

| Variable | Plugin | Default | What breaks when set to `1` |
|---|---|---|---|
| `QA_CYCLE_DISABLE` | `qa-cycle` | unset (active) | The state-file library, the `PreToolUse` gate, and the session-start item report all go silent. State-file writes are no longer checked against the transition table at all — anything can be written, including human-only transitions with no token. |
| `QA_SIGNOFF_DISABLE` | `signoff` | unset (active) | The sign-off directive and verdict-capture hook both stop. No new verdict tokens are ever minted, so every human-only transition (`reproduced -> handed-off`, `reproduced -> not-a-defect`, `reproduced -> wont-fix`, `handed-off -> re-verifying`) becomes permanently unreachable through `/go-no-go` while this is set, even though `qa-cycle`'s gate itself is unaffected. |
| `QA_INTAKE_DISABLE` | `intake` | unset (active) | `/qa-init`'s directive and session-start profile report stop. Later plugins fall back to ad-hoc discovery instead of reading a frozen profile. |
| `QA_TESTRUN_DISABLE` | `testrun` | unset (active) | The execution-discipline directive (evidence-per-verdict, report-don't-fix) stops injecting; nothing else about `/testrun` is disabled by this switch. |
| `QA_BUGREPORT_DISABLE` | `bugreport` | unset (active) | The bug-filing discipline directive stops injecting; nothing else about `/bug` is disabled by this switch. |
| `QA_REGRESS_DISABLE` | `regress` | unset (active) | The three-check adoption-gate directive stops firing automatically on relevant turns; `/regress` run explicitly is unaffected by this switch. |
| `QA_STATS_DISABLE` | `stats` | unset (active) | The trust-accounting directive stops injecting; `/qa-stats` run explicitly is unaffected by this switch. |

Each variable follows the "off means off" convention already used across
this repo: only an explicit truthy-ish value disables a hook. Empty, `0`,
`false`, `no`, and `off` all mean "not off" — the plugin stays active on any
of those spellings, and only a value like `1` turns it off.

## Record root resolution

All QA-cycle state lives in the target repo the plugin is installed into:
`docs/reports/records/<subject>/qa/`, per
`docs/specs/role-handoff-contract.md` §10. There is no external workspace
mechanism — no environment variable names a separate root, and no hook logic
is keyed on one being set or unset.

The repo root itself resolves the same way every gate in this repo resolves
it: `CLAUDE_PROJECT_DIR` when set, otherwise the git top-level of the
current working directory. A hook that cannot resolve a repo root this way
exits 0 (nothing to enforce yet) for read-only/reporting hooks, or refuses
(exit 2) for `qa-cycle`'s `PreToolUse` gate, which requires a resolvable,
validated root (carrying `docs/specs/role-handoff-contract.md`) before it
will adjudicate anything.

## Gate refusal behavior

`qa-cycle/hooks/transition-gate.sh` runs on `PreToolUse` for writes to
`state.md`. On each attempted write it:

1. Resolves and validates the repo root, refusing (exit 2) if it cannot be
   resolved or validated, per the previous section. Writes under
   `docs/reports/records/<subject>/qa/` are then checked against qa's
   ownership of that subtree; a write to exactly `qa/state.md` falls
   through to the item-level machine below, and a write to any other file
   under `qa/**` (already confirmed as qa's own path) is allowed directly —
   only `state.md` gets this transition machine.
2. Reads every item's current `state` from the subject's `state.md` and
   determines which single item the attempted write changes (comparing
   every item block in the new content against that item's currently
   recorded state). Each block's `item:` value is checked against the item
   id allow-list ("Item id and project identifier shape" above) at the
   moment it is parsed out of the block — a value outside that allow-list
   makes the block unparseable, the same as a missing `item:`/`state:`
   pair. If the file is missing, unreadable, has malformed frontmatter,
   changes zero items, or changes more than one item, the gate refuses — an unreadable/absent/ambiguous state is never treated as "no
   restriction" and never falls through to allow. An item absent from
   `state.md` altogether resolves to the well-defined starting state
   `(none)`, from which only the bootstrap transition into `observed` (item
   creation) is legal — this row is part of the spec's own transition
   table, with `agent` as its actor, not an addition beyond it. Row count
   and table shape are not restated here; see the spec's transition table,
   which it describes as exhaustive.
3. Looks up the item's current state in the transition table in
   [`docs/specs/qa-cycle-state-machine.md`](../specs/qa-cycle-state-machine.md)
   and checks whether the attempted `from -> to` write is one the table
   permits for that item.
4. If the specific `from -> to` row's Actor is `human`, the gate additionally
   requires a matching, unconsumed token or a matching pending `.consuming`
   marker for that item — matching on both `item` and the exact
   `transition` pair, never on the destination state alone — `reproduced` is
   the source of three different human rows (`-> handed-off`,
   `-> not-a-defect`, `-> wont-fix`), so the pair, not the destination state,
   is what a token must bind to. Without a match, it refuses regardless of
   what state the item is currently in. An item in
   `handed-off` refuses every transition attempt without exception unless a
   human token authorizes it — this falls directly out of `handed-off`
   having exactly one legal outbound row and that row being a human row.
5. On success (exit 0) the write proceeds and, for a human-only transition,
   the token is reserved for consumption (moved to a `.consuming` marker,
   not deleted) as part of the same operation — see "Consumption is
   reserve-then-finalize" above.
6. On refusal (exit 2) the message names the item, its current state, and
   the set of transitions the table actually allows from it, so the next
   action is legible without reading the spec. It never prints file
   contents — not the state file's, not the token file's. For a refused
   human-only transition the message instead names what a person must
   decide and what evidence they need, per the spec's "Human decision
   points" section — not merely "no token found."

Refusal is always the safe default: malformed input, an unreadable file, an
unresolvable/unvalidated repo root, a disallowed transition, an ambiguous
multi-item write, or a missing/mismatched token for a human-only transition
all produce the same outcome — exit 2, never exit 0.
