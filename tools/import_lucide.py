"""Rasterize the pinned Lucide controls into a small, tintable atlas."""

import io
import subprocess
import urllib.request
from pathlib import Path

from PIL import Image

VERSION = "1.80.0"
BASE = f"https://raw.githubusercontent.com/lucide-icons/lucide/{VERSION}"
ICONS = [
    "arrow-left", "house", "rotate-ccw", "volume-2", "headphones", "vibrate",
    "languages", "check", "copy", "lock-keyhole", "chevron-left", "chevron-right",
    "shapes", "sliders-horizontal", "chevrons-up-down",
]
SIDE = 132
COLUMNS = 5
ROOT = Path(__file__).resolve().parents[1] / "assets/ui/lucide"


def get(path):
    with urllib.request.urlopen(BASE + "/" + path, timeout=20) as response:
        return response.read()


def icon(name):
    svg = get(f"icons/{name}.svg").decode()
    svg = svg.replace('stroke="currentColor"', 'stroke="#fff"')
    svg = svg.replace('width="24"', f'width="{SIDE}"', 1)
    svg = svg.replace('height="24"', f'height="{SIDE}"', 1)
    raster = subprocess.run(
        ["inkscape", "--pipe", "--export-type=png", "--export-filename=-"],
        input=svg.encode(), check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    return Image.open(io.BytesIO(raster.stdout)).convert("RGBA")


if __name__ == "__main__":
    ROOT.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (SIDE * COLUMNS, SIDE * 3))
    for index, name in enumerate(ICONS):
        tile = icon(name)
        assert tile.size == (SIDE, SIDE) and tile.getbbox() is not None, name
        atlas.paste(tile, (index % COLUMNS * SIDE, index // COLUMNS * SIDE))
    atlas.save(ROOT / "controls.png", optimize=True)
    (ROOT / "LICENSE.txt").write_bytes(get("LICENSE"))
