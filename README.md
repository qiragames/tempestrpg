# TempestRPG

A Godot **4.6.3** / GDScript prototype for a top-down pixel-art Isekai RPG.

## Play

Open `project.godot` in Godot 4.6.3 and press **F5** to run the project. Move with **WASD / arrow keys**, strike in your facing direction with **Space / J**, and restart with **R**. Explore as a placeholder slime; trees, rocks, water, and the map edge have collision.

The initial foundation uses a 480 × 320 viewport, integer scaling, nearest texture filtering, and a bounded player camera. Art is a procedural placeholder. One Forest Gnasher notices you within 180 pixels, chases at 55 pixels/second, and pauses for a 0.35-second bite windup. Dodge away while it turns orange. It recovers for 0.9 seconds before attacking again. Its basic AI can collide with terrain; pathfinding is not implemented.

The player has 100 HP and 0.65-second damage immunity. Bites deal 12 damage; aura-assisted directional strikes deal 10 damage, cost **8 Magicules**, and have a 0.4-second cooldown. A strike spends its cost even if it misses. The shared Magicule pool starts at **100**, regenerates **6 per second** after **1.5 seconds** without successful spending, and is shown as a number and bar. Unaffordable strikes fail without damage or cooldown; moving remains free so you can retreat and recover. Cooldown rejection does not spend resources or postpone recovery. Defeat stops recovery; restarting restores the pool.

The enemy has 30 HP and a visible health bar. Strike range and obstruction checks prevent attacks through terrain. Defeated creatures remain available for absorption; a defeated player must restart. Naming and naming-induced sleep remain planned. The shared resource component is ready to support their future costs; current numbers are prototype balance values.

## Absorption and analysis

After defeating the Gnasher, stand within 36 pixels of its body and press **E**. Analysis costs **12 Magicules** and takes **1.2 seconds** beside an unobstructed specimen. The analysis panel shows progress; completion consumes the body and learns the **Common Skill Rending Bite**. Duplicate specimens do not stack the same learned skill. Leaving range, moving behind terrain, or being defeated interrupts analysis: its cost is spent, but the corpse remains available. Magicule drops are independent of corpse absorption.

Skill/specimen definitions live in `data/skills` and `data/specimens`. Acquired skills are currently session-local; restarting resets them. Skill activation and dimensional storage are the next roadmap step; save/load is planned for M2.

## Enemy difficulty and drops

Defeated mobs leave a cyan Magicule pickup at their position. Walk close to collect it. Full reserves leave the pickup intact; partial collection retains the unused amount for later. Terrain blocks collection, defeated players cannot collect, and each enemy drops only once. Restart clears the encounter and its pickups.

The reusable Forest Gnasher's `difficulty` property selects real stats and rewards:

| Difficulty | HP | Bite damage | Speed | Magicule drop |
| --- | --- | --- | --- | --- |
| Easy | 20 | 8 | 45 | 8 |
| Standard | 30 | 12 | 55 | 16 |
| Elite | 60 | 20 | 65 | 32 |

The clearing uses Standard difficulty. Change an enemy instance's difficulty in the Inspector before running to try the other tiers. Easy is green, Standard is tan, and Elite is purple; orange still marks a bite windup. Drops restore current reserves, rather than increasing capacity. Difficulty selection and rewards are prototype balance values, not a player-level scaling system.

The user's supplied sprite chart is recorded in `docs/ART_REFERENCES.md` for later animation integration; it has not replaced the placeholder artwork yet.

## Cloud commands

```bash
cd /workspace/tempestrpg
source /workspace/.tempestrpg/env.sh
"$GODOT_BIN" --headless --path . --editor --import
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/smoke.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/combat.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/magicules.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/drops.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/absorption.gd
"$GODOT_BIN" --headless --path . --quit-after 120
```

The cloud checks validate import, 17 foundation checks, 24 combat checks, 27 Magicule checks, 32 drop checks, and 26 absorption checks. These exercise movement/collision, enemy behavior, strike rules, spending failures, HUD state, delayed regeneration, depletion/recovery, invalid values, resource bounds, tier rewards, pickup proximity/overflow/obstruction, defeat, and restart. The final command runs the actual main scene for 120 frames. To play visually on a computer with a display, run `godot --path .` or use the editor; headless mode provides automated validation. Visual playtesting is still pending.

## Structure

- `scenes/player`, `scripts/player`: reusable player and movement.
- `scenes/world`, `scripts/world`: initial clearing and shared obstacle geometry.
- `scripts/combat`: shared health and directional strike components.
- `scripts/resources`: shared Magicule spending, restoration, and regeneration.
- `scenes/pickups`, `scripts/pickups`: collectible Magicule drops.
- `scenes/enemies`, `scripts/enemies`: Forest Gnasher encounter and state machine.
- `tests/smoke.gd`: integration checks using the actual game scene.
- `tests/combat.gd`: combat encounter and edge-case checks.
- `tests/magicules.gd`: resource and gameplay integration checks.
- `tests/drops.gd`: enemy-tier rewards and collection integration checks.
- `scripts/absorption`, `scripts/skills`, `data`: analysis, acquired-skill book, and creature/skill definitions.
- `tests/absorption.gd`: acquisition, channel interruption, duplicates, and restart.
- `ROADMAP.md`: project goals and progress; `ROADMAP.html`: interactive dependency graph.

After roadmap changes, run `python3 tools/build_roadmap.py` to update the graph.
