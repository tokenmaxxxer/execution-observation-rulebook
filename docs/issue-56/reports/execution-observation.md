loop_state: phase-2-complete

## What was done

Executed the approved phase-1 proposal's rename set: renamed the `qa/`
plugin directory to `execution-observation/` (git mv, history preserved),
retargeted `.claude-plugin/marketplace.json`'s marketplace name, plugin
entry name/source, and the three `eo-*` plugin sources; rewrote
`execution-observation/README.md` to describe the plugin as it ships
today; removed the four stale qa-cycle-era command files with no current
equivalent; updated `install.sh`'s `MARKET`/`BUNDLE`/`GITHUB_REPO` and
install-loop plugin name; fixed the hardcoded `../qa/...` path
dependencies in three `tests/*.sh` probes that the directory rename would
otherwise have silently broken; and updated the remaining stale
`qa/hooks/directive.sh` path references left in sub-plugin READMEs,
`execution-observation/hooks/directive.sh`'s own header comment, and
`tests/fetch-core.sh`. Ran the full probe/test suite (`jq` parses,
`tests/parse-check.sh`, `tests/deny-only-check.sh`,
`tests/run-gate-tests.sh`, `install.sh` syntax + variable check) and
logged the output below. Then wrote this record as the first phase-2 act
and committed it on this branch.

## Why

Issue #56 lists this rename as a hard-error blocking issue #56's own A+
certification closeout; requirement 1 requires the change and green
tests, requirement 3 requires this record to carry the probe/test
evidence.

## Open findings

One step-level deficiency remains open (see **step** below):
`docs/design.md`/`docs/design.ko.md` still reference the old
`tokenmaxxxer-qa` marketplace name in their install instructions, and this
session could not edit them — the repo's own `board-gate.sh` (contract v3
s10) refuses writes to `docs/` paths outside the six standing buckets and
outside an issue tree, and these two files are neither. Routing (e.g. a
board-gate exception or relocating these files) is left to the user,
since this role files no issues itself.

## Next steps

None for this role on this issue — the four surfaces the issue's
blocking reason names are closed and probes are green. The one open
finding above requires action from outside this role's write surface
(see resolution path below); this role has nothing further to execute on
issue #56 unless the user reopens it with a different scope.

## Open-finding resolution path

The `docs/design.md`/`docs/design.ko.md` stale-reference finding cannot
be closed by any role under the current `board-gate.sh` rule (contract v3
s10), since neither file is under an allowed `docs/` bucket or issue tree.
Resolution requires a user decision on one of: (a) extend
`board-gate.sh`'s allowed-bucket list to cover pre-existing root design
docs, or (b) relocate `docs/design.md`/`docs/design.ko.md` under an
allowed bucket (e.g. `docs/handbooks/`) so a future role/PR can edit them.
Either requires a human call and, if (a), a change to `board-gate.sh`
itself — outside this role's own write surface — so it is left here as an
open item rather than actioned. This role files no issues; the user may
file one against this finding if they judge it worth tracking.

# issue-56 phase 2 — execution-observation record

Scope: issue #56 ("A+ 인증 마감: 인증 감사 차단 사유 해소"), role
execution-observation, session on branch `issue-56/execution-observation`.
Observed subject: this role's own phase-1 deliverable — PR #57
(`https://github.com/tokenmaxxxer/execution-observation-rulebook/pull/57`),
commit `b6338602f322b64f287eb70dadcedfb3009f63e8` (squash-merged to main as
`8cdbac7dfcdc2d3cb5c8eef6a0e29160493cb797`), and its own record files
`docs/issue-56/reports/execution-observation/survey.md` and
`docs/issue-56/proposals/execution-observation-proposal.md`, all read this
session before any verdict below.

## Independence statement

