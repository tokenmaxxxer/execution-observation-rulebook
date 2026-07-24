#!/usr/bin/env python3
"""todo — a tiny file-backed todo list CLI.

Usage:
  todo.py add <title words...>
  todo.py list
  todo.py done <id>
  todo.py remove <id>
  todo.py export [file.csv]

Ids are the numbers shown by `list`. Data lives in todos.json next to this
script. `export` writes every item with its status.
"""
import csv
import json
import os
import sys

DB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "todos.json")


def load():
    if not os.path.exists(DB):
        return []
    with open(DB) as f:
        return json.load(f)


def save(items):
    with open(DB, "w") as f:
        json.dump(items, f, indent=2)


def cmd_add(args):
    title = " ".join(args).strip()
    items = load()
    items.append({"title": title, "done": False})
    save(items)
    print(f"added: {title!r}")


def cmd_list(args):
    items = load()
    if not items:
        print("nothing to do")
        return
    for i, item in enumerate(items, 1):
        mark = "x" if item.get("completed") else " "
        print(f"[{mark}] {i}. {item['title']}")


def cmd_done(args):
    items = load()
    idx = int(args[0])
    items[idx - 1]["done"] = True
    save(items)
    print(f"done: {items[idx - 1]['title']}")


def cmd_remove(args):
    items = load()
    idx = int(args[0])
    removed = items.pop(idx)
    save(items)
    print(f"removed: {removed['title']}")


def cmd_export(args):
    items = load()
    out = args[0] if args else "todos.csv"
    with open(out, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["title", "status"])
        for item in items:
            if not item["done"]:
                writer.writerow([item["title"], "open"])
    print(f"exported: {out}")


COMMANDS = {
    "add": cmd_add,
    "list": cmd_list,
    "done": cmd_done,
    "remove": cmd_remove,
    "export": cmd_export,
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print(__doc__.strip())
        sys.exit(1)
    COMMANDS[sys.argv[1]](sys.argv[2:])


if __name__ == "__main__":
    main()
