"""Builds the Demon player sheets from the Human ones (user feedback 2026-10-22: the old demon looked
like a heart). Same frames and animations as the Human, recoloured (crimson skin, black-violet hair,
violet robes, glowing eyes) with curved bone horns on the head.

    python -I tools/make_demon_sprites.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/game/sprites/player_human"
TARGET = ROOT / "assets/game/sprites/player_demon"

# Human colour -> demon colour.
RECOLOUR = {
    (0xd1, 0x4b, 0x34): (0x24, 0x1d, 0x33),  # hair -> black
    (0x96, 0x53, 0x40): (0x8a, 0x24, 0x40),  # shade -> dark crimson
    (0xef, 0x91, 0x4f): (0xd2, 0x3f, 0x50),  # skin -> crimson
    (0xe3, 0xf1, 0xf5): (0x63, 0x3f, 0x96),  # shirt -> violet robe
    (0x54, 0x87, 0x89): (0x2c, 0x1f, 0x42),  # trousers -> dark violet
    (0xd3, 0xa2, 0xc0): (0xff, 0x7a, 0x5c),  # blush -> ember
}
HORN = (0xf2, 0xe6, 0xc8, 255)
HORN_SHADE = (0xb9, 0xa4, 0x7e, 255)
OUTLINE = (0x14, 0x1b, 0x1b, 255)
FRAME = 16


def recolour(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            if a and (r, g, b) in RECOLOUR:
                pixels[x, y] = RECOLOUR[(r, g, b)] + (a,)
    return out


def _opaque(pixels, x, y, box):
    left, top, right, bottom = box
    return left <= x < right and top <= y < bottom and pixels[x, y][3] > 0


def _put(pixels, x, y, colour, box, scale, only_empty=False):
    left, top, right, bottom = box
    for dy in range(scale):
        for dx in range(scale):
            px, py = x + dx, y + dy
            if left <= px < right and top <= py < bottom and (not only_empty or pixels[px, py][3] == 0):
                pixels[px, py] = colour


def add_horns(image: Image.Image, frame: int, scale: int = 1) -> None:
    """Two curved bone horns on each frame's head: the base through the head's top edge, rising
    and bending outward where there is room, outlined against the background."""
    pixels = image.load()
    for fy in range(0, image.height, frame):
        for fx in range(0, image.width, frame):
            box = (fx, fy, fx + frame, fy + frame)
            top = next((y for y in range(fy, fy + frame) if any(_opaque(pixels, x, y, box) for x in range(fx, fx + frame))), None)
            if top is None:
                continue
            row = min(top + 2 * scale, fy + frame - 1)
            xs = [x for x in range(fx, fx + frame) if _opaque(pixels, x, row, box)]
            if len(xs) < 6 * scale:
                continue
            left, right = xs[0], xs[-1]
            for x, outward in ((left + 2 * scale, -1), (right - 3 * scale + 1, 1)):
                # Base (two wide) on the head, then up and out.
                path = [(0, 1, HORN_SHADE), (1, 1, HORN_SHADE), (0, 0, HORN), (1, 0, HORN), (0, -1, HORN), (outward, -2, HORN)]
                for dx, dy, colour in path:
                    _put(pixels, x + dx * scale, top + dy * scale, colour, box, scale)
                for dx, dy, colour in path:
                    if dy < 0:
                        for ox, oy in ((-1, 0), (1, 0), (0, -1)):
                            _put(pixels, x + (dx + ox) * scale, top + (dy + oy) * scale, OUTLINE, box, scale, only_empty=True)


EYE = (0xff, 0xd2, 0x3f, 255)


def glowing_eyes(source: Image.Image, image: Image.Image, frame: int, head_rows: int) -> None:
    """The Human's eye whites (light pixels in the head) glow yellow; the same colour lower down is
    the shirt and stays a robe."""
    original = source.convert("RGBA").load()
    pixels = image.load()
    for y in range(image.height):
        if y % frame >= head_rows:
            continue
        for x in range(image.width):
            if original[x, y][3] and original[x, y][:3] in ((0xe3, 0xf1, 0xf5), (0xf2, 0xea, 0xf1)):
                pixels[x, y] = EYE


def main() -> None:
    for name in ["idle", "walk", "attack", "dead"]:
        source = Image.open(SOURCE / f"human_{name}.png")
        image = recolour(source)
        if name != "dead":
            glowing_eyes(source, image, FRAME, 11)
            add_horns(image, FRAME)
        image.save(TARGET / f"demon_{name}.png")
    face = recolour(Image.open(SOURCE / "human_faceset.png"))
    add_horns(face, face.width, 2)
    face.save(TARGET / "demon_faceset.png")
    print("demon sheets written to", TARGET)


if __name__ == "__main__":
    main()
