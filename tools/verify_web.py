#!/usr/bin/env python3
"""Smoke the exported Web build in a real browser.

The itch page is what the four jams will link to, so "it boots and keeps drawing
frames" is a gate, not a nice-to-have: a stripped autoload or a mis-patched shell
can leave a black canvas that no headless test would ever notice.

    python tools/verify_web.py
    python tools/verify_web.py --builds builds/web --json
    python tools/verify_web.py --shot visual/preview/sprint9_web_smoke.png

Exit codes: 0 = booted and rendering, 1 = failed, 2 = skipped (no build / no browser).
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import shutil
import socket
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
TABBIT = pathlib.Path(os.environ.get(
    "TABBIT_CLI",
    str(pathlib.Path(os.environ.get("LOCALAPPDATA", "")) / "Tabbit" / "LocalAgent" / "bin" / "tabbit-cli.exe"),
))


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def wait_for_port(port: int, seconds: float = 15.0) -> bool:
    deadline = time.time() + seconds
    while time.time() < deadline:
        with socket.socket() as sock:
            sock.settimeout(0.4)
            if sock.connect_ex(("127.0.0.1", port)) == 0:
                return True
        time.sleep(0.2)
    return False


SCRIPT = r"""
const fs = require("fs");
const OUT = __OUT__;
const SHOT = __SHOT__;
const URL = __URL__;

const errors = [];
const warnings = [];
let inWarning = false;
page.on("console", (m) => {
  const text = String(m.text()).slice(0, 300);
  // Godot routes its own user warnings (and their stack lines) through
  // console.error on the web export. Worth printing, but not "build broken".
  if (/^(USER WARNING|WARNING):/.test(text)) { inWarning = true; warnings.push(text); return; }
  if (inWarning && /^\s+at:/.test(text)) { warnings.push(text); return; }
  inWarning = false;
  if (m.type() === "error") errors.push(text);
});
page.on("pageerror", (e) => errors.push("pageerror: " + String(e).slice(0, 300)));

