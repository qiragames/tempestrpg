"""M13: small fixes to the pixel fonts in assets/game/fonts/ (needs fontTools; run once, from the
repository root, with `python -P tools/patch_fonts.py`; running it again changes nothing).
- m3x6: the middle dot sat at cap height; it moves to the middle like m5x7's.
- m5x7 and m3x6 have no en/em dash; both are mapped to the hyphen (the engine font's long dash
  looked out of place in pixel text).
- Toasty has no middle dot: a borrowed one came from another font with a taller line and pushed
  the whole heading down; it gets its own (its period, raised to the hyphen's height), and the
  dashes map to its hyphen."""
import copy
from fontTools.ttLib import TTFont

PIXEL = 64  # font units per pixel (unitsPerEm 1024 at the native size 16)

for name in ("m3x6", "m5x7"):
    path = f"assets/game/fonts/{name}.ttf"
    font = TTFont(path)
    glyf = font["glyf"]
    if name == "m3x6":
        dot = glyf["periodcentered"]
        dot.recalcBounds(glyf)
        shift = dot.yMin - 2 * PIXEL
        if shift:
            coords = dot.coordinates
            for index in range(len(coords)):
                x, y = coords[index]
                coords[index] = (x, y - shift)
            dot.recalcBounds(glyf)
    for table in font["cmap"].tables:
        if table.isUnicode():
            for code in (0x2013, 0x2014):
                table.cmap.setdefault(code, "hyphen")
    font.save(path)
    print("patched", path)

path = "assets/game/fonts/toasty.ttf"
font = TTFont(path)
glyf = font["glyf"]
if "periodcentered" not in glyf.keys():
    dot = copy.deepcopy(glyf["period"])
    dot.recalcBounds(glyf)
    hyphen = glyf["hyphen"]
    hyphen.recalcBounds(glyf)
    coords = dot.coordinates
    for index in range(len(coords)):
        x, y = coords[index]
        coords[index] = (x, y + hyphen.yMin - dot.yMin)
    order = font.getGlyphOrder()
    font.setGlyphOrder(order + ["periodcentered"])
    glyf.glyphs["periodcentered"] = dot
    glyf.glyphOrder = font.getGlyphOrder()
    font["hmtx"].metrics["periodcentered"] = font["hmtx"].metrics["period"]
    font["maxp"].numGlyphs = len(font.getGlyphOrder())
for table in font["cmap"].tables:
    if table.isUnicode():
        table.cmap.setdefault(0xB7, "periodcentered")
        for code in (0x2013, 0x2014):
            table.cmap.setdefault(code, "hyphen")
font.save(path)
print("patched", path)
