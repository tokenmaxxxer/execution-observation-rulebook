# issue-35 current-state survey (coding, phase 1)

## Scope of the sweep
`grep -rniE "wake|WAKES-ON|board|downstream" .` (excluding `.git`) across
the whole repo, then filtered to live rulebook surfaces per the issue:
directive.sh, specs, skills, gate comments, plugin descriptions —
excluding `docs/issue-*`, `docs/proposals/`, `docs/reports/` (historical,
explicitly out of scope).

## What the sweep found

Only one live rulebook file carries routing-side vocabulary:

`qa/hooks/directive.sh:58-65` — the "YOUR RECORD IS THE BOARD" paragraph:

```
YOUR RECORD IS THE BOARD (do not skip this): docs/issue-<n>/reports/qa.md
is the sole phase-2 artifact that matters — research files, surveys, and
proposals are not it. Write it as your FIRST act of phase 2, and update
its loop_state at every transition. A record never committed to the
branch means the work never reached the board. (Measured: a
phase-1-only issue left the board empty.) For the actual wake-routing
rule — which record state summons which role — see
docs/specs/wake-routing.md.
```

Issue-33 already dropped the "WAKES-ON reads ... ONLY" / "no downstream
role can ever be woken" claims and left a filename-only pointer to
`docs/specs/wake-routing.md`. Issue-35 goes further: even that pointer,
and the "board" framing itself ("YOUR RECORD IS THE BOARD", "never
reached the board"), are routing-device vocabulary and must go. The
paragraph should say only: which file to write, when to write it
(first act of phase 2), what to keep current in it (`loop_state`), and
that it must be committed on the branch — nothing about a board, a
pointer to routing canon, or who acts on the record.

`qa/README.md:23` mentions "the blackboard record (`qa.md`)" — this
names the record file itself, not a routing mechanism or a reader; it
does not say who wakes on it or point at wake-routing.md. No change
needed there per the issue's actual ask (routing vocabulary, not every
use of the word "board").

No other live file (`qa/commands/`, `qa/hooks/*` besides directive.sh,
any `.claude/` config, skill files, gate comments) contains "wake",
"WAKES-ON", "board", or "downstream" per the same grep — confirmed no
`directive.sh` exists for a `coding` role inside this repo (this
session's own coding directive is supplied by an external plugin root,
outside this repo's tree, and out of scope for an in-repo PR).

## Scout skip record
Skipped — spec leaves no design decision open. This is a mechanical
vocabulary-stripping edit inside an already-identified paragraph
(continuation of issue-33's routing-removal line of work); there is no
product-shaped or best-in-class field to survey.
