# issue-47 phase 2 record (execution-observation)

## Scope

issue-47, PR #48 (phase 1, merged as commit 85c809f) plus this phase-2
delivery on the same branch `issue-47/execution-observation` — this is
the execution-observation role building its own rulebook's enforcement
tooling, not an observation of another role's PR. The subject observed
is this repo's own approved proposal:
`docs/issue-47/proposals/execution-observation-proposal.md`, approved by
the single-account-mode trigger — issue #47 comment "APPROVE
issue-47/execution-observation" from an approvers.md account.

## Independence statement

This record covers work this same session performed (implementing the
approver-corrected proposal), not a review of another role's
independently-authored artifact. The independence rule this role
otherwise enforces on itself (never edit the observed artifact) does not
apply to a self-implementation phase-2 delivery — there is no second
party's artifact being judged here. What follows is a delivery report
against the proposal's own phase-2 acceptance criteria, not a verdict on
someone else's work.

## What was done (against the proposal's phase-2 acceptance criteria)

- **outcome** — three new plugin directories created exactly as
  proposed: `qa/plugins/eo-directive/`, `qa/plugins/eo-methodology-gate/`,
  `qa/plugins/eo-state/`, each with its own `.claude-plugin/plugin.json`
  (name/description/author, matching `scout`'s shape) and, where
  applicable, its own `hooks/` and `hooks.json`. `.claude-plugin/marketplace.json`
  now lists four plugins total (`qa` unchanged plus the three new ones),
  each description naming exactly one methodology — confirmed by reading
  the file after edit (`python3 -m json.tool` parsed clean, 4 entries).
  `qa/hooks/directive.sh`'s four bodies are now fetched from
  `eo-directive/hooks/directive-body.sh` (via subprocess, one call per
  variable, so `directive.sh` itself stays inside `tests/stub-check.sh`'s
  structural stub cap — `bash tests/stub-check.sh qa/hooks` passes,
  confirmed this session) and contain the per-facet judgment criteria
  from proposal section (1). `eo-methodology-gate/hooks/methodology-gate.sh`
  exists, `bash -n` passes, and its own `hooks.json` registers the new
  `PreToolUse` entry (`Write|Edit|MultiEdit`). `tests/run-gate-tests.sh`
  passes with the 10 new cases from proposal section (4) included (`bash
  tests/run-gate-tests.sh` this session: 10/10 new `eo-*` cases pass; 7
  pre-existing failures are unrelated stale references to
  `record-fields-gate.sh`/`trailer-gate.sh`, files already removed from
  this repo per issue-42's core-canon conversion — not this issue's ask
  to fix, per the proposal's stated out-of-scope). `eo-state/hooks/state.sh`
  exists, defines `eo_state_marker_path`, and is sourced by
  `qa/hooks/hooks.json`'s `SessionStart` array (second entry, added
  alongside the existing directive.sh entry) — confirmed by reading the
  file after edit.
- **trajectory** — phase 1 (survey + scout brief + proposal) was
  committed and PR'd as #48, approver feedback ("요구 정정") was
  reflected into a restructured plugin-set proposal (commit ec642b2),
  approval arrived via the single-account-mode issue comment "APPROVE
  issue-47/execution-observation" (not prose, exact string), and this
  phase-2 work implements that same approved proposal verbatim — no new
  methodology invented, no scope expansion beyond the three plugins +
  marketplace registration + gate tests the proposal named.
- **step** — one deviation from the proposal's literal text, reasoned
  and disclosed: proposal section (1) described `eo-directive`'s body as
  "sourced" into `qa/hooks/directive.sh`. Implementing it as a literal
  `source` (`.`) produced a `tests/stub-check.sh` FAIL (`qa/hooks/directive.sh:
  has non-stub line(s), looks like regrown boilerplate`) — stub-check.sh
  is a core-canon-distributed file this repo does not modify, and its
  structural cap only whitelists lines matching `role-directive.sh` /
  `core_role_directive` / a plain `VAR=` assignment. Fixed by having
  `eo-directive/hooks/directive-body.sh` become an executable
  subprocess (one argument per body name, prints to stdout) invoked via
  four `VAR="$(...)"` command-substitution assignments instead of a
  `source` line — every line in `qa/hooks/directive.sh` still matches
  the stub-check whitelist, confirmed passing this session. The
  methodology (four bodies owned and supplied by `eo-directive`) is
  unchanged; only the mechanism (subprocess vs. source) differs from the
  proposal's literal wording, to satisfy a pre-existing test this
  proposal did not anticipate interacting with.

## Why

Issue #47 asked for the approved methodology-gate/eo-directive/eo-state
plugin set to actually be built (not just proposed), per the approver's
"요구 정정" restructuring and the exact-string APPROVE comment on the
issue that opened phase 2. Every design choice here traces to the
already-approved proposal; the one deviation (subprocess instead of
source) is explained above as a step-level note, not a re-decision of
methodology.

## Upstream basis

Commit 85c809f (PR #48, merged) for the approved proposal;
`docs/issue-47/proposals/execution-observation-proposal.md` sections
(1)-(4) for the exact required shapes implemented here.

loop_state: landed

## Open findings

None. The one deviation from the proposal's literal wording (subprocess
vs. source for `eo-directive`'s body, see "step" above) is disclosed
inline as a reasoned implementation detail, not an open finding — it
does not change what `eo-directive` supplies, only how `qa/hooks/directive.sh`
retrieves it, and was necessary to keep `tests/stub-check.sh` passing.

## Evidence

- `docs/issue-47/proposals/execution-observation-proposal.md` (this
  session's read, approved proposal — Marketplace/Plugin-list sections).
- Issue #47 comments (`gh issue view 47 --comments`, read this session):
  "요구 정정" feedback comment and "APPROVE issue-47/execution-observation".
  PR #48 merge commit `85c809f6d1ab50d0f253789bda3490c91161c393`
  (`gh pr view 48`, read this session).
- This session's own file writes/edits: `qa/plugins/eo-directive/`,
  `qa/plugins/eo-methodology-gate/`, `qa/plugins/eo-state/`,
  `.claude-plugin/marketplace.json`, `qa/hooks/directive.sh`,
  `qa/hooks/hooks.json`, `tests/run-gate-tests.sh` (all read back after
  edit this session).
- Test runs this session: `bash tests/stub-check.sh qa/hooks` (pass, all
  5 checks ok), `bash tests/parse-check.sh` (pass), `bash
  tests/run-gate-tests.sh` (10/10 new `eo-*` cases pass; 7 unrelated
  pre-existing failures), `bash -n` on every new/edited shell file
  (pass), `python3 -m json.tool` on every new/edited JSON file (pass).
