# TempestRPG

A Godot **4.6.3** / GDScript prototype for a top-down pixel-art Isekai RPG.

## Play

Open `project.godot` in Godot 4.6.3 and press **F5** to run the project. The game opens at the **title menu**: create a **New World** (name and optional seed), **Load World** from your saves, or **Join a Friend**. In a world, move with **WASD / arrow keys**, strike with **Space / J**, absorb with **E**, use hotbar slots with **1–4** or a click, open storage with **I**, open the skill tree with **K**, press **Esc** for the pause menu (Resume, Open to friends, Save, Save & quit to title) and **F9** to save. **T** switches mimic form, **R** retries offline or respawns a defeated hosted character. Explore as a placeholder slime; trees, rocks, water, and the map edge have collision.

The game renders at a 640 × 360 base resolution (×2 = 1280 × 720 default window, ×3 = 1920 × 1080 fullscreen), integer scaling, nearest texture filtering, and a bounded player camera. Art is a procedural placeholder. One Forest Gnasher notices you within 180 pixels, chases at 55 pixels/second, and pauses for a 0.35-second bite windup. Dodge away while it turns orange. It recovers for 0.9 seconds before attacking again. Its basic AI can collide with terrain; pathfinding is not implemented.

The player has 100 HP and 0.65-second damage immunity. Bites deal 12 damage; aura-assisted directional strikes deal 10 damage, cost **8 Magicules**, and have a 0.4-second cooldown. A strike spends its cost even if it misses. The shared Magicule pool starts at **100**, regenerates **6 per second** after **1.5 seconds** without successful spending, and is shown as a number and bar. Unaffordable strikes fail without damage or cooldown; moving remains free so you can retreat and recover. Cooldown rejection does not spend resources or postpone recovery. Defeat stops recovery; restarting restores the pool.

The two starting enemies have 30 HP each and visible health bars. Strike range and obstruction checks prevent attacks through terrain. Defeated creatures remain available for absorption; a defeated player must restart. Naming can cause temporary sleep; current numbers are prototype balance values.

## Absorption and analysis

After defeating the Gnasher, stand within 36 pixels of its body and press **E**. Analysis costs **12 Magicules** and takes **1.2 seconds** beside an unobstructed specimen. The analysis panel shows progress; completion consumes the body and learns the **Common Skill Rending Bite**. Duplicate specimens do not stack the same learned skill. Leaving range, moving behind terrain, or being defeated interrupts analysis: its cost is spent, but the corpse remains available. Magicule drops are independent of corpse absorption.

Skill/specimen definitions live in `data/skills` and `data/specimens`. Hosted characters persist their acquired skills and materials. The initial offline sandbox remains session-local; R resets that sandbox. Hosted multiplayer/save foundations are implemented (N0); first-ally naming/evolution is implemented (M2).

## Skill hotbar and dimensional storage

Analysis learns Rending Bite; press **K** and spend a skill point to activate it. Activation fills the first free hotbar slot. Use **1** or click its button for a directional **20-damage** strike costing **12 Magicules**, with a **0.8-second cooldown**. It shares attack recovery with the basic strike so alternating keys cannot bypass cooldowns. Other slots fill as you activate acquired skills or buy tree skill nodes. The hotbar shows resource costs and cooldown state, and rejects use before acquisition, after defeat, or with insufficient Magicules. A second Gnasher in the clearing lets you try the acquired skill.

Each completed analysis retains one **Gnasher Essence** in dimensional storage, even when its skill was already known. **I** opens a dark framed material bag with stack counts, capacity, item details, and **Discard 1**. **I / Escape / Close** resumes the game. In offline mode, opening the bag pauses gameplay. In hosted multiplayer, it blocks only the local player’s movement/actions; enemies, other players, resources, and analysis continue. The capacity is **20 material units**; a full bag prevents absorption without charging its cost. If it fills during analysis, the channel cancels and retains the corpse. Discarding essence does not remove learned skills.

