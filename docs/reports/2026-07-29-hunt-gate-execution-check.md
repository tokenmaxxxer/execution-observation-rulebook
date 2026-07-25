---
proposal: docs/proposals/2026-07-29-gate-execution-check.md
---

# Hunt record — gate-execution-check

## before-landing — stance 3: assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — the gate consumes (deletes) the verdict token as soon as it decides to allow a human-actor transition, but nothing ties that consumption to the underlying Write/Edit tool call actually landing on state.md; if the tool call fails or is aborted after the PreToolUse hook returns allow, the token is gone and state.md is unchanged, permanently blocking the legitimate transition until a fresh human signoff is produced.
Kind: design-error
Seed: qa-cycle/hooks/tests/run-gate-tests.sh (case 4/5, "human-actor-transition-matching-token" / "token-replayed"), qa-cycle/hooks/transition-gate.sh (the `os.remove(token_path)` call, and its own comment: "Consumed by the same operation that performs the transition: delete it now, before the write this permission decision is gating is allowed through.")

### Reproduce
```
ws=$(mktemp -d); slug=owner-repo
mkdir -p "$ws/projects/$slug"
printf '%s' $'---\nphase: finding-triage\n---\n' > "$ws/projects/$slug/state.md"
{
  printf 'transition: %s\n' "finding-triage -> Confirmed-Defect"
  printf 'project: %s\n' "$slug"
  printf 'phrase: %s\n' "yes"
} > "$ws/projects/$slug/.verdict-token"

payload=$(python3 -c "import json; print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'$ws/projects/$slug/state.md','content':'---\nphase: Confirmed-Defect\n---\n'}}))")

# Simulate the hook allowing the write, then the actual Write tool call
# never landing (aborted turn, downstream error, another hook denying it,
# etc.) -- state.md is left untouched on purpose to model that.
printf '%s' "$payload" | QA_WORKSPACE="$ws" qa-cycle/hooks/transition-gate.sh; echo "exit=$?"
cat "$ws/projects/$slug/state.md"
ls "$ws/projects/$slug/.verdict-token" 2>&1

# Retry the identical, still-legitimate transition (state.md never advanced):
printf '%s' "$payload" | QA_WORKSPACE="$ws" qa-cycle/hooks/transition-gate.sh; echo "exit=$?"
rm -rf "$ws"
```

### Observed
First call: exit=0 (allow), and the token file is deleted immediately, even though `state.md` still reads `phase: finding-triage` (the write was never actually applied to model a downstream failure). Second call, retrying the exact same still-legal transition against the unchanged state: exit=2, "refused — finding-triage -> Confirmed-Defect is a human-only transition and no verdict token is present ... A person must decide this and state the verdict in their own turn."

### Expected
The gate's own model treats "current phase" (read from state.md) and "token consumed" as a single coupled fact — a token is meant to authorize exactly one transition and be spent by it. But the hook has no way to know whether the write it just permitted will actually succeed (PreToolUse only decides permission; it does not observe or roll back on failure of the subsequent tool call, nor is there any PostToolUse companion that could restore the token). The harness's own case 4/5 pair encodes the intended invariant (token consumed only together with a successful transition, and never reusable) but only ever exercises the case where the write is assumed to have happened; it never runs the case where a hook-permitted write does not land, which is exactly the case that breaks the invariant the token model depends on and that "12/12 passing" was reported to establish.
