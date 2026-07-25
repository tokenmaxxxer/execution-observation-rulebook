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
