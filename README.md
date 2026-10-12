# TempestRPG

A Godot **4.6.3** / GDScript prototype for a top-down pixel-art Isekai RPG.

## Play

Open `project.godot` in Godot 4.6.3 and press **F5** to run the project. Move with **WASD / arrow keys**, strike with **Space / J**, absorb with **E**, use hotbar slots with **1–3** or a click, open storage with **I**, and use **F8** for Host/Join or **F9** for host save. **R** retries offline or respawns a defeated hosted character. Explore as a placeholder slime; trees, rocks, water, and the map edge have collision.

The initial foundation uses a 480 × 320 viewport, integer scaling, nearest texture filtering, and a bounded player camera. Art is a procedural placeholder. One Forest Gnasher notices you within 180 pixels, chases at 55 pixels/second, and pauses for a 0.35-second bite windup. Dodge away while it turns orange. It recovers for 0.9 seconds before attacking again. Its basic AI can collide with terrain; pathfinding is not implemented.

The player has 100 HP and 0.65-second damage immunity. Bites deal 12 damage; aura-assisted directional strikes deal 10 damage, cost **8 Magicules**, and have a 0.4-second cooldown. A strike spends its cost even if it misses. The shared Magicule pool starts at **100**, regenerates **6 per second** after **1.5 seconds** without successful spending, and is shown as a number and bar. Unaffordable strikes fail without damage or cooldown; moving remains free so you can retreat and recover. Cooldown rejection does not spend resources or postpone recovery. Defeat stops recovery; restarting restores the pool.

The two starting enemies have 30 HP each and visible health bars. Strike range and obstruction checks prevent attacks through terrain. Defeated creatures remain available for absorption; a defeated player must restart. Naming and naming-induced sleep remain planned. The shared resource component is ready to support their future costs; current numbers are prototype balance values.

## Absorption and analysis

After defeating the Gnasher, stand within 36 pixels of its body and press **E**. Analysis costs **12 Magicules** and takes **1.2 seconds** beside an unobstructed specimen. The analysis panel shows progress; completion consumes the body and learns the **Common Skill Rending Bite**. Duplicate specimens do not stack the same learned skill. Leaving range, moving behind terrain, or being defeated interrupts analysis: its cost is spent, but the corpse remains available. Magicule drops are independent of corpse absorption.

Skill/specimen definitions live in `data/skills` and `data/specimens`. Hosted characters persist their acquired skills and materials. The initial offline sandbox remains session-local; R resets that sandbox. Hosted multiplayer/save foundations are implemented (N0); ally/naming progression is next (M2).

## Skill hotbar and dimensional storage

Rending Bite auto-equips in slot **1** after analysis. Use **1** or click its button for a directional **20-damage** strike costing **12 Magicules**, with a **0.8-second cooldown**. It shares attack recovery with the basic strike so alternating keys cannot bypass cooldowns. Slots 2–3 stay empty until other skills exist. The hotbar shows resource costs and cooldown state, and rejects use before acquisition, after defeat, or with insufficient Magicules. A second Gnasher in the clearing lets you try the acquired skill.

Each completed analysis retains one **Gnasher Essence** in dimensional storage, even when its skill was already known. **I** opens a dark framed material bag with stack counts, capacity, item details, and **Discard 1**. **I / Escape / Close** resumes the game. In offline mode, opening the bag pauses gameplay. In hosted multiplayer, it blocks only the local player’s movement/actions; enemies, other players, resources, and analysis continue. The capacity is **20 material units**; a full bag prevents absorption without charging its cost. If it fills during analysis, the channel cancels and retains the corpse. Discarding essence does not remove learned skills.

The HUD binds to the local character and includes an event log, acquired-skill slots, and a Host/Join panel. The bag is a functional prototype following the supplied UI direction; equipment, category tabs beyond materials, usable items, paper-doll rendering, title/main pause screens, and final imported art remain future work. Neither gear stats nor sample items from the references are fabricated into the game.

## Enemy difficulty and drops

Defeated mobs leave a cyan Magicule pickup at their position. Walk close to collect it. Full reserves leave the pickup intact; partial collection retains the unused amount for later. Terrain blocks collection, defeated players cannot collect, and each enemy drops only once. Restart clears the encounter and its pickups.

The reusable Forest Gnasher's `difficulty` property selects real stats and rewards:

| Difficulty | HP | Bite damage | Speed | Magicule drop |
| --- | --- | --- | --- | --- |
| Easy | 20 | 8 | 45 | 8 |
| Standard | 30 | 12 | 55 | 16 |
| Elite | 60 | 20 | 65 | 32 |

