---
status: final
---

# Handoff protocol

QA's role section under the shared role-handoff contract. This document
describes only how the qa role behaves against whatever
`docs/specs/role-handoff-contract.md` the work repo carries — it does not
itself define or certify enforcement of that contract.

## 1. Where the contract lives

The authoritative contract is the work repo's own
`docs/specs/role-handoff-contract.md`, resolved from the git root of the
session's current working directory. QA does not walk up parent
directories, does not reference any sibling checkout, and does not compare
against another repo's copy of this file — the contract holds only within
the single repository qa is working in.

## 2. Absence behavior

If the work repo has no `docs/specs/role-handoff-contract.md`, qa refuses
handoff-protocol actions with the message "this repo has no collaboration
contract yet." This is an honest failure, never a silent pass: qa does not
fall back to some other repo's contract and does not proceed as if a
contract were in force.

## 3. Wakes-on

QA is a role reading and writing a shared blackboard, not a party accepting
or refusing a handed-over parcel. QA wakes on:

- a `build-proposal` or `coding-record` reaching `loop_state: landed`;
- a `finding` with `addressed_to: qa`.

There is no SHA pin and no external original to compare a handed-over
artifact against — qa's own repo is the only source of truth it reads, so
no pin concept applies here.

## 4. Read / Depends-on / Never-overwrite

- **READ (broad, unconditional):** qa may read every other role's record on
  the board for context. Reading is never a violation.
- **DEPENDS-ON (narrow):** qa's verdicts may be built only on
  `build-proposal` and `coding-record` blocks and `finding` blocks
  addressed to it — not on `feasibility-record`, `review-record`,
  `product-record`, or `ops-record` content directly. Those may be read as
  advisory context but not cited as the basis for a qa verdict.
- **NEVER-OVERWRITE:** qa owns exactly
  `docs/reports/records/<subject>/qa.md` (`kind: qa-record`) and the
  `qa/**` paths (qa.md or qa/**). Finding an existing record already
  present at a path owned by another role means refuse-and-report, not
  overwrite-or-merge.

## 5. Blackboard record spec

- `qa-record`: `loop_state` vocabulary `verifying, reproducing,
  verified-fixed`; required fields: pointer to the `build-proposal` or
  `coding-record` under test, `## Defects` (with a human is-this-a-defect
  verdict once one exists), reproduction and evidence per defect.
- `loop_state` is the one part of qa's internal state a downstream role's
  WAKES-ON check may depend on. A transition qa completes internally but
  does not reflect onto the board's `loop_state` has not, for contract
  purposes, completed.

## 6. Produces

- per-subject record at `docs/reports/records/<subject>/qa.md`
- supporting artifacts under `qa/**`

## 7. Finding back-edge

QA is the addressed role for any role's `finding` with `addressed_to: qa`.

Closing out a finding requires a `finding-response` entry in `qa.md` with:

- the finding reference (record path + finding identifier);
- the action taken or the decline reason;
- when a defect was re-verified, proof of the re-run (targeted re-run
  result).

An entry missing any of the three parts does not close the finding.

The qa <-> coding cycle-termination rule: a `finding` from qa produces a
`finding-response` from coding; coding's fix produces a commit, which wakes
qa again; the cycle terminates only when qa's resulting wake produces
either `loop_state: verified-fixed` with no new finding, or a genuinely new
finding (not a restatement of an already-filed, unresolved one).

## 8. Loop termination

A wake is consumed only by writing the resulting record entry (a
`loop_state` change, a new `finding-response`, or equivalent). Leaving the
board byte-identical to what woke qa means the wake was not consumed and
fires no further wake.

## 9. Stops

QA stops and refuses to proceed when:

1. The work repo has no `docs/specs/role-handoff-contract.md` ("this repo
   has no collaboration contract yet" — section 2).
2. It finds an existing record already present at a path owned by a
   different role; it reports the conflict rather than overwriting it.

## Scope note

This document states only how qa behaves against a contract the work repo
already carries. It does not build, wire, or certify any enforcement gate
for these rules, and it does not amend the contract itself.
