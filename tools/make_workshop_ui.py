"""Prepare transparent menu art and draw the embossed workshop symbols."""

import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt, gaussian_filter, label

from make_assets import rgba

DESTINATION = Path(__file__).resolve().parents[1] / "assets/ui/workshop"
BUTTONS = ["primary", "plum", "amber", "muted", "tray", "card"]
OBJECTS = ["star", "clock", "shine"]
GLYPHS = ["play", "calendar", "collection", "trophy", "settings", "pause", "back",
          "home", "restart", "sound", "flag", "check", "cutter"]


def isolated(image):
    pixels = np.asarray(image.convert("RGBA")).copy()
    groups, count = label(pixels[..., 3] >= 102)
    if count == 0:
        raise ValueError("Expected a visible motif")
    areas = np.bincount(groups.ravel())
    areas[0] = 0
    main = groups == areas.argmax()
    pixels[distance_transform_edt(~main) > 1.8] = 0
    cleaned = Image.fromarray(pixels)
    return cleaned.crop(cleaned.getbbox(alpha_only=True))


def prepare_frame(source):
    frame = isolated(Image.open(source))
    w, h = frame.size
    side = 1024
    edge = 62
    trim = int(min(w, h) * .152)
    source_x = [0, trim, w - trim, w]
    source_y = [0, trim, h - trim, h]
    target = [0, edge, side - edge, side]
    reshaped = Image.new("RGBA", (side, side))
    for y in range(3):
        for x in range(3):
            section = frame.crop((source_x[x], source_y[y], source_x[x + 1], source_y[y + 1]))
            size = (target[x + 1] - target[x], target[y + 1] - target[y])
            reshaped.paste(section.resize(size, Image.Resampling.LANCZOS), (target[x], target[y]))
    reshaped.save(DESTINATION / "board.png", optimize=True)


def prepare_kit(source):
    montage = Image.open(source).convert("RGBA")
    for index, name in enumerate(BUTTONS + OBJECTS):
        row, column = divmod(index, 3)
        image = isolated(montage.crop((column * montage.width // 3, row * montage.height // 3,
                                       (column + 1) * montage.width // 3, (row + 1) * montage.height // 3)))
        if name in BUTTONS:
            image = image.resize((224, 112), Image.Resampling.LANCZOS)
        else:
            image.thumbnail((132, 132), Image.Resampling.LANCZOS)
        image.save(DESTINATION / (name + ".png"), optimize=True)


def icon_mask(name):
    mask = Image.new("L", (128, 128))
    draw = ImageDraw.Draw(mask)
    if name == "play":
        draw.polygon([(42, 21), (106, 63), (42, 105)], fill=255)
    elif name == "calendar":
        draw.rounded_rectangle((22, 30, 106, 104), 15, fill=255)
        for x in (43, 84):
            draw.rounded_rectangle((x - 7, 19, x + 7, 47), 5, fill=255)
        draw.rectangle((31, 53, 96, 62), fill=0)
        for x in (43, 65, 86):
            draw.rounded_rectangle((x - 4, 73, x + 4, 82), 2, fill=0)
    elif name == "collection":
        for x, y in [(28, 28), (66, 28), (28, 66), (66, 66)]:
            draw.rounded_rectangle((x, y, x + 33, y + 33), 9, fill=255)
    elif name == "trophy":
        draw.rounded_rectangle((37, 22, 91, 75), 18, fill=255)
        draw.arc((21, 32, 47, 68), 75, 270, fill=255, width=8)
        draw.arc((80, 32, 106, 68), -90, 105, fill=255, width=8)
        draw.rounded_rectangle((56, 65, 72, 97), 5, fill=255)
        draw.rounded_rectangle((39, 93, 89, 105), 5, fill=255)
    elif name == "settings":
        teeth = []
        for point in range(32):
            theta = point * math.tau / 32.0
            radius = 42 if point % 4 in (1, 2) else 33
            teeth.append((64 + math.cos(theta) * radius, 64 + math.sin(theta) * radius))
        draw.polygon(teeth, fill=255)
        draw.ellipse((51, 51, 77, 77), fill=0)
    elif name == "pause":
        draw.rounded_rectangle((36, 23, 55, 105), 8, fill=255)
        draw.rounded_rectangle((73, 23, 92, 105), 8, fill=255)
    elif name == "back":
        draw.line([(67, 33), (38, 64), (67, 95)], fill=255, width=15, joint="curve")
        draw.rounded_rectangle((42, 57, 103, 72), 6, fill=255)
    elif name == "home":
        draw.polygon([(17, 61), (64, 22), (111, 61), (100, 68), (27, 68)], fill=255)
        draw.rounded_rectangle((31, 55, 97, 102), 9, fill=255)
        draw.rounded_rectangle((56, 74, 75, 105), 5, fill=0)
    elif name == "restart":
        draw.arc((25, 25, 103, 103), -70, 244, fill=255, width=14)
        draw.polygon([(25, 18), (26, 54), (60, 42)], fill=255)
    elif name == "sound":
        draw.polygon([(25, 50), (42, 50), (63, 33), (63, 95), (42, 78), (25, 78)], fill=255)
        draw.arc((46, 33, 101, 95), -65, 65, fill=255, width=8)
        draw.arc((49, 47, 86, 81), -65, 65, fill=255, width=8)
    elif name == "flag":
        draw.rounded_rectangle((34, 23, 44, 106), 4, fill=255)
        draw.polygon([(40, 28), (97, 28), (81, 47), (98, 66), (40, 66)], fill=255)
    elif name == "check":
        draw.line([(29, 65), (55, 87), (98, 43)], fill=255, width=15, joint="curve")
    elif name == "cutter":
        draw.rounded_rectangle((22, 25, 106, 62), 11, fill=255)
        draw.rounded_rectangle((49, 48, 80, 98), 10, fill=255)
        draw.rounded_rectangle((32, 34, 96, 52), 7, fill=0)
        draw.rounded_rectangle((57, 50, 71, 87), 5, fill=0)
    return np.asarray(mask) > 0


def draw_glyphs():
    atlas = Image.new("RGBA", (128 * 7, 128 * 2))
    rng = np.random.default_rng(22)
    for index, name in enumerate(GLYPHS):
        mask = icon_mask(name)
        signed = gaussian_filter(distance_transform_edt(mask) - distance_transform_edt(~mask), 1.45)
        height = 1.0 - np.exp(-np.clip(signed, 0, None) * .19)
        dy, dx = np.gradient(height)
        vertical = np.linspace(.10, -.23, 128)[:, None]
        light = np.clip(.89 + vertical + dx * 1.6 + dy * 2.05, .38, 1)
        light += gaussian_filter(rng.normal(0, .027, light.shape), .39)
        colors = np.dstack([light * 1.10, light * .97, light * .91])
        alpha = np.clip(signed + .66, 0, 1)
        atlas.paste(rgba(colors, alpha), (index % 7 * 128, index // 7 * 128))
    atlas.save(DESTINATION / "glyphs.png", optimize=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--frame", type=Path)
    parser.add_argument("--kit", type=Path)
    options = parser.parse_args()
    DESTINATION.mkdir(parents=True, exist_ok=True)
    if options.frame:
        prepare_frame(options.frame)
    if options.kit:
        prepare_kit(options.kit)
    draw_glyphs()
