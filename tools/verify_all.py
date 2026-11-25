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
    ready = True
    if not (ROOT / ".godot/global_script_class_cache.cfg").is_file():
        ready, out, err = run(command + ["--import"], args.timeout)
        if not ready:
            print(out + err, file=sys.stderr)

    ok, out, err = False, "", ""
    if ready:
        ok, out, err = run(command + ["--script", "res://tests/run_all.gd"], args.timeout)
    lines = out.rstrip().splitlines()
    summary = re.fullmatch(r"RCD TESTS: ALL PASS — (\d+) assertions(?: in [\d.]+ s)?",
                           lines[-1] if lines else "")
    assertions = int(summary[1]) if summary else 0
    noise = err.count("mesh_get_surface_count")
    godot_ok = ok and summary is not None and assertions >= args.baseline and noise == 0
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
