---
status: approved
issue: "#7"
files:
  - qa-cycle/hooks/hooks.json
  - signoff/hooks/hooks.json
  - regress/hooks/hooks.json
  - stats/hooks/hooks.json
  - qa-cycle/hooks/transition-gate.sh
  - docs/proposals/2026-07-27-qa-cycle-enforcement.md
  - docs/handbooks/qa-cycle.md
---

# QA cycle wiring: register the hooks, close the gate's silent-allow path

## Intent

PR #6 built the enforcement layer's structure; this makes it actually
enforce. Register the hooks that never fire, and close the gate's
silent-allow path so unreadable input refuses instead of passing. Lands on
the same branch as PR #6 — the point of the sequencing is that main never
holds enforcement that does not enforce.

## Constraints

- Every failure path in the gate exits 2. Unreadable stdin, malformed
  payload, missing state file, malformed state, missing or mismatched
  token — all refuse, none allow. There is no input shape for which the
  gate exits 0 without having affirmatively matched a permitted transition.
- Every transition the spec's table marks `Actor: human` requires a
  matching unconsumed verdict token, not only the four the earlier contract
  named. The table is the authority and is not edited; the gate is what
  changes.
- Registration files follow the shape the repo's existing `hooks/hooks.json`
  files already use — read one, match it.
- Kill switch names stay as shipped (`_DISABLE`); the stale proposal prose
  is corrected to match the code rather than the code being renamed to
  match the prose.
- No write into the qa-workspace repository.

## What will be done

Write the four missing `hooks/hooks.json` files so the gate runs on
PreToolUse, the phase reporter on SessionStart, and every directive plus
the verdict-token minter on UserPromptSubmit. Rework the gate so refusal is
the default and allow is reached only by an affirmative match, including on
non-JSON stdin. Extend the token requirement to every human-actor row in
the table. Correct the earlier proposal's kill-switch wording. Update the
handbook if its description of refusal behavior no longer matches.

## Out of scope

Benchmarks, the installer, the qa-workspace repository, and the transition
table itself. If the table turns out to be wrong, stop and report rather
than editing it.

## How I will know it worked

Feeding the gate a non-JSON payload refuses with a non-zero exit rather
than passing. Every plugin that ships a hook has a registration file
naming it. An agent attempting any human-actor transition without a token
is refused, including the rows beyond the original four. The shipped
kill-switch names and the documents that describe them agree.

## What did not work

- keying the extended token requirement by destination phase name alone
  (the earlier contract's `TOKEN_REQUIRED_TARGETS` set) does not work:
  `report-filed` is the target of both an agent row
  (`Confirmed-Defect -> report-filed`) and a human row
  (`report-filed -> report-filed`, the severity/priority-set self-loop), so
  a target-only set either wrongly gates the agent row or wrongly skips the
  human one — the fix keys the check on the exact `(from, to)` pair via the
  table's own actor column instead.
