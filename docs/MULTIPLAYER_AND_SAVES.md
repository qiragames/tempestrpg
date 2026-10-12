# Hosted multiplayer and persistent worlds

User requirement, 2026-10-12: friends connect to the user's machine, which hosts the game server. Persist each character and the shared world. Confirmed player limit: **8 total, including the host (1 host + 7 guests)**. Keep the limit configurable rather than scattering a hardcoded number through gameplay.

## Current state and order

N0 is implemented for desktop/LAN testing. The host owns simulation, admits seven guests, verifies per-world reconnect credentials, and saves/restores characters and world entities. The offline sandbox remains session-local; choose Host/Join with F8 to use persistent hosted play. Real processes verified host/client movement, shared claims, reconnect after host restart, forged identity rejection, eight-player capacity, and local UI without global pause. Internet connectivity, encrypted transport, visual playtesting, and high-latency/performance tuning remain unverified or unimplemented. M2 recruitment, naming/evolution and exhaustion are implemented.

## Authority and identity

- The user's machine runs an authoritative Godot server, optionally with the host's local player in the same process. ENet/UDP is implemented with client-to-host-only communication (peer relay disabled). LAN testing comes first; Internet reachability/encrypted transport are separate follow-up work.
- Clients send actions/intent, not trusted HP, inventory, currency, damage, rewards, or positions. The host validates ownership, movement, range, line of sight, costs, cooldowns, and interaction targets, then applies and replicates results.
- Each world, player character, enemy, pickup, and settlement entity needs a stable ID. Network peer IDs are temporary connection IDs and must never be used as permanent save ownership.
- Reconnecting must bind to the player's existing character through host-verified identity. A claimed character ID alone is not authorization. The host issues a random private credential and stores only its per-world salted hash. The client stores its credential privately; reconnect verifies it before restoring the character.
- Drops, corpse consumption, skill acquisition, inventory changes, and shared objectives must resolve once on the host. Simultaneous interactions must not duplicate loot or consume one specimen twice.

## Persistent state

| Scope | State to preserve |
| --- | --- |
| Per character | Stable ID, world/region and position, level/experience, race/form, stats, HP, current/maximum Magicules, learned skills/loadout, inventory/equipment, personal quest progress, progression and naming state |
| Shared world | World ID/seed, time, surviving/defeated/absorbed entities, uncollected drops and remaining quantities, shared quest progress, settlements/buildings/resources, citizens and roles, diplomacy and world progression |
| Runtime restoration | Reconstruct entity state and relevant recovery timers; pause disconnected-player activity according to explicit host rules, rather than depending on processes or sockets surviving |

Save actual implemented fields first and extend the schema with each new feature. The references' sample levels, gear, currency, and quests are not default saved data. Party-wide and personal quest state must be modeled separately before quest implementation.

The host owns world saves. Version 9 uses stable definition IDs, validated primitive fields, draft-version defaults/migration, atomic replacement, and a previous valid backup. Extend this schema with each later feature. Do not serialize runtime node paths, object IDs, physics handles, network peers, or arbitrary executable resources as save identity. Persist related reward/corpse/inventory changes in one consistent world snapshot. Write atomically with a recoverable previous save so a crash cannot truncate the only copy. Support autosave, explicit save, clean shutdown, and clear handling of a corrupt or incompatible save. User saves and reconnect credentials stay out of Git.

## Multiplayer-aware gameplay and UI

- Components should receive an explicit player/entity reference. HUDs use explicit local-player bindings; enemy targeting searches nearby living characters, and stable IDs resolve players/entities.
- Inventory, equipment, skills, quests, and progression are owned by a specific character. Settlements and appropriate objectives belong to the world.
- The offline inventory pauses the scene tree. Hosted inventory sends a local menu intent that blocks that character’s actions/movement while shared simulation and recovery continue. No multiplayer menu may globally pause the host.
- Bind each HUD to the local controlled character and replicated state. UI must not apply authoritative gameplay mutations.
- Loading a world must restore positions in the appropriate region, resources and items without duplication, and depleted/dead states under explicit recovery rules.

## Verification and remaining work

