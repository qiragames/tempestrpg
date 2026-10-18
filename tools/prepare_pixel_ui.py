"""M13 pixel UI: slice the Dogobongocat UI sheet (CC0, assets/source/packs/dogobongocat_ui/UI.png)
into the pieces in assets/game/ui/pixel/ that scripts/ui/ui_style.gd uses. Run from the repository root:
    python -I tools/prepare_pixel_ui.py
"""
import os
from PIL import Image

OUT = "assets/game/ui/pixel"
os.makedirs(OUT, exist_ok=True)
UI = Image.open("assets/source/packs/dogobongocat_ui/UI.png").convert("RGBA")
PIECES = {
    "panel_navy": (209, 18, 46, 45),
    "panel_navy_flat": (145, 17, 46, 46),
    "panel_paper": (209, 82, 46, 45),
    "plate_navy": (145, 65, 46, 14),
    "plate_paper": (145, 129, 46, 14),
    "slot": (16, 240, 16, 16),
    "slot_grey": (32, 240, 16, 16),
    "slot_light": (48, 240, 16, 16),
    "bar_red": (769, 18, 46, 12),
    "bar_red_empty": (769, 34, 46, 12),
    "bar_blue": (769, 50, 46, 12),
    "bar_blue_empty": (769, 66, 46, 12),
    "bar_thin_gold": (512, 276, 64, 8),
    "bar_thin_navy": (512, 292, 64, 8),
    "portrait_ring": (530, 145, 29, 30),
    "divider": (611, 177, 74, 14),
    "clock_dawn": (1056, 16, 48, 48),
    "clock_day": (1104, 16, 48, 48),
    "clock_dusk": (1152, 16, 48, 48),
    "clock_evening": (1056, 64, 48, 48),
    "clock_night": (1104, 64, 48, 48),
    "clock_midnight": (1152, 64, 48, 48),
}
for name, (x, y, w, h) in PIECES.items():
    UI.crop((x, y, x + w, y + h)).save(os.path.join(OUT, name + ".png"))
# A bright blue Magicules bar: the red bar with its reds swapped for blues (the pack's own blue
# bar is a dark navy that reads as empty).
SWAP = {(181, 89, 69): (79, 134, 198), (115, 76, 68): (52, 82, 130), (165, 120, 85): (128, 176, 224)}
red = Image.open(os.path.join(OUT, "bar_red.png")).convert("RGBA")
blue = red.copy()
pixels = blue.load()
for y in range(blue.height):
    for x in range(blue.width):
        r, g, b, a = pixels[x, y]
        if (r, g, b) in SWAP:
            pixels[x, y] = SWAP[(r, g, b)] + (a,)
blue.save(os.path.join(OUT, "bar_magic.png"))
print(len(PIECES) + 1, "pieces")
