---
date: 2026-07-26
status: decided
---

# Human gate over pipeline gate

**Chosen:** a named human holds the ship/no-ship verdict and the is-this-a-defect verdict. No transition into `Go`, `No-Go`, `Shipped-Under-Exception`, or `Confirmed-Defect` may be taken by an agent alone.

**Over:** encoding the same criteria (pass rate, coverage threshold, perf benchmark) as automated pipeline gates and letting any change through once the pipeline is green — the MinimumCD "QA Sign-Off as a Release Gate" anti-pattern position (`docs/reports/research/2026-07-25-qa-practice-landscape.md`, "Human gates in a real QA workflow" § Contested).

**Why:** this product's premise is an agent that performs testing while a human owns judgment. Moving the verdict into a pipeline removes the thing the rulebook exists to structure, and the research's own AI-testing evidence shows agents produce severity inflation and false positives absent a clear success signal — exactly the judgment a pipeline gate would have to encode without a human.

**Evidence base:** `docs/reports/research/2026-07-25-qa-practice-landscape.md`, sections "Human gates in a real QA workflow" and "The QA role under automation and AI."
