---
proposal: docs/proposals/2026-07-28-qa-cycle-wiring.md
---

# Hunt record — qa-cycle-wiring

## after-proposal — stance 2: assume this guard goes silent when its own input is malformed

Verdict: FINDING — malformed hook payload JSON causes transition-gate.sh to silently `allow()` the write instead of refusing, contradicting its own documented "fails closed" guarantee.
Kind: silent-failure
Seed: qa-cycle/hooks/transition-gate.sh (proposal reworks this file so "every failure path exits 2 and allow is reached only by affirmative match")

### Reproduce
```
mkdir -p /tmp/ws/projects/proj1
cat > /tmp/ws/projects/proj1/state.md <<'STATE'
---
phase: finding-triage
---
STATE
export QA_WORKSPACE=/tmp/ws
echo 'not-json{{{' | ./qa-cycle/hooks/transition-gate.sh; echo "exit=$?"
```

### Observed
`exit=0` — the hook allows the (undecodable) event through with no stderr message at all, because `json.loads` raising `ValueError` is caught and routed straight to `allow()`:
```python
try:
    event = json.loads(os.environ.get("QA_CYCLE_PAYLOAD", ""))
except ValueError:
    allow()
if not isinstance(event, dict):
    allow()
```
This is unconditional allow — it does not even check whether the tool call in question is a Write/Edit to state.md; any malformed payload for any tool bypasses the gate entirely and silently.

### Expected
Per the script's own header comment ("Fails closed: unreadable/missing/malformed state or token, or an unset QA_WORKSPACE, all refuse (exit 2) rather than allow"), a malformed payload — which is at least as fundamental as a malformed state/token file — should refuse (exit 2), or at minimum the ambiguity of not being able to tell whether this is a state.md write should be resolved by refusing, not by a bare, message-less allow. The proposal's stated goal that "every failure path exits 2 and allow is reached only by affirmative match" is violated here: this is not an affirmative match on tool/path, it's an inability to parse the input at all, and it's currently routed to allow.

## before-landing — stance 2: assume this guard goes silent when its own input is malformed

Verdict: FINDING — `attempted_phase()` in transition-gate.sh treats any content lacking real YAML frontmatter as legitimate so long as it contains a bare `phase: <target>` line anywhere, silently authorizing writes that never actually establish a state.md's frontmatter.
Kind: silent-failure
Seed: commit 6724858, qa-cycle/hooks/transition-gate.sh `attempted_phase()` (only calls `read_frontmatter` when `content.lstrip().startswith("---")`; otherwise searches the raw content with the same `PHASE` regex).

### Reproduce
```
WS=/tmp/scratch-ws   # any workspace dir
mkdir -p "$WS/projects/demo"
cat > "$WS/projects/demo/state.md" <<'STATE'
---
phase: intake-scoping
---
body
STATE

python3 - <<PY > /tmp/payload.json
import json
content = "Some notes about migration.\nphase: session-chartered\nThat was just an example in a bullet list, not real frontmatter.\n"
print(json.dumps({"tool_name":"Write","tool_input":{"file_path": "$WS/projects/demo/state.md", "content": content}}))
PY

QA_WORKSPACE="$WS" bash qa-cycle/hooks/transition-gate.sh < /tmp/payload.json
echo "EXIT: $?"
```

### Observed
```
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "qa-cycle: intake-scoping -> session-chartered is a transition the spec permits from the current phase."}}
EXIT: 0
```
The gate allows the write even though the content carries no `---`-delimited frontmatter at all — the write will leave state.md with no readable `phase:` field per the gate's own frontmatter-only reading in `current_phase()`, yet the gate approved it as a legitimate `intake-scoping -> session-chartered` transition based on a stray line of prose.

### Expected
The comment block above `attempted_phase()` and the module docstring both claim refusal is the default and exit 0 is reached "only via ... after the attempted (from -> to) has been matched against the table" — implying the match is against a real transition declaration, not incidental text. A write whose content does not carry actual YAML frontmatter (the same structure `current_phase()` requires to read state) should be refused as malformed/unparseable, the same way a state.md without frontmatter is refused when read. Instead the malformed-content case is silently treated as an affirmative, well-formed transition.
