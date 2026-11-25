"""Prepare transparent menu art and draw the embossed workshop symbols."""

import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt, gaussian_filter, label

from make_assets import rgba

DESTINATION = Path(__file__).resolve().parents[1] / "assets/ui/workshop"
GLYPHS = ["home", "restart", "sound", "music", "haptics", "globe", "check", "cutter"]


def isolated(image, minimum_fraction=1.0):
    pixels = np.asarray(image.convert("RGBA")).copy()
    groups, count = label(pixels[..., 3] >= 102)
    if count == 0:
        raise ValueError("Expected a visible motif")
    areas = np.bincount(groups.ravel())
    areas[0] = 0
    main = (groups > 0) & (areas[groups] >= areas.max() * minimum_fraction)
    pixels[distance_transform_edt(~main) > 1.8] = 0
    cleaned = Image.fromarray(pixels)
    return cleaned.crop(cleaned.getbbox(alpha_only=True))


def prepare_dock(source):
    tray = isolated(Image.open(source), .003)
    tray.thumbnail((1152, 308), Image.Resampling.LANCZOS)
    tray.save(DESTINATION / "dock.png", optimize=True)


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


def sprite_grid(source, minimum_fraction=1.0):
    montage = Image.open(source).convert("RGBA")
    for index in range(9):
        row, column = divmod(index, 3)
        yield isolated(montage.crop((column * montage.width // 3, row * montage.height // 3,
                                     (column + 1) * montage.width // 3, (row + 1) * montage.height // 3)), minimum_fraction)


def prepare_icons(source):
    atlas = Image.new("RGBA", (160 * 3, 160 * 3))
    for index, sprite in enumerate(sprite_grid(source)):
        sprite.thumbnail((146, 146), Image.Resampling.LANCZOS)
        row, column = divmod(index, 3)
        atlas.paste(sprite, (column * 160 + (160 - sprite.width) // 2,
                             row * 160 + (160 - sprite.height) // 2))
    atlas.save(DESTINATION / "icons.png", optimize=True)


def prepare_seals(source):
    sheet = Image.open(source).convert("RGBA")
    atlas = Image.new("RGBA", (320, 320))
    for index in range(4):
        row, column = divmod(index, 2)
        seal = isolated(sheet.crop((column * sheet.width // 2, row * sheet.height // 2,
                                   (column + 1) * sheet.width // 2, (row + 1) * sheet.height // 2)))
        seal.thumbnail((148, 148), Image.Resampling.LANCZOS)
        atlas.paste(seal, (column * 160 + (160 - seal.width) // 2,
                           row * 160 + (160 - seal.height) // 2))
    atlas.save(DESTINATION / "seals.png", optimize=True)


def prepare_effects(source):
    atlas = Image.new("RGBA", (160 * 3, 160 * 3))
    for index, sprite in enumerate(sprite_grid(source, .075)):
        sprite.thumbnail((146, 146), Image.Resampling.LANCZOS)
        row, column = divmod(index, 3)
        atlas.paste(sprite, (column * 160 + (160 - sprite.width) // 2,
                             row * 160 + (160 - sprite.height) // 2))
    atlas.save(DESTINATION / "effects.png", optimize=True)


def fit(sprite, size=122):
    image = sprite.copy()
    image.thumbnail((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (128, 128))
    canvas.paste(image, ((128 - image.width) // 2, (128 - image.height) // 2))
    return canvas


def brightness(sprite, scale):
    pixels = np.array(sprite)
    pixels[..., :3] = np.uint8(np.clip(pixels[..., :3] * scale, 0, 255))
    return Image.fromarray(pixels)


def prepare_cubes(source):
    atlas = Image.new("RGBA", (128 * 10, 128 * 9))
    for row, sprite in enumerate(sprite_grid(source)):
        face = fit(sprite)
        for variant in range(7):
            changed = face.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if variant % 2 else face
            changed = changed.rotate([0, 0, 2, -2, 1, -1, 3][variant], resample=Image.Resampling.BICUBIC)
            atlas.paste(brightness(changed, [1.0, .96, 1.02, 1.01, .97, .99, 1.04][variant]), (variant * 128, row * 128))
        atlas.paste(brightness(face, .85), (7 * 128, row * 128))
        crumb = sprite.resize((96, 82), Image.Resampling.LANCZOS).rotate(23, expand=True, resample=Image.Resampling.BICUBIC)
        atlas.paste(fit(crumb, 99), (9 * 128, row * 128))
    atlas.save(DESTINATION.parent.parent / "clay" / "studio.png", optimize=True)


def surface(recessed=False):
    w, h = 224, 112
    yy, xx = np.mgrid[0:h, 0:w]
    dx, dy = abs(xx - (w - 1) / 2) - 78, abs(yy - (h - 1) / 2) - 22
    signed = 32 - np.hypot(np.maximum(dx, 0), np.maximum(dy, 0)) - np.minimum(np.maximum(dx, dy), 0)
    grain = np.random.default_rng(39 if recessed else 21).normal(0, .054, (h, w))
    rolling = gaussian_filter(grain, 5)
    height = .73 * (1 - np.exp(-np.maximum(0, signed) * .17))
    height += .055 * np.sin(xx * .052 + yy * .072) + .033 * np.sin(xx * .105 - yy * .037)
    if recessed:
        height -= .44 / (1 + np.exp(-(signed - 13) * .57))
    slope_y, slope_x = np.gradient(height)
    light = .93 + slope_x * .83 + slope_y * 1.72 + (1 - yy / h) * .095 + rolling * 7
    light += np.sin(xx * .087 - yy * .105) * .017 + grain * .16
    if recessed:
        light -= .093 / (1 + np.exp(-(signed - 13) * .5))
    alpha = np.clip(signed + rolling * 24 + .55, 0, 1)
    return rgba(np.dstack([light, light * .995, light * .975]), alpha)


def icon_mask(name):
    mask = Image.new("L", (128, 128))
    draw = ImageDraw.Draw(mask)
    if name == "home":
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
    elif name == "music":
        draw.rounded_rectangle((52, 27, 63, 88), 5, fill=255)
        draw.rounded_rectangle((89, 18, 100, 73), 5, fill=255)
        draw.polygon([(52, 27), (100, 18), (100, 32), (52, 42)], fill=255)
        draw.ellipse((31, 76, 63, 100), fill=255)
        draw.ellipse((70, 61, 100, 84), fill=255)
    elif name == "haptics":
        draw.rounded_rectangle((41, 21, 87, 106), 10, fill=255)
        draw.rounded_rectangle((49, 31, 79, 88), 5, fill=0)
        draw.ellipse((59, 92, 69, 102), fill=0)
        draw.arc((16, 34, 55, 94), 115, 245, fill=255, width=6)
        draw.arc((74, 34, 112, 94), -65, 65, fill=255, width=6)
    elif name == "globe":
        draw.ellipse((24, 24, 104, 104), outline=255, width=8)
        draw.ellipse((47, 24, 81, 104), outline=255, width=7)
        draw.line((25, 64, 103, 64), fill=255, width=7)
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
    parser.add_argument("--dock", type=Path)
    parser.add_argument("--icons", type=Path)
    parser.add_argument("--cubes", type=Path)
    parser.add_argument("--hero", type=Path)
    parser.add_argument("--effects", type=Path)
    parser.add_argument("--seals", type=Path)
    options = parser.parse_args()
    DESTINATION.mkdir(parents=True, exist_ok=True)
    if options.frame:
        prepare_frame(options.frame)
    if options.dock:
        prepare_dock(options.dock)
    if options.icons:
        prepare_icons(options.icons)
    if options.effects:
        prepare_effects(options.effects)
    if options.seals:
        prepare_seals(options.seals)
    if options.cubes:
        prepare_cubes(options.cubes)
    if options.hero:
        hero = isolated(Image.open(options.hero), .003)
        hero.thumbnail((960, 960), Image.Resampling.LANCZOS)
        hero.save(DESTINATION.parent / "hero.png", optimize=True)
        icon = Image.new("RGBA", (256, 256))
        draw = ImageDraw.Draw(icon)
        draw.rounded_rectangle((4, 4, 251, 251), 49, fill="#a5dfc4")
        draw.rounded_rectangle((12, 12, 243, 243), 44, fill="#fff0cc")
        hero.thumbnail((223, 221), Image.Resampling.LANCZOS)
        icon.alpha_composite(hero, ((256 - hero.width) // 2, (256 - hero.height) // 2))
        icon.save(DESTINATION.parent / "icon.png", optimize=True)
    surface().save(DESTINATION / "card.png", optimize=True)
    surface(True).save(DESTINATION / "tray.png", optimize=True)
    draw_glyphs()
