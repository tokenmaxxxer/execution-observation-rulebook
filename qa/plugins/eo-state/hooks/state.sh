#!/usr/bin/env bash
# Maintains the marker at .claude/.eo-read-marker that signals at least one
# artifact of an execution-observation target has plausibly been read this
# session. Nothing gates on this marker's absence from within this plugin —
# eo-methodology-gate is the consumer; this plugin only produces the signal.
#
#   reset  (SessionStart)  new session — drop the marker so a stale marker
#           from a previous session never survives to vouch for reads that
#           never happened this session.
#   mark   (PostToolUse)   read stdin (the tool-call payload) and, on a
#           best-effort substring match for an observed-role artifact path
#           or a gh command, write the marker.
#
# Kill switch: export EXECUTION_OBSERVATION_STATE_OFF=1

# Sources the gate-house standard library (core issue-72) for the fixed
# kill-switch convention instead of hand-rolling the case statement: only a
# recognized on-spelling (1/true/yes/on) disables; every other value,
# recognized-off or unrecognized (e.g. a typo), stays active. Reference
# only, never copied (docs/handbooks/canon-scripts.md); same
# CLAUDE_PLUGIN_ROOT_CORE resolution convention as qa/hooks/directive.sh.
CORE_ROOT="${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel 2>/dev/null)/core}"
. "$CORE_ROOT/hooks/lib/gate-lib.sh"
gate_kill_switch_active "${EXECUTION_OBSERVATION_STATE_OFF:-}" || exit 0

# Root resolution: the project directory, normalized to the git top level
# when there is one, matching the convention used across this repo's other
# state scripts.
eo_state_marker_path() {
  local root top
  root="${CLAUDE_PROJECT_DIR:-$PWD}"
  top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)"
  [ -n "$top" ] && root="$top"
  echo "$root/.claude/.eo-read-marker"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    reset)
      # Stale markers must not survive across sessions: a marker left over
      # from a prior session would vouch for reads this session never did.
      rm -f "$(eo_state_marker_path)" 2>/dev/null
      ;;
    mark)
      payload="$(cat)"
      # Best-effort signal, not a strict prover: this is a substring check
      # on the raw hook payload, not a verification that the read was of
      # the actual observed target. False positives are accepted (an
      # unrelated docs/issue-*/reports/ read still sets the marker); false
      # negatives are the known limitation (a read routed through a tool
      # this check doesn't recognize sets nothing). Mirrors the
      # proportionality note hunt-guard.sh makes about its own
      # unenforceable 4th limit — a cheap approximate signal beats no
      # signal at all.
      if printf '%s' "$payload" | grep -qE 'docs/issue-[^"]*/(reports|proposals)/' \
        || printf '%s' "$payload" | grep -qE 'gh (api|pr)'; then
        marker="$(eo_state_marker_path)"
        mkdir -p "$(dirname "$marker")" 2>/dev/null
        date +%s > "$marker" 2>/dev/null
      fi
      ;;
  esac
  exit 0
fi
