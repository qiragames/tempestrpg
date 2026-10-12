# TempestRPG — Living Roadmap

Last updated: 2026-10-12

## Goal

A top-down 2D pixel-art Isekai action RPG in Godot 4 with GDScript, with friends connecting to the user’s host machine and persistent characters/worlds. Explore, fight, absorb creatures and acquire skills, name and evolve allies, and grow a camp into a multi-race nation with trade, diplomacy, and army battles.

## Current focus

**N0 implemented for desktop/LAN testing:** an authoritative host supports 8 total players, verified character reconnects, private identities, versioned character/world saves, recovery from a valid backup, and per-player multiplayer inventory menus. 161 gameplay, 32 persistence, and 68 real-process networking checks passed headlessly. The actual game CLI also hosted/joined successfully. **Next: recruit a nameless ally (M2), then naming, evolution and their replicated/save state.** Internet connectivity, encrypted transport, final art integration, and visual playtesting remain outstanding.

| Task | Status | Prerequisite | Completion evidence |
| --- | --- | --- | --- |
| Establish the game design brief | Done | User's GDD | Genre, core loop, progression rules agreed |
| Choose engine and language | Done | Engine decision | Godot 4 + GDScript selected |
| Create persistent roadmap | Done | GDD and engine | This file and agent update instructions |
| Select and install a stable Godot 4 version | Done | Linux/cloud compatibility | Preinstalled Godot 4.6.3 verified; temporary-project import and GDScript/2D runtime checks passed |
| Create the minimal Godot project | Done | Engine version | Actual project imported without errors in Godot 4.6.3 |
| Define input, pixel scale, and scene structure | Done | Godot project | 480 × 320 viewport, player/camera/world scenes; movement and collision checks passed |
| Validate startup and save reusable environment instructions | Done | Runnable project | 17 smoke checks passed, 120-frame main-scene run passed; tested install/start draft saved |

## Current milestone tasks

| Task | Status | Prerequisite | Completion evidence |
| --- | --- | --- | --- |
| Player health, strike, damage, enemy AI, and defeat | Done | Validated foundation | 24 combat checks passed; shared health and strike components, Forest Gnasher, HP feedback and restart |
| Magicules as a shared resource with regeneration | Done | Validated foundation | 27 Magicule checks passed: spending, failure, delay, regeneration, depletion, HUD, defeat and restart |
| Difficulty-scaled Magicule drops and proximity collection | Done | Combat and Magicules | 32 checks passed: tier stats/rewards, one drop per defeat, collection, overflow, obstruction and restart |
| Absorb a defeated creature, analyze it, acquire one Common Skill | Done | Combat, Magicules and drops | 26 checks passed: cost, corpse selection, range, obstruction, channel, interruption, acquisition and duplicates |
| Skill hotbar, cooldowns, inventory storage, and System Voice | Done | Absorption and analysis | 35 checks passed: acquisition/use loop, skill costs/cooldown, material stacks, capacity, discard, UI and pause |

## Milestones and dependencies

Milestones are ordered by dependencies. Later phases remain provisional until the playable slice establishes scope and balance. No delivery dates have been estimated.

### M0 — Development foundation · Done

- Pin Godot version and establish project folders, input actions, and pixel rendering settings.
- Build a small test scene with placeholder art and player movement.
- Set up repeatable local/cloud validation and reusable installation/startup instructions.
- Exit goal: the project opens, runs, and passes a meaningful headless smoke check.

### M1 — Combat and absorption · Done

- Completed: player health, directional basic attack, chasing enemy, telegraphed bite, damage immunity, defeat, and restart (24 checks passed).
- Completed: shared Magicules, aura-strike spending, delayed regeneration, numeric/bar HUD, depletion and recovery (27 checks passed).
- Completed user-requested addition: difficulty-scaled Magicule drops with proximity collection and overflow preservation (32 checks passed).
- Completed: defeated-creature absorption, timed analysis, and acquisition of Common Skill Rending Bite (26 checks passed).
- Completed: three hotbar slots, Rending Bite activation, shared attack cooldown, bounded material stacks, paused inventory UI, and System Voice/event-log feedback (35 checks passed).
- Exit goal: movement → combat → defeat → absorption → skill use works end to end.

### N0 — Hosted multiplayer + saves · Done

