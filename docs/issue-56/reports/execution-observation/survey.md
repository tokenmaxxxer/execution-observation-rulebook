# issue-56 current-state survey

Scope: issue #56 ("A+ 인증 마감: 인증 감사 차단 사유 해소"), role execution-observation,
session on branch `issue-56/execution-observation`, no prior PR exists yet for this
subject (first commit on this branch). Read this session: `gh issue view 56`
(full body), `.claude-plugin/marketplace.json`, `qa/.claude-plugin/plugin.json`,
`qa/README.md`, `qa/commands/*.md` listing, `qa/plugins/*` listing,
`docs/specs/approvers.md`, and a repo-wide grep for `tokenmaxxxer-qa` / `qa`.

## Blocking reason (verbatim from issue)

> 옛 역할명 qa 전면 개명: marketplace.json(tokenmaxxxer-qa→execution-observation),
> 플러그인 qa/→역할명 정합, README·commands 갱신 — 하드 에러 해소

## What exists now

- `.claude-plugin/marketplace.json`: marketplace `name` is `tokenmaxxxer-qa`.
  Its first plugin entry is `name: "qa"`, `source: "./qa"`, but the
  entry's own `description` already reads as execution-observation's
  role description (contract v3, verdict/citation language) — the
  metadata name and the description already disagree.
- `qa/.claude-plugin/plugin.json`: `name: "qa"`, same
  execution-observation description text as the marketplace entry.
- `qa/README.md`: describes a *different, older* concept — "qa-cycle",
  a `docs/reports/records/<subject>/qa/state.md` transition-gate system
  (`hooks/transition-gate.sh`, `report-phase.sh`, `directive.sh`). This
  content does not describe eo-directive/eo-methodology-gate/eo-state
  (the plugins actually shipped under `qa/plugins/`, added in PR #49 per
  issue #47). The README is stale, not just misnamed.
- `qa/commands/*.md`: `qa-init.md`, `qa-stats.md`, `regress.md`,
  `testrun.md` — QA-cycle-era command names, unrelated to the current
  execution-observation role's actual commands/plugins.
- `qa/plugins/{eo-directive,eo-methodology-gate,eo-state}`: these three
  already carry the `eo-` (execution-observation) naming; only the
  parent `qa/` directory and its own README/commands/plugin.json are on
  the old name.
- Other repo files referencing `tokenmaxxxer-qa`: `install.sh`,
  `docs/design.md`, `docs/design.ko.md` (both instruct
  `/plugin install qa-agent-env@tokenmaxxxer-qa`). These are root-level
  shared docs/install script, not under any role's exclusive docs tree.
- No sub-plugin or hook script content (`qa/hooks/`, `qa/plugins/*/hooks/*.sh`)
  was found to embed the string `qa` as a functional identifier beyond
  path references already covered above — confirmed via the grep above
  returning only the files listed.

## Gap this issue must close

Rename target: `qa` → `execution-observation` (directory, plugin name,
marketplace plugin entry name/source, and the marketplace package name
`tokenmaxxxer-qa` → `tokenmaxxxer-execution-observation`), plus bringing
`README.md` and `commands/*.md` content in line with what the plugin
actually is today (eo-directive/eo-methodology-gate/eo-state under
contract v3), not the old qa-cycle system. `install.sh` and
`docs/design*.md` need their `@tokenmaxxxer-qa` marketplace reference
updated to match, since they instruct users to install from the
marketplace by that name.

## Test/probe baseline (pre-change)

Repo has no top-level test runner config found (`package.json` /
`Makefile` test target) in this survey; "테스트 green 유지" for this
change class means: shipping-state probe (marketplace.json parses,
plugin sources resolve) and a clean-clone install check
(`install.sh` against the renamed marketplace name resolves). Exact
probe commands are deferred to phase 2 execution, to be logged with
their actual output in the phase-2 record per issue requirement 3.
