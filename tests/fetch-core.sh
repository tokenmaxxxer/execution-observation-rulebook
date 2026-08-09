#!/usr/bin/env bash
# Resolves a local checkout of tokenmaxxxer/tokenmaxxxer-core (core canon:
# gate-lib.sh/.py, docs/handbooks/gate-house-standard.md,
# core/hooks/tests/compliance-check.sh) for tests to reference — never
# vendored into this repo (docs/handbooks/canon-scripts.md's reference-not-
# copy rule; stub-check.sh's canon-manifest.txt catches a vendored copy).
#
# Resolution order: CLAUDE_PLUGIN_ROOT_CORE (a real plugin install) > a
# ./core sibling checked out for local dev, matching execution-observation/hooks/directive.sh's
# own fallback convention > a cached shallow clone under $TMPDIR (test-only,
# network-fetched once per cache lifetime, never committed).
#
# Prints the resolved core root (the directory containing hooks/lib/
# gate-lib.sh) on stdout. If none of the three candidates resolve, this
# follows the SKIP contract from tokenmaxxxer/on-the-record's
# docs/specs/test-env-resolution.md (issue #551): print the convention's
# SKIP message on stderr and exit 75 (EX_TEMPFAIL) rather than a generic
# failure code, so callers can tell "unverifiable outside spawn env"
# apart from a real defect.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [ -n "${CLAUDE_PLUGIN_ROOT_CORE:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT_CORE/hooks/lib/gate-lib.sh" ]; then
  echo "$CLAUDE_PLUGIN_ROOT_CORE"
  exit 0
fi

if [ -f "$HERE/../core/hooks/lib/gate-lib.sh" ]; then
  (cd "$HERE/../core" && pwd -P)
  exit 0
fi

CACHE="${TOKENMAXXXER_CORE_CACHE:-${TMPDIR:-/tmp}/tokenmaxxxer-core-cache}"
if [ ! -f "$CACHE/core/hooks/lib/gate-lib.sh" ]; then
  rm -rf "$CACHE" 2>/dev/null
  git clone --depth 1 -q https://github.com/tokenmaxxxer/tokenmaxxxer-core "$CACHE" >&2
fi
if [ -f "$CACHE/core/hooks/lib/gate-lib.sh" ]; then
  echo "$CACHE/core"
  exit 0
fi

# None of the three candidates resolved (env var, ./core sibling, cached/
# network clone) — per on-the-record's test-env-resolution.md (issue
# #551), this is SKIP, not failure: unverifiable outside the spawn env.
echo "SKIP: core plugin unreachable — unverifiable outside spawn env" >&2
exit 75