The clearing uses two Standard-difficulty Gnashers. Change an enemy instance's difficulty in the Inspector before running to try the other tiers. Easy is green, Standard is tan, and Elite is purple; orange still marks a bite windup. Drops restore current reserves, rather than increasing capacity. Difficulty selection and rewards are prototype balance values, not a player-level scaling system.

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
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/skills_storage.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/persistence.gd
python3 tests/network_integration.py
"$GODOT_BIN" --headless --path . --quit-after 120
```

The cloud checks validate import, 17 foundation checks, 24 combat checks, 27 Magicule checks, 32 drop checks, 26 absorption checks, 35 skills/storage checks, 32 persistence checks, and 68 real multi-process networking checks. These exercise movement/collision, enemy behavior, strike rules, spending failures, HUD state, delayed regeneration, depletion/recovery, invalid values, resource bounds, tier rewards, pickup proximity/overflow/obstruction, defeat, and restart. The final command runs the actual main scene for 120 frames. To play visually on a computer with a display, run `godot --path .` or use the editor; headless mode provides automated validation. Visual playtesting is still pending. Networking was tested on loopback with one host plus seven simultaneous guests; real LAN/WAN connectivity and performance on your machines still need playtesting.

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

- `scripts/inventory`, `scripts/ui`: dimensional-storage model and hotbar/bag/event-log presentation.
- `tests/skills_storage.gd`: complete acquisition/use loop, inventory transactions, UI controls, and pause behavior.

## Hosted multiplayer and saves

**8 players total: 1 host + 7 guests.** Press **F8**, choose **Host saved world**, and have friends choose **Join address** with your machine’s LAN IP. The default is **UDP 24560**. Do not use `127.0.0.1` from a different machine; that address refers to that friend’s computer.

The host owns movement, combat, drops, corpse claims, skills, inventories, and world saves. Clients send validated intentions. Enemies select nearby living players; each HUD and bag belongs to its local character. One player opening inventory does not pause everyone else. R respawns a defeated character with its learned skills, inventory, level and current Magicules retained; living characters cannot use respawn to reset health.

Save locations (Godot application user-data folder):

- `user://worlds/forest.json`: host world and all registered character records.
- The adjacent `.bak`: previous valid save, used if the primary is corrupt.
- `user://profiles/characters.json`: each client’s private reconnect identities. Keep this file on that player’s machine; do not commit or share it. Losing it requires a new character rather than claiming another character’s ID.

Hosting loads the world if it exists; invalid saves with no valid backup are preserved and hosting stops. Saves use a versioned schema, validation, a temporary file and atomic rename. Saving happens on important reward/inventory/defeat changes, guest join/disconnect, **F9**, every **15 seconds**, and normal window close. A force-killed process can restore only its last completed save. Offline characters stop simulating. Disconnected or reloaded analysis channels are interrupted with no cost refund; their unconsumed corpse remains available.

Current saves cover stable world/character/entity IDs, positions/facing, implemented stats, HP and Magicules/recovery timers, learned skills/loadout, materials/capacity, attack recovery, enemy state, and remaining pickups. Character progression dictionaries include level/experience/race and reserved personal quest/equipment state; shared progression holds world time and quest/settlement dictionaries. Actual XP, equipment, quest and settlement gameplay is not implemented yet. Each later feature must extend the validated schema rather than fabricate sample progression.

CLI launch with your Godot executable:

```bash
godot --path . -- --host
godot --path . -- --join=192.168.1.10
```

Optional arguments: `--port=24560`, host `--save=/path/to/world.json`, client `--identity=/path/to/private-profile.json`. Use distinct identity files when testing multiple guests on the same computer. Start the host first and keep that process running. Host changes are saved on its machine; clients’ profiles reconnect them to the same characters after host restart.

This is a desktop/LAN prototype. It uses ENet/UDP, host-verified reconnect credentials and reliable full-state snapshots; encrypted transport, latency prediction, and Internet deployment are not implemented/tested. Joining across the Internet also requires a reachable host (typically UDP port forwarding and a firewall allowance on the host machine). LAN playtesting comes first; do not treat the loopback checks as proof that Internet connectivity works.

Architecture and future persistence requirements: `docs/MULTIPLAYER_AND_SAVES.md`. Networking/persistence code: `scripts/network`, `scripts/persistence`. Source code is on GitHub; world saves and reconnect profiles remain private user data.
