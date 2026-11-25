"""Run verify_all in the specified worktree (default: this script's worktree)."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("worktree", type=Path, nargs="?", default=Path(__file__).resolve().parents[1])
    parser.add_argument("--baseline", type=int, help="minimum Godot assertion count for verify_all")
    args = parser.parse_args()
    root = args.worktree.resolve()
    report = {"worktree": str(root), "ok": False}
    try:
        # verify_all restores project.godot from the index after stripping autoloads.
        dirty = subprocess.run(["git", "diff", "--exit-code", "--", "project.godot"],
                               cwd=root, capture_output=True)
        if dirty.returncode:
            raise ValueError("cannot verify with unstaged project.godot changes or unreadable index")
        command = [sys.executable, "tools/verify_all.py", "--json"]
        if args.baseline is not None:
            command.extend(["--baseline", str(args.baseline)])
        child = subprocess.run(command,
                               cwd=root, capture_output=True,
                               env={**os.environ, "PYTHONIOENCODING": "utf-8"})
        sys.stderr.write(child.stderr.decode("utf-8", "replace"))
        result = json.loads(child.stdout.decode("utf-8", "replace"))
        report.update(result)
        report["ok"] = child.returncode == 0 and result["godot_ok"] and result["python_ok"]
    except (OSError, ValueError, KeyError, TypeError) as exc:
        report.update(ok=False, error=str(exc))
    print(json.dumps(report))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
