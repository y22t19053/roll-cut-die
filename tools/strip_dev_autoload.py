#!/usr/bin/env python
"""Take the dev command server out of project.godot before an export, put it back after.

godot-bridge re-registers `McpInteractionServer` in [autoload] every time it launches
the project for interactive testing, while export_presets.cfg excludes `autoload/*`
from the shipped pack. The result is a release build that logs
`Attempt to open script 'res://autoload/mcp_interaction_server.gd' ... File not found`
at every boot. This script removes the declaration for the duration of an export.

    python tools/strip_dev_autoload.py --strip      # before exporting
    python tools/strip_dev_autoload.py --restore    # after exporting (keeps --strip idempotent)
    python tools/strip_dev_autoload.py --check      # prints "present" / "absent"

It is deliberately line-based: project.godot is a config file that Godot rewrites on
its own terms, and touching anything else in it would produce noisy diffs.
"""
import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJECT = ROOT / "project.godot"
LINE = re.compile(r'^McpInteractionServer\s*=')
BACKUP = ROOT / "tools" / ".dev_autoload.bak"


def read_lines() -> list[str]:
    return PROJECT.read_text(encoding="utf-8").splitlines(keepends=True)


def strip() -> int:
    lines = read_lines()
    kept = [ln for ln in lines if not LINE.match(ln)]
    if len(kept) == len(lines):
        print("absent (nothing to strip)")
        return 0
    BACKUP.write_text("".join(ln for ln in lines if LINE.match(ln)), encoding="utf-8")
    PROJECT.write_text("".join(kept), encoding="utf-8")
    print("stripped 1 line")
    return 0


def restore() -> int:
    if not BACKUP.exists():
        print("no backup; nothing to restore")
        return 0
    saved = BACKUP.read_text(encoding="utf-8")
    if not saved.strip():
        print("backup empty")
        return 0
    lines = read_lines()
    if any(LINE.match(ln) for ln in lines):
        print("already present")
        return 0
    # Put it back at the end of [autoload], where Godot wrote it originally
    # (after GameSession, before the next section header).
    for i, ln in enumerate(lines):
        if ln.strip() == "[autoload]":
            at = i + 1
            for j in range(i + 1, len(lines)):
                if lines[j].startswith("["):
                    at = j
                    break
            else:
                at = len(lines)
            lines.insert(at, saved.strip() + "\n")
            break
    else:
        lines.append("\n[autoload]\n" + saved.strip() + "\n")
    PROJECT.write_text("".join(lines), encoding="utf-8")
    print("restored 1 line")
    return 0


def check() -> int:
    present = any(LINE.match(ln) for ln in read_lines())
    print("present" if present else "absent")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--strip", action="store_true")
    group.add_argument("--restore", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.strip:
        return strip()
    if args.restore:
        return restore()
    return check()


if __name__ == "__main__":
    sys.exit(main())