"""Icons for the v1.7 fused skills: each is its two parts' icons joined along the diagonal (the
first part top left, the second bottom right) with a cyan seam, the colour of Extra skills.

    python -I tools/make_fusion_icons.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ICONS = ROOT / "assets/game/ui/skills"
FUSIONS = {
    "permafrost_maul": ("frost_maul", "chill_touch"),
    "venom_sandstorm": ("venom_fang", "sand_burst"),
    "rot_bloom": ("mire_grasp", "spore_cloud"),
    "lantern_lance": ("bamboo_thrust", "lantern_flare"),
    "sky_dive": ("gale_wing", "burrow_strike"),
    "magma_eruption": ("ember_burst", "magma_bite"),
}
SEAM = (111, 208, 255, 255)


def main() -> None:
    for fused, (first, second) in FUSIONS.items():
        a = Image.open(ICONS / f"{first}.png").convert("RGBA")
        b = Image.open(ICONS / f"{second}.png").convert("RGBA").resize(a.size, Image.NEAREST)
        size = a.width
        out = Image.new("RGBA", a.size)
        for y in range(size):
            for x in range(size):
                diagonal = x + y - (size - 1)
                source = a if diagonal < 0 else b
                pixel = source.getpixel((x, y))
                if diagonal == 0 and pixel[3] > 0:
                    pixel = SEAM
                out.putpixel((x, y), pixel)
        out.save(ICONS / f"{fused}.png")
    print("fusion icons written:", ", ".join(FUSIONS))


if __name__ == "__main__":
    main()
