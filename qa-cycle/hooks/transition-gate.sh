#!/usr/bin/env bash
# --- fail-closed trap (must stay the first executable statement) ---
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook: the QA cycle gate.
#
# Reads the transition table below (encoded from
# docs/specs/qa-cycle-state-machine.md "Transition table" — that file is the
# source; this table is a copy for runtime speed, not a re-derivation) and,
# for the specific feedback item a write touches, that item's current state
# from state.md. A write that would change one item's state is allowed only
# when (current-state -> attempted-state) is a row in that table for that
# item, and, for every row the table marks Actor: human, only when a
# matching unconsumed verdict token for that exact item and (from, to) pair
# sits next to state.md.
#
# state.md now holds one record per feedback item (see docs/handbooks/qa-cycle.md
# "The state file"), not a single project-wide `phase`. This gate is keyed on
# the item axis throughout.
#
# Fails closed: refusal is the default outcome of this script. Every path
# that is not an affirmative match against the transition table — unreadable
# stdin, a malformed payload, a missing/malformed state file, a missing or
# mismatched verdict token, an ambiguous write touching more than one item's
# state — exits 2. Allow (exit 0) is reached
# only via the single explicit success path at the bottom of the embedded
# Python, after the attempted (item, from -> to) has been matched against
# the table and, for human-actor rows, after a matching unconsumed token has
# been found and reserved for consumption.
#
# Kill switch: export QA_CYCLE_DISABLE=1 — this is a deliberate operator
# override (an explicit opt-out someone set on purpose), not an instance of
# the silent-allow bug this file otherwise closes. It intentionally exits 0
# before any of the refuse-by-default logic below runs.
set -euo pipefail

case "${QA_CYCLE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || { echo "qa-cycle: python3 not found; refusing rather than allowing an unchecked write." >&2; exit 2; }

# --- gate-protection root resolution (contract: docs/proposals/2026-07-26-gate-root-from-project-dir.md) ---
# root candidate: CLAUDE_PROJECT_DIR when set; otherwise the git top-level of
# cwd. (This hook has no reliable access to the PreToolUse target path before
# the JSON payload is parsed below, so — same as every other repo-local check
# in this preamble, which already runs before payload parsing — the fallback
# here is cwd's git top-level rather than the target path's.)
#
# The handoff contract, and the records-tree root used further down
# (QA_CYCLE_REPO_ROOT), are both keyed off this one resolved root. No
# parent-directory walk, no reference to any sibling repo, no comparison
# against another repo's git history or SHA: this rulebook is a plugin
# installed into a work repo, and the only contract that can bind a
# handoff-protocol action is the one that repo itself carries.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  _contract_repo_root="${CLAUDE_PROJECT_DIR%/}"
else
  if ! command -v git >/dev/null 2>&1 || ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "qa-cycle: refused — this repo has no collaboration contract yet (CLAUDE_PROJECT_DIR is unset and this is not inside a git repository, so no root to resolve docs/specs/role-handoff-contract.md against). Refusing handoff-protocol actions rather than proceeding without one." >&2
    exit 2
  fi
  _contract_repo_root="$(git rev-parse --show-toplevel)"
fi

# root VALIDITY (contract): the resolved root must be a plausible project
# root — either a git work-tree top-level, or a directory that itself
# carries docs/specs/role-handoff-contract.md. A CLAUDE_PROJECT_DIR pointing
# at an unrelated or empty directory (neither) is INDETERMINATE and refused
# outright, before any payload is even read — default-deny, never a silent
# pass-through to a downstream check that might not apply to this root at
# all.
if ! {
  [ -f "$_contract_repo_root/docs/specs/role-handoff-contract.md" ] \
  || {
    command -v git >/dev/null 2>&1 \
    && [ -d "$_contract_repo_root" ] \
    && [ "$(cd "$_contract_repo_root" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$_contract_repo_root" 2>/dev/null && pwd -P 2>/dev/null)" ]
  }
}; then
  echo "qa-cycle: refused — the resolved project root ($_contract_repo_root) is not a recognizable project root (no docs/specs/role-handoff-contract.md there, and it is not a git work-tree top-level itself). Refusing rather than trusting an unvalidated root." >&2
  exit 2
fi
if [ ! -f "$_contract_repo_root/docs/specs/role-handoff-contract.md" ]; then
  echo "qa-cycle: refused — this repo has no collaboration contract yet (no docs/specs/role-handoff-contract.md at $_contract_repo_root). Refusing handoff-protocol actions rather than proceeding without one." >&2
  exit 2
fi

# --- note on read-refusal (contract v2 conformance) -------------------------
# There is, and was, no kind-based read-refusal logic in this file to
# delete. This gate has never read docs/reports/records/<subject>/qa.md or
# any other role's record, so it has never blocked a read of one either.
# v1's "qa uniformly refuses hypothesis/build-proposal/feasibility-record/
# review-record/ops-state if handed over" lived entirely in README.md prose,
# never in this gate. The blackboard-record additions below (NEVER-OVERWRITE
# path check and the structural DEPENDS-ON `upstream:` check) are new write
# checks, not a relaxation of any prior read check — do not go looking for
# read-refusal code here to remove, there was never any to remove.

