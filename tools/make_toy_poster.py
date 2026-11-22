"""Toy 平台的封面（4:3）与图标（正方形）。

itch 要 630x500，Toy 的卡片是 4:3，所以不能把 16:9 的静帧硬拉成 4:3 ——
这里先裁成 4:3（保住甲板与亮线），再套 make_cover 的同一套字。

  C:\\AI\\venv\\Scripts\\python.exe tools/make_toy_poster.py
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_cover import FONT, INK, ACCENT, scrim, set_title  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "visual", "cover.png")


def four_three(img: Image.Image) -> Image.Image:
    """Crop 16:9 to 4:3, leaning left so the lit floor stays in frame."""
    w, h = img.size
    want = int(round(h * 4 / 3))
    if want <= w:
        left = int((w - want) * 0.35)
        return img.crop((left, 0, left + want, h))
    want_h = int(round(w * 3 / 4))
    top = int((h - want_h) * 0.5)
    return img.crop((0, top, w, top + want_h))


def icon(size: int = 512) -> Image.Image:
    """Black slate, clapper stripes, three letters — readable at 64 px."""
    img = Image.new("RGBA", (size, size), (22, 21, 19, 255))
    d = ImageDraw.Draw(img)

    band = int(size * 0.26)
    d.rectangle([(0, 0), (size, band)], fill=(238, 233, 221, 255))
    step = int(size * 0.13)
    for i in range(-1, int(size / step) + 2):
        x = i * step
        d.polygon([(x, band), (x + step, band), (x + step - band, 0), (x - band, 0)],
                  fill=(24, 23, 21, 255))
    d.rectangle([(0, band), (size, band + int(size * 0.028))], fill=ACCENT)

    big = ImageFont.truetype(FONT, int(size * 0.30))
    track = int(size * 0.020)
    text = "RCD"
    widths = [big.getlength(c) for c in text]
    total = sum(widths) + track * (len(text) - 1)
    x = (size - total) / 2
    y = band + (size - band) * 0.40
    for ch, w in zip(text, widths):
        d.text((x, y), ch, font=big, fill=INK)
        x += w + track

    rule_y = int(y + size * 0.40)
    d.line([(int(size * 0.30), rule_y), (int(size * 0.70), rule_y)],
           fill=ACCENT, width=max(3, int(size * 0.012)))
    return img


def main() -> None:
    base = four_three(Image.open(SRC).convert("RGBA"))
    poster = set_title(scrim(base, 235), 1.0)
    out = poster.convert("RGB").resize((1200, 900), Image.LANCZOS)
    path = os.path.join(ROOT, "visual", "toy_poster.png")
    out.save(path)
    print("wrote toy_poster.png", out.size)

    ipath = os.path.join(ROOT, "visual", "toy_icon.png")
    icon(512).convert("RGB").save(ipath)
    print("wrote toy_icon.png", (512, 512))


if __name__ == "__main__":
    main()