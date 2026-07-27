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

## before-landing — stance 0: bypassable-gate

Verdict: FINDING — trailer-gate.sh's `git commit` command detector misses `git -C <dir> commit`, silently skipping the §13 Subject:/Kind: trailer requirement
Kind: silent-failure
Seed: docs/proposals/2026-07-27-qa-records-in-target-repo.md — $QA_WORKSPACE mechanism removed entirely, qa-cycle/hooks/trailer-gate.sh re-rooted to the target repo's docs/reports/records/<subject>/qa.md; same command-detection regex (unchanged by the migration) still gates the §13 trailer requirement in the new records tree.

### Reproduce
```
cd /tmp && rm -rf trailer-repro && mkdir trailer-repro && cd trailer-repro
git init -q
mkdir -p docs/specs docs/reports/records/foo/qa
touch docs/specs/role-handoff-contract.md
git add docs/specs/role-handoff-contract.md
git -c user.email=a@a -c user.name=a commit -q -m init
printf 'kind: qa-record\nloop_state: in-progress\n' > docs/reports/records/foo/qa.md
git add docs/reports/records/foo/qa.md

GATE=/home/jwjung/tokenmaxxxer/qa-agent-rulebook/qa-cycle/hooks/trailer-gate.sh

# plain "git commit" (no Subject:/Kind: trailer) — correctly denied
payload='{"tool_name":"Bash","tool_input":{"command":"git commit -m \"land qa record\""}}'
echo "$payload" | CLAUDE_PROJECT_DIR="$PWD" bash "$GATE"; echo "exit=$?"

# identical intent, "git -C <dir> commit" — same missing trailer
payload="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git -C $PWD commit -m \\\"land qa record\\\"\"}}"
echo "$payload" | CLAUDE_PROJECT_DIR="$PWD" bash "$GATE"; echo "exit=$?"
```

### Observed
```
== plain git commit (no trailer) ==
qa-cycle: refused — this commit lands an in-progress qa unit but its message is missing the §13 trailer key(s): Subject:, Kind:. ...
exit=2
== git -C <dir> commit (no trailer) ==
exit=0
```
The regex `\bgit\b(?:\s+-{1,2}\S+)*\s+commit\b` (qa-cycle/hooks/trailer-gate.sh line 74) only tolerates flag tokens of the shape `-X`/`--long` between `git` and `commit`; `-C <path>` is a two-token global option (flag + separate argument), so the argument token breaks the match, `re.search` returns no match, and the gate falls through to `allow()` at line 75 as if the Bash call were not a commit at all — never reaching the staged-set/trailer check.

### Expected
Any invocation that actually runs `git commit` (including `git -C <dir> commit`, `git --git-dir=... commit`, etc.) should be recognized and, when it lands a non-terminal `qa.md`/`qa/**` change, refused (exit 2) unless the message carries the required `Subject:`/`Kind:` trailer — matching the plain `git commit` behavior.
