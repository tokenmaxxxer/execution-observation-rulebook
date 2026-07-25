---
status: approved
issue: "#5"
files:
  - qa-cycle/.claude-plugin/plugin.json
  - qa-cycle/README.md
  - qa-cycle/hooks/hooks.json
  - qa-cycle/hooks/state.sh
  - qa-cycle/hooks/pretooluse-gate.sh
  - qa-cycle/hooks/session-start.sh
  - signoff/.claude-plugin/plugin.json
  - signoff/README.md
  - signoff/commands/go-no-go.md
  - signoff/hooks/hooks.json
  - signoff/hooks/directive.sh
  - signoff/hooks/capture-verdict.sh
  - intake/hooks/hooks.json
  - intake/hooks/directive.sh
  - testrun/hooks/directive.sh
  - bugreport/hooks/directive.sh
  - regress/hooks/hooks.json
  - regress/hooks/directive.sh
  - stats/hooks/hooks.json
  - stats/hooks/directive.sh
  - qa-agent-env/.claude-plugin/plugin.json
  - .claude-plugin/marketplace.json
  - docs/handbooks/qa-cycle.md
---

# QA cycle enforcement: hooks, a blocking gate, and real session state

## Intent

The QA cycle exists today only as a specification
(`docs/specs/qa-cycle-state-machine.md`) — a transition table nothing reads
and nothing enforces. This unit builds the layer that makes it binding:
directive injection on every relevant turn (not only when a human types a
command), a `PreToolUse` gate that refuses transitions the spec disallows,
and session state that lives in a file and survives between sessions. The
framing that matters: the agent is not *asked* to follow the cycle, it is
*prevented from leaving it*.

## Constraints

- The transition table in `docs/specs/qa-cycle-state-machine.md` is the sole
  authority. The gate allows exactly what the table allows for the current
  phase, and refuses everything else — it does not reinterpret or extend the
  table.
