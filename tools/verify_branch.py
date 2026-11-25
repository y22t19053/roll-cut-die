"""Run the target worktree's gate and optionally pin its exact assertion count."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("worktree", type=Path)
    parser.add_argument("--baseline", type=int, help="exact expected Godot assertion count")
    args = parser.parse_args()
    root = args.worktree.resolve()
    report = {"worktree": str(root), "ok": False}
    try:
        # verify_all restores project.godot from the index after stripping autoloads.
        dirty = subprocess.run(["git", "diff", "--exit-code", "--", "project.godot"],
                               cwd=root, capture_output=True)
        if dirty.returncode:
            raise ValueError("cannot verify with unstaged project.godot changes or unreadable index")
        child = subprocess.run([sys.executable, "tools/verify_all.py", "--json"],
                               cwd=root, capture_output=True,
                               env={**os.environ, "PYTHONIOENCODING": "utf-8"})
        sys.stderr.write(child.stderr.decode("utf-8", "replace"))
        result = json.loads(child.stdout.decode("utf-8", "replace"))
        count = result["assertions"]
        report.update(result)
        report["ok"] = child.returncode == 0 and result["godot_ok"] and result["python_ok"]
        if args.baseline is not None and count != args.baseline:
            report.update(ok=False, error=f"expected {args.baseline} assertions, got {count}")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        report.update(ok=False, error=str(exc))
    print(json.dumps(report))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
