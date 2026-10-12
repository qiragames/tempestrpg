# TempestRPG

A Godot **4.6.3** / GDScript prototype for a top-down pixel-art Isekai RPG.

## Play

Open `project.godot` in Godot 4.6.3 and press **F5** to run the project. Move with **WASD / arrow keys**, strike in your facing direction with **Space / J**, and restart with **R**. Explore as a placeholder slime; trees, rocks, water, and the map edge have collision.

The initial foundation uses a 480 × 320 viewport, integer scaling, nearest texture filtering, and a bounded player camera. Art is a procedural placeholder. One Forest Gnasher notices you within 180 pixels, chases at 55 pixels/second, and pauses for a 0.35-second bite windup. Dodge away while it turns orange. It recovers for 0.9 seconds before attacking again. Its basic AI can collide with terrain; pathfinding is not implemented.

The player has 100 HP and 0.65-second damage immunity. Bites deal 12 damage; aura-assisted directional strikes deal 10 damage, cost **8 Magicules**, and have a 0.4-second cooldown. A strike spends its cost even if it misses. The shared Magicule pool starts at **100**, regenerates **6 per second** after **1.5 seconds** without successful spending, and is shown as a number and bar. Unaffordable strikes fail without damage or cooldown; moving remains free so you can retreat and recover. Cooldown rejection does not spend resources or postpone recovery. Defeat stops recovery; restarting restores the pool.

The enemy has 30 HP and a visible health bar. Strike range and obstruction checks prevent attacks through terrain. Defeated creatures remain for the upcoming absorption mechanic; a defeated player must restart. Skills, absorption, naming, and naming-induced sleep remain planned. The shared resource component is ready to support their future costs; current numbers are prototype balance values.

The user's supplied sprite chart is recorded in `docs/ART_REFERENCES.md` for later animation integration; it has not replaced the placeholder artwork yet.

## Cloud commands

```bash
cd /workspace/tempestrpg
source /workspace/.tempestrpg/env.sh
"$GODOT_BIN" --headless --path . --editor --import
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/smoke.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/combat.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/magicules.gd
"$GODOT_BIN" --headless --path . --quit-after 120
```

The cloud checks validate import, 17 foundation checks, 24 combat checks, and 27 Magicule checks. These exercise movement/collision, enemy behavior, strike rules, spending failures, HUD state, delayed regeneration, depletion/recovery, invalid values, resource bounds, defeat, and restart. The final command runs the actual main scene for 120 frames. To play visually on a computer with a display, run `godot --path .` or use the editor; headless mode provides automated validation. Visual playtesting is still pending.

## Structure

- `scenes/player`, `scripts/player`: reusable player and movement.
- `scenes/world`, `scripts/world`: initial clearing and shared obstacle geometry.
- `scripts/combat`: shared health and directional strike components.
- `scripts/resources`: shared Magicule spending, restoration, and regeneration.
- `scenes/enemies`, `scripts/enemies`: Forest Gnasher encounter and state machine.
- `tests/smoke.gd`: integration checks using the actual game scene.
- `tests/combat.gd`: combat encounter and edge-case checks.
- `tests/magicules.gd`: resource and gameplay integration checks.
- `ROADMAP.md`: project goals and progress; `ROADMAP.html`: interactive dependency graph.

After roadmap changes, run `python3 tools/build_roadmap.py` to update the graph.
