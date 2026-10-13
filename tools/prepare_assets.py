#!/usr/bin/env python3
"""Prepare game textures from the third-party packs in assets/source/packs (step 18).

Copies the chosen sheets into assets/game/ with lowercase names, keeping every pixel unchanged
(originals stay in assets/source/packs), and renders x3 nearest-neighbour preview sheets into
docs/asset_previews/ for review. Re-run after changing the selection below. Requires Pillow.

Packs (licences next to the originals):
  Ninja Adventure (pixel-boy, AAA) — CC0 1.0.
  Pixel Crawler Free Pack 2.11 (Anokolisa) — free for any project incl. commercial; the art itself
  may not be resold (see assets/source/packs/pixel_crawler/Terms.txt).
  Kyrise's Free 16x16 RPG Icon Pack V1.3 — CC BY 4.0 (credit "Kyrise", see CREDITS.md).
  Shade's 16x16 Weapon RPG Icons — free incl. commercial use, no credit required.
"""
from pathlib import Path
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
NINJA = ROOT / "assets/source/packs/ninja_adventure"
CRAWLER = ROOT / "assets/source/packs/pixel_crawler"
GAME = ROOT / "assets/game"
PREVIEW = ROOT / "docs/asset_previews"

# (target path under assets/game, source file, note)
SPRITES = [
    # Playable races (Ninja Adventure, 16x16 frames; columns = directions down, up, left, right).
    ("sprites/player_slime/slime_walk.png", NINJA / "Actor/Monster/Slime3/Slime3.png", "Slime race: 4x4 grid of 16x16, columns = direction, rows = walk frames"),
    ("sprites/player_slime/slime_faceset.png", NINJA / "Actor/Monster/Slime3/Faceset.png", "Slime portrait"),
    ("sprites/player_human/human_idle.png", NINJA / "Actor/Character/Boy/SeparateAnim/Idle.png", "Human race: 4 directions x 1 frame (16x16)"),
    ("sprites/player_human/human_walk.png", NINJA / "Actor/Character/Boy/SeparateAnim/Walk.png", "Human: 4 directions x 4 frames"),
    ("sprites/player_human/human_attack.png", NINJA / "Actor/Character/Boy/SeparateAnim/Attack.png", "Human: 4 directions x 1 frame"),
    ("sprites/player_human/human_dead.png", NINJA / "Actor/Character/Boy/SeparateAnim/Dead.png", "Human: defeated pose"),
    ("sprites/player_human/human_faceset.png", NINJA / "Actor/Character/Boy/Faceset.png", "Human portrait"),
    ("sprites/player_demon/demon_idle.png", NINJA / "Actor/Character/DemonRed/SeparateAnim/Idle.png", "Demon race: 4 directions x 1 frame"),
    ("sprites/player_demon/demon_walk.png", NINJA / "Actor/Character/DemonRed/SeparateAnim/Walk.png", "Demon: 4 directions x 4 frames"),
    ("sprites/player_demon/demon_attack.png", NINJA / "Actor/Character/DemonRed/SeparateAnim/Attack.png", "Demon: 4 directions x 1 frame"),
    ("sprites/player_demon/demon_dead.png", NINJA / "Actor/Character/DemonRed/SeparateAnim/Dead.png", "Demon: defeated pose"),
    ("sprites/player_demon/demon_faceset.png", NINJA / "Actor/Character/DemonRed/Faceset.png", "Demon portrait"),
    # Goblin-look creatures (Pixel Crawler, side view only; flip horizontally for the other side).
    ("sprites/gnasher/gnasher_idle.png", CRAWLER / "Entities/Mobs/Orc Crew/Orc/Idle/Idle-Sheet.png", "Forest Gnasher (user: Goblin look): 4 frames of 32x32"),
    ("sprites/gnasher/gnasher_run.png", CRAWLER / "Entities/Mobs/Orc Crew/Orc/Run/Run-Sheet.png", "Gnasher: 6 frames of 64x64"),
    ("sprites/gnasher/gnasher_death.png", CRAWLER / "Entities/Mobs/Orc Crew/Orc/Death/Death-Sheet.png", "Gnasher: 6 frames of 64x64"),
    ("sprites/thornback/thornback_idle.png", CRAWLER / "Entities/Mobs/Orc Crew/Orc - Shaman/Idle/Idle-Sheet.png", "Thornback Gnasher (red hood, clearly another enemy): 4 frames of 32x32"),
    ("sprites/thornback/thornback_run.png", CRAWLER / "Entities/Mobs/Orc Crew/Orc - Shaman/Run/Run-Sheet.png", "Thornback: 6 frames of 64x64"),
    ("sprites/thornback/thornback_death.png", CRAWLER / "Entities/Mobs/Orc Crew/Orc - Shaman/Death/Death-Sheet.png", "Thornback: 6 frames of 64x64"),
    ("sprites/ally_goblin/goblin_idle.png", CRAWLER / "Entities/Mobs/Orc Crew/Orc - Rogue/Idle/Idle-Sheet.png", "Nameless goblin ally (brown hood, distinct from enemies): 4 frames of 32x32"),
    ("sprites/ally_goblin/goblin_run.png", CRAWLER / "Entities/Mobs/Orc Crew/Orc - Rogue/Run/Run-Sheet.png", "Goblin ally: 6 frames of 64x64"),
    ("sprites/hobgoblin/hobgoblin_idle.png", CRAWLER / "Entities/Mobs/Orc Crew/Orc - Warrior/Idle/Idle-Sheet.png", "Named Hobgoblin (armored; naming visibly evolves the ally): 4 frames of 32x32"),
    ("sprites/hobgoblin/hobgoblin_run.png", CRAWLER / "Entities/Mobs/Orc Crew/Orc - Warrior/Run/Run-Sheet.png", "Hobgoblin: 6 frames of 64x64"),
    # Effects for attacks and analysis.
    ("sprites/fx/slash.png", NINJA / "FX/Attack/SlashCurved/SpriteSheet.png", "Basic strike / sword slash effect"),
    ("sprites/fx/claw.png", NINJA / "FX/Attack/Claw/SpriteSheet.png", "Bite/claw skills (Rending Bite, Shadow Claw)"),
]
WORLD = [
    ("world/terrain_field.png", NINJA / "Backgrounds/Tilesets/TilesetField.png", "Grass ground, 16x16 tiles"),
    ("world/terrain_floor.png", NINJA / "Backgrounds/Tilesets/TilesetFloor.png", "Paths, dirt and ground autotiles, 16x16"),
    ("world/terrain_floor_detail.png", NINJA / "Backgrounds/Tilesets/TilesetFloorDetail.png", "Ground details (flowers, cracks), 16x16"),
    ("world/water.png", NINJA / "Backgrounds/Tilesets/TilesetWater.png", "Water, shores and lily pads (pond, later the sea), 16x16"),
    ("world/nature.png", NINJA / "Backgrounds/Tilesets/TilesetNature.png", "Trees (incl. pink/snowy biomes), rocks, bushes, flowers; multi-tile props"),
    ("world/relief.png", NINJA / "Backgrounds/Tilesets/TilesetRelief.png", "Cliffs and elevation, 16x16"),
    ("world/house.png", NINJA / "Backgrounds/Tilesets/TilesetHouse.png", "Buildings for the hut/storehouse and later towns"),
    ("world/camp.png", NINJA / "Backgrounds/Tilesets/tileset_camp.png", "Camp props: tents, fire, crates"),
    ("world/boat.png", NINJA / "Backgrounds/Vehicles/Boat.png", "Boat for the M4.5 ferries/ships"),
    ("world/sail.png", NINJA / "Backgrounds/Vehicles/Sail.png", "Sail for the M4.5 ships"),
    ("world/station_anvil.png", CRAWLER / "Environment/Structures/Stations/Anvil/Anvil.png", "Forge: anvil station sheet"),
    ("world/station_bonfire.png", CRAWLER / "Environment/Structures/Stations/Bonfire/Bonfire.png", "Camp flag/bonfire sheet"),
]
UI = [
    ("ui/dialog_box.png", NINJA / "Ui/Dialog/DialogBox.png", "Dialog/panel frame (9-slice)"),
    ("ui/dialog_box_faceset.png", NINJA / "Ui/Dialog/DialogBoxFaceset.png", "Dialog with portrait slot"),
    ("ui/choice_box.png", NINJA / "Ui/Dialog/ChoiceBox.png", "Menu/choice frame"),
    ("ui/faceset_box.png", NINJA / "Ui/Dialog/FacesetBox.png", "Portrait frame"),
    ("ui/heart.png", NINJA / "Ui/Receptacle/Heart.png", "HP heart icon"),
    ("ui/lifebar_mini_under.png", NINJA / "Ui/Receptacle/LifeBarMiniUnder.png", "Small bar background (enemy HP)"),
    ("ui/lifebar_mini_progress.png", NINJA / "Ui/Receptacle/LifeBarMiniProgress.png", "Small bar fill (enemy HP)"),
    ("ui/font_normal.ttf", NINJA / "Ui/Font/NormalFont.ttf", "Pixel font (CC0)"),
    ("ui/icons/sword.png", NINJA / "Items/Weapons/Sword/Sprite.png", "Weapon icon: sword"),
    ("ui/icons/bow.png", NINJA / "Items/Weapons/Bow/Sprite.png", "Weapon icon: bow"),
    ("ui/icons/chest_closed.png", NINJA / "Items/Treasure/LittleTreasureChest.png", "Chest (closed)"),
    ("ui/icons/chest_big.png", NINJA / "Items/Treasure/BigTreasureChest.png", "Chest (big)"),
    ("ui/icons/bag.png", NINJA / "Items/Object/Bag.png", "Bag / storage icon"),
    ("ui/icons/money_bag.png", NINJA / "Items/Object/MoneyBag.png", "Currency (M4.5)"),
    ("ui/icons/coin_gold.png", NINJA / "Items/Treasure/GoldCoin.png", "Currency coin (M4.5)"),
    ("ui/icons/wood.png", NINJA / "Items/Resource/Branch.png", "Camp resource: wood"),
    ("ui/icons/stone.png", NINJA / "Items/Resource/Rock.png", "Camp resource: stone"),
    ("ui/icons/essence.png", NINJA / "Items/Resource/GemGreen.png", "Camp resource: essence / Gnasher Essence"),
    ("ui/icons/quill.png", NINJA / "Items/Resource/feather.png", "Thornback Quill"),
    ("ui/icons/bar_iron.png", NINJA / "Items/Resource/BarIron.png", "Forge material (later recipes)"),
]