Passed: 161 existing gameplay checks, 32 persistence checks, and 68 real-process networking checks. The network runner starts a host/two guests, verifies movement/authority, concurrent corpse claims and shared pickup accounting, shuts down and reloads the host, restores both verified character identities, rejects a forged credential, and admits seven simultaneous guests while rejecting the ninth total player. Application CLI host/join startup was also tested independently. Save tests cover primitive data round-trips, actor/entity restoration without duplicate drops, invalid fields/IDs/capacity, corrupt-primary recovery, preserved valid writes, draft migration, and respawn retaining progression.

Network tests use loopback on one machine; the encounter fixtures isolate networking from the separately tested enemy AI. They do not establish real WAN connectivity, latency behavior, visual quality, or eight players simultaneously fighting under adverse network conditions. Full snapshots are a first implementation; later transport/prediction/performance work should preserve host authority and save ownership.

Disconnect preserves the character’s last authoritative state and releases any pending absorption reservation. Reload/reconnect interrupts unfinished channels without refunding their paid cost. Drops/corpses and inventories restore from the same snapshot. Saved dead characters remain dead until an authorized per-character respawn; rejoining never supplies free HP/resources. Respawn preserves inventory, knowledge, progression and existing Magicules.

## Ally naming and recovery

Host validates ally owner, living/awake namer, range/terrain, unique valid name and 80-Magicule reserves. Naming/evolution/cost happen once; repeated or competing requests cannot spend twice. World-owned ally records retain stable owner ID, name, race, stats and position. Character-owned exhaustion retains its remaining minimum 8-second timer plus 25% resource threshold. Schema v0/v1/v2 migration supplies missing fields. Dead characters can respawn with exhaustion retained; disconnected characters do not recover until reconnect.

## First camp

The top-level `camp` record owns stable site/deposit/structure IDs, founded/founder, shared wood/stone, remaining finite deposits and built-hut state. It is distinct from the earlier reserved settlement progression dictionary. Deposits are fixed definitions: wood_1/wood_2 = 8 each, stone_1 = 8, hut_1 costs 12 wood + 6 stone. Validation enforces conservation of gathered/spent stock, valid founder identity and construction prerequisites. v3→v4 migration introduces an untouched camp.

Clients request only operation and target ID. The host checks living/awake actor, distance, terrain, owner-linked evolved ally for founding, remaining deposits, recipe funds, single construction and unobstructed footprint. Related stock/deposit/hut changes occur once in a host transaction and one world snapshot. A disconnected founder retains identity and the camp remains shared. Camp menus behave like inventory: local blocking online, scene pause offline. Built terrain collision is reconstructed on restore and clients. 34 settlement checks and 42 dedicated real-process networking checks verify the new loop, in addition to prior suites.

## Citizen work

`ally_work` intents carry only ally ID and role. The host resolves the requesting character and checks ownership, evolved/named ally, living/awake owner near camp, camp founding, nearby worker and relevant deposits/funds. Repeated identical assignments do not reset progress. Ally records now include `work = {role, target, remaining}`; v4→v5 migration defaults to Follow. Resource conservation in the camp schema remains unchanged.

Host physics moves the worker and advances work only beside an unobstructed target. Gathering takes 3 seconds per finite deposit; construction takes 4 seconds and pauses for occupied placement. Shared harvest/completion functions resolve resource transfer/spending once, also for competing manual actions. Payment occurs at completion, so recall has no prepaid materials to refund. Assignments continue independently of owner connection/death; no simulation runs while the host is shut down. Saved position/target/remaining time resume on reload. Clients replicate work state and never tick it. 35 worker checks plus 63 camp networking checks include owner-only commands, concurrent requests, partial-job host restart, disconnected workers, and final conserved construction stock.

## Camp growth (schema v6)

The camp record adds three outlying deposits (wood_3 at (700, 440), stone_2 at (860, 200), stone_3 at (200, 540); 8 each), shared `essence` stock, an `essence_offered` counter and `storehouse`/`shrine` flags. Structures are fixed definitions in `first_camp.gd` `STRUCTURES`: hut_1 (12 wood + 6 stone), storehouse_1 (10 wood + 6 stone) and shrine_1 (8 stone + 2 essence); the latter two require the hut. Validation keeps conservation for every resource: stock = gathered (or offered) − cost of built structures, never negative; structures need founding and their prerequisite; deposits are full or empty. v5→v6 migration adds the new fields and untouched outlying deposits without changing existing progress.

