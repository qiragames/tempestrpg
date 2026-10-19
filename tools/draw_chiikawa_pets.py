"""Draws the Chiikawa pets (user request) in the pets' style: two 16 x 16 frames (standing and a
hop) with a dark outline, plus a 38 x 38 face for the pets window. Fan art of Chiikawa, Hachiware
and Usagi (characters by Nagano); the user's private, non-commercial game.

Run: python -I tools/draw_chiikawa_pets.py  (writes assets/game/sprites/pets/pet_<id>[_face].png)
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "game" / "sprites" / "pets"
INK = (42, 34, 48, 255)
BLUSH = (244, 150, 168, 255)
EYE = (30, 24, 34, 255)
FACE_BG = (20, 26, 26, 255)

PETS = {
    "chiikawa": {"base": (250, 248, 244, 255), "shade": (222, 216, 214, 255), "ears": "round"},
    "hachiware": {"base": (250, 250, 252, 255), "shade": (220, 222, 230, 255), "ears": "cat", "cap": (58, 76, 128, 255)},
    "usagi": {"base": (250, 232, 160, 255), "shade": (226, 200, 120, 255), "ears": "rabbit"},
}


def body_mask(hop: bool):
    cx, cy, rx, ry = (8.0, 10.0, 5.9, 4.6) if hop else (8.0, 9.5, 5.4, 5.0)
    mask = set()
    for y in range(16):
        for x in range(16):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                mask.add((x, y))
    # Little feet.
    bottom = max(y for _, y in mask)
    for x in (5, 6, 9, 10):
        if bottom + 1 < 16 and not hop:
            mask.add((x, bottom + 1))
    return mask, cx, cy, rx, ry


def ears(kind: str, cy: float, ry: float):
    top = int(cy - ry)
    cells = set()
    if kind == "round":
        for ex in (4, 11):
            for dx in (-1, 0, 1):
                for dy in (-1, 0):
                    if abs(dx) + abs(dy) <= 1 or dy == 0:
                        cells.add((ex + dx, top + dy))
    elif kind == "cat":
        cells |= {(4, top - 2), (3, top - 1), (4, top - 1), (3, top), (4, top), (5, top)}
        cells |= {(11, top - 2), (11, top - 1), (12, top - 1), (10, top), (11, top), (12, top)}
    elif kind == "rabbit":
        for ex in (5, 10):
            for y in range(max(0, top - 5), top + 1):
                cells.add((ex, y))
                cells.add((ex + 1, y))
    return cells


def frame(pet: str, hop: bool) -> Image.Image:
    spec = PETS[pet]
    mask, cx, cy, rx, ry = body_mask(hop)
    ear_cells = ears(spec["ears"], cy, ry)
    shape = mask | ear_cells
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = image.load()
    for (x, y) in shape:
        if 0 <= x < 16 and 0 <= y < 16:
            colour = spec["base"]
            # Soft shade on the lower right.
            if (x, y) in mask and x + 0.5 > cx + rx * 0.45 and y + 0.5 > cy + ry * 0.2:
                colour = spec["shade"]
            px[x, y] = colour
    # Hachiware's blue cap with the white split down the middle, and blue ears.
    if pet == "hachiware":
        for (x, y) in shape:
            if 0 <= x < 16 and 0 <= y < 16 and y + 0.5 < cy - 0.5:
                gap = (y + 0.5 - (cy - ry)) * 0.75
                if abs(x + 0.5 - cx) > gap or (x, y) in ear_cells:
                    px[x, y] = spec["cap"]
    # Rabbit ears: a pink inside line.
    if pet == "usagi":
        for (x, y) in ear_cells:
            if x in (6, 10) and y < int(cy - ry) - 1:
                px[x, y] = BLUSH
    # Outline.
    for y in range(16):
        for x in range(16):
            if (x, y) in shape:
                continue
            if any((x + dx, y + dy) in shape for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = INK
    # Face: dot eyes, blush, a tiny mouth (Usagi's is a little open).
    eye_y = int(cy + (0.5 if hop else 0.0))
    for ex in (6, 10):
        px[ex, eye_y] = EYE
    for bx in (5, 11):
        px[bx, eye_y + 1] = BLUSH
    px[8, eye_y + 1] = EYE if pet != "usagi" else (190, 70, 80, 255)
    return image


def face(pet: str) -> Image.Image:
    image = Image.new("RGBA", (38, 38), FACE_BG)
    big = frame(pet, False).resize((32, 32), Image.NEAREST)
    image.paste(big, (3, 5), big)
    return image


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for pet in PETS:
        sheet = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
        sheet.paste(frame(pet, False), (0, 0))
        sheet.paste(frame(pet, True), (16, 0))
        sheet.save(OUT / f"pet_{pet}.png")
        face(pet).save(OUT / f"pet_{pet}_face.png")
        print("wrote", pet)


if __name__ == "__main__":
    main()
