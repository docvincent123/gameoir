"""Pack continuous clay surfaces and prepare the carving tray."""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps
from scipy.ndimage import gaussian_filter

from make_workshop_ui import isolated

ROOT = Path(__file__).resolve().parents[1]
PATCH = 320
COLS = 5


def flat_surface(source):
    image = Image.open(source).convert("RGB")
    inset = round(min(image.size) * .045)
    area = image.crop((inset, inset, image.width - inset, image.height - inset))
    return ImageOps.fit(area, (PATCH, PATCH), Image.Resampling.LANCZOS)


def pack(peach, cool):
    atlas = Image.new("RGB", (COLS * PATCH, 4 * PATCH))
    glaze = (flat_surface(peach), flat_surface(cool))
    roughness = np.asarray(glaze[0].convert("L"), dtype=float)
    grain = (roughness - gaussian_filter(roughness, 2.6)) * .52
    old = Image.open(ROOT / "assets/clay/materials.png").convert("RGB")
    for style in range(16):
        y = style * 128
        patch = old.crop((18, y + 18, 110, y + 110)).resize((PATCH, PATCH), Image.Resampling.BICUBIC)
        textured = np.clip(np.asarray(patch, dtype=float) + grain[..., None], 0, 255).astype(np.uint8)
        atlas.paste(Image.fromarray(textured), (style % COLS * PATCH, style // COLS * PATCH))
    for style, surface in enumerate(glaze, start=16):
        atlas.paste(surface, (style % COLS * PATCH, style // COLS * PATCH))
    atlas.save(ROOT / "assets/clay/slabs.jpg", quality=91, subsampling=0, optimize=True)


def prepare_tray(source):
    tray = isolated(Image.open(source), .003)
    tray = tray.resize((1024, 1024), Image.Resampling.LANCZOS)
    tray.save(ROOT / "assets/ui/workshop/board.png", optimize=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("peach", type=Path)
    parser.add_argument("cool", type=Path)
    parser.add_argument("tray", type=Path)
    options = parser.parse_args()
    pack(options.peach, options.cool)
    prepare_tray(options.tray)
