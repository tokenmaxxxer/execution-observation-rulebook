#!/usr/bin/env bash
# Mechanically compares what the seven directive.sh files CLAIM the gate
# enforces against what qa-cycle/hooks/transition-gate.sh --dump-facts says
# it actually enforces.
#
# See docs/proposals/2026-08-04-directive-drift-check.md for the design.
#
# Markers, one HTML comment per bullet a directive already states in prose:
#
#   <!-- gate-covers: observed->reproducing, reproducing->reproduced -->
#   <!-- gate-claim: transition observed->reproducing actor=agent requires=none -->
#   <!-- gate-claim: transition reproducing->reproduced actor=agent requires=severity -->
#   <!-- gate-claim: field priority actor=human requires=token,closed-set -->
#
# Divergence, three kinds:
#   1. A gate-claim names a subject --dump-facts does not have, or names
#      one with a different actor or requirement set. Hard failure.
#   2. A subject in a directive's own gate-covers has no matching
#      gate-claim in that same file. Hard failure.
#   3. A table/field subject appears in no directive's gate-covers at all.
#      Reported, not failed.
#
# A malformed marker (gate-claim or gate-covers that does not parse) is a
# hard failure too, on the same refuse-by-default reasoning the gate
# itself uses — never silently skipped.
#
# Exit 0: no hard failures. Exit 1: at least one hard failure, named.
set -euo pipefail

# This script needs bash 4+ for its associative arrays. macOS ships bash
# 3.2.57 — the last GPLv2 release — as /bin/bash, where `declare -A` is not
# an option and the resulting "declare: -A: invalid option" reads like a bug
# in this script rather than a missing interpreter. Exit 3, distinct from the
# 2 this script uses for "drift found", so a caller can tell DID NOT RUN from
# RAN AND FAILED — the two are not the same verdict.
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "directive-drift-check: needs bash 4+ (associative arrays); this is bash ${BASH_VERSION}." >&2
  echo "  macOS's /bin/bash is 3.2. Install a newer bash (e.g. brew install bash) and run this script with it." >&2
  exit 3
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="${SCRIPT_DIR}/../transition-gate.sh"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

DIRECTIVES=(
  "intake/hooks/directive.sh"
  "testrun/hooks/directive.sh"
  "bugreport/hooks/directive.sh"
  "regress/hooks/directive.sh"
  "stats/hooks/directive.sh"
  "qa-cycle/hooks/directive.sh"
  "signoff/hooks/directive.sh"
)

FAILURES=0
fail() {
  echo "directive-drift-check: FAIL — $1" >&2
  FAILURES=$((FAILURES + 1))
}

# --- pull the gate's own facts ----------------------------------------------

FACTS_JSON="$("$GATE" --dump-facts)"

# --- normalize gate facts into "<subject>|<actor>|<requires-csv-sorted-normalized>"
# lines, one per transition and one per field. Requires are normalized by
# taking only the part before ':' of each token (so "closed-set:a,b,c"
# collapses to "closed-set", matching the marker vocabulary, which restates
# the closed-set FACT, not the literal set contents) and sorting.
FACT_LINES="$(FACTS_JSON="$FACTS_JSON" python3 <<'PY'
import json, os, sys

facts = json.loads(os.environ["FACTS_JSON"])

def norm_requires(reqs):
    toks = sorted(r.split(":", 1)[0] for r in reqs) if reqs else ["none"]
    return ",".join(toks)

for t in facts["transitions"]:
    subject = "transition %s->%s" % (t["from"], t["to"])
    print("%s|%s|%s" % (subject, t["actor"], norm_requires(t["requires"])))

for f in facts["fields"]:
    subject = "field %s" % f["field"]
    print("%s|%s|%s" % (subject, f["actor"], norm_requires(f["requires"])))
PY
)"

declare -A FACT_ACTOR
declare -A FACT_REQUIRES
declare -a FACT_SUBJECTS
while IFS='|' read -r subject actor requires; do
  [ -z "$subject" ] && continue
  FACT_ACTOR["$subject"]="$actor"
  FACT_REQUIRES["$subject"]="$requires"
  FACT_SUBJECTS+=("$subject")
done <<< "$FACT_LINES"

# --- parse markers out of each directive ------------------------------------

declare -A ALL_CLAIMED_SUBJECTS   # subject -> 1, union across all directives (for case 3)

