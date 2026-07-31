# issue-47 scout brief (execution-observation, phase 1)

Mode: parallel (multiple `gh api` calls batched in single turns) for
the two sibling-repo angles; 1 sweep stage, judged, then one targeted
deepening stage on the two hits that mattered (methodology-gate.sh full
body; hunt-guard.sh full body). Saturated after that — a third round
would not change the proposal's shape. Total wall-clock well under
budget.

Angles run:
1. Org repo inventory (`gh repo list tokenmaxxxer`) — which sibling
   rulebooks exist to compare against, since the issue names two by
   name (`pricing-rulebook`, `implementation-rulebook`).
2. `pricing-rulebook` tree (methodology-gate pattern — the issue's
   explicit "reference, per pricing-rulebook's methodology-gate.sh").
3. `implementation-rulebook` tree (hook-machine-level pattern — the
   issue's explicit "implementation-rulebook 수준" quality bar).

## Must-bes (what both exemplars assume/require)

- **Fail-closed trap at the top of the file**, before any `set`/source
  line: `trap` on `EXIT` that forces exit 2 on any abnormal termination
  so a hook crash denies rather than silently passing (both
  `pricing/hooks/methodology-gate.sh` and `implementation-rulebook`'s
  `hunt-guard.sh` open with the identical `__fc` trap idiom).
- **Kill switch env var**, checked immediately, with the "off means
  off" spelling rule: only `""/0/false/no/off` count as off; any other
  non-empty value (a likely typo of "on") is NOT treated as off. Both
  exemplars implement this exact case statement.
- **python3 required, denied if absent** — the JSON-payload judgment
  logic runs in an embedded `python3 <<'PY'` heredoc reading the
  PreToolUse payload from an env var, never trusting shell string
  parsing for JSON.
- **Path scoping to the role's own write surface only** — regex-match
  the target file path against exactly this role's proposal/record
  path convention (`docs/issue-<n>/proposals/*.md`,
  `docs/issue-<n>/reports/execution-observation.md`); `sys.exit(0)`
  (allow, not-my-business) for every other path. Both exemplars resolve
  `tool_input.file_path` against a project root found via
  `CLAUDE_PROJECT_DIR` with a git-toplevel fallback, never a bare
  string compare.
- **Reconstructed post-write content, not just current-disk content**
  — for `Write` use `tool_input.content`; for `Edit`/`MultiEdit`,
  simulate the replacement against current file content so the check
  runs against what the file WILL contain, not what it already
  contains (a fresh `Write` of a still-incomplete document must be
  judged on the actual first draft).
- **Missing-elements list named in the denial message**, not a bare
  "invalid" — `pricing`'s gate builds a `missing = [...]` list and
  states exactly which required elements are absent, with a pointer to
  the norms document that requires them.
- **Ordering enforced by trackable session state, not directive prose,
  only where the methodology has a real order dependency** —
  `implementation-rulebook`'s `hunt-state.sh` + `hunt-guard.sh` pair
  (single-flight lock + session dispatch cap) is the pattern for
  "situation X may not happen until situation Y has already happened
  this session," backed by a written lock file plus a documented reason
  for why deeper nesting enforcement was foreclosed structurally
  instead of coded (tool-list omission), not left as a TODO.
- **Gate tests run the gate as a real subprocess** with a synthetic
  PreToolUse JSON payload piped over stdin, in a throwaway `git init`
  tempdir, asserting exit code (0=allow, 2=deny) — never a mocked/
  simulated invocation. `tests/run-gate-tests.sh` (already in this
  repo) is the exact harness shape; `hunt-guard.sh`'s own test peers
  follow the identical stdin-JSON-into-real-bash-subprocess convention.

## Performance axes the two exemplars compete on

1. **Denial-message actionability** — pricing's gate names each missing
   element and cites the norms doc; a bare "denied" (seen in weaker
   gates elsewhere) is a smell to avoid.
2. **Fail-closed completeness** — both exemplars fail closed on: missing
   python3, unparseable JSON, non-dict payload, internal exception
   (wrapped in `try/except` at the outermost script level printing
   `fail-closed: internal error` and exiting 2), not just on the
   substantive check failing.
3. **Scope precision** — the gate must ignore writes to files outside
   its own role's write surface (`sys.exit(0)` fast-path), so it never
   blocks another role's or another issue's write.

## Adopt / skip

- **Adopt**: fail-closed trap, kill-switch off-spelling rule, python3
  json-heredoc judge, path-scoped regex match against this role's own
  write surfaces (`docs/issue-<n>/proposals/*execution-observation*.md`
  and `docs/issue-<n>/reports/execution-observation.md`), reconstructed
  post-write content for Write/Edit/MultiEdit, named-missing-elements
  denial message, real-subprocess gate tests added to
  `tests/run-gate-tests.sh`.
- **Adopt, scoped down**: state-tracked ordering — this role's actual
  order dependency is narrower than `implementation-rulebook`'s hunter
  concurrency problem (no concurrent dispatch to bound here); the
  adopted shape is a single per-session marker file recording "the
  observed artifact was read this session" so the gate can refuse a
  phase-2 record write that never read anything, not a lock/cap pair.
- **Skip**: `implementation-rulebook`'s nesting-foreclosure-via-tool-list
  argument is specific to warrant-hunter subagent dispatch, which this
  role has no analogue of (execution-observation dispatches no
  subagents of its own under contract v3) — not adopted, noted as
  inapplicable rather than silently dropped.
- **Skip**: pricing's conjoint-family / labeled-numbers / residual-list
  checks are pricing-domain-specific field names; only the *shape*
  (regex-driven required-element list against this role's own adopted
  norms doc) is adopted, not those field names.

## Gap line (survey vs field must-bes)

Already met: fail-closed philosophy exists elsewhere in this repo's
generic gates (core canon, referenced not vendored) — this role just
never had its OWN methodology gate to apply it to. Missing, confirmed
by survey.md: no methodology-gate.sh-shaped file exists for
execution-observation at all; no state-tracking marker exists; no
gate-specific test exists in `run-gate-tests.sh` for this role.

## Sources

- https://github.com/tokenmaxxxer (`gh repo list tokenmaxxxer`)
- https://github.com/tokenmaxxxer/pricing-rulebook (tree via `gh api
  repos/tokenmaxxxer/pricing-rulebook/contents/pricing/hooks`)
- https://github.com/tokenmaxxxer/pricing-rulebook/blob/main/pricing/hooks/methodology-gate.sh
- https://github.com/tokenmaxxxer/pricing-rulebook/blob/main/pricing/hooks/hooks.json
- https://github.com/tokenmaxxxer/pricing-rulebook/blob/main/pricing/hooks/directive.sh
- https://github.com/tokenmaxxxer/implementation-rulebook (tree via
  `gh api repos/tokenmaxxxer/implementation-rulebook/contents/coding/hooks`)
- https://github.com/tokenmaxxxer/implementation-rulebook/blob/main/coding/hooks/hunt-guard.sh
- this repo: `docs/issue-42/reports/implementation.md`,
  `docs/issue-41/proposals/execution-observation-proposal.md`,
  `tests/run-gate-tests.sh`
