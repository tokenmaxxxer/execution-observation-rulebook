#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — this role's own execution-
# observation methodology write surfaces.
#
# Targets: docs/issue-<n>/proposals/*execution-observation*.md (phase-1
# proposals) and docs/issue-<n>/reports/execution-observation.md (phase-2
# record) — the two write surfaces described in
# docs/issue-47/proposals/execution-observation-proposal.md section (2).
#
# Sources the gate-house standard library (core issue-72,
# docs/handbooks/gate-house-standard.md) for the trap/kill-switch/path-
# normalize/reconstruct machinery instead of hand-rolling it — reference
# only, never copied (docs/handbooks/canon-scripts.md). Resolution order
# for the core plugin root matches execution-observation/hooks/directive.sh's own
# CLAUDE_PLUGIN_ROOT_CORE convention: the runtime-provided env var first,
# a `core` checkout sibling to this repo's own root otherwise (local dev).
#
# Kill switch: export EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF=1
CORE_ROOT="${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../core" && pwd -P)}"
. "$CORE_ROOT/hooks/lib/gate-lib.sh" || { echo "methodology-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF:-}" || { trap - EXIT; exit 0; }

role="${CLAUDE_ROLE:-eo}"
deny() { echo "${role}: refused — $1" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || deny "methodology-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "methodology-gate: empty tool-use payload on stdin; cannot evaluate the methodology gate."

# Extract the write target for root-discovery purposes, failing closed on
# malformed JSON here too (not just in the full judge below) via the same
# gate_lib.gate_parse_json_or_deny the judge uses.
_target="$(printf '%s' "$payload" | env GATE_LIB_PY="$GATE_LIB_PY" python3 -c '
import importlib.util, os, sys
_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)

def _deny(msg):
    sys.stderr.write("eo: refused — %s\n" % msg)
    sys.exit(2)

raw = sys.stdin.read()
e = gate_lib.gate_parse_json_or_deny(raw, _deny)
ti = e.get("tool_input") if isinstance(e, dict) else None
if isinstance(ti, dict):
    for k in ("file_path", "notebook_path"):
        v = ti.get(k)
        if isinstance(v, str) and v:
            print(v)
            break
')"
_extract_rc=$?
[ "$_extract_rc" -eq 0 ] || exit "$_extract_rc"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
_under() {
  [ -z "$2" ] && return 0
  env GATE_LIB_PY="$GATE_LIB_PY" python3 -c '
import importlib.util, os, sys
_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)
root, target = sys.argv[1], sys.argv[2]
try:
    real_root = os.path.realpath(root)
except OSError:
    sys.exit(1)
sys.exit(0 if gate_lib.gate_normalize_path(real_root, target) is not None else 1)
' "$1" "$2"
}

root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR" && _under "$CLAUDE_PROJECT_DIR" "$_target"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  d="$_target"; [ -n "$d" ] || d="$(pwd -P)"; [ -d "$d" ] || d="$(dirname "$d")"
  root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; failing closed (methodology check cannot run)."

