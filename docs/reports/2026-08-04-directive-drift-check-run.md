---
proposal: docs/proposals/2026-08-04-directive-drift-check.md
---

# Run record — directive-drift-check

Records the actual runs performed to close out
`docs/proposals/2026-08-04-directive-drift-check.md`: the clean-tree runs
(steps 6-7) and the three deliberate-drift regressions (step 8).

## Clean-tree runs

### `directive-drift-check.sh`, standalone

```
$ qa-cycle/hooks/tests/directive-drift-check.sh
directive-drift-check: undeclared subjects (informational, not a failure):
  - transition (none)->observed
  - transition parked-unreproducible->observed
  - transition re-verifying->verified-fixed
  - transition re-verifying->reproducing

directive-drift-check: passed — no directive claim mismatches the gate's declared facts.
```

Exit code: `0`.

The four undeclared subjects are exactly the four rows
`docs/reports/2026-08-04-hunt-directive-drift-check.md` identified as
having no owning prose in any directive today (the bootstrap row,
`parked-unreproducible -> observed`, and both `re-verifying` rows). They
are printed, not failed on, per the proposal's rewritten completeness
rule — no directive was made to declare coverage of these just to turn
the check green.

### `run-gate-tests.sh`, full suite

```
$ qa-cycle/hooks/tests/run-gate-tests.sh
...
=== tally: 38 passed, 0 failed (of 38 cases) ===

=== directive-drift-check ===
...
=== directive-drift-check: passed ===
```

Exit code: `0`. All 38 pre-existing fixture cases pass with observed exit
codes identical to before the `TABLE`/`FIELDS` restructuring — the
restructuring and the addition of `--dump-facts` changed no enforcement
decision. `directive-drift-check.sh` now runs as the suite's final step
and its exit code folds into the suite's own exit code.

## Deliberate-drift regressions (step 8)

Each of the three regressions the proposal names was introduced one at a
time (directive.sh edited, check run, then the file restored from a
backup copy before the next regression), never combined.

### Drift 1: testrun's severity precondition dropped

Changed `testrun/hooks/directive.sh`'s `gate-claim` for
`reproducing->reproduced` from `requires=severity` to `requires=none` —
the exact shape of the drift `docs/reports/2026-08-03-hunt-directive-severity-sync.md`
found by hand.

```
directive-drift-check: FAIL — testrun/hooks/directive.sh: gate-claim for "transition reproducing->reproduced" says requires=none, but the gate enforces requires=severity.
...
directive-drift-check: FAILED — 1 divergence(s) found.
```

Exit code: `1`. Reverted (file restored from `/tmp/testrun-directive.bak`);
re-running the clean-tree check afterward confirmed `0` again.

### Drift 2: bugreport's priority setter stated as agent-set

Changed `bugreport/hooks/directive.sh`'s `gate-claim` for `field priority`
from `actor=human` to `actor=agent` — the setter-symmetry error class.

```
directive-drift-check: FAIL — bugreport/hooks/directive.sh: gate-claim for "field priority" says actor=agent, but the gate enforces actor=human.
...
directive-drift-check: FAILED — 1 divergence(s) found.
```

Exit code: `1`. Reverted; re-run confirmed `0`.

### Drift 3: signoff's gate-covers declares priority, then never claims it

Removed only the `<!-- gate-claim: field priority ... -->` line from
`signoff/hooks/directive.sh`, leaving its `gate-covers` line's
`field:priority` entry in place — a declared-but-unclaimed subject.

```
directive-drift-check: FAIL — signoff/hooks/directive.sh: gate-covers declares "field priority" but no gate-claim for it exists in this file.
...
directive-drift-check: FAILED — 1 divergence(s) found.
```

Exit code: `1`. Reverted; re-run confirmed `0`.

