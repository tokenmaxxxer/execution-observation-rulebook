---
proposal: docs/proposals/2026-07-27-gate-shlex-parse-failure-deny.md
---

# Hunt record — gate-shlex-parse-failure-deny

## after-proposal — stance 3: rule-cannot-hold/state nothing maintains

Verdict: FINDING — the proposed fallback regex `re.search(r'(?:^|\s)git\b.*?\bcommit\b', cmd)` does not match across newlines (Python's `.*?` excludes `\n` unless `re.DOTALL` is set), so a multi-line/line-continued `git ... commit` invocation with an unterminated quote falls through the heuristic to `False` — i.e. it fails open exactly the way the proposal exists to prevent.
Kind: design-error
Seed: docs/proposals/2026-07-27-gate-shlex-parse-failure-deny.md — the "conservative fallback heuristic" `re.search(r'(?:^|\s)git\b.*?\bcommit\b', cmd)` in section "What will be done" item 1, described as "allowing intervening flags/whitespace" between `git` and `commit`.

### Reproduce
```
python3 - <<'PY'
import re, shlex
cmd = 'git \\\n  commit -m "fix: the user\'s edge case'
print("raw command:\n", cmd)
try:
    shlex.split(cmd)
    print("shlex parsed OK (unexpected)")
except ValueError as e:
    print("shlex.split raises ValueError as expected:", e)

m = re.search(r'(?:^|\s)git\b.*?\bcommit\b', cmd)
print("proposal heuristic match:", m)
PY
```

### Observed
```
shlex.split raises ValueError as expected: No closing quotation
proposal heuristic match: None
```
The regex fails to detect the `git ... commit` shape solely because `git` and `commit` are separated by a line-continuation newline (a plain, unremarkable shell idiom — not adversarial), so `is_git_commit_invocation()` would return `False` under the proposed fix and the command falls through to `allow()`, silently skipping the §13 trailer check for a real, unparseable commit attempt.

### Expected
Per the proposal's own stated intent ("allowing intervening flags/whitespace" between the `git` and `commit` tokens), a newline is whitespace and should not defeat the heuristic; the fallback should deny (treat as a commit) here just as it does when `git` and `commit` are separated by a single space. The regex needs `re.DOTALL` (or `[\s\S]*?` in place of `.*?`) to hold as specified.

## before-landing — stance 4: write-set-cannot-carry-the-work

Verdict: NO FINDING
Seed: branch `gate-shlex-parse-failure-deny` (commit d884f38, now merged into main at 3de87b2) vs main — is_git_commit_invocation() fallback heuristic in trailer-gate.sh and handbook-trigger-gate.sh; declared write set: qa-cycle/hooks/trailer-gate.sh, qa-cycle/hooks/handbook-trigger-gate.sh, qa-cycle/hooks/tests/run-procedure-gate-tests.sh, qa-cycle/.claude-plugin/plugin.json.

Checked: grep for other copies of is_git_commit_invocation() in this repo (none found outside the two declared files); confirmed the second shlex.split() re-parse in trailer-gate.sh (item 3 of the proposal) is guarded as described within the same declared file; ran qa-cycle/hooks/tests/run-procedure-gate-tests.sh directly — all 28 cases (including the new unterminated-quote and multi-line cases) pass; checked qa-agent-env/.claude-plugin/plugin.json and .claude-plugin/marketplace.json for a pinned qa-cycle version that the declared plugin.json bump might miss (none — dependencies are listed by name only, unversioned). The declared write set fully carries the described work; no gap found.
