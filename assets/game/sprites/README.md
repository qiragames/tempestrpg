# Prepared sprites

Step 18 (asset preparation). Copied unchanged from the third-party packs in `assets/source/packs/` by `tools/prepare_assets.py`; previews (x3, nearest) in `docs/asset_previews/`. **Status: prepared, not yet integrated** (scenes still use the code-drawn placeholders until steps 19–21).

Pixel scale 1:1 with the 640x360 viewport; nearest filtering (project default). Foot pivot: bottom-centre of each frame unless noted.

| File | Size | Frames / layout | Source |
| --- | --- | --- | --- |
| `player_slime/slime_walk.png` | 64x64 | Slime race: 4x4 grid of 16x16, columns = direction, rows = walk frames | `assets/source/packs/ninja_adventure/Actor/Monster/Slime3/Slime3.png` |
| `player_slime/slime_faceset.png` | 38x38 | Slime portrait | `assets/source/packs/ninja_adventure/Actor/Monster/Slime3/Faceset.png` |
| `player_human/human_idle.png` | 64x16 | Human race: 4 directions x 1 frame (16x16) | `assets/source/packs/ninja_adventure/Actor/Character/Boy/SeparateAnim/Idle.png` |
| `player_human/human_walk.png` | 64x64 | Human: 4 directions x 4 frames | `assets/source/packs/ninja_adventure/Actor/Character/Boy/SeparateAnim/Walk.png` |
| `player_human/human_attack.png` | 64x16 | Human: 4 directions x 1 frame | `assets/source/packs/ninja_adventure/Actor/Character/Boy/SeparateAnim/Attack.png` |
| `player_human/human_dead.png` | 16x16 | Human: defeated pose | `assets/source/packs/ninja_adventure/Actor/Character/Boy/SeparateAnim/Dead.png` |
| `player_human/human_faceset.png` | 38x38 | Human portrait | `assets/source/packs/ninja_adventure/Actor/Character/Boy/Faceset.png` |
| `player_demon/demon_idle.png` | 64x16 | Demon race: 4 directions x 1 frame | `assets/source/packs/ninja_adventure/Actor/Character/DemonRed/SeparateAnim/Idle.png` |
| `player_demon/demon_walk.png` | 64x64 | Demon: 4 directions x 4 frames | `assets/source/packs/ninja_adventure/Actor/Character/DemonRed/SeparateAnim/Walk.png` |
| `player_demon/demon_attack.png` | 64x16 | Demon: 4 directions x 1 frame | `assets/source/packs/ninja_adventure/Actor/Character/DemonRed/SeparateAnim/Attack.png` |
| `player_demon/demon_dead.png` | 16x16 | Demon: defeated pose | `assets/source/packs/ninja_adventure/Actor/Character/DemonRed/SeparateAnim/Dead.png` |
| `player_demon/demon_faceset.png` | 38x38 | Demon portrait | `assets/source/packs/ninja_adventure/Actor/Character/DemonRed/Faceset.png` |
| `gnasher/gnasher_idle.png` | 128x32 | Forest Gnasher (user: Goblin look): 4 frames of 32x32 | `assets/source/packs/pixel_crawler/Entities/Mobs/Orc Crew/Orc/Idle/Idle-Sheet.png` |
| `gnasher/gnasher_run.png` | 384x64 | Gnasher: 6 frames of 64x64 | `assets/source/packs/pixel_crawler/Entities/Mobs/Orc Crew/Orc/Run/Run-Sheet.png` |
| `gnasher/gnasher_death.png` | 384x64 | Gnasher: 6 frames of 64x64 | `assets/source/packs/pixel_crawler/Entities/Mobs/Orc Crew/Orc/Death/Death-Sheet.png` |
| `thornback/thornback_idle.png` | 128x32 | Thornback Gnasher (red hood, clearly another enemy): 4 frames of 32x32 | `assets/source/packs/pixel_crawler/Entities/Mobs/Orc Crew/Orc - Shaman/Idle/Idle-Sheet.png` |
| `thornback/thornback_run.png` | 384x64 | Thornback: 6 frames of 64x64 | `assets/source/packs/pixel_crawler/Entities/Mobs/Orc Crew/Orc - Shaman/Run/Run-Sheet.png` |
| `thornback/thornback_death.png` | 448x64 | Thornback: 6 frames of 64x64 | `assets/source/packs/pixel_crawler/Entities/Mobs/Orc Crew/Orc - Shaman/Death/Death-Sheet.png` |
| `ally_goblin/goblin_idle.png` | 128x32 | Nameless goblin ally (brown hood, distinct from enemies): 4 frames of 32x32 | `assets/source/packs/pixel_crawler/Entities/Mobs/Orc Crew/Orc - Rogue/Idle/Idle-Sheet.png` |
| `ally_goblin/goblin_run.png` | 384x64 | Goblin ally: 6 frames of 64x64 | `assets/source/packs/pixel_crawler/Entities/Mobs/Orc Crew/Orc - Rogue/Run/Run-Sheet.png` |
| `hobgoblin/hobgoblin_idle.png` | 128x32 | Named Hobgoblin (armored; naming visibly evolves the ally): 4 frames of 32x32 | `assets/source/packs/pixel_crawler/Entities/Mobs/Orc Crew/Orc - Warrior/Idle/Idle-Sheet.png` |
| `hobgoblin/hobgoblin_run.png` | 384x64 | Hobgoblin: 6 frames of 64x64 | `assets/source/packs/pixel_crawler/Entities/Mobs/Orc Crew/Orc - Warrior/Run/Run-Sheet.png` |
| `fx/slash.png` | 128x32 | Basic strike / sword slash effect | `assets/source/packs/ninja_adventure/FX/Attack/SlashCurved/SpriteSheet.png` |
| `fx/claw.png` | 128x32 | Bite/claw skills (Rending Bite, Shadow Claw) | `assets/source/packs/ninja_adventure/FX/Attack/Claw/SpriteSheet.png` |

