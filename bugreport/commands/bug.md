---
description: File a confirmed bug to the project's tracker, following its issue template and labels
argument-hint: "[short symptom, or a run-record failure to file]"
---

File a bug: $ARGUMENTS

## 0. Precondition — reproduction

Only file what was actually reproduced. If the bug named in the argument was
not reproduced in this session (and is not backed by a run-record failure with
evidence), reproduce it first; if it does not reproduce, say so and stop —
nothing gets filed.

## 1. Load the filing rules

From `qa/intake.md`: `issues.repo`, `issues.template`, `issues.labels` /
`severity_labels`, `language`. Without a profile: use the origin repo, check
`.github/ISSUE_TEMPLATE/` directly, and note the fallback in the report.

## 2. Search for duplicates

`gh issue list --repo <repo> --state open --search "<symptom keywords>"`.
On a likely match: show it, add the new reproduction/evidence as a comment
instead of filing, and record it in the run record as `DUP(<issue URL>)` —
`/qa-stats` counts these separately from new filings. Only file a new issue
when no match holds.

## 3. Compose

- Project template exists → follow its fields exactly (form `.yml`: map each
  field; `.md`: fill each section). Do not invent extra sections.
- No template → the stack's standard form:

```markdown
## Summary
One sentence: where, what goes wrong.

## Steps to reproduce
1. numbered, from the actual reproduction — environment/URL included

## Expected
## Actual
Include the exact error text/output.

## Environment
commit/version tested, environment (local/staging), browser or client, OS.

## Evidence
Command + output inline; screenshots/log paths from qa/evidence/ (attach or
quote the relevant excerpt — a path alone is not readable from the tracker).

## Severity
Per the project's scheme; fallback: sev:critical (data loss / no workaround),
sev:high (main flow broken, workaround exists), sev:medium, sev:low.
```

Write the issue in the profile's `language`. Title: `[area] symptom`, concise
and searchable — no "bug:" prefix if the label already says it.

## 4. File and record

`gh issue create --repo <repo> --title ... --body-file ... --label ...`
(labels only from the project's actual label set). Then append the issue URL
to the run record entry that produced it, and report the URL in one line.
