# TempestRPG — Living Roadmap

Last updated: 2026-10-12

## Goal

A top-down 2D pixel-art Isekai action RPG in Godot 4 with GDScript, with friends connecting to the user’s host machine and persistent characters/worlds. Explore, fight, absorb creatures and acquire skills, name and evolve allies, and grow a camp into a multi-race nation with trade, diplomacy, and army battles.

## Current focus

**Current focus: M4 steps 15 (first mimic form), 17 (analysis assistant model) and 18 (asset preparation) are ready.** Step 14 is done (Claude): a Thornback Gnasher variant in the southeast corner, a second Common skill (Thorn Lash) and the first Extra skill (Piercing Fang: a line thrust that hits every creature in it), unlocked only when a character knows both Rending Bite and Thorn Lash with Thornback evidence, in either order. Schema v8 adds enemy kinds, the Thornback Quill material and the encounter to older worlds. 636 automated checks pass on Windows (441 local + 90 general network + 105 camp network) plus the extended visual playtest. Details: `docs/M4_PLAN.md`. Real LAN/WAN checks and final art/audio remain pending.

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
| Pixel scale and camera | 640 × 360 base (user target 1920 × 1080 = ×3), integer scaling, bounded camera, 1280 × 720 default window | Step 12 done |
| Starting form | Slime/shapeshifter prototype consistent with absorption | M1 |
| Naming balance | 80 cost, 25% recovery reserve, minimum 8-second sleep verified; tune through playtesting | M2 complete |
| World identity | Develop original names, lore, and assets from the supplied inspirations | Before final content production |
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

**Approved by the user, 2026-10-12.** Detailed goals, files, authority/save contracts and completion evidence: `docs/M4_PLAN.md`. Steps 13 and 14 are Done; steps 15, 17 and 18 are Next; later steps remain Planned behind their prerequisites.

| Task | Status | Prerequisite | Completion evidence |
| --- | --- | --- | --- |
| Approve M4 plan | Done | M3 | User explicitly approved steps 13–24 on 2026-10-12 |
| 13 Skill catalogue and unlock ledger | Done | Approve M4 plan | 48 catalogue checks + 4 new network checks: four-tier rule validation, per-character evidence, idempotent unlocks, forged/premature unlock and save rejection, host loadout intent, effect dispatch, eight separate ledgers, v6→v7 migration |
| 14 Second specimen and Extra upgrade | Done | 13 | 37 checks: Thornback encounter, Thorn Lash, Piercing Fang in both unlock orders, line hits/LOS/cost/cooldown, contested corpse, quill/kind save, v7→v8 migration; visible showcase |
| 15 First mimic form | Next | 13, 14 | Owned transform/revert, safe collision, no resource refill and replicated saved form |
| 16 Personal trial and Unique gate | Planned | 13, 15 | One personal trial/Unique; mastery saved, Ultimate explicitly locked for future ascension |
| 17 Analysis assistant model | Next | 13, 14 | Read-only factual traits/unlock/recovery advice isolated to each character |
| 18 Prepare sprite, tileset and UI assets | Next | Approve M4 plan | Preserve originals; review transparent exports, pivots/atlases and nearest previews at x2/x3 |
| 19 Character sprites and mimic presentation | Planned | 15, 16, 18 | Visible state/form/evolution animations; combat timing and client identity unchanged |
| 20 Forest and village tiles/props | Planned | 18, 19 | All routes/deposits remain reachable; visual depth, collision/LOS and camp restore pass |
| 21 HUD, assistant and storage UI | Planned | 17, 18, 20 | Live values, per-client inventory, focus/contrast/modal rules and x2/x3 visual evidence |
| 22 Title and pause flow | Planned | 21 | Real New/Continue/Join/Resume/Quit paths, host saves, guest disconnect and corrupt-save handling |
| 23 Audio and combat/analysis VFX | Planned | 16, 19, 21 | Clear cues, mute/reduced effects, no duplicate snapshot audio or gameplay timing change |
| 24 Balance and M4 acceptance | Planned | 14, 15, 16, 17, 20, 21, 22, 23 | Visible user feedback, measured costs/recovery, eight-player/save checks and scoped LAN validation |

## Update contract

Open `ROADMAP.html` for the graphical dependency map. Hover or click a title to view its purpose, completion criteria, prerequisites, and successors. Generate the view after roadmap edits with `python3 tools/build_roadmap.py`; it has no external dependencies or running server requirement.

This file is the shared source of truth. At the beginning of project work, read it and select the nearest unmet prerequisite. After meaningful work, update task statuses, verified outcomes, blockers, and the next action. Mark work Done only with evidence. If priorities change, revise dependencies explicitly.

Updates happen during our project work, not through an unattended background process. Future agents follow `AGENTS.md`; work outside these sessions needs a corresponding roadmap update.

## Progress log

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
