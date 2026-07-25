---
proposal: docs/proposals/2026-08-02-severity-priority-axes.md
---

# Hunt record — severity-priority-axes

## after-proposal — stance 2: assume this guard goes silent when its own input is malformed; make it go silent

(Housekeeping note: `.warrant-hunt.count` was found stuck at 4, not advancing
between dispatches. Prior manual rotations used 0, 1, 3; this dispatch takes
index 2 per the launching agent's instruction.)

Verdict: FINDING — the `priority-set-by: human` attribution marker is self-attested inside the same agent-writable Write content it is meant to gate, so any agent can forge human attribution for a `priority` change in the same tool call that changes it, with no cross-check against any human-originated channel (no token, no separate file, no signoff artifact).
Kind: design-error
Seed: docs/proposals/2026-08-02-severity-priority-axes.md ("Mechanism for the priority lock" paragraph); existing `qa-cycle/hooks/transition-gate.sh` (untouched, does not yet implement this check) and `signoff/hooks/capture-verdict.sh` (deliberately not touched by this proposal, so it mints nothing for priority).

### Reproduce
The proposal specifies the *entire* priority lock as: "if the new content's
`priority:` value ... differs from the previously recorded value, the write
is refused unless it also carries a `priority-set-by: human` marker" written
directly into `state.md`'s own content — no token file, no `.consuming`
lifecycle, nothing outside the Write call itself (this is explicit: "because
the mechanism does not use the token/`.consuming` lifecycle,
`signoff/hooks/capture-verdict.sh` is not touched"). A faithful, standalone
implementation of exactly that check:

```
python3 - <<'PY'
import re
def check_priority(old_content, new_content):
    def get_priority(t):
        m = re.search(r"^priority:\s*(.*)$", t, re.M)
        return m.group(1).strip() if m else ""
    if get_priority(new_content) == get_priority(old_content):
        return "allow (unchanged)"
    marker = re.search(r"^priority-set-by:\s*human\s*$", new_content, re.M)
    return "allow (marker present)" if marker else "refuse (no marker)"

old_record = "---\nitem: ITEM-1\nstate: reproduced\npriority: later\n---\n"
# An agent's single Write tool_input, containing the marker it typed itself:
agent_forged_write = ("---\nitem: ITEM-1\nstate: reproduced\n"
                       "priority: now\npriority-set-by: human\n---\n")
print(check_priority(old_record, agent_forged_write))
PY
```

### Observed
```
allow (marker present)
```
The write is allowed even though nothing about it originated from a human
turn — the agent authored both the changed `priority:` value and the
`priority-set-by: human` line in the exact same Write call.

### Expected
Per the proposal's own stated intent ("Priority is ... Actor: human", "the
gate must refuse any agent-attempted write that changes `priority`"), an
agent-originated write that changes `priority` should be refused regardless
of what strings that same write also contains, the same way the existing
verdict-token mechanism refuses `reproduced -> handed-off` unless a token
was minted from a genuinely separate, human-authenticated turn (via
`capture-verdict.sh`) rather than a claim embedded in the very file being
written. Storing the attribution inside the content it attributes gives the
locked actor (the agent) the means to satisfy its own lock — a composition
identical in shape to the token-consumption discipline this same repo
already treats as load-bearing (see `docs/decisions/2026-07-31-token-consumption-ordering.md`
and the token-reservation logic in `transition-gate.sh`), which the proposal
explicitly declines to reuse for priority "because it doesn't need
single-use consumption semantics" — but single-use-ness was never the
property doing the work; provenance-outside-the-gated-file was.

## before-landing — stance 4: assume the write set cannot carry this work; find the path the build will need that the proposal does not list.

Note: `.warrant-hunt.count` is stuck at 4 and does not advance (manual rotations so far used 0, 1, 3, 2, so 4 was the next unused index for this cycle).

Verdict: FINDING — `testrun/hooks/directive.sh` (not in the declared write set) still describes the `reproducing -> reproduced` transition's required evidence without mentioning the new severity precondition the gate now enforces for that exact transition, so the directive undersells what will actually be refused.
Kind: silent-failure
Seed: `git diff main...spec/severity-priority` (adds severity precondition to `qa-cycle/hooks/transition-gate.sh` for the `reproducing -> reproduced` row only; does not touch `testrun/hooks/directive.sh`)

### Reproduce
```
WS=/tmp/ws-repro
rm -rf "$WS"; mkdir -p "$WS/projects/foo-bar/tokens"
cat > "$WS/projects/foo-bar/state.md" <<'STATE'
---
item: item1
state: reproducing
---
STATE

payload=$(python3 -c '
import json
new_content = """---
item: item1
state: reproduced
reproduction: steps here
evidence: cmd+output
---
"""
print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"'"$WS"'/projects/foo-bar/state.md","content":new_content}}))
')
echo "$payload" | QA_WORKSPACE="$WS" bash qa-cycle/hooks/transition-gate.sh
echo "exit: $?"

grep -n "severity" testrun/hooks/directive.sh
```

### Observed
The gate refuses:
```
qa-cycle: refused — item item1: reproducing -> reproduced requires a valid `severity:` (exactly one line,
one of {critical, major, minor, trivial}). Absent, empty, or repeated `severity:` lines all mean no severity,
which refuses this transition.
exit: 2
```
`grep -n "severity" testrun/hooks/directive.sh` returns no match — the directive that `testrun` injects every turn, and that explicitly enumerates "Required evidence" for `reproducing -> reproduced` (reproduction procedure + run-record case table), says nothing about severity being required to make that write succeed.

### Expected
`testrun/hooks/directive.sh`'s per-transition "Required evidence" bullet for `reproducing -> reproduced` should have been updated in this unit (or added to the write set) to mention the severity precondition it now owns triggering, so an agent following the injected directive does not attempt — and get refused on — a write that omits it.
