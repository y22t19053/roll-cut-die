"""Two fixes to Godot's exported HTML shell.

1. Touches on the canvas must not be read as page gestures. Godot's stock shell
   puts `touch-action: none` on `body`, which does not help — touch-action is
   resolved on the element the finger lands on, and here that element is always
   `#canvas`. Without the rule a two-finger pinch meant for the camera can zoom
   the whole page, and a double tap zooms instead of pressing a pad button.

2. The Bilibili TOY page does not hand its SDK to the game: `window.Toy` is
   undefined inside the toy iframe (verified on the published page), so a game
   that wants a leaderboard has to ask for the SDK itself. It is loaded only when
   the page is actually running under bilibilitoy.com, so itch and local builds
   never make a third-party request for a platform they do not have.

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

TOY_MARK = "rcd-toy-sdk"
TOY_BOOT = """<script id="rcd-toy-sdk">
// The TOY SDK is not injected into this frame by the host page: it has to be
// asked for from inside the page that wants it, and only there.
(function () {
	if (window.Toy) { return; }
	if (location.hostname.indexOf("bilibilitoy.com") === -1) { return; }
	var s = document.createElement("script");
	s.src = "https://s1.hdslb.com/bfs/seed/toy/app/sdk/toy-sdk.js";
	s.async = true;
	document.head.appendChild(s);
})();
</script>
"""
TOY_ANCHOR = '<script src="index.js"></script>'


def patch(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    changed = False
    if "touch-action: none;\n\t-webkit-user-select" not in text:
        if ANCHOR not in text:
            raise SystemExit(f"shell changed shape; no canvas anchor in {path}")
        text = text.replace(ANCHOR, ANCHOR + RULE.lstrip("\n"), 1)
        changed = True
    if TOY_MARK not in text:
        if TOY_ANCHOR not in text:
            raise SystemExit(f"shell changed shape; no index.js tag in {path}")
        text = text.replace(TOY_ANCHOR, TOY_BOOT + TOY_ANCHOR, 1)
        changed = True
    if changed:
        path.write_text(text, encoding="utf-8")
    return changed


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    p = Path(sys.argv[1])
    changed = patch(p)
    print(("patched " if changed else "already patched ") + str(p))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())