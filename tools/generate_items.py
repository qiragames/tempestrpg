"""Item expansion (user request): hundreds of weapons and armour pieces in six rarities.

Looks come from three CC0 icon packs (7Soul's 496 RPG icons, Idylwild's Arsenal and Armory, the
Super Epic Weapons pack) plus scythes drawn from parts here. Every source icon gets colour
variants in material and element palettes, so one hand-drawn icon yields several distinct items.
Writes:
  assets/game/ui/items/<group>.png           32x32 icon atlases (16 columns)
  scripts/items/item_bases.gd                the generated catalogue (names, slots, elements,
                                             levels, minimum rarity, stat ranges, icon cells)
  docs/asset_previews/items_<group>.png      preview sheets (4x)
Deterministic: the same packs always give the same catalogue (item IDs stay stable).
Run: python -I tools/generate_items.py
"""
import colorsys
import hashlib
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACKS = ROOT / "assets/source/packs"
OUT = ROOT / "assets/game/ui/items"
PREVIEW = ROOT / "docs/asset_previews"
CELL = 32
COLUMNS = 16

# --- Palettes: (dark, mid, light) per material or element; elements also have an accent.
PALETTES = {
    "iron": None,
    "bronze": ("5a3a1a", "a8692c", "f0bb78"),
    "gold": ("6e4a0e", "d4a020", "fff2a8"),
    "obsidian": ("150f20", "3c3156", "9488bc"),
    "mithril": ("23455a", "78c2da", "ecfcff"),
    "bone": ("5a4f3a", "c8b890", "f6efdc"),
    "fire": ("5a1408", "e0501a", "ffd070"),
    "frost": ("1a3a6a", "6ab8f0", "f0ffff"),
    "storm": ("2a2060", "8a70e0", "fff6a0"),
    "shadow": ("140a1e", "4c2c6e", "a874d8"),
    "holy": ("6a5a2a", "f0d890", "ffffff"),
    "nature": ("1e3a14", "5aa83a", "dcf4a4"),
    "blood": ("3a0610", "a8182c", "ff7484"),
    "arcane": ("2a0a4a", "b040d0", "f8ccff"),
}
ACCENTS = {"fire": "ff8030", "frost": "a8ecff", "storm": "ffe14a", "shadow": "c060ff", "holy": "fff2a0",
           "nature": "8fe05a", "blood": "ff3050", "arcane": "ff60f0"}
ELEMENTS = ["fire", "frost", "storm", "shadow", "holy", "nature", "blood", "arcane"]
MATERIALS = ["bronze", "gold", "obsidian", "mithril", "bone"]

# --- Names
ELEMENT_WORDS = {
    "fire": ["Ember", "Cinder", "Blaze", "Pyre", "Inferno", "Scorch", "Magma", "Flame", "Ash", "Sunfire"],
    "frost": ["Frost", "Rime", "Glacier", "Hoarfrost", "Winter", "Ice", "Snowfall", "Frostbite", "Sleet", "Boreal"],
    "storm": ["Storm", "Thunder", "Tempest", "Volt", "Gale", "Lightning", "Squall", "Skyfire", "Thunderclap", "Cyclone"],
    "shadow": ["Shadow", "Dusk", "Umbral", "Night", "Void", "Gloom", "Eclipse", "Nightfall", "Shade", "Abyssal"],
    "holy": ["Dawn", "Radiant", "Sun", "Sacred", "Halo", "Lumen", "Seraph", "Blessed", "Daybreak", "Aurora"],
    "nature": ["Thorn", "Verdant", "Briar", "Grove", "Wild", "Moss", "Bramble", "Oakheart", "Sylvan", "Fern"],
    "blood": ["Blood", "Crimson", "Sanguine", "Vein", "Gore", "Scarlet", "Bloodmoon", "Ruby", "Carmine", "Heartseeker"],
    "arcane": ["Arcane", "Mystic", "Rune", "Astral", "Star", "Ether", "Spell", "Moonlit", "Prism", "Nova"],
}
MATERIAL_WORDS = {"iron": ["Iron", "Steel", "Soldier's", "Knight's", "Warden's", "Ranger's", "Militia", "Veteran's", "Captain's", "Squire's", "Traveler's", "Hunter's", "Sentinel's", "Guard's", "Mercenary's"],
                  "bronze": ["Bronze", "Copper", "Brass"], "gold": ["Gilded", "Golden", "Royal"],
                  "obsidian": ["Obsidian", "Blackened", "Onyx"], "mithril": ["Mithril", "Silvered", "Moonsteel"],
                  "bone": ["Bone", "Ivory", "Fossil"]}