The HUD binds to the local character and includes an event log, acquired-skill slots, and the title/pause session flow. The bag is a functional prototype following the supplied UI direction; equipment, category tabs beyond materials, usable items, paper-doll rendering, final title/pause presentation and imported art remain future work. Neither gear stats nor sample items from the references are fabricated into the game.

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
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/allies.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/naming.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/settlement.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/ally_work.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/camp_growth.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/skill_catalogue.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/extra_skill.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/mimic_form.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/trial_unique.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/absorb_healing.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/worlds_menu.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/seeded_worlds.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/leveling.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/races.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/skill_tree.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/fusion.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/respawn.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/gear.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/weapons.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/gear_sources.gd
python3 tests/network_integration.py
python3 tests/network_settlement.py
python3 tests/network_forms.py
python3 tests/network_trial.py
python3 tests/network_worlds.py
"$GODOT_BIN" --headless --path . --quit-after 120
```

The cloud checks validate import, 26 local gameplay/persistence/UI suites (847 checks) and 266 real multi-process networking checks (1113 total through the naming/mimic update after step 17f, independently verified on Linux and reported on Windows 11; use `python3` on Linux or `python` on Windows). These exercise movement/collision, enemy behavior, strike rules, spending failures, HUD state, delayed regeneration, depletion/recovery, invalid values, resource bounds, tier rewards, pickup proximity/overflow/obstruction, defeat, and restart. The final command runs the actual main scene for 120 frames. To play visually on a computer with a display, run `godot --path .` or use the editor; headless mode provides automated validation. A scripted visible Windows playtest is recorded in `docs/playtest/`; manual usability and real-network playtests remain pending. Networking was tested on loopback with one host plus seven simultaneous guests; real LAN/WAN connectivity and performance on your machines still need playtesting.

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

**8 players total: 1 host + 7 guests.** Load or create a world, press **Esc** and choose **Open to friends**; the pause menu shows your LAN address. Friends choose **Join a Friend** on the title menu and enter that address. The default is **UDP 24560**. Do not use `127.0.0.1` from a different machine; that address refers to that friend’s computer.

The host owns movement, combat, drops, corpse claims, skills, inventories, and world saves. Clients send validated intentions. Enemies select nearby living players; each HUD and bag belongs to its local character. One player opening inventory does not pause everyone else. R respawns a defeated character with its learned skills, inventory, level and current Magicules retained; living characters cannot use respawn to reset health.

Save locations (Godot application user-data folder):

- `user://worlds/<world name>.json`: one file per world (save slot) with its name, seed, dates and all registered character records. An older `forest.json` appears in the list as "Earlier world".
- The adjacent `.bak`: previous valid save, used if the primary is corrupt.
- `user://profiles/characters.json`: each client’s private reconnect identities. Keep this file on that player’s machine; do not commit or share it. Losing it requires a new character rather than claiming another character’s ID.

Hosting loads the world if it exists; invalid saves with no valid backup are preserved and hosting stops. Saves use a versioned schema, validation, a temporary file and atomic rename. Saving happens on important reward/inventory/defeat changes, guest join/disconnect, **F9**, every **15 seconds**, and normal window close. A force-killed process can restore only its last completed save. Offline characters stop simulating. Disconnected or reloaded analysis channels are interrupted with no cost refund; their unconsumed corpse remains available.

Current saves cover stable world/character/entity IDs, positions/facing, implemented stats, HP and Magicules/recovery timers, learned skills/loadout, materials/capacity, attack recovery, enemy state, and remaining pickups. Character progression dictionaries include level/experience/race and reserved personal quest/equipment state; shared progression holds world time and quest/settlement dictionaries. XP, levels and unspent skill points are implemented; equipment and personal quest mechanics remain planned. The shared camp implements settlement founding, gathering, structures and ally work, while broader settlement progression remains planned. Each later feature must extend the validated schema rather than fabricate sample progression.

CLI launch with your Godot executable:

