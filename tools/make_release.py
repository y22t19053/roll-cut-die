#!/usr/bin/env python
"""Build every shippable artifact in one pass, with versioned names.

One command, in the order that has actually burned us before:

    python tools/make_release.py --tag s5

    1. read the short hash of HEAD (it goes in every filename)
    2. strip the godot-bridge autoload out of project.godot   (tools/strip_dev_autoload.py)
    3. export the Windows build  -> builds/RCD-<tag>-<hash>.exe
    4. export the Web build      -> builds/web/index.html
    5. put the autoload line back and let git normalise project.godot's EOLs
    6. patch Godot's HTML shell  (tools/patch_web_shell.py)
    7. mirror the Web build into builds/toy-roll-cut-die/ (no *.import, no editor junk)
    8. zip the Windows exe and the Web build under the same versioned stem
    9. print sizes and SHA256 so the release register can be filled in

Red line from docs/RCD_RELEASE_AND_PUBLIC_ASSETS_REGISTER.md: never overwrite a
build that already exists. Everything here is written under a fresh
`RCD-<tag>-<hash>` stem, and an existing file is treated as an error, not as a
target to clobber.

Exit code 0 means every requested artifact exists; anything else means the tree
was left exactly as it was found (the autoload is restored in a finally block).
"""
import argparse
import hashlib
import os
import pathlib
import shutil
import subprocess
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILDS = ROOT / "builds"
WEB = BUILDS / "web"
TOY = BUILDS / "toy-roll-cut-die"

FALLBACK_GODOT = pathlib.Path(r"C:\Users\11ee11\Desktop\工具\程序\Godot_v4.3-stable\godot.exe")


def godot_bin() -> str:
    env = os.environ.get("GODOT_BIN")
    if env and pathlib.Path(env).is_file():
        return env
    if FALLBACK_GODOT.is_file():
        return str(FALLBACK_GODOT)
    return "godot"


def short_hash() -> str:
    out = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True
    )
    return out.stdout.strip()


def run(cmd: list[str], what: str) -> None:
    print(f"[release] {what}")
    proc = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    tail = (proc.stdout + proc.stderr).strip().splitlines()[-6:]
    for line in tail:
        print("    " + line)
    if proc.returncode != 0:
        raise SystemExit(f"[release] {what} FAILED (exit {proc.returncode})")


def export(preset: str, output: pathlib.Path, what: str) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    run(
        [godot_bin(), "--headless", "--path", str(ROOT), "--export-release", preset, str(output)],
        what,
    )
    if not output.is_file():
        raise SystemExit(f"[release] {what}: no file at {output}")


def web_files() -> list[pathlib.Path]:
    """Everything in builds/web that a browser actually needs."""
    return [
        p
        for p in sorted(WEB.rglob("*"))
        if p.is_file() and p.suffix != ".import" and not p.name.startswith(".")
    ]


def mirror_toy() -> None:
    if TOY.exists():
        shutil.rmtree(TOY)
    TOY.mkdir(parents=True)
    for src in web_files():
        dst = TOY / src.relative_to(WEB)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    print(f"[release] mirrored {len(web_files())} files into {TOY.relative_to(ROOT)}")


def zip_dir(zip_path: pathlib.Path, files: list[pathlib.Path], base: pathlib.Path | None) -> None:
    if zip_path.exists():
        raise SystemExit(f"[release] refusing to overwrite existing build {zip_path.name}")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for src in files:
            arc = src.name if base is None else str(src.relative_to(base))
            zf.write(src, arc)


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tag", default="dev", help="version tag used in every filename (default: dev)")
    parser.add_argument("--skip-exe", action="store_true", help="Windows export only skipped")
    parser.add_argument("--skip-web", action="store_true", help="Web export and TOY mirror skipped")
    args = parser.parse_args()

    head = short_hash()
    stem = f"RCD-{args.tag}-{head}"
    exe = BUILDS / f"{stem}.exe"
    exe_zip = BUILDS / f"{stem}-windows.zip"
    web_zip = BUILDS / f"{stem}-web.zip"
    made: list[pathlib.Path] = []

    for path in (exe, exe_zip, web_zip):
        if path.exists():
            raise SystemExit(f"[release] {path.name} already exists — bump --tag, nothing was overwritten")

    python = sys.executable
    BUILDS.mkdir(exist_ok=True)
    stripped = False
    try:
        run([python, str(ROOT / "tools" / "strip_dev_autoload.py"), "--strip"], "strip dev autoload")
        stripped = True

        if not args.skip_exe:
            export("Windows Desktop", exe, f"export Windows -> {exe.name}")
            zip_dir(exe_zip, [exe], None)
            made += [exe, exe_zip]

        if not args.skip_web:
            export("Web", WEB / "index.html", "export Web -> builds/web/index.html")
            run([python, str(ROOT / "tools" / "patch_web_shell.py"), str(WEB / "index.html")], "patch web shell")
            mirror_toy()
            zip_dir(web_zip, web_files(), WEB)
            made.append(web_zip)
    finally:
        if stripped:
            run([python, str(ROOT / "tools" / "strip_dev_autoload.py"), "--restore"], "restore dev autoload")
            subprocess.run(["git", "checkout", "--", "project.godot"], cwd=ROOT, capture_output=True, text=True)

    print("\n[release] artifacts")
    for path in made:
        print(f"  {path.name:<34} {path.stat().st_size:>12,} B  {sha256(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
