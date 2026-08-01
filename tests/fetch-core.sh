#!/usr/bin/env bash
# Resolves a local checkout of tokenmaxxxer/tokenmaxxxer-core (core canon:
# gate-lib.sh/.py, docs/handbooks/gate-house-standard.md,
# core/hooks/tests/compliance-check.sh) for tests to reference — never
# vendored into this repo (docs/handbooks/canon-scripts.md's reference-not-
# copy rule; stub-check.sh's canon-manifest.txt catches a vendored copy).
#
# Resolution order: CLAUDE_PLUGIN_ROOT_CORE (a real plugin install) > a
# ./core sibling checked out for local dev, matching qa/hooks/directive.sh's
# own fallback convention > a cached shallow clone under $TMPDIR (test-only,
# network-fetched once per cache lifetime, never committed).
#
# Prints the resolved core root (the directory containing hooks/lib/
# gate-lib.sh) on stdout; exits non-zero with a diagnostic on stderr if none
# of the three resolve.
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
  if ! git clone --depth 1 -q https://github.com/tokenmaxxxer/tokenmaxxxer-core "$CACHE" >&2; then
    echo "fetch-core: could not clone tokenmaxxxer-core (network unavailable?) — set CLAUDE_PLUGIN_ROOT_CORE or check out ./core yourself" >&2
    exit 1
  fi
fi
if [ -f "$CACHE/core/hooks/lib/gate-lib.sh" ]; then
  echo "$CACHE/core"
  exit 0
fi
echo "fetch-core: cloned tokenmaxxxer-core to $CACHE but core/hooks/lib/gate-lib.sh is still missing" >&2
exit 1