```bash
godot --path . -- --host
godot --path . -- --join=192.168.1.10
```

Optional arguments: `--port=24560`, host `--save=/path/to/world.json`, client `--identity=/path/to/private-profile.json`. Use distinct identity files when testing multiple guests on the same computer. Start the host first and keep that process running. Host changes are saved on its machine; clients’ profiles reconnect them to the same characters after host restart.

This is a desktop/LAN prototype. It uses ENet/UDP, host-verified reconnect credentials and reliable full-state snapshots; encrypted transport, latency prediction, and Internet deployment are not implemented/tested. Joining across the Internet also requires a reachable host (typically UDP port forwarding and a firewall allowance on the host machine). LAN playtesting comes first; do not treat the loopback checks as proof that Internet connectivity works.

Architecture and future persistence requirements: `docs/MULTIPLAYER_AND_SAVES.md`. Networking/persistence code: `scripts/network`, `scripts/persistence`. Source code is on GitHub; world saves and reconnect profiles remain private user data.

## First ally

A nameless goblin waits west of the starting point at (220, 360). Defeat the clearing’s first Gnasher, approach within 40 pixels, and press **F**. The dialog shows its actual stats and a **Recruit** button. Recruitment is free. Enter a name in the same dialog and explicitly confirm the cost of **80% of your maximum Magicules** to evolve it into a Hobgoblin (HP 60, power 8, follow speed 65, larger armored silhouette). Naming is permanent and only the owner can do it. The goblin follows its owner with terrain collision, waits if that character disconnects/dies, and retains ownership when the character reconnects. Other players cannot steal it, and simultaneous claims resolve once on the host. Its placeholder appearance is a small green goblin; combat orders/pathfinding come later.

Since schema version **3**, saves include allied entities, stable ownership, naming/evolution, and per-character exhaustion. Version-1 worlds migrate by introducing the unclaimed goblin, while retaining their characters and world progress. Allied positions and ownership replicate and save with the world. Validation rejects unknown owners and duplicate entity IDs. `tests/allies.gd` adds 18 checks; `tests/naming.gd` adds 28.

Naming leaves a namer below 25% reserves asleep for at least **8 seconds**, and until reserves reach 25%. Movement, attacks and absorption stop; regeneration continues while alive. Other players continue playing. Exhaustion, its remaining timer, and paid costs survive host save/reload and reconnect. Disconnected characters stop simulating; respawn preserves exhaustion. Offline dialogs pause recovery until closed; hosted dialogs only block that character’s input. Allies currently follow rather than fight.

## Working with Codex and Claude Code

Both tools follow `AGENTS.md` and `docs/AI_HANDOFF.md`; Claude Code starts from `CLAUDE.md`. The handoff records implemented behavior, architecture, validation and the next task. Update it after either tool completes work and coordinate concurrent file ownership before overlapping edits.

## First goblin camp

Press **B** to open the camp menu. Close it to move between targets; offline menus pause the game. The camp site is the flag at **(350, 350)**, west of spawn. After naming your ally and recovering, bring it near the flag and click **Found camp** within 55 pixels. Founding is free; the camp belongs to the shared world.

Approach each material deposit within 36 pixels, open **B**, and click **Gather nearby materials**. Two wood piles at **(300, 350)** and **(350, 300)** supply 8 wood each; the stone deposit at **(410, 350)** supplies 8 stone. Anyone can contribute, including before founding. Deposits are finite and emptied only once. Return to the flag, open **B**, and confirm **Build hut: 12 wood + 6 stone**. The hut appears southeast of the flag with real collision; move characters/allies clear of its footprint if construction is blocked. Remaining shared stock is 4 wood and 2 stone after gathering all deposits and building.

The camp menu shows current shared stock and disables unavailable actions. Hosted menus block only your own movement/actions; the world keeps running. The host saves founding, founder identity, stock, depleted deposits and construction together. Schema **v4** introduces these fields; older worlds retain their existing progress and gain the untouched camp. The reserved `progression.settlements` dictionary is separate from this implemented, validated first camp.

