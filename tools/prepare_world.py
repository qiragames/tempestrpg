"""Prepare the extra world sheets for the M4.5 archipelago (run from the repository root).

- assets/game/world/ruins.png   copy of Ninja Adventure TilesetVillageAbandoned.png (CC0)
- assets/game/world/desert.png  copy of Ninja Adventure TilesetDesert.png (CC0)
- assets/game/world/lava.png    derived from water.png rows 0-5 (the sand-shore set): water
  recoloured to glowing lava, sand to volcanic ash. Same tile layout, so the same corner
  lookup works for lava pools on the Emberreach islets. (CC0 source; derived work is ours.)
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


def main():
    shutil.copyfile(NINJA / "TilesetVillageAbandoned.png", WORLD / "ruins.png")
    shutil.copyfile(NINJA / "TilesetDesert.png", WORLD / "desert.png")
    water = Image.open(WORLD / "water.png").convert("RGBA").crop((0, 0, 448, 96))
    lava = Image.new("RGBA", water.size)
    lava.putdata([lava_color(p) for p in water.getdata()])
    lava.save(WORLD / "lava.png")
    print("wrote ruins.png, desert.png, lava.png")


if __name__ == "__main__":
    main()