for rel in "${DIRECTIVES[@]}"; do
  f="${REPO_ROOT}/${rel}"
  if [ ! -f "$f" ]; then
    fail "$rel: declared in the drift check's file list but does not exist."
    continue
  fi

  declare -A file_claims_actor=()
  declare -A file_claims_requires=()
  declare -a file_covers=()

  # gate-claim lines: strict shape or fail.
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Expected: transition A->B actor=X requires=Y,Z   OR   field NAME actor=X requires=Y,Z
    if [[ "$line" =~ ^transition\ ([A-Za-z0-9_()-]+)-\>([A-Za-z0-9_()-]+)\ actor=([a-z]+)\ requires=([a-zA-Z0-9,-]+)$ ]]; then
      subject="transition ${BASH_REMATCH[1]}->${BASH_REMATCH[2]}"
      actor="${BASH_REMATCH[3]}"
      requires="${BASH_REMATCH[4]}"
    elif [[ "$line" =~ ^field\ ([A-Za-z0-9_-]+)\ actor=([a-z]+)\ requires=([a-zA-Z0-9,-]+)$ ]]; then
      subject="field ${BASH_REMATCH[1]}"
      actor="${BASH_REMATCH[2]}"
      requires="${BASH_REMATCH[3]}"
    else
      fail "$rel: malformed gate-claim marker: \"$line\" — does not match \"transition A->B actor=X requires=Y,Z\" or \"field NAME actor=X requires=Y,Z\". Refusing to skip it."
      continue
    fi
    # normalize requires: split on comma, sort, join (matches fact normalization)
    norm_requires="$(printf '%s' "$requires" | tr ',' '\n' | sort | paste -sd, -)"
    if [ -n "${file_claims_actor[$subject]+x}" ]; then
      fail "$rel: duplicate gate-claim for subject \"$subject\"."
      continue
    fi
    file_claims_actor["$subject"]="$actor"
    file_claims_requires["$subject"]="$norm_requires"
    ALL_CLAIMED_SUBJECTS["$subject"]=1

    # case 1: compare against the gate's own facts.
    if [ -z "${FACT_ACTOR[$subject]+x}" ]; then
      fail "$rel: gate-claim names subject \"$subject\", which --dump-facts has no record of."
      continue
    fi
    if [ "${FACT_ACTOR[$subject]}" != "$actor" ]; then
      fail "$rel: gate-claim for \"$subject\" says actor=$actor, but the gate enforces actor=${FACT_ACTOR[$subject]}."
    fi
    if [ "$norm_requires" != "${FACT_REQUIRES[$subject]}" ]; then
      fail "$rel: gate-claim for \"$subject\" says requires=$norm_requires, but the gate enforces requires=${FACT_REQUIRES[$subject]}."
    fi
  done < <(grep -oE '<!-- gate-claim:.*-->' "$f" | sed -E 's/<!-- gate-claim:\s*(.*[^ ])\s*-->/\1/')

  # gate-covers lines: one or more per file, each a comma-separated list.
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    IFS=',' read -ra parts <<< "$line"
    for raw in "${parts[@]}"; do
      subject_raw="$(printf '%s' "$raw" | sed -E 's/^\s+|\s+$//g')"
      [ -z "$subject_raw" ] && { fail "$rel: malformed gate-covers entry (empty item) in \"$line\"."; continue; }
      if [[ "$subject_raw" =~ ^[A-Za-z0-9_()-]+-\>[A-Za-z0-9_()-]+$ ]]; then
        subject="transition ${subject_raw//->/->}"
      elif [[ "$subject_raw" =~ ^field:[A-Za-z0-9_-]+$ ]]; then
        subject="field ${subject_raw#field:}"
      else
        fail "$rel: malformed gate-covers entry \"$subject_raw\" — expected \"A->B\" or \"field:NAME\"."
        continue
      fi
      file_covers+=("$subject")
    done
  done < <(grep -oE '<!-- gate-covers:.*-->' "$f" | sed -E 's/<!-- gate-covers:\s*(.*[^ ])\s*-->/\1/')

  # case 2: every declared-covered subject must have a matching claim in
  # this same file.
  for subject in "${file_covers[@]}"; do
    if [ -z "${file_claims_actor[$subject]+x}" ]; then
      fail "$rel: gate-covers declares \"$subject\" but no gate-claim for it exists in this file."
    fi
  done

  unset file_claims_actor file_claims_requires file_covers
done

# --- case 3: table/field subjects nobody declares — reported, not failed --
echo ""
echo "directive-drift-check: undeclared subjects (informational, not a failure):"
undeclared_count=0
for subject in "${FACT_SUBJECTS[@]}"; do
  if [ -z "${ALL_CLAIMED_SUBJECTS[$subject]+x}" ]; then
    echo "  - $subject"
    undeclared_count=$((undeclared_count + 1))
  fi
done
if [ "$undeclared_count" -eq 0 ]; then
  echo "  (none)"
fi

echo ""
if [ "$FAILURES" -ne 0 ]; then
  echo "directive-drift-check: FAILED — ${FAILURES} divergence(s) found." >&2
  exit 1
fi
echo "directive-drift-check: passed — no directive claim mismatches the gate's declared facts."
exit 0
