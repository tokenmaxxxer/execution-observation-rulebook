---
description: Discover this project's QA profile (issue tracker, templates, labels, app launch, test conventions) and write qa/intake.md — or verify the environment with --check
argument-hint: "[--check]"
---

Create or verify this project's QA profile: $ARGUMENTS

## If the argument is `--check` (doctor mode)

Verify the environment and report a short table — do not modify anything:

1. `qa/intake.md` exists and parses (frontmatter readable).
2. `gh auth status` succeeds.
3. The issue repo from the profile is reachable: `gh repo view <issues.repo>`.
4. The app start command from the profile exists (script/target present — do not launch).
5. Every env var named in the profile's `env:` list is set in this shell. Report set/unset by NAME only — never print values.

Report pass/fail per line with the one command that fixes each failure (e.g. `gh auth login`, `gh auth setup-git`, `/qa-init`). Then stop.

## Otherwise (init mode)

Discover the profile by reading the project — ask the user only for what cannot be discovered.

1. **Issue tracker.** `git remote -v` → `gh repo view` for the canonical repo. If there are signs the tracker lives elsewhere (monorepo package, a separate `*-issues` repo referenced in CONTRIBUTING/README), ask the user which repo receives bugs; otherwise use the origin repo and note it as an assumption.
2. **Issue templates.** List `.github/ISSUE_TEMPLATE/*` (both `.md` and form `.yml`). Identify the bug template if one exists. Record its path; bugreport will follow its fields verbatim.
3. **Labels.** `gh label list --repo <issues.repo>`. Record the labels actually used for bugs, severity, priority, and components. If the repo has no severity scheme, leave the field empty — bugreport falls back to the stack's standard `sev:` scheme.
4. **App launch.** Read `package.json` scripts, `docker-compose*`, `Makefile`, and the README's run instructions. Record: start command, base URL/port, stop command, and how to tell it's up (health endpoint or landing page).
5. **Test conventions.** Existing test framework(s), where tests live, and the CI test command — so regression tests, when written, match the project's stack.
6. **Environments and secrets.** Record env var NAMES the QA work needs (staging URL, test account, …) — never values, never guesses. Unknown = leave listed but unset, and say so.
7. **Language.** Issue and report language: infer from existing issues/README (e.g. `ko`, `en`); ask if unclear.

Write the result to `qa/intake.md`. If the file already exists, update only fields that discovery contradicts and preserve everything a human added. Format:

```markdown
---
issues:
  repo: org/product
  template: .github/ISSUE_TEMPLATE/bug_report.yml   # empty if none
  labels: [bug]
  severity_labels: []          # empty -> stack default sev:critical/high/medium/low
language: ko
app:
  start: "docker compose up -d"
  url: "http://localhost:3000"
  ready: "GET /health returns 200"
  stop: "docker compose down"
tests:
  framework: playwright
  dir: e2e/
  ci: "npm test"
env:                           # names only — values never live in this file
  - QA_STAGING_URL
  - QA_TEST_ACCOUNT
---

# QA intake — <project>

Main user flows, environments, fragile areas, anything the team should know
before testing. Free-form, human-edited — discovery never overwrites this
section.
```

Finish with: the profile summary in a few lines, which fields were assumed vs confirmed, and a reminder to commit `qa/intake.md` so the whole team shares it.
