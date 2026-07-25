---
proposal: docs/proposals/2026-08-05-target-declaration.md
---

# Hunt record — target-declaration

## after-proposal — stance 1: assume this change and another plugin's rule cancel each other — find the pair

Verdict: FINDING — the new `target` precondition is placed only on the `observed -> reproducing` row, but `reproducing` has a second, pre-existing zero-requirement entry point (`re-verifying -> reproducing`, `requires: []`) that the proposal never touches, so an item can reach `reproducing` — and testrun can run a full session against it — without `target.md` ever having existed, silently defeating the proposal's own stated intent ("nothing checks a reproduction was run against the target the user meant").
Kind: design-error
Seed: docs/proposals/2026-08-05-target-declaration.md item 4 ("Add `\"target\"` to the `requires` list on the `observed -> reproducing` row ... exactly the way `severity` already gates `reproducing -> reproduced`") plus qa-cycle/hooks/transition-gate.sh TABLE, row `{"from": "re-verifying", "to": "reproducing", "actor": "agent", "requires": []}`.

### Reproduce
```
WS=/tmp/target-hunt-ws
mkdir -p "$WS/projects/acme-app"
cat > "$WS/projects/acme-app/state.md" <<'STATE'
---
item: BUG-1
state: re-verifying
---
STATE
NEW_CONTENT='---
item: BUG-1
state: reproducing
---
'
PAYLOAD=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'$WS/projects/acme-app/state.md','content':'''$NEW_CONTENT'''}}))")
echo "$PAYLOAD" | QA_WORKSPACE="$WS" bash qa-cycle/hooks/transition-gate.sh
ls "$WS/projects/acme-app"   # note: no target.md anywhere in the workspace
```

### Observed
```
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "qa-cycle: item BUG-1: re-verifying -> reproducing is a transition the spec permits from its current state."}}
```
exit 0 — the write is allowed, `state.md` now records BUG-1 in `reproducing`, and `target.md` does not exist anywhere under the workspace. The proposal's `target` precondition (mirroring how `severity` gates `reproducing -> reproduced` by checking `row["requires"]` generically per-row) is attached to the `observed -> reproducing` row only; `re-verifying -> reproducing` is a distinct row in the same `TABLE` with `requires: []` and is completely unaffected, even though it lands the item in the exact same `reproducing` state that `target.md` is meant to anchor every reproduction to.

### Expected
Either every row whose `to` is `reproducing` should carry the same `target` precondition (so `re-verifying -> reproducing` also refuses without a valid `target.md`), or the proposal should explicitly say why the regression-retest path is exempt. As written, an item parked in `re-verifying` (e.g. a failed regression re-check via `regress`) re-enters `reproducing` and can be worked by `testrun` with zero target declaration ever required — the exact gap item 4's own justification ("anchors every later reproduction to it") claims to close.
