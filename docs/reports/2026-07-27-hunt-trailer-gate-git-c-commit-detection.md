---
proposal: docs/proposals/2026-07-27-trailer-gate-git-c-commit-detection.md
---

# Hunt record — trailer-gate-git-c-commit-detection

## after-proposal — stance 1: cancelling-pair with another plugin's rule

Verdict: NO FINDING
Seed: docs/proposals/2026-07-27-trailer-gate-git-c-commit-detection.md — trailer-gate.sh's
commit-detection regex `\bgit\b(?:\s+-{1,2}\S+)*\s+commit\b` (line 74) fails to match
argument-taking global options (`git -C <dir> commit`, `git -c k=v commit`), confirmed by
direct regex test (`git -C dir commit -m x` and `git -c user.name=x commit -m x` both fail
to match; `git --git-dir=/x commit -m x` matches since its value is attached with `=`).
The identical regex/bug exists in `handbook-trigger-gate.sh:75`, and the proposal explicitly
scopes that file out as a separate future proposal. Checked whether the two gates form a
cancelling pair (one's allow overriding the other's deny): `qa-cycle/hooks/hooks.json`
registers both `handbook-trigger-gate.sh` and `trailer-gate.sh` as independent PreToolUse
hooks on the same `Bash` matcher; Claude Code's PreToolUse semantics block a tool call if
*any* matching hook denies (exit 2), so one gate allowing does not cancel another gate's
deny — there is no "allow wins over deny" composition here, only two gates independently
vulnerable to the same bypass in the same direction (both fail open on the same crafted
input), which is duplication, not cancellation. No PreToolUse hooks exist in any sibling
plugin (signoff, stats, bugreport, testrun, regress, intake all register empty
PreToolUse arrays) that could interact with trailer-gate's fix. No cancelling-pair
composition regression reproduced.

## before-landing — stance 2: guard-goes-silent-on-malformed-input

Verdict: FINDING — an unparseable (shlex.split-invalid) `git commit` command string makes `is_git_commit_invocation()` return False, causing the gate to `allow()` (exit 0) silently instead of denying, directly contradicting the script's own documented contract ("an unparseable command ... all DENY (exit 2), never exit 0 silently").
Kind: silent-failure
Seed: branch `trailer-gate-git-c-commit-detection` vs main (517a5c3) — trailer-gate.sh / handbook-trigger-gate.sh new `is_git_commit_invocation()` tokenizer using `shlex.split(cmd)` wrapped in `try/except ValueError: return False`.

### Reproduce
```bash
cd /tmp && rm -rf gate-test && mkdir gate-test && cd gate-test && git init -q
mkdir -p docs/reports/records/unit1/qa
printf 'loop_state: in-progress\n' > docs/reports/records/unit1/qa.md
git add docs/reports/records/unit1/qa.md

GATE=/home/jwjung/tokenmaxxxer/qa-agent-rulebook/qa-cycle/hooks/trailer-gate.sh
python3 -c '
import json
cmd = "git commit -m \"unterminated"
print(json.dumps({"tool_name":"Bash","tool_input":{"command":cmd}}))
' > /tmp/payload.json

CLAUDE_PROJECT_DIR=/tmp/gate-test bash "$GATE" < /tmp/payload.json
echo "EXIT: $?"
```

### Observed
```
EXIT: 0
```
No stderr, no denial — the commit is allowed even though an in-progress qa unit (`docs/reports/records/unit1/qa.md`, `loop_state: in-progress`) is staged and the commit message carries no `Subject:`/`Kind:` trailer.

### Expected
Per the script's own header comment, an unparseable command should DENY (exit 2) fail-closed, the same as a malformed JSON payload or unreadable staged set. Instead `is_git_commit_invocation()` swallows the `shlex.split` `ValueError` and returns `False`, which the caller treats identically to "this Bash command definitely isn't `git commit`" — routing straight to `allow()` and skipping the trailer check entirely.
