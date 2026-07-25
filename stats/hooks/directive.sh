#!/usr/bin/env bash
# UserPromptSubmit hook: injects the trust-accounting discipline.
# Kill switch: export QA_STATS_DISABLE=1

# Off means off: only explicit truthy-ish values disable the hook; "0",
# "false", "no", "off" and empty all mean "not off".
case "${QA_STATS_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
<qa-stats-directive priority="low">
SURFACE GATE: this directive is inert outside a request to report, summarize, or judge the QA stack's production signal (acceptance rate, noise rate, backlog, filing discipline). It is inert for intake, execution, filing, triage, sign-off, or regression work themselves — those are reported on, not performed, here.

Trigger conditions: a request for `/qa-stats`, a question about whether the QA stack's filings are being acted on, or any request to summarize run records, filed-issue outcomes, or backlog health.

Rules:
- READ-ONLY. `/qa-stats` never writes a run record, an evidence file, an issue, or the cycle state file (`state.md`). It only reads `projects/<slug>/runs/*.md` and queries the tracker via `gh`.
- NO TRANSITION OWNERSHIP. `stats` owns no transition in the QA cycle state machine and never writes `<QA_WORKSPACE>/projects/<owner>-<repo>/state.md` or any `.verdict-token` file, under any circumstance, even when its own report would seem to justify one (e.g. a high acceptance rate does not authorize an `exit-readiness` or `go-no-go` write — that belongs to `qa-cycle`/`signoff`).
- NEVER GUESS AN OUTCOME. If `gh` cannot resolve an issue, count it as unreachable rather than inferring fixed/rejected.
- NEVER PERSIST THE REPORT. Print it; do not write it to a file.

NEVER:
- Never write, edit, or delete `state.md`, `.verdict-token`, run records, evidence files, or issues.
- Never state or imply a cycle-phase transition happened based on a stats report.
- Never read a secret env var value; report names only, per workspace convention.

COMPOSITION: `stats` reads records that `testrun` and `bugreport` produce (run records under `projects/<slug>/runs/`, `Filed:` entries pointing at issues `bugreport` filed) and reports on outcomes `regress` and `qa-cycle` transitions leave behind. It hands nothing forward — no other plugin consumes a `stats` write, because `stats` performs none.
</qa-stats-directive>
EOF
exit 0
