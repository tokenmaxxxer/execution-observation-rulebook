---
proposal: docs/proposals/2026-07-27-qa-cycle-enforcement.md
---

# Hunt record — qa-cycle-enforcement

## after-proposal — stance 1: assume this change and another plugin's rule cancel each other — find the pair

Verdict: FINDING — qa-cycle's PreToolUse gate and signoff's write mechanism cancel each other: the gate refuses every agent-attempted human-only transition "regardless of current phase," but the actual write of a Go/No-Go/Shipped-Under-Exception/Confirmed-Defect verdict is necessarily performed by the agent's own tool call (Claude Code has no other actor that executes tool calls), and PreToolUse hook input carries no field distinguishing "human typed /go-no-go and the agent is now recording it" from "agent decided this alone." As specified, the gate therefore refuses signoff's entire reason for existing, with no described bypass.
Kind: composition
Seed: docs/proposals/2026-07-27-qa-cycle-enforcement.md — "qa-cycle... hooks/pretooluse-gate.sh... refuses... anything the table disallows or that is human-only per the decision doc" combined with "Transitions whose Actor is human ... are refused when an agent attempts them, regardless of current phase" (Constraints) and signoff's "the actual verdict is never taken by the agent alone" / "these transitions request a write through qa-cycle, never a direct one" (decomposition section). No field in the PreToolUse hook payload (session_id, transcript_path, cwd, hook_event_name, tool_name, tool_input) records that a human explicitly invoked /go-no-go before this tool call.

### Reproduce
A faithful transcription of the gate's stated logic (refuse any agent tool call whose payload names a human-only transition, unconditionally):
```
input=$(cat)
transition=$(echo "$input" | grep -o '"transition":"[^"]*"' | head -1 | cut -d'"' -f4)
for t in Confirmed-Defect Go No-Go Shipped-Under-Exception; do
  [ "$transition" = "$t" ] && { echo "qa-cycle: refused. '$transition' is human-only... regardless of current phase." >&2; exit 1; }
done
exit 0
```
Fed the tool call that signoff's own `/go-no-go` command must eventually issue to record a human-attested verdict:
```
echo '{"tool_name":"Write","tool_input":{"file_path":"qa-workspace/projects/acme-api/state.md"},"transition":"Go"}' | ./pretooluse-gate.sh
echo "exit code: $?"
```

### Observed
```
qa-cycle: refused. 'Go' is human-only per docs/decisions/2026-07-26-human-gate-over-pipeline-gate.md. An agent may not take this transition, regardless of current phase.
exit code: 1
```
The gate refuses even though a human already ran `/go-no-go` and supplied the verdict — the gate has no way to see that a human triggered this call, and the proposal names no mechanism (token, out-of-band flag, human-only tool) by which signoff's write could ever pass the gate.

### Expected
The proposal's own "How I will know it worked" requires both: agent-initiated human-only transitions refused, AND signoff able to actually record a Go/No-Go verdict a human gave. As written, satisfying the first guarantee makes the second impossible — the proposal needs to specify how the gate recognizes a signoff-mediated write as distinct from an agent's unsupervised attempt (e.g., a separate tool identity, a token in tool_input signoff writes and the gate is allowed to trust, or the gate being scoped to only qa-cycle's own writer and signoff bypassing it entirely), and it does not.

## before-landing — stance 2: assume this guard goes silent when its own input is malformed — make it go silent

Verdict: FINDING — malformed (non-JSON) PreToolUse payload makes transition-gate.sh silently `allow()` instead of refusing, contradicting its own "Fails closed" contract.
Kind: silent-failure
Seed: qa-cycle/hooks/transition-gate.sh (PreToolUse blocking gate)

### Reproduce
```
mkdir -p /tmp/qa-ws/projects/foo-bar
printf -- '---\nphase: intake-scoping\n---\n' > /tmp/qa-ws/projects/foo-bar/state.md
export QA_WORKSPACE=/tmp/qa-ws
echo 'not json at all {{{' | bash qa-cycle/hooks/transition-gate.sh
echo "EXIT:$?"
```

### Observed
`EXIT:0` — the hook allows the tool call through with no stderr message at all, silently, because `json.loads` raising `ValueError` on malformed payload hits `except ValueError: allow()` (line ~54 of the embedded python), which exits 0 unconditionally instead of refusing.

### Expected
Per the header comment ("Fails closed: unreadable/missing/malformed state or token, or an unset QA_WORKSPACE, all refuse (exit 2) rather than allow.") and per the general PreToolUse-gate design, a malformed hook payload — the gate's own primary input — should cause `refuse()` (exit 2), not `allow()`. As written, any caller (or a bug in Claude Code's hook invocation, or an attacker who can influence the JSON stdin) that sends non-JSON on stdin bypasses the entire transition gate silently, permitting illegal phase transitions and token-required writes (e.g. jumping straight to `Go`/`No-Go`) with no message logged.
