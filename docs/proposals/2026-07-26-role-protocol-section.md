---
status: landed
files:
  - README.md
  - qa-cycle/hooks/transition-gate.sh
---

# Role protocol section for qa

## Intent

A running qa session today has to read the full shared
`docs/specs/role-handoff-contract.md` to learn that qa in fact accepts no
upstream role artifact at all, and to find where its own two output kinds
(the in-repo pointer and the out-of-repo evidence tree) land. This proposal
gives qa's own rulebook (`README.md`) a "Handoff protocol" section carrying
only qa's rows, so that "qa accepts nothing from other roles" is stated
locally instead of implied by absence in a six-role table.

## Constraints that change what gets built

- Excerpt only, from `docs/specs/role-handoff-contract.md` at
  `2affe5db7dfb285abaa2860d3004edb3f97c9aec` (root `tokenmaxxxer` repo) —
  qa's rows from sections 2, 3, and 7, plus qa's reading of sections 1, 4,
  and 6 (the `$QA_WORKSPACE` exception).
- The section header pins that SHA; `qa-cycle/hooks/transition-gate.sh`,
  which already adjudicates qa-cycle state transitions, gains a check that
  refuses to proceed when the pinned SHA no longer matches the contract's
  current SHA.
- Per-role path ownership (section 7) is enforced by this same gate — not
  by warrant, which has no presence in this repo, and not by any other
  mechanism, since section 7 states this is each rulebook's own
  responsibility.

## What will be done

Add "Handoff protocol" to `README.md` with four parts:

1. **ACCEPTS** — none. qa works from direct observation of the running
   system, not from other roles' records, and refuses `hypothesis`,
   `build-proposal`, `feasibility-record`, `review-record`, and `ops-state`
   uniformly if any is handed over as if it were required input.
2. **WHERE UPSTREAM LIVES** — not applicable; stated explicitly as such
   rather than left blank, so a session does not go looking.
3. **PRODUCES** — `qa-state` (the thin in-repo pointer) at
   `docs/reports/records/<subject>/qa.md`, required fields: role status
   (`observed,reproducing,reproduced,handed-off,re-verifying,verified-fixed,
   not-a-defect,wont-fix`), a `path:` pointer into `$QA_WORKSPACE`, plus the
   common header including `handoff_status`; and `qa-evidence` at
   `$QA_WORKSPACE/projects/<owner>-<repo>/**` (out-of-repo, the section 6
   exception), carrying intake profile, bug reports, regression records,
   and run stats as qa's existing templates already define.
4. **STOPS** — upstream stale at role entry (applies only if qa is ever
   handed a pointer despite accepting nothing — the check still exists as a
   backstop); an existing record already at a path qa does not own under
   `docs/reports/records/` (refuse and report, never overwrite); input
   carrying `handoff_status: provisional` that qa is not permitted to
   consume as final (moot in the common case since qa accepts no kind, but
   stated for the edge case of a stray handoff).

Also add the SHA-pin check to `qa-cycle/hooks/transition-gate.sh`.

## Out of scope

Changing `docs/specs/role-handoff-contract.md`. Changing warrant's
`scope-gate.sh` (not present in this repo, and not this proposal's target
regardless). The other five rulebook repos. Starting any qa-cycle build
work.

## How you will know it worked

A qa session can state, from `README.md` alone, that it accepts no
upstream kind and where each of its two output kinds lands, without
opening the shared contract. `transition-gate.sh` refuses to proceed when
the pinned SHA no longer matches the contract's current SHA, and refuses a
write to a `docs/reports/records/` path qa does not own.