## Effects (step 23, `tools/prepare_audio.py`)

| File | Size | Frames | Source |
| --- | --- | --- | --- |
| `fx/hit_spark.png` | 192x32 | 6 frames of 32x32 | `assets/source/packs/ninja_adventure/FX/Magic/Circle/SpriteSheetSpark.png` |
| `fx/ring.png` | 128x32 | 4 frames of 32x32 | `assets/source/packs/ninja_adventure/FX/Magic/Circle/SpriteSheetWhite.png` |
| `fx/sparkle.png` | 270x35 | 9 frames of 30x35 | `assets/source/packs/ninja_adventure/FX/Magic/Spark/SpriteSheet.png` |
| `fx/aura.png` | 125x24 | 5 frames of 25x24 | `assets/source/packs/ninja_adventure/FX/Magic/Aura/SpriteSheet.png` |
| `fx/boost.png` | 424x35 | 8 frames of 53x35 | `assets/source/packs/ninja_adventure/FX/Magic/Boost/SpriteSheet.png` |
| `fx/smoke.png` | 192x32 | 6 frames of 32x32 | `assets/source/packs/ninja_adventure/FX/Smoke/Smoke/SpriteSheet.png` |

## Region creatures and shopkeepers (M4.5c, `tools/prepare_creatures.py`)

Copies of Ninja Adventure sheets (CC0): 64x64, four columns (down, up, left, right) by four walk frames of 16x16, drawn with SpriteLibrary's four-direction sets; shopkeepers also keep the 38x38 portrait (`*_face.png`) for the shop window. Preview: `docs/asset_previews/region_creatures.png`.

| Folder | Source (Actor/…) | Used for |
| --- | --- | --- |
| `frost_bear`, `snow_wisp` | Monster/Bear, Monster/Spirit | Frostpeak creatures |
| `dune_viper`, `sand_scuttler` | Monster/Snake, Monster/SpiderYellow | Sunscorch Desert creatures |
| `bog_kappa`, `mirecap` | Monster/KappaGreen, Monster/Mushroom | Mirewood Marsh creatures |
| `bamboo_sprite`, `paper_lantern` | Monster/Bamboo, Monster/LanternRed | Sakura Vale creatures |
| `amber_owl`, `burrow_mole` | Monster/Owl, Monster/Mole | Ambervale creatures |
| `ember_flame`, `salamander` | Monster/Flam, Monster/Reptile2 | Emberreach creatures |
| `merchant_verdant`, `merchant_harrow`, `merchant_frost`, `merchant_desert`, `merchant_sakura`, `merchant_amber`, `merchant_marsh`, `merchant_ember` | Character/Villager, Noble, Eskimo, Sultan, Monk, Hunter, Shaman, OldMan | Town merchants |
| `camp_trader`, `camp_smith`, `traveller`, `ferryman`, `shipwright` | Character/Woman, FighterWhite, MaskRacoon, OldMan2, Inspector | Hired camp staff, the travelling merchant, the harbours' ferrymen and shipwrights |

Mounts (M4.5d): `mount_donkey`, `mount_horse`, `mount_black_horse`, `mount_wild_boar`, `mount_lion` hold `front.png` and `side.png` copied from Actor/Animal (Donkey grey, Horse brown/black, WildBoar, Lion orange); two walk frames each (the boar has only a side view).

Ki Realm (M4.7), same four-direction format:

| Folder | Source (Actor/…) | Used for |
| --- | --- | --- |
| `raptor`, `tyrant_rex` | Monster/Dragon, Monster/TRex | Raptor Gulch's dinosaurs |
| `gi_fighter`, `monkey_brawler` | Character/FighterRed, MonkeyBoxerRed | Martial artists (canyon, tournament) |
| `android_scout`, `bio_android`, `android_tank` | Character/RobotGrey, RobotGreen, RobotCamouflage | The Android Works |
| `demon_king` | Character/DemonRed | The canyon's boss and the tournament's final bout |
| `secret_hermit`, `realm_guide`, `turtle_sage`, `spire_sage`, `guardian`, `canyon_hermit`, `mountain_master`, `announcer` | Character/OldMan3 (both), Master, CaveLion, MaskFrog, Caveman2, Tengu, Villager5 | The hermit in Sakura Vale, the guide, the mentors and the tournament's announcer |

Citizens (M5b): `citizen_1` … `citizen_6` from Character/Villager2, Villager3, Villager4, Villager6, Boy and Cavegirl (same four-direction format).

Quest givers (M9c): `npc_<id>` hold `npc_<id>_walk.png` (four-direction walk sheet, same format) and `npc_<id>_face.png` (38 × 38 portrait), copied unchanged from Actor/Character: orrin OldMan, maren Knight, vex Vampire, regent SorcererBlack, hilde Woman, rowan OldMan2, nessa Villager2, alric Monk, ulla Eskimo, steward Sultan, bram Villager3, moss Shaman, kaito Samurai, ignis Flam, temur NinjaYellow, morwen SorcererOrange, lin Monk2, inspector Inspector, princess Princess, hunter Hunter. `npc_lumi/npc_lumi_face.png` is Character/Spirit's Faceset tinted gold (Lumi, the star-sprite; portrait only).

Licences and credits: see `CREDITS.md` at the repository root and the licence files next to each pack in `assets/source/packs/`.
