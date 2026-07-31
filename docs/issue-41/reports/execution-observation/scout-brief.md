# issue-41 scout brief (execution-observation, phase 1)

Mode: parallel fan-out, 3 angles in one batch (Agent tool, single message),
1 sweep stage, no deepening — judge point 1 found strong cross-angle
convergence, so saturation was reached without a second round.

## Category must-bes
- Instrument as correlated signals sharing one context/trace id, not
  isolated logs (OTel three pillars; GenAI semantic conventions nest
  spans per LLM/tool call under one root span).
- Golden-signal-equivalent minimum set per observed unit: for a request
  RED (rate/errors/duration); for an agent run, per-step timed spans
  with full inputs/outputs.
- Evidence over opinion: conclusions must trace to reproducible,
  timestamped, scope-correct artifacts (ISO 19011, SOC2) — a policy/
  intent statement is not evidence.
- Independence: the observer must not be grading its own work (ISO
  19011 conflict-of-interest principle).
- Multi-level verdict: outcome alone is insufficient — trajectory/path
  soundness and per-step (tool/component) attribution are judged
  separately (LangSmith trajectory evals).

## Performance axes (what strong deliverables compete on)
1. Timeline/trail completeness (nested spans or chronological log with
   timestamps + actor) vs. summary-only.
2. Evidence traceability (every claim cites a specific artifact) vs.
   asserted verdicts.
3. Blameless, structured root-cause + owned action items vs. narrative
   postmortems with no follow-through.

## Adopt / skip
- Adopt: evidence-cited, timestamped record; multi-level verdict
  (outcome + trajectory + step attribution); blameless postmortem shape
  (impact, timeline, root cause, action items) for anomaly write-ups.
- Skip: full OTel span/trace-id wire format — this role narrates human-
  readable session observation, not machine telemetry; adopt the
  *shape* (nested, timed, evidence-linked), not the protocol.

## Segment fit
This repo's role observes OTHER roles' AI-agent execution sessions
(process/session audit), closer to the audit + agent-trace segment than
to infra/service observability — weight ISO 19011 and GenAI-trace
sources over pure SRE golden-signals.

## Gap line
Repo currently ships only a `qa`-role directive (test verdicts); no
execution-observation directive, no evidence/trail required-fields gate,
no multi-level verdict vocabulary exist here — every must-be above is
currently unmet in this repo (see survey.md for detail).

Sources:
- https://sre.google/sre-book/monitoring-distributed-systems/
- https://sre.google/sre-book/postmortem-culture/
- https://sre.google/workbook/postmortem-analysis/
- https://grafana.com/blog/the-red-method-how-to-instrument-your-services/
- https://clickhouse.com/resources/engineering/red-use-methods
- https://www.dash0.com/knowledge/logs-metrics-and-traces-observability
- https://preteshbiswas.com/2023/11/28/iso-190012018-clause-4-principles-of-auditing/
- https://safetyculture.com/topics/iso-19011
- https://www.zengrc.com/blog/what-is-iso-19011/
- https://www.thesoc2.com/post/what-counts-as-valid-evidence-in-soc2-type-ii-audits
- https://www.forensicnotes.com/audit-trails/
- https://greptime.com/blogs/2026-05-09-opentelemetry-genai-semantic-conventions
- https://opentelemetry.io/blog/2026/genai-observability/
- https://docs.langchain.com/langsmith/trajectory-evals
- https://www.confident-ai.com/blog/llm-agent-evaluation-complete-guide
