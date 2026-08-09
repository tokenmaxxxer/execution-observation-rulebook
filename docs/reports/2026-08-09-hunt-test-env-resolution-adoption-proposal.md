---
proposal: docs/issue-67/proposals/test-env-resolution-adoption-proposal.md
---

# Hunt record — test-env-resolution-adoption-proposal

## after-proposal — stance 4: assume the write set cannot carry this work — find the path the build will need that the proposal does not list.

Verdict: NO FINDING
Seed: docs/issue-67/proposals/test-env-resolution-adoption-proposal.md (frozen write set: tests/fetch-core.sh, tests/run-gate-tests.sh, docs/handbooks/execution-observation-plugins.md)
cap_seconds: 60
tier: docs-only-diff
diff_stat_lines: 204
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:05:00Z

Checked for a consumer outside the frozen write set that depends on the current exit-code contract of tests/fetch-core.sh / tests/run-gate-tests.sh (would need to change alongside them but is not listed): no CI workflow files exist anywhere in the repo (find for *.yml/*.yaml outside docs/ returns nothing), no Makefile, install.sh does not reference either script, and README.md's "Run the checks" section only invokes run-gate-tests.sh directly without branching on its exit code. tests/stub-check.sh exists in the tree (contradicting the proposal's Out-of-scope claim that it is "absent from the current tree" — it was added in commit cfe1c34, `ls tests/stub-check.sh` confirms it is present) but it does not call fetch-core.sh or resolve CLAUDE_PLUGIN_ROOT_CORE itself (`grep -n "fetch-core\|CLAUDE_PLUGIN_ROOT_CORE" tests/stub-check.sh` is empty), so it has no dependency on the SKIP contract being adopted and is not a build path the proposal silently omits. No other script greps or branches on run-gate-tests.sh's current exit 2 for unresolved core. Found no reproducible missing path.
