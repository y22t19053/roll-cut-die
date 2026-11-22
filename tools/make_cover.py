"""Typeset the store cover from the still, at the sizes itch actually asks for.

The still is the picture; the type is the game's own face (Noto, wide tracking,
uppercase, two lines, the same rhythm as the title screen). No new pixels are drawn
on the photograph beyond a soft scrim under the type — a cover that fights its own
art reads as a template.

  C:\\AI\\venv\\Scripts\\python.exe tools/make_cover.py
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "visual", "cover.png")
FONT = os.path.join(ROOT, "assets", "fonts", "RCD-Noto.otf")
INK = (243, 223, 173, 255)      # the deck's chalk colour
ACCENT = (226, 67, 46, 255)     # CUT! red


def scrim(img: Image.Image, band: int) -> Image.Image:
    """Darken the left third only, so the type sits on quiet pixels."""
    w, h = img.size
    veil = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(veil)
    for x in range(int(w * 0.72)):
        t = x / (w * 0.72)
        d.line([(x, 0), (x, h)], fill=(8, 10, 12, int(band * (1.0 - t) ** 1.5)))
    return Image.alpha_composite(img.convert("RGBA"), veil)


def set_title(img: Image.Image, cap: float) -> Image.Image:
    w, h = img.size
    big = ImageFont.truetype(FONT, int(h * 0.155))
    small = ImageFont.truetype(FONT, int(h * 0.030))
    d = ImageDraw.Draw(img)
    x = int(w * 0.055)
    y = int(h * 0.30)
    tracking = int(h * 0.012)

    def tracked(text: str, font: ImageFont.FreeTypeFont, at: tuple, fill) -> None:
        cx = at[0]
        for ch in text:
            d.text((cx, at[1]), ch, font=font, fill=fill)
            cx += font.getlength(ch) + tracking

    tracked("ROLL", big, (x, y), INK)
    tracked("CUT DIE", big, (x, y + int(h * 0.185)), INK)
    d.line([(x, y + int(h * 0.40)), (x + int(w * 0.20), y + int(h * 0.40))], fill=ACCENT, width=max(2, int(h * 0.006)))
    # The line under the title crosses the lit floor, where pale type disappears.
    # A soft bar, not a box: it should read as the photograph falling off, not as UI.
    tag_y = y + int(h * 0.44)
    bar = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(bar).rectangle(
        [(x - int(w * 0.02), tag_y - int(h * 0.022)), (x + int(w * 0.66), tag_y + int(h * 0.052))],
        fill=(8, 10, 12, 120))
    img = Image.alpha_composite(img, bar.filter(ImageFilter.GaussianBlur(int(h * 0.012))))
    d = ImageDraw.Draw(img)
    tracked("YOUR LAST TAKE WALKS BACK TOWARD YOU", small, (x, tag_y), (243, 223, 173, 220))
    return img


def save(img: Image.Image, name: str, size: tuple) -> None:
    out = img.convert("RGB").resize(size, Image.LANCZOS)
    path = os.path.join(ROOT, "visual", name)
    out.save(path)
    print("wrote", name, out.size)


def main() -> None:
    base = Image.open(SRC).convert("RGBA")
    wide = set_title(scrim(base, 235), 1.0)
    save(wide, "cover_titled.png", (1024, 576))
    save(wide, "cover_titled_630.png", (630, 500))
    save(wide, "capsule_1920.png", (1920, 620))


if __name__ == "__main__":
    main()