KYRISE = ROOT / "assets/source/packs/kyrise_icons/icons/16x16"
SHADE = ROOT / "assets/source/packs/shade_weapons/16x16 Weapons RPG Icons"
## Gear icons per item base, one per rarity (0 Common .. 4 Legendary). Kyrise variants a..e map to
## the five rarities; Shade's scythe uses bronze, iron, steel, gold, gold.
GEAR_ICONS = {
    "cloth_hood": "hat_01", "iron_helm": "helmet_01", "padded_vest": "armor_01", "scale_mail": "armor_01",
    "leather_gloves": "gloves_01", "travel_boots": "boots_01", "copper_ring": "ring_01", "spirit_amulet": "necklace_01",
    "iron_sword": "sword_01", "hunting_bow": "bow_01",
}
SHADE_CELLS = {"field_scythe": (14, 10), "ash_spear": (16, 0)}  # column, row of 16x16 cells in Shade's metal sheets

def gear_icons():
    rows = []
    out = GAME / "ui/icons/gear"
    out.mkdir(parents=True, exist_ok=True)
    for base, stem in GEAR_ICONS.items():
        for rarity, letter in enumerate("abcde"):
            source = KYRISE / f"{stem}{letter}.png"
            if not source.exists():
                source = KYRISE / f"{stem}{letter}{letter}.png"  # e.g. bow_01cc.png in the pack
            shutil.copyfile(source, out / f"{base}_{rarity}.png")
        rows.append((f"ui/icons/gear/{base}_0.png", source.relative_to(ROOT).as_posix().rsplit("/", 1)[0] + f"/{stem}a..e.png", (16, 16), f"{base}: rarity 0..4 = Kyrise variants a..e (CC BY 4.0, credit Kyrise)"))
    for base, (x, y) in SHADE_CELLS.items():
        for rarity, metal in enumerate(["bronze", "iron", "steel", "gold", "gold"]):
            sheet = Image.open(SHADE / f"{metal}-weapons.png").convert("RGBA")
            sheet.crop((x * 16, y * 16, x * 16 + 16, y * 16 + 16)).save(out / f"{base}_{rarity}.png")
        rows.append((f"ui/icons/gear/{base}_0.png", (SHADE / "iron-weapons.png").relative_to(ROOT).as_posix(), (16, 16), f"{base}: cell {x},{y}; rarity 0..4 = bronze, iron, steel, gold, gold (Shade, free incl. commercial, no credit needed)"))
    return rows