- Completed: ENet host/client architecture, host-validated intents, explicit player ownership, stable character/entity IDs, verified reconnect credentials, and 8 total player capacity.
- Completed: versioned atomic saves/backups for implemented player/entity/world state, reserved character/shared progression dictionaries, and restoration tests. Extend validated schemas as new gameplay systems are added.
- Completed: authoritative movement/combat/rewards and concurrent-claim validation without duplicated loot or skill/material awards.
- Completed: local HUD/inventory binding and per-character menu input blocking; shared simulation continues.
- Passed: 68 real-process networking checks and 32 persistence checks; one host plus seven guests, ninth-player rejection, save/reload/reconnect, invalid credentials, corrupt save recovery. LAN/WAN, encryption, latency and visual playtests remain future validation.
- Exit goal: verified locally with 8-player capacity and restored character/world state; real network deployment remains a follow-up check.

### M2 — First ally and naming · Next, requires N0

- Recruit one nameless ally through a small encounter.
- Name the ally with a visible Magicule cost and confirmation of the expected result.
- Evolve its race, stats, and visual appearance; support depletion and recovery.
- Extend N0 multiplayer/save foundations to persist recruited allies, naming costs, race evolution, and depletion/recovery state.
- Exit goal: naming has a meaningful cost, evolution persists, and depletion cannot be bypassed by reload.

### M3 — First settlement · Planned, requires M2

- Establish a goblin camp with limited resources and a few buildable structures.
- Assign allies to gathering, agriculture, and construction roles.
- Connect exploration rewards to settlement production and growth.
- Exit goal: a complete playable slice from exploration to an evolved ally contributing to the camp.

### M4 — Progression and presentation · Planned, requires M3

- Expand skill data across Common, Extra, Unique, and Ultimate tiers with explicit unlock rules.
- Add analysis/assistant UI, selected skill combinations, and an initial mimic form.
- Develop original regions, factions, sprites, audio, and combat VFX.
- Balance naming costs, skill acquisition, and recovery against actual playtests.
- Exit goal: the core slice is readable, enjoyable, and balanced before adding world scale.

### M5 — Nation building and diplomacy · Planned, requires M4

- Expand settlement services, citizen roles, trade routes, and faction relationships.
- Add emissaries, diplomatic choices, and consequences.
- Introduce settlement threats and a small defensive siege.
- Exit goal: economy and diplomacy change the outcome of a playable conflict.

### M6 — Armies and endgame · Planned, requires M5

- Introduce squad commands, evolved citizen units, and larger invasions.
- Develop major ascensions, Ultimate Skills, and apex encounters.
- Validate performance, progression pacing, accessibility, and save compatibility.
- Exit goal: late-game combat and nation management extend the established core loop reliably.

## Design rules to preserve

- Naming transfers a substantial amount of Magicules from the namer; repeated naming risks exhaustion or temporary sleep.
- Evolution changes race, stats, and silhouette. It must have explicit prerequisites and balanced gains.
- Absorption is followed by analysis; acquisition and mimicry need defined rules rather than granting unlimited power immediately.
- Skills follow Common → Extra → Unique → Ultimate tiers. Strong abilities require appropriate progression.
- The System Voice is cold and concise; the internal assistant exposes useful analysis and automation.
- Citizens matter to the economy and military. Race-specific aptitudes are starting design ideas, not a substitute for individual roles.
- Use placeholder assets for the initial slice; polish after the core loop works.

## Open decisions and risks

| Topic | Default or required decision | When needed |
| --- | --- | --- |
| Godot version | Godot 4.6.3 stable selected and verified | Done |
| Pixel scale and camera | 480 × 320, integer scaling, bounded camera; final art resolution provisional | M0 complete |
| Starting form | Slime/shapeshifter prototype consistent with absorption | M1 |
| Naming balance | Define costs, reserves, exhaustion, and recovery; test exploit cases | M2 |
| World identity | Develop original names, lore, and assets from the supplied inspirations | Before final content production |
| Project scope | Ship a small playable slice before expanding to nation-scale simulation | M3 review |

## Update contract

Open `ROADMAP.html` for the graphical dependency map. Hover or click a title to view its purpose, completion criteria, prerequisites, and successors. Generate the view after roadmap edits with `python3 tools/build_roadmap.py`; it has no external dependencies or running server requirement.

This file is the shared source of truth. At the beginning of project work, read it and select the nearest unmet prerequisite. After meaningful work, update task statuses, verified outcomes, blockers, and the next action. Mark work Done only with evidence. If priorities change, revise dependencies explicitly.