Ally gathering/construction assignments and camp growth are described below. Structures use fixed sites rather than free placement. Camp tests: `tests/settlement.gd` (34 checks), `tests/camp_growth.gd` (48 checks) and `python3 tests/network_settlement.py` (105 checks). All suites total **547 checks**; local visual and real LAN/WAN playtests remain pending.

## Ally work assignments

After founding the camp, stand within 55 pixels of its flag and open **B**. Your named Hobgoblin must be within 100 pixels when starting work. Only its owner can command it. The bottom row provides:

- **Ally: Gather** — walk to each remaining deposit and gather it after 3 seconds of work. Materials go directly into shared camp stock. It skips deposits another player has emptied and returns to Follow when none remain.
- **Ally: Build** — available when a structure is unlocked and funded (see Camp growth). The ally works at the camp for 4 seconds, then builds the first funded structure and charges its recipe once. It waits if someone occupies the hut footprint; keep that area clear. A manual build safely ends the same job without a second charge.
- **Ally: Follow** — recall the worker and cancel unfinished work. Construction materials are paid on completion, so recall before completion spends nothing.

Close the menu to let work run offline. Hosted menus keep work running. The menu shows the ally's current role, target and remaining work time. Assigned citizens continue working while their owner is disconnected/dead; the host world must remain running. Follow waits for the owner's return. Schema **v5** saves role, target, position and remaining job timer, and migrates earlier allies to Follow. Reload resumes the job without creating extra materials. Workers use straight-line movement with collision; navigation around complex obstacles is future work. Deposits remain finite, and a previously completed hut cannot be constructed again.

## Camp growth: exploration and new buildings

The three deposits near the flag only cover the hut. To grow the camp further, explore:

- **Outlying deposits** — wood far east at **(700, 440)** near the second Gnasher, stone northeast at **(860, 200)** past the pond, and stone southwest at **(200, 540)**. 8 each. Walk there yourself and use **B → Gather nearby**; the materials go straight into shared camp stock. Allied workers only gather near the camp, so exploring is the player's job.
- **Gnasher Essence offerings** — every absorbed Gnasher leaves one essence in your bag (I). At the flag, **B → Offer essence** moves one essence from your bag into shared camp stock.

The camp menu has one build button per structure (stand within 55 pixels of the flag). The hut must come first; it unlocks the others:

| Structure | Cost | Effect |
| --- | --- | --- |
| Goblin Hut | 12 wood + 6 stone | Unlocks the Storehouse and Essence Shrine |
| Storehouse | 10 wood + 6 stone | Ally work takes half the time (gather 1.5 s, build 2 s) |
| Essence Shrine | 8 stone + 2 essence | Within 60 pixels, Magicules regenerate twice as fast (after the normal 1.5 s delay); a faint ring shows the range |

The menu header shows the **camp level** (1 when founded, +1 per structure, up to 4) and stock of wood, stone and essence. **Ally: Build** picks the first funded structure in the order above. All six deposits together give 24 wood and 24 stone, enough for every building with 2 wood and 4 stone left over. Each structure is built once and has collision.

The host performs every gather, offering and build, so two players clicking at the same time cannot duplicate materials or essence. Schema **v6** saves essence, the offering count and the new structures; older worlds keep their progress and gain the untouched outlying deposits. Agriculture and free building placement are future work.

## Visual playtest

On a computer with a display, run the automated playtest **without** `--headless`. A window opens and plays the whole first slice by itself, using the real input actions for movement, strikes, absorb, Rending Bite and the B/I/F/F8 menus: fight → absorb → recruit/name → recover → found camp → ally gathers and builds → explore all outlying deposits (and fight the second Gnasher) → offer essence → Storehouse and Shrine.

```bash
godot --path . --script tests/visual_playtest.gd
```

