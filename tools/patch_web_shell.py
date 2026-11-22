"""One fix to Godot's exported HTML shell: touches on the canvas must not be
interpreted as page gestures.

Godot's stock shell puts `touch-action: none` on `body`, which does not help —
touch-action is resolved on the element the finger actually lands on, and on this
game that element is always `#canvas`. Without the rule a two-finger pinch meant
for the camera can be read as a page zoom, and a double tap can zoom the whole
page instead of pressing a pad button.

Run after every Web export:

    python tools/patch_web_shell.py builds/web/index.html
"""

import sys
from pathlib import Path

RULE = """
#canvas {
	touch-action: none;
	-webkit-user-select: none;
	user-select: none;
}
"""

ANCHOR = "#canvas {\n\tdisplay: block;\n}\n"


def patch(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if "touch-action: none;\n\t-webkit-user-select" in text:
        return False
    if ANCHOR not in text:
        raise SystemExit(f"shell changed shape; no anchor in {path}")
    text = text.replace(ANCHOR, ANCHOR + RULE.lstrip("\n"), 1)
    path.write_text(text, encoding="utf-8")
    return True


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    p = Path(sys.argv[1])
    changed = patch(p)
    print(("patched " if changed else "already patched ") + str(p))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())