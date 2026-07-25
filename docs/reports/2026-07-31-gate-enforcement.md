---
proposal: docs/proposals/2026-07-31-item-axis-enforcement.md
---

# Gate enforcement — item-axis rewrite, harness run record

## What was run

```sh
qa-cycle/hooks/tests/run-gate-tests.sh
```

Run against the rewritten `qa-cycle/hooks/transition-gate.sh` (item-keyed
legality, item-and-transition-bound tokens, reserve-then-finalize
consumption) on branch `enforce/item-axis`, after the harness itself was
extended from 11 to 19 cases: the original 11 re-expressed on the item axis
(project-`phase` fixtures replaced with per-item `---item:`/`state:` blocks
and per-item `tokens/<item>.token` files), plus 8 new cases —
`human-actor-live-token-gone` / `human-actor-consuming-marker-present`
(the reserve step is observable on disk), the retry case
(`consuming-marker-authorizes-retry-of-same-transition`), item-scoped and
transition-scoped replay rejection (cases 12–13), `handed-off`-without-a-
human-trigger (case 14), and the three-step consumption-timing sequence
(case 15) that reproduces
`docs/reports/2026-07-29-hunt-gate-execution-check.md`'s finding end to
end: allow a human-actor write, leave `state.md` unadvanced to model the
write not landing, retry the identical transition and confirm it is still
allowed, then land the write and confirm a *different* subsequent
transition on the same item is refused without a fresh token.

## What came back

```
case: valid-table-permitted-transition | expected: 0 | observed: 0 | ok
case: transition-not-permitted-from-current-state | expected: 2 | observed: 2 | ok
case: human-actor-transition-no-token | expected: 2 | observed: 2 | ok
case: human-actor-transition-matching-token | expected: 0 | observed: 0 | ok
case: human-actor-live-token-gone | expected: absent | observed: absent | ok
case: human-actor-consuming-marker-present | expected: exists | observed: exists | ok
case: consuming-marker-authorizes-retry-of-same-transition | expected: 0 | observed: 0 | ok
case: non-json-stdin | expected: 2 | observed: 2 | ok
case: state-file-absent | expected: 2 | observed: 2 | ok
case: state-file-no-frontmatter | expected: 2 | observed: 2 | ok
case: no-item-block-in-write-body | expected: 2 | observed: 2 | ok
case: qa-workspace-unset | expected: 2 | observed: 2 | ok
case: qa-cycle-disable-override | expected: 0 | observed: 0 | ok
case: token-for-one-item-rejected-for-another | expected: 2 | observed: 2 | ok
case: token-for-one-transition-rejected-for-another | expected: 2 | observed: 2 | ok
case: handed-off-refuses-without-human-token | expected: 2 | observed: 2 | ok
case: consumption-timing-first-allow-write-does-not-land | expected: 0 | observed: 0 | ok
case: consumption-timing-retry-still-allowed | expected: 0 | observed: 0 | ok
case: consumption-timing-marker-does-not-authorize-a-different-transition | expected: 2 | observed: 2 | ok

=== tally: 19 passed, 0 failed (of 19 cases) ===
```

Harness process exit code: `0` (all 19 cases passed on the first run; no
fix-and-rerun cycle was needed for the harness itself — the case-15 sequence
matched the reserve-then-finalize design in
`docs/decisions/2026-07-31-token-consumption-ordering.md` on the first
implementation).

## Observed exit codes, gate script directly

Spot-checked outside the harness by replaying
`docs/reports/2026-07-29-hunt-gate-execution-check.md`'s reproduction
against the rewritten gate (item-axis fixtures substituted for the old
project-`phase` ones): first allow call exits `0` and moves the token to
`tokens/BUG-1.consuming` without touching `state.md`; the immediate retry
against the still-`reproduced` item also exits `0` (previously this
retry exited `2`, the defect); a subsequent different transition attempted
on the same item after the marker's authorized write actually lands exits
`2`, confirming the marker does not outlive the transition it authorized.

## Revision — item id / path containment fix

A before-landing warrant hunt on this same unit
(`docs/reports/2026-07-31-hunt-item-axis-enforcement.md`, "before-landing —
stance 0") found that `transition-gate.sh` built `token_path`/
`consuming_path` from the unvalidated `item:` field with no normalization
and no containment check. An agent could write `item:
../../../../../../../../tmp/evil-item`, plant a self-forged "token" file at
that attacker-chosen path, and the gate would accept it as authorization for
the human-only `reproduced -> handed-off` transition — `capture-verdict.sh`
never ran. This revision closes that bypass in both hooks per
`docs/handbooks/qa-cycle.md` "Item id and project identifier shape": an
allow-list check on the item id and project identifier at the point each is
read, plus an independent resolve-then-contain check on every path built
from either value.

### What was run

```sh
qa-cycle/hooks/tests/run-gate-tests.sh
```

extended from 19 to 24 cases (cases 16–20: the hunt's exact
path-traversal reproduction, a leading-hyphen item id, an item id with a
disallowed character, an over-length item id, and a project identifier
with a disallowed character).

### What came back

```
case: path-traversing-item-id-refused | expected: 2 | observed: 2 | ok
case: item-id-leading-hyphen-refused | expected: 2 | observed: 2 | ok
case: item-id-disallowed-characters-refused | expected: 2 | observed: 2 | ok
case: item-id-over-length-refused | expected: 2 | observed: 2 | ok
case: project-id-disallowed-characters-refused | expected: 2 | observed: 2 | ok

=== tally: 24 passed, 0 failed (of 24 cases) ===
```

Harness process exit code: `0`. First run of the extended harness failed 16
of 19 pre-existing cases with exit `1` (a `NameError: name 'PROJECT_ID_RE'
is not defined` — the allow-list regexes were defined after their first use
in the gate's Python). Fixed by moving the `ITEM_ID_RE`/`PROJECT_ID_RE`
definitions above their use; re-run passed all 24/24.

### Hunt reproduction, replayed directly against the fixed gate

```sh
rm -rf /tmp/ws && mkdir -p /tmp/ws/projects/proj/tokens
ITEM='../../../../../../../../tmp/evil-item'
# ... (state.md write, forged /tmp/evil-item.token, payload as in the hunt record)
QA_WORKSPACE=/tmp/ws bash qa-cycle/hooks/transition-gate.sh < /tmp/payload.json
```

Observed:

```
qa-cycle: refused — the write contains a block with no readable, unambiguous `item:` and `state:` pair. Refusing rather than guessing which item or state is meant.
exit=2
```

Previously (before this revision): `permissionDecision: allow`, exit `0` —
the bypass. Now: refused, exit `2`, and the message does not echo the
attempted item id.

`signoff/hooks/capture-verdict.sh` was spot-checked the same way: a
legitimate `item BUG-1 confirmed defect, hand it off` turn still mints
`tokens/BUG-1.token` (exit `0`); a forged `item
../../../../tmp/evil confirmed defect, hand it off` turn and a leading-hyphen
`item -BUG1 ...` turn both mint no token file anywhere (exit `0`, per this
hook's never-blocks design — "refusal" here means no mint, not a non-zero
exit).
