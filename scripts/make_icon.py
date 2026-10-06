"""Build the in-game icon from the source art.

Downscales .github/assets/shoulder-cam.png to Media/Icon.tga: 64x64, 32-bit,
bottom-left origin, no RLE (the format every WoW flavor loads).
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / ".github" / "assets" / "shoulder-cam.png"
TARGET = ROOT / "Media" / "Icon.tga"
SIZE = 64

image = Image.open(SOURCE).convert("RGBA")
side = max(image.size)
square = Image.new("RGBA", (side, side))
square.paste(image, ((side - image.width) // 2, (side - image.height) // 2))
square.resize((SIZE, SIZE), Image.LANCZOS).save(TARGET, rle=False, orientation=-1)
