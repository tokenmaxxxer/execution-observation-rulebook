---
proposal: docs/proposals/2026-07-30-item-axis-state-machine.md
---

# Hunt record — item-axis-state-machine

## after-proposal — stance 4: assume the write set cannot carry this work — find the path the build will need that the proposal does not list.

Verdict: FINDING — `bugreport/hooks/directive.sh` hardcodes the per-project phase vocabulary (`finding-triage`, `Confirmed-Defect`, `closed-not-a-defect`) the proposal's rewrite eliminates/renames, and is neither in the declared write set (`docs/specs/qa-cycle-state-machine.md`) nor in the "Explicitly out of scope" list (which names only `transition-gate.sh`, signoff token minting, and the state-file layout).
Kind: design-error
Seed: commit 51f37c6a968e00598e8adbe6faabbec1fd3056c3 (docs/proposals/2026-07-30-item-axis-state-machine.md)

### Reproduce
```
grep -n "finding-triage\|Confirmed-Defect\|closed-not-a-defect" bugreport/hooks/directive.sh
grep -n "finding-triage" docs/specs/qa-cycle-state-machine.md
```

### Observed
`bugreport/hooks/directive.sh` line 15 fires its TRIGGER CONDITIONS on `` `finding-triage` phase ``, and lines 19-20/28/33 reference the phase-keyed states `Confirmed-Defect` / `closed-not-a-defect` by name, taken verbatim from the current per-project state table in `docs/specs/qa-cycle-state-machine.md` (lines 18, 35-38, 78-81). The proposal's "What will be done" rewrites that spec's primary table to be keyed on the feedback item, replacing the phase set with item states (observation, handed-off, and four distinct terminal states named confirmed-and-fix-verified / closed-as-not-a-defect / parked-as-unreproducible / won't-fix). None of these new names match `finding-triage`, `Confirmed-Defect`, or `closed-not-a-defect`. The proposal's write set and its explicit out-of-scope list cover only `docs/specs/qa-cycle-state-machine.md`, `transition-gate.sh`, signoff minting, and the state file layout — `bugreport/hooks/directive.sh` is not mentioned in either, so landing this unit as scoped leaves that plugin's directive quoting phase names the spec no longer defines.

### Expected
The proposal's write set (or its out-of-scope list, with an explicit acknowledgment of the resulting divergence, as it does for `transition-gate.sh`) should include `bugreport/hooks/directive.sh`, since its TRIGGER CONDITIONS and RULES text is not independent prose but a direct quotation of the per-project phase vocabulary this unit's rewrite retires.

## before-landing — stance 4: assume the write set cannot carry this work — find the path the build will need that the proposal does not list.

Verdict: NO FINDING
Seed: git diff main...spec/item-axis-state-machine

Re-checked the write set as it now stands (grown to include `bugreport/hooks/directive.sh` plus seven sibling directive/command files, per "Why the write set grew" in the proposal). Grepped every plugin's hooks/commands directory for the retired per-project phase vocabulary (`finding-triage`, `Confirmed-Defect`, `closed-not-a-defect`); the only remaining hits outside the write set are `qa-cycle/hooks/transition-gate.sh`, `signoff/hooks/capture-verdict.sh` (named in the out-of-scope list), and `qa-cycle/README.md` / `signoff/README.md` / `docs/handbooks/qa-cycle.md` (user-facing docs whose phase-vocabulary text still accurately describes those two untouched hooks' current behavior, so it is not stale). Cross-checked all eight write-set files' state names (`observed`, `reproducing`, `reproduced`, `handed-off`, `re-verifying`, `verified-fixed`, `not-a-defect`, `parked-unreproducible`, `wont-fix`) against the rewritten spec's state and transition tables — every occurrence matches exactly, including the four human-locked transitions listed in `qa-cycle/hooks/directive.sh` and `signoff/hooks/directive.sh`. No path the build needs is missing from the declared write set.
