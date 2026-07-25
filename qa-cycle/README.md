# qa-cycle

The QA cycle spine. This plugin alone owns the session-state file at
`$QA_WORKSPACE/projects/<owner>-<repo>/state.md`, and enforces
`docs/specs/qa-cycle-state-machine.md`'s transition table as a real gate
rather than a document nothing reads.

## What it ships

- `hooks/transition-gate.sh` — `PreToolUse`. Reads the attempted write to a
  project's `state.md`, checks `(current phase -> attempted phase)` against
  the transition table (encoded in the script, sourced from
  `docs/specs/qa-cycle-state-machine.md`), and allows it only if the table
  permits it. For the four human-only transitions — entry into
  `Confirmed-Defect`, `Go`, `No-Go`, `Shipped-Under-Exception` — it
  additionally requires a matching, unconsumed verdict token at
  `.verdict-token` next to `state.md` (minted by `signoff`), and consumes
  (deletes) that token as part of granting the write. Fails closed: an
  unset `QA_WORKSPACE`, or a missing/unreadable/malformed state or token
  file, all refuse rather than allow.
- `hooks/report-phase.sh` — `SessionStart`. Reports the current phase of
  every project with a `state.md` under `$QA_WORKSPACE/projects/`. Silent
  when there is none in flight.
- `hooks/directive.sh` — `UserPromptSubmit`. States that the cycle is
  enforced, that `state.md` is the single source of phase, that only
  `qa-cycle` writes it, and that other plugins request transitions through
  this plugin rather than writing it themselves.

## State file

`$QA_WORKSPACE/projects/<owner>-<repo>/state.md`, markdown with YAML
frontmatter:

```yaml
---
phase: session-executed
updated_by: testrun
transition: session-chartered -> session-executed
evidence: runs/2026-07-25-smoke.md
---
```

No secret values, ever — environment variable names only. No target-project
code. No bug report bodies.

## Verdict token

`$QA_WORKSPACE/projects/<owner>-<repo>/.verdict-token`, YAML:

```yaml
transition: go-no-go -> Go
project: acme-widgets
phrase: "ship it, exit criteria are met"
```

Single-use. Minted by `signoff` from the user's own turn, never inferred
from a file, issue, PR, comment, or tool result. Consumed by
`transition-gate.sh` the moment it authorizes the matching write. A token
whose `transition` or `project` does not match the attempted write is
treated as absent.

## Kill switch

`QA_CYCLE_DISABLE=1` — every hook in this plugin checks it first and, if
set to a truthy value, emits nothing and exits 0 immediately. Unset, empty,
`0`, `false`, `no`, `off` all mean "not disabled."
