---
proposal: docs/proposals/2026-07-27-qa-records-in-target-repo.md
---

# Hunt record — qa-records-in-target-repo

## after-proposal — stance 4: write-set-cannot-carry-the-work

Verdict: FINDING — the proposal's file list omits the actual executable
gate test suite (only lists `qa-cycle/hooks/tests/README.md`), leaving a
hardcoded exit-2-on-unset-QA_WORKSPACE assertion that the proposal's own
success criteria require to no longer hold.
Kind: design-error
Seed: proposal frontmatter `files:` list (~25 paths) for repointing QA's
primary record store from $QA_WORKSPACE to docs/reports/records/<subject>/qa/**;
transition-gate.sh is listed and is to stop exiting 2 on unset $QA_WORKSPACE.

### Reproduce
```
cd /home/jwjung/tokenmaxxxer/qa-agent-rulebook
grep -n 'QA_WORKSPACE unset' qa-cycle/hooks/tests/run-gate-tests.sh
grep -n 'run_case "qa-workspace-unset"' qa-cycle/hooks/tests/run-gate-tests.sh
bash qa-cycle/hooks/tests/run-gate-tests.sh 2>&1 | tail -5
```

### Observed
`qa-cycle/hooks/tests/run-gate-tests.sh` (1198 lines, not in the proposal's
`files:` list — only its README.md sibling is) contains, at line 430:
`run_case "qa-workspace-unset" 2 "" "$payload"`, a case that feeds the gate
a payload targeting `/nonexistent/projects/owner-repo/state.md` under an
unset `QA_WORKSPACE` and asserts the gate refuses with exit code 2. Running
the suite today confirms it passes as part of "85 passed, 0 failed". The
proposal's "What will be done" explicitly commissions
`qa-cycle/hooks/transition-gate.sh` to stop exiting 2 on unset
`$QA_WORKSPACE` and move its precondition check to the in-repo `qa/**`
subtree — which this test case, left untouched because it's outside the
write set, would then fail against (or worse, silently keep asserting a
refusal-on-unset-workspace contract the gate no longer implements, if the
fixture path happens to still not exist for unrelated reasons).

### Expected
The write set should include `qa-cycle/hooks/tests/run-gate-tests.sh` (and
`qa-cycle/hooks/tests/run-procedure-gate-tests.sh`, the other executable
test file in the same directory, to be checked for the same pattern) so the
test suite's assertions are updated in lockstep with the gate behavior the
proposal changes, rather than the change landing against a test file that
still encodes the old contract as a passing case.
