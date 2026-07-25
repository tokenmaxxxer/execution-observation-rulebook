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

if [ -z "${QA_WORKSPACE:-}" ]; then
  echo "qa-cycle: refused — QA_WORKSPACE is unset. The gate has no state file to read, so it cannot verify this write is a legal transition. Set QA_WORKSPACE to the QA workspace root." >&2
  exit 2
fi

payload="$(cat)"

QA_CYCLE_PAYLOAD="$payload" QA_CYCLE_WORKSPACE="$QA_WORKSPACE" python3 <<'PY'
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
TABLE = [
    ("(none)", "observed", "agent"),  # bootstrap: first record of a new item
    ("observed", "reproducing", "agent"),
    ("reproducing", "reproduced", "agent"),
    ("reproducing", "observed", "agent"),
    ("reproducing", "parked-unreproducible", "agent"),
    ("parked-unreproducible", "observed", "agent"),
    ("reproduced", "handed-off", "human"),
    ("reproduced", "not-a-defect", "human"),
    ("reproduced", "wont-fix", "human"),
    ("handed-off", "re-verifying", "human"),
    ("re-verifying", "verified-fixed", "agent"),
    ("re-verifying", "reproducing", "agent"),
]

# Every row the spec's table marks Actor: human requires a matching
# unconsumed verdict token, keyed by the exact (item id, from, to) triple —
# not by the destination state alone. `handed-off` has exactly one legal
# outbound row and it is a human row, so "handed-off refuses every
# transition without a human trigger" falls directly out of table lookup;
# the explicit assertion below is a defensive backstop, not new logic.
ACTOR_OF = {(f, t): a for f, t, a in TABLE}
ALLOWED = set(ACTOR_OF)

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
project_dir = posixpath.join(ws_real, "projects", slug)
state_path = posixpath.join(project_dir, "state.md")
tokens_dir = posixpath.join(project_dir, "tokens")

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

# Determine which single item this write changes. Every item block present
# in the new content must either match the item's current recorded state
# (unchanged, fine) or be exactly the one item whose state differs (the
# attempted transition). More than one differing item, or a block that
# fails to parse its own item/state pair, is refused as ambiguous.
changed = []
for block in new_blocks:
    item_id, new_state = block_item_and_state(block)
    if item_id is None or new_state is None:
        refuse("qa-cycle: refused — the write contains a block with no readable, unambiguous `item:` and `state:` pair. Refusing rather than guessing which item or state is meant.")
    old_state = item_state_from_text(cur_text, item_id)
    if old_state is None:
        refuse("qa-cycle: refused — %s already holds an ambiguous record for item %s (more than one block, or an unreadable state). The current state cannot be established, so no write is permitted." % (state_path, item_id))
    if old_state != new_state:
        changed.append((item_id, old_state, new_state))

if len(changed) == 0:
    refuse("qa-cycle: refused — this write does not change any item's recorded state. There is no transition here for the gate to authorize.")
if len(changed) > 1:
    refuse("qa-cycle: refused — this write changes more than one item's state in a single operation (%s). Each transition must be its own write so the gate can authorize it individually." % ", ".join(i for i, _, _ in changed))

item_id, cur, new = changed[0]


def legal_from(state):
    return sorted({t for f, t, _ in TABLE if f == state})


if (cur, new) not in ALLOWED:
    legal = legal_from(cur)
    refuse(
        "qa-cycle: refused — item %s: %s -> %s is not a transition docs/specs/qa-cycle-state-machine.md permits.\n"
        "Current state: %s. Transitions legal from here: %s."
        % (item_id, cur, new, cur, ", ".join(legal) if legal else "(none)")
    )

actor = ACTOR_OF[(cur, new)]

# Defensive backstop for the spec's "handed-off refuses every transition
# without a human trigger, without exception": the only legal outbound row
# from handed-off is already a human row, so this can never trip in
# practice against the table above — it exists so a future table edit that
# quietly added an agent-actor row out of handed-off would still be caught.
if cur == "handed-off" and actor != "human":
    refuse("qa-cycle: refused — item %s is handed-off; no transition out of handed-off is permitted without a human trigger, without exception." % item_id)

if actor == "human":
    token_path = posixpath.join(tokens_dir, "%s.token" % item_id)
    consuming_path = posixpath.join(tokens_dir, "%s.consuming" % item_id)

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

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "qa-cycle: item %s: %s -> %s is a transition the spec permits from its current state." % (item_id, cur, new),
}}))
sys.exit(0)
PY

exit $?
