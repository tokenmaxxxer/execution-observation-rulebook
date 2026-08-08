---
status: landed
---

# qa rulebook conformance to role-handoff-contract v2 (blackboard/event model)

## Intent

`docs/specs/role-handoff-contract.md` landed at commit `b240ec4` as `status:
final`, replacing v1's one-shot parcel-handoff model (ACCEPTS/refuse at a
single moment) with a shared blackboard each role reads, writes its own
record onto, and wakes from. qa's own rulebook still describes and enforces
v1: `README.md`'s "Handoff protocol" section states an `ACCEPTS: None` table
inherited from `docs/proposals/2026-07-26-role-protocol-section.md`, and
`qa-cycle/hooks/transition-gate.sh` gates an item-level state machine keyed
entirely on `$QA_WORKSPACE`, a tree the new contract's §10 explicitly
abolishes. This proposal commissions bringing both back into conformance.
It is a proposal, not the implementation — no other file in this repo is
touched by writing it.

## Grounding: what's actually there today

**`README.md`, "Handoff protocol" section (lines 112–146).** Quoting the
current text verbatim:

> **ACCEPTS.** None. qa works from direct observation of the running system,
> not from other roles' records. It uniformly refuses `hypothesis`,
> `build-proposal`, `feasibility-record`, `review-record`, and `ops-state` if
> any is handed over as if it were required input.

This conflates two things contract v2 §4 explicitly separates: "may qa open
the file" (READ) and "may qa's verdict cite it" (DEPENDS-ON). v1's uniform
refusal reads as a read-ban; §4 states plainly this reading is "not a reading
ban" and calls out qa's row by name as the example of the conflation:
"qa may READ `feasibility-record`'s `measurement_design` and any other
record as advisory context, the same as any role... But qa's verdict must be
built from direct observation of the running system, never from another
role's record." The loosening is real and must be stated as a loosening, not
smoothed over as "no change."

The PRODUCES table (README.md lines 129–134) lists `qa-state` and
`qa-evidence` as the two output kinds, with `qa-evidence` explicitly living
`$QA_WORKSPACE/projects/<owner>-<repo>/**`, "out-of-repo, section 6
exception." Contract v2 has no such exception; §10 states it in these words:
"v1 kept qa's bulk evidence (intake profile, run logs, regression history)
in `$QA_WORKSPACE`, an external, host-local, uncommitted tree, with only a
thin pointer record left inside the repo. That exception is abolished." The
kind name itself also drifts: v2 §2's table row is `qa-record`, not
`qa-state`/`qa-evidence`.

