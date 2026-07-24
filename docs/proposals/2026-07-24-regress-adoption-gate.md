# Proposal: regress ships with an adoption gate — and moves ahead of testplan

*2026-07-24. Spec frozen ahead of implementation; the roadmap plugin builds
to this or argues here first.*

## Problem

A regression test generated from a confirmed bug is only worth keeping if it
would actually have caught that bug. Coverage-raising tests that assert
nothing real are debt with a green checkmark — the failure mode Meta's ACH
work identified and solved with mutation-style validation: a test earns its
place by killing the fault it was written for.

## The gate

`/regress <issue>` writes a test in the profile's `tests:` stack, then must
pass all three checks before the test is committed:

1. **Fails on the buggy commit.** Check out the commit recorded in the run
   record that filed the bug (`app: <commit>`) into a temp worktree
   (`git worktree add`), run the new test there — it must **fail**.
2. **Passes on the fixed commit.** Run the same test on the commit that
   closed the issue (or current HEAD if the fix isn't isolated) — it must
   **pass**.
3. **Stable.** Repeat check 2 k times (default k=5) — **all** pass. A test
   that flakes at birth is rejected, not committed-and-quarantined.

Fail any check → the test is discarded and the attempt recorded in the run
record; nothing lands. The same worktree mechanics serve the roadmap's
`git bisect` duty — one mechanism, two uses.

Prerequisite already in place: run records carry the commit tested, so check
1 needs no new bookkeeping.

## Roadmap order: regress before testplan

The original order was testplan → regress → signoff. Flipped, because:

- **regress has proven ROI and a built-in oracle** (the bug itself — the
  gate above is self-adjudicating). testplan's output quality is hard to
  judge without exactly the kind of instrument bench/ is only starting to be.
- **Trust compounds from caught regressions.** `/qa-stats` measures whether
  filed issues get fixed; a regression suite that provably guards those
  fixes is the fastest way to make the stack's value visible.
- testplan loses nothing by waiting — testrun already runs plan-less.

## Exit criteria

regress graduates from roadmap to plugin when: gate implemented as above,
one real bug → test → gate-pass cycle demonstrated on a bench target, and
the whole flow (`/bug` → fix → `/regress`) documented in its README.