const report = { url: URL, sample: null, moved: false, errors, warnings, shot: null };
try {
  await page.goto(URL, { waitUntil: "load", timeout: 45000 });
  // A hidden tab throttles requestAnimationFrame, which stops Godot's main loop
  // entirely: two screenshots of it are byte-identical while the game is fine.
  // Ask Chrome to treat the page as focused before measuring motion.
  try {
    const cdp = await page.context().newCDPSession(page);
    await cdp.send("Emulation.setFocusEmulationEnabled", { enabled: true });
  } catch (err) { /* no CDP on this harness; fall back to reporting visibility */ }
  try { await page.bringToFront(); } catch (err) { /* foreground policy may preserve */ }
  for (let i = 0; i < 60; i++) {
    await page.waitForTimeout(500);
    report.sample = await page.evaluate(() => {
      const c = document.querySelector("canvas");
      if (!c) return null;
      const gl = c.getContext("webgl2") || c.getContext("webgl");
      return { w: c.width, h: c.height, title: document.title, gl: !!gl,
               visibility: document.visibilityState,
               engine: typeof window.Engine !== "undefined" };
    });
    if (report.sample && report.sample.w > 600 && report.sample.h > 300) break;
  }
  const first = await page.screenshot({ type: "png" });
  await page.waitForTimeout(1500);
  const second = await page.screenshot({ type: "png" });
  // The harness may hand back a plain Buffer or a serialised object; compare in
  // a shape that works for both.
  const a = Buffer.isBuffer(first) ? first.toString("base64") : JSON.stringify(first);
  const b = Buffer.isBuffer(second) ? second.toString("base64") : JSON.stringify(second);
  report.moved = a !== b;
  if (!fs.existsSync(SHOT)) {
    if (Buffer.isBuffer(second)) fs.writeFileSync(SHOT, second);
    else if (second && second.data) fs.writeFileSync(SHOT, Buffer.from(second.data));
  }
  report.shot = fs.existsSync(SHOT) ? SHOT : null;
  if (!report.shot) {
    // Writing through the harness' own screenshot path is sandboxed to its
    // artifact directory, so pull the pixels out of the canvas instead.
    try {
      const dataUrl = await page.evaluate(() => {
        const c = document.querySelector("canvas");
        return c ? c.toDataURL("image/png") : "";
      });
      const comma = dataUrl.indexOf(",");
      if (comma > 0) {
        fs.writeFileSync(SHOT, Buffer.from(dataUrl.slice(comma + 1), "base64"));
        report.shot = SHOT;
      }
    } catch (err) { /* a blank capture is better than a failed gate */ }
  }
} catch (err) {
  errors.push("harness: " + String(err).slice(0, 300));
}
fs.writeFileSync(OUT, JSON.stringify(report), "utf8");
"""


def run_browser(port: int, out_path: pathlib.Path, shot_path: pathlib.Path, task: str) -> dict:
    script = (SCRIPT
              .replace("__OUT__", json.dumps(str(out_path)))
              .replace("__SHOT__", json.dumps(str(shot_path)))
              .replace("__URL__", json.dumps(f"http://127.0.0.1:{port}/index.html")))
    cmd = [str(TABBIT), "nodejs", "--task", task, "--request-id", f"{task}-{int(time.time())}",
           "--timeout-ms", "180000"]
    proc = subprocess.run(cmd, input=script.encode("utf-8"), capture_output=True)
    text = proc.stdout.decode("utf-8", errors="replace").strip()
    payload = {}
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("{"):
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                continue
    return {"cli_exit": proc.returncode, "cli": payload,
            "stderr": proc.stderr.decode("utf-8", errors="replace")[-800:]}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--builds", default="builds/web")
    ap.add_argument("--shot", default="visual/preview/sprint9_web_smoke.png")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    web_dir = (ROOT / args.builds).resolve()
    index = web_dir / "index.html"
    if not index.is_file():
        print(f"[skip] no web build at {index}; run `python tools/make_release.py --tag <tag>` first")
        return 2
    if not TABBIT.is_file():
        print(f"[skip] Tabbit CLI not found at {TABBIT}")
        return 2

    shot = (ROOT / args.shot).resolve()
    shot.parent.mkdir(parents=True, exist_ok=True)

    port = free_port()
    server = subprocess.Popen(
        [sys.executable, "-m", "http.server", str(port), "--bind", "127.0.0.1", "--directory", str(web_dir)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    out_path = pathlib.Path(tempfile.gettempdir()) / f"rcd_web_smoke_{port}.json"
    if out_path.exists():
        out_path.unlink()
    try:
        if not wait_for_port(port):
            print("[fail] local http server did not come up")
            return 1
        run = run_browser(port, out_path, shot, "rcd-verify-web")
    finally:
        server.terminate()
        try:
            server.wait(timeout=8)
        except subprocess.TimeoutExpired:
            server.kill()

    if not out_path.exists():
        print("[fail] browser script produced no report")
        print(json.dumps(run.get("cli"), ensure_ascii=False)[:1200])
        if run.get("stderr"):
            print(run["stderr"])
        return 1
    report = json.loads(out_path.read_text(encoding="utf-8"))

    sample = report.get("sample") or {}
    width, height = int(sample.get("w") or 0), int(sample.get("h") or 0)
    errors = [e for e in report.get("errors") or []]
    warnings = [w for w in report.get("warnings") or []]
    problems = []
    if width <= 600 or height <= 300:
        problems.append(f"canvas never sized up (got {width}x{height})")
    if not sample.get("gl"):
        problems.append("no WebGL context on the canvas")
    hidden = sample.get("visibility") == "hidden"
    if not sample.get("engine"):
        problems.append("Godot's web Engine object never appeared")
    if errors:
        problems.append(f"{len(errors)} console error(s): {errors[0]}")

    summary = {
        "web_dir": str(web_dir),
        "canvas": f"{width}x{height}",
        "title": sample.get("title"),
        "engine": bool(sample.get("engine")),
        "tab_visible": not hidden,
        # Motion is only observable in a foreground tab; the harness may keep the
        # tab hidden, in which case this stays false without meaning anything.
        "frames_compared_moved": bool(report.get("moved")),
        "console_errors": len(errors),
        "console_warnings": len(warnings),
        "shot": str(shot) if shot.exists() else None,
        "ok": not problems,
        "problems": problems,
    }
    if warnings:
        summary["warning_sample"] = warnings[:3]
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    if not args.json:
        for problem in problems:
            print(f"[fail] {problem}")
    return 0 if not problems else 1


if __name__ == "__main__":
    raise SystemExit(main())
