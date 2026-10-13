# TempestRPG — Living Roadmap

Last updated: 2026-10-13

## Goal

A top-down 2D pixel-art Isekai action RPG in Godot 4 with GDScript, with friends connecting to the user’s host machine and persistent characters/worlds. Explore, fight, absorb creatures and acquire skills, name and evolve allies, and grow a camp into a multi-race nation with trade, diplomacy, and army battles.

## Current focus

**Current focus: step 17 — experience and levels** (first of the user's new systems, 2026-10-13). **User direction change:** the Great Sage / analysis assistant is scrapped; instead come **three playable races (Human, Demon, Slime)**, a **skill tree** fed by level-ups, a drag-and-drop **skill fusion window**, and **gear** (armor, accessories and weapons — sword, spear, scythe, bow — with looks, rarities, stats, and passives/actives on higher rarities). Order by user decision: systems first (17 → 17b → 17c → 17d → 17e → 17f → 17g), then art (18+), so sprites cover all races and weapon types. Step 16d is done (Claude): every new world is laid out from its seed — deposits (positions, outlying amounts 8–12), creature spots and difficulty, the trial stone and ally start (from designed candidate spots), trees and rocks — while the roads, pond, camp and spawn stay fixed. Same seed = same world for the host and every friend; seed 0 is the original hand-made map, and worlds saved before 16d keep it (schema v13 `seeded` flag). Reachability is verified for 200 seeds. 617 local + 256 network = 873 automated checks pass on Windows plus the visual playtest. Step 16c (Claude, Save & quit guard by Codex): the game starts at a title menu with New World (name + seed), Load World (save slots with name, seed and last-played date; damaged files listed), Join a Friend and Quit. Every world is hosted and always saved; solo play opens no port. The pause menu (Esc) offers Resume, **Open to friends** (starts listening in the running world, shows the LAN address), Save and Save & quit to title. The F8 panel is gone. Schema v12 stores world meta. 833 automated checks pass on Windows (579 local + 254 network) plus the visual playtest.

| Task | Status | Prerequisite | Completion evidence |
| --- | --- | --- | --- |
| Establish the game design brief | Done | User's GDD | Genre, core loop, progression rules agreed |
| Choose engine and language | Done | Engine decision | Godot 4 + GDScript selected |
| Create persistent roadmap | Done | GDD and engine | This file and agent update instructions |
| Select and install a stable Godot 4 version | Done | Linux/cloud compatibility | Preinstalled Godot 4.6.3 verified; temporary-project import and GDScript/2D runtime checks passed |
| Create the minimal Godot project | Done | Engine version | Actual project imported without errors in Godot 4.6.3 |
| Define input, pixel scale, and scene structure | Done | Godot project | 480 × 320 viewport (now 640 × 360, step 12), player/camera/world scenes; movement and collision checks passed |
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

### M2 — First ally and naming · Done, requires N0

- Completed: recruit a nameless goblin after defeating the clearing threat; stable ownership, follow behavior, host-only claims and save/reconnect (18 ally checks plus network coverage).
- Completed: cost preview and explicit confirmation, 80-Magicule naming, owner/range/name validation and single evolution.
- Completed: Goblin → Hobgoblin, stats/silhouette changes, minimum 8-second sleep below 25% reserves, recovery at 25%.
- Completed: schema-v3 migration, saved/replicated ally evolution and per-character exhaustion, including respawn without bypassing sleep; 28 naming and 86 network checks passed.
- Exit goal: naming has a meaningful cost, evolution persists, and depletion cannot be bypassed by reload.

### M3 — First settlement · Done, requires M2

- Completed first structure: found a camp with your evolved ally nearby; gather finite wood/stone into shared stock and build one Goblin Hut for 12 wood + 6 stone.
- Verified: one transaction per deposit/structure, safe placement and collision, schema-v4 migration and host restart/client replication (34 local + 42 camp networking checks). Additional structures follow after the work-role loop.
- Completed: owner commands for timed automatic gathering, hut construction and recall; job/target/timer save and replication, autonomous work while owner disconnects. Agriculture remains future work.
- Completed: exploration rewards feed camp growth — outlying player-only deposits, Gnasher Essence offerings, Storehouse and Essence Shrine recipes with real effects, camp level, schema-v6 migration (48 growth checks, 105 camp network checks).
- Completed: visible automated playtest of the full slice on Windows (`tests/visual_playtest.gd`, 22 screenshots in `docs/playtest/`); 640×360 base resolution; HUD/menu readability fixes. Agriculture moves to later settlement work.
- Exit goal: a complete playable slice from exploration to an evolved ally contributing to the camp.

### M4 — Progression and presentation · Next, requires M3

- Expand skill data across Common, Extra, Unique, and Ultimate tiers with explicit unlock rules.
- Add selected skill combinations and an initial mimic form. (User, 2026-10-13: the analysis assistant is scrapped; skills fuse in a drag-and-drop fusion window instead.)
- Add three playable races (Human, Demon, Slime), experience/levels with a per-race skill tree, and gear: armor, accessories and weapons (sword, spear, scythe, bow) with looks, rarities, stats and higher-rarity passives/actives.
- Develop original regions, factions, sprites, audio, and combat VFX.
- Balance naming costs, skill acquisition, and recovery against actual playtests.
- Exit goal: the core slice is readable, enjoyable, and balanced before adding world scale.

### M5 — Nation building and diplomacy · Planned, requires M4

- Expand settlement services, citizen roles, trade routes, and faction relationships.
- Add currency and merchants that sell gear (user decision 2026-10-13: gear also comes from merchants).
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
| Pixel scale and camera | 640 × 360 base (user target 1920 × 1080 = ×3), integer scaling, bounded camera, 1280 × 720 default window | Step 12 done |
| Starting form | Slime/shapeshifter prototype consistent with absorption | M1 |
| Naming balance | 80 cost, 25% recovery reserve, minimum 8-second sleep verified; tune through playtesting | M2 complete |
| World identity | Develop original names, lore, and assets from the supplied inspirations | Before final content production |
| Defenseless at 0 Magicules | Step 16c playtest: every attack costs Magicules, so a drained character cannot fight back; retreating to regenerate works but is easy to miss. Consider a free weak attack or cheaper basic strike | Step 24 (balance) |
| HP recovery and trial difficulty | Step 16 playtest: the trial was too hard without healing. Addressed in 16b by absorbed vitality (Easy 15 / Standard 25 / Elite 40 HP over 10 s); the unassisted playtest now completes the trial. Fine-tune in step 24 | Step 24 |
| Project scope | Ship a small playable slice before expanding to nation-scale simulation | M3 review |

## Ally progression tasks

| Task | Status | Prerequisite | Completion evidence |
| --- | --- | --- | --- |
| Recruit and follow a nameless goblin with persistent ownership | Done | Hosted multiplayer and saves | 18 ally checks and 73 network checks passed, including concurrent claims and reload |
| Name and evolve the ally with saved Magicule costs and exhaustion | Done | Recruited ally | 28 naming and 86 network checks passed: preview, single cost/evolution, recovery, migration and reconnect |

## Settlement tasks

| Task | Status | Prerequisite | Completion evidence |
| --- | --- | --- | --- |
| Found a shared camp, gather finite materials and build the first hut | Done | Named evolved ally and saved world | 34 settlement and 42 real-process camp network checks passed; schema-v4 migration and collision verified |
| Assign the ally to gathering and construction work | Done | First camp and limited materials | 35 worker checks and 63 camp network checks passed: owner commands, jobs, conservation, recall and partial-job reload |
| Connect exploration rewards and production to camp growth | Done | Ally work assignments | 48 camp-growth checks and 105 camp network checks passed: outlying deposits, essence offerings, storehouse/shrine effects, concurrency, schema-v6 migration and reload |

## M4 approved steps

**Approved by the user, 2026-10-12.** Detailed goals, files, authority/save contracts and completion evidence: `docs/M4_PLAN.md`. Steps 13–16 are Done; steps 17 and 18 are Next; later steps remain Planned behind their prerequisites.

| Task | Status | Prerequisite | Completion evidence |
| --- | --- | --- | --- |
| Approve M4 plan | Done | M3 | User explicitly approved steps 13–24 on 2026-10-12 |
| 13 Skill catalogue and unlock ledger | Done | Approve M4 plan | 48 catalogue checks + 4 new network checks: four-tier rule validation, per-character evidence, idempotent unlocks, forged/premature unlock and save rejection, host loadout intent, effect dispatch, eight separate ledgers, v6→v7 migration |
| 14 Second specimen and Extra upgrade | Done | 13 | 37 checks: Thornback encounter, Thorn Lash, Piercing Fang in both unlock orders, line hits/LOS/cost/cooldown, contested corpse, quill/kind save, v7→v8 migration; visible showcase |
| 15 First mimic form | Done | 13, 14 | 30 local + 17 real-process checks: unlock by analysis, cost once, room check, no refills, exhaustion/menus/replicas blocked, defeat/respawn revert, per-character body, v8→v9 migration, replicated/saved/reloaded forms; visible showcase |
| 16 Personal trial and Unique gate | Done | 13, 15 | 40 local + 22 real-process checks: start rules, owner-only credit, four failure paths, no rewards/analysis from trial creatures, Predator Focus reach/time/consumption/no refund/expiry, trial excluded from saves but replicated, v9→v10 migration; visible showcase. Story is a placeholder. |
| 17 Experience and levels (replaces the cancelled analysis assistant) | Next | 13, 16d | Per-character XP from defeats, absorptions and trials; level curve; skill points per level; host-authoritative, replicated, saved and migrated; HUD level/XP readout |
| 18 Prepare sprite, tileset and UI assets | Next | Approve M4 plan | Preserve originals; review transparent exports, pivots/atlases and nearest previews at x2/x3 |
| 19 Character sprites and mimic presentation | Planned | 15, 16, 17b, 17f, 18 | All three races, weapon types and gear looks; visible state/form/evolution animations; combat timing and client identity unchanged |
| 20 Forest and village tiles/props | Planned | 18, 19 | All routes/deposits remain reachable; visual depth, collision/LOS and camp restore pass |
| 21 HUD, skill tree, fusion, equipment and storage UI | Planned | 17d, 17g, 18, 20 | Reference-style presentation of the working skill tree, fusion window, paper doll/equipment and bag; live values, per-client state, focus/contrast/modal rules and x2/x3 visual evidence |
| 22 Title and pause flow | Planned | 21 | Real New/Continue/Join/Resume/Quit paths, host saves, guest disconnect and corrupt-save handling |
| 23 Audio and combat/analysis VFX | Planned | 16, 19, 21 | Clear cues, mute/reduced effects, no duplicate snapshot audio or gameplay timing change |
| 24 Balance and M4 acceptance | Planned | 14, 15, 16, 17d, 17g, 20, 21, 22, 23 | Visible user feedback, measured costs/recovery, eight-player/save checks and scoped LAN validation |
| 16b Healing on absorb | Done | 16 | Codex review: frame-rounding correction accepted; fractional carry now saved (16c). 21 checks: tier heals 15/25/40 over 10 s, gradual and capped, stronger heal replaces weaker, ends on defeat, host-only, saved/reloaded, v10→v11; the unassisted visible playtest now completes the trial |
| 16c Worlds, save slots and menus (user step A) | Done | 16b | Review: Codex's save-failure quit guard accepted (37 local, verified on Windows; 16d builds on it). 35 local + 16 real-process checks: registry/seed parsing, create/save/list/load cycle, damaged files, solo hosting without a port, pause behavior, open to friends mid-game, quit to title, friend kept across reload and rejoin, v11→v12 meta; visible showcase from the title menu |
| 16d Seeded worlds (user step B) | Done | 16c | 36 local + 2 real-process checks: seed 0 = reference map, determinism, 200 seeds checked for IDs, amounts, building budget, placement rules and on-foot reachability (grid flood fill), fresh placement, save/reload from the seed, validation against the seed's deposits, v12→v13 keeps older worlds on the original map, friend sees the host's layout; playtest screenshots of two seeds |
| 17b Playable races: Human, Demon, Slime | Planned | 17 | Race chosen when a character is created (host's new world, friend's first join); per-race base stats and one racial ability; everyone can absorb but the Slime absorbs best; mimic forms stay Slime-only; existing characters migrate as Slimes |
| 17c Skill tree | Planned | 17, 17b | Per-race tree: stat nodes bought with level-up points and a new skill every few nodes; skills gained by leveling/absorbing stay locked until activated in the tree; only active skills fit the hotbar; forged activations rejected |
| 17d Skill fusion window | Planned | 17c | Drag-and-drop window (skills listed on the right); dropping two fusable skills onto each other replaces both with the fused skill; a fused skill can always be split back into its two originals; data-driven recipes; Piercing Fang becomes a fusion |
| 17e Gear foundation: armor and accessories | Planned | 17b | Equipment slots, item instances with stable IDs, rarities, stat rolls, passives on higher and actives on the highest rarities, distinct looks; equip/unequip per character; saved and validated |
| 17f Weapons: sword, spear, scythe, bow | Planned | 17e | Each weapon type has its own attack shape (arc, long thrust, wide sweep, projectile) and rarity scaling; host-authoritative hits; replicated |
| 17g Gear sources: drops, chests, camp crafting | Planned | 17f | Creature drops by tier, seeded chests/points of interest and trial rewards, a camp forge recipe; merchants follow with currency/trade in M5 |

## Update contract

Open `ROADMAP.html` for the graphical dependency map. Hover or click a title to view its purpose, completion criteria, prerequisites, and successors. Generate the view after roadmap edits with `python3 tools/build_roadmap.py`; it has no external dependencies or running server requirement.

This file is the shared source of truth. At the beginning of project work, read it and select the nearest unmet prerequisite. After meaningful work, update task statuses, verified outcomes, blockers, and the next action. Mark work Done only with evidence. If priorities change, revise dependencies explicitly.

Updates happen during our project work, not through an unattended background process. Future agents follow `AGENTS.md`; work outside these sessions needs a corresponding roadmap update.

## Progress log

- 2026-10-13: **User direction change (planned by Claude Code with the user).** Step 17 (analysis assistant / Great Sage) is cancelled and becomes **17 Experience and levels**. New steps 17b playable races (Human, Demon, Slime; everyone absorbs, Slime best; mimic Slime-only), 17c skill tree (level-up points for stats; a new skill every few nodes; acquired skills must be activated in the tree), 17d skill fusion window (drag and drop; fusing consumes both originals; a fused skill can always be split back), 17e gear foundation (armor/accessories, rarities, stats, passives/actives), 17f weapons (sword, spear, scythe, bow), 17g gear sources (drops, chests, camp crafting; merchants in M5). Systems before art; 19, 21 and 24 now depend on the new steps. Codex reviewed 16d with no findings (873 checks on Linux). Branch: `claude/plan-races-skilltree-gear`.

- 2026-10-13: Codex reviewed seeded-world step `3191d72`, confirmed the save-and-quit correction is carried forward, and independently reproduced 873 checks on Linux (617 local + 256 network), import and startup. Additional 10,000-seed placement probe found no failures; 38 screenshots/log links verified. No blocking findings; documentation acknowledgment on `codex/review-seeded-worlds`. Next remains 17.

- 2026-10-13: Claude Code completed step 16d (user step B), built on Codex's accepted `codex/fix-save-before-quit`. New `scripts/world/world_layout.gd` (`generate(seed)`, `seed_of(meta)`, `describe(meta)`); `forest.gd` `apply_layout(seed, fresh)` rebuilds deposits, trial stone, trees/rocks (with collisions) and, for a new world, places creatures/ally and resets the camp; `FirstCamp.sites` and `ProvingTrial.stone` are per world (constants stay as the reference map); `GameSession` applies the layout on host start and from snapshot meta on clients; `SaveStore` v13 validates the camp against the seed's deposits and adds `meta.seeded` (false for migrated worlds). Random seeds are never 0. New `tests/seeded_worlds.gd` (36), +2 checks in `tests/network_worlds.py`. 617 local + 256 network = 873 checks pass on Windows. Branch: `claude/roadmap-16d-seeded-worlds`. Next: 17.

- 2026-10-13: Codex reviewed 16c through `0bf7ac3`: 833 existing Linux checks pass; both previous healing findings confirmed resolved. Found Save & quit discards live progress on save failure; separate correction on `codex/fix-save-before-quit` retains world/menu for retry, two regressions pass (37 menu checks, 16 network checks rerun). Correction and acknowledgment published after retrying a transient GitHub authentication failure. Next remains 16d.

- 2026-10-13: Claude Code completed step 16c (user step A). New title menu (`scenes/menu/title_menu.tscn`, now the main scene) and `scripts/menu/world_registry.gd` (save slots in `user://worlds/`, name cleaning, Minecraft-style seed parsing, listing with damaged files). `GameSession`: solo hosting with an offline peer (`start_host(..., listen = false, meta)`), `open_to_friends()`, `launch_pending()`, `quit_to_title()`, world meta in every save. Pause menu (Esc) replaces the F8 panel. Schema v12. New `tests/worlds_menu.gd` (35) and `tests/network_worlds.py` (16); the smoke test now loads the world scene explicitly. 579 local + 254 network checks pass on Windows. Branch: `claude/roadmap-16c-worlds-menus`. Next: 16d seeded worlds.

- 2026-10-13: Codex independently reviewed steps 16/16b: 776 existing Linux checks, import and startup pass. Extra probes found one HP lost at frame-sized healing ticks (proposed correction on `codex/fix-absorbed-vitality-rounding`, verified) and fractional progress lost on reload (pending Claude’s claimed 16c save files). Handoff includes exact reproduction and restoration requirements; passing existing tests do not resolve that save defect.

- 2026-10-13: Claude Code completed step 16b (user request): absorbed vitality heals by creature tier (Easy 15 / Standard 25 / Elite 40 HP over 10 s, host-only, capped, no stacking unless stronger, ends on defeat), HUD shows "+ healing", schema v11. New `tests/absorb_healing.gd` (21). The visual playtest no longer restores HP before the trial and still passes. User decisions recorded: new steps 16c (worlds/save slots/menus, "Open to friends") and 16d (seeded worlds) come before 17. 538 local + 238 network checks pass on Windows. Branch: `claude/roadmap-16b-absorb-healing`.

- 2026-10-13: Claude Code completed M4 step 16 with a placeholder story (user decision). New `scripts/trials/proving_trial.gd` (stone at (480, 100), F to start, 3 Easy no-reward creatures, 60 s, 150 px arena, owner-only credit, fail on defeat/leaving/disconnect/timeout, never saved), `SkillBook.record_trial`, Unique **Predator Focus** (`focus` effect, 25 Magicules: next analysis within 20 s has double reach and a 0.3 s channel, consumed at start), 4th hotbar slot/key 4, HUD trial banner, schema v10. New `tests/trial_unique.gd` (40) and `tests/network_trial.py` (22); visual playtest fights the trial. 517 local + 234 network checks pass on Windows. Branch: `claude/roadmap-16-trial-unique`. Next: 17, 18; the story placeholders await the user's storyline.

- 2026-10-13: Codex reviewed Claude mimic-form step `59d035c`, confirmed the prior save-prerequisite correction is carried forward, and independently reproduced 689 checks on Linux (477 local + 90 general network + 105 camp network + 17 form network), import and startup. Verified 28 screenshot files/log links and inspected the mimic capture. No blocking findings; documentation-only acknowledgment on `codex/review-mimic-form`. Steps 16/17/18 remain ready; no new feature claim or merge.

- 2026-10-13: Claude Code completed M4 step 15 (next step in order, user decision) on top of Codex's accepted step-14 save fix (`ca95570`, verified on Windows: 642 checks). Added `scripts/forms/form_catalogue.gd` (base Slime; Gnasher Form unlocked by Forest Gnasher analysis: 20 Magicules, ×1.3 speed, +4 basic strike, radius 8), player `try_transform` with room check and 2s change cooldown, `transform` host intent and T key, defeat-to-slime policy, HUD form line, schema v9. New `tests/mimic_form.gd` (30) and `tests/network_forms.py` (17 real-process checks); visual playtest shows Gnasher Form. 477 local + 212 network checks pass on Windows. Branch: `claude/roadmap-15-mimic-form`. Next: 16, 17, 18.

- 2026-10-13: Codex reviewed step-14 `ce35b1d` and reproduced its 636 checks on Linux; verified 27 screenshot files/log links. Found and reproduced an inconsistent-save case allowing Piercing Fang without required known Commons. Separate branch `codex/fix-extra-skill-save-prerequisites` requires actual known prerequisites; 6 new regressions fail before/pass after, full fixed suite 642 checks plus startup passed. Acknowledgment published; Claude’s branch unchanged and user version selection pending.

- 2026-10-13: Claude Code completed M4 step 14 (next step in order, user decision). Added the Thornback Gnasher (`scenes/enemies/thornback_gnasher.tscn`, kind `thornback`, southeast corner (880, 560)), specimen `thornback_gnasher` with material Thornback Quill, Common skill Thorn Lash (14 dmg, 8 Magicules, 0.5s) and Extra skill Piercing Fang (`pierce` effect: 64px line, 26 dmg to every creature in it, 18 Magicules, 1.2s), unlocked by Rending Bite + Thorn Lash + Thornback analysis. Saves v8: enemy kind and material IDs validated against the catalogue; v7 worlds gain one living Thornback. New `tests/extra_skill.gd` (37 checks); visual playtest extended to hunt the Thornback and fire Piercing Fang. 441 local + 90 + 105 network checks pass on Windows. Branch: `claude/roadmap-14-extra-skill`. Next: 15 (mimic), 17 (assistant model), 18 (assets).

- 2026-10-13: Codex reviewed Claude step-13 implementation and visual-script hardening through `1fa7f13`; independently reproduced 599 checks, clean import and startup on Linux. No blocking gameplay findings; clarified README save-validation and visual-test status wording. Documentation-only acknowledgment on `codex/review-skill-catalogue-complete`; no merges or new feature claim. Steps 14 and 18 remain ready.

- 2026-10-12: Claude Code completed M4 step 13 (user decision: Claude takes the next step in order). Added `scripts/skills/skill_catalogue.gd` (stable skill/specimen/trial/ascension IDs, tier rule shapes and validation), per-character `skill_evidence` in the skill book, rule-based unlocks on analysis (no direct grants), host `assign_slot` intent, effect dispatch for skill activation, a read-only requirements overview, and schema v7 (saved skills must be justified by evidence; v6 migration rebuilds analyses only from actual knowledge). User art decision: the Forest Gnasher will use the Goblin row of the monster chart. 404 local + 90 + 105 network checks and the visual playtest pass on Windows. Branch: `claude/roadmap-13-skill-catalogue`. Next: step 14 (second specimen + Extra) and step 18 (assets).

- 2026-10-12: User explicitly approved the M4 plan (steps 13–24). Recorded approval in plan/handoff/graph; steps 13 (Codex skill foundations) and 18 (Claude asset preparation) are ready in parallel. Later steps retain their dependencies and require ownership claims before edits. Commit/push on `codex/m4-plan`; no implementation or branch merge in this approval update.

- 2026-10-12: Codex reviewed Claude step-12 `41a9558`, verified 22 decodable 640×360 screenshots/log links, inspected representative menus/camp captures and reproduced 547 headless checks plus startup on Linux. Drafted proposed M4 steps 13–24, approval gate, tier rules and parallel file ownership in `docs/M4_PLAN.md` and this roadmap. Branch `codex/m4-plan`; no gameplay implementation or merge. User approval pending.

- 2026-10-12: Claude Code completed roadmap step 12 and closed M3. Switched base resolution 480×320 → 640×360 (user decision; 1920×1080 = ×3) with a 1280×720 window and re-centered HUD, hotbar, event log, inventory, camp, ally and host/join panels. Added `tests/visual_playtest.gd`, a visible automated run of the whole slice using real input actions, with 22 screenshots and a log in `docs/playtest/`. Fixes from the playtest: camp-menu help text overlapping buttons (larger menu), event-log scrollbar/cut-off lines, unreadable stats/analysis text over terrain (translucent backing panels), player hidden under the log at the map's bottom-left corner (southwest stone moved to (200, 540)). All 547 checks plus the playtest pass on Windows. Branch: `claude/roadmap-12-visual-playtest`. Next: Codex drafts the M4 plan.

- 2026-10-12: Codex reviewed Claude image additions `3d839e3`/`758ccc6`. All seven originals now pass independent image decoding/dimension/SHA256 checks. Corrected stale missing-image documentation and retained earlier review acknowledgments on `codex/review-complete-reference-library`. No gameplay edits, integration or new gameplay test run. Visible playtest remains next.

- 2026-10-12: Claude Code completed roadmap step 11, exploration rewards and camp growth. Added three outlying deposits (player-gathered; workers stay near camp), host-side Gnasher Essence offerings, Storehouse (10 wood + 6 stone, halves ally work time) and Essence Shrine (8 stone + 2 essence, doubles Magicule regeneration within 60px), both unlocked by the hut; worker Build now picks the next funded structure; camp level shown in the B menu. Schema v6 with v5→v6 migration and conservation checks for essence. Windows validation: 356 local (incl. 48 new growth checks) + 191 network (86 general + 105 camp) checks plus main-scene startup. Branch: `claude/roadmap-11-camp-growth`. Next: visual playtest of the full slice, then M3 review.

- 2026-10-12: Added shared `assets/` reference/source/game-art folders, common tool guidance and an index for the six supplied conversation images. Original image files are unavailable in the cloud and explicitly marked missing; source images still need to be supplied or added locally by Claude. No gameplay changes; Claude retains ownership of camp growth. Branch: `codex/shared-art-assets`.

- 2026-10-12: Codex acknowledged Claude’s full handoff and reviewed commit `1f59d03` (portable test paths, UTF-8 roadmap generation and coordination board). Review-only documentation branch `codex/acknowledge-claude-handoff`; no gameplay changes, independent test rerun or merge. Added reciprocal pushed review acknowledgments. Next gameplay task unchanged; user baseline selection pending.

- 2026-10-12: Claude Code joined (Windows 11, local Godot 4.6.3 with a display). Fixed three tests that saved to Linux-only `/tmp` and hung on Windows; all 457 checks (308 local + 149 network) plus main-scene startup now pass on Windows as well as Linux. Added the coordination board and the user's cross-review rule to the handoff/AGENTS. Branch: `claude/fix-windows-test-paths`. Next roadmap step unchanged: exploration rewards and camp growth.

- 2026-10-12: Added Gather/Build/Follow camp commands, finite timed citizen jobs, single completion rewards/costs, blocked-site waiting and recall. Schema-v5 retains role/target/time and migrates old allies to Follow. 457 checks passed headlessly (308 local + 86 general network + 63 camp network), plus main-scene startup. GitHub/Claude handoff checked before architecture and commit. Branch: `codex/roadmap-10-ally-work`. Next: exploration rewards and camp growth.

- 2026-10-12: Added the shared first camp, finite deposits, evolved-ally founding requirement, one costed hut with collision, B camp UI, validated schema-v4 migration and host save/replication. 401 checks passed headlessly (273 local + 86 prior network + 42 camp network), plus main-scene startup. Reinforced reciprocal Claude/Codex checks before critical steps and commits. Branch: `codex/roadmap-09-first-camp`. Next: ally work assignments.

- 2026-10-12: Completed naming/evolution and persistent exhaustion; 325 total checks passed headlessly (239 local + 86 network), plus main-scene startup. Added Claude Code entry point and shared AI handoff/common collaboration rules. Branch: `codex/roadmap-08-naming-evolution`. Next: M3 first persistent camp.

- 2026-10-12: Added the first goblin, threat-gated recruitment, stable ownership, collision-aware following, interaction UI and schema-v2 migration/save/replication. 18 ally checks and 73 network checks passed alongside 193 previous local checks (284 total). Branch: `codex/roadmap-07-first-ally`. Naming/evolution/recovery is next.

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
