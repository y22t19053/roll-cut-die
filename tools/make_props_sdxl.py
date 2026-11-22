"""Paint the hardware and shoot a cover, using the local SDXL weights on D:.

`metal.png` is a MULTIPLY MASK (near-white) because `_surface()` multiplies it with
the material's albedo. `builds/cover.png` is a finished colour image — it is not
multiplied by anything, so it ships as-is.

  C:\\AI\\venv\\Scripts\\python.exe tools/make_props_sdxl.py
"""

import os
import numpy as np
import torch
from PIL import Image
from diffusers import StableDiffusionXLPipeline

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "assets", "textures")
BUILDS = os.path.join(ROOT, "builds")
CKPT = r"D:\ComfyModels\checkpoints\RealVisXL_V5.0_fp16.safetensors"


def pipe() -> StableDiffusionXLPipeline:
    p = StableDiffusionXLPipeline.from_single_file(CKPT, torch_dtype=torch.float16, use_safetensors=True)
    try:
        p.enable_model_cpu_offload()
    except Exception:
        p.to("cuda")
    if hasattr(p, "enable_attention_slicing"):
        p.enable_attention_slicing("max")
    return p


def tileable(img: Image.Image) -> Image.Image:
    a = np.asarray(img, dtype=np.float64)
    h, w, _ = a.shape
    out = a.copy()
    band = w // 8
    for i in range(band):
        t = i / (2.0 * band)
        left, right = a[:, i, :], a[:, w - 1 - i, :]
        out[:, i, :] = left * (1 - t) + right * t
        out[:, w - 1 - i, :] = right * (1 - t) + left * t
    for i in range(band):
        t = i / (2.0 * band)
        top, bot = a[i, :, :], a[h - 1 - i, :, :]
        out[i, :, :] = top * (1 - t) + bot * t
        out[h - 1 - i, :, :] = bot * (1 - t) + top * t
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def as_mask(img: Image.Image, floor: float) -> Image.Image:
    g = np.asarray(img.convert("L"), dtype=np.float64) / 255.0
    lo, hi = np.percentile(g, 1), np.percentile(g, 99)
    n = np.clip((g - lo) / max(hi - lo, 1e-6), 0.0, 1.0)
    m = floor + (1.0 - floor) * (0.35 * n + 0.65 * np.clip(n * 1.6 - 0.3, 0, 1))
    rgb = np.stack([m, m * 0.99, m * 0.975], axis=-1)
    return Image.fromarray(np.clip(rgb * 255.0, 0, 255).astype(np.uint8))


def main() -> None:
    os.makedirs(TEX, exist_ok=True)
    os.makedirs(BUILDS, exist_ok=True)
    p = pipe()

    metal = p(
        prompt=("flat top-down photograph of matte black painted steel, chipped paint on the "
                "edges, fine scratches, worn dolly hardware, even studio light, no shadows, "
                "seamless tileable, photogrammetry texture"),
        num_inference_steps=24, guidance_scale=5.5, width=768, height=768).images[0]
    # Mirroring a nearly uniform plate leaves a bright frame around it, which reads as a
    # painted border on a dolly. Cut the frame off and let the seams be panel edges.
    w, h = metal.size
    inset = int(w * 0.16)
    metal = metal.crop((inset, inset, w - inset, h - inset)).resize((512, 512), Image.LANCZOS)
    as_mask(metal, 0.70).save(os.path.join(TEX, "metal.png"))
    print("wrote metal.png")

    cover_path = os.path.join(BUILDS, "cover.png")
    if os.path.exists(cover_path):
        print("cover.png already there, keeping it")
        return
    cover = p(
        prompt=("cinematic still of an empty film soundstage at night, one strip of camera dolly "
                "track running through it, warm practical lamp hanging above, tall pale set walls, "
                "deep shadows, muted teal and amber, wide angle, no people, no text, no watermark, "
                "35mm film grain"),
        num_inference_steps=28, guidance_scale=6.0, width=1024, height=576).images[0]
    cover.save(cover_path)
    print("wrote cover.png")


if __name__ == "__main__":
    main()
