# qa-agent-rulebook — design record

*[한국어](design.ko.md)*

*2026-07-24. The design as discussed before scaffolding v0.1; kept as the
rationale a later contributor can read.*

## Premise

Build a stack that makes a Claude Code session **behave as QA** for a target
project. Deliberately function-first: the lineup is derived from what a QA
engineer actually does, not from the sibling coding stack's
generation/verification thesis. What is inherited from
[coding-agent-rulebook](https://github.com/tokenmaxxxer/coding-agent-rulebook)
is packaging only: marketplace layout, one directory per plugin, thin
shell-script hooks, per-plugin kill switches (with the "off means off"
non-empty-value lesson), the `*-env` dependency bundle, and honest
"Unbenchmarked as of vX" labeling.

## The QA cycle → plugin map

Practical QA decomposes into five blocks: **design → execute → report →
regression → sign-off**.

| block | plugin | v0.1? |
|---|---|---|
| project onboarding | intake | ✅ |
| execution | testrun | ✅ |
| reporting | bugreport | ✅ |
| test design | testplan | roadmap |
| regression | regress | roadmap |
| sign-off | signoff | roadmap |

v0.1 is the minimum stack that stands on its own: *profile the project, run
the product, file what breaks*. testrun deliberately works without a plan
(ad-hoc smoke) so testplan can land later without blocking v0.1.

The center of gravity differs from the coding stack: that stack was almost
all `UserPromptSubmit` steering prose; QA is procedural work, so the weight
sits in **commands/skills** (runnable procedures) with only thin directives
(the two invariants below).

## Two invariants

1. **Verdicts require execution, and carry evidence.** The QA agent may not
   claim pass/fail about anything it did not actually exercise; every verdict
   cites a command+output, screenshot, or log. Code reading yields notes.
2. **Report, don't fix.** A QA session never edits product code. Findings
   become tracker issues or run-record entries. (v0.1 enforces this by
   directive; a `PreToolUse` gate refusing product-code edits is the natural
   mechanical upgrade if drift is observed.)

## intake: why a separate plugin

Issue destination, templates, and labels are not bugreport-private: testrun
needs the launch method and environment, regress will need the test-stack
conventions. So project knowledge is discovered once (`/qa-init`), frozen
into one committed file (`qa/intake.md`), and read by everyone. Fields the
agent cannot discover (separate tracker repo, staging URL, test accounts) are
asked, never guessed; secrets appear as env var *names* only.

`/qa-init --check` is the doctor: profile present, `gh` authed, issue repo
reachable, launch command present, named env vars set.

## Deployment: the 3-layer model

The stack installs where the QA agent runs; product repos carry knowledge,
not software. (Revised same-day: an earlier draft made repo-scoped settings
the primary path — flipped so QA directives never reach non-QA sessions on
the product repos.)

1. **Marketplace layer — this repo.** Stack-wide standards live in the
   plugins themselves (standard bug form fallback, severity fallback
   scheme, evidence rules). Standards change by PR here and propagate by
   plugin update.
2. **QA-agent layer — a user-scope install.** `/plugin marketplace add` +
   `/plugin install qa-agent-env@tokenmaxxxer-qa`, once, in the environment
   (interactive or headless) that performs QA. Secrets (values for the env
   vars the profile names) and `QA_*_OFF` kill switches live here too.
3. **Project layer — one committed file per target repo.** `qa/intake.md`:
   the profile any visiting QA session reads (tracker, template, labels,
   launch method). The only per-project footprint.

Optional repo-scoped variant, when QA should be runnable by anyone in a
given repo rather than a dedicated agent: the repo's checked-in
`.claude/settings.json` may declare `extraKnownMarketplaces` +
`enabledPlugins`; configured plugins auto-install at session startup for
every user who opens the repo (boundary: repo access plus folder trust).
Private GitHub marketplaces work over normal git credentials (background
auto-update needs `gh auth setup-git` or SSH). Repo-scope plugins also load
in `claude -p` headless sessions (not `--bare`). Marketplace `version`
fields pin plugin versions; stable/latest channels are possible via two
branches.

Precedence: plugin built-in stack standard < intake profile < the user's
session instruction.

Known open items:
- Whether a trust prompt appears on first auto-install from repo settings
  (the optional variant) is undocumented — test once, note in onboarding.
- `install.sh` still deliberately skipped: the primary path is two `/plugin`
  commands. Add when provisioning QA-agent environments needs automation.

## The `qa/` contract

All stack state lives committed in the target repo — profile, plans, run
records, evidence — so interrupted sessions resume from disk, every user
shares one state, and CI reads/writes the same records. Run records link failures to
the issues they became (`UNFILED(<reason>)` otherwise), which is the thread a
sign-off plugin will later pull.

## Roadmap notes

- **testplan**: spec/PR → cases via boundary values, equivalence classes,
  negative paths, state transitions; requirement↔case traceability that
  signoff can diff against runs.
- **regress**: each confirmed bug → an automated test in the project's own
  framework (from `tests:` in the profile) that would have caught it; flaky
  detection across runs; `git bisect` on regressions.
- **signoff**: plan-vs-run summary — run/passed/failed/blocked, coverage
  holes, open blockers. Decision *material* for a human; never a shipped/not
  verdict.
- **CI**: scheduled smoke via headless sessions using the same plugins —
  works today in principle; productize after v0.1 settles.
