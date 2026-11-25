"""Build checked-in clay and metal atlases and original synthesized sounds."""

import json
import math
import re
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, gaussian_filter

ROOT = Path(__file__).resolve().parents[1]
S = 128
rng = np.random.default_rng(41337)
yy, xx = np.mgrid[0:S, 0:S] / (S - 1)
PALETTES = [
    ((174, 81, 238), (118, 37, 174)),
    ((250, 154, 198), (90, 72, 201)),
    ((119, 69, 230), (41, 18, 102)),
    ((255, 195, 38), (172, 81, 6)),
    ((243, 217, 217), (148, 80, 185)),
    ((255, 111, 177), (178, 32, 107)),
    ((172, 225, 56), (60, 136, 13)),
    ((255, 116, 130), (167, 33, 64)),
    ((230, 163, 98), (149, 76, 38)),
    ((62, 225, 209), (17, 108, 130)),
    ((252, 141, 40), (161, 32, 36)),
    ((147, 220, 250), (37, 107, 201)),
]


def rgba(rgb, opacity):
    pixels = np.uint8(np.clip(np.dstack((rgb, opacity)) * 255, 0, 255))
    pixels[pixels[..., 3] == 0, :3] = 0
    return Image.fromarray(pixels)


def smooth_noise(sigma):
    field = gaussian_filter(rng.random((S, S)), sigma)
    return (field - field.mean()) / field.std()


def clay(material, variation, mode="tile"):
    qx, qy = abs(xx - .5) - .288, abs(yy - .494) - .282
    perimeter = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    distance = .194 - perimeter - np.minimum(np.maximum(qx, qy), 0)
    fine = smooth_noise(.75)
    roll = smooth_noise(3.5)
    smear = smooth_noise(11)
    distance += .0035 * roll + .004 * smear
    if mode == "crumb":
        theta = np.arctan2(yy - .5, xx - .5)
        distance = .38 - np.hypot((xx - .5) * .98, (yy - .5) * 1.23)
        distance += .021 * np.sin(theta * 5) + .028 * np.cos(theta * 3) + .006 * roll
    edge = np.clip(distance, 0, 1)
    height = .64 * (1 - np.exp(-19 * edge)) + .32 * (1 - np.exp(-4.5 * edge))
    height += .087 * (1 - np.clip(np.hypot(xx - .36, yy - .26), 0, 1))
    groove = np.sin(xx * 7.2 + yy * 9.0 + variation * 2.5 + .57 * smear)
    height += .027 * smear + .012 * groove + .0050 * roll + .0009 * fine
    dy, dx = np.gradient(height * 12)
    shade = np.clip(.78 * dx + dy, -.42, .45) + .026 * roll + .018 * fine
    shade += .25 * np.exp(-np.hypot((xx - .30) * 1.2, (yy - .22) * 2.3) * 3.8)
    mix = np.clip(.83 - .37 * yy + .06 * smear, 0, 1)
    bright, dark = (np.array(color) / 255 for color in PALETTES[material])
    color = mix[..., None] * bright + (1 - mix[..., None]) * dark

    if material == 1:
        stripe = np.mod((xx + yy * .83 + .08 * smear) * .78, 1)
        stops = [[250, 115, 163], [255, 188, 87], [248, 219, 129], [119, 218, 163],
                 [95, 188, 226], [146, 113, 241], [250, 115, 163]]
        color = np.dstack([np.interp(stripe, np.linspace(0, 1, len(stops)), np.array(stops)[:, n])
                           for n in range(3)]) / 255
    if material in (2, 3, 9, 11):
        cloud = np.clip((smear + 1) / 3, 0, 1)
        tint = np.array({2: [.24, .18, .39], 3: [.28, .17, .02],
                         9: [.03, .22, .18], 11: [.12, .19, .25]}[material])
        color += cloud[..., None] * tint
        light = np.zeros((S, S))
        for _ in range(44 if material == 2 else 26):
            sy, sx = rng.integers(6, S - 6, 2)
            light[sy, sx] = rng.uniform(.25, 1)
        light = gaussian_filter(light, .67)
        color += light[..., None] * 2.35
        if material == 2:
            for _ in range(3):
                sx, sy = rng.uniform(.19, .81, 2)
                ray = np.exp(-abs(xx - sx) * 190 - abs(yy - sy) * 30)
                ray += np.exp(-abs(xx - sx) * 30 - abs(yy - sy) * 190)
                color += ray[..., None] * .62
    if material == 4:
        swirl = .5 + .5 * np.sin((xx * .80 + yy + .135 * smear) * 14)
        blend = np.clip(swirl ** 2.5 * .80, 0, 1)[..., None]
        color = color * (1 - blend) + np.array([.62, .30, .78]) * blend
    if material in (7, 8):
        if material == 7:
            rind = np.clip((yy - .80 + .033 * smear) * 18, 0, 1)[..., None]
            color = color * (1 - rind) + np.array([.22, .62, .24]) * rind
        for _ in range(9):
            sx, sy = rng.uniform(.14, .86, 2)
            dot = np.exp(-((xx - sx) ** 2 * 1.7 + (yy - sy) ** 2) * (1700 if material == 7 else 930))
            color *= 1 - dot[..., None] * .62
    if material == 10:
        veins = np.clip(abs(np.sin((xx + yy + .14 * smear) * 7)) ** 22 * .61, 0, 1)
        color = color * (1 - veins[..., None]) + np.array([.37, .065, .13]) * veins[..., None]

    bevel = np.exp(-((distance - .026) * 57) ** 2)
    glint = bevel * np.maximum(0, (.69 - yy) + (.46 - xx) * .3)
    color = color * (1 + shade[..., None]) + .11 * glint[..., None]
    if mode == "pressed":
        dimple = np.exp(-((xx - .51) ** 2 * 24 + (yy - .47) ** 2 * 22))
        color *= (1 - .37 * dimple[..., None])
    if mode == "cavity":
        thickness = np.clip((distance - .027) * 20, 0, 1)
        inside = np.dstack([.08 + fine * .007, .034 + fine * .005, .147 + fine * .013])
        color = color * (1 - thickness[..., None]) * .64 + inside * thickness[..., None]
    opacity = np.clip(distance * S + .50, 0, 1)
    return rgba(color, opacity)


