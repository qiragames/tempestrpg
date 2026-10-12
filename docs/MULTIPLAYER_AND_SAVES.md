# Hosted multiplayer and persistent worlds

User requirement, 2026-10-12: friends connect to the user's machine, which hosts the game server. Persist each character and the shared world. Confirmed player limit: **8 total, including the host (1 host + 7 guests)**. Keep the limit configurable rather than scattering a hardcoded number through gameplay.

## Current state and order

The current M1 prototype is single-player and session-local. Restart resets the encounter, skills, and inventory; it does not implement saved worlds or networking. Complete the currently tested M1 loop, then build N0 (networking and save foundations) before ally evolution and settlement progression. Do not call the game multiplayer-ready until real host/client checks and save/reconnect checks pass.

## Authority and identity

- The user's machine runs an authoritative Godot server, optionally with the host's local player in the same process. ENet/UDP is the initial transport candidate; LAN hosting comes first, with Internet connection setup evaluated afterward.
- Clients send actions/intent, not trusted HP, inventory, currency, damage, rewards, or positions. The host validates ownership, movement, range, line of sight, costs, cooldowns, and interaction targets, then applies and replicates results.
- Each world, player character, enemy, pickup, and settlement entity needs a stable ID. Network peer IDs are temporary connection IDs and must never be used as permanent save ownership.
- Reconnecting must bind to the player's existing character through host-verified identity. A claimed character ID alone is not authorization. Define the reconnect association before shipping character restoration.
- Drops, corpse consumption, skill acquisition, inventory changes, and shared objectives must resolve once on the host. Simultaneous interactions must not duplicate loot or consume one specimen twice.

## Persistent state

| Scope | State to preserve |
| --- | --- |
| Per character | Stable ID, world/region and position, level/experience, race/form, stats, HP, current/maximum Magicules, learned skills/loadout, inventory/equipment, personal quest progress, progression and naming state |
| Shared world | World ID/seed, time, surviving/defeated/absorbed entities, uncollected drops and remaining quantities, shared quest progress, settlements/buildings/resources, citizens and roles, diplomacy and world progression |
| Runtime restoration | Reconstruct entity state and relevant recovery timers; pause disconnected-player activity according to explicit host rules, rather than depending on processes or sockets surviving |

Save actual implemented fields first and extend the schema with each new feature. The references' sample levels, gear, currency, and quests are not default saved data. Party-wide and personal quest state must be modeled separately before quest implementation.

The host owns world saves. Use versioned data, stable definition IDs, validation of loaded fields, and migrations/defaults for later features. Do not serialize runtime node paths, object IDs, physics handles, network peers, or arbitrary executable resources as save identity. Persist related reward/corpse/inventory changes in one consistent world snapshot. Write atomically with a recoverable previous save so a crash cannot truncate the only copy. Support autosave, explicit save, clean shutdown, and clear handling of a corrupt or incompatible save. User saves and reconnect credentials stay out of Git.

## Multiplayer-aware gameplay and UI

- Components should receive an explicit player/entity reference. The prototype's named Player bindings and first-player lookup must be replaced before multiple players exist.
- Inventory, equipment, skills, quests, and progression are owned by a specific character. Settlements and appropriate objectives belong to the world.
- The current single-player inventory pauses the scene tree. In multiplayer, opening one player's inventory/pause menu must not pause the host, other players, resource timers, combat, or analysis. Capture only that player's UI input; host simulation continues.
- Bind each HUD to the local controlled character and replicated state. UI must not apply authoritative gameplay mutations.
- Loading a world must restore positions in the appropriate region, resources and items without duplication, and depleted/dead states under explicit recovery rules.

## Required evidence for N0

Run a real host and at least two client processes. Verify movement/ownership, attacks and rewards, concurrent pickup/corpse claims, disconnect/reconnect, correct capacity limits, and local menus without pausing other players. Save, shut down, load, and reconnect; verify current player state, inventory/skills, enemy/drop state, and later quest/settlement data. Test corrupt saves and schema migration/defaults. Eight-player behavior (1 host + 7 guests) remains a separate required capacity check before claiming full supported capacity.
