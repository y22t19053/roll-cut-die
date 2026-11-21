"""Procedural set dressings for the relay rooms.

Two seamless albedo maps, written straight into assets/textures/. They are
*multiply masks*, not colour: the material keeps its own albedo colour and this
map only adds tooth, wear and seams on top of it. Deterministic (fixed seeds) so
a rebuild of the game rebuilds the same floor.
"""
import os
import numpy as np
from PIL import Image

OUT = r"C:\Users\11ee11\Documents\deepseek-harness\default-workspace\roll-cut-die\assets\textures"
SIZE = 512
TINT = np.array([1.0, 0.985, 0.97])   # a hair warm, so paint reads as paint
NEUTRAL = 230.0                        # multiply pivot: 230/255 ≈ 0.90


def value_noise(rng, cells, size):
    """Tileable value noise: a small grid, bilinearly upsampled with wrap."""
    grid = rng.random((cells + 1, cells + 1))
    grid[-1, :] = grid[0, :]
    grid[:, -1] = grid[:, 0]
    ys = np.linspace(0, cells, size, endpoint=False)
    xs = np.linspace(0, cells, size, endpoint=False)
    y0 = ys.astype(int)
    x0 = xs.astype(int)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = grid[y0][:, x0]
    b = grid[y0][:, x0 + 1]
    c = grid[y0 + 1][:, x0]
    d = grid[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(rng, octaves=(4, 8, 16, 32), gain=0.5):
    total = np.zeros((SIZE, SIZE))
    amp = 1.0
    norm = 0.0
    for cells in octaves:
        total += value_noise(rng, cells, SIZE) * amp
        norm += amp
        amp *= gain
    return total / norm


def grain(rng, amount):
    return (rng.random((SIZE, SIZE)) - 0.5) * amount


def to_image(rgb):
    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    return Image.fromarray(rgb, mode="RGB")


def deck():
    rng = np.random.default_rng(7)
    blotch = fbm(rng, (4, 8, 16, 32)) - 0.5          # broad wear
    fine = fbm(rng, (32, 64, 128)) - 0.5              # paper tooth
    g = grain(rng, 16)
    field = blotch * 26 + fine * 22 + g
    # Scuffs: a few long, faint diagonal drags across the deck.
    ys, xs = np.mgrid[0:SIZE, 0:SIZE]
    for _ in range(7):
        y0 = rng.integers(0, SIZE)
        slope = rng.uniform(-0.5, 0.5)
        width = rng.uniform(1.5, 5.0)
        strength = rng.uniform(4.0, 11.0)
        d = np.abs((ys - y0) - slope * xs)
        d = np.minimum(d, SIZE - d)
        field += strength * np.exp(-((d / width) ** 2))
    # Seams every 256 px: plywood sheets laid on the stage.
    seam = np.minimum(np.abs(((ys + 128) % 256) - 128), 1e9)
    field -= 12 * np.exp(-((seam / 1.6) ** 2))
    rgb = NEUTRAL + field[:, :, None] * 0.95 * TINT
    return to_image(rgb)


def flat():
    rng = np.random.default_rng(11)
    # Painted plywood: fine tooth everywhere, plus faint vertical brush pulls.
    fine = fbm(rng, (8, 16, 32, 64)) - 0.5
    g = grain(rng, 10)
    # One-dimensional noise along x, smoothed into soft brush columns.
    col = rng.random(SIZE)
    k = np.ones(9) / 9.0
    col = np.convolve(np.concatenate([col[-4:], col, col[:5]]), k, mode="same")[4:-5]
    col = (col - col.mean()) * 22.0
    field = fine * 20 + g + col[None, :]
    # A faint horizontal batten line, like a flat braced at chest height.
    ys, xs = np.mgrid[0:SIZE, 0:SIZE]
    batten = np.abs(((ys + 64) % 256) - 128)
    field -= 6 * np.exp(-((batten / 2.2) ** 2))
    rgb = NEUTRAL + field[:, :, None] * 0.95 * TINT
    return to_image(rgb)


def main():
    os.makedirs(OUT, exist_ok=True)
    deck().save(os.path.join(OUT, "deck.png"), optimize=True)
    flat().save(os.path.join(OUT, "flat.png"), optimize=True)
    for name in ("deck.png", "flat.png"):
        p = os.path.join(OUT, name)
        print(name, os.path.getsize(p), "bytes")


if __name__ == "__main__":
    main()