This session did not author or edit the observed artifact (PR #57's
survey and proposal) beyond reading it this session to judge it; the code
changes made in this same PR under phase 2 (the actual `qa`→
`execution-observation` rename) are this role's own approved-scope
execution work, not edits to another role's artifact — the observed
subject being judged here is the phase-1 survey/proposal's soundness, not
the phase-2 code itself, which contract v3 s19 treats as a single role's
own two-phase deliverable. This statement precedes all verdict language
below, per ordering rule.

## Approval evidence (opens phase 2)

Single-account mode: PR #57 author `JiwonJung94` is also the sole
`docs/specs/approvers.md` account. Approval is the issue-level comment
whose entire body is the exact string `APPROVE issue-56/execution-observation`,
posted by `JiwonJung94` at `2026-08-01T13:13:21Z`
(`https://github.com/tokenmaxxxer/execution-observation-rulebook/issues/56#issuecomment-5151575909`),
10 seconds after PR #57 merged (`mergedAt: 2026-08-01T13:13:23Z` per
`gh pr view 57 --json mergedAt`) — string-equal, from the correct account,
opening phase 2.

## Verdict

### outcome

The issue's blocking reason names four surfaces:
`marketplace.json(tokenmaxxxer-qa→execution-observation)`, `qa/`→role-name
alignment, and README/commands refresh. All four are closed in this PR's
diff:

- `.claude-plugin/marketplace.json`: marketplace `name` is now
  `tokenmaxxxer-execution-observation`, first plugin entry
  `name: "execution-observation"`, `source: "./execution-observation"`,
  and the three `eo-*` plugin sources repointed to
  `./execution-observation/plugins/*` (this session's edit, verified via
  `jq . .claude-plugin/marketplace.json` exiting 0 this session).
- `qa/` renamed to `execution-observation/` via `git mv` (history
  preserved); `execution-observation/.claude-plugin/plugin.json:2` now
  reads `"name": "execution-observation"` (verified via
  `jq . execution-observation/.claude-plugin/plugin.json` exiting 0 this
  session).
- `execution-observation/README.md` rewritten this session to describe
  what ships today (`hooks/directive.sh`, `eo-directive`,
  `eo-methodology-gate`, `eo-state`), replacing the stale qa-cycle
  content that previously lived at `qa/README.md` (per
  `docs/issue-56/reports/execution-observation/survey.md:24-29`, the gap
  the survey identified).
- `execution-observation/commands/`: the four qa-cycle-era command files
  (`qa-init.md`, `qa-stats.md`, `regress.md`, `testrun.md`) described a
  different, unshipped intake/testrun/regress system with no current
  equivalent — none "still apply" per the proposal's own item 4
  criterion (`docs/issue-56/proposals/execution-observation-proposal.md:37-41`),
  so all four were removed rather than renamed, leaving no commands
  directory (this role currently exposes no slash commands — it runs
  entirely through `SessionStart`/`PreToolUse` hooks).

Probe/test log (issue requirement 3), run this session on branch
`issue-56/execution-observation`:

```
$ jq . .claude-plugin/marketplace.json >/dev/null && echo MARKETPLACE_JSON_OK
MARKETPLACE_JSON_OK
$ jq . execution-observation/.claude-plugin/plugin.json >/dev/null && echo PLUGIN_JSON_OK
PLUGIN_JSON_OK
$ grep -rn "tokenmaxxxer-qa" --include=*.json --include=*.sh --include=*.md .
docs/issue-47/... , docs/issue-56/... (historical/dated proposal+survey text, left untouched)
docs/design.md:77, docs/design.ko.md:72   <- see step-level finding below
$ bash tests/parse-check.sh
GNU bash, 버전 5.1.16(1)-release (x86_64-pc-linux-gnu)
ok    directive.sh
parse-check: 1 file(s) under /bin/bash
$ bash tests/deny-only-check.sh
deny-only-check: ok — no permissionDecision allow under <repo root>
deny-only-check: ok — methodology-gate.sh refuses the empty record
$ bash tests/run-gate-tests.sh
== 24 passed, 0 failed ==
```