It saves 22 screenshots plus `log.md` (checklist, captions and system messages) to `docs/playtest/` and exits with code 1 if any check fails. Don't minimize the window while it runs; covering it with other windows is fine. Menu buttons are pressed programmatically, and offline (sandbox) mode is used; hosted play is covered by the network suites.

## Skill tiers and unlock rules

Every skill is listed in `scripts/skills/skill_catalogue.gd` with a stable ID, a tier and an explicit unlock rule:

| Tier | How it unlocks |
| --- | --- |
| Common | Analyze a specific creature (Rending Bite: Forest Gnasher) |
| Extra | Already know the listed Common skills, then analyze a specific creature |
| Unique | Know the required Extra skill and complete a personal trial |
| Ultimate | Know and master the required Unique skill, then reach an ascension milestone |

Each character keeps its own **evidence**: which creatures it has analyzed and which trials, masteries and ascensions it has earned. The host grants skills only when that evidence satisfies a rule, so repeating an analysis or reconnecting does not duplicate unlocks. Save validation rejects knowledge that its saved evidence does not justify; this checks consistency of the host-owned save. Current skills: **Rending Bite** (Common, analyze a Forest Gnasher), **Thorn Lash** (Common, analyze the Thornback Gnasher: 14 damage, 8 Magicules, 0.5 s) and **Piercing Fang** (Extra: know both Commons and have analyzed a Thornback, in either order). Piercing Fang is a long thrust in your facing direction that hits **every** creature in a 64-pixel line for 26 damage (18 Magicules, 1.2 s cooldown); terrain still blocks it. The **Thornback Gnasher**, a spiny purple variant, waits in the far southeast corner at (880, 560); absorbing it stores a Thornback Quill. Unique/Ultimate stay locked until a trial (step 16) and ascension (later) exist. Hotbar slots are assigned by the host through an `assign_slot` request, and skills activate through a fixed effect list. Schema **v7** stores the evidence; older worlds rebuild it from the skills characters actually know. Tests: `tests/skill_catalogue.gd` (51 checks, including required known-skill consistency).

Review fix: saved Extra/Unique/Ultimate skills must retain their required known skills as well as supporting evidence. This rejects inconsistent saves that kept an Extra while removing its Common prerequisites. Normal earned skills and schema v8 remain unchanged.

## Mimicry: Gnasher Form

After your character has analyzed a Forest Gnasher, press **T** to take **Gnasher Form** for **20 Magicules**: you move 30% faster and your basic strike deals 14 instead of 10 damage. Skills keep their own damage. Press **T** again to turn back into a slime for free. Changing form has a 2-second cooldown, shown next to the form name in the HUD. The Gnasher body is slightly larger, so you need a little room away from walls to transform; if there is none, nothing is charged. Transforming never restores HP or Magicules and is impossible while asleep, defeated or in a menu. Defeat always turns you back into a slime. Each character's form is saved (schema **v9**; older characters start as slimes) and every player sees it. Tests: `tests/mimic_form.gd` (30) and `python3 tests/network_forms.py` (17 real-process checks).

## Proving Trial and the first Unique skill (placeholder story)

*The trial's name, texts and look are placeholders until the storyline is written.*

A stone stands in the north at **(480, 100)**. Once your character knows **Piercing Fang**, stand at the stone and press **F** to begin the **Proving Trial**: three trial creatures appear, and you have **60 seconds** to defeat them all while staying inside the faint circle. A banner at the top shows the creatures left and the time. Other players may help, but **only the character who started the trial is credited**. The trial fails if you are defeated, leave the circle, disconnect or run out of time, and you can simply try again. Trial creatures drop nothing and cannot be analyzed. A trial in progress is not saved: a host restart cancels it.

Completing it teaches the first **Unique** skill, **Predator Focus** (placeholder name), which goes into the new **4th hotbar slot (key 4)**. It costs 25 Magicules: your **next analysis within 20 seconds** reaches twice as far (72 px) and completes in 0.3 s instead of 1.2 s. It is used up when that analysis begins, so interrupting it gives nothing back, and it cannot be stacked. **Ultimate** skills stay locked until an ascension exists (planned for M6). Schema **v10** stores the fourth slot and an armed focus. Tests: `tests/trial_unique.gd` (40) and `python3 tests/network_trial.py` (22 real-process checks).

