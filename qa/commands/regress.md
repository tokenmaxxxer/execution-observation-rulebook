---
description: Turn a confirmed, fixed bug into a regression test — adopted only if it fails on the bug commit and passes stably on the fix
argument-hint: "[issue URL | run-record failure reference]"
---

Build and gate a regression test for: $ARGUMENTS

A regression test earns its place only by proving it would have caught the
bug it targets. Anything that can't prove that gets discarded — a test that
verifies nothing is debt with a green checkmark.

## 1. Resolve the bug

Resolve the subject's QA record area (`docs/issue-<n>/reports/qa/`
in the target repo). The argument is an issue URL/number or a run-record failure
reference; either way, find the failure entry in
`docs/issue-<n>/reports/qa/runs/` (grep
for the issue URL, or match the failure description). From it take:

- **bug commit** — the record's `app: <commit>` line. No commit recorded →
  say so and stop; the gate cannot run.
- **the symptom** — what was done, expected vs actual, the evidence. This is
  what the test must assert.

## 2. Resolve the fix commit

The commit that closed the issue (`gh issue view --json closedByPullRequests`
/ the linked commit); if the fix can't be isolated, use the target's current
HEAD. Sanity check: the fix commit must differ from the bug commit —
otherwise the bug isn't fixed yet; say so and stop.

## 3. Write the test

One test, in the profile's `tests:` framework, asserting the exact symptom
from the run record (the reproduction steps become the arrange/act, the
expected behavior becomes the assert). Save it under
`docs/issue-<n>/reports/qa/regress/` — qa's own record area, committed
to the target repo, never mixed into the target's own application/test tree.
Name it after the issue (e.g. `regress_<issue-number>_<slug>`).

## 4. The gate — all three checks, in order

Run each check in a temp worktree of the target: `git worktree add <tmp>
<commit>`, **copy the test file into the worktree** (it exists only under
qa's own record area, not in the target's own tree at the bug/fix commits),
prepare the environment (install deps per the profile's
`tests.ci` conventions), run the test, tear the worktree down after. If the
environment cannot be prepared at some commit, that is `BLOCKED`, not a
failed check — record `REGRESS-BLOCKED(<reason>)` in the run record and stop;
the test is neither adopted nor condemned.

1. **Fails on the bug commit.** Worktree at the bug commit → the test must
   **fail**. A pass means it doesn't actually detect the bug.
2. **Passes on the fix commit.** Worktree at the fix commit → the test must
   **pass**.
3. **Stable.** Repeat check 2 until the test has passed k=5 times total —
   **all** of them. A test that is flaky at birth is discarded, not
   quarantined.

## 5. Adopt or discard

- **All three pass** → adopt: keep the test in
  `docs/issue-<n>/reports/qa/regress/`, add
  a one-line runner note if the suite needs one (how to invoke it against a
  checkout), append `REGRESS-ADOPTED(<test path>)` to the run-record failure
  entry, and commit that in the target repo. From now on every `/testrun`
  executes it.
- **Any check fails** → discard: delete the test file, append
  `REGRESS-DISCARDED(passed-on-bug-commit | failed-on-fix | flaky <n>/<k>)`
  to the run-record failure entry. Nothing else persists — the attempt record
  IS the value.

Report in a few lines: bug commit, fix commit, the three check results, and
the verdict (adopted at <path> / discarded because <reason> / blocked).

The same worktree mechanism doubles for `git bisect` when a regression
surfaces later with an unknown breaking commit: the adopted test is the
bisect predicate.
