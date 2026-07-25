#!/usr/bin/env bash
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
# stdin, a malformed payload, a missing/malformed state file, an unset
# QA_WORKSPACE, a missing or mismatched verdict token, an ambiguous write
# touching more than one item's state — exits 2. Allow (exit 0) is reached
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

# --dump-facts is a read-only introspection path: it prints the same
# TABLE/FIELDS structures the decision logic below branches on, as JSON,
# and exits 0. It touches no state file, no token, no QA_WORKSPACE, and
# reads no stdin — it is not reachable from, and shares no code path with,
# any write decision. See qa-cycle/hooks/tests/directive-drift-check.sh,
# which is the only consumer.
dump_facts=0
if [ "${1:-}" = "--dump-facts" ]; then
  dump_facts=1
fi

if [ "$dump_facts" != 1 ]; then
  if [ -z "${QA_WORKSPACE:-}" ]; then
    echo "qa-cycle: refused — QA_WORKSPACE is unset. The gate has no state file to read, so it cannot verify this write is a legal transition. Set QA_WORKSPACE to the QA workspace root." >&2
    exit 2
  fi
fi

if [ "$dump_facts" = 1 ]; then
  payload=""
else
  payload="$(cat)"
fi

QA_CYCLE_PAYLOAD="$payload" QA_CYCLE_WORKSPACE="${QA_WORKSPACE:-}" QA_CYCLE_DUMP_FACTS="$dump_facts" python3 <<'PY'
import json
import os
import posixpath
import re
import sys

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
    {"from": "observed", "to": "reproducing", "actor": "agent", "requires": []},
    {"from": "reproducing", "to": "reproduced", "actor": "agent", "requires": ["severity"]},
    {"from": "reproducing", "to": "observed", "actor": "agent", "requires": []},
    {"from": "reproducing", "to": "parked-unreproducible", "actor": "agent", "requires": []},
    {"from": "parked-unreproducible", "to": "observed", "actor": "agent", "requires": []},
    {"from": "reproduced", "to": "handed-off", "actor": "human", "requires": ["token"]},
    {"from": "reproduced", "to": "not-a-defect", "actor": "human", "requires": ["token"]},
    {"from": "reproduced", "to": "wont-fix", "actor": "human", "requires": ["token"]},
    {"from": "handed-off", "to": "re-verifying", "actor": "human", "requires": ["token"]},
    {"from": "re-verifying", "to": "verified-fixed", "actor": "agent", "requires": []},
    {"from": "re-verifying", "to": "reproducing", "actor": "agent", "requires": []},
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
    # Read-only: nothing above this point touches state.md, a token file,
    # or QA_WORKSPACE, and nothing below this line runs.
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
if tool not in ("Write", "Edit"):
    # Not a write-shaped tool call at all; this gate has nothing to say
    # about it. Distinct from the malformed-shape refusals above and below.
    not_applicable()
if not isinstance(tool_input, dict):
    refuse("qa-cycle: refused — a %s call arrived with no readable tool_input. Refusing rather than allowing an uninspectable write." % tool)

path = tool_input.get("file_path")
if not isinstance(path, str) or not path:
    refuse("qa-cycle: refused — a %s call arrived with no readable file_path. Refusing rather than allowing an uninspectable write." % tool)

ws = os.environ.get("QA_CYCLE_WORKSPACE", "")
ws_real = posixpath.normpath(os.path.realpath(ws).replace("\\", "/"))
path_norm = path.replace("\\", "/")
path_abs = posixpath.normpath(path_norm if posixpath.isabs(path_norm) else posixpath.join(os.getcwd(), path_norm))
path_real = posixpath.normpath(os.path.realpath(path_abs).replace("\\", "/"))

# Only state.md writes are this gate's business, and only ones inside the
# workspace root — never trust a path by name alone.
if not (path_real == ws_real or path_real.startswith(ws_real + "/")):
    not_applicable()

rel = path_real[len(ws_real) + 1:]
parts = rel.split("/")
if len(parts) != 3 or parts[0] != "projects" or parts[2] != "state.md":
    not_applicable()
slug = parts[1]

# An item id is validated by allow-list, at the point it is read, before it
# is used in any path or any comparison: ASCII letters, digits, hyphen, and
# underscore only, length 1..64, never starting with a hyphen. Anything
# outside this shape is not an item id — rejected by pattern, never
# sanitized. This is what stops a value like
# "../../../../../../../../tmp/evil-item" from ever becoming an item_id in
# the first place, closing the path-traversal bypass of the human-only gate
# recorded in docs/reports/2026-07-31-hunt-item-axis-enforcement.md.
ITEM_ID_RE = re.compile(r"^(?!-)[A-Za-z0-9_-]{1,64}$")

# Same allow-list discipline for the project identifier (<owner>-<repo>),
# which comes from the same untrusted surface (the write's file_path) and
# has the same escape if trusted blindly.
PROJECT_ID_RE = re.compile(r"^(?!-)[A-Za-z0-9_-]{1,128}$")

# The project identifier comes from the same untrusted surface (the
# write's file_path) as the item id and gets the same two checks: an
# allow-list at the point it is read, before it is used in any path, and —
# independently — the path built from it is resolved to a real path and
# containment-checked against the workspace root before use.
if not PROJECT_ID_RE.match(slug):
    refuse("qa-cycle: refused — the project path in this write is not a recognized project identifier. Refusing rather than trusting an unvalidated value in a path.")

project_dir = posixpath.join(ws_real, "projects", slug)
state_path = posixpath.join(project_dir, "state.md")
tokens_dir = posixpath.join(project_dir, "tokens")

# Resolve first, then check containment — a check performed before
# resolution proves nothing. Belt-and-braces on top of the allow-list
# above: even though slug was built from an already-resolved, already
# contained path_real, re-resolve and re-check the path actually used from
# here on.
project_dir_real = posixpath.normpath(os.path.realpath(project_dir).replace("\\", "/"))
if not (project_dir_real == ws_real or project_dir_real.startswith(ws_real + "/")):
    refuse("qa-cycle: refused — the resolved project directory for this write escapes the workspace root. Refusing rather than reading or writing outside it.")

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
    try:
        with open(state_path, encoding="utf-8-sig") as fh:
            return fh.read(1 << 20)
    except (OSError, UnicodeDecodeError):
        refuse("qa-cycle: refused — %s exists but could not be read. Fix or remove it before attempting a transition." % state_path)


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

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": reason,
}}))
sys.exit(0)
PY

exit $?
