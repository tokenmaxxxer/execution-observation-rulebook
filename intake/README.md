# intake

Per-project QA profile. `/qa-init` reads the target project once — where bugs
get filed, which issue template and labels that repo actually uses, how the app
launches, what test stack the project already has — and freezes the answers
into a single committed file, `qa/intake.md`. Every other plugin in the stack
reads that file instead of rediscovering (or guessing) per session.

This is what makes the stack work *per project, for a whole team*: one person
runs `/qa-init` and commits the profile; from then on every user's QA
session files issues to the same repo, in the same template, with the same
labels, launching the app the same way.

## Pieces

- **`/qa-init`** — discovery: git remote → issue repo, `.github/ISSUE_TEMPLATE/*`,
  `gh label list`, package scripts / compose / Makefile / README for the launch
  method, existing test conventions. Asks only what it cannot discover (separate
  tracker repo, staging URL, language). Writes `qa/intake.md`; re-running
  updates stale fields and preserves human edits.
- **`/qa-init --check`** — doctor: profile present, `gh` authenticated, issue
  repo reachable, launch command present, profile-named env vars set (checked
  by name, values never printed). One fixing command per failure.
- **`SessionStart` hook** — one line: profile found (and where issues go), or
  missing (with the suggestion to run `/qa-init`).

## Secrets

The profile records env var *names* only. Values live in each person's
environment or secret manager — the file is committed, so nothing secret may
enter it.

Kill switch: `QA_INTAKE_OFF=1` silences the SessionStart line.

Unbenchmarked as of v0.1.0.