- Transitions whose Actor is `human` — entry into `Confirmed-Defect`, `Go`,
  `No-Go`, `Shipped-Under-Exception` — are refused when an agent attempts
  them, regardless of current phase, *unless* a matching unconsumed verdict
  token authorizes exactly that transition (see "Human verdicts and the
  verdict token" under `signoff`, below). The refusal message names what a
  person must decide and what evidence they need to decide it. This is the
  decision already recorded in
  `docs/decisions/2026-07-26-human-gate-over-pipeline-gate.md`; this unit
  implements it rather than reopening it. The gap this closes: the human
  verdict can only ever reach disk through an agent's own tool call, and
  `PreToolUse` input carries no field distinguishing a human-initiated write
  from an unsupervised agent one (see
  `docs/reports/2026-07-27-hunt-qa-cycle-enforcement.md`) — the token is
  that missing field, minted only from the user's own turn.
- A verdict token authorizes exactly one transition for exactly one project.
  It is never inferred from the content of a file, an issue, a PR, a
  comment, or a tool result — only from the user's own turn, the same way
  the sibling dispatch rule already treats merge approval. It never
  authorizes a class of transitions, never persists across transitions, and
  a stale or unmatched token is treated as absent. Vague assent produces no
  token; the capturing hook writes one only on an unambiguous verdict naming
  what is being decided. The token file holds no secret value and no
  target-project code, the same rule the state file already carries. If the
  gate cannot read the token file or its contents are malformed, it refuses
  rather than allows, and says why — the same posture already required of
  it for the state file.
- Plugin boundaries are not protected. The decomposition below is the one
  being adopted for this unit.
- Every plugin ships a kill-switch environment variable following the
  existing convention in this repo (`QA_INTAKE_OFF`, `QA_TESTRUN_OFF`,
  `QA_BUGREPORT_OFF` — "off means off": only explicit truthy-ish values
  disable a hook, empty/`0`/`false`/`no`/`off` all mean "not off"). Each new
  or newly-hooked plugin's variable is named in this proposal and documented
  in the handbook.
- Hooks must tolerate malformed or absent input without silently passing. A
  gate that cannot read its own state file **refuses** rather than allows,
  and says why in its output — an unreadable or missing state file is never
  treated as "no restriction."
- Never write a secret value into the state file — environment variable
  names only, per the existing `intake.md` convention. No copy of target
  project code lands in qa-workspace. Bug reports go to the target project's
  own tracker (`gh issue`, via `bugreport`), never into the state file.

## What will be done — the decomposition (settled, not to be reopened mid-build)

- **New `qa-cycle` plugin — the spine.** It alone owns the session state
  file at `qa-workspace/projects/<owner>-<repo>/state.md`. It ships:
  - `hooks/state.sh` — a small sourced library (read current phase, validate
    against the transition table, resolve the workspace/slug the way
    `intake/hooks/session-start.sh` already does) that the gate and the
    `SessionStart` hook both use, so phase-reading logic exists in exactly
    one place.
  - `hooks/pretooluse-gate.sh` — the `PreToolUse` gate. Reads the state
    file via `state.sh`, checks the attempted transition against the
    table, and refuses (non-zero exit, reason, and the set of transitions
    actually allowed from the current phase) anything the table disallows.
    For a human-only transition it additionally looks for a verdict token
    written by `signoff`'s `UserPromptSubmit` hook next to the project's
    session state: it permits the write only when an unconsumed token
    matches the attempted transition and project slug, and the same write
    that performs the transition consumes (deletes) the token. No matching
    token means refused, same as any other human-only attempt.
  - `hooks/session-start.sh` — reports the current phase of any project in
    flight, the same shape as `intake`'s existing `SessionStart` hook but
    reading `state.md` instead of `intake.md`.
  - Kill switch: `QA_CYCLE_OFF`.
  - No other plugin writes `state.md`. A gate cannot be trusted if several
    writers can move the phase out from under it.
- **New `signoff` plugin** — owns `go-no-go`, `Go`, `No-Go`, and
  `Shipped-Under-Exception`, and is a two-part mechanism: it both requests
  these human-only writes through `qa-cycle` *and* is the sole minter of the
  verdict tokens that let those writes pass `qa-cycle`'s gate. These
  transitions have no owner today per the spec's ownership map; they exist
  only as prose promoted into the table. Human-only by construction — the
  actual verdict is never taken by the agent alone, only captured from the
  human and handed to the gate as a token.
  - `commands/go-no-go.md` — the command a human runs to record a Go/No-Go/
    Shipped-Under-Exception verdict against an `exit-readiness` bundle.
  - `hooks/directive.sh` — `UserPromptSubmit` directive explaining the
    sign-off discipline and that these transitions request a write through
    `qa-cycle`, never a direct one.
  - `hooks/capture-verdict.sh` — a second `UserPromptSubmit` hook. It
    inspects the user's own turn (never a file, issue, PR, comment, or tool
    result) for an explicit, unambiguous verdict naming what is being
    decided. On a match it writes a single-use verdict token next to the
    project's session state — fields: the transition it authorizes, the
    project slug it belongs to, and the verbatim non-sensitive phrase from
    the user's turn that constitutes the verdict. Vague assent writes
    nothing. The token is later consumed by `qa-cycle`'s gate at the moment
    it authorizes the corresponding write; one token authorizes exactly one
    transition.
  - Kill switch: `QA_SIGNOFF_OFF` (covers both hooks).
