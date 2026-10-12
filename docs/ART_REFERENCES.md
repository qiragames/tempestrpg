# Sprite reference and integration plan

The user supplied a monster animation reference chart in chat on 2026-10-12. It shows Ogre, Orc, Goblin, Skeleton, Slime, Dark Knight, Necromancer, and Devil rows, each organized into idle, walk, attack, and death animation examples.

Use the blue slime as the first player animation reference; keep the larger silhouettes for later enemies and evolution. Idle, walk, attack, and death should map to separate animation states. Future evolved forms should visibly change silhouette rather than only tinting the same frame.

The supplied chart has labels, borders, a background, and uneven frame sizes. No clean sprite texture has been imported yet, and the source image is currently in the conversation rather than saved in this repository. The current game continues using procedural placeholders. Obtain or prepare individual frames/a clean sheet before replacing them; use nearest filtering, consistent feet/pivot alignment, and separate collision geometry from sprite bounds.

Integration order: slime idle/walk → strike/death → first enemy animations → future race/evolution variants. Preserve combat timing independently of the artwork; animation changes must not bypass cooldowns, Magicule costs, or defeat states.

## Forest and goblin village tileset

The user supplied a world-building chart on 2026-10-12 showing terrain/auto-tiles (grass, dirt paths, stone paving, cliff edges and stairs), foliage (trees, shrubs, rocks, stumps, logs), modular structures (thatch roofs, wall/door pieces, palisades, fences, gates, complete huts), and village utilities (crates, barrels, stalls, campfires, cooking pots, signs, wells, carts and tents).

Use this direction for the initial forest and later goblin camp. Build terrain with Godot TileMapLayer/TileSet terrain sets; place larger trees, buildings, and interactive props separately. Define collision only on trunks, rocks, walls, cliffs and relevant obstacles; do not make every canopy pixel solid. Preserve walkable doorways, player foot alignment, and vertical sorting around structures.

The chart includes headings, backgrounds, irregular layouts, and some multi-tile objects. It is a reference rather than a ready imported TileSet. A clean atlas with tile dimensions (plus separately prepared large props) is needed before creating terrain connections and collision polygons. The source image remains in the conversation; the repository currently contains reference notes, not the image itself. Art replacement remains a future step; the current clearing uses procedural placeholders.

## Shared image storage

Both Claude Code and Codex use `assets/README.md` and `assets/references/index.json`. The index records the original-image paths and their actual availability. Since 2026-10-12 the monster chart, an additional ogre-only animation sheet (`sprites/ogre_animation_reference.jpg`), the forest/goblin village tileset, the title screen, the pause menu, the inventory screen and the gameplay HUD are stored in Git; no listed original is missing. Preserve originals under `assets/references/`, working art under `assets/source/`, and prepared textures under `assets/game/`. Descriptions alone do not supply image bytes.