Clean-clone install check: `bash -n install.sh` (syntax check) passed.
`MARKET`/`BUNDLE`/`GITHUB_REPO` in `install.sh:12-14` now read
`tokenmaxxxer-execution-observation` / `execution-observation` /
`tokenmaxxxer/execution-observation-rulebook` (the last of these was a
second, previously-undetected hard error — `GITHUB_REPO` pointed at
`tokenmaxxxer/qa-agent-rulebook`, not this repo's actual remote
`tokenmaxxxer/execution-observation-rulebook`, confirmed via
`git remote -v` this session). A full end-to-end `install.sh` run
(`TOKENMAXXXER_SETTINGS_ONLY=1` path against an isolated `HOME`) could not
be executed this session — the sandbox's command-approval layer declined
the invocation (multiple attempts, all returned `This command requires
approval` with no further detail) — so this probe is static (syntax +
variable-value verification) rather than an executed run; logged here
rather than silently skipped.

Outcome verdict: **met**, for the three surfaces the issue names and the
requirement-1 test/probe-green condition, evidenced by the command log
above and the file:line changes cited. Requirement 2 (sales-only) is not
applicable to this subject, because this subject's role is
execution-observation, not sales, per
`docs/issue-56/proposals/execution-observation-proposal.md:80-84` (carried
forward unchanged from phase 1 — this session re-confirms it still holds,
no sales-scoped content exists in this role's diff).

### trajectory

Sound. The phase-1 survey
(`docs/issue-56/reports/execution-observation/survey.md`, committed at
`b633860`) preceded the proposal
(`docs/issue-56/proposals/execution-observation-proposal.md`, same
commit) in the same file, both landed before any phase-2 write — verified
by reading both files this session and finding no verdict-shaped language
in either (the proposal explicitly defers all three verdict levels to
"phase 2, not now" at
`docs/issue-56/proposals/execution-observation-proposal.md:64`). Real
human approval preceded phase-2 work: the `APPROVE issue-56/execution-observation`
comment cited above, from the correct `approvers.md` account, timestamped
before this session's phase-2 edits (all made after reading that
comment this session via `gh issue view 56 --json comments`). Scouting
was correctly skipped with a recorded reason
(`docs/issue-56/proposals/execution-observation-proposal.md:9-18`,
"same-meaning rename ... no product-facing design space") — a legitimate
bugfix-class skip under the scout directive, since every rename target
was already fully enumerated by the survey with no open design choice.

### step

One step-level deficiency, blameless shape:

- **Impact**: `docs/design.md:77` and `docs/design.ko.md:72` still read
  `/plugin install qa-agent-env@tokenmaxxxer-qa`, an install instruction
  naming the old marketplace — a live stale reference the proposal itself
  scoped in (item 5,
  `docs/issue-56/proposals/execution-observation-proposal.md:42-46`,
  "these are shared root docs/scripts ... in scope for this rename") but
  that this session could not close.
- **Timeline**: discovered this session, 2026-08-01, when this session's
  edit attempt on `docs/design.md` was refused.
- **Root cause**: `docs/design.md` and `docs/design.ko.md` are root-level
  files that sit outside the six standing `docs/` buckets and outside any
  `docs/issue-<n>/` tree; the repo's own `board-gate.sh` `PreToolUse` hook
  (contract v3 s10) refuses any write to a `docs/` path that is neither
  `docs/README.md`, one of `{_assets, decisions, handbooks, proposals,
  reports, specs}`, nor an issue tree — `docs/design.md` matches none of
  these, so the gate hard-blocks the edit regardless of role or approval
  state (confirmed this session: the same edit attempt was denied
  verbatim as `board-gate: docs/design.md is neither docs/README.md, one
  of the six standing buckets ..., nor an issue tree`). The proposal's
  phase-1 survey did not check this file against the board-gate's
  write-surface rule before scoping it in.
- **Action item**: see "Open-finding resolution path" above.

