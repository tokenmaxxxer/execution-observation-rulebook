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