Updates happen during our project work, not through an unattended background process. Future agents follow `AGENTS.md`; work outside these sessions needs a corresponding roadmap update.

## Progress log

- 2026-10-12: Implemented N0 host-authoritative sessions, stable entity/character IDs, reconnect credentials, private profiles, versioned atomic saves/backup recovery, autosave/explicit save/normal shutdown, local multiplayer menus, and per-character respawn. 161 gameplay + 32 persistence + 68 network checks passed; actual CLI host/join also passed. Branch: `codex/roadmap-06-network-saves`. Local eight-player capacity is verified; WAN/encryption/visual checks remain. M2 recruitment/naming is next.

- 2026-10-12: User added hosted multiplayer and complete persistent-world requirements. Inserted N0 before deeper progression and recorded authority, stable identity, character/shared state, local-menu behavior, and save/restore validation in `docs/MULTIPLAYER_AND_SAVES.md`. Runtime networking and saves remain unimplemented; player cap is confirmed as 8 total (1 host + 7 guests).

- 2026-10-12: Completed M1 with usable Common Skill Rending Bite, hotbar cost/cooldown feedback, a second enemy, analyzed-material storage, bag/details/discard UI, gameplay pause during inventory, and an event log. 35 new integration checks and 126 previous checks passed headlessly. Branch: `codex/roadmap-05-skills-storage`. Next: hosted multiplayer and persistent-save foundations, then the first nameless ally and naming/evolution progression.

- 2026-10-12: Added the corpse absorption channel, specimen/skill data, acquired-skill book, analysis progress/notifications, and duplicate protection. 26 absorption checks and the 100 previous checks passed headlessly. Documented inventory and forest/village tileset references. Branch: `codex/roadmap-04-absorption`. Next: hotbar skill activation and dimensional storage.

- 2026-10-12: Added user-requested enemy difficulty and Magicule pickups: Easy 8, Standard 16, Elite 32; health, bite damage and speed scale with tier. Corpses remain for future absorption; pickups preserve overflow, block collection through terrain, and drop only once. 32 drop checks and 68 previous checks passed. Branch: `codex/roadmap-03-magicule-drops`. Documented the incoming title/pause art references. Absorption remains the next step.

- 2026-10-12: Added a reusable Magicule pool with validated spending/restoration, delayed regeneration, HUD feedback, defeat handling, and resource costs on strikes. 27 Magicule checks, 24 combat checks, and 17 foundation checks passed; main scene runs headlessly. Branch: `codex/roadmap-02-magicules`. Recorded the supplied sprite chart in `docs/ART_REFERENCES.md`; clean sprite import remains future work. Next: absorption and analysis.

- 2026-10-12: Added modular combat components and the Forest Gnasher encounter. Import, 24 combat checks, 17 foundation checks, and a 120-frame main-scene run passed. Graph expanded with M1 task dependencies; combat marked Done, Magicules Next. Defeated creatures remain as a foundation for later absorption; no absorption or skills are implemented yet. Visual validation remains pending.

- 2026-10-12: Created the actual Godot project, modular player/world scenes, placeholder clearing/slime, input, pixel rendering, collision, camera, HUD, and restart. Import succeeded; 17 integration checks and a 120-frame main-scene run passed. Repeated the saved setup commands successfully and saved updated install/start instructions. M0 complete for headless development; visual playtesting remains pending. The user requests visible test windows whenever supported. Next: basic combat and one enemy.

- 2026-10-12: Verified the cloud-provided Godot 4.6.3 binary. Configured writable XDG directories outside the checkout; project import and headless GDScript, CharacterBody2D, scene serialization, and frame-processing checks passed using a temporary project. Repeated environment activation successfully; saved install/start instructions as a configuration draft (publication pending). Next: create the actual Godot project.

- 2026-10-12: Added an interactive graphical roadmap with dependency arrows, hover/click details, status colors, and navigation to the next task. The view is generated from this document. Browser checks verified hover/click details, pinned selection, prerequisite/successor navigation, next-task navigation, keyboard focus, zoom, and a mobile layout. Engine and application setup remain pending.

- 2026-10-12: Reviewed the supplied GDD, selected Godot 4/GDScript, and created the shared roadmap. GitHub read access was validated during onboarding. Application setup remains pending because no game project exists yet.
