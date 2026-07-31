# issue-41 rulebook-maturation proposal (execution-observation, phase 1)

files (phase 2): `qa/hooks/directive.sh` (role-directive text body),
`docs/issue-<n>/reports/execution-observation.md` (future records, format
only — no record written this session)

## Scout brief
Ran (parallel 3-angle sweep, 1 stage, no deepening — saturated on first
pass). Full brief: `docs/issue-41/reports/execution-observation/scout-brief.md`.
Current-state survey: `docs/issue-41/reports/execution-observation/survey.md`.

## Request (paraphrased intent)
Fix this rulebook's phase-1/phase-2 norms to a domain-researched
standard instead of an assumed one: (a) how a phase-1 proposal in this
role should be built and what it must contain, (b) how a phase-2
deliverable in this role should be built and what it must contain, (c)
why each choice follows from the domain, (d) how the plugin enforces
it. Core canon (warrant-hunter, gates) is referenced, never copied.

## (a) Phase-1 proposal norms — methodology and required sections

**Methodology:** discovery-over-guessing survey of the actual
sessions/artifacts being observed (never assume what a role did — read
its PR, commits, and record), then a scout sweep against the
observation domain itself when the deliverable shape is not already
fixed by contract v3 (it is here, per this session — see Scout skip
precedent in issue-38/42's proposals for the pattern this repo already
follows).

**Required sections** (mirrors the shape this repo already uses in
issue-33/35/38/42, tightened with the domain finding that evidence
must be traceable to a specific artifact, not asserted):
1. Scope — which role(s)/session(s)/issue(s) are the observation
   target, stated explicitly (independence requirement, see (c)).
2. Current-state survey reference — what was actually read (commits,
   PR diffs, prior records) before any judgment, each claim pointing at
   a specific commit SHA, file, or PR comment.
3. Proposed observation plan — what will be checked and at which of
   the three levels (outcome / trajectory / step — see (b)) before any
   verdict is rendered.
4. Constraints — phase-1-only, no APPROVE-by-self, output-layout rules
   (unchanged from contract v3, restated per existing repo convention).

## (b) Phase-2 deliverable norms — methodology and required components

**Methodology:** observe, don't re-execute the observed role's task —
read its actual artifacts (diff, commits, PR, its own record) and cite
them; never render a verdict about something not read this session
(direct analogue of qa's "verdicts require execution," adapted to
"verdicts require citation").

**Required components**, adopted from scout-brief's must-bes:
1. **Evidence-cited findings** — every claim names its source artifact
   (commit SHA / file:line / PR comment url), never asserted from
   memory. (Adopts ISO 19011 evidence-based-approach + SOC2 "policy
   statement is not evidence.")
2. **Three-level verdict**, not outcome-only: outcome (did the PR/
   record land what the issue asked), trajectory (was the role's
   phase-1→phase-2 path sound — e.g. did it scout when required, did
   it survey before proposing), step (which specific artifact, if any,
   is deficient). (Adopts LangSmith trajectory-eval's multi-level
   grading — the direct fit for auditing *other agents'* sessions.)
3. **Timestamped, ordered trail** of what was checked and when within
   the observation session, even though this role does not emit
   machine telemetry — the human-readable analogue of a span trail.
   (Adopts OTel/GenAI's "nested, timed record" shape, not its wire
   format — scout-brief explicitly skips the protocol.)
4. **Blameless anomaly write-up shape** for any deficiency found:
   impact, timeline, root cause, action item — reused from SRE
   postmortem structure, scaled down to a single finding.
5. **Independence statement** — the record states plainly that this
   role did not author or edit the observed artifact this session.
   (Adopts ISO 19011 conflict-of-interest principle; also already
   true structurally under contract v3's per-role branch isolation.)

## (c) Why each choice follows from the domain (not preference)
- Evidence-over-assertion is the one norm all three researched angles
  (SRE, ISO 19011, GenAI-agent-eval) converge on independently — an
  observation role that asserts without citing is indistinguishable
  from guessing, which defeats the role's entire purpose.
- Three-level verdict is required specifically because this role's
  target is *other agents' multi-phase sessions*, not a single running
  system — outcome-only grading (as qa does for a target app) would
  silently pass a session that reached the right PR through a broken
  process (e.g. skipped survey, self-approved), which is exactly the
  failure mode contract v3's phase-gate exists to prevent.
- Independence is structurally already enforced by per-role branches
  and the approvers.md human-gate, but stating it explicitly in the
  record makes the constraint auditable by a reader who doesn't already
  know contract v3.
- Blameless write-up shape is adopted narrowly (only for anomaly
  findings, not the whole record) because full postmortem ceremony is
  disproportionate to a single-finding note; the shape (impact/
  timeline/cause/action) is cheap and prevents blame-language creep
  which would poison future cross-role trust.

## (d) Plugin reflection plan
1. **Directive** (`qa/hooks/directive.sh`'s `core_role_directive` call):
   replace the four text blocks with execution-observation-specific
   YOU DECIDE / RESEARCH / CURRENT-STATE SURVEY / PROPOSAL / EXECUTION
   JUDGMENT / RECORD REQUIREMENTS wording encoding (a) and (b) above —
   verdicts-require-citation, three-level verdict, independence
   statement. Structural mechanism unchanged (still delegates to core's
   `role-directive.sh`); only the four variable bodies change.
2. **Record required fields**: set `RECORD_FIELDS_TERMINAL_STATES` for
   this role's own vocabulary (e.g. `confirmed-sound confirmed-
   deficient inconclusive`) so core's `record-fields-gate.sh` enforces
   real terminal states instead of falling back to its unrelated
   default (`landed`) — same fix pattern issue-42 already applied for
   qa's `verified-fixed not-a-defect wont-fix`.
3. **Gate**: no new gate script — core's trailer/handbook/record-fields
   gates are already role-agnostic (issue-42). This role's phase-2
   record path (`docs/issue-<n>/reports/execution-observation.md`)
   slots into their existing path convention with no code change.
4. **warrant-hunter**: reference core's canon only (`core issue #63`);
   confirmed no vendored copy exists to remove (survey.md).

## Constraints
- Phase 1 only this session: research + current-state survey + this
  proposal, open the PR, stop. No edit to `qa/hooks/directive.sh` or
  any gate in this session (contract v3 s19). No APPROVE by any role.
- Output layout: docs under `docs/issue-41/` only; no rulebook code
  edited this session.
- Does not fix the repo/template naming mismatch (qa-agent-rulebook
  content living in execution-observation-rulebook) — out of scope for
  this issue; noted in survey.md for the human.

## Out of scope
- Actually editing `qa/hooks/directive.sh` or setting the env var —
  phase 2, after human APPROVE.
- Renaming the `qa/` plugin directory or README — template-mismatch
  fix, not a rulebook-maturation decision this issue asks for.
- Any warrant-hunter file — none exists here; nothing to convert.

## How it'll be known to work (phase 2 acceptance)
- `qa/hooks/directive.sh`'s four text blocks contain the three-level-
  verdict and evidence-citation language; `tests/parse-check.sh` still
  passes (heredoc/bash integrity).
- `grep -n RECORD_FIELDS_TERMINAL_STATES` shows this role's terminal
  vocabulary set somewhere in the plugin config (settings/env, same
  mechanism issue-42 used for qa).
- `docs/issue-41/reports/execution-observation.md` (once written in
  phase 2) demonstrably cites a specific artifact per finding and
  states outcome/trajectory/step verdicts separately.
