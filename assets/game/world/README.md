# Prepared world tiles and props

Step 18 (asset preparation). Copied unchanged from the third-party packs in `assets/source/packs/` by `tools/prepare_assets.py`; previews (x3, nearest) in `docs/asset_previews/`. **Status: integrated in step 20** through `scripts/visual/world_art.gd` (regions used: light-grass floor row, the dirt and pond nine-slices, tree/rock/stone/pebble props, hut/storehouse/shrine/standing stone from `house.png`, logs and camp post from `camp.png`, the small anvil station and the fire pit; the rest stays available for later areas).

Pixel scale 1:1 with the 640x360 viewport; nearest filtering (project default). Foot pivot: bottom-centre of each frame unless noted.

| File | Size | Frames / layout | Source |
| --- | --- | --- | --- |
| `terrain_field.png` | 80x240 | Grass ground, 16x16 tiles | `assets/source/packs/ninja_adventure/Backgrounds/Tilesets/TilesetField.png` |
| `terrain_floor.png` | 352x417 | Paths, dirt and ground autotiles, 16x16 | `assets/source/packs/ninja_adventure/Backgrounds/Tilesets/TilesetFloor.png` |
| `terrain_floor_detail.png` | 256x80 | Ground details (flowers, cracks), 16x16 | `assets/source/packs/ninja_adventure/Backgrounds/Tilesets/TilesetFloorDetail.png` |
| `water.png` | 448x272 | Water, shores and lily pads (pond, later the sea), 16x16 | `assets/source/packs/ninja_adventure/Backgrounds/Tilesets/TilesetWater.png` |
| `nature.png` | 384x336 | Trees (incl. pink/snowy biomes), rocks, bushes, flowers; multi-tile props | `assets/source/packs/ninja_adventure/Backgrounds/Tilesets/TilesetNature.png` |
| `relief.png` | 320x192 | Cliffs and elevation, 16x16 | `assets/source/packs/ninja_adventure/Backgrounds/Tilesets/TilesetRelief.png` |
| `house.png` | 528x368 | Buildings for the hut/storehouse and later towns | `assets/source/packs/ninja_adventure/Backgrounds/Tilesets/TilesetHouse.png` |
| `camp.png` | 368x144 | Camp props: tents, fire, crates | `assets/source/packs/ninja_adventure/Backgrounds/Tilesets/tileset_camp.png` |
| `boat.png` | 80x32 | Boat for the M4.5 ferries/ships | `assets/source/packs/ninja_adventure/Backgrounds/Vehicles/Boat.png` |
| `sail.png` | 30x43 | Sail for the M4.5 ships | `assets/source/packs/ninja_adventure/Backgrounds/Vehicles/Sail.png` |
| `station_anvil.png` | 272x160 | Forge: anvil station sheet | `assets/source/packs/pixel_crawler/Environment/Structures/Stations/Anvil/Anvil.png` |
| `station_bonfire.png` | 64x384 | Camp flag/bonfire sheet | `assets/source/packs/pixel_crawler/Environment/Structures/Stations/Bonfire/Bonfire.png` |

## Archipelago sheets (M4.5a, `tools/prepare_world.py`)

| File | Size | Source | Used for |
| --- | --- | --- | --- |
| `ruins.png` | 320x192 | Ninja Adventure `TilesetVillageAbandoned.png` (copy) | Lakeward Keep and Ambervale ruins |
| `desert.png` | 320x192 | Ninja Adventure `TilesetDesert.png` (copy) | Harrowmere walls and tower |
| `lava.png` | 448x96 | Derived from `water.png` rows 0-5: water → lava, sand → ash (same layout) | Lava pools and ash ground (Cinder Crater, Emberreach) |

Corner sets used by `scripts/world/world_terrain.gd` (16 combinations, shared layout: pond 3x3 at columns 0-2, pond-with-island 4x4 at 4-7, diagonals at column 9, plain land at (0, 5)): `water.png` rows 0-5 (sand shore), rows 6-11 (grass shore, lakes), `lava.png`, `terrain_floor.png` rows 7-12 (dirt paths). Rounded biome overlays: `terrain_field.png` 3x3 patches (grass, forest, autumn).

Licences and credits: see `CREDITS.md` at the repository root and the licence files next to each pack in `assets/source/packs/`.
