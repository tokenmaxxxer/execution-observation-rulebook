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
