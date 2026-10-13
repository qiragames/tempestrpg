# Shared art library — Codex and Claude Code

Both tools use this directory for artwork received from the user and artwork prepared for the game. Commit the actual files, metadata and related notes on the branch doing the art work so the other tool can fetch them. This folder becomes shared through Git; copies sitting only in chat or on one computer are not available to the other tool.

| Directory | What belongs here | Godot import |
| --- | --- | --- |
| `references/sprites/` | Original creature/sprite reference sheets | Excluded via `.gdignore` |
| `references/ui/` | Original HUD/title/pause/inventory reference images | Excluded via `.gdignore` |
| `references/world/` | Original tileset/world-building references | Excluded via `.gdignore` |
| `source/` | Editable art files and working atlases, preserving originals | Excluded via `.gdignore` |
| `game/sprites/` | Prepared character/enemy animation PNGs | Imported normally |
| `game/ui/` | Prepared transparent frames, icons, portraits and backgrounds | Imported normally |
| `game/world/` | Prepared tile atlases and separate props | Imported normally |

## Third-party packs (step 18)

`assets/source/packs/` holds four downloaded packs with their licence files (Ninja Adventure CC0, Pixel Crawler free incl. commercial, Kyrise CC BY 4.0, Shade free). They are listed under `packs` in `references/index.json`; credits in `../CREDITS.md`. `tools/prepare_assets.py` copies the chosen sheets into `game/` unchanged (plus 16x16 gear icons per rarity) and renders x3/x4 previews into `../docs/asset_previews/`. Prepared ≠ integrated: scenes keep the code-drawn placeholders until steps 19–21.

## Original references

`references/index.json` lists the reference images and their paths. Their descriptions are in `docs/ART_REFERENCES.md` and `docs/UI_REFERENCES.md`. As of 2026-10-12, all seven originals are in Git (monster chart, ogre sheet, title screen, pause menu, inventory, gameplay HUD, forest/goblin village tileset; added by Claude from the user's PC/chat). Do not mark an entry available or imported until the actual file exists.

When the user supplies PNG/JPG files or a ZIP, place each original at the path in the index, preserving its pixels. Set its `status` to `available`, add its `sha256` and dimensions, and commit the image and index together. If Claude already has the originals on the user's computer, Claude can add them directly to these paths and push. Keep future entries in the same index. Record source/credit details when supplied.

## Preparing game art

- Preserve originals; save edits/crops/atlases in `source/` and exported textures in `game/`.
- Use lowercase descriptive names, for example `slime_idle.png` or `forest_terrain_atlas.png`. Add a nearby Markdown note for sprite frame dimensions, animation order/timing, tile dimensions, pivots, transparency and intended scene usage.
- Prefer transparent PNG for individual sprites/UI pieces. Use nearest filtering; preserve consistent foot pivots, collision geometry and pixel scale. Current viewport: 640 × 360 (shown at ×3 = 1920 × 1080).
- Reference charts contain labels, backgrounds and irregular frames; storing them does not make them ready-to-use animation/TileSet assets. Prepare and inspect real exports before replacing placeholders.
- Keep UI labels/stats dynamic rather than baked into gameplay textures. Keep combat timing, costs, authority and saves independent of art.
- Store source images and preparation notes in Git. Godot's generated `.godot/` cache remains ignored. A stored/prepared asset is not integrated until scenes/resources use it and relevant checks pass.

## Coordination

Read `AGENTS.md`, `CLAUDE.md` and `docs/AI_HANDOFF.md` before changes. Claim the specific assets/files before overlapping art edits, check remote branches for additions, and acknowledge the other tool's handoff. Update the index and handoff with actual availability/preparation/integration status. Do not overwrite another tool's source art or recreate a missing user reference and label it as the original.
