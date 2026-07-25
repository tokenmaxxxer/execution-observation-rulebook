# QA cycle enforcement handbook

This handbook documents the runtime layer that makes the QA cycle binding:
the session state file, the single-use verdict token, the seven kill
switches, `QA_WORKSPACE`, and the gate's refusal behavior. The transition
table itself — which phase can move to which, on what trigger, with what
evidence, by which actor — is not restated here; it lives in
[`docs/specs/qa-cycle-state-machine.md`](../specs/qa-cycle-state-machine.md)
and that document is the sole authority on it.

## The state file

Path: `<QA_WORKSPACE>/projects/<owner>-<repo>/state.md`.

One file per project, owned exclusively by the `qa-cycle` plugin — no other
plugin writes it. It is markdown with a YAML frontmatter block:

```yaml
---
phase:            # current cycle state, exactly one name from the spec's States section
updated_by:       # plugin name that performed the last transition
transition:       # the transition just taken, written `from -> to`
evidence:         # relative path(s) under the project dir proving the transition's Required evidence
---
```

It never holds a secret value (environment variable names only, the same
rule `intake.md` already follows) and never holds a copy of target-project
code or a bug report body — bug reports go to the target project's own
tracker via `bugreport`, and only the resulting issue URL is ever referenced
from workspace files.

## The verdict token

Path: `<QA_WORKSPACE>/projects/<owner>-<repo>/.verdict-token`.

Minted only by `signoff`'s verdict-capture hook, from the user's own turn —
never inferred from a file, an issue, a PR, a comment, or a tool result.
YAML shape:

```yaml
transition:       # the single transition this token authorizes, `from -> to`
project:          # the `<owner>-<repo>` slug
phrase:           # the verbatim NON-SENSITIVE phrase from the user's own turn constituting the verdict
```

Single-use: the same write that performs the authorized transition consumes
(deletes) the token. It authorizes exactly one transition for exactly one
project — never a class of transitions, and it never persists past the
transition it authorized. A token whose `transition` or `project` field does
not match the write actually being attempted is treated as absent, the same
as no token existing at all. Vague assent from the user produces no token.

## Kill switches

Every plugin in the QA stack checks its own switch first, before doing
anything else. Unset or empty means the plugin is active (the default);
setting the variable to `1` makes that plugin's hooks emit nothing and exit
0 immediately — an intentional silent no-op, not a refusal.

| Variable | Plugin | Default | What breaks when set to `1` |
|---|---|---|---|
| `QA_CYCLE_DISABLE` | `qa-cycle` | unset (active) | The state-file library, the `PreToolUse` gate, and the session-start phase report all go silent. State-file writes are no longer checked against the transition table at all — anything can be written, including human-only transitions with no token. |
| `QA_SIGNOFF_DISABLE` | `signoff` | unset (active) | The sign-off directive and verdict-capture hook both stop. No new verdict tokens are ever minted, so every human-only transition (`Confirmed-Defect`, `Go`, `No-Go`, `Shipped-Under-Exception`) becomes permanently unreachable through `/go-no-go` while this is set, even though `qa-cycle`'s gate itself is unaffected. |
| `QA_INTAKE_DISABLE` | `intake` | unset (active) | `/qa-init`'s directive and session-start profile report stop. Later plugins fall back to ad-hoc discovery instead of reading a frozen profile. |
| `QA_TESTRUN_DISABLE` | `testrun` | unset (active) | The execution-discipline directive (evidence-per-verdict, report-don't-fix) stops injecting; nothing else about `/testrun` is disabled by this switch. |
| `QA_BUGREPORT_DISABLE` | `bugreport` | unset (active) | The bug-filing discipline directive stops injecting; nothing else about `/bug` is disabled by this switch. |
| `QA_REGRESS_DISABLE` | `regress` | unset (active) | The three-check adoption-gate directive stops firing automatically on relevant turns; `/regress` run explicitly is unaffected by this switch. |
| `QA_STATS_DISABLE` | `stats` | unset (active) | The trust-accounting directive stops injecting; `/qa-stats` run explicitly is unaffected by this switch. |

Each variable follows the "off means off" convention already used across
this repo: only an explicit truthy-ish value disables a hook. Empty, `0`,
`false`, `no`, and `off` all mean "not off" — the plugin stays active on any
of those spellings, and only a value like `1` turns it off.

## `QA_WORKSPACE`

`QA_WORKSPACE` names the root directory where all QA-cycle state lives:
`<QA_WORKSPACE>/projects/<owner>-<repo>/`. It is never the target project's
own repository.

There is no default for enforcement purposes. (Some read-only or reporting
hooks fall back to `~/qa-workspace` for convenience when nothing is being
enforced, but the gate does not.) Most hooks that need `QA_WORKSPACE` and
find it unset simply exit 0 — there is nothing yet to enforce, so they stay
silent rather than fail.

The gate is the deliberate exception: if `QA_WORKSPACE` is unset when
`qa-cycle`'s `PreToolUse` gate runs, it exits 2 (refuses the write) and says
the variable is unset. A gate that cannot locate the workspace root has no
state file to check and therefore has no basis for allowing anything through
— unset is treated the same as "state unreadable," not as "nothing to
enforce."

## Gate refusal behavior

`qa-cycle/hooks/transition-gate.sh` runs on `PreToolUse` for writes to
`state.md`. On each attempted write it:

1. Resolves `QA_WORKSPACE` and the project slug, refusing (exit 2) if
   `QA_WORKSPACE` is unset, per the previous section.
2. Reads the current `phase` from the project's `state.md`. If the file is
   missing when it's required, unreadable, or its frontmatter is malformed,
   the gate refuses — an unreadable or absent state file is never treated as
   "no restriction" and never falls through to allow.
3. Looks up the current phase in the transition table in
   [`docs/specs/qa-cycle-state-machine.md`](../specs/qa-cycle-state-machine.md)
   and checks whether the attempted `from -> to` write is one the table
   permits.
4. If the transition's Actor is `human` (`Confirmed-Defect`, `Go`, `No-Go`,
   `Shipped-Under-Exception` per the spec), the gate additionally requires a
   matching, unconsumed `.verdict-token` — matching on both `transition` and
   `project`. Without one, it refuses regardless of what phase the project
   is currently in.
5. On success (exit 0) the write proceeds and, for a human-only transition,
   the token is consumed (deleted) as part of the same operation.
6. On refusal (exit 2) the message names the current phase and the set of
   transitions the table actually allows from it, so the next action is
   legible without reading the spec. It never prints file contents — not the
   state file's, not the token file's. For a refused human-only transition
   the message instead names what a person must decide (e.g. "is this a
   genuine defect," "ship or hold") and what evidence they need to decide
   it, per the spec's "Human decision points" section — not merely "no
   token found."

Refusal is always the safe default: malformed input, an unreadable file, a
missing `QA_WORKSPACE`, a disallowed transition, or a missing/mismatched
token for a human-only transition all produce the same outcome — exit 2,
never exit 0.