Clients still send only `camp` intents with an operation and target ID. `offer` (id `gnasher_essence`) is a single host transaction that discards one essence from the requesting character's inventory and credits the camp; it requires a founded camp, a living/awake character within 55 px of the flag and an essence in that character's bag, so concurrent or repeated requests cannot duplicate or lose essence. Outlying deposits are player-only exploration rewards; workers only target near deposits and saves reject workers assigned to outlying ones. Worker Build picks the first funded, unlocked structure, pays at completion and saves any known structure ID as its target. Storehouse halves new job durations (3 s → 1.5 s gather, 4 s → 2 s build). The host applies the Shrine bonus each physics frame to living characters within 60 px whose regeneration delay has elapsed (one extra regeneration rate), so replicas never simulate it. Covered by `tests/camp_growth.gd` (48 checks) and the extended `tests/network_settlement.py` (105 checks, including concurrent duplicate requests from two guests for every new action).

## Skill unlock evidence (schema v7)

Each character record adds `skill_evidence = {analyzed, trials, mastery, ascensions}`, arrays of stable catalogue IDs (`scripts/skills/skill_catalogue.gd`). The host records analysis evidence when an analysis completes and grants whatever the catalogue rules now unlock; clients never send skills or evidence. Validation requires known evidence IDs without duplicates, mastery only for a known Unique, unique equipped slots, and every saved skill to be derivable from that character's evidence alone. Trials and ascensions have no completable entries yet, so any saved trial/ascension evidence is rejected. v6→v7 migration rebuilds only the analyses implied by skills the character already knows and never fabricates trials, mastery or ascensions. `assign_slot` intents carry only slot index and skill ID; the host checks knowledge and moves rather than duplicates. Skill activation dispatches on the definition's `effect` (currently `strike`); unknown effects never execute or spend. Covered by `tests/skill_catalogue.gd` (48 checks) and 4 new real-process checks in `tests/network_integration.py` (single evidence record under concurrent absorption, skills matching evidence, evidence restored on reconnect).

## Second specimen and Extra (schema v8)

Enemy records carry a validated `kind` (`gnasher`, `thornback`) that selects the scene on restore through `StateCodec.ENEMY_SCENES`; client data never supplies scene paths. Inventory counts accept the catalogue materials (`gnasher_essence`, `thornback_quill`). v7→v8 migration appends one living `thornback_1` at its home (880, 560) only when absent, so a defeated Thornback is never revived or duplicated; an absorbed one is consumed and absent from v8 saves like any absorbed corpse. Unlocks still come only from host-recorded evidence: Piercing Fang requires Rending Bite and Thorn Lash known plus Thornback analysis evidence. The existing corpse reservation makes concurrent absorption award once. Covered by `tests/extra_skill.gd` (37 checks).

## Step 14 review correction

On `codex/fix-extra-skill-save-prerequisites`, `SkillCatalogue.justified` checks each saved skill against both its evidence and the actual saved known-skill list. Evidence implying a lower-tier skill is insufficient if that required skill is missing from the saved list. Six regressions cover missing prerequisites at Extra/Unique/Ultimate tiers and Piercing Fang saves with neither or only one of its Commons. This is a validation correction within v8; valid earned saves/migrations are preserved, and inconsistent saves are rejected rather than supplied free prerequisite skills.

## Mimic forms (schema v9)

Each character record adds `form = {id, cooldown}`. Validation requires a catalogue form unlocked by that character's own `skill_evidence` (base `slime` always), a cooldown within 0–2 s, and the base form for defeated characters. v8→v9 migration gives everyone the slime. Clients send `transform {form}` only; the host checks unlock, life, exhaustion, menu blocking, cooldown and terrain room for a larger body, then charges the cost once. HP, Magicules, exhaustion, inventory and identity are never refilled or changed by mimicry. Defeat reverts to the slime and respawn keeps it. Forms replicate through character snapshots and restore with body size after reload. Covered by `tests/mimic_form.gd` (30) and `tests/network_forms.py` (17 real-process checks: rejected client-side mutation, single cost under duplicate requests, rejection without evidence, identical forms on both clients, saved and restored forms).