def make_clay():
    atlas = Image.new("RGBA", (S * 6, S * len(PALETTES)))
    for material in range(len(PALETTES)):
        for x in range(6):
            mode = ["tile", "tile", "tile", "pressed", "cavity", "crumb"][x]
            atlas.paste(clay(material, x, mode), (x * S, material * S))
    atlas.save(ROOT / "assets/clay/materials.png", optimize=True)


def cutters():
    patterns = (ROOT / "resources/shapes/patterns.gd").read_text()
    shapes = {}
    for name, rows in re.findall(r'\["([a-z0-9_]+)", [0-9], (\[[^\]]+\])\]', patterns):
        shape = [(x, y) for y, row in enumerate(json.loads(rows)) for x, cell in enumerate(row) if cell == "#"]
        seen = set()
        for rotation in range(4):
            min_x, min_y = min(x for x, _ in shape), min(y for _, y in shape)
            transformed = tuple(sorted((x - min_x, y - min_y) for x, y in shape))
            if transformed not in seen:
                shapes[f"{name}_{rotation}"] = transformed
                seen.add(transformed)
            shape = [(-y, x) for x, y in shape]

    size = 256
    cols = 7
    atlas = Image.new("RGBA", (cols * size, math.ceil(len(shapes) / cols) * size))
    catalog = {}
    for i, (key, shape) in enumerate(shapes.items()):
        w, h = max(x for x, _ in shape) + 1, max(y for _, y in shape) + 1
        unit = (size - 30) / max(w, h)
        ox, oy = (size - w * unit) / 2, (size - h * unit) / 2 - 1
        mask = np.zeros((size, size), dtype=bool)
        for x, y in shape:
            mask[round(oy + y * unit):round(oy + (y + 1) * unit),
                 round(ox + x * unit):round(ox + (x + 1) * unit)] = True
        field = distance_transform_edt(mask) - distance_transform_edt(~mask)
        smooth = gaussian_filter(field, 3.1)
        signed = smooth - 2.2
        depth = 6.4 + unit * .030
        dy, dx = np.gradient(signed)
        light = np.clip((.48 * dx + .72 * dy), -.75, .72)
        levels = np.clip(signed * .22, 0, 1)
        silver = .43 + .49 * np.exp(-((levels - .34) * 3.8) ** 2) + light * .19
        silver += np.clip((np.roll(signed, 3, axis=0) - signed) * .021, -.08, .07)
        silver += rng.random((size, size)) * .025
        rgb = np.dstack([silver * 1.07, silver * 1.00, silver * 1.13])
        rim = np.clip((signed + .8) * 1.3, 0, 1) * np.clip((depth + .6 - signed) * 1.2, 0, 1)
        shift = round(depth * .81)
        shifted = np.roll(signed, shift, axis=0)
        side = np.clip((shifted + .9) * 1.3, 0, 1) * np.clip((depth + .8 - shifted) * 1.2, 0, 1)
        side_rgb = np.dstack([silver * .43, silver * .36, silver * .49])
        metal = rgba(side_rgb, side)
        metal.alpha_composite(rgba(rgb, rim))
        ax, ay = i % cols * size, i // cols * size
        atlas.paste(metal, (ax, ay))
        catalog[key] = [ax, ay, size, size, unit]
    atlas.save(ROOT / "assets/cutters/steel.png", optimize=True)
    (ROOT / "assets/cutters/regions.json").write_text(json.dumps(catalog, indent=2) + "\n")


