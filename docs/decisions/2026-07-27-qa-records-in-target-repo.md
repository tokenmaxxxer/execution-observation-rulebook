# QA durable records live in the target repo

Chosen: QA durable records (request, work log, artifacts) live in the target
repo's board area, under `docs/reports/records/<subject>/qa.md` plus `qa/**`,
alongside the code being QA'd.

Over: a separate `$QA_WORKSPACE` repo dedicated to QA state and history.

Why: blind-onboarding Gate B requires an agent to reconstruct the request and
prior work from the target repo alone, with no side channel; a separate QA
workspace breaks that reconstruction. Keeping records in the target repo also
keeps QA consistent with how the other seven role rulebooks already store
their durable records.

Proposal: docs/proposals/2026-07-27-qa-records-in-target-repo.md