def gear_preview(scale=4):
    bases = list(GEAR_ICONS) + ["field_scythe", "ash_spear"]
    colours = ["9aa3a8", "6fcf7a", "5aa2ee", "b47cf0", "f0a34a"]
    cell = 16 * scale + 8
    sheet = Image.new("RGBA", (110 + cell * 5, cell * len(bases)), (37, 58, 52, 255))
    draw = ImageDraw.Draw(sheet)
    for row, base in enumerate(bases):
        draw.text((4, row * cell + cell // 2 - 6), base, fill=(235, 240, 230, 255))
        for rarity in range(5):
            x, y = 110 + rarity * cell, row * cell
            draw.rectangle((x + 1, y + 1, x + cell - 3, y + cell - 3), outline="#" + colours[rarity], width=2)
            icon = Image.open(GAME / f"ui/icons/gear/{base}_{rarity}.png").convert("RGBA").resize((16 * scale, 16 * scale), Image.NEAREST)
            sheet.alpha_composite(icon, (x + 3, y + 3))
    sheet.convert("RGB").save(PREVIEW / "gear_icons.png")

def copy(entries):
    rows = []
    for target, source, note in entries:
        if not source.exists():
            raise SystemExit(f"missing source: {source}")
        destination = GAME / target
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        size = Image.open(destination).size if destination.suffix == ".png" else None
        rows.append((target, source.relative_to(ROOT).as_posix(), size, note))
    return rows

def preview(rows, name, scale=3, columns=4):
    images = [(target, Image.open(GAME / target).convert("RGBA")) for target, _, _, _ in rows if target.endswith(".png")]
    cell_w = max(min(img.width, 192) for _, img in images) * scale
    cell_h = max(min(img.height, 160) for _, img in images) * scale + 14
    grid_rows = (len(images) + columns - 1) // columns
    sheet = Image.new("RGBA", (cell_w * columns, cell_h * grid_rows), (37, 58, 52, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (target, img) in enumerate(images):
        crop = img.crop((0, 0, min(img.width, 192), min(img.height, 160)))
        big = crop.resize((crop.width * scale, crop.height * scale), Image.NEAREST)
        x, y = (index % columns) * cell_w, (index // columns) * cell_h
        sheet.alpha_composite(big, (x + 2, y + 14))
        draw.text((x + 3, y + 1), target.split("/")[-1], fill=(235, 240, 230, 255))
    PREVIEW.mkdir(parents=True, exist_ok=True)
    (PREVIEW / ".gdignore").write_text("")
    sheet.convert("RGB").save(PREVIEW / f"{name}.png")

def notes(rows, folder, title):
    lines = [f"# Prepared {title}", "",
             "Step 18 (asset preparation). Copied unchanged from the third-party packs in `assets/source/packs/` by `tools/prepare_assets.py`; previews (x3, nearest) in `docs/asset_previews/`. **Status: prepared, not yet integrated** (scenes still use the code-drawn placeholders until steps 19–21).", "",
             "Pixel scale 1:1 with the 640x360 viewport; nearest filtering (project default). Foot pivot: bottom-centre of each frame unless noted.", "",
             "| File | Size | Frames / layout | Source |", "| --- | --- | --- | --- |"]
    for target, source, size, note in rows:
        lines.append(f"| `{target.split('/', 1)[1]}` | {f'{size[0]}x{size[1]}' if size else '—'} | {note} | `{source}` |")
    lines += ["", "Licences and credits: see `CREDITS.md` at the repository root and the licence files next to each pack in `assets/source/packs/`."]
    (GAME / folder / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

if __name__ == "__main__":
    sprite_rows, world_rows, ui_rows = copy(SPRITES), copy(WORLD), copy(UI) + gear_icons()
    notes(sprite_rows, "sprites", "sprites")
    notes(world_rows, "world", "world tiles and props")
    notes(ui_rows, "ui", "UI frames, font and icons")
    preview(sprite_rows, "sprites")
    preview(world_rows, "world", scale=1, columns=3)
    preview(ui_rows, "ui", columns=6)
    gear_preview()
    print(f"prepared {len(sprite_rows)} sprite, {len(world_rows)} world and {len(ui_rows)} UI files")
