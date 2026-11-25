"""Run the Python and Godot regression suites from any working directory."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[1]
PYTHON = Path.home() / ".dsh/dsh-runtimes/dsh-primary-runtime/dependencies/python/python.exe"
GODOT = Path.home() / "Desktop/工具/程序/Godot_v4.3-stable/godot.exe"


def run(command, timeout):
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=timeout)
        code, stdout, stderr = result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired as exc:
        print(f"{command[0]} timed out after {timeout}s", file=sys.stderr)
        code, stdout, stderr = 1, exc.stdout or b"", exc.stderr or b""
    except OSError as exc:
        print(exc, file=sys.stderr)
        return False, "", ""
    return code == 0, stdout.decode("utf-8", "replace"), stderr.decode("utf-8", "replace")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--baseline", type=int, default=815)
    parser.add_argument("--noise-budget", type=int, default=1,
                        help="allowed dummy-renderer mesh lines; see NOISE note below")
    parser.add_argument("--timeout", type=int, default=130, help="seconds per subprocess")
    args = parser.parse_args()
    if args.timeout <= 0 or args.baseline < 0:
        parser.error("timeout must be positive and baseline nonnegative")

    start = time.monotonic()
    python = PYTHON if PYTHON.is_file() else sys.executable
    ok, out, err = run([python, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"], args.timeout)
    count = re.search(r"^Ran (\d+) tests? in ", err, re.MULTILINE)
    python_tests = int(count[1]) if count else 0
    python_ok = ok and python_tests > 0
    if not python_ok:
        print(out + err, file=sys.stderr)

    engine = os.environ.get("GODOT_BIN") or (GODOT if GODOT.is_file() else "godot")
    command = [engine, "--headless", "--path", str(ROOT)]
    # The godot-bridge autoload talks to a fixed local port and keeps Mesh resources
    # alive for its own screenshot path; both distort a measured headless run (and a
    # second copy of the suite then collides with a game already on 9090). Export
    # strips it, so the suite is measured against the shape the release ships in.
    stripped = run([python, str(ROOT / "tools/strip_dev_autoload.py"), "--strip"], args.timeout)[0]
    try:
        ready = True
        if not (ROOT / ".godot/global_script_class_cache.cfg").is_file():
            ready, out, err = run(command + ["--import"], args.timeout)
            if not ready:
                print(out + err, file=sys.stderr)

        ok, out, err = False, "", ""
        if ready:
            ok, out, err = run(command + ["--script", "res://tests/run_all.gd"], args.timeout)
    finally:
        if stripped:
            run([python, str(ROOT / "tools/strip_dev_autoload.py"), "--restore"], args.timeout)
            # strip/restore rewrites project.godot; git drops the CRLF churn only when
            # asked, and a dirty tree would block the next commit.
            subprocess.run(["git", "checkout", "--", "project.godot"], cwd=ROOT,
                           capture_output=True, text=True)

    # Anything the engine prints after the summary (autoload shutdown, leak warnings)
    # must not hide the verdict, so the summary is searched for, not required last.
    # The separator between PASS and the count is an em dash that goes through several
    # encodings on the way here, so match any run of non-digits instead of the glyph.
    summary = re.search(r"RCD TESTS: ALL PASS[^\d]*(\d+) assertions", out)
    assertions = int(summary[1]) if summary else 0
    # A failing suite prints "FAILED — <modules>" and then "N passed, M failed", so
    # the count lives on a different line than it does for a pass.
    failed = re.search(r"RCD TESTS: FAILED[^\n]*\nRCD TESTS: (\d+) passed, (\d+) failed", out)
    if summary is None and failed:
        assertions = int(failed[1]) + int(failed[2])
    noise = err.count("mesh_get_surface_count")
    # NOISE BUDGET: run_all.gd keeps every Mesh that leaves the tree, which turns the
    # hundreds of lines a module teardown used to spray into a single one per whole
    # scene freed at once (test_scene frees main.tscn from its root). A probe that
    # retained all 61 MeshInstance3D meshes first still produced that one line, so the
    # remainder is the dummy renderer's own teardown order, not a missing reference.
    # The budget fails the gate the moment a second scene or a new module starts
    # spraying again, which is the regression this number exists to catch.
    # A GDScript runtime error can abort just one module and still leave an
    # ALL PASS summary from the remaining modules.
    godot_ok = (ok and "SCRIPT ERROR:" not in err and summary is not None and assertions >= args.baseline
                and noise <= args.noise_budget)
    if not godot_ok:
        print(out, file=sys.stderr)
    if err:
        print(err, end="", file=sys.stderr)

    report = dict(python_ok=python_ok, python_tests=python_tests, godot_ok=godot_ok,
                  assertions=assertions, stderr_noise=noise, seconds=round(time.monotonic() - start, 2))
    if args.json:
        print(json.dumps(report))
    else:
        for key, value in report.items():
            print(f"{key}: {json.dumps(value)}")
    return 0 if python_ok and godot_ok else 1


if __name__ == "__main__":
    sys.exit(main())
