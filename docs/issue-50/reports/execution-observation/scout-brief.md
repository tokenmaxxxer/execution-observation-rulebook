# issue-50 scout brief (execution-observation, phase 1)

Mode: batched-sequential (single session, no parallel subagent dispatch
available for this turn's scope; two `gh api` fan-out calls issued
together, see Sources). Stages used: 1 sweep + 1 supplementary check =
2 of the 5-stage budget; wall-clock well under 3min. Saturated after
stage 2 — the prerequisite names exactly one adoption target, so
sweep breadth is inherently narrow (width-1 reference, not an open
field of exemplars).

## Gap line (current state vs. field)

Survey (`survey.md` section 5) already shows this rulebook's gate is
below the gate-house standard on all six defect classes the standard
names: hand-rolled trap (met, but duplicated logic — not itself a
gap), old-shape kill switch (gap: default-open-on-unrecognized-value),
hand-rolled path-normalize (gap: not `gate_normalize_path`), bare
`.replace(o,n,1)` reconstruction ignoring `replace_all` (gap, matches
core's own pre-#72 `record-fields-gate.sh` bug exactly), no
`NotebookEdit` handling (gap), and substring-only semantic checks (gap,
not itself a gate-lib scope — this repo's own design work, see
proposal).

## Must-bes (from the adopted reference, core issue #72)

- Source `gate-lib.sh`, load `gate-lib.py` via the documented
  `importlib.util.spec_from_file_location` pattern — never vendor a
  copy (`canon-manifest.txt` / `stub-check.sh`-equivalent catches
  copies).
- `gate_trap_fail_closed` as the literal first statement, before `set
  -uo pipefail`.
- `gate_kill_switch_active`: only `1`/`true`/`yes`/`on` (case-
  insensitive) disables; every other value, including unrecognized
  ones, stays active.
- `gate_reconstruct_write` honors `replace_all` per-edit
  independently and covers `NotebookEdit`.
- Six-case test harness is mandatory when migrating: `replace_all`
  Edit, mixed-`replace_all` MultiEdit, malformed JSON, unrecognized
  kill-switch value, absolute + `./`-prefixed path, Bash-tool write
  target.

## Performance axes chosen

1. Reference fidelity (call the shared function, don't reimplement its
   shape with local names).
2. Semantic precision (structural match, not substring) — this repo's
   own axis, since gate-lib does not cover proposal/record content
   semantics; core issue #72's scope is the mechanical shapes only.

## Adopt / skip

- Adopt: every `gate_*` function named above, verbatim usage pattern.
- Adopt: the six-case harness shape, extended with two of this repo's
  own semantic-structure cases (see proposal requirement 3, case 6).
- Skip: reimplementing any lock/counter/cap mechanism from other
  plugins (`eo-state`'s per-session marker already fits this role's
  actual need; gate-lib has no lock primitive to adopt, and none is
  needed).

## Segment fit

One line: this rulebook's write surfaces are two markdown documents
per issue (proposal, record) written by this role's own directive —
narrower and more controlled than a general-purpose gate target, so
the section/heading-based semantic parser proposed (plain `re` +
`##`/`###` split) is proportionate; no markdown-AST dependency needed.

## Sources

- https://github.com/tokenmaxxxer/tokenmaxxxer-core (contents:
  `core/hooks/lib/gate-lib.sh`, `core/hooks/lib/gate-lib.py`,
  `docs/handbooks/gate-house-standard.md`) — primary reference, read
  in full this session via `gh api`.
- https://github.com/tokenmaxxxer/pricing-rulebook (contents:
  `qa/hooks/methodology-gate.sh`) — supplementary check, 404: that
  repo has since moved off the flat `qa/hooks/methodology-gate.sh`
  path this repo's own gate header cites as its lineage (consistent
  with the same plugin-set restructuring this repo already applied in
  issue #47); no additional pattern extracted beyond the primary
  source.
