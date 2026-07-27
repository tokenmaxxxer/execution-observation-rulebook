---
status: landed
files:
  - qa-cycle/hooks/trailer-gate.sh
  - qa-cycle/hooks/handbook-trigger-gate.sh
  - qa-cycle/hooks/tests/run-procedure-gate-tests.sh
  - qa-cycle/.claude-plugin/plugin.json
---

## Intent

`is_git_commit_invocation()` in both `qa-cycle/hooks/trailer-gate.sh` and `qa-cycle/hooks/handbook-trigger-gate.sh` calls `shlex.split(cmd)` and, on a `ValueError` (an unparseable command string — e.g. an unterminated quote), returns `False`:

```python
def is_git_commit_invocation(cmd):
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        return False
    ...
```

Both call sites then treat `False` as "not a commit, nothing to enforce" and allow the tool call through (`allow()` at trailer-gate.sh:107-108; the analogous check at handbook-trigger-gate.sh:105). This means `git commit -m "unterminated` — a string that is in fact attempting a commit — currently exits 0 with no trailer/handbook enforcement, contradicting the documented fail-closed contract: an inability to determine whether a command is a commit must not be treated as "not a commit."

The fix: a shlex parse failure during commit detection must not fail open. If the raw, unparsed command string contains the token `git` followed later by the token `commit` (checked via a cheap, non-shlex substring/regex heuristic over the raw string — not a shell-accurate parse, just a conservative smell test), treat the invocation as a commit and apply the same enforcement as a normally-parsed commit. Only when that heuristic also finds no evidence of a git-commit shape does a parse failure fall through to allow — because a command shlex cannot parse and that gives no textual hint of `git ... commit` is far more likely to be an unrelated malformed command than a disguised commit.

## Constraints

- Existing behavior for commands that parse cleanly with `shlex.split` is unchanged — this only touches the `except ValueError` path.
- Deny means exit 2, matching the gates' existing deny convention.
- No new dependencies; the heuristic uses only `re`/string operations already available via the existing `re` import.
- The same fix, structurally identical, must land in both `trailer-gate.sh` and `handbook-trigger-gate.sh` since both embed independent copies of `is_git_commit_invocation()`.
- The second `shlex.split(command)` call in trailer-gate.sh (line 183, used after commit detection to extract trailer content) is out of scope here except to confirm it is unreachable when the heuristic fallback fires without a successful parse — see "what will be done" below for how that is handled.

## What will be done

1. In both gate scripts, wrap the `shlex.split(cmd)` call in `is_git_commit_invocation()` in `try`/`except ValueError` as today, but on failure do not unconditionally return `False`. Instead apply a conservative fallback heuristic against the raw `cmd` string: a case-sensitive regex/substring check for a `git` token followed later (allowing intervening flags/whitespace, including newlines) by a `commit` token. The raw `cmd` string may itself be multi-line (e.g. a backslash-continued shell command), so the regex must match across newlines — use `re.search(r'(?:^|\s)git\b.*?\bcommit\b', cmd, re.DOTALL)`, or equivalently a whitespace-token scan of the raw string that does not rely on `.` excluding `\n`. If it matches, return `True` (treat as a commit invocation); otherwise return `False` (fall through to allow, as today).
2. Emit a stderr warning whenever the fallback path is taken (parse failed), regardless of which way the heuristic resolves, so a human/agent reviewing gate output can see that detection degraded to the heuristic rather than the real parse.
3. In `trailer-gate.sh`, the downstream code that calls `shlex.split(command)` again at line 183 to extract trailer content assumes a successful parse already happened. Guard that second call the same way: if it also raises `ValueError` (it will, since the same unparseable string is being re-split), treat the trailer as absent/invalid rather than crashing, which — combined with `is_git_commit_invocation` now returning `True` — causes the gate to deny for missing/unverifiable trailer, the correct fail-closed outcome.
4. Update `qa-cycle/hooks/tests/run-procedure-gate-tests.sh` with new cases:
   - An unterminated-quote commit command (e.g. `git commit -m "unterminated`) without a trailer is denied (exit 2).
   - An unterminated-quote command with no `git`/`commit` shape (e.g. `echo "unterminated`) is still allowed (exit 0), confirming the fallback doesn't over-deny unrelated malformed commands.
   - A multi-line unterminated-quote commit command, where `git` and `commit` are split across a backslash-continuation newline (e.g. `git \` on one line followed by `commit -m "unterminated` on the next), without a trailer, is denied (exit 2) — confirming the fallback regex matches across newlines and does not fail open on multi-line commit invocations.
   - The full existing suite remains green.
5. Bump `qa-cycle/.claude-plugin/plugin.json` version from `0.1.2` to `0.1.3` (patch bump) to reflect the gate behavior fix.

## Out of scope

- Any other repo's gates or copies of similar commit-detection logic outside `qa-cycle/hooks/trailer-gate.sh` and `qa-cycle/hooks/handbook-trigger-gate.sh`.
- Making the fallback heuristic shell-accurate (e.g. handling quoting/escaping precisely); it only needs to be conservative enough not to fail open on a real commit attempt.
- Any change to gate behavior for commands that parse successfully.

## Success criteria

- The reproduction `git commit -m "unterminated` (no trailer) now exits 2 in both gates instead of exit 0.
- The multi-line unterminated-quote reproduction (`git \` continued onto a next line with `commit -m "unterminated`, no trailer) also exits 2 in both gates, confirming the fallback heuristic matches across newlines rather than only on a single line.
- The new and pre-existing cases in `qa-cycle/hooks/tests/run-procedure-gate-tests.sh` all pass.
- `qa-cycle/.claude-plugin/plugin.json` version reflects the patch bump.

## What did not work

- The "unterminated-quote command with proper trailers → allowed" case for `trailer-gate.sh` could not be built as a literal genuinely-unparseable command carrying a valid `Subject:`/`Kind:` trailer: `shlex.split` is called a second time (line 183+) on the exact same raw `command` string to extract the message, so if the first `shlex.split` call raises `ValueError`, the second call raises the identical `ValueError` — there is no way for an unparseable command to yield a message that gets successfully re-tokenized. The proposal's own step 3 confirms this: a second-parse failure is treated as "trailer absent/invalid" and denies. Implemented instead as the closest faithful analog: an unterminated-quote commit is **allowed** when no qa unit is in-progress (trailer not required), because the gate's `trailer_required` check and its `allow()` short-circuit run *before* the message is ever parsed for a trailer, so the parse failure never gets a chance to matter. This preserves the intended coverage (parse failure does not cause an incorrect deny when enforcement doesn't apply) without claiming an impossible test scenario.
