#!/usr/bin/env bash
# SessionStart: qa's role directive — how this role fills each stage of
# the core lifecycle. core's directive carries the protocol; this carries
# the role. Kill switch: export QA_CYCLE_OFF=1
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"

# The directive body — you_decide/use_when/produces/hand_off — is deepened
# per-facet judgment criteria owned by eo-directive, fetched via subprocess
# (not sourced) so this file's own lines stay inside stub-check.sh's cap.
EO_DIRECTIVE_ROOT="${CLAUDE_PLUGIN_ROOT_EO_DIRECTIVE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../plugins/eo-directive" && pwd -P)}"
you_decide="$("$EO_DIRECTIVE_ROOT/hooks/directive-body.sh" you_decide)"
use_when="$("$EO_DIRECTIVE_ROOT/hooks/directive-body.sh" use_when)"
produces="$("$EO_DIRECTIVE_ROOT/hooks/directive-body.sh" produces)"
hand_off="$("$EO_DIRECTIVE_ROOT/hooks/directive-body.sh" hand_off)"

core_role_directive "$you_decide" "$use_when" "$produces" "$hand_off"
