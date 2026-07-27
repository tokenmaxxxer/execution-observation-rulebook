---
status: landed
files:
  - qa-cycle/hooks/trailer-gate.sh
  - qa-cycle/hooks/handbook-trigger-gate.sh
  - qa-cycle/hooks/tests/run-procedure-gate-tests.sh
---

## Intent

`qa-cycle/hooks/trailer-gate.sh` decides whether a Bash tool call is a `git commit` invocation with a single regex:

```
r'\bgit\b(?:\s+-{1,2}\S+)*\s+commit\b'
```

(`trailer-gate.sh:74`). This matches flag-only global options (`git -x commit`) but not global options that take a **separate argument token** — `git -C <dir> commit`, `git -c k=v commit`, `git --git-dir <path> commit`, `git --work-tree <path> commit`. When the argument token appears before `commit`, the `(?:\s+-{1,2}\S+)*` group cannot consume it (it only matches option-shaped tokens), so the whole pattern fails to match at `commit`, and the hook takes the "any other Bash command passes through" exit — the entire §13 Subject:/Kind: trailer requirement is silently skipped. Reproduced in `docs/reports/2026-07-27-hunt-qa-records-in-target-repo.md`: plain `git commit -m` with a missing trailer is denied exit 2, but `git -C $PWD commit -m` with the identical missing trailer is allowed exit 0.

Commit detection must recognize `git` invocations that carry global options taking a separate argument — `-C <path>`, `-c <k>=<v>`, `--git-dir <path>`, `--work-tree <path>`, and other `-c`-style key=value pairs — as still being `git commit`, so §13 enforcement cannot be bypassed by inserting one of these options before the subcommand.

## Constraints

- Legitimate non-commit git commands (`git -C <dir> status`, `git log`, `git -c core.pager=cat diff`, etc.) must stay allowed — the gate is only about to fire on `commit`.
- Deny semantics are unchanged: a commit that lands an in-progress qa unit without the §13 trailer still exits 2 with the existing deny message; commits that don't match the in-progress-unit condition still pass.
- The fix is detection-only. It must not alter tokenization, message extraction, or trailer-verification logic downstream of the match (`trailer-gate.sh:148` onward), only the up-front decision of "is this worth inspecting at all."
- No new external dependencies; the hook is a single Python-in-shell script and should stay that way.

## What will be done

1. Replace the single flags-then-commit regex at `trailer-gate.sh:74` with a small tokenizer-based check (or an equivalent regex that explicitly accounts for argument-taking global options) that walks tokens after `git`, skips over recognized global options *and* their argument token when the option takes one (`-C`, `-c`, `--git-dir`, `--work-tree`, plus `--namespace`, `-c key=value` combined forms), and asks whether the next non-option token is `commit`.
2. Keep behavior for flag-only global options (`-p`, `--no-pager`, `--bare`, etc.) and for `commit` appearing with no global options at all unchanged.
3. Add test cases to `qa-cycle/hooks/tests/run-procedure-gate-tests.sh`:
   - `git -C <dir> commit -m "..."` with missing §13 trailer → denied exit 2 (the reproduced bypass, now closed).
   - `git -c user.name=x commit -m "..."` with missing trailer → denied exit 2.
   - `git --git-dir <path> commit -m "..."` with missing trailer → denied exit 2.
   - `git --work-tree <path> commit -m "..."` with missing trailer → denied exit 2.
   - Negative control: `git -C <dir> status` and `git -c core.pager=cat log` → pass through untouched (not treated as commit).
   - Positive control: `git -C <dir> commit -m "..."` *with* a valid §13 trailer → allowed exit 0.
4. `handbook-trigger-gate.sh:75` carries the identical commit-detection regex; apply the same tokenizer-based fix there and add the same set of test cases (adapted to that gate's trigger condition) to `run-procedure-gate-tests.sh`.

## Out of scope

Any other gate (this proposal covers `trailer-gate.sh` and `handbook-trigger-gate.sh` only). Changes to trailer format, message extraction, or the qa unit in-progress determination. Any decision record or hunt-report edits beyond what already exists.

## How I will know it worked

The previously-reproduced bypass — `git -C $PWD commit -m "..."` with no §13 trailer while a qa unit is in progress — now denies with exit 2, matching plain `git commit -m` behavior. The full `run-procedure-gate-tests.sh` suite, including the new cases above, passes green. The same bypass against `handbook-trigger-gate.sh` (`git -C $PWD commit ...`) is also closed, with matching test coverage in the same suite.