**`qa-cycle/hooks/transition-gate.sh`.** This gate does not, today, adjudicate
writes to `docs/reports/records/<subject>/qa.md` at all — it adjudicates
writes to `$QA_WORKSPACE/projects/<slug>/state.md`, an entirely different
artifact (the item-level QA-cycle state machine defined in
`docs/specs/qa-cycle-state-machine.md`, keyed on `item:`/`state:` blocks, not
on the contract's `kind:`/`loop_state:` header). Concretely:

- Line 108: `if [ -z "${QA_WORKSPACE:-}" ]; then` — refuses outright when
  `$QA_WORKSPACE` is unset, before even reading a payload. The whole gate is
  built around this variable; `ws = os.environ.get("QA_CYCLE_WORKSPACE", "")`
  (line 239) and every path built from it (`project_dir`, `state_path`,
  `tokens_dir`, `target_path`) is `$QA_WORKSPACE`-rooted.
- Lines 250–253: the gate only fires on paths matching
  `projects/<slug>/state.md` under the workspace root (`parts[0] !=
  "projects" or parts[2] != "state.md"` → `not_applicable()`). It has no
  awareness of `docs/reports/records/<subject>/qa.md` or
  `docs/reports/records/<subject>/qa/**` as paths it should govern.
- Field parsing (lines 308–309) is `ITEM_KEY = re.compile(r"^item:\s*(.*?)\s*(?:#.*)?$", re.M)` and `STATE_KEY = re.compile(r"^state:\s*(.*?)\s*(?:#.*)?$", re.M)` — note both
  already tolerate a trailing `#`-comment (`(?:#.*)?$`), which is the correct
  shape. There is **no** `kind:`-parsing regex anywhere in this file or
  elsewhere in the repo (confirmed by grep for `^kind` across
  `qa-agent-rulebook/`) — because the gate has never needed to read the
  contract's `kind:` header field at all, since it has never governed the
  blackboard record.
- Lines 41–59: the SHA-pin / repo-local-contract check
  (`docs/proposals/2026-07-26-repo-local-contract.md`) is the one piece of
  this file that already speaks the contract's language — it resolves the
  git root and refuses handoff-protocol actions when
  `docs/specs/role-handoff-contract.md` is absent there. This logic is sound
  under v2 as-is and should be kept, not rewritten — v2 §1's frontmatter and
  §8 both still presuppose a contract file exists at that path.

The separately-maintained `docs/proposals/2026-07-26-role-protocol-section.md`
(the proposal that produced today's README section) pins the contract at SHA
`2affe5db7dfb285abaa2860d3004edb3f97c9aec` and describes a "SHA-pin check"
in `transition-gate.sh` that refuses when the pinned SHA no longer matches —
grep of the current `transition-gate.sh` shows no such check actually landed
(the file's only contract-awareness is the file-presence check at lines
41-59, not a SHA comparison). This proposal does not resurrect the SHA-pin
mechanism; v2 is now `status: final` and the contract itself is the
authority, so pinning a stale SHA in qa's own docs is the wrong direction —
flagged here so whoever picks up the rewrite does not treat the abandoned
SHA-pin as still-live intent.

`README.ko.md` mentions `$QA_WORKSPACE` once (line 75, install-section
prose unrelated to the handoff section) and carries no separate "Handoff
protocol" section of its own — it is out of scope for the handoff rewrite
itself but should get the same `$QA_WORKSPACE`-language update if/when the
README.md rewrite lands, noted under Out of scope below since this proposal
does not commission Korean-doc changes.

## What this proposal commissions

### 1. `README.md` — rewrite "Handoff protocol" (replaces lines 112–146)

Replace the four-part ACCEPTS/WHERE-UPSTREAM-LIVES/PRODUCES/STOPS shape with
sections keyed to the contract's own vocabulary, so a qa session can read
this section alone and act:

- **WAKES-ON** (contract §3, qa's row): qa wakes on any commit touching
  `src/` or `tests/` in the running system. State this as the trigger
  condition, replacing the old ACCEPTS framing entirely — v2 has no
  accept/refuse-at-handoff moment for qa to gate on.
- **READ / DEPENDS-ON / NEVER-OVERWRITE** (contract §4, §11): state READ as
  broad and unconditional — any board record, including
  `feasibility-record`, `hypothesis`, `build-proposal`, `review-record`,
  `ops-record` — explicitly naming this as a reversal of the current
  "uniformly refuses... if handed over as if it were required input" text,
  not a restatement of it. State DEPENDS-ON as empty for qa, with the
  direct-observation principle carried forward as *why* DEPENDS-ON is empty,
  not as a read ban: qa may read `feasibility-record`'s `measurement_design`
  and any other record as advisory context, but a qa verdict citing another
  role's record as its basis (rather than the qa session's own direct
  observation of the running system) is out of contract. State
  NEVER-OVERWRITE per §11's table row: qa writes only
  `docs/reports/records/<subject>/qa.md` and
  `docs/reports/records/<subject>/qa/**`.
- **Blackboard record spec** (§7 + §2's `qa-record` row): rename the output
  kind from `qa-state`/`qa-evidence` to the single `qa-record` kind (§2 uses
  one row per role, not two), `loop_state` vocabulary
  `observed,reproducing,reproduced,handed-off,re-verifying,verified-fixed,
  not-a-defect,wont-fix` (unchanged set, now living under the contract's
  `loop_state` field name rather than a bespoke `role status` field), and
  required content — intake profile, bug reports, regression records, run
  stats — now entirely in-repo under `docs/reports/records/<subject>/qa/**`
  alongside `qa.md` itself. Call out explicitly, as its own labeled
  paragraph, that this abolishes the `$QA_WORKSPACE` external/host-local/
  uncommitted tree described in the current PRODUCES table and in
  `docs/design.md`'s "one central private repo" model — this is a migration
  of where qa's bulk evidence physically lives, not a documentation wording
  change, and should be flagged as the section's highest-risk item since
  `qa-cycle/`, `intake/`, `testrun/`, `bugreport/`, `regress/`, `signoff/`,
  and `stats/` all currently read or write `$QA_WORKSPACE` paths (see grep
  results above) and are not touched by this proposal.
- **Finding back-edge** (§5): qa produces `finding` blocks
  `addressed_to: coding` for defects, and its own record's WAKES-ON already
  covers findings addressed to qa from other roles (§3 row: "a `finding`
  with `addressed_to: coding`" is coding's row, not qa's — qa's own WAKES-ON
  row is the `src/`/`tests/` commit trigger; state this precisely rather
  than implying qa also wakes on findings addressed to it, since §3's table
  does not give qa a findings-trigger row).
- **Cycle termination** (§6, restated for qa↔coding specifically): a
  `finding` from qa → a `finding-response` from coding → coding's fix
  produces a new commit → qa wakes again (§3). The cycle terminates only
  when a qa wake produces a `verified-fixed` write with no new `finding`, or
  a genuinely new `finding`. State explicitly, per §6's own wording, that
  "a wake that reproduces an already-filed, unresolved finding without
  adding new information is not a new board change... and does not re-open
  the cycle" — this is the rule that keeps the loop from ping-ponging
  forever and should be stated in qa's own words in the README, not left
  only in the shared contract.
- **Loop-termination rule** (§6, general form): a wake is consumed only by
  writing the resulting record entry; writing nothing does not consume it.

### 2. `qa-cycle/hooks/transition-gate.sh` — rewrite to match

- **Read-refusal deletion.** There is currently no kind-based read-refusal
  logic in this file to delete — the gate has never read
  `docs/reports/records/<subject>/qa.md` or any other role's record, so it
  has never blocked a read of one either. State this finding explicitly in
  the implementation (a code comment near the top, alongside the existing
  §41–59 contract-presence check) so a future reader does not go looking for
  read-refusal code that never existed: v1's refusal lived entirely in
  README.md prose ("qa... uniformly refuses... if any is handed over"), not
  in this gate. The rewrite's job here is to make sure nothing added by
  item 1 below *introduces* a read-refusal, not to remove one.
- **Narrow the gate's job to three things**, replacing its current sole
  focus (item-level `state.md` transition legality under
  `$QA_WORKSPACE`) with a scope that also covers the blackboard record:
  (a) refuse writes outside qa's owned paths — extend the path-matching
  block at lines 245–253 (currently `parts[0] != "projects" or parts[2] !=
  "state.md"`) with a second recognized shape:
  `docs/reports/records/<subject>/qa.md` or
  `docs/reports/records/<subject>/qa/**`, refusing any write under
  `docs/reports/records/<subject>/` whose second path segment is not `qa.md`
  or `qa/`;
  (b) refuse DEPENDS-ON violations only where mechanically detectable — a
  qa.md write can be checked for whether its own `upstream:` list cites a
  non-empty `sha`/`path` pointing at another role's record kind (e.g.
  `feasibility-record`) as if it were a dependency basis, since `upstream`
  is structured YAML the gate can parse the same way it already parses
  `item:`/`state:` blocks; note explicitly in the gate's header comment that
  this check *cannot* detect a verdict's prose citing another role's record
  by name in free text, so the "qa's verdict must come from direct
  observation" rule stays a documentation-only rule beyond the structural
  `upstream:` check — contract §14 says this outright ("Section 11's path
  ownership is a table, not a gate" applies by the same logic to
  DEPENDS-ON);
  (c) keep the existing repo-local-contract-presence refusal (lines 41–59)
  unchanged — it already implements contract v2's presupposition that a
  contract file must exist before any handoff-protocol action proceeds, and
  needs no rewrite, only re-verification that it still gates the newly
  added `docs/reports/records/` write path the same way it gates the
  existing `state.md` path.
- **Kind-parsing regex.** No `^kind:\s*(\S+)\s*$`-style regex exists
  anywhere in this repo today (grep confirmed empty). The existing
  `ITEM_KEY`/`STATE_KEY` patterns at lines 308–309 already use the
  comment-tolerant shape (`^item:\s*(.*?)\s*(?:#.*)?$`) contract §2 requires
  ("`kind` parsing by any gate must tolerate a trailing comment on the
  line... a regex anchored to end-of-line with no comment tolerance is a
  gate defect"). Commission a new `KIND_KEY` pattern built on that same
  template — `re.compile(r"^kind:\s*(.*?)\s*(?:#.*)?$", re.M)` — for the
  gate's new `docs/reports/records/<subject>/qa.md` write path (item 2's
  path-matching addition above), so the one new parser this rewrite
  introduces is comment-tolerant from the start rather than needing a
  follow-on fix.
- **`$QA_WORKSPACE` removal.** This file references `$QA_WORKSPACE` at lines
  108–109 (the unset-check that refuses the entire gate before reading a
  payload) and 239 (`QA_CYCLE_WORKSPACE` env passthrough into the Python
  heredoc), with every downstream path (`ws_real`, `project_dir`,
  `state_path`, `tokens_dir`, `target_path`) built from it. Commission
  removing this dependency for the new `docs/reports/records/<subject>/qa/**`
  write path specifically: that path check must resolve and
  containment-check against the target repo's own root (the same
  `_contract_repo_root` already resolved at line 55 for the contract-presence
  check), not against `$QA_WORKSPACE`. Do **not** commission removing
  `$QA_WORKSPACE` from the item-level `state.md` transition-table logic
  (lines 160–822) in this same pass — that machinery is qa-cycle's own
  internal item state machine, a different concern from the blackboard
  record, and migrating it off `$QA_WORKSPACE` is a larger follow-on (see
  Out of scope) that touches `intake/`, `testrun/`, `bugreport/`, `regress/`,
  `signoff/`, and `docs/specs/qa-cycle-state-machine.md` together — bundling
  it into this gate-only pass risks leaving those plugins pointed at a
  workspace root the gate no longer enforces.

### 3. Write set

Exact files this proposal commissions changing:

- `/home/jwjung/tokenmaxxxer/qa-agent-rulebook/README.md` — replace the
  "Handoff protocol" section (current lines 112–146) per item 1 above.
- `/home/jwjung/tokenmaxxxer/qa-agent-rulebook/qa-cycle/hooks/transition-gate.sh`
  — add the `docs/reports/records/<subject>/qa.md` /
  `docs/reports/records/<subject>/qa/**` path recognition, the comment-
  tolerant `KIND_KEY` parser, the structural `upstream:` DEPENDS-ON check,
  and the repo-root-based (not `$QA_WORKSPACE`-based) containment check for
  that new path, per item 2 above, leaving the existing `state.md`/
  `$QA_WORKSPACE` item-state-machine logic (lines 32–822 as they stand
  today, minus the additions just listed) otherwise untouched.

No other file is written by this proposal.

## Out of scope

- Implementing any of the above — this document is the commissioning
  proposal only; `status: proposed`.
- Running any build, test, or lint step against the changed files.
- Any `git commit`.
- `README.ko.md` — should receive the equivalent Korean-language rewrite in
  a follow-on pass once the English section's shape is landed and stable,
  not translated speculatively against a moving draft.
- Migrating `intake/`, `testrun/`, `bugreport/`, `regress/`, `signoff/`,
  `stats/`, and `docs/specs/qa-cycle-state-machine.md` off `$QA_WORKSPACE`
  for the item-level state machine itself. Contract v2 only abolishes
  `$QA_WORKSPACE` as the home for qa's *cross-role-visible* evidence (§10);
  whether qa's internal item-tracking machinery also moves in-repo, and how
  `docs/reports/records/<subject>/qa/**` and
  `$QA_WORKSPACE/projects/<slug>/state.md` relate to each other going
  forward (one becomes a view onto the other? one is retired?) is a design
  question this proposal does not resolve and a separate proposal should
  own.
- Resurrecting or updating the abandoned SHA-pin mechanism described in
  `docs/proposals/2026-07-26-role-protocol-section.md` (pinned SHA
  `2affe5db7dfb285abaa2860d3004edb3f97c9aec`) — v2 supersedes it; the
  repo-local-contract-presence check (lines 41–59 of `transition-gate.sh`)
  is kept as-is instead.
- Changing `docs/specs/role-handoff-contract.md` itself, or any of the other
  five role rulebooks (coding, feasibility, product, ops, review) — the
  contract states landing it "in each rulebook is separate, one proposal per
  repo."
- Adding a mechanical check for section 11's path-ownership table beyond
  the one narrow addition in item 2(a) above (qa's own owned-path check);
  the contract's §14 states this table is normative prose, not something
  every gate must enforce, and this proposal does not attempt full
  cross-role enforcement.

## How you will know it worked

A qa session can read `README.md`'s "Handoff protocol" section alone and
correctly state: it may read any board record but must never cite one as a
verdict's basis; its only output kind is `qa-record` at
`docs/reports/records/<subject>/qa.md` plus `qa/**`, entirely in-repo; and
its wake condition is a commit touching `src/`/`tests/`, not an accepted
handoff. `transition-gate.sh` refuses a write attempted at
`docs/reports/records/<subject>/coding.md` from a qa-attributed session
(NEVER-OVERWRITE), refuses a `qa.md` write whose `upstream:` list cites
another role's record with no `acknowledged_sha` (DEPENDS-ON, structurally
checkable case only), tolerates `kind: qa-record  # re-scoped` on the new
`KIND_KEY` path, and no longer requires `$QA_WORKSPACE` to be set for a
write under `docs/reports/records/<subject>/qa/**` specifically.

## What did not work

- Tested the new gate logic by running `transition-gate.sh` directly from
  inside this repo (`qa-agent-rulebook` itself) first — it refused every
  case with the contract-presence check, because this rulebook repo is the
  plugin, not a work repo, and has no `docs/specs/role-handoff-contract.md`
  of its own. Had to build a throwaway repo under `mktemp -d` with that file
  present to exercise the new path at all.
- First draft of the `_is_qa_owned` check treated `docs/reports/records/`
  itself (with no subject segment) as in-scope and tried to split on `/`
  without checking `_rparts[0]` was non-empty, which would have let a
  malformed path with a leading slash segment slip past silently instead of
  falling through to the unchanged path. Added the explicit `_rparts[0]`
  truthiness check before treating it as a real subject.
