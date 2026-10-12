# Sprite reference and integration plan

The user supplied a monster animation reference chart in chat on 2026-10-12. It shows Ogre, Orc, Goblin, Skeleton, Slime, Dark Knight, Necromancer, and Devil rows, each organized into idle, walk, attack, and death animation examples.

Use the blue slime as the first player animation reference; keep the larger silhouettes for later enemies and evolution. Idle, walk, attack, and death should map to separate animation states. Future evolved forms should visibly change silhouette rather than only tinting the same frame.

The supplied chart has labels, borders, a background, and uneven frame sizes. No clean sprite texture has been imported yet, and the source image is currently in the conversation rather than saved in this repository. The current game continues using procedural placeholders. Obtain or prepare individual frames/a clean sheet before replacing them; use nearest filtering, consistent feet/pivot alignment, and separate collision geometry from sprite bounds.

Integration order: slime idle/walk → strike/death → first enemy animations → future race/evolution variants. Preserve combat timing independently of the artwork; animation changes must not bypass cooldowns, Magicule costs, or defeat states.
