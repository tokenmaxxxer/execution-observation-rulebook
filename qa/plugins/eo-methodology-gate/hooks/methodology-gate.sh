#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — this role's own execution-
# observation methodology write surfaces.
#
# Targets: docs/issue-<n>/proposals/*execution-observation*.md (phase-1
# proposals) and docs/issue-<n>/reports/execution-observation.md (phase-2
# record) — the two write surfaces described in
# docs/issue-47/proposals/execution-observation-proposal.md section (2).
#
# Structurally modeled on pricing-rulebook's methodology-gate.sh (fail-
# closed trap, kill-switch off-spelling, python3 JSON-heredoc judge,
# path-scoped regex, content reconstruction, named-missing-elements
# denial) — referenced, not copied; field names and paths below are this
# role's own.
#
# Kill switch: export EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF=1
set -uo pipefail

role="${CLAUDE_ROLE:-eo}"
deny() { echo "${role}: refused — $1" >&2; exit 2; }

case "${EXECUTION_OBSERVATION_METHODOLOGY_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "methodology-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "methodology-gate: empty tool-use payload on stdin; cannot evaluate the methodology gate."

_target="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    for k in ("file_path","notebook_path"):
        v=ti.get(k)
        if isinstance(v,str) and v: print(v); break
' 2>/dev/null || true)"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
_under() {
  [ -z "$2" ] && return 0
  python3 -c '
import os,posixpath,sys
r,t=sys.argv[1],sys.argv[2]
try: rr=posixpath.normpath(os.path.realpath(r).replace("\\","/"))
except Exception: sys.exit(1)
n=t.replace("\\","/"); a=n if posixpath.isabs(n) else posixpath.join(rr,n)
a=posixpath.normpath(a); real=posixpath.normpath(os.path.realpath(a).replace("\\","/"))
sys.exit(0 if (real==rr or real.startswith(rr+"/")) else 1)
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
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("eo: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("EO_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge methodology fields on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on methodology.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (methodology).")

    root = posixpath.normpath(os.environ["EO_ROOT"].replace("\\", "/"))
    PROPOSAL_RE = re.compile(r'^docs/issue-[0-9]+/proposals/.*execution-observation.*\.md$', re.I)
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/execution-observation\.md$')

    def resolve(p):
        n = p.replace("\\", "/")
        a = n if posixpath.isabs(n) else posixpath.join(root, n)
        a = posixpath.normpath(a)
        try:
            return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
        except OSError:
            return a

    path = None
    if tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)

    r = resolve(path)
    if not r.startswith(root + "/"):
        sys.exit(0)
    rel = r[len(root):].lstrip("/")

    is_proposal = bool(PROPOSAL_RE.match(rel))
    is_record = bool(RECORD_RE.match(rel))
    if not (is_proposal or is_record):
        sys.exit(0)  # not an execution-observation methodology write surface — not this gate's business

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on methodology." % rel)

    new_text = None
    if tool == "Write":
        c = ti.get("content")
        if isinstance(c, str):
            new_text = c
    elif tool == "Edit":
        o, n = ti.get("old_string"), ti.get("new_string")
        if isinstance(o, str) and isinstance(n, str) and current is not None and o in current:
            new_text = current.replace(o, n, 1)
    elif tool == "MultiEdit":
        edits = ti.get("edits")
        text = current
        if isinstance(edits, list) and text is not None:
            ok = True
            for e in edits:
                if not isinstance(e, dict):
                    ok = False; break
                o, n = e.get("old_string"), e.get("new_string")
                if not isinstance(o, str) or not isinstance(n, str) or o not in text:
                    ok = False; break
                text = text.replace(o, n, 1)
            if ok:
                new_text = text

    if new_text is None:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so the methodology fields can be "
            "checked." % (rel, tool)
        )

    low = new_text.lower()

    def has_any(*needles):
        return any(nd in low for nd in needles)

    missing = []

    if is_proposal:
        # a. ## Scope heading
        if "## Scope" not in new_text:
            missing.append("eo-directive: '## Scope' heading missing")

        # b. issue/PR number pattern
        if not (re.search(r'#\d+', new_text) or re.search(r'issue-\d+', new_text, re.I)):
            missing.append("eo-directive: no issue/PR number pattern (#<n> or issue-<n>) present")

        # c. current-state-survey path reference
        if not re.search(r'docs/issue-\d+/reports/execution-observation', new_text, re.I):
            missing.append("eo-directive: no current-state-survey path reference (docs/issue-<n>/reports/execution-observation) present")

        # d. verdict-level plan: at least two of outcome/trajectory/step
        levels = ("outcome", "trajectory", "step")
        level_count = sum(1 for w in levels if w in low)
        if level_count < 2:
            missing.append("eo-directive: no stated verdict-level plan (need at least two of outcome/trajectory/step)")

        # e. plugin-list section
        if not has_any("플러그인 목록", "plugin list", "plugin 목록"):
            missing.append("eo-directive: no plugin-list section (플러그인 목록 / plugin list / plugin 목록)")

        # f. prohibition: premature verdict language
        verdict_phrases = (
            "outcome: sound", "outcome: deficient",
            "trajectory: sound", "trajectory: deficient",
            "step: sound", "step: deficient",
        )
        if has_any(*verdict_phrases):
            missing.append("eo-directive: premature verdict language in phase-1 proposal")

    else:  # is_record
        # a. independence-statement-before-verdict ordering
        indep_idx = low.find("independence statement")
        verdict_markers = ("outcome:", "trajectory:", "step:", "sound", "deficient")
        marker_idx = None
        for m in verdict_markers:
            i = low.find(m)
            if i != -1 and (marker_idx is None or i < marker_idx):
                marker_idx = i
        if marker_idx is not None and (indep_idx == -1 or marker_idx < indep_idx):
            missing.append("eo-directive: independence-before-verdict-ordering")

        # b. all three verdict levels present
        levels = ("outcome", "trajectory", "step")
        absent_levels = [w for w in levels if w not in low]
        if absent_levels:
            missing.append("eo-directive: missing-verdict-level(s): %s" % ", ".join(absent_levels))

        # c. blameless shape, only when a deficiency/finding is claimed
        if has_any("deficient", "finding"):
            blameless = ("impact", "timeline", "root cause", "action item")
            absent_blameless = [w for w in blameless if w not in low]
            if absent_blameless:
                missing.append("eo-directive: blameless-shape-incomplete: %s" % ", ".join(absent_blameless))

        # d. eo-state marker-shaped check
        marker_path = posixpath.join(root, ".claude", ".eo-read-marker")
        if not os.path.isfile(marker_path):
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
