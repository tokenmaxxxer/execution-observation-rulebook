---
description: Launch the product and execute QA — regression suite + plan if the workspace has them, ad-hoc smoke otherwise
argument-hint: "[scope — e.g. 'checkout flow' | 'smoke' | empty = full]"
---

Execute a QA run. Scope: $ARGUMENTS

## 1. Load the profile

Resolve the QA workspace: root = `$QA_WORKSPACE`, or `~/qa-workspace` if
unset (create + `git init` if missing, say so in one line; `git pull
--rebase` first when it has a remote). This project's
directory is `<root>/projects/<slug>/`, `<slug>` = repo name from the origin
remote (directory name if no remote). Read `<project-dir>/intake.md`. If it
is missing, do a one-pass ad-hoc discovery (launch command, base URL) and say
in one line that you are running without a profile.

## 2. Launch

Start the app with the profile's `app.start`, wait for `app.ready` (poll the
health endpoint or landing page — don't sleep blind). If it was already
running, use it and don't stop it at the end. If it fails to start, that is
itself the first finding: record the command and its output, stop the run.

## 3. Decide the case list

- `<project-dir>/regress/` has tests → always run the whole regression suite
  first (per its runner notes), one case row per test. A regression failure is
  a confirmed regression — file it like any other failure.
- `<project-dir>/plan.md` exists → execute its cases, filtered by the scope
  argument.
- No plan → build an ad-hoc smoke list from what the product itself exposes:
  navigation/routes, README feature list, main user flows. Cover each main
  flow's happy path plus its most obvious failure path (bad input, empty
  state, unauthenticated access). Keep the list to what one session can
  actually run — state what was left out.

## 4. Execute

Per case: exercise the real product — browser automation for web UI, `curl`
for APIs, the real CLI for terminal tools. Record for every case:

- verdict: `pass` / `fail` / `blocked` (with what blocked it)
- evidence: command + output, screenshot path, or log excerpt — stored under
  `<project-dir>/evidence/<run-slug>/`

Verdicts follow the testrun directive: nothing you didn't run gets a verdict.

## 5. Record

Write `<project-dir>/runs/<YYYY-MM-DD>-<slug>.md`:

```markdown
# Run <date> — <scope>

profile: projects/<slug>/intake.md (or "none")
app: <commit/version tested> at <url>

| case | verdict | evidence |
|---|---|---|
| login happy path | pass | evidence/<slug>/login.png |
| login wrong password | fail | evidence/<slug>/login-err.txt |

## Failures
One block per failure: what was done, expected, actual, evidence. Filed:
<issue URL>, DUP(<existing issue URL>), or UNFILED(<reason>).
```

## 6. Close

Stop the app if this run started it. Summarize: cases run / passed / failed /
blocked, and for each confirmed failure either file it now via the `/bug`
discipline (a duplicate becomes `DUP(<url>)`) or record it as UNFILED with
the reason. Commit the run record and evidence in the workspace repo (push if
it has a remote).