NOUNS = {
    "sword": ["Blade", "Sword", "Saber", "Brand", "Edge", "Longsword", "Claymore", "Falchion", "Broadsword", "Cutlass", "Scimitar", "Gladius"],
    "dagger": ["Dagger", "Dirk", "Stiletto", "Fang", "Shiv", "Kris", "Kukri", "Knife", "Talon", "Sting", "Rondel", "Misericorde"],
    "spear": ["Spear", "Lance", "Pike", "Glaive", "Halberd", "Partisan", "Trident", "Javelin", "Spike", "Ranseur"],
    "scythe": ["Scythe", "Reaper", "Sickle", "Harvester", "Crescent", "Grim", "Thresher", "Cutter"],
    "bow": ["Bow", "Longbow", "Recurve", "Shortbow", "Warbow", "Greatbow", "Crossbow", "Arbalest", "Flatbow", "Stringer"],
    "staff": ["Staff", "Wand", "Rod", "Scepter", "Stave", "Crook", "Focus", "Spire", "Cane", "Branch"],
    "fist": ["Knuckles", "Claws", "Cestus", "Fists", "Talons", "Handwraps", "Knucklebands", "Grips"],
    "head": ["Helm", "Hood", "Cap", "Coif", "Crown", "Visor", "Circlet", "Mask", "Greathelm", "Cowl"],
    "body": ["Mail", "Cuirass", "Robe", "Jerkin", "Hauberk", "Plate", "Vestment", "Brigandine", "Tunic", "Coat"],
    "hands": ["Gloves", "Gauntlets", "Bracers", "Grips", "Handwraps", "Vambraces", "Mitts", "Fists"],
    "feet": ["Boots", "Greaves", "Sabatons", "Treads", "Striders", "Shoes", "Sandals", "Walkers"],
    "ring": ["Ring", "Band", "Loop", "Signet", "Seal", "Coil"],
    "amulet": ["Amulet", "Pendant", "Talisman", "Locket", "Medallion", "Charm", "Torc", "Sigil"],
}
EPIC_THEMES = ["fire", "frost", "nature", "holy", "shadow"]
# Sets (part 3): one per element, five pieces (head, body, hands, feet, amulet), Epic and up.
SETS = {
    "fire": ("emberlord", "Emberlord's"), "frost": ("rimewarden", "Rimewarden's"), "storm": ("stormcaller", "Stormcaller's"),
    "shadow": ("nightstalker", "Nightstalker's"), "holy": ("dawnguard", "Dawnguard"), "nature": ("wildheart", "Wildheart"),
    "blood": ("bloodbound", "Bloodbound"), "arcane": ("starweaver", "Starweaver's"),
}
SET_SLOTS = [("head", "metal"), ("body", "metal"), ("hands", "metal"), ("feet", "metal"), ("amulet", "amulet")]
# Uniques (part 3): hand-named Legendary (4) / Mythic (5) pieces with their own ability, drawn from
# the packs' finest icons in their element's colours with a glowing outline.
# [name, group, source (pack, file), element, min rarity, ability]
UNIQUES = [
    ["Dawnbreaker", "sword", ("7soul", "W_Sword016.png"), "holy", 5, "radiance"],
    ["Cinderheart", "sword", ("7soul", "W_Sword015.png"), "fire", 4, "inferno"],
    ["Kingsbane", "sword", ("7soul", "W_Sword019.png"), "shadow", 4, "executioner"],
    ["Whisperfang", "dagger", ("7soul", "W_Dagger021.png"), "shadow", 4, "executioner"],
    ["Viperkiss", "dagger", ("7soul", "W_Dagger019.png"), "nature", 4, "overgrowth"],
    ["Heartpiercer", "dagger", ("7soul", "W_Dagger020.png"), "blood", 5, "bloodthirst"],
    ["Skyrender", "bow", ("7soul", "W_Bow16.png"), "storm", 5, "thunderlord"],
    ["Frostwind", "bow", ("7soul", "W_Bow14.png"), "frost", 4, "glacier"],
    ["Starfall Longbow", "bow", ("7soul", "W_Bow15.png"), "arcane", 4, "starfall"],
    ["Stormpiercer", "spear", ("7soul", "W_Spear014.png"), "storm", 4, "thunderlord"],
    ["Sunlance", "spear", ("7soul", "W_Spear013.png"), "holy", 4, "radiance"],
    ["Glacier's Edge", "spear", ("7soul", "W_Spear012.png"), "frost", 5, "glacier"],
    ["Soulreaper", "scythe", ("arsenal", "scythe2.png"), "shadow", 5, "eclipse"],
    ["Harvest Moon", "scythe", ("arsenal", "scythe1.png"), "arcane", 4, "starfall"],
    ["Thornreaver", "scythe", ("drawn", 7), "nature", 4, "overgrowth"],
    ["Crown of the Tempest", "head", ("7soul", "C_Elm04.png"), "storm", 4, "windwalker"],
    ["Phoenix Plate", "body", ("armory", "platemail"), "fire", 5, "phoenix"],
    ["Wardenshell", "body", ("armory", "breastplate"), "frost", 4, "warden"],
    ["Berserker's Grips", "hands", ("armory", "gauntlets"), "blood", 4, "berserker"],
    ["Windrunner Boots", "feet", ("armory", "studded_boots"), "storm", 4, "windwalker"],
    ["Heart of the Phoenix", "amulet", ("7soul", "Ac_Necklace08.png"), "fire", 5, "phoenix"],
    ["Band of Fury", "ring", ("armory", "gold_ring"), "blood", 4, "berserker"],
    ["Seal of the Warden", "ring", ("armory", "silver_ring"), "holy", 4, "warden"],
]
# M12c: uniques of the two new weapon types.
CLASS_UNIQUES = [
    ["Starweaver's Staff", "staff", ("7soul", "W_Staff08.png"), "arcane", 5, "starfall"],
    ["Emberwand", "staff", ("arsenal", "wand2.png"), "fire", 4, "inferno"],
    ["Frostbinder Rod", "staff", ("7soul", "W_Staff05.png"), "frost", 4, "glacier"],
    ["Dragon's Grip", "fist", ("7soul", "W_Fist005.png"), "fire", 5, "inferno"],
    ["Thunder Knuckles", "fist", ("7soul", "W_Fist003.png"), "storm", 4, "thunderlord"],
    ["Bloodfist Claws", "fist", ("7soul", "W_Fist004.png"), "blood", 4, "bloodthirst"],
]
UNIQUE_ARCHETYPE = {"head": "metal", "body": "metal", "hands": "metal", "feet": "leather", "ring": "ring", "amulet": "amulet"}
EPIC_WORDS = {"fire": "Dragonfire", "frost": "Glacial", "nature": "Wildwood", "holy": "Sunforged", "shadow": "Nightshade"}

