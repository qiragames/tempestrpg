"""Prepare the extra world sheets for the M4.5 archipelago (run from the repository root).

- assets/game/world/ruins.png   copy of Ninja Adventure TilesetVillageAbandoned.png (CC0)
- assets/game/world/desert.png  copy of Ninja Adventure TilesetDesert.png (CC0)
- assets/game/world/lava.png    derived from water.png rows 0-5 (the sand-shore set): water
  recoloured to glowing lava, sand to volcanic ash. Same tile layout, so the same corner
  lookup works for lava pools on the Emberreach islets. (CC0 source; derived work is ours.)
- assets/game/world/terrain_field.png gains rows 15-17 (M4.5c): a murky mud patch for Mirewood
  Marsh, recoloured from the forest patch (rows 6-8) with the same layout. Idempotent: the
  sheet is cut back to its 15 original rows first.
"""
from pathlib import Path
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
NINJA = ROOT / "assets/source/packs/ninja_adventure/Backgrounds/Tilesets"
WORLD = ROOT / "assets/game/world"


def lava_color(pixel):
    r, g, b, a = pixel
    if a == 0:
        return pixel
    light = (r * 299 + g * 587 + b * 114) / 1000
    if b > r + 30:  # water -> lava, brighter water = hotter lava
        t = max(0.0, min(1.0, (light - 120) / 110))
        return (int(200 + 55 * t), int(60 + 110 * t), int(30 + 30 * t), a)
    if r > 240 and g > 240 and b > 240:  # foam -> glowing rim
        return (255, 214, 120, a)
    # sand and its rim -> ash, keeping the shading
    t = max(0.0, min(1.0, light / 255))
    grey = int(48 + 90 * t)
    return (grey, int(grey * 0.92), int(grey * 0.95), a)


def mud_color(pixel):
    r, g, b, a = pixel
    if a == 0:
        return pixel
    light = (r * 299 + g * 587 + b * 114) / 1000 / 255
    return (int(58 + 70 * light), int(52 + 62 * light), int(30 + 34 * light), a)


def tone(low, high):
    def color(pixel):
        r, g, b, a = pixel
        if a == 0:
            return pixel
        light = (r * 299 + g * 587 + b * 114) / 1000 / 255
        light = max(0.0, min(1.0, (light - 0.55) / 0.45))
        return tuple(int(low[i] + (high[i] - low[i]) * light) for i in range(3)) + (a,)
    return color


def recolour(patch, color):
    out = Image.new("RGBA", patch.size)
    out.putdata([color(p) for p in patch.getdata()])
    return out


def add_mud():
    field = Image.open(WORLD / "terrain_field.png").convert("RGBA")
    base = field.crop((0, 0, 80, 240))
    out = Image.new("RGBA", (80, 384))
    out.paste(base, (0, 0))
    out.paste(recolour(base.crop((0, 96, 80, 144)), mud_color), (0, 240))
    snow = base.crop((0, 192, 80, 240))
    out.paste(recolour(snow, tone((176, 128, 70), (246, 214, 150))), (0, 288))
    out.paste(recolour(snow, tone((52, 46, 50), (132, 122, 126))), (0, 336))
    out.save(WORLD / "terrain_field.png")


PATH_GROUNDS = [
    ((214, 170, 110), (246, 214, 150)),  # sand
    ((186, 196, 214), (246, 248, 252)),  # snow
    ((214, 132, 154), (250, 192, 206)),  # blossom
    ((66, 60, 36), (122, 114, 72)),      # mud
    ((76, 70, 74), (142, 132, 136)),     # ash
    ((198, 116, 56), (246, 170, 100)),   # autumn
]


def add_paths():
    floor = Image.open(WORLD / "terrain_floor.png").convert("RGBA")
    dirt = floor.crop((0, 112, 160, 208))
    out = Image.new("RGBA", (160, 96 * (1 + len(PATH_GROUNDS))))
    out.paste(dirt, (0, 0))
    for index, (low, high) in enumerate(PATH_GROUNDS):
        def fringe(pixel, low=low, high=high):
            r, g, b, a = pixel
            if a == 0 or r - g >= 30:
                return pixel
            light = max(0.0, min(1.0, ((r * 299 + g * 587 + b * 114) / 1000 / 255 - 0.35) / 0.4))
            return tuple(int(low[i] + (high[i] - low[i]) * light) for i in range(3)) + (a,)
        out.paste(recolour(dirt, fringe), (0, 96 * (index + 1)))
    out.save(WORLD / "paths.png")


def main():
    shutil.copyfile(NINJA / "TilesetVillageAbandoned.png", WORLD / "ruins.png")
    shutil.copyfile(NINJA / "TilesetDesert.png", WORLD / "desert.png")
    shutil.copyfile(NINJA / "TilesetReliefDetail.png", WORLD / "relief_detail.png")
    water = Image.open(WORLD / "water.png").convert("RGBA").crop((0, 0, 448, 96))
    lava = Image.new("RGBA", water.size)
    lava.putdata([lava_color(p) for p in water.getdata()])
    lava.save(WORLD / "lava.png")
    add_mud()
    add_paths()
    print("wrote ruins.png, desert.png, lava.png, terrain_field.png (mud rows)")


if __name__ == "__main__":
    main()