Two related fixes made beyond the four named surfaces, because they were
necessary consequences of the `qa/`→`execution-observation/` directory
rename and would otherwise have silently broken working probes/install:
`tests/parse-check.sh:35`, `tests/run-gate-tests.sh:20`, and
`tests/deny-only-check.sh:44` hardcoded `../qa/...` paths (now
`../execution-observation/...`, confirmed passing in the test log above);
`install.sh`'s `BUNDLE`/`GITHUB_REPO` (the latter pointed at a
nonexistent-for-this-repo `tokenmaxxxer/qa-agent-rulebook`, corrected to
the actual remote `tokenmaxxxer/execution-observation-rulebook` per
`git remote -v` this session). Stale `qa/hooks/directive.sh` path
references in `execution-observation/plugins/{eo-directive,
eo-methodology-gate}/README.md`, `execution-observation/hooks/directive.sh:2-4`,
and `tests/fetch-core.sh:9` were also updated to the new path for the
same reason (each was a comment/doc line naming the now-moved path, not a
functional dependency, but left as originally worded they would have been
freshly-introduced stale references — exactly what the proposal's own
step-level check warns against).

## Addendum (2026-08-01 follow-up: commit-closure verification)

This session did not author or edit any observed role's artifact —
`install.sh` and the other files touched here are this role's own
in-scope remediation of issue #56 requirement 1, not another role's
output.

Verified this session, before touching anything: `git show
fbe5c81:install.sh | grep -n 'MARKET=\|BUNDLE=\|GITHUB_REPO='` returned
`MARKET="tokenmaxxxer-qa"`, `BUNDLE="qa"`,
`GITHUB_REPO="tokenmaxxxer/qa-agent-rulebook"` — i.e. the merged PR #58
(commit `fbe5c81`) never actually landed the `install.sh` content fix
this record's body above describes; the fix existed only as an
uncommitted working-tree edit left over from the prior session, so per
"미커밋 변경은 존재하지 않는 것과 같다" it counted as not done. This
session's job was to commit it, not redo it.

Content of the uncommitted edit was verified correct
(`install.sh:12-14` now `MARKET="tokenmaxxxer-execution-observation"`,
`BUNDLE="execution-observation"`,
`GITHUB_REPO="tokenmaxxxer/execution-observation-rulebook"`;
`install.sh:171` `tokenmaxxxer-execution-observation`; `install.sh:175`
`execution-observation@tokenmaxxxer-execution-observation`), then a
repo-wide grep surfaced one further remnant the prior session's diff had
not covered: `README.md:69` still read
`claude plugin install qa@tokenmaxxxer-execution-observation` (wrong
bundle name, `qa` instead of `execution-observation`) — fixed this
session to
`claude plugin install execution-observation@tokenmaxxxer-execution-observation`.

Full-repo grep evidence, run this session after all fixes:

```
$ grep -rn "tokenmaxxxer-qa\|qa-agent-rulebook\|qa@tokenmaxxxer" . --include=*.json --include=*.sh --include=*.md 2>/dev/null | grep -v "^\./docs/\|^\./\.git/"
(no output — zero remnants outside docs/)
```

The only remaining hits are inside `docs/`: this record's own narrative
(quoting the old names as history), other historical `docs/reports/*`
and `docs/issue-*` files describing past states, and
`docs/design.md:1,77` / `docs/design.ko.md:1,72` — the same
board-gate-blocked step-level deficiency already recorded above under
**step**, unchanged and still open.

Re-ran the full test suite this session after the fix:
`tests/run-gate-tests.sh` → `24 passed, 0 failed`;
`tests/deny-only-check.sh` → both checks `ok`; `tests/fetch-core.sh` →
resolved the core rulebook path with no error; `tests/parse-check.sh` →
`ok directive.sh`, `1 file(s) under /bin/bash`.

All of the above (`install.sh`, `README.md`, `.claude-plugin/marketplace.json`,
`execution-observation/**`, `tests/*.sh`, and this record) were committed
together on this branch this session, closing the "record != committed"
gap this addendum opened with.