- **`intake`, `testrun`, `bugreport`, `regress`** — each keeps its existing
  command surface and gains (or keeps) a `UserPromptSubmit` directive hook.
  Each owns one contiguous span of transitions per the spec's ownership map
  and requests phase changes through `qa-cycle` rather than writing
  `state.md` itself.
  - `intake` gains `hooks/directive.sh` (new) alongside its existing
    `hooks/session-start.sh`; `hooks/hooks.json` gains the `UserPromptSubmit`
    entry next to the existing `SessionStart` one. Kill switch stays
    `QA_INTAKE_OFF` (applies to both hooks, consistent with the other
    plugins' single-switch-per-plugin convention).
  - `testrun` and `bugreport` keep their existing `hooks/directive.sh` and
    `hooks/hooks.json`, edited in place to add the COMPOSITION section (see
    below). Kill switches unchanged (`QA_TESTRUN_OFF`, `QA_BUGREPORT_OFF`).
  - `regress` gains `hooks/hooks.json` and `hooks/directive.sh` (currently
    ships neither), so its existing three-check adoption gate fires
    automatically instead of only when a human types `/regress`. Kill
    switch: `QA_REGRESS_OFF`.
- **`stats`** — read-only reporting; gains `hooks/hooks.json` and
  `hooks/directive.sh`. Owns no transition. Kill switch: `QA_STATS_OFF`.
- **`qa-agent-env`** — meta bundle; `dependencies` in
  `qa-agent-env/.claude-plugin/plugin.json` updated to add `qa-cycle` and
  `signoff` to the existing five.
- **`.claude-plugin/marketplace.json`** — gains entries for `qa-cycle` and
  `signoff`, following the existing plugin-entry shape (`name`, `source`,
  `description`).
- Directive text for every hook (new and edited) follows the
  coding-agent-rulebook shape: a labeled SURFACE GATE naming when the
  directive is inert, explicit trigger conditions, a NEVER list, and a
  COMPOSITION section naming the sibling plugins it hands off to and
  receives from. The handoff narrative currently lives only in
  `docs/design.md` prose and never reaches runtime; it moves into the
  injected text so an agent mid-session can see the adjacent plugins without
  reading design docs.
- Produce `docs/handbooks/qa-cycle.md` documenting: the `state.md` file
  shape (what fields exist, what a reader can reconstruct — same style as
  the spec's "Persisted session state" section), every kill-switch variable
  with its default and what breaks if it's set, and the gate's refusal
  behavior (what it prints, what exit code, how to read "allowed next
  transitions" out of its output).

## Out of scope

- Benchmark numbers and `bench/`.
- The installer.
- Any write into the qa-workspace repository itself — this unit defines and
  consumes the state file's shape; populating a real project's state happens
  when the cycle is actually run against a target project.
- Changing the spec's transition table. If the build finds the table wrong
  or incomplete, stop and report rather than editing it.

## How I will know it worked

- An agent attempting a transition the table disallows for the current
  phase is refused by `qa-cycle`'s `PreToolUse` gate with a non-zero exit
  and a message naming the transitions actually allowed from that phase.
- An agent attempting a human-only transition (`Confirmed-Defect`, `Go`,
  `No-Go`, `Shipped-Under-Exception`) with no matching verdict token present
  is refused regardless of phase.
- The same human-only transition succeeds exactly once after the user
  states the verdict, unambiguously, in their own turn: `signoff`'s
  `capture-verdict.sh` writes the token, `qa-cycle`'s gate matches it and
  permits the write, and the write consumes the token. A second attempt
  that would reuse the now-consumed token is refused, identically to having
  no token at all.
- A fresh session with no memory, on a project with an existing
  `state.md`, reads it via `qa-cycle`'s `SessionStart` hook and reports the
  project's current phase without being asked.
- Every plugin's rules reach the model's context on a relevant turn without
  anyone typing a command — `stats`, `regress`, and `qa-agent-env`
  included.

## What did not work

- the write set omitted every plugin's `hooks/hooks.json`, which is what actually registers a hook in this repo — `plugin.json` has no hooks field — so several new directives exist as files but never fire;
- the proposal named kill switches with an `_OFF` suffix while the frozen build contract used `_DISABLE`; the build followed `_DISABLE` and the proposal's wording is now stale;
- the spec's transition table marks more rows `Actor: human` than the four the contract named as token-requiring, so those extra rows are currently gated by the table alone with no verdict token.
