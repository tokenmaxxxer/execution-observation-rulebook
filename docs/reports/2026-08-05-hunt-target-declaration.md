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

## before-landing — stance 2: assume this guard goes silent when its own input is malformed — make it go silent

Verdict: FINDING — the 64KB read cap on target.md (`fh.read(1 << 16)`) lets an oversized target.md with two `---` blocks (which is genuinely ambiguous/malformed and should refuse) pass as a single well-formed block and be silently ALLOWed, because the second block is truncated away before the gate ever sees it.

Kind: silent-failure

Seed: `qa-cycle/hooks/transition-gate.sh`, the `target` precondition block starting at line ~503 (`if "target" in requires:`), specifically the read at line 522-523:
```
with open(target_path_real, encoding="utf-8-sig") as fh:
    target_text = fh.read(1 << 16)
```
followed by `parse_blocks(target_text)` and the `len(target_blocks) != 1` check at line 528.

### Reproduce
```bash
WS=/tmp/ws-repro
rm -rf "$WS"
mkdir -p "$WS/projects/myproj/tokens"
cat > "$WS/projects/myproj/state.md" <<'STATEEOF'
---
item: item1
state: observed
---
STATEEOF

python3 -c "
pad = 'x' * 70000
content = '---\nlabel: mytarget\nentry_point: mytarget\n---\n' + pad + '\n---\nlabel: decoy\nentry_point: decoy\n---\n'
open('$WS/projects/myproj/target.md','w').write(content)
"

payload=$(python3 -c "
import json
print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'$WS/projects/myproj/state.md','content':'---\nitem: item1\nstate: reproducing\nevidence: ran mytarget\n---\n'}}))
")

echo "$payload" | QA_WORKSPACE="$WS" bash qa-cycle/hooks/transition-gate.sh
echo "EXIT: $?"
```

### Observed
```
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "qa-cycle: item item1: observed -> reproducing is a transition the spec permits from its current state."}}
EXIT: 0
```
Confirmed via direct parse that the *full* (untruncated) file contains 2 blocks (`len(BLOCK_RE.finditer(full_text)) == 2`), which is exactly the shape the gate's own `len(target_blocks) != 1` check exists to refuse ("Refusing rather than guessing which declaration is meant") — but the gate never sees the second block because its read is capped at 65536 bytes (`len(truncated) == 65536`, `len(BLOCK_RE.finditer(truncated)) == 1`).

### Expected
An oversized/ambiguous target.md with more than one declaration block should refuse the same way a small one with two blocks does (as verified: two small `---`-blocks in target.md correctly produces exit 2, "is not a single well-formed `---`-delimited frontmatter block"). Truncating the read silently converts a would-be refusal into an allow whenever the ambiguity happens to fall past the 64KB boundary.