# --- Stats
WEAPON_DAMAGE = {"dagger": (8, 11), "sword": (12, 15), "spear": (13, 17), "scythe": (15, 20), "bow": (9, 12),
                 # M12c: the Mage's staff (a free magic bolt) and the Monk's fist weapons (very fast).
                 "staff": (11, 14), "fist": (7, 9)}
# Armour archetypes: stat → [low, high] at level 1.
ARMOUR = {
    "head": {"cloth": {"hp": (3, 6), "magicules": (3, 6)}, "leather": {"hp": (5, 8), "speed": (1, 3)}, "metal": {"hp": (6, 10), "defense": (1, 2)}},
    "body": {"cloth": {"hp": (6, 10), "regen": (0.2, 0.4)}, "leather": {"hp": (8, 13), "speed": (1, 3)}, "metal": {"hp": (10, 16), "defense": (1, 3), "speed": (-6, -3)}},
    "hands": {"cloth": {"magicules": (4, 8)}, "leather": {"strike": (1, 2)}, "metal": {"strike": (1, 2), "defense": (1, 1)}},
    "feet": {"cloth": {"speed": (3, 6)}, "leather": {"speed": (2, 5), "hp": (2, 4)}, "metal": {"hp": (4, 7), "defense": (1, 2)}},
    "ring": {"ring": {"magicules": (5, 10)}},
    "amulet": {"amulet": {"regen": (0.2, 0.5)}},
}
# Elements add a themed stat to armour.
ELEMENT_STAT = {"fire": ("strike", (1, 2)), "frost": ("defense", (1, 1)), "storm": ("speed", (2, 4)), "shadow": ("speed", (1, 3)),
                "holy": ("hp", (4, 8)), "nature": ("regen", (0.1, 0.3)), "blood": ("hp", (5, 9)), "arcane": ("magicules", (5, 9))}


