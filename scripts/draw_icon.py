"""Draw the ShoulderCam icon in WoW's painted-icon style.

A bevelled gold camera body with a glass lens, tilted slightly, on an arcane
blue background. Drawn at 8x, then downscaled. Writes Icon.png, Icon.tga
(32-bit, bottom-left, no RLE) and Icon_preview.png (64px at 6x, 36px at 3x,
18px at 6x).
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
FINAL = 64
W = FINAL * 8
YY, XX = np.mgrid[0:W, 0:W].astype(float)


def hexrgb(h):
    return [int(h[i : i + 2], 16) for i in (1, 3, 5)]


def ramp(t, stops):
    """Multi-stop color ramp over t in [0, 1]; stops are (pos, '#rrggbb')."""
    pos = [p for p, _ in stops]
    cols = np.array([hexrgb(c) for _, c in stops], float)
    rgb = np.stack([np.interp(t, pos, cols[:, i]) for i in range(3)], -1)
    alpha = np.full(t.shape + (1,), 255.0)
    return Image.fromarray(np.concatenate([rgb, alpha], -1).astype(np.uint8), "RGBA")


def linear(stops, dx, dy, box=(0, 0, W, W)):
    x0, y0, x1, y1 = box
    t = ((XX - x0) / (x1 - x0)) * dx + ((YY - y0) / (y1 - y0)) * dy
    return ramp(np.clip(t / (abs(dx) + abs(dy)), 0, 1), stops)


def radial(stops, cx, cy, r):
    return ramp(np.clip(np.hypot(XX - cx, YY - cy) / r, 0, 1), stops)


def mask(draw_fn):
    m = Image.new("L", (W, W))
    draw_fn(ImageDraw.Draw(m))
    return m


def rrect(box, r):
    return mask(lambda d: d.rounded_rectangle(box, radius=r, fill=255))


def circle(cx, cy, r):
    return mask(lambda d: d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255))


def inset(box, n):
    return (box[0] + n, box[1] + n, box[2] - n, box[3] - n)


def paint(base, fill, m, opacity=1.0):
    """Composite fill onto base through mask m."""
    layer = fill.copy() if isinstance(fill, Image.Image) else Image.new("RGBA", (W, W), fill)
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), m.point(lambda v: int(v * opacity))))
    base.alpha_composite(layer)


# --- background: arcane blue, lit from the upper left, painterly noise ----
img = radial([(0, "#5aa0f0"), (0.45, "#2350a8"), (0.8, "#0f1f5c"), (1, "#050a22")], 190, 150, 460)
noise = Image.effect_noise((W, W), 60).filter(ImageFilter.GaussianBlur(2)).convert("RGBA")
img = Image.blend(img, noise, 0.07)
paint(img, "#9fd8ff", mask(lambda d: d.ellipse((60, 40, 440, 400))).filter(ImageFilter.GaussianBlur(70)), 0.45)

# --- camera, on its own layer so it can be tilted -------------------------
body = (56, 150, 456, 412)
bump = (148, 98, 288, 176)  # viewfinder housing on top of the body
GOLD = [(0, "#fff6c2"), (0.3, "#f0c44e"), (0.65, "#c48a26"), (1, "#7a5212")]
layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
shadow = ImageChops.lighter(rrect((body[0] + 14, body[1] + 22, body[2] + 14, body[3] + 22), 48), rrect((bump[0] + 14, bump[1] + 22, bump[2] + 14, bump[3] + 22), 24))
paint(layer, "#02040c", shadow.filter(ImageFilter.GaussianBlur(16)), 0.75)

paint(layer, linear(GOLD, 0.55, 1, bump), rrect(bump, 26))
paint(layer, linear(GOLD, 0.55, 1, body), rrect(body, 50))
paint(layer, "#3a2406", rrect(inset(body, 17), 34))  # groove inside the gold rim
paint(layer, linear([(0, "#5a4a3a"), (1, "#1c140c")], 0, 1, body), rrect(inset(body, 23), 29))

# Lens: gold ring, dark barrel, blue glass with a white glint.
LENS = (256, 284)
paint(layer, linear(GOLD, 0.55, 1, (LENS[0] - 118, LENS[1] - 118, LENS[0] + 118, LENS[1] + 118)), circle(*LENS, 118))
paint(layer, "#1a1208", circle(*LENS, 100))
paint(layer, radial([(0, "#9fe0ff"), (0.4, "#2c6cc8"), (1, "#060c24")], LENS[0] - 24, LENS[1] - 28, 110), circle(*LENS, 84))
paint(layer, "#ffffff", circle(LENS[0] - 30, LENS[1] - 32, 22).filter(ImageFilter.GaussianBlur(4)), 0.85)
paint(layer, "#ffffff", circle(LENS[0] + 34, LENS[1] + 30, 9), 0.5)

# Flash window on the body's top-right corner.
flash = (348, 186, 420, 226)
paint(layer, linear([(0, "#ffffff"), (1, "#8e98ae")], 0, 1, flash), rrect(flash, 10))

img.alpha_composite(layer.rotate(4, resample=Image.BICUBIC, center=(256, 256)))

# --- vignette, like Blizzard icons ----------------------------------------
vignette = ramp(np.clip(np.hypot(XX - W / 2, YY - W / 2) / (W * 0.72), 0, 1) ** 2.6, [(0, "#ffffff"), (1, "#707070")])
img = ImageChops.multiply(img, vignette)

icon = img.resize((FINAL, FINAL), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=0.8, percent=50, threshold=0))
icon.putalpha(255)
OUT.mkdir(parents=True, exist_ok=True)
icon.save(OUT / "Icon.png")
icon.save(OUT / "Icon.tga", orientation=-1)  # Pillow: -1 = bottom-left origin; no RLE

preview = Image.new("RGBA", (384 + 20 + 108 + 20 + 108, 384), (24, 24, 28, 255))
preview.paste(icon.resize((384, 384), Image.NEAREST), (0, 0))
preview.paste(icon.resize((36, 36), Image.LANCZOS).resize((108, 108), Image.NEAREST), (404, 0))
preview.paste(icon.resize((18, 18), Image.LANCZOS).resize((108, 108), Image.NEAREST), (532, 0))
preview.save(OUT / "Icon_preview.png")
