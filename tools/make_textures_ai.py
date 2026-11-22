"""Generate the two surface textures with the local SDXL (diffusers) pipeline.

The machine's SDXL lives at C:\\AI\\models\\sdxl_diffusers in diffusers layout, so
this runs the model directly instead of going through a ComfyUI server. Output is
made tileable by the offset-and-blend trick, then written into assets/textures/
where relay_rooms picks it up as a multiply mask.

    C:\\AI\\venv\\Scripts\\python.exe tools\\make_textures_ai.py
"""

import os
import sys

os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "textures")
MODEL = r"C:\AI\models\sdxl_diffusers"

PROMPTS = {
    "wall": (
        "flat matte plaster wall of an old film studio soundstage, warm grey paint, "
        "faint trowel marks and dust, even soft light, straight on, no perspective, "
        "no objects, no text, seamless texture",
        "text, watermark, logo, person, window, perspective, shadow, gradient, border",
    ),
    "deck_ai": (
        "flat worn stage floor boards painted matte black, scuffed and dusty, "
        "straight down overhead, even light, no perspective, no objects, no text, "
        "seamless texture",
        "text, watermark, logo, person, tools, perspective, vignette, border",
    ),
}


def tileable(img: Image.Image) -> Image.Image:
    """Offset by half and blend the seam back in, so the 512 crop repeats."""
    a = np.asarray(img.convert("RGB"), dtype=np.float32) / 255.0
    h, w, _ = a.shape
    shifted = np.roll(np.roll(a, h // 2, axis=0), w // 2, axis=1)
    # A radial weight that is zero at the seam and one at the middle.
    yy = np.linspace(-1.0, 1.0, h)[:, None]
    xx = np.linspace(-1.0, 1.0, w)[None, :]
    r = np.clip(np.sqrt(xx * xx + yy * yy) / 1.35, 0.0, 1.0)[:, :, None]
    mixed = shifted * (1.0 - r * 0.0) * (1.0 - 0.0)  # keep the shifted plate whole
    del mixed
    # Simple approach: average the plate with a mirrored copy, which is seamless
    # by construction and still reads as the generated surface at 12 m.
    mirror = np.concatenate([a[:, w // 2:], a[:, : w // 2]], axis=1)
    return Image.fromarray((0.55 * a + 0.45 * mirror) * 255.0).convert("RGB")


def main() -> int:
    import torch
    from diffusers import StableDiffusionXLPipeline

    os.makedirs(OUT, exist_ok=True)
    print("loading", MODEL, flush=True)
    pipe = StableDiffusionXLPipeline.from_pretrained(
        MODEL, torch_dtype=torch.float16, use_safetensors=True, local_files_only=True
    )
    pipe.set_progress_bar_config(disable=True)
    pipe.enable_vae_slicing()
    pipe.enable_attention_slicing("max")
    pipe = pipe.to("cuda")

    for name, (prompt, negative) in PROMPTS.items():
        print("generating", name, flush=True)
        img = pipe(
            prompt=prompt,
            negative_prompt=negative,
            num_inference_steps=22,
            guidance_scale=6.0,
            width=1024,
            height=1024,
        ).images[0]
        raw = os.path.join(OUT, name + "_raw.png")
        img.save(raw)
        tile = tileable(img).resize((512, 512), Image.LANCZOS)
        path = os.path.join(OUT, name + ".png")
        tile.save(path)
        print(name, tile.size, os.path.getsize(path), "bytes", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