## Finding gear

- **Creature drops:** defeated creatures sometimes drop gear on the ground (Easy 10%, Standard 20%, Elite 45%; tougher creatures drop rarer items, Elites even Legendary). Walk over it to pick it up.
- **Chests:** every world has three chests at points of interest (the original map: far north-west, south-east by the Thornback, and north of the pond). Press **F** next to one to open it — Uncommon or better. Each character can open each chest once.
- **Trial:** completing the Proving Trial also gives a Rare or Epic item.
- **Forge:** build the **Forge** at the camp (4 stone + 3 essence, after the hut). Standing at it, use the camp menu (**B**): **armor** from 2 Gnasher Essence, **weapons** from 2 Thornback Quill, **accessories** from one of each.

Merchants come later with money and trade. Saved per world and character (schema **v19**). Tests: `tests/gear_sources.gd` (29).

## Weapons

Equip a weapon in the new **weapon slot** (bag → Equipment) and your basic attack (Space) changes: **Sword** — a balanced arc in front (0.45 s); **Spear** — a long thrust that hits everything in a narrow line (0.55 s); **Scythe** — a slow, wide sweep that also catches creatures beside you (0.75 s); **Bow** — a shot at the first creature in line of sight up to 200 pixels (0.6 s); trees and rocks block it. The weapon's damage replaces your unarmed 10 and grows with rarity; Human weapon mastery, the skill tree and gloves add on top. The HUD shows your weapon. Tests: `tests/weapons.gd` (20).

## Gear: armor and accessories

You have six gear slots: **head, body, hands, feet and two accessories** (rings, amulets). Items come in five rarities — **Common, Uncommon, Rare, Epic, Legendary** — shown in grey, green, blue, purple and orange. Each item has its own rolled stats (max HP, Magicules, Magicule recovery, speed, strike damage or **defense**, which reduces every hit you take); higher rarities roll higher. **Rare** and better items add passives (Swift, Wellspring, Keen, Lifesteal, Thorns), and **Epic/Legendary** items have an **active** you trigger with **G** (Barrier: 2 s invulnerable; Mana Surge: +30 Magicules). Open the bag (**I**) and press **Equipment** to equip items or click a slot to take one off. Worn gear shows on your character. Gear is saved per character (schema **v18**). Gear comes from creature drops, chests, the trial and the camp Forge (see "Finding gear"). Tests: `tests/gear.gd` (38).

## Creature respawning

Defeated creatures come back at their usual spot **60 seconds** later, with the same strength — so you can keep earning XP, Magicules and materials. A creature never appears right on top of you (it waits until nobody is within about 160 pixels), and an unabsorbed corpse disappears when its creature returns. Trial creatures never respawn. Pending respawns are saved with the world (schema **v17**). Tests: `tests/respawn.gd` (22).

## Skill fusion

Press **U** to open the **fusion window**. Your skills are listed on the right: drag one into the fusion area, then drag another skill onto it. If the two fuse, **both are replaced** by the fused skill, which takes the first skill's hotbar slot. Right now **Rending Bite + Thorn Lash → Piercing Fang** (Extra; needs a Thornback analysis). A fused skill has a **Split** button that always gives you both skills back. Only activated skills can be fused, and fusing or splitting costs no skill points. Extra skills are no longer granted automatically. Saved with your character (schema **v16**). Tests: `tests/fusion.gd` (41).

## Skill tree

