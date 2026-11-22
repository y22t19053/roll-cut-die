"""Paint the set with the real model library, not with noise.

Both outputs are MULTIPLY MASKS: near-white, carrying only wear and tooth, because
`relay_rooms._surface()` multiplies them with the material's own albedo colour. A
finished-colour texture would be darkened twice and the set would go black.

Run with the venv that has torch/diffusers:
  C:\\AI\\venv\\Scripts\\python.exe tools/make_textures_sdxl.py
"""

import os
import numpy as np
import torch
from PIL import Image
from diffusers import StableDiffusionXLPipeline

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "textures")
CKPT = r"D:\ComfyModels\checkpoints\RealVisXL_V5.0_fp16.safetensors"
SIZE = 768
STEPS = 24


def pipe() -> StableDiffusionXLPipeline:
    p = StableDiffusionXLPipeline.from_single_file(CKPT, torch_dtype=torch.float16, use_safetensors=True)
    # 8 GB of VRAM: keep the unet and the text encoders on the CPU and page them in,
    # otherwise a 768² pass runs the card out of memory mid-conv.
    try:
        p.enable_model_cpu_offload()
    except Exception:
        p.to("cuda")
    if hasattr(p, "enable_attention_slicing"):
        p.enable_attention_slicing("max")
    return p


def tileable(img: Image.Image) -> Image.Image:
    """Mirror-and-average the seams so the texture repeats without a visible join."""
    a = np.asarray(img, dtype=np.float64)
    h, w, _ = a.shape
    out = a.copy()
    band = w // 8
    for i in range(band):
        t = i / (2.0 * band)
        left = a[:, i, :]
        right = a[:, w - 1 - i, :]
        out[:, i, :] = left * (1 - t) + right * t
        out[:, w - 1 - i, :] = right * (1 - t) + left * t
    for i in range(band):
        t = i / (2.0 * band)
        top = a[i, :, :]
        bot = a[h - 1 - i, :, :]
        out[i, :, :] = top * (1 - t) + bot * t
        out[h - 1 - i, :, :] = bot * (1 - t) + top * t
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def as_mask(img: Image.Image, floor: float = 0.76) -> Image.Image:
    """Turn a painted surface into a near-white multiply mask with its tooth kept."""
    g = np.asarray(img.convert("L"), dtype=np.float64) / 255.0
    lo, hi = np.percentile(g, 1), np.percentile(g, 99)
    n = np.clip((g - lo) / max(hi - lo, 1e-6), 0.0, 1.0)
    m = floor + (1.0 - floor) * (0.35 * n + 0.65 * np.clip(n * 1.6 - 0.3, 0, 1))
    rgb = np.stack([m * 1.0, m * 0.995, m * 0.985], axis=-1)
    return Image.fromarray(np.clip(rgb * 255.0, 0, 255).astype(np.uint8))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    p = pipe()
    jobs = [
        ("deck_ai.png",
         "flat top-down photograph of a worn painted stage floor, scuffed matte paint, "
         "faint roller texture, even studio light, no shadows, seamless tileable, "
         "photogrammetry texture, high detail, neutral tone"),
        ("wall.png",
         "flat top-down photograph of painted plywood stage flat, matte beige paint over wood, "
         "brushed brush marks, fine grain, even studio light, no shadows, seamless tileable, "
         "photogrammetry texture, high detail"),
    ]
    for name, prompt in jobs:
        img = p(prompt=prompt, num_inference_steps=STEPS, guidance_scale=5.5,
                width=SIZE, height=SIZE).images[0]
        img = tileable(img).resize((512, 512), Image.LANCZOS)
        mask = as_mask(img, 0.76 if name.startswith("deck") else 0.80)
        mask.save(os.path.join(OUT, name))
        print("wrote", name, mask.size)


if __name__ == "__main__":
    main()
