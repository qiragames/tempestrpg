"""Prepare the M4.5c region creatures from the Ninja Adventure monster sheets (CC0, already stored
under assets/source/packs/ninja_adventure; run from the repository root).

Each sheet is 64x64: four columns (down, up, left, right) by four walk frames of 16x16. It is
copied to assets/game/sprites/<kind>/<kind>_walk.png (same layout as the player sheets, so
SpriteLibrary builds walk/idle animations per direction), plus a preview contact sheet in
docs/asset_previews/region_creatures.png.
"""
from pathlib import Path
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MONSTERS = ROOT / "assets/source/packs/ninja_adventure/Actor/Monster"
SPRITES = ROOT / "assets/game/sprites"
PREVIEW = ROOT / "docs/asset_previews/region_creatures.png"

# kind -> Ninja Adventure monster folder
KINDS = {
    "frost_bear": "Bear",
    "snow_wisp": "Spirit",
    "dune_viper": "Snake",
    "sand_scuttler": "SpiderYellow",
    "bog_kappa": "KappaGreen",
    "mirecap": "Mushroom",
    "bamboo_sprite": "Bamboo",
    "paper_lantern": "LanternRed",
    "amber_owl": "Owl",
    "burrow_mole": "Mole",
    "ember_flame": "Flam",
    "salamander": "Reptile2",
}


CHARACTERS = ROOT / "assets/source/packs/ninja_adventure/Actor/Character"
# Shopkeepers (M4.5c): npc id -> Ninja Adventure character folder (walk sheet + face portrait).
NPCS = {
    "merchant_verdant": "Villager", "merchant_frost": "Eskimo", "merchant_desert": "Sultan",
    "merchant_sakura": "Monk", "merchant_amber": "Hunter", "merchant_marsh": "Shaman",
    "merchant_ember": "OldMan", "merchant_harrow": "Noble", "camp_trader": "Woman",
    "camp_smith": "FighterWhite", "traveller": "MaskRacoon", "ferryman": "OldMan2", "shipwright": "Inspector",
}


ANIMALS = ROOT / "assets/source/packs/ninja_adventure/Actor/Animal"
# Mounts (M4.5d): mount sprite set -> (front sheet, side sheet); two walk frames each. The boar
# has only a side view (used for every direction).
MOUNTS = {
    "mount_donkey": ("Donkey/SpriteSheetGrey.png", "Donkey/SpriteSheeGreySide.png"),
    "mount_horse": ("Horse/SpriteSheetBrown.png", "Horse/SpriteSheetBrownSide.png"),
    "mount_black_horse": ("Horse/SpriteSheetBlack.png", "Horse/SpriteSheetBlackSide.png"),
    "mount_wild_boar": ("WildBoar/SpriteSheet.png", "WildBoar/SpriteSheet.png"),
    "mount_lion": ("Lion/SpriteSheetOrange.png", "Lion/SpriteSheetOrangeSide.png"),
}


def sheet(folder: Path) -> Path:
    candidates = [p for p in folder.glob("*.png") if p.name != "Faceset.png"]
    return candidates[0]


def main():
    preview = Image.new("RGBA", (len(KINDS) * 72, 72), (40, 46, 40, 255))
    for index, (kind, folder) in enumerate(KINDS.items()):
        source = sheet(MONSTERS / folder)
        target = SPRITES / kind
        target.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target / f"{kind}_walk.png")
        image = Image.open(source).convert("RGBA")
        assert image.size == (64, 64), (kind, image.size)
        frame = image.crop((0, 0, 16, 16)).resize((64, 64), Image.NEAREST)
        preview.alpha_composite(frame, (index * 72 + 4, 4))
    for npc, folder in NPCS.items():
        target = SPRITES / npc
        target.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(CHARACTERS / folder / "SeparateAnim" / "Walk.png", target / f"{npc}_walk.png")
        shutil.copyfile(CHARACTERS / folder / "Faceset.png", target / f"{npc}_face.png")
    for mount, (front, side) in MOUNTS.items():
        target = SPRITES / mount
        target.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ANIMALS / front, target / "front.png")
        shutil.copyfile(ANIMALS / side, target / "side.png")
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW)
    print(f"prepared {len(KINDS)} creature sheets, {len(NPCS)} shopkeepers, {len(MOUNTS)} mounts and {PREVIEW.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