def sound(path, duration, tones, noise=0, sweep=0):
    rate = 22050
    t = np.arange(int(rate * duration)) / rate
    signal = np.zeros_like(t)
    for frequency, start, gain, decay in tones:
        local = np.clip(t - start, 0, None)
        env = np.minimum(local / .012, 1) * np.exp(-local * decay)
        signal += gain * env * (np.sin(2 * np.pi * (frequency * local + sweep * local ** 2))
                               + .16 * np.sin(4 * np.pi * frequency * local))
    if noise:
        hiss = gaussian_filter(rng.normal(0, 1, len(t)), 2.4)
        signal += noise * hiss * np.minimum(1, t * 165) * np.exp(-23 * t)
    signal *= np.minimum((duration - t) * 30, 1)
    with wave.open(str(path), "wb") as stream:
        stream.setparams((1, 2, rate, len(t), "NONE", "not compressed"))
        stream.writeframes(np.int16(np.clip(signal, -1, 1) * 32767).tobytes())


def audio():
    sounds = {
        "tap": (.14, [(335, 0, .33, 30)], .15, -100),
        "press": (.20, [(140, 0, .55, 20)], .42, -140),
        "stretch": (.22, [(120, 0, .27, 15), (228, .045, .19, 16)], .37, 210),
        "cut": (.21, [(170, 0, .55, 18), (660, .033, .19, 29)], .49, -180),
        "separate": (.24, [(240, .02, .29, 18), (465, .04, .19, 15)], .21, 160),
        "land": (.20, [(96, 0, .53, 24)], .3, -50),
        "refill": (.52, [(360 * i, .035 * i, .10, 9) for i in range(1, 5)], .13, 0),
        "combo": (.75, [(f, i * .061, .24, 7) for i, f in enumerate([523, 659, 784, 1046])], .08, 0),
        "best": (.98, [(f, i * .086, .25, 6) for i, f in enumerate([659, 784, 987, 1175, 1568])], .05, 0),
        "over": (.72, [(f, i * .12, .23, 8) for i, f in enumerate([349, 293, 261])], .08, 0),
    }
    destination = ROOT / "assets/audio"
    for name, (length, notes, texture, sweep) in sounds.items():
        sound(destination / (name + ".wav"), length, notes, texture, sweep)
    progression = [[130.81, 196, 261.63, 329.63], [110, 164.81, 261.63, 329.63],
                   [87.31, 130.81, 220, 261.63], [98, 146.83, 196, 293.66]]
    pitches = [(f, bar * 5.6 + i * .67, .14, .93) for bar, chord in enumerate(progression * 2)
               for i, f in enumerate(chord + chord[1:3])]
    with tempfile.TemporaryDirectory() as directory:
        wav = Path(directory) / "loop.wav"
        sound(wav, 44.8, pitches)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis",
                        "-q:a", "4", str(destination / "workshop.ogg")], check=True)


def icon():
    img = clay(0, 0)
    img = img.resize((256, 256), Image.Resampling.LANCZOS)
    cut = clay(0, 0, "cavity").resize((78, 78), Image.Resampling.LANCZOS)
    for x, y in [(50, 66), (89, 66), (128, 66), (89, 105)]:
        img.alpha_composite(cut, (x, y))
    img.save(ROOT / "assets/ui/icon.png", optimize=True)


if __name__ == "__main__":
    make_clay()
    cutters()
    audio()
    icon()