def hexcolor(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def gradient(palette, v):
    dark, mid, light = (hexcolor(c) for c in palette)
    return lerp(dark, mid, v / 0.55) if v < 0.55 else lerp(mid, light, (v - 0.55) / 0.45)


def fit(image):
    """Trim to the drawn pixels and centre on a 32x32 cell (icons are 32 or 34 px)."""
    image = image.convert("RGBA")
    box = image.getbbox()
    if box is None:
        return Image.new("RGBA", (CELL, CELL))
    image = image.crop(box)
    if image.width > CELL or image.height > CELL:
        scale = CELL / max(image.width, image.height)
        image = image.resize((max(1, int(image.width * scale)), max(1, int(image.height * scale))), Image.NEAREST)
    cell = Image.new("RGBA", (CELL, CELL))
    cell.paste(image, ((CELL - image.width) // 2, (CELL - image.height) // 2), image)
    return cell


def recolour(image, palette_name, metal_only):
    """Recolour metal (greys) — and for armour every coloured part — into a palette; gems take the
    element's accent; outlines stay."""
    palette = PALETTES[palette_name]
    if palette is None:
        return image.copy()
    accent = hexcolor(ACCENTS[palette_name]) if palette_name in ACCENTS else None
    out = image.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if v < 0.2:
                continue
            gem = s > 0.55 and v > 0.55 and not (0.04 < h < 0.13)
            if gem and accent is not None:
                shade = lerp((0, 0, 0), accent, 0.55 + 0.45 * v)
                pixels[x, y] = shade + (a,)
            elif s < 0.28 or not metal_only:
                pixels[x, y] = gradient(palette, v) + (a,)
    return out


def outline(image, colour=(24, 18, 28, 255)):
    out = image.copy()
    src = image.load()
    dst = out.load()
    for y in range(image.height):
        for x in range(image.width):
            if src[x, y][3] == 0 and any(0 <= x + dx < image.width and 0 <= y + dy < image.height and src[x + dx, y + dy][3] > 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                dst[x, y] = colour
    return out


def scythe(seed):
    """A scythe from parts: a diagonal shaft, a curved blade at the top, grip wraps, a pommel."""
    rng = int(hashlib.md5(str(seed).encode()).hexdigest(), 16)
    image = Image.new("RGBA", (CELL, CELL))
    px = image.load()
    wood = [(92, 58, 32), (140, 92, 52), (176, 122, 72)][rng % 3]
    metal = (178, 184, 192)
    light = (232, 236, 240)
    length = 18 + rng % 6
    for i in range(length):
        x, y = 7 + i * 0.85, 27 - i
        for w in range(2):
            px[int(x) + w, int(y)] = wood + (255,)
    # Wraps on the grip.
    for i in range(2, 8, 3):
        x, y = 7 + i * 0.85, 27 - i
        px[int(x), int(y)] = (200, 60, 50, 255) if rng % 2 else (60, 90, 160, 255)
    top_x, top_y = int(7 + (length - 1) * 0.85), 27 - (length - 1)
    reach = 10 + (rng >> 3) % 6
    bend = 3 + (rng >> 6) % 4
    for i in range(reach):
        t = i / max(1, reach - 1)
        x = top_x - i
        y = top_y + int(bend * (t * t * 2.0)) - 1
        thickness = 3 if t < 0.5 else 2 if t < 0.85 else 1
        for k in range(thickness):
            if 0 <= x < CELL and 0 <= y + k < CELL:
                px[x, y + k] = (light if k == 0 else metal) + (255,)
    if (rng >> 9) % 3 == 0:
        # A second, smaller blade on the other side.
        for i in range(5):
            if top_x + 1 + i < CELL and top_y + i // 2 < CELL:
                px[top_x + 1 + i, top_y + i // 2] = metal + (255,)
    if (rng >> 11) % 2 == 0:
        px[6, 28] = (220, 190, 80, 255)
        px[7, 28] = (220, 190, 80, 255)
    return fit(outline(image))


def sources():
    """[group, archetype, image, origin] per hand-drawn source icon (plus drawn scythes)."""
    soul = PACKS / "icons_7soul"
    arsenal = PACKS / "icons_idylwild_arsenal"
    armory = PACKS / "icons_idylwild_armory"
    found = []

    def add(group, archetype, path, origin):
        found.append([group, archetype, fit(Image.open(path)), origin])

    def files(folder, pattern):
        return sorted(p for p in folder.rglob("*.png") if re.fullmatch(pattern, p.name))

    for path in files(soul, r"W_Sword\d+\.png") + files(soul, r"W_Gold_Sword\.png"):
        add("sword", "", path, "7soul")
    for path in files(soul, r"W_Dagger\d+\.png") + files(soul, r"W_Gold_Dagger\.png"):
        add("dagger", "", path, "7soul")
    for path in files(soul, r"W_Bow\d+\.png")[:-1] + files(soul, r"W_Gold_Bow\.png"):
        add("bow", "", path, "7soul")
    for path in files(soul, r"W_Spear\d+\.png") + files(soul, r"W_Gold_Spear\.png"):
        add("spear", "", path, "7soul")
    for path in files(arsenal, r"sword\d\.png"):
        add("sword", "", path, "idylwild")
    for path in files(arsenal, r"(dagger\d|knife|throwing_knife1)\.png"):
        add("dagger", "", path, "idylwild")
    for path in files(arsenal, r"(bow\d|crossbow\d)\.png"):
        add("bow", "", path, "idylwild")
    for path in files(arsenal, r"(spear\d|javelin|polearm\d|triden)\.png"):
        add("spear", "", path, "idylwild")
    for path in files(arsenal, r"scythe\d\.png"):
        add("scythe", "", path, "idylwild")
    for seed in range(16):
        found.append(["scythe", "", scythe(seed), "drawn"])
    # Armour (archetype by what the piece is made of).
    for path in files(soul, r"C_Elm\d+\.png"):
        add("head", "metal", path, "7soul")
    for path in files(soul, r"C_Hat\d+\.png"):
        add("head", "cloth", path, "7soul")
    for name, archetype in [("cloth_hood", "cloth"), ("leather_cap", "leather"), ("chainmail_coif", "metal"), ("studded_helmet", "leather"),
                            ("close_helmet", "metal"), ("horned_helmet", "metal"), ("platemail_helmet", "metal")]:
        add("head", archetype, armory_file(armory, name), "idylwild")
    for path in files(soul, r"A_Armou?r\d+\.png"):
        add("body", "metal", path, "7soul")
    for path in files(soul, r"A_Clothing\d+\.png"):
        add("body", "cloth", path, "7soul")
    for name, archetype in [("breastplate", "metal"), ("chainmail_jacket", "metal"), ("chainmail_alt", "metal"), ("cloth_robe", "cloth"), ("cloak", "cloth"),
                            ("leather_jacket", "leather"), ("leather_jacket_alt", "leather"), ("platemail", "metal"), ("quilted_armor", "cloth"),
                            ("studded_jacket", "leather"), ("studded_jacket_alt", "leather"), ("tattered_shirt", "cloth")]:
        add("body", archetype, armory_file(armory, name), "idylwild")
    for name, archetype in [("cloth_gloves", "cloth"), ("leather_gloves", "leather"), ("studded_gloves", "leather"), ("chainmail_gloves", "metal"),
                            ("gauntlets", "metal"), ("iron_bracers", "metal"), ("leather_bracers", "leather")]:
        add("hands", archetype, armory_file(armory, name), "idylwild")
    for path in files(soul, r"A_Shoes\d+\.png"):
        add("feet", "leather", path, "7soul")
    for name, archetype in [("cloth_shoes", "cloth"), ("leather_boots", "leather"), ("studded_boots", "leather"), ("chainmail_boots", "metal"), ("greaves", "metal")]:
        add("feet", archetype, armory_file(armory, name), "idylwild")
    for path in files(soul, r"Ac_Ring\d+\.png"):
        add("ring", "ring", path, "7soul")
    for name in ["copper_ring", "iron_ring", "silver_ring", "gold_ring"]:
        add("ring", "ring", armory_file(armory, name), "idylwild")
    for path in files(soul, r"Ac_(Necklace|Medal)\d+\.png"):
        add("amulet", "amulet", path, "7soul")
    return found


def class_weapon_sources():
    """M12c: [group, archetype, image, origin] for staffs and fist weapons."""
    soul = PACKS / "icons_7soul"
    arsenal = PACKS / "icons_idylwild_arsenal"
    found = []
    for path in sorted(p for p in soul.rglob("*.png") if re.fullmatch(r"W_Staff\d+\.png", p.name)):
        found.append(["staff", "", fit(Image.open(path)), "7soul"])
    for path in sorted(p for p in arsenal.rglob("*.png") if re.fullmatch(r"(staff\d|wand\d)\.png", p.name)):
        found.append(["staff", "", fit(Image.open(path)), "idylwild"])
    for path in sorted(p for p in soul.rglob("*.png") if re.fullmatch(r"W_Fist\d+\.png", p.name)):
        found.append(["fist", "", fit(Image.open(path)), "7soul"])
    return found


def armory_file(folder, name):
    return next(p for p in folder.rglob(name + ".png"))


def epic_sources():
    """The Super Epic Weapons sheet: five themed rows; columns by weapon type."""
    sheet = Image.open(PACKS / "icons_epic_weapons/super_epic_weapons.png").convert("RGBA")
    columns = {0: "sword", 3: "dagger", 4: "bow", 5: "spear", 6: "scythe", 8: "hands"}
    found = []
    for row, theme in enumerate(EPIC_THEMES):
        for column, group in columns.items():
            cell = _clear_background(sheet.crop((column * 64, row * 64, column * 64 + 64, row * 64 + 64)))
            found.append([group, "metal" if group == "hands" else "", fit(cell.resize((32, 32), Image.NEAREST)), theme])
    return found


def _clear_background(cell, tolerance=26):
    """The sheet has a smooth teal/blue backdrop: clear everything connected to the edges that
    continues that gradient (each step only slightly different from its neighbour)."""
    cell = cell.convert("RGBA")
    px = cell.load()
    w, h = cell.size

    def backdrop(c):
        return c[2] > c[0] + 20 and c[1] > c[0]

    original = {(x, y): px[x, y] for x in range(w) for y in range(h)}
    seen = set()
    stack = [((x, y), original[(x, y)]) for x in range(w) for y in (0, h - 1)] + [((x, y), original[(x, y)]) for y in range(h) for x in (0, w - 1)]
    while stack:
        (x, y), previous = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        colour = original[(x, y)]
        if not backdrop(colour) or sum(abs(colour[i] - previous[i]) for i in range(3)) > tolerance * 3:
            continue
        seen.add((x, y))
        px[x, y] = (0, 0, 0, 0)
        for step in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            stack.append(((x + step[0], y + step[1]), colour))
    # Pockets enclosed by the weapon (inside a bow) in the backdrop's own colour.
    corner = original[(0, 0)]
    for (x, y), colour in original.items():
        if colour[3] > 0 and backdrop(colour) and sum(abs(colour[i] - corner[i]) for i in range(3)) < 45:
            px[x, y] = (0, 0, 0, 0)
    return cell


def glow_outline(image, colour):
    """A soft two-step glow around the icon (uniques)."""
    base = image.copy()
    out = Image.new("RGBA", image.size)
    src = image.load()
    dst = out.load()
    r, g, b = hexcolor(colour)
    for y in range(image.height):
        for x in range(image.width):
            if src[x, y][3] > 0:
                continue
            near = [(dx, dy) for dx in range(-2, 3) for dy in range(-2, 3) if 0 <= x + dx < image.width and 0 <= y + dy < image.height and src[x + dx, y + dy][3] > 0]
            if near:
                closest = min(abs(dx) + abs(dy) for dx, dy in near)
                dst[x, y] = (r, g, b, 230 if closest == 1 else 110)
    out.alpha_composite(base)
    return out


def stats_for(group, archetype, level, element, grade_bonus):
    scale = 1.0 + 0.045 * (level - 1) + grade_bonus
    if group in WEAPON_DAMAGE:
        low, high = WEAPON_DAMAGE[group]
        return {"damage": [round(low * scale), max(round(low * scale), round(high * scale))]}
    result = {}
    for stat, (low, high) in ARMOUR[group][archetype].items():
        result[stat] = _span(stat, low, high, scale)
    if element:
        stat, (low, high) = ELEMENT_STAT[element]
        extra = _span(stat, low, high, scale)
        result[stat] = [result[stat][0] + extra[0], result[stat][1] + extra[1]] if stat in result else extra
        result[stat] = [round(v, 1) if stat == "regen" else int(v) for v in result[stat]]
    return result


def _span(stat, low, high, scale):
    if low < 0:
        return [low, high]
    if stat == "regen":
        return [round(low * scale, 1), max(round(low * scale, 1), round(high * scale, 1))]
    return [max(1, round(low * scale)), max(1, round(low * scale), round(high * scale))]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    groups = {}
    used_names = set()
    bases = []

    def unique(name):
        candidate = name
        counter = 2
        while candidate in used_names:
            candidate = f"{name} {['II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'][min(counter - 2, 6)]}" if counter < 9 else f"{name} {counter}"
            counter += 1
        used_names.add(candidate)
        return candidate

    def add(group, archetype, image, name, element, level, min_rarity, grade_bonus, slot):
        index = len(groups.setdefault(group, []))
        groups[group].append(image)
        base_id = f"{group}_{index + 1:03d}"
        entry = {"id": base_id, "slot": slot, "name": unique(name), "element": element, "level": level, "min_rarity": min_rarity,
                 "icon": group, "cell": index, "stats": stats_for(group, archetype, level, element, grade_bonus), "archetype": archetype}
        if group in WEAPON_DAMAGE:
            entry["weapon"] = group
        bases.append(entry)

    slot_of = {"sword": "weapon", "dagger": "weapon", "spear": "weapon", "scythe": "weapon", "bow": "weapon", "staff": "weapon", "fist": "weapon",
               "head": "head", "body": "body", "hands": "hands", "feet": "feet", "ring": "accessory", "amulet": "accessory"}
    found = sources()
    per_group = {}
    for entry in found:
        per_group.setdefault(entry[0], []).append(entry)
    def expand(group, entries):
        nouns = NOUNS[group]
        for index, (group_name, archetype, image, origin) in enumerate(entries):
            seed = int(hashlib.md5(f"{group}:{index}".encode()).hexdigest(), 16)
            progress = index / max(1, len(entries) - 1)
            level = 1 + int(progress * 13)
            noun = nouns[index % len(nouns)]
            # The original look: plain material, Common and up.
            material_word = MATERIAL_WORDS["iron"][seed % len(MATERIAL_WORDS["iron"])]
            add(group, archetype, image, f"{material_word} {noun}", "", level, 0, 0.0, slot_of[group])
            # One material variant: a little better, Uncommon and up.
            material = MATERIALS[seed % len(MATERIALS)]
            words = MATERIAL_WORDS[material]
            add(group, archetype, recolour(image, material, group in WEAPON_DAMAGE), f"{words[(seed >> 4) % len(words)]} {noun}", "",
                min(20, level + 2), 1, 0.05, slot_of[group])
            # Two element variants: themed names and colours, Rare and up, stronger.
            for k in range(2):
                element = ELEMENTS[(seed >> (8 + 3 * k)) % len(ELEMENTS)]
                if k == 1 and element == ELEMENTS[(seed >> 8) % len(ELEMENTS)]:
                    element = ELEMENTS[(ELEMENTS.index(element) + 3) % len(ELEMENTS)]
                words = ELEMENT_WORDS[element]
                word = words[(seed >> (14 + 4 * k)) % len(words)]
                alt_noun = nouns[(index + 3 + k * 5) % len(nouns)]
                add(group, archetype, recolour(image, element, group in WEAPON_DAMAGE), f"{word} {alt_noun}", element,
                    min(20, level + 4 + 2 * k), 2, 0.12, slot_of[group])

    for group, entries in per_group.items():
        expand(group, entries)
    # Epic themed pieces from the Super Epic sheet: Epic and up, high level.
    for index, (group, archetype, image, theme) in enumerate(epic_sources()):
        nouns = NOUNS[group]
        add(group, archetype, image, f"{EPIC_WORDS[theme]} {nouns[(index * 7) % len(nouns)]}", theme, 14 + index % 7, 3, 0.25, slot_of[group])
    # Sets: five Epic pieces per element (the first source icon of each slot in its colours).
    for element, (set_id, prefix) in SETS.items():
        for k, (group, archetype) in enumerate(SET_SLOTS):
            source = next(entry for entry in per_group[group] if entry[1] in (archetype, "amulet"))
            nouns = NOUNS[group]
            add(group, archetype, recolour(source[2], element, False), f"{prefix} {nouns[(k + len(element)) % len(nouns)]}", element, 16, 3, 0.3, slot_of[group])
            bases[-1]["set"] = set_id
    # Uniques.
    soul = PACKS / "icons_7soul"
    arsenal = PACKS / "icons_idylwild_arsenal"
    armory = PACKS / "icons_idylwild_armory"
    for name, group, (pack, file), element, min_rarity, ability in UNIQUES:
        if pack == "drawn":
            image = scythe(100 + file)
        else:
            folder = {"7soul": soul, "arsenal": arsenal, "armory": armory}[pack]
            image = fit(Image.open(armory_file(folder, file) if pack == "armory" else next(folder.rglob(file))))
        image = glow_outline(recolour(image, element, group in WEAPON_DAMAGE), ACCENTS[element])
        archetype = UNIQUE_ARCHETYPE.get(group, "")
        add(group, archetype, image, name, element, 18 if min_rarity == 4 else 20, min_rarity, 0.45, slot_of[group])
        bases[-1]["unique"] = ability
    # M12c: staffs and fist weapons, after everything else so every earlier item keeps its ID
    # and name.
    per_class = {}
    for entry in class_weapon_sources():
        per_class.setdefault(entry[0], []).append(entry)
    for group, entries in per_class.items():
        expand(group, entries)
    for name, group, (pack, file), element, min_rarity, ability in CLASS_UNIQUES:
        folder = {"7soul": soul, "arsenal": arsenal}[pack]
        image = glow_outline(recolour(fit(Image.open(next(folder.rglob(file)))), element, True), ACCENTS[element])
        add(group, "", image, name, element, 18 if min_rarity == 4 else 20, min_rarity, 0.45, slot_of[group])
        bases[-1]["unique"] = ability
    # Atlases and previews.
    PREVIEW.mkdir(parents=True, exist_ok=True)
    for group, images in groups.items():
        rows = (len(images) + COLUMNS - 1) // COLUMNS
        atlas = Image.new("RGBA", (COLUMNS * CELL, rows * CELL))
        for index, image in enumerate(images):
            atlas.paste(image, ((index % COLUMNS) * CELL, (index // COLUMNS) * CELL), image)
        atlas.save(OUT / f"{group}.png")
        preview = Image.new("RGBA", atlas.size, (36, 38, 48, 255))
        preview.alpha_composite(atlas)
        preview.resize((atlas.width * 2, atlas.height * 2), Image.NEAREST).save(PREVIEW / f"items_{group}.png")
    # The catalogue.
    lines = ["extends RefCounted",
             "## GENERATED by tools/generate_items.py — do not edit by hand.",
             "## Item bases of the item expansion: id → slot, weapon type, name, element, level, minimum",
             "## rarity, icon atlas and cell, stat ranges at Common (scaled by rarity like every base).",
             "const BASES := {"]
    for entry in bases:
        stats = ", ".join(f'"{k}": [{v[0]}, {v[1]}]' for k, v in entry["stats"].items())
        weapon = f', "weapon": "{entry["weapon"]}"' if "weapon" in entry else ""
        weapon += f', "set": "{entry["set"]}"' if "set" in entry else ""
        weapon += f', "unique": "{entry["unique"]}"' if "unique" in entry else ""
        lines.append(f'    "{entry["id"]}": {{"slot": "{entry["slot"]}"{weapon}, "name": "{entry["name"]}", "look": "icon", "element": "{entry["element"]}", '
                     f'"level": {entry["level"]}, "min_rarity": {entry["min_rarity"]}, "icon": "{entry["icon"]}", "cell": {entry["cell"]}, '
                     f'"archetype": "{entry["archetype"]}", "stats": {{{stats}}}}},')
    lines.append("}")
    lines.append(f"const ATLAS_COLUMNS := {COLUMNS}")
    lines.append(f"const CELL := {CELL}")
    (ROOT / "scripts/items/item_bases.gd").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    counts = {group: len(images) for group, images in groups.items()}
    print("bases:", len(bases), counts)


if __name__ == "__main__":
    main()