(The proposal separately names a fourth case — removing `priority` from
`gate-covers` *and* the claim in the same stroke — as a named, not
reproduced-here, residual gap: that degrades to the case-3 informational
line, not a failure. Not exercised as a fourth regression fixture here
since it demonstrates the absence of a failure, not its presence; the
proposal's "How you will know it worked" section states this gap in
prose rather than asking for a fixture that proves a negative.)

## Tallies

| Run | Cases | Pass | Fail | Exit |
|---|---|---|---|---|
| `directive-drift-check.sh` (clean tree) | 3 divergence checks, 4 undeclared reports | n/a | 0 | 0 |
| `run-gate-tests.sh` (full suite, includes drift check) | 38 fixture cases + drift check | 38 | 0 | 0 |
| Drift 1 (testrun severity) | 1 | 0 | 1 | 1 |
| Drift 2 (bugreport priority actor) | 1 | 0 | 1 | 1 |
| Drift 3 (signoff declared-but-unclaimed) | 1 | 0 | 1 | 1 |

## Revision run — `--dump-facts` bypass fix

A before-landing warrant hunt (`docs/reports/2026-08-04-hunt-directive-drift-check.md`,
"before-landing — stance 0") reproduced a real bypass: `transition-gate.sh
--dump-facts` exited 0 unconditionally on `$1 == "--dump-facts"`, ignoring
whatever hook payload was on stdin. A `handed-off -> re-verifying` write
(token-gated, human-only, no token present) piped alongside `--dump-facts`
was silently allowed instead of refused.

Fix, in `qa-cycle/hooks/transition-gate.sh`:

- Argument handling is now exact-match and total: zero arguments is the
  normal adjudication path; exactly one argument, the literal
  `--dump-facts`, is the diagnostic path; anything else (a second argument,
  an unrecognized flag, `--dump-facts` alongside another argument) refuses
  (exit 2) rather than falling through to normal operation.
- `--dump-facts` now peeks for a real byte on stdin (a short-timeout,
  single-byte `read`) before dumping. `read -t 0` alone was tried first and
  rejected: it cannot distinguish "a payload is waiting" from "stdin is
  already at EOF," since both report as immediately readable. The
  single-byte peek only ever runs on the `--dump-facts` path, which reads
  no payload either way, so the normal path's single `cat` of stdin is
  untouched.
- No other argument path existed in the gate to audit — `$1` was the only
  branch point on argv before this fix, and it is now the only one after.

Harness cases added to `qa-cycle/hooks/tests/run-gate-tests.sh` (cases
31–34): the hunt's exact reproduction (`--dump-facts` with the
`handed-off -> re-verifying` payload on stdin, no token — now refuses);
`--dump-facts` with a second argument (refuses); an unrecognized flag alone
(refuses); `--dump-facts` standalone with no stdin payload (still allows
and still emits the facts).

Run:

```
bash qa-cycle/hooks/tests/run-gate-tests.sh
```

Tally: `42 passed, 0 failed (of 42 cases)`. `directive-drift-check.sh`
(invoked as the harness's final step, same clean tree): passed, exit 0.

The hunt's reproduction, re-run standalone after the fix:

```
printf '%s' "$payload" | QA_WORKSPACE="$WS" bash qa-cycle/hooks/transition-gate.sh --dump-facts
echo "exit=$?"
```

now refuses with `exit=2` (observed), where the payload is the same
`handed-off -> re-verifying`, no-token write from the hunt record — instead
of the prior silent `exit=0` allow.

## What this check does not cover

Stated plainly, matching the proposal's own scope line: this check
compares structured claims (`gate-claim`, `gate-covers`) against declared
enforcement (`--dump-facts`). It cannot judge whether a directive's
surrounding prose is good advice, correctly explains *why* a precondition
exists, or is otherwise well-written — a green check here is not a
correctness claim about directive quality. It also cannot catch a
directive quietly withdrawing a `gate-covers` declaration it used to make
(see Drift 3's note above); that is an ownership withdrawal, not a
claim/fact mismatch, and this check does not adjudicate it.
