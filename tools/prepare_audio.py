"""Prepare step 23's audio and effect sheets from the Ninja Adventure pack (CC0), run from the
repository root. Files are copied unchanged under short names; README tables are written next to
them. Source pack: assets/source/packs/ninja_adventure (Audio/, FX/).
"""
from pathlib import Path
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PACK = ROOT / "assets/source/packs/ninja_adventure"
AUDIO = ROOT / "assets/game/audio"
FX = ROOT / "assets/game/sprites/fx"

MUSIC = {
    "title": "Audio/Musics/38 - Intro.ogg",
    "clearing": "Audio/Musics/11 - Clearing.ogg",
    "verdant": "Audio/Musics/35 - Adventure.ogg",
    "thornwood": "Audio/Musics/37 - Dark Forest.ogg",
    "mirror_lake": "Audio/Musics/13 - Mystical.ogg",
    "cinder_crater": "Audio/Musics/28 - Tension.ogg",
    "harrowmere": "Audio/Musics/36 - Village.ogg",
    "sea": "Audio/Musics/39 - Boat.ogg",
    "trial": "Audio/Musics/17 - Fight.ogg",
}
SFX = {
    "swing": "Audio/Sounds/Whoosh & Slash/Slash.wav",
    "bow": "Audio/Sounds/Whoosh & Slash/Launch.wav",
    "hit": "Audio/Sounds/Hit & Impact/Hit1.wav",
    "hurt": "Audio/Sounds/Hit & Impact/Impact.wav",
    "defeat": "Audio/Sounds/Hit & Impact/Impact3.wav",
    "magicules": "Audio/Sounds/Bonus/Bonus.wav",
    "item": "Audio/Sounds/Bonus/PowerUp1.wav",
    "analysis": "Audio/Sounds/Magic & Skill/Magic1.wav",
    "learned": "Audio/Sounds/Magic & Skill/Spirit.wav",
    "form": "Audio/Sounds/Magic & Skill/Magic3.wav",
    "shrine": "Audio/Sounds/Magic & Skill/Heal.wav",
    "gather": "Audio/Sounds/Elemental/Grass.wav",
    "exhausted": "Audio/Sounds/Alert/Alert.wav",
    "level_up": "Audio/Jingles/LevelUp1.wav",
    "chest": "Audio/Jingles/Secret1.wav",
    "evolve": "Audio/Jingles/Success1.wav",
    "build": "Audio/Jingles/Success2.wav",
    "game_over": "Audio/Jingles/GameOver.wav",
    "ui_move": "Audio/Sounds/Menu/Move1.wav",
    "ui_accept": "Audio/Sounds/Menu/Accept.wav",
    "ui_cancel": "Audio/Sounds/Menu/Cancel.wav",
}
# name: (source, frame width) — one row of square-ish frames.
EFFECTS = {
    "hit_spark": ("FX/Magic/Circle/SpriteSheetSpark.png", 32),
    "ring": ("FX/Magic/Circle/SpriteSheetWhite.png", 32),
    "sparkle": ("FX/Magic/Spark/SpriteSheet.png", 30),
    "aura": ("FX/Magic/Aura/SpriteSheet.png", 25),
    "boost": ("FX/Magic/Boost/SpriteSheet.png", 53),
    "smoke": ("FX/Smoke/Smoke/SpriteSheet.png", 32),
}


def main():
    rows = ["# Prepared audio (step 23)", "", "Copied unchanged from `assets/source/packs/ninja_adventure/` (CC0) by `tools/prepare_audio.py`. Played by `scripts/audio/audio_director.gd`.", "", "| File | Use | Source |", "| --- | --- | --- |"]
    for folder, table in (("music", MUSIC), ("sfx", SFX)):
        (AUDIO / folder).mkdir(parents=True, exist_ok=True)
        for name, source in table.items():
            suffix = Path(source).suffix
            shutil.copyfile(PACK / source, AUDIO / folder / f"{name}{suffix}")
            rows.append(f"| `{folder}/{name}{suffix}` | {name.replace('_', ' ')} | `{source}` |")
    (AUDIO / "README.md").write_text("\n".join(rows) + "\n", encoding="utf-8", newline="\n")
    notes = []
    for name, (source, frame) in EFFECTS.items():
        shutil.copyfile(PACK / source, FX / f"{name}.png")
        size = Image.open(FX / f"{name}.png").size
        notes.append(f"| `fx/{name}.png` | {size[0]}x{size[1]} | {size[0] // frame} frames of {frame}x{size[1]} | `{source}` |")
    print("\n".join(notes))


if __name__ == "__main__":
    main()
