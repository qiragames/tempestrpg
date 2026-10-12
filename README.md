# TempestRPG

A Godot **4.6.3** / GDScript prototype for a top-down pixel-art Isekai RPG.

## Play

Open `project.godot` in Godot 4.6.3 and press **F5** to run the project. Move with **WASD / arrow keys**, strike in your facing direction with **Space / J**, and restart with **R**. Explore as a placeholder slime; trees, rocks, water, and the map edge have collision.

The initial foundation uses a 480 × 320 viewport, integer scaling, nearest texture filtering, and a bounded player camera. Art is a procedural placeholder. One Forest Gnasher notices you within 180 pixels, chases at 55 pixels/second, and pauses for a 0.35-second bite windup. Dodge away while it turns orange. It recovers for 0.9 seconds before attacking again. Its basic AI can collide with terrain; pathfinding is not implemented.

The player has 100 HP and 0.65-second damage immunity. Bites deal 12 damage; directional strikes deal 10 damage with a 0.4-second cooldown. The enemy has 30 HP and a visible health bar. Strike range and obstruction checks prevent attacks through terrain. Defeated creatures remain for the upcoming absorption mechanic; a defeated player must restart. Skills, Magicules, absorption, and naming remain planned.

## Cloud commands

```bash
cd /workspace/tempestrpg
source /workspace/.tempestrpg/env.sh
"$GODOT_BIN" --headless --path . --editor --import
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/smoke.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/combat.gd
"$GODOT_BIN" --headless --path . --quit-after 120
```

The cloud checks validate import, 17 foundation checks, and 24 combat checks (detection, chase, bite telegraph/dodge, damage immunity, directional attacks, cooldown, range, obstruction, defeat, and restart). The final command runs the actual main scene for 120 frames. To play visually on a computer with a display, run `godot --path .` or use the editor; headless mode provides automated validation. Visual playtesting is still pending.

## Structure

- `scenes/player`, `scripts/player`: reusable player and movement.
- `scenes/world`, `scripts/world`: initial clearing and shared obstacle geometry.
- `scripts/combat`: shared health and directional strike components.
- `scenes/enemies`, `scripts/enemies`: Forest Gnasher encounter and state machine.
- `tests/smoke.gd`: integration checks using the actual game scene.
- `tests/combat.gd`: combat encounter and edge-case checks.
- `ROADMAP.md`: project goals and progress; `ROADMAP.html`: interactive dependency graph.

After roadmap changes, run `python3 tools/build_roadmap.py` to update the graph.