Press **K** to open your race's **skill tree**. Every level (level 1 included) gives **one skill point**. Spend points on stat upgrades (more HP or Magicules, faster Magicule recovery, speed, strike damage); every third node is a **new skill** — Slime: Acid Splash and Engulf, Human: Power Slash and Lunge, Demon: Shadow Claw and Dark Lance. Rows unlock in order. Skills you learn by **absorbing** creatures or from **trials** are listed on the right and must be **activated with a point** before you can use them; activated skills go to the next free hotbar slot. Your tree is saved with your character (schema **v15**). Placeholder layout until the UI step. Tests: `tests/skill_tree.gd` (34).

## Playable races

When you create a world (or join a friend's world for the first time) you choose your race:

- **Slime** — HP 100, Magicules 100. Absorbs fastest and gains the full absorbed vitality; takes **mimic forms** from the start.
- **Human** — HP 120, Magicules 70. **Weapon mastery:** +4 strike damage and every attack recovers 25% faster.
- **Demon** — HP 90, Magicules 130, a little faster. **Dark affinity:** skills deal 25% more damage and drain 20% of the damage dealt back as HP.

Everyone can absorb creatures and learn their skills; Humans and Demons just take longer (1.8 s instead of 1.2 s) and heal half as much from it. **Mimicry** comes to every race: Slimes from level 1, Demons from level 5, Humans only at the endgame (level 20). **Naming** an ally costs **80% of your maximum Magicules** (Slime 80, Human 56, Demon 104), so every race can name its first ally. Your race is kept with your character in that world. The art is placeholder until the sprite step. Tests: `tests/races.gd` (30).

## Experience and levels

You earn **XP** for the defeating blow on a creature (Easy 10, Standard 20, Elite 40), for every completed **absorption** (5 / 10 / 20) and for completing the **trial** (60). Levels need 50, 150, 300, 500 … total XP, up to **level 20** for now. Each level (level 1 included) gives **one skill point** for the skill tree (K). The top-right of the HUD shows your level, XP toward the next level and unspent points, and the System Voice announces level-ups. Only the player who earns XP gets it; trial creatures give no XP of their own. Saved with your character (schema **v14**). Tests: `tests/leveling.gd` (29).

## Healing: absorbed vitality

Hit points do not regenerate on their own. Completing an **absorption** heals you gradually over **10 seconds**, depending on the creature: **Easy 15 HP, Standard 25 HP, Elite 40 HP** (the Thornback is Standard). The HP display shows "+ healing" while it runs. A new absorption only replaces a running heal if it would restore more, healing never exceeds your maximum, and it stops if you are defeated. Trial creatures cannot be absorbed, so trials cannot be used to heal. Running heals are saved (schema **v11**). Tests: `tests/absorb_healing.gd` (21).

## Worlds, save slots and playing with friends

The title menu lists every saved world with its **name, seed and last-played date**; damaged files are shown as damaged instead of disappearing. **New World** asks for a name and a seed: leave the seed empty for a random one, type a number to use it directly, or type any text (it is turned into a number, like in Minecraft). The seed shapes the world: where the wood and stone piles are (and how rich the outlying ones are), where creatures wait and how strong they are, where the trial stone and the goblin start, and where trees and rocks grow. Roads, the pond, the camp and your spawn are always the same, and every place stays reachable on foot. The same seed always gives the same world, and friends who join see exactly what you see. Seed **0** is the original hand-made map; worlds saved before seeds existed keep it and show "original map". Tests: `tests/seeded_worlds.gd` (36). Each world gets its own file, so two worlds with the same name get separate slots.

**Every world is always saved.** Playing alone means you host the world without opening anything on the network (no firewall prompt). Press **Esc** for the pause menu: playing alone, it freezes the world; with friends connected, it only stops your own character. **Open to friends** starts accepting up to 7 friends in the running world without a restart and shows your LAN address and port (UDP 24560). **Save & quit to title** saves and closes the port; joined players see **Leave to title** instead. When you load the world again it starts solo, and your friends' characters are kept, so they rejoin as themselves after you open it again. Command-line `--host` / `--join` still work and skip the menu. Tests: `tests/worlds_menu.gd` (37) and `python3 tests/network_worlds.py` (18 real-process checks).
