# regress

Regression tests with an **adoption gate**. A test generated from a confirmed
bug is only worth keeping if it would actually have caught that bug — a test
that verifies nothing while raising coverage is debt with a green checkmark
(the failure mode Meta's ACH work targeted with mutation-style validation:
a test earns its place by killing the fault it aims at).

## The gate

`/regress <issue | run-record failure>` writes one test in the project's own
test framework (per the intake profile's `tests:`), then must pass all three
checks before adoption:

1. **Fails on the bug commit** — the commit recorded in the run record
   (`app: <commit>`), checked out in a temp `git worktree`, the test copied
   in. A pass here means the test doesn't detect the bug.
2. **Passes on the fix commit** — the commit that closed the issue (HEAD as
   fallback).
3. **Stable** — check 2 repeated to k=5 total passes, no exceptions. Flaky at
   birth = discarded, not quarantined.

Any failure discards the test; only the attempt is recorded
(`REGRESS-DISCARDED(<reason>)` in the run record). Environment trouble at an
old commit is `REGRESS-BLOCKED(<reason>)` — undecided, not condemned.

## The full loop

```
/testrun            # failure found, run record gets app: <commit>
/bug                # filed to the project's tracker
  (dev session fixes it — e.g. via coding-agent-rulebook dispatch)
/regress <issue>    # test written, gated, adopted into projects/<slug>/regress/
/testrun            # every later run executes the regression suite first
```

Adopted tests live in the QA workspace (`projects/<slug>/regress/`), never in
the target repo — `/testrun` runs them against a fresh checkout each run, and
a break is filed like any other confirmed failure. A project that wants the
test in its own CI can take it as an upstream PR.

The same worktree mechanism serves `git bisect` when a regression appears
with an unknown breaking commit: the adopted test is the predicate.

No hook, so no kill switch — a command you don't invoke is off.

Gate demonstrated end-to-end on the bench target (bug → fix → adoption):
[bench/demos/regress-gate-2026-07-24.md](../bench/demos/regress-gate-2026-07-24.md).
Unbenchmarked as of 0.1.0 — the demo proves the mechanism, not the on/off
delta.
