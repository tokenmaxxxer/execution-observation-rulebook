# issue-56 phase 1 proposal — rename qa → execution-observation

Scope: role execution-observation, session on branch
`issue-56/execution-observation`, issue #56, no PR opened for this
subject yet (this is the first commit). This proposal covers ONLY the
design for resolving the certification-blocking rename; it renders no
verdict of any kind — verdicts belong to phase 2.

## Scout: skipped, mechanical rename

This task is a same-meaning rename across a fixed, already-enumerated
file set (survey.md's "What exists now" section) with no product-facing
design space — the plugin's behavior, hooks, and role content do not
change, only names and stale prose describing an already-superseded
system. It fits the bugfix-class skip condition (no open design
decision beyond "match the current role name consistently"). Scouting
best-in-class marketplace-plugin naming conventions would not change
any of the concrete renames below, so it is skipped rather than run.

## Change set

1. `.claude-plugin/marketplace.json`
   - `name`: `tokenmaxxxer-qa` → `tokenmaxxxer-execution-observation`
   - plugin entry `name`: `qa` → `execution-observation`,
     `source`: `./qa` → `./execution-observation`
2. Directory rename `qa/` → `execution-observation/` (git mv, preserves
   history), including `qa/.claude-plugin/plugin.json` (`name` field
   updated to `execution-observation`) and the already-correctly-named
   `qa/plugins/{eo-directive,eo-methodology-gate,eo-state}` subtree
   (moves with the parent, no internal renames needed).
3. `execution-observation/README.md` — replace the stale "qa-cycle"
   content (transition-gate/report-phase/directive.sh description of a
   `docs/reports/records/<subject>/qa/state.md` system) with a
   description of what actually ships today: the execution-observation
   role plugin plus eo-directive/eo-methodology-gate/eo-state, per
   contract v3 s19 and the plugin.json description already in place.
4. `execution-observation/commands/*.md` — rename/update
   `qa-init.md`, `qa-stats.md`, `regress.md`, `testrun.md` to match
   whatever commands this role plugin actually exposes; drop any that
   describe qa-cycle behavior no longer shipped, keep/rename any that
   still apply.
5. `install.sh`, `docs/design.md`, `docs/design.ko.md` — update the
   `/plugin install qa-agent-env@tokenmaxxxer-qa` install instructions
   to the new marketplace name (`@tokenmaxxxer-execution-observation`).
   These are shared root docs/scripts, not another role's exclusive
   docs tree, so they are in scope for this rename.

## Test/probe plan (to satisfy issue requirement 1 and 3)

- Shipping-state probe: `jq . .claude-plugin/marketplace.json` and
  `jq . execution-observation/.claude-plugin/plugin.json` parse clean;
  confirm no remaining `"qa"` name/source strings via grep.
- Clean-clone check: fresh clone/worktree, run `install.sh` (or the
  equivalent marketplace-add step it documents) against the renamed
  marketplace name, confirm it resolves without the old name.
- Repo-wide grep for `tokenmaxxxer-qa` and bare `qa/` path references
  returns empty outside of historical/issue docs (e.g.
  `docs/issue-47/proposals/execution-observation-proposal.md`, which is
  a dated historical record and is left untouched).
- Actual command output/log of the above goes into the phase-2 record
  (`docs/issue-56/reports/execution-observation.md`) once phase 2
  opens, per issue requirement 3.

## Verdict levels this subject will be checked against (phase 2, not now)

- **outcome** — against: marketplace.json/plugin.json/README/commands
  no longer reference `qa` as the role name, and the probe/grep
  commands above pass, evidenced by their logged output and by
  file:line diffs in the merged PR.
- **trajectory** — against: whether this phase-1 survey ran before the
  proposal (it did, this file follows survey.md), and whether a real
  human Approve (PR review or `APPROVE issue-56/execution-observation`
  comment from an `approvers.md` account) preceded any phase-2 write,
  evidenced by the PR review/comment timestamp and author login.
- **step** — against: whether any individual rename (marketplace.json,
  directory move, README rewrite, commands, install.sh/docs) was left
  half-done or introduced a new stale reference, evidenced by
  file:line in the diff.

## Note on issue requirement 2

Issue #56's requirement 2 ("sales만 해당: core #78 랜딩 후 착수") does not
apply to this subject — it names the `sales` role only. Not applicable,
because this subject's role is execution-observation, not sales.