# --dump-facts is a read-only introspection path: it prints the same
# TABLE/FIELDS structures the decision logic below branches on, as JSON,
# and exits 0. It touches no state file and no token, and
# reads no stdin — it is not reachable from, and shares no code path with,
# any write decision. See qa-cycle/hooks/tests/directive-drift-check.sh,
# which is the only consumer.
#
# Argument handling is exact-match and total, the same refuse-by-default
# rule as the rest of this gate: the only two legal invocation shapes are
# zero arguments (the normal adjudication path) and exactly one argument
# that is the literal string "--dump-facts" (the diagnostic path). Any
# other argument, any extra argument alongside "--dump-facts", or any
# unrecognized flag is a refusal — never a silent fall-through to normal
# operation, and never a silent ignore.
dump_facts=0
if [ $# -eq 0 ]; then
  dump_facts=0
elif [ $# -eq 1 ] && [ "$1" = "--dump-facts" ]; then
  dump_facts=1
else
  echo "qa-cycle: refused — unrecognized arguments to transition-gate.sh. The only supported invocations are with no arguments (adjudicate a hook payload on stdin) or exactly \`--dump-facts\` alone (read-only diagnostic dump). Refusing rather than falling through to normal operation on an unrecognized argument shape." >&2
  exit 2
fi

# A caller with a hook payload to adjudicate is not making a diagnostic
# call. If stdin has data available, --dump-facts refuses rather than
# dumping — this is exactly the bypass a payload carrying --dump-facts as
# $1 would otherwise get: skipping adjudication entirely.
#
# `read -t 0` alone cannot tell "a payload is waiting" apart from "stdin is
# already at EOF" — both report as immediately readable, since consuming an
# EOF is itself instantaneous. So this peeks at most one real byte with a
# short timeout instead: if a byte arrives, a payload is present and this
# refuses; if the timeout elapses (an interactive terminal with nothing
# typed yet) or stdin is already at EOF (nothing was piped), no payload is
# present and the dump proceeds. This consumes up to one byte of stdin, but
# only on the --dump-facts path, which never reads a payload anyway — the
# normal adjudication path below is untouched and still reads its payload
# with a single `cat` exactly as it does today.
if [ "$dump_facts" = 1 ]; then
  if IFS= read -r -t 1 -n 1 _dump_facts_stdin_peek; then
    echo "qa-cycle: refused — --dump-facts was invoked with a hook payload present on stdin. --dump-facts is a read-only diagnostic path reachable only as a deliberate, standalone invocation; it never adjudicates a payload. Refusing rather than treating this as a diagnostic call." >&2
    exit 2
  fi
fi

if [ "$dump_facts" = 1 ]; then
  payload=""
else
  payload="$(cat)"
fi

set +e
QA_CYCLE_PAYLOAD="$payload" QA_CYCLE_REPO_ROOT="$_contract_repo_root" QA_CYCLE_DUMP_FACTS="$dump_facts" python3 <<'PY'
import json
import os
import posixpath
import re
import sys

# --- fail-closed on ANY internal error (frozen contract: gates DENY on error) ---
# Any uncaught exception in the judge below (e.g. os.path.realpath on a
# null-byte/undecodable path raising ValueError, which would otherwise exit 1
# = fail-OPEN for a PreToolUse hook) becomes exit 2 (DENY). not_applicable()/
# allow()/refuse() raise SystemExit, which does NOT pass through this hook, so
# the exact allow(0)/deny(2) verdict paths are preserved unchanged.
def _qa_fail_closed_excepthook(_t, _e, _tb):
    sys.stderr.write("qa-cycle: refused — fail-closed: internal error: %s\n" % (_e,))
    try:
        sys.stderr.flush()
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _qa_fail_closed_excepthook

def not_applicable():
    # This PreToolUse call is not a write this gate governs at all (wrong
    # tool, or a path outside the workspace's state.md shape). That is not
    # the same thing as a parse failure or an unexpected shape on a write
    # this gate *does* govern — those refuse, below. This is the only
    # function in this script that exits 0 other than the single explicit
    # allow() at the bottom, and it is reached only once we know the event
    # parsed cleanly as the expected top-level shape.
    sys.exit(0)

def allow():
    sys.exit(0)

def refuse(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)

# --- the transition table, from docs/specs/qa-cycle-state-machine.md -------
# (from, to, actor)  actor in {"agent", "human"}
#
# The spec's table is exhaustive for the 9 named states and has no row whose
# `from` is "(none)" — `observed` is the item's entry state and the spec
# never models item *creation* as a transition. This gate still needs one
# rule to admit the very first record of a brand-new item, so it adds a
# single bootstrap row, ("(none)", "observed", "agent"), not present in the
# spec's 11-row table. This is the only departure from the spec's table and
# is documented here and in docs/handbooks/qa-cycle.md.
# Each row carries its own preconditions in `requires`, so a precondition
# cannot live only in code the table says nothing about: the decision logic
# below reads `row["requires"]` to decide whether the token check or the
# severity check applies to a given row, rather than hard-coding "if actor
# == human, check token" / "if this is reproducing->reproduced, check
# severity" as separate, undeclared facts. `--dump-facts` (below) prints
# this exact structure — not a second list that mirrors it.
TABLE = [
    {"from": "(none)", "to": "observed", "actor": "agent", "requires": []},  # bootstrap: first record of a new item
    {"from": "observed", "to": "reproducing", "actor": "agent", "requires": ["target"]},
    {"from": "reproducing", "to": "reproduced", "actor": "agent", "requires": ["severity"]},
    {"from": "reproducing", "to": "observed", "actor": "agent", "requires": []},
    {"from": "reproducing", "to": "parked-unreproducible", "actor": "agent", "requires": []},
    {"from": "parked-unreproducible", "to": "observed", "actor": "agent", "requires": []},
    {"from": "reproduced", "to": "handed-off", "actor": "human", "requires": ["token"]},
    {"from": "reproduced", "to": "not-a-defect", "actor": "human", "requires": ["token"]},
    {"from": "reproduced", "to": "wont-fix", "actor": "human", "requires": ["token"]},
    {"from": "handed-off", "to": "re-verifying", "actor": "human", "requires": ["token"]},
    {"from": "re-verifying", "to": "verified-fixed", "actor": "agent", "requires": []},
    {"from": "re-verifying", "to": "reproducing", "actor": "agent", "requires": ["target"]},
]

# `priority` and `severity` are fields, not transitions — they sit beside
# the state machine rather than being rows in it. Made first-class here so
# `--dump-facts` can state their actor/requirements the same way it states
# a transition's, instead of leaving them to be discovered only by reading
# the code below.
FIELDS = [
    {"field": "severity", "actor": "agent", "requires": ["closed-set:critical,major,minor,trivial"]},
    {"field": "priority", "actor": "human", "requires": ["token", "closed-set:now,next,later,someday"]},
]

if os.environ.get("QA_CYCLE_DUMP_FACTS") == "1":
    # Read-only: nothing above this point touches state.md or a token file,
    # and nothing below this line runs.
    print(json.dumps({"transitions": TABLE, "fields": FIELDS}))
    sys.exit(0)

# Every row the table marks actor: human requires a matching unconsumed
# verdict token ("token" in that row's `requires`), keyed by the exact
# (item id, from, to) triple — not by the destination state alone.
# `handed-off` has exactly one legal outbound row and it is a human row, so
# "handed-off refuses every transition without a human trigger" falls
# directly out of table lookup; the explicit assertion below is a
# defensive backstop, not new logic.
ROW_OF = {(r["from"], r["to"]): r for r in TABLE}
ALLOWED = set(ROW_OF)

# --- severity and priority, per docs/specs/qa-cycle-state-machine.md
# "Severity and priority" -----------------------------------------------
#
# severity: closed set, agent-set, required (present and valid) whenever an
# item enters `reproduced` (i.e. the attempted transition is exactly
# reproducing -> reproduced). Exactly one `severity:` line is required;
# zero or multiple both mean "no severity."
#
# priority: closed set, human-set. Not required for any transition. Any
# write that changes an item's recorded `priority` value (including from
# unset to a value) requires a matching unconsumed priority verdict token
# bound to (item id, field name, new value), distinct from the
# state-transition token, reserved/finalized under the same
# reserve-then-finalize discipline.
SEVERITY_SET = {"critical", "major", "minor", "trivial"}
PRIORITY_SET = {"now", "next", "later", "someday"}

try:
    event = json.loads(os.environ.get("QA_CYCLE_PAYLOAD", ""))
except ValueError:
    refuse("qa-cycle: refused — the hook payload on stdin could not be parsed as JSON. Refusing rather than allowing a write this gate cannot inspect.")
if not isinstance(event, dict):
    refuse("qa-cycle: refused — the hook payload did not parse to a JSON object. Refusing rather than allowing a write this gate cannot inspect.")

tool = event.get("tool_name") or ""
tool_input = event.get("tool_input")

# --- write-target resolution (contract: docs/proposals/2026-07-26-fix-state-gate-writeop-bypass.md) ---
# Which tool ran is not what decides whether this is a write this gate must
# inspect — the TARGET PATH is. A tool-name allowlist ("only Write/Edit are
# writes") is exactly the bypass this replaces: a Bash call that writes a
# file (e.g. `python3 -c "open(path,'w').write(...)"`, a shell redirect, a
# `tee`) is just as much a write as a Write/Edit call, and must be
# adjudicated the same way. Nothing here weakens the tool-agnostic checks
# below; it only changes how `path` (the thing those checks inspect) is
# obtained.
if tool in ("Write", "Edit"):
    if not isinstance(tool_input, dict):
        refuse("qa-cycle: refused — a %s call arrived with no readable tool_input. Refusing rather than allowing an uninspectable write." % tool)
    path = tool_input.get("file_path")
    if not isinstance(path, str) or not path:
        refuse("qa-cycle: refused — a %s call arrived with no readable file_path. Refusing rather than allowing an uninspectable write." % tool)
elif tool == "NotebookEdit":
    if not isinstance(tool_input, dict):
        refuse("qa-cycle: refused — a %s call arrived with no readable tool_input. Refusing rather than allowing an uninspectable write." % tool)
    path = tool_input.get("notebook_path")
    if not isinstance(path, str) or not path:
        refuse("qa-cycle: refused — a %s call arrived with no readable notebook_path. Refusing rather than allowing an uninspectable write." % tool)
elif tool == "Bash":
    if not isinstance(tool_input, dict):
        refuse("qa-cycle: refused — a Bash call arrived with no readable tool_input. Refusing rather than allowing an uninspectable write.")
    command = tool_input.get("command")
    if not isinstance(command, str) or not command:
        refuse("qa-cycle: refused — a Bash call arrived with no readable command. Refusing rather than allowing an uninspectable write.")

    # A Bash command's write target cannot be determined with the same
    # confidence as a Write/Edit's file_path: it is an arbitrary shell
    # program that may write anywhere via redirection, `python3 -c`, `tee`,
    # `cp`, `sed -i`, etc. Rather than try to parse shell semantics
    # correctly (and inevitably miss a case), this pulls every path-shaped
    # token out of the command (quoted or bare, containing a `/`) as a
    # *candidate* write target and checks whether any candidate resolves
    # into the owned record tree (docs/reports/records/). If the command
    # references that tree at all, this refuses — a Bash write into that
    # tree can never be confirmed to be a legal, content-validated
    # transition the way a Write/Edit call can (the content-shape checks
    # below key off tool_input.content / tool_input.new_string, which a
    # Bash call does not have), so "cannot confirm" and "targets the
    # record tree" together are default-deny territory per the contract,
    # regardless of which subject/role the candidate path names.
    _bash_tokens = []
    for _m in re.finditer(r"'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"|(\S+)", command):
        _tok = _m.group(1) if _m.group(1) is not None else (_m.group(2) if _m.group(2) is not None else _m.group(3))
        if _tok and "/" in _tok:
            _bash_tokens.append(_tok)

    _repo_root_for_bash = os.environ.get("QA_CYCLE_REPO_ROOT", "")
    _repo_root_for_bash_real = posixpath.normpath(os.path.realpath(_repo_root_for_bash).replace("\\", "/")) if _repo_root_for_bash else ""
    _bash_records_root = (_repo_root_for_bash_real + "/docs/reports/records") if _repo_root_for_bash_real else ""

    _bash_hits_records_tree = False
    _bash_hit_tok = None
    for _tok in _bash_tokens:
        _tok_norm = _tok.replace("\\", "/")
        _tok_abs = posixpath.normpath(_tok_norm if posixpath.isabs(_tok_norm) else posixpath.join(os.getcwd(), _tok_norm))
        if _bash_records_root and (_tok_abs == _bash_records_root or _tok_abs.startswith(_bash_records_root + "/")):
            _bash_hits_records_tree = True
            _bash_hit_tok = _tok_norm
            break
        # Also treat a bare relative reference to the tree (not resolvable
        # to an absolute path from cwd alone, e.g. embedded in a larger
        # expression) as a hit — conservative on purpose.
        if "docs/reports/records/" in _tok_norm:
            _bash_hits_records_tree = True
            _bash_hit_tok = _tok_norm
            break

    if not _bash_hits_records_tree:
        # No reference to the owned record tree found anywhere in the
        # command: this gate has nothing further to say about it (it may
        # still be a write, just not one to a path this gate governs).
        not_applicable()

    # --- path-reference default-deny (contract: docs/proposals/2026-07-26-gate-nested-shell-default-deny.md) ---
    # A Bash command that references a path inside the owned record tree —
    # whether it names qa's own record or another role's — is DEFAULT-DENIED
    # unless the reference can be *proven* read-only: read-only-shaped
    # commands only, no shell nesting (sh -c/bash -c/eval), no command
    # substitution ($( )/backtick), and no write idiom anywhere in the
    # command. This is a strictly stronger bar than idiom-matching: the
    # write-idiom list below is one trigger for "cannot prove read-only",
    # not the exhaustive definition of a write.
    WRITE_IDIOM_RE = re.compile(
        r"open\s*\([^)]*,\s*['\"]?[wax]"
        r"|\.write\s*\("
        r"|\.write_text\s*\("
        r"|\.write_bytes\s*\("
        r"|os\.write\s*\("
        r"|(?<![0-9&])>{1,2}(?![&|])"
        r"|\btee\b"
        r"|\bdd\b"
    )
    NESTED_SHELL_RE = re.compile(r"\b(?:sh|bash)\s+-c\b|\beval\b")
    READ_ONLY_CMDS = {
        "cat", "grep", "egrep", "fgrep", "head", "tail", "test", "ls", "[",
        "wc", "find", "stat", "file", "sort", "uniq", "cut", "diff",
        "md5sum", "sha256sum",
    }

    def _command_substitution_free(cmd):
        return "$(" not in cmd and "`" not in cmd

    def _no_nested_shell(cmd):
        return NESTED_SHELL_RE.search(cmd) is None

    def _no_write_idiom(cmd):
        return WRITE_IDIOM_RE.search(cmd) is None

    def _only_read_commands(cmd):
        for seg in re.split(r"[;\n]|&&|\|\|", cmd):
            for part in seg.split("|"):
                part = part.strip()
                if not part:
                    continue
                words = part.split()
                if not words:
                    continue
                first = words[0]
                # skip leading VAR=value assignments
                idx = 0
                while idx < len(words) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[idx]):
                    idx += 1
                if idx >= len(words):
                    continue
                first = words[idx].rstrip("()")
                if first not in READ_ONLY_CMDS:
                    return False
        return True

    def _proven_read_only(cmd):
        return (
            _command_substitution_free(cmd)
            and _no_nested_shell(cmd)
            and _no_write_idiom(cmd)
            and _only_read_commands(cmd)
        )

    if _proven_read_only(command):
        # Read-only proven: this reference to the record tree is not a
        # write this gate governs.
        not_applicable()

    # Not proven read-only. The one narrow carve-out: a PLAIN redirection
    # (>, >>) — no shell nesting, no command substitution, no other write
    # idiom mixed in — targeting qa's OWN record path is still adjudicated
    # as a possible legal state transition, exactly as a Write/Edit to that
    # same path would be (contract: "자기 레코드 평이 리다이렉션 write가
    # 합법 상태전이면 여전히 허용"). Everything else — any foreign-role
    # reference, or any self reference that is not a plain redirection —
    # is refused outright.
    _hit_norm = (_bash_hit_tok or "").replace("\\", "/")
    _own_hit = False
    _m_owner = re.search(r"docs/reports/records/([^/\s'\"]+)/([^\s'\"]+)", _hit_norm)
    if _m_owner:
        _hit_subject, _hit_rest = _m_owner.group(1), _m_owner.group(2)
        _own_hit = _hit_rest == "qa.md" or _hit_rest.startswith("qa/")

    _plain_redirect_only = (
        _command_substitution_free(command)
        and _no_nested_shell(command)
        and re.search(r"(?<![0-9&])>{1,2}(?![&|])", command) is not None
        and re.search(
            r"open\s*\([^)]*,\s*['\"]?[wax]|\.write\s*\(|\.write_text\s*\(|\.write_bytes\s*\(|os\.write\s*\(|\btee\b|\bdd\b",
            command,
        ) is None
    )

    if not (_own_hit and _plain_redirect_only):
        refuse(
            "qa-cycle: refused — a Bash command references the owned record tree "
            "(docs/reports/records/) at %r and this reference cannot be proven read-only "
            "(no shell nesting, no command substitution, no write idiom). Path-reference "
            "default-deny applies to any such reference, whether it names qa's own record "
            "or another role's." % (_bash_hit_tok,)
        )

    # Plain self-redirection: extract the redirection target and the
    # content being written, and adjudicate it exactly as the Write/Edit
    # path below adjudicates a qa.md write — same structural checks
    # (kind:, DEPENDS-ON), never a second, looser code path.
    _redir_m = re.search(r">{1,2}\s*(\S+)\s*$", command.strip())
    if not _redir_m:
        refuse("qa-cycle: refused — could not identify the redirection target in this command. Refusing rather than guessing.")
    _redir_target_raw = _redir_m.group(1).strip("'\"")
    _redir_target_norm = _redir_target_raw.replace("\\", "/")
    _redir_target_abs = posixpath.normpath(_redir_target_norm if posixpath.isabs(_redir_target_norm) else posixpath.join(os.getcwd(), _redir_target_norm))
    if not (_bash_records_root and (_redir_target_abs == _bash_records_root or _redir_target_abs.startswith(_bash_records_root + "/"))):
        refuse("qa-cycle: refused — the redirection target does not resolve into the owned record tree the same way the matched reference did. Refusing rather than trusting a mismatch.")

    _producer = command[:_redir_m.start()].strip()
    _content_m = re.search(r"'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"", _producer)
    if not _content_m:
        refuse("qa-cycle: refused — could not extract the literal content this redirection writes. Refusing rather than adjudicating unreadable content.")
    _bash_content = _content_m.group(1) if _content_m.group(1) is not None else _content_m.group(2)
    _bash_content = _bash_content.replace("\\n", "\n").replace("\\t", "\t").replace("\\'", "'").replace('\\"', '"')

    tool_input = {"file_path": _redir_target_abs.replace(_repo_root_for_bash_real, _repo_root_for_bash, 1) if _repo_root_for_bash_real else _redir_target_abs, "content": _bash_content}
    tool = "Write"
    path = tool_input["file_path"]
    # Falls through to the normal path-resolution and blackboard-record
    # checks below, exactly as a Write call targeting this same path and
    # content would.
else:
    # Not a write-shaped tool call at all; this gate has nothing to say
    # about it. Distinct from the malformed-shape refusals above and below.
    not_applicable()

path_norm = path.replace("\\", "/")
path_abs = posixpath.normpath(path_norm if posixpath.isabs(path_norm) else posixpath.join(os.getcwd(), path_norm))
path_real = posixpath.normpath(os.path.realpath(path_abs).replace("\\", "/"))

# project_dir is set below, only when this write targets exactly
# docs/reports/records/<subject>/qa/state.md (the item-level state machine's
# one governed file). Any other path — including every other file under
# qa/** — either allow()s or refuse()s inside the records-tree block below
# and never reaches the item-level machine at all.
project_dir = None


def attempted_content_generic():
    """Same shape as attempted_content() below, but usable before that
    function is defined and without assuming the state.md item-block
    context — used only by the blackboard-record path below."""
    if tool == "Write":
        c = tool_input.get("content")
    else:  # Edit
        c = tool_input.get("new_string")
    if not isinstance(c, str):
        refuse("qa-cycle: refused — could not read the new content of this write, so it cannot be checked.")
    return c


# --- qa's record area: docs/reports/records/<subject>/qa.md and qa/** ------
# Contract v2 §10 is qa's sole record store now: the blackboard record
# (qa.md) and every piece of durable QA evidence — intake, plan, run
# records, evidence, state.md, tokens/ — all live under this one repo-root-
# resolved tree. There is no second, external, host-local store any of this
# ever falls back to. This path is resolved and containment-checked against
# the *repo root* already resolved above for the contract-presence check
# (_contract_repo_root, passed through as QA_CYCLE_REPO_ROOT).
#
# A write to qa.md gets the kind:/DEPENDS-ON structural checks below and
# then allow()s. A write to exactly qa/state.md falls through to the
# item-level transition machine further down (project_dir is set here and
# left unset for every other path). A write to any other file under qa/**
# (intake.md, plan.md, runs/**, target.md, tokens/**, and any other
# evidence) is allow()d here directly — qa already owns this whole subtree;
# there is no further structural check this gate applies to those files.
_repo_root = os.environ.get("QA_CYCLE_REPO_ROOT", "")
_repo_root_real = posixpath.normpath(os.path.realpath(_repo_root).replace("\\", "/")) if _repo_root else ""
if _repo_root_real:
    _records_root = _repo_root_real + "/docs/reports/records"
    if path_real == _records_root or path_real.startswith(_records_root + "/"):
        _records_rel = path_real[len(_records_root) + 1:]
        _rparts = _records_rel.split("/")
        if len(_rparts) >= 2 and _rparts[0]:
            _subject, _second = _rparts[0], _rparts[1]
            _is_qa_owned = (_second == "qa.md" and len(_rparts) == 2) or (_second == "qa" and len(_rparts) >= 2)

            if not _is_qa_owned:
                # NEVER-OVERWRITE (contract §11, qa's row): qa owns exactly
                # docs/reports/records/<subject>/qa.md and
                # docs/reports/records/<subject>/qa/** under this subject.
                # Anything else under docs/reports/records/<subject>/ (e.g.
                # coding.md, review.md) is another role's path.
                refuse(
                    "qa-cycle: refused — %s is under docs/reports/records/%s/ but is not one of qa's owned "
                    "paths (qa.md or qa/**). NEVER-OVERWRITE (contract §11): qa may not write another role's "
                    "record path." % (path, _subject)
                )

            if _second == "qa.md":
                _content = attempted_content_generic()

                # Comment-tolerant `kind:` parser (contract §2: "kind
                # parsing by any gate must tolerate a trailing comment on
                # the line"), built on the same template as the existing
                # ITEM_KEY/STATE_KEY patterns below. No `^kind:`-style
                # regex existed anywhere in this repo before this addition.
                KIND_KEY = re.compile(r"^kind:\s*(.*?)\s*(?:#.*)?$", re.M)
                _kind_matches = KIND_KEY.findall(_content)
                _kind = _kind_matches[0].strip() if len(_kind_matches) == 1 and _kind_matches[0].strip() else None

                # DEPENDS-ON structural check (contract §4, §11, §14): the
                # only mechanically detectable violation is a qa.md write
                # whose own upstream fields cite a non-empty sha/path
                # pointing at another role's record kind, with no
                # acknowledged_sha, as if it were a dependency basis.
                # DEPENDS-ON is empty for qa — qa may READ any record as
                # advisory context but must never cite one as its verdict's
                # basis. This check cannot see a verdict's prose citing
                # another role's record by name in free text; per §14,
                # that stays a documentation-only rule beyond this
                # structural check.
                def _field(key):
                    m = re.search(r"^%s:\s*(.*?)\s*(?:#.*)?$" % re.escape(key), _content, re.M)
                    v = m.group(1).strip() if m else ""
                    return v or None

                _upstream_kind = _field("upstream_kind")
                _upstream_sha = _field("upstream_sha")
                _upstream_path = _field("upstream_path")
                _acknowledged_sha = _field("acknowledged_sha")

                if (
                    _upstream_kind
                    and _upstream_kind != "qa-record"
                    and (_upstream_sha or _upstream_path)
                    and not _acknowledged_sha
                ):
                    refuse(
                        "qa-cycle: refused — this qa.md write's upstream fields cite kind %r (upstream_sha=%r, "
                        "upstream_path=%r) with no acknowledged_sha. DEPENDS-ON is empty for qa (contract §4, "
                        "§11): qa may READ another role's record as advisory context, but a qa verdict may "
                        "never be built on another role's record as its basis. This is the structurally "
                        "checkable case only (contract §14)." % (_upstream_kind, _upstream_sha, _upstream_path)
                    )

            if _second == "qa" and len(_rparts) == 3 and _rparts[2] == "state.md":
                # The one file under qa/** the item-level transition machine
                # governs. Set project_dir and fall through to that machine
                # below instead of allow()ing here directly.
                project_dir = _records_root + "/" + _subject + "/qa"
            else:
                allow()

# --- item-level state.md machine --------------------------------------
# Governs exactly docs/reports/records/<subject>/qa/state.md. project_dir is
# set above only when this write targets that one file; any other path
# either allow()d or refuse()d already and never reaches here.
if project_dir is None:
    not_applicable()

# An item id is validated by allow-list, at the point it is read, before it
# is used in any path or any comparison: ASCII letters, digits, hyphen, and
# underscore only, length 1..64, never starting with a hyphen. Anything
# outside this shape is not an item id — rejected by pattern, never
# sanitized. This is what stops a value like
# "../../../../../../../../tmp/evil-item" from ever becoming an item_id in
# the first place, closing the path-traversal bypass of the human-only gate
# recorded in docs/reports/2026-07-31-hunt-item-axis-enforcement.md.
ITEM_ID_RE = re.compile(r"^(?!-)[A-Za-z0-9_-]{1,64}$")

state_path = posixpath.join(project_dir, "state.md")
tokens_dir = posixpath.join(project_dir, "tokens")

# project_dir was built from _subject, which was itself read out of
# path_real (an already-resolved, already-containment-checked path under
# _records_root). Belt-and-braces on top of that: re-resolve project_dir
# and re-check its containment against _records_root before it is used for
# any further read or write below.
project_dir_real = posixpath.normpath(os.path.realpath(project_dir).replace("\\", "/"))
if not (project_dir_real == _records_root or project_dir_real.startswith(_records_root + "/")):
    refuse("qa-cycle: refused — the resolved record directory for this write escapes docs/reports/records/. Refusing rather than reading or writing outside it.")
project_dir = project_dir_real

# --- per-item record parsing -------------------------------------------
# state.md holds a chain of item blocks. Each block is its own
# `---`-delimited frontmatter-shaped document:
#
#   ---
#   item: <id>
#   state: <one of the 9 spec states>
#   reproduction: <procedure text, once recorded>
#   evidence: <evidence for the most recent transition>
#   transition: <from> -> <to>
#   ---
#
# Recognized ONLY as blocks opened by a `---` line at the start of a line
# and closed by a later `---` line — never a bare `item:`/`state:` pair
# floating outside a block.
BLOCK_RE = re.compile(r"^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*\r?\n?", re.M | re.S)
ITEM_KEY = re.compile(r"^item:\s*(.*?)\s*(?:#.*)?$", re.M)
STATE_KEY = re.compile(r"^state:\s*(.*?)\s*(?:#.*)?$", re.M)


def field_values(block, key):
    """All values of `key:` lines in a block, in order. Never raises."""
    pattern = re.compile(r"^%s:\s*(.*?)\s*(?:#.*)?$" % re.escape(key), re.M)
    return pattern.findall(block)


def block_severity(block):
    """The item's attempted `severity`, or None if absent/ambiguous/empty.
    Per contract: exactly one `severity:` line is required; zero or
    multiple lines both mean "no severity." Does NOT itself refuse on an
    out-of-set value — callers that require a valid severity check
    membership in SEVERITY_SET themselves so they can produce a specific
    refusal message."""
    vals = field_values(block, "severity")
    if len(vals) != 1:
        return None
    v = vals[0].strip()
    return v if v else None


def block_priority(block, item_id):
    """The item's attempted `priority`, or None if absent/empty. Refuses
    outright (malformed shape) on more than one `priority:` line, or on a
    non-empty value outside the closed set — priority is never silently
    treated as absent when malformed, unlike severity, because a
    malformed priority could otherwise be used to dodge the token check
    below by making "old != new" evaluate on a value the gate never
    actually validated."""
    vals = field_values(block, "priority")
    if len(vals) > 1:
        refuse("qa-cycle: refused — item %s: more than one `priority:` line in one record. Refusing rather than guessing which is meant." % item_id)
    if len(vals) == 0:
        return None
    v = vals[0].strip()
    if not v:
        return None
    if v not in PRIORITY_SET:
        refuse("qa-cycle: refused — item %s: priority %r is not one of the closed set {%s}." % (item_id, v, ", ".join(sorted(PRIORITY_SET))))
    return v


def parse_blocks(text):
    """Return a list of raw block bodies (the text between one pair of ---
    delimiters each). Never raises; an unparseable file yields []."""
    return [m.group(1) for m in BLOCK_RE.finditer(text)]


def block_item_and_state(block):
    """Return (item_id, state) for a block, or (None, None) if the block
    does not declare exactly one non-empty item id and exactly one
    non-empty state — either of which is a refusal, never a guess."""
    items = ITEM_KEY.findall(block)
    states = STATE_KEY.findall(block)
    if len(items) != 1 or len(states) != 1:
        return None, None
    item_id = items[0].strip()
    state = states[0].strip()
    if not item_id or not state:
        return None, None
    # Validated here, at the point the id is read out of the block, before
    # it is used in any comparison or path anywhere downstream. A value
    # that fails the allow-list is not an item id at all: treat the block
    # as unparseable, the same as a missing item:/state: pair, rather than
    # trying to strip or repair it.
    if not ITEM_ID_RE.match(item_id):
        return None, None
    return item_id, state


def item_state_from_text(text, item_id):
    """Current state of item_id as recorded in text, or None if it cannot
    be established unambiguously (item absent -> "(none)" is returned
    instead, which is a valid, well-defined starting state, not a
    refusal)."""
    matches = []
    for block in parse_blocks(text):
        bid, bstate = block_item_and_state(block)
        if bid == item_id:
            matches.append(bstate)
    if not matches:
        return "(none)"
    if len(matches) != 1 or matches[0] is None:
        return None
    return matches[0]


def item_priority_from_text(text, item_id):
    """Currently recorded priority for item_id in text, or None if absent
    or the item has no record yet. Loose on purpose: text here is state.md's
    own last-approved content, already validated on the write that produced
    it; this is a read of settled state, not a fresh validation."""
    for block in parse_blocks(text):
        bid, bstate = block_item_and_state(block)
        if bid == item_id:
            vals = field_values(block, "priority")
            if len(vals) == 1 and vals[0].strip():
                return vals[0].strip()
            return None
    return None


def current_state_text():
    if not os.path.exists(state_path):
        return ""
    # A truncated read is never a verdict: this gate judges structure
    # (block count, item/state pairs) over the *whole* file, so a cap that
    # silently drops the tail could make an ambiguous file (e.g. two blocks
    # for the same item, the second past the cap) look well-formed. Read one
    # byte past the cap; if that extra byte materializes, the file exceeds
    # what this gate can adjudicate and it refuses rather than guessing from
    # a prefix.
    cap = 1 << 20
    try:
        with open(state_path, encoding="utf-8-sig") as fh:
            text = fh.read(cap + 1)
    except (OSError, UnicodeDecodeError):
        refuse("qa-cycle: refused — %s exists but could not be read. Fix or remove it before attempting a transition." % state_path)
    if len(text) > cap:
        refuse(
            "qa-cycle: refused — %s exceeds the %d-byte cap this gate reads. An oversized state file is an "
            "unadjudicable input; refusing rather than judging structure from a truncated prefix." % (state_path, cap)
        )
    return text


def attempted_content():
    content = None
    if tool == "Write":
        content = tool_input.get("content")
    else:  # Edit
        content = tool_input.get("new_string")
    if not isinstance(content, str):
        refuse("qa-cycle: refused — could not read the new content of this write, so the attempted item state cannot be determined.")
    return content


cur_text = current_state_text()
new_text = attempted_content()

new_blocks = parse_blocks(new_text)
if not new_blocks:
    refuse("qa-cycle: refused — the write does not declare any item in valid `---`-delimited block form (each block needs its own `item:` and `state:` keys). Nothing for the gate to authorize.")

# Determine which single item this write touches. A block "touches" its
# item if either its state differs from the currently recorded state (a
# transition attempt) or its priority differs from the currently recorded
# priority (a priority-verdict attempt) — these are independent axes and
# either alone, or both together on the same item, is a legal shape for one
# write. More than one item touched on either axis, or a block that fails
# to parse its own item/state pair, is refused as ambiguous. Every block's
# priority shape is validated (block_priority refuses on malformed shape)
# regardless of whether that item ends up being the one touched, so a
# malformed `priority:` line elsewhere in the same file cannot be smuggled
# through by pointing the gate's attention at a different item.
state_changed = []
priority_changed = []
priority_new_by_item = {}
for block in new_blocks:
    item_id, new_state = block_item_and_state(block)
    if item_id is None or new_state is None:
        refuse("qa-cycle: refused — the write contains a block with no readable, unambiguous `item:` and `state:` pair. Refusing rather than guessing which item or state is meant.")
    old_state = item_state_from_text(cur_text, item_id)
    if old_state is None:
        refuse("qa-cycle: refused — %s already holds an ambiguous record for item %s (more than one block, or an unreadable state). The current state cannot be established, so no write is permitted." % (state_path, item_id))
    if old_state != new_state:
        state_changed.append((item_id, old_state, new_state))

    new_priority = block_priority(block, item_id)
    priority_new_by_item[item_id] = new_priority
    old_priority = item_priority_from_text(cur_text, item_id)
    if old_priority != new_priority:
        priority_changed.append(item_id)

touched_items = {i for i, _, _ in state_changed} | set(priority_changed)
if len(touched_items) == 0:
    refuse("qa-cycle: refused — this write does not change any item's recorded state or priority. There is no transition or priority verdict here for the gate to authorize.")
if len(touched_items) > 1:
    refuse("qa-cycle: refused — this write changes more than one item's state or priority in a single operation (%s). Each transition or priority verdict must be its own write so the gate can authorize it individually." % ", ".join(sorted(touched_items)))

item_id = next(iter(touched_items))
state_change_for_item = next(((i, f, t) for i, f, t in state_changed if i == item_id), None)


def legal_from(state):
    return sorted({r["to"] for r in TABLE if r["from"] == state})


if state_change_for_item is not None:
    _, cur, new = state_change_for_item

    if (cur, new) not in ALLOWED:
        legal = legal_from(cur)
        refuse(
            "qa-cycle: refused — item %s: %s -> %s is not a transition docs/specs/qa-cycle-state-machine.md permits.\n"
            "Current state: %s. Transitions legal from here: %s."
            % (item_id, cur, new, cur, ", ".join(legal) if legal else "(none)")
        )

    row = ROW_OF[(cur, new)]
    actor = row["actor"]
    requires = row["requires"]

    # Defensive backstop for the spec's "handed-off refuses every transition
    # without a human trigger, without exception": the only legal outbound row
    # from handed-off is already a human row, so this can never trip in
    # practice against the table above — it exists so a future table edit that
    # quietly added an agent-actor row out of handed-off would still be caught.
    if cur == "handed-off" and actor != "human":
        refuse("qa-cycle: refused — item %s is handed-off; no transition out of handed-off is permitted without a human trigger, without exception." % item_id)

    # severity precondition: an item cannot enter `reproduced` without a
    # valid severity already present in the attempted write. Only rows that
    # declare "severity" in their own `requires` carry this precondition —
    # currently exactly reproducing -> reproduced — see docs/specs/
    # qa-cycle-state-machine.md "Severity and priority".
    # target precondition: an item cannot enter `reproducing` without a
    # valid target declaration already on disk for this project. This
    # attaches to the DESTINATION state, not to one row: every row in TABLE
    # whose `to` is "reproducing" declares "target" in its own `requires`
    # (currently observed -> reproducing and re-verifying -> reproducing),
    # the same generic per-row mechanism `severity` uses on
    # reproducing -> reproduced — see docs/specs/qa-cycle-state-machine.md
    # "Target declaration". target.md is agent-writable; this gate holds
    # the transition to the declaration's *content* (a valid, non-empty
    # entry_point and label), not to who wrote it.
    if "target" in requires:
        # project_dir was already resolved and containment-checked against
        # _records_root above; independently, the path built from it here is
        # resolved to a real path and re-checked before it is opened.
        target_path = posixpath.join(project_dir, "target.md")
        target_path_real = posixpath.normpath(os.path.realpath(target_path).replace("\\", "/"))
        if not (target_path_real == _records_root or target_path_real.startswith(_records_root + "/")):
            refuse("qa-cycle: refused — the resolved target declaration path for this write escapes docs/reports/records/. Refusing rather than reading outside it.")

        if not os.path.exists(target_path_real):
            refuse(
                "qa-cycle: refused — item %s: %s -> reproducing requires a target declaration at %s and none "
                "is present. The agent writes target.md (label, entry_point, env_names — names only, never values) "
                "before attempting this transition." % (item_id, cur, target_path)
            )
        # A truncated read is never a verdict: block count (len == 1) is
        # judged over the whole file, never a prefix — a second `---` block
        # that falls past a silent cap must not be able to flip an
        # ambiguous, refuse-worthy file into a well-formed one. Read one
        # byte past the cap; if that extra byte materializes, the
        # declaration exceeds what this gate can adjudicate and it refuses.
        target_cap = 1 << 16
        try:
            with open(target_path_real, encoding="utf-8-sig") as fh:
                target_text = fh.read(target_cap + 1)
        except (OSError, UnicodeDecodeError):
            refuse("qa-cycle: refused — item %s: %s exists but could not be read. Refusing rather than allowing a transition this gate cannot verify." % (item_id, target_path))
        if len(target_text) > target_cap:
            refuse(
                "qa-cycle: refused — item %s: %s exceeds the %d-byte cap this gate reads. An oversized "
                "declaration is an unadjudicable input; refusing rather than judging block structure from a "
                "truncated prefix." % (item_id, target_path, target_cap)
            )

        target_blocks = parse_blocks(target_text)
        if len(target_blocks) != 1:
            refuse(
                "qa-cycle: refused — item %s: %s is not a single well-formed `---`-delimited frontmatter block. "
                "Refusing rather than guessing which declaration is meant." % (item_id, target_path)
            )
        target_block = target_blocks[0]

        def target_field(key):
            vals = field_values(target_block, key)
            if len(vals) != 1:
                return None
            v = vals[0].strip()
            return v if v else None

        target_label = target_field("label")
        target_entry_point = target_field("entry_point")
        if not target_label or not target_entry_point:
            refuse(
                "qa-cycle: refused — item %s: %s is malformed — it must declare exactly one non-empty `label:` and "
                "exactly one non-empty `entry_point:` line. Absent, empty, or repeated lines all refuse this "
                "transition." % (item_id, target_path)
            )

        # The attempted write's own evidence must reference the declared
        # target (by label or entry point appearing in the new item block)
        # — a target.md existing elsewhere is not evidence this particular
        # reproduction attempt was run against it.
        new_block = next(b for b in new_blocks if block_item_and_state(b)[0] == item_id)
        if target_label not in new_block and target_entry_point not in new_block:
            refuse(
                "qa-cycle: refused — item %s: the write's run-record evidence does not reference the declared "
                "target (label %r or entry_point %r) from %s. Reference the declared target in this write's "
                "evidence before attempting %s -> reproducing." % (item_id, target_label, target_entry_point, target_path, cur)
            )

    if "severity" in requires:
        new_block = next(b for b in new_blocks if block_item_and_state(b)[0] == item_id)
        severity = block_severity(new_block)
        if severity is None:
            refuse(
                "qa-cycle: refused — item %s: reproducing -> reproduced requires a valid `severity:` (exactly one line, "
                "one of {%s}). Absent, empty, or repeated `severity:` lines all mean no severity, which refuses this "
                "transition." % (item_id, ", ".join(sorted(SEVERITY_SET)))
            )
        if severity not in SEVERITY_SET:
            refuse(
                "qa-cycle: refused — item %s: severity %r is not one of the closed set {%s}."
                % (item_id, severity, ", ".join(sorted(SEVERITY_SET)))
            )
else:
    actor = None
    requires = []
    cur = new = None

if "token" in requires:
    # item_id was already validated by allow-list where it was parsed out
    # of the state.md block (block_item_and_state), before it was ever
    # used in a comparison. Independently of that, the paths built from it
    # here are resolved to real paths and containment-checked against
    # tokens_dir before they are opened — resolve first, then check.
    token_path = posixpath.join(tokens_dir, "%s.token" % item_id)
    consuming_path = posixpath.join(tokens_dir, "%s.consuming" % item_id)

    tokens_dir_real = posixpath.normpath(os.path.realpath(tokens_dir).replace("\\", "/"))
    for _p in (token_path, consuming_path):
        _p_real = posixpath.normpath(os.path.realpath(_p).replace("\\", "/"))
        if not (_p_real == tokens_dir_real or _p_real.startswith(tokens_dir_real + "/")):
            refuse("qa-cycle: refused — a token path for this transition resolves outside the item's tokens directory. Refusing rather than reading or writing a token file outside it.")

    def read_token_file(path):
        try:
            with open(path, encoding="utf-8-sig") as fh:
                ttext = fh.read(8192)
        except (OSError, UnicodeDecodeError):
            return None
        im = re.search(r"^item:\s*(.+?)\s*(?:#.*)?$", ttext, re.M)
        tm = re.search(r"^transition:\s*(.+?)\s*(?:#.*)?$", ttext, re.M)
        if not im or not tm:
            return None
        return im.group(1).strip(), tm.group(1).strip(), ttext

    want_item = item_id
    want_transition = "%s -> %s" % (cur, new)

    # --- finalize any stale consuming marker for this item first ---------
    # A marker left over from a previous allow is finalized (deleted) once
    # its recorded destination state is actually the item's current
    # recorded state — i.e. the write it authorized landed. This is safe to
    # do unconditionally: a marker whose `to` doesn't match the current
    # state simply means that write never landed yet, and is left alone
    # below so it can still authorize a retry of the exact same transition.
    consuming = read_token_file(consuming_path)
    reused_marker = False
    if consuming is not None:
        c_item, c_transition, _ = consuming
        cm = re.match(r"^(.*?)\s*->\s*(.*)$", c_transition)
        c_to = cm.group(2).strip() if cm else None
        if c_item == item_id and c_to == cur:
            # The transition that marker authorized already landed (current
            # state now equals its `to`) — that marker's job is done.
            try:
                os.remove(consuming_path)
            except OSError:
                pass
            consuming = None

    if consuming is not None:
        c_item, c_transition, _ = consuming
        if c_item == want_item and c_transition == want_transition:
            # The write this marker authorized never landed (current state
            # is still `cur`, this marker's `from`). This is a legitimate
            # retry of the exact same human-authorized transition — allow
            # again without requiring a fresh human verdict, and leave the
            # marker in place for the next gate call to finalize or reuse.
            reused_marker = True

    if not reused_marker:
        token = read_token_file(token_path)
        if token is None:
            refuse(
                "qa-cycle: refused — item %s: %s -> %s is a human-only transition and no verdict token is present at %s.\n"
                "A person must decide this and state the verdict in their own turn (signoff mints the token from that "
                "turn); the evidence needed is exactly what docs/specs/qa-cycle-state-machine.md requires for this "
                "transition." % (item_id, cur, new, token_path)
            )
        t_item, t_transition, ttext = token
        if t_item != want_item or t_transition != want_transition:
            refuse(
                "qa-cycle: refused — the token at %s authorizes a different item or transition, so it does not "
                "cover %s for item %s. Treated as absent; a fresh, matching verdict is required." % (token_path, want_transition, item_id)
            )
        # Reserve the token for consumption: move it out of the live token
        # slot into a "consuming" marker rather than deleting it outright.
        # This decouples "decided to allow" from "irrevocably spent" so a
        # write that fails or is aborted after this decision leaves the
        # transition retryable (see docs/decisions/2026-07-31-token-consumption-ordering.md).
        # If the underlying write never lands, the marker itself later
        # re-authorizes the identical retry above; once it lands, the next
        # gate call's finalization step above deletes the marker for good.
        try:
            os.makedirs(tokens_dir, exist_ok=True)
            with open(consuming_path, "w", encoding="utf-8") as fh:
                fh.write(ttext)
            os.remove(token_path)
        except OSError:
            refuse("qa-cycle: refused — the verdict token at %s could not be reserved for consumption. Refusing rather than allowing a write whose token would remain reusable." % token_path)

# --- priority verdict token, independent of the state-transition token
# above --------------------------------------------------------------
#
# priority is human-set (docs/specs/qa-cycle-state-machine.md "Severity and
# priority"). Any write that changes item_id's recorded priority value
# requires a matching, unconsumed priority token bound to
# (item id, field name, new value), stored at
# tokens/<item-id>.priority.token, distinct from tokens/<item-id>.token
# used for state transitions, minted only by
# signoff/hooks/capture-verdict.sh from the user's own turn. Consumed under
# the same reserve-then-finalize ordering as the state-transition token,
# via tokens/<item-id>.priority.consuming, so a permitted priority write
# that fails or is aborted does not strand the item unable to retry — and,
# symmetrically, a `priority-set-by: human` marker present in the write's
# own content plays NO part in this decision: only presence and
# consumption of the matching token do.
if item_id in priority_changed:
    new_priority = priority_new_by_item[item_id]

    priority_token_path = posixpath.join(tokens_dir, "%s.priority.token" % item_id)
    priority_consuming_path = posixpath.join(tokens_dir, "%s.priority.consuming" % item_id)

    tokens_dir_real = posixpath.normpath(os.path.realpath(tokens_dir).replace("\\", "/"))
    for _p in (priority_token_path, priority_consuming_path):
        _p_real = posixpath.normpath(os.path.realpath(_p).replace("\\", "/"))
        if not (_p_real == tokens_dir_real or _p_real.startswith(tokens_dir_real + "/")):
            refuse("qa-cycle: refused — a priority token path for this write resolves outside the item's tokens directory. Refusing rather than reading or writing a token file outside it.")

    def read_priority_token_file(path):
        try:
            with open(path, encoding="utf-8-sig") as fh:
                ttext = fh.read(8192)
        except (OSError, UnicodeDecodeError):
            return None
        im = re.search(r"^item:\s*(.+?)\s*(?:#.*)?$", ttext, re.M)
        fm = re.search(r"^field:\s*(.+?)\s*(?:#.*)?$", ttext, re.M)
        vm = re.search(r"^value:\s*(.+?)\s*(?:#.*)?$", ttext, re.M)
        if not im or not fm or not vm:
            return None
        return im.group(1).strip(), fm.group(1).strip(), vm.group(1).strip(), ttext

    old_priority_now = item_priority_from_text(cur_text, item_id)

    consuming = read_priority_token_file(priority_consuming_path)
    reused_marker = False
    if consuming is not None:
        c_item, c_field, c_value, _ = consuming
        if c_item == item_id and c_field == "priority" and old_priority_now == c_value:
            # The priority write that marker authorized already landed
            # (current recorded priority equals the marker's value) — spent.
            try:
                os.remove(priority_consuming_path)
            except OSError:
                pass
            consuming = None

    if consuming is not None:
        c_item, c_field, c_value, _ = consuming
        if c_item == item_id and c_field == "priority" and c_value == new_priority:
            # The write this marker authorized never landed yet (current
            # recorded priority is still the pre-change value). Legitimate
            # retry of the identical priority verdict — allow again without
            # a fresh human token, leave the marker in place.
            reused_marker = True

    if not reused_marker:
        token = read_priority_token_file(priority_token_path)
        if token is None:
            refuse(
                "qa-cycle: refused — item %s: priority change to %r requires a matching verdict token at %s and none "
                "is present (a `priority-set-by: human` marker in the write's own content does not count — it is "
                "descriptive only). A person must state the priority verdict in their own turn; signoff mints the "
                "token from that turn." % (item_id, new_priority, priority_token_path)
            )
        t_item, t_field, t_value, ttext = token
        if t_item != item_id or t_field != "priority" or t_value != new_priority:
            refuse(
                "qa-cycle: refused — the priority token at %s authorizes a different item, field, or value, so it "
                "does not cover setting item %s's priority to %r. Treated as absent; a fresh, matching verdict is "
                "required." % (priority_token_path, item_id, new_priority)
            )
        try:
            os.makedirs(tokens_dir, exist_ok=True)
            with open(priority_consuming_path, "w", encoding="utf-8") as fh:
                fh.write(ttext)
            os.remove(priority_token_path)
        except OSError:
            refuse("qa-cycle: refused — the priority token at %s could not be reserved for consumption. Refusing rather than allowing a write whose token would remain reusable." % priority_token_path)

if state_change_for_item is not None:
    reason = "qa-cycle: item %s: %s -> %s is a transition the spec permits from its current state." % (item_id, cur, new)
else:
    reason = "qa-cycle: item %s: priority verdict accepted." % item_id

# Pass through, do not grant. A gate refuses or stands aside; emitting
# permissionDecision "allow" would suppress the user's own permission prompt,
# which is a grant of authority rather than a restriction. Measured
# 2026-07-27 in two rulebooks: a Bash call of the shape
# `curl … | sh; echo x >> <record>` was auto-approved on the strength of the
# trailing append — the append was the whole of what the gate inspected.
# This gate's competence is the state machine, not the rest of the command.
sys.stderr.write(reason + "\n")
sys.exit(0)
PY
rc=$?
set -e
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "qa-cycle: refused — fail-closed: internal error (transition-gate.sh judge exited $rc)." >&2
  exit 2
fi
exit "$rc"