EO_PAYLOAD="$payload" EO_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import importlib.util, os, posixpath, re, sys

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)

    def deny(m):
        sys.stderr.write("eo: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("EO_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (methodology).")

    root = posixpath.normpath(os.environ["EO_ROOT"].replace("\\", "/"))
    PROPOSAL_RE = re.compile(r'^docs/issue-[0-9]+/proposals/.*execution-observation.*\.md$', re.I)
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/execution-observation\.md$')

    path = None
    if tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)

    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None:
        sys.exit(0)  # resolves outside the project root — not this gate's business

    is_proposal = bool(PROPOSAL_RE.match(rel))
    is_record = bool(RECORD_RE.match(rel))
    if not (is_proposal or is_record):
        sys.exit(0)  # not an execution-observation methodology write surface

    real_path = posixpath.join(root, rel) if rel else root
    current = None
    if os.path.isfile(real_path):
        try:
            with open(real_path, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on methodology." % rel)

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches (honoring replace_all), so the "
            "methodology fields can be checked." % (rel, tool)
        )

    # --- structural section parsing (heading -> body), replacing the old
    # bare-substring "anywhere in the document" checks -----------------
    HEADING_RE = re.compile(r'^(#{2,3})[ \t]+(.*)$', re.MULTILINE)

    def sections(text):
        marks = list(HEADING_RE.finditer(text))
        out = []
        for i, m in enumerate(marks):
            start = m.end()
            end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
            out.append((m.group(2), text[start:end]))
        return out

    secs = sections(new_text)

    def sections_matching(*needles):
        for heading_text, body in secs:
            low_h = heading_text.lower()
            if any(nd.lower() in low_h for nd in needles):
                yield heading_text, body

    LEVEL_MARK_RE = re.compile(r'\b(outcome|trajectory|step)\s*[:—-]', re.I)
    LIST_ITEM_RE = re.compile(r'^\s*[-*]\s+\S', re.MULTILINE)

    missing = []

    if is_proposal:
        if "## Scope" not in new_text:
            missing.append("eo-directive: '## Scope' heading missing")

        if not (re.search(r'#\d+', new_text) or re.search(r'issue-\d+', new_text, re.I)):
            missing.append("eo-directive: no issue/PR number pattern (#<n> or issue-<n>) present")

        if not re.search(r'docs/issue-\d+/reports/execution-observation', new_text, re.I):
            missing.append("eo-directive: no current-state-survey path reference (docs/issue-<n>/reports/execution-observation) present")

        plan_secs = list(sections_matching("verdict.level", "verdict-level", "plan"))
        if not any(
            len({m.group(1).lower() for m in LEVEL_MARK_RE.finditer(body)}) >= 2
            for _, body in plan_secs
        ):
            missing.append(
                "eo-directive: no verdict-level-plan section (heading matching "
                "verdict-level/plan) with >=2 of outcome/trajectory/step in "
                "list/plan position (word immediately followed by ':'/'-'/'—')"
            )

        plugin_secs = list(sections_matching("플러그인 목록", "plugin list", "plugin 목록"))
        if not any(LIST_ITEM_RE.search(body) for _, body in plugin_secs):
            missing.append("eo-directive: no plugin-list section heading with an actual list item under it (플러그인 목록 / plugin list / plugin 목록)")

        verdict_re = re.compile(r'\b(outcome|trajectory|step)\s*[:—-]\s*(sound|deficient)\b', re.I)
        if verdict_re.search(new_text):
            missing.append("eo-directive: premature verdict language in phase-1 proposal")

    else:  # is_record
        markers = list(LEVEL_MARK_RE.finditer(new_text))
        low = new_text.lower()
        indep_idx = low.find("independence statement")
        first_marker_idx = markers[0].start() if markers else None
        if first_marker_idx is not None and (indep_idx == -1 or first_marker_idx < indep_idx):
            missing.append("eo-directive: independence-before-verdict-ordering")

        levels_present = {m.group(1).lower() for m in markers}
        absent_levels = [w for w in ("outcome", "trajectory", "step") if w not in levels_present]
        if absent_levels:
            missing.append("eo-directive: missing-verdict-level(s): %s" % ", ".join(absent_levels))

        if re.search(r'deficient|finding', new_text, re.I):
            BLAMELESS = ("impact", "timeline", "root cause", "action item")
            lines = new_text.split("\n")
            line_starts = []
            pos = 0
            for ln in lines:
                line_starts.append(pos)
                pos += len(ln) + 1

            def line_of(offset):
                lo, hi = 0, len(line_starts) - 1
                while lo < hi:
                    mid = (lo + hi + 1) // 2
                    if line_starts[mid] <= offset:
                        lo = mid
                    else:
                        hi = mid - 1
                return lo

            trigger_lines = sorted({line_of(m.start()) for m in re.finditer(r'deficient|finding', new_text, re.I)})

            def section_span_for_line(idx):
                heads = list(HEADING_RE.finditer(new_text))
                cur_start, cur_end = 0, len(lines)
                for i, m in enumerate(heads):
                    s = line_of(m.start())
                    e = line_of(heads[i + 1].start()) if i + 1 < len(heads) else len(lines)
                    if s <= idx < e:
                        cur_start, cur_end = s, e
                return cur_start, cur_end

            found = {label: False for label in BLAMELESS}
            for t_idx in trigger_lines:
                s, e = section_span_for_line(t_idx)
                window_lo = min(s, t_idx + 1)
                window_hi = max(e, t_idx + 6)
                window_hi = min(window_hi, len(lines))
                for li in range(window_lo, window_hi):
                    ln = lines[li]
                    for label in BLAMELESS:
                        if found[label]:
                            continue
                        if re.match(r'^#{2,4}.*' + re.escape(label), ln, re.I) or \
                           re.match(r'^\s*\*\*' + re.escape(label), ln, re.I):
                            found[label] = True

            absent_blameless = [w for w in BLAMELESS if not found[w]]
            if absent_blameless:
                missing.append("eo-directive: blameless-shape-incomplete: %s" % ", ".join(absent_blameless))

        marker_path = posixpath.join(root, ".claude", ".eo-read-marker")
        marker_dir = posixpath.join(root, ".claude")
        if not os.path.isfile(marker_path):
            if os.path.isdir(marker_dir) and not os.access(marker_dir, os.R_OK | os.X_OK):
                missing.append("eo-state: eo-state-marker-unavailable (.claude/ exists but is not inspectable — this may be a marker-write failure, not an unread artifact)")
            else:
                missing.append("eo-state: eo-state-marker-missing (.claude/.eo-read-marker not present — no artifact of the observed target has been read this session)")

    if missing:
        deny(
            "execution-observation methodology write to %s is missing required element(s): %s." % (rel, "; ".join(missing))
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("methodology-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "eo: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
