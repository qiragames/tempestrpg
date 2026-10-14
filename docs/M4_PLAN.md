# M4 — Progression and presentation

**Approved by the user on 2026-10-12. Steps 13–24 may proceed under the dependencies and ownership rules below.**

Drafted by Codex, 2026-10-12, after reviewing Claude step 12 at `41a9558`. Baseline: Godot 4.6.3, 640×360 integer-scaled viewport, eight total players, host authority, schema v6, completed first camp loop. Claude's Windows visual run/log and 22 screenshots are in `docs/playtest/`; Codex independently reproduced 547 headless checks on Linux and inspected representative captures. This is automated visual evidence, not a substitute for the user's feedback on feel/balance.

## Order and scope

Each numbered step is one feature branch with meaningful completion evidence, its own roadmap/handoff update and push. Titles and mechanic names below are working proposals. Preserve implemented combat, naming, exhaustion, camp conservation and old-save behavior.

Codex handles the mechanical progression lane (13–17). Claude can prepare art (18) alongside it, then handle scene/UI presentation (19–23). The final balance step (24) combines Claude's visible tests and Codex's authority/persistence checks. No delivery dates are estimated. Do not implement an entire catalogue of high-tier abilities, a whole new region, equipment, quests or diplomacy as part of one step.

## Approved tier rules

| Tier | Unlock rule | M4 deliverable |
| --- | --- | --- |
| Common | Complete authoritative analysis of a supported specimen | Preserve Rending Bite; add one second Common skill in 14 |
| Extra | Know the specified pair of Common skills and successfully analyze the second specimen | One explicitly defined upgrade in 14; no random unlocks |
| Unique | Know the required Extra and complete a personal trial once in 16 | One usable Unique skill, with host-validated prerequisites |
| Ultimate | Required Unique mastery plus a personal ascension milestone | Data/locked UI/validation supported in M4; no grant or playable Ultimate until an approved later ascension step (currently M6) |

Personal trial/mastery evidence belongs to the character. A shared camp level alone must not grant a late-tier skill to every guest. Repeating absorption/reconnecting never duplicates unlocks. Migration reconstructs only evidence implied by actual saved knowledge and never fabricates completed trials. Higher tiers have explicit costs/cooldowns and do not bypass the existing resource, exhaustion or global attack-recovery rules. Precise balance values are proposed with each feature and tuned in 24.

## 13 — Skill catalogue and unlock ledger (Claude, by user decision) — **Done**

**Status 2026-10-12:** implemented by Claude on `claude/roadmap-13-skill-catalogue` because the user asked Claude to take the next step in order. Contract for later steps: `SkillCatalogue.RULES` (tier rule shapes), `SKILLS`/`SPECIMENS`/`TRIALS`/`ASCENSIONS` (stable IDs), `SkillBook.record_analysis(id)` (host-only evidence + unlock), `SkillBook.assign_slot` / `assign_slot` intent, `SkillDefinition.effect` dispatched in `MeleeAttack.attack_skill`, `SkillBook.describe()` / `SkillCatalogue.overview()` read-only view for 17/21. Step 14 adds a specimen + Common + Extra by extending these tables and the effect match; 16 adds a trial ID to `TRIALS` and a recorder for trial evidence.

**Goal/dependencies:** after M4 approval, define stable tier/skill/unlock IDs and a per-character progression ledger while keeping Rending Bite behavior intact. This is the contract for later skills and assistant queries.

**Files/systems:** `data/skills/`, `scripts/skills/`, narrowly scoped skill intents in `scripts/network/game_session.gd`, `scripts/persistence/{state_codec,save_store}.gd`, skill/persistence tests. Publish the effect-dispatch/read-only-query contract before presentation work binds to it.

**Authority/save:** host owns acquisition, unlock evidence, slot assignment and activation; clients send owned intent/definition IDs. Save unlocked IDs, loadout and genuine personal evidence with a versioned migration from v6; never serialize executable paths supplied by clients. Validate all four tier labels and missing/invalid prerequisites.

**Done evidence:** old saves preserve skills/resources/loadout; forged/premature unlocks fail; duplicate/reconnect acquisition is idempotent; eight-character ownership stays separate. Existing combat/absorption/network suites pass. Locked Ultimate remains unavailable.

## 14 — Second specimen and one Extra upgrade (Claude, next in order by user decision) — **Done**

**Status 2026-10-13:** implemented on `claude/roadmap-14-extra-skill`. Thornback Gnasher (enemy kind `thornback`, entity `thornback_1` at (880, 560), specimen `thornback_gnasher`, material `thornback_quill`), Common **Thorn Lash** (`strike`, 14/8/0.5s), Extra **Piercing Fang** (`pierce`, 64×14 px line, 26 dmg per creature, 18 Magicules, 1.2s) with rule `requires [rending_bite, thorn_lash]` + `analysis thornback_gnasher`. Enemy kinds map to scenes in `StateCodec.ENEMY_SCENES`; materials to specimens in `SkillCatalogue.MATERIALS`. Schema v8 migration adds one living Thornback to v7 worlds. The Thornback uses placeholder drawing (purple body + quills) until step 19.

**Goal/dependencies:** requires 13. Add one modest variant encounter with a distinct specimen and second Common skill. Suggested low-scope upgrade: existing Rending Bite plus a second analyzed trait unlocks an Extra piercing strike; final names/numbers remain proposals.

**Files/systems:** a new specimen/skill definition and modular encounter scene, `scripts/enemies/`, skill effect dispatcher, absorption definition lookup and world encounter wiring; codecs/validation only for the newly added persistent entities/effects.

**Authority/save:** host validates combat, drops, corpse reservation, analysis and exact unlock combination. Persist stable encounter/specimen IDs, knowledge and consumed-world state; single awards under simultaneous absorption. Temporary strike/cooldown state follows the existing recovery contract.

**Done evidence:** both Common skills and the Extra can actually be earned/used; unsupported combinations fail; two players cannot claim the same corpse twice; save/reload preserves claims and unlocks. Use placeholders until 19.

## 15 — First mimic form (Claude, next in order by user decision) — **Done**

**Status 2026-10-13:** implemented on `claude/roadmap-15-mimic-form`. `FormCatalogue.FORMS` (`slime` base; `gnasher`: analysis `forest_gnasher`, cost 20, speed ×1.3, basic-strike +4, radius 8), `Player.try_transform` (host-only; unlocked, alive, awake, off cooldown, room for a larger body, cost paid on success), `transform` intent `{form}`, T key, `CHANGE_COOLDOWN` 2s, defeat reverts to base (respawn as slime), saved `form = {id, cooldown}` (schema v9). Visual form ID for step 19: `Player.form`. Placeholder: cyan Gnasher silhouette.

**Goal/dependencies:** requires 13–14. Unlock one analyzed creature form, allow transform/revert with an explicit Magicule cost, and give it one bounded movement/attack difference.

**Files/systems:** `scripts/forms/`, player movement/ability dispatch, explicit form intent, form definitions, character codec/schema and tests. Retain player identity and camera; expose visual form ID for 19.

**Authority/save:** host checks genuine specimen knowledge, alive/awake state, cost and safe collision placement. Persist selected/unlocked form IDs and any gameplay timers/modifiers. Transformation never refills HP/Magicules, clears naming exhaustion or alters inventory/character ownership. Reversion must work if a shape would overlap terrain; choose safe placement rules before coding.

**Done evidence:** form changes are replicated to two clients, old characters migrate to Slime, resources/cooldowns survive switching and reconnect, blocked transformations fail without charging, and death/respawn retain an explicit safe-form policy.

## 16 — Personal trial, one Unique and future Ultimate gate (Claude, next in order by user decision) — **Done (placeholder story)**

**Status 2026-10-13:** implemented on `claude/roadmap-16-trial-unique`. **All names, text and looks are placeholders** until the user writes the storyline. Trial `proving_trial` (`scripts/trials/proving_trial.gd`): stone (480, 100), start with F (intent `trial {operation: "start"}`) when the character knows `piercing_fang`, has not completed it, is alive/awake/at the stone and no trial runs; 3 Easy creatures (`trial_0..2`, no specimen, `drops_rewards = false`); success when all fall within 60 s while the owner is alive and within 150 px; fails on owner defeat/leaving/disconnect/timeout; only the owner is credited (`SkillBook.record_trial`). Running trials replicate in snapshots (`trial` state + creatures) but `GameSession.persistent_document()` strips them from saves, so a host restart cancels the attempt. Unique `predator_focus` (`focus` effect, 25 Magicules, 1 s cooldown): arms `Absorption.focus_left` = 20 s; the next analysis has double reach and a 0.3 s channel, focus is consumed when it starts (no refund), and it cannot stack. Fourth hotbar slot (`skill_4`, key 4). Mastery is not recorded yet and no Ultimate/ascension exists, so Ultimate remains locked. Schema v10 (4 slots, `analysis.focus`).

**Goal/dependencies:** requires 13–15. Add one small trial using the existing map/encounter foundations, unlock one Unique synthesis from its personal completion and the required Extra. Suggested Unique: Predator Focus, a costed modifier to the next analysis, with limits defined before implementation. Ultimate remains locked behind future ascension.

**Files/systems:** bounded encounter/trial definitions, `scripts/skills/`, analysis effect contract and personal progression; narrowly scoped world/authority/save extensions and tests. This is one trial and one Unique, not a quest system or a full boss campaign.

**Authority/save:** host records completion once for qualifying participants under explicit attribution rules; spectators/reconnecting guests do not inherit it. Save personal trial and mastery IDs plus timed/one-use effect state; bound analysis modifier and consumption rules so interrupt/reload cannot duplicate a benefit.

**Done evidence:** trial can be completed legitimately; unauthorized/duplicate rewards and cross-character unlocks fail; interrupted analysis obeys the chosen paid-benefit rules; Unique works once per activation; Ultimate is visibly and mechanically locked until real ascension exists.

## 17 — Analysis assistant model (Codex) — **Cancelled by the user (2026-10-13)**; see "User direction change" below

**Goal/dependencies:** requires 13–14. Expose factual specimen traits, known skills, unlock requirements, current form and resource/recovery advice through a read-only analysis model. It supplies the Great Sage-inspired panel in 21.

**Files/systems:** `scripts/analysis/`, specimen/skill read APIs and tests; keep `scripts/ui/game_hud.gd` and render/layout files free for Claude. This is deterministic game analysis, not an external AI service.

**Authority/save:** derive suggestions from authoritative character/world state; validate any later requested action through existing host intents. Never grant rewards through the panel. Save only genuinely earned discoveries if added; explanatory text and UI selection are local and need no world persistence.

**Done evidence:** the model distinguishes unknown/known traits, locked tiers, interrupted analysis and exhausted state; each client sees its own discoveries; advice matches actual costs/timers and never invents gear/quests/stats.

## 18 — Prepare sprite, tileset and UI assets (Claude; parallel lane) — **Done**

**Status 2026-10-13:** prepared on `claude/roadmap-18-assets` from four licence-checked packs (see `CREDITS.md`, `assets/references/index.json`). Role mapping: Slime = Ninja `Slime3`, Human = `Boy`, Demon = `DemonRed`; Gnasher = Pixel Crawler `Orc` (user: Goblin look), Thornback = `Orc - Shaman`, goblin ally = `Orc - Rogue`, Hobgoblin = `Orc - Warrior`; gear icons per base and rarity (Kyrise a..e; Shade metals for scythe/spear). Pixel Crawler creatures are side-view only (flip for the other side); Ninja sheets have columns = down, up, left, right. Integration is 19–21.

**Goal/dependencies:** M4 approval; can run alongside 13–17. Prepare a small usable export set from the seven preserved references at 640×360 without touching gameplay files.

**Files/systems:** `assets/references/index.json` for provenance additions, `assets/source/`, `assets/game/{sprites,world,ui}/`, preparation notes. Preserve original JPEG/PNG/WebP bytes. Record atlas cells, animation ordering/timing, pivots, transparency and intended use.

**Authority/save:** visual-only resources, no progression/save mutations. Assets use stable named paths; rendered labels/stats remain dynamic. The chart has no explicitly labeled Forest Gnasher row. **User decision 2026-10-12: the Forest Gnasher uses the Goblin row**; keep enemy and allied goblins visually distinct (e.g. palette/difficulty tint) without changing creature IDs. JPEG/chart labels/backgrounds require cleanup; approve poor-quality slices before integration.

**Done evidence:** inspect slime, goblin/Hobgoblin and Gnasher/form candidates, one small forest atlas/props set and reusable frame/icon pieces; nearest-filter export preview at ×2 and ×3; originals/index checksums retained. Actual scene integration is 19–22.

## 19 — Character/enemy sprites and mimic presentation (Claude) — **Done**

**Status 2026-10-13:** integrated on `claude/roadmap-19-character-sprites` via `scripts/visual/sprite_library.gd`. Bodies are `AnimatedSprite2D` children drawn behind each node's own `_draw` (bars, gear, markers). Movement is read from position changes on every peer, so clients need no new replicated fields. Weapon/gear looks remain the 17e/17f overlay shapes for now; the size gap between Pixel Crawler creatures (~26 px) and Ninja characters (16 px) is recorded for step 24.

**Goal/dependencies:** requires 15–16 and 18 so gameplay/form contracts are stable. Bind prepared art to idle/walk/attack/death, evolution and transform states.

**Files/systems:** character/ally/enemy render child scenes/scripts and prepared sprite resources. Coordinate renderer adapters separately from Codex's state components; do not rewrite attack/health/form authority while replacing drawings.

**Authority/save:** consume replicated actor/race/form/action state. Local animations are presentation only; they cannot inflict damage, spend resources or finish analysis. Persist semantic IDs, not frame numbers or animation node paths.

**Done evidence:** visible captures of all relevant states at ×2/×3, consistent feet/pivots/z-order, readable attack telegraph; headless tests confirm costs/attack timing unchanged and clients see the same forms/evolution.

## 20 — Forest and village tiles/props (Claude) — **Done**

**Status 2026-10-13:** integrated on `claude/roadmap-20-tiles-props` via `scripts/visual/world_art.gd`. The map geometry (roads, pond, borders, seeded rocks/trees, camp footprints) is unchanged; art is anchored to it (a prop's foot = the bottom edge of its collision footprint + 2 px). Ground is drawn by `forest.gd` from tiles (no TileMapLayer resource needed for a 960x640 map drawn once); props/buildings are `Sprite2D`s under y-sorted parents. No migration: nothing saved changed.

**Goal/dependencies:** requires 18–19. Replace the initial clearing visuals with a small tile/prop slice while preserving encounter/camp/deposit IDs and routes.

**Files/systems:** `assets/game/world/`, TileSet/TileMapLayer resources, `scenes/world/forest.tscn`, world drawing/collision presentation, structure render resources. Keep walkable routes and doors; canopy art must not block paths.

**Authority/save:** collisions used by the host and replicas must agree. Save world IDs and dynamic built/depleted flags as today; static tile art needs no per-character state. Explicit migration required if gameplay locations or saved world geometry become incompatible.

**Done evidence:** replay the full slice around terrain/buildings; all deposits reachable, no trapped spawn or misaligned hut footprints; visual depth/occlusion checks and authoritative collision/LOS/network regressions pass.

## 21 — Reference-style HUD, assistant and storage UI (Claude) — **Done**

**Status 2026-10-14:** integrated on `claude/roadmap-21-ui`. The "assistant" is the existing Analysis box (the Great Sage was dropped by the user), styled cyan. Shared look in `scripts/ui/ui_style.gd`: a Theme merged into `ThemeDB.get_default_theme()` once (a Window theme does not reach Controls under a CanvasLayer). Only implemented systems are shown — no minimap, clock, quests or currency. The Ninja Adventure pixel font was evaluated and rejected for body text (broken glyphs at 8–11 px).

**Goal/dependencies:** requires 17–18 and 20. Bring gold/dark/cyan styling into implemented panels at 640×360, bind the assistant model, and improve material-bag readability.

**Files/systems:** `scripts/ui/`, dedicated UI scenes/themes, HUD nodes and `assets/game/ui/`. Bind to 13/17 APIs. Show portrait, HP/Magicules, hotbar/cooldowns, live camp/assistant messages and current material inventory; add other panels only if backed by real systems.

**Authority/save:** local-player binding and UI focus remain local; all action buttons use validated host intents. Online menus never pause other players. Pure layout/selection has no save requirement; chosen loadout is already host-owned under 13.

**Done evidence:** actual values match host snapshots; keyboard/mouse focus, contrast, tooltips and modal exclusivity work; no overlap at ×2/×3. Visual multiplayer test shows each guest's own inventory/skills. Reference sample levels, gear, currency, minimap and quests are not fabricated into gameplay.

## 22 — Title and pause flow (Claude) — **Done**

**Status 2026-10-14:** integrated on `claude/roadmap-22-title-pause`. Continue = most recently played valid world from `WorldRegistry.list` (damaged saves skipped; Load Game still lists them as damaged). Settings are local (`user://settings.cfg`: fullscreen, 1x/2x/3x window) and applied at the title. Pause keeps the 16c semantics (solo freezes, with guests only this character stops) and adds shortcuts that return to the pause menu. `GameSession` unchanged. Ornamented frames (`OrnateBox`, Kenney CC0 borders) replaced the plain panel boxes at the user's request.

**Goal/dependencies:** requires 21. Implement New offline sandbox, Continue/Host saved world, Join and a usable pause overlay using stored references.

**Files/systems:** dedicated title/pause scenes and scripts, application entry flow, session lifecycle adapters and UI assets. Keep domain save/network logic in `GameSession`; shared-file handoff required if it needs modification.

**Authority/save:** offline pause freezes simulation; hosted pause blocks only that character. Host quit saves the world before shutdown; guest quit disconnects without writing host saves. Continue loads only a real valid world with existing backup/corruption handling. No invented multi-slot Load Game until implemented. Local audio/display preferences may use separate local configuration, never world progression.

**Done evidence:** visible New/Continue/Join/Resume/Quit loop, keyboard focus, corrupt-save handling, reconnect identity retained, host versus guest exit behavior verified, and no hidden menu grants free HP/resources.

## 23 — Audio and combat/analysis VFX (Claude) — **Done**

**Status 2026-10-14:** integrated on `claude/roadmap-23-audio-vfx`. No network change: `presentation.gd` derives cues from state it already observes on each peer (HP, `attack_recovery`, level, skills, chests, form, ally race, camp state, pickups near characters), with a baseline on first sight. Music/SFX/UI buses; settings local in `user://settings.cfg`.

**Goal/dependencies:** requires 16, 19 and 21. Add a small coherent set of strikes, pickups, analysis, naming/evolution, shrine and UI cues with independent volume/mute controls.

**Files/systems:** `assets/game/audio/`, audio buses, effect scenes and presentation event adapters; coordinate any authoritative event hook with Codex before touching network components.

**Authority/save:** host decides outcomes; replicated event IDs prevent duplicate sounds/effects on retries/snapshots. Cosmetic particles/audio do not change hit timing/LOS or rewards. Preferences are local; gameplay effect timers still belong to host saves. Support headless/muted operation.

**Done evidence:** visible/listened playtest confirms clear cues, no repeated snapshot audio, no permanently stuck VFX after reconnect, readable reduced-effects/mute mode, no simulation regressions.

## 24 — Balance and M4 acceptance (Claude visible tests; Codex authority checks)

**User decisions (2026-10-14, Q&A before 24):** split into two halves — **24a systems**, **24b numbers + acceptance** (bot playtests only; real LAN test skipped for M4).
- *Pace/difficulty:* about 10–15 h to level 20; moderate solo difficulty. XP curve: fast start, long tail (Lv 2 after ~4 creatures, Lv 5 ~30 min, Lv 10 ~3 h, Lv 20 ~12 h); harder regions give more XP.
- *Death:* respawn after 5 s at the camp if founded, else the spawn, full HP/Magicules; lose 10% of the XP towards the next level (never a level); the bag (materials and unequipped gear) drops as a pile where you fell, equipped gear stays. Piles never expire; each death adds a pile; all are marked on the world map and a new round **minimap** (top right). Only the owner can pick a pile up for 5 minutes, then anyone.
- *Multiplayer fairness:* everyone with ≥10% of a creature's damage gets the full XP; one loot roll per creature, distributed by damage rank (currency split proportionally — Magicule drops until gold exists; items ranked by rarity go to the damage ranks in order); only characters with ≥10% damage may absorb. Creature HP +25% per extra player nearby (capped at 8). A **party system** comes later.
- *Creatures:* respawn by tier 45 s / 90 s / 180 s; **two hidden leveling spots per creature region** (2–3 creatures respawning 3× faster, unmarked until discovered); creature sprites at ~75% (Elites ~85%), collision unchanged; **creature levels** (naming cost = 35% + 2.5% per monster level, capped at 90%; the goblin ally is level 1).
- *Weapons/races:* bow fires a flying arrow (~320 px/s, host decides the hit on arrival). Basic strikes: Human 10 dmg free, Slime 12 dmg for 2 Magicules, Demon 14 dmg for 4; weapons keep their own damage for every race (no race multiplier).
- *Skills:* damage ∝ cost^0.75 relative to the basic strike plus utility effects of all four kinds (slow/root, knockback/stun, area/damage-over-time, self buffs/drain). Magicule regeneration unchanged unless evidence says otherwise.
- *Camp:* costs unchanged; region deposits refill (one full deposit every 15 min).
- *After M4:* M4.5c currency and merchants.

**24a status (2026-10-14, Claude): done** on `claude/roadmap-24a-systems` — all systems above except the numbers (race strikes, skill curve/effects, XP curve, region XP) which are 24b. Death applies in hosted worlds; the offline sandbox keeps R to retry.

**24b status (2026-10-14, Claude): done** on `claude/roadmap-24b-numbers` (from Codex's `codex/fix-balance-state-preservation` `82ef773`, accepted). Numbers:
- *Basic strikes:* Slime 12 dmg / 2 Magicules, Human 10 dmg free (recovers 25% faster), Demon 14 dmg / 4 Magicules; weapons keep their own damage for every race (the old Human +4 is gone).
- *Skills:* damage = 12 × (cost / 2)^0.75 (Thorn Lash 34, Acid Splash 40, Shadow Claw 40, Rending Bite 46, Power Slash 46, Engulf 57, Lunge 57, Piercing Fang 62, Dark Lance 62) plus one utility package each (`scripts/skills/skill_effects.gd`): slow (Thorn Lash, Dark Lance), root (Engulf), stun interrupting a bite wind-up (Power Slash, Piercing Fang), knockback (Power Slash, Lunge), area (Acid Splash), damage over time credited to the caster and ignoring hit immunity (Acid Splash, Rending Bite, Engulf, Piercing Fang), dash (Lunge), drain (Shadow Claw). The strongest active effect tints the creature on every peer (`status` in snapshots). Hotbar tooltips list the effects.
- *Creatures:* +30% HP and +8% bite per level above the tier's base level (clearing creatures unchanged; crater Elites 186–222 HP, bites 31–34).
- *XP:* defeat (10 + 2.5 × level) × tier factor 1 / 1.4 / 2 (clearing 13 / 21 / 40), absorption half of it, trial 1500; curve 100 × (level − 1)^2.8 (100, 696, 2167, 4850, … 380,636 at level 20).
- *Schema v22:* characters keep level and points and their progress within the level is carried over proportionally onto the new curve; saved creatures get their level-scaled HP.
- *Magicule regeneration* unchanged (6/s after 1.5 s): with a 25% reserve every race still wins its fights in the probe, so nothing called for a change.

**Evidence (bot playtests, user decision):** `tests/balance_probe.gd` fights every placed creature (tier × level) with every race using the game's own combat code, with basic strikes only and with the band's skill, and projects XP per hour from the measured fights, travel/absorb time and respawn caps. Results in `docs/balance/report.md`: every race beats every creature of its band one on one with its skill; Easy creatures fall within 5 s; crater Elites cost a Slime about two thirds of its HP and kill strike-only characters (moderate); level 2 after 5 Easy creatures, level 5 after ~19 min, level 10 ~2.1 h, level 20 ~11.4 h (races within 3% of each other). Measured first try at the planned numbers was 1.4 h to level 20 with one-shot skills, which is why creature HP growth (12% → 30%) and the curve were tuned.

**M4 acceptance record (2026-10-14, Claude; Codex's isolated edge fixes `73c8884` verified on Windows and adopted — M4 accepted):** M4's systems slice — races, skill tree, fusion, gear and weapons, camp, allies, trials, world map and regions, audio/VFX, death and multiplayer fairness, balance — is complete and covered by the automated suites (local + five real host/client network suites) and the visible bot playtest on Windows. By user decision the real LAN test is skipped for M4 and evidence comes from bot playtests; WAN/encryption stay out of scope. Open items carried forward: real-machine LAN session, human-feel tuning after friends play (dodging the wind-up makes fights easier than the standing bot measures; gear and tree upgrades make kills faster), M4.5c currency and merchants next, then ferries/ships and the party system.

**Goal/dependencies:** requires 14–17 and 19–23. Playtest the approved skill/form/settlement loop, tune bounded values from recorded evidence and decide whether M4 is ready for nation-scale work.

**Files/systems:** gameplay definitions/configs and targeted fixes on separate reviewed branches, `docs/playtest/`, tests, roadmap and handoff. Assign each tuning/fix file before concurrent edits; no broad refactor bundled with balance.

**Authority/save:** keep ownership, single resource transactions and compatible saves across balance changes. Define how existing upgraded stats/timers migrate rather than silently resetting characters. Include guest disconnect/reconnect, exhausted/dead actors and old-save restore.

**Done evidence:** user-visible full slice and eight-total-player checks, meaningful cost/recovery/cooldown measurements, Extra/Unique unlock evidence, race/form/skill-tree/fusion/equipment UI usability, host save/reload, no duplicate rewards/audio. Validate real LAN with the user's machines; WAN/encryption remain separately scoped. Record unresolved issues and user feedback before marking M4 Done.

## Parallel work and approval

The original steps were approved on 2026-10-12. The user's 2026-10-13 direction below supersedes the original assistant scope and ownership proposal: systems first (17, 17b–17g), then asset preparation/presentation (18+). Claude continues in order with 17 unless reassigned; Codex reviews released work. No unclaimed future file ownership is implied. Completed steps and their review history remain intact.

Claim file ownership in `docs/AI_HANDOFF.md` and push the claim before implementation. Exchange exact branch/commit acknowledgments and preserve the selected baseline before dependent work. Both tools check new remote commits before critical changes and periodically during long active tasks. Plan approval does not merge branches automatically.

## User direction change (2026-10-13): races, skill tree, fusion window, gear

The user scrapped the Great Sage / analysis assistant concept. **Step 17 is cancelled** and its slot becomes the first of the new systems below. User decisions: everyone can absorb but the Slime absorbs best, and mimic forms stay Slime-only; fusing consumes both original skills, and a fused skill can always be split back into the two originals; gear comes from creature drops, camp crafting, chests/points of interest and merchants (merchants need currency and arrive with M5 trade); systems come before the art steps, so 19 can draw every race and weapon type at once. Exact numbers below are starting proposals for tuning in 24, not final balance.

### 17 — Experience and levels (replaces the analysis assistant) — **Done**

**Status 2026-10-13:** implemented on `claude/roadmap-17-xp-levels`. Curve: total XP for level L = 25·L·(L−1) (50, 150, 300, 500 …), cap 20. Awards (host only): defeating blow by tier 10/20/40, completed absorption 5/10/20, completed trial 60 (owner only); trial creatures, sourceless defeats, failed trials and clients award nothing. One skill point per level, stored unspent in `progression.skill_points`. HUD title bar: `Lv N · XP x / next · k skill points`.
Per-character `level` and `experience` (already reserved in `progression`) become real: XP from defeats (by creature tier), completed absorptions and trials, awarded only on the host and only to the character who earned it (trial creatures and contested corpses follow existing credit rules). A level curve, a level cap for M4, and one **skill point** per level (stored as unspent points for 17c). HUD level/XP readout and a System Voice line on level-up. Saved, validated (level/XP consistent with the curve, points never above levels earned), migrated (existing characters start at level 1 with XP 0) and replicated in snapshots.

### 17b — Playable races: Human, Demon, Slime — **Done**

**Status 2026-10-13:** implemented on `claude/roadmap-17b-races` with the proposed numbers below. Non-Slimes absorb at 1.5× channel time with half absorbed vitality; Human +4 basic-strike damage and ×0.75 recovery on all attacks; Demon ×1.25 skill damage and 20% of skill damage dealt returned as instant HP (capped, skills only). Race is chosen at creation only; no respec yet. No schema bump: `progression.race` already existed and every stored character is a Slime.
Race chosen at character creation: the host when creating a world, a friend on first join (a small picker before the character is created; reconnecting characters keep their race). Starting proposal: **Slime** (HP 100, Magicules 100; fastest absorption, full analysis evidence, mimic forms), **Human** (HP 120, Magicules 70; +weapon damage, faster attack recovery; absorbs slower), **Demon** (HP 90, Magicules 130; +skill damage, small life drain on skill hits; absorbs slower). Race is per character, saved/validated, host-authoritative and visible to other players (placeholder silhouettes until 19). Existing characters migrate as Slimes. Allies and naming keep working for every race.

### 17c — Skill tree — **Done**

**Status 2026-10-13:** implemented on `claude/roadmap-17c-skill-tree`. Every level including level 1 gives a point (changed from 17: one more point per character, added by the v15 migration). Per race three rows: two stat nodes (+10/+15 HP or Magicules, +0.5 Magicules/s, +5 speed, +1/+2 strike) and in rows 1–2 a skill node needing both; row 2 needs row 1's skill, row 3 needs row 2's. Each node and each activation costs 1 point; there is no respec yet. Balance finding: the slice cannot yet supply enough XP (three creatures, no respawns).
One tree per race. Nodes cost skill points from 17: **stat nodes** (HP, Magicules, regeneration, power, speed) and, every few nodes, a **skill node** that grants a new skill. Skills gained by leveling or absorbing appear in the tree but stay **locked until activated** with points; only active skills can go on the hotbar or into the fusion window. Host validates every purchase (prerequisite nodes, enough points, node belongs to the character's race); forged or out-of-order saves are rejected. Existing learned skills migrate as already active so no one loses progress.

### 17d — Skill fusion window (replaces the assistant UI) — **Done**

**Status 2026-10-13:** implemented on `claude/roadmap-17d-fusion`. Only active skills can be dragged; a fused skill is active when both parts were activated (activations are recorded on the base skills, so fusing/splitting never changes points). The fused skill takes the first part's hotbar slot. Splitting is always allowed; a Unique learned while holding the fused skill stays valid after a split (prerequisites are checked against the fusion closure). v15→v16: holders of Piercing Fang keep it fused; its parts leave the held list and their slots; a paid activation of Piercing Fang itself is refunded.
A window with the character's active skills listed on the right; drag two skills into the fusion area and onto each other. If a recipe exists, both originals are **replaced** by the fused skill; otherwise nothing happens and the window says they do not fuse. A fused skill can always be **split** back into its two originals. Recipes are data in the skill catalogue; the existing automatic Extra unlock (Rending Bite + Thorn Lash after a Thornback analysis → Piercing Fang) becomes the first fusion recipe, keeping its analysis requirement. Host-authoritative intent, saved, migrated (characters who already own Piercing Fang keep it as a fused skill with its originals recoverable by splitting), and the hotbar updates when slotted skills are fused or split.

### 17d2 — Creature respawning (user decision, 2026-10-13) — **Done**

Inserted after 17d at the user's request to fix the finite-XP finding. Defeated creatures (not trial creatures) are scheduled on defeat and return after 60 s at their home with the same ID, kind and difficulty; an unabsorbed corpse is removed at that moment (not while being absorbed); nobody gets a creature spawned on top of them (160 px clearance, 5 s retry). Rewards (XP, drops, absorption evidence/materials) repeat. Saved as top-level `respawns` (v17).

### 17e — Gear foundation: armor and accessories — **Done**

**Status 2026-10-13:** implemented on `claude/roadmap-17e-gear`. Eight bases (cloth hood, iron helm, padded vest, scale mail, leather gloves, travel boots, copper ring, spirit amulet); rarity scale 1.0/1.25/1.5/1.8/2.2 on positive ranges; passives 0/0/1/1/2; one active on Epic/Legendary (Barrier 30 s, Mana Surge 45 s), G uses the first ready one in slot order. Max HP/Magicules and regeneration are adjusted on equip/unequip (saved values include gear); speed, strike and defense are derived live. No sources yet — 17g.
Equipment slots (proposal: head, body, hands, feet, two accessories, weapon). Items are instances with stable IDs, a base type, a **rarity** (Common, Uncommon, Rare, Epic, Legendary), stat rolls within the base type's range, **passives** from Rare and an **active** on Epic/Legendary, and a distinct look per base type/rarity. Equip/unequip per character from the bag; stats apply on the host; the existing inventory reference (paper doll, bag, item details) is the layout guide. Saved, validated (stats within ranges, passives/actives allowed for the rarity, no duplicated instance IDs) and replicated.

### 17f — Weapons: sword, spear, scythe, bow — **Done**

**Status 2026-10-13:** implemented on `claude/roadmap-17f-weapons`. Bases: Iron Sword 12–15, Ash Spear 13–17, Field Scythe 15–20, Hunting Bow 9–12 (Common; rarity scales). Shapes: sword circle r20 20 px ahead (front cone), spear 52×10 line, scythe circle r30 10 px ahead (dot ≥ −0.3, includes the sides), bow ray 200 px against terrain and creatures. Magicule cost stays 8 per basic attack. The bow is instant (hit-scan) with a visible shot line rather than a travelling projectile.
Each weapon type changes the basic attack: **sword** balanced arc, **spear** long narrow thrust, **scythe** wide slow sweep, **bow** projectile with range and line of sight. Rarity scales damage and can add passives/actives like other gear. Host resolves all hits; replicas show them. Races interact with weapons through their racial bonuses (17b).

### 17g — Gear sources: drops, chests, camp crafting — **Done**

**Status 2026-10-13:** implemented on `claude/roadmap-17g-gear-sources`. Drop chance 10/20/45% by tier with rarity weights per tier (Easy ≤ Rare, Standard ≤ Epic, Elite up to Legendary); loot is a world entity, picked up by walking over it (line of sight, bag room). Chests: three per world (`chest_1..3`, reference positions or seeded), opened once per character with F; Uncommon+. Trial: Rare 70% / Epic 30%. Forge (`forge_1`, 4 stone + 3 essence, requires the hut) crafts from bag materials, Common–Rare. Merchants arrive with currency (M4.5).
Creature drops by tier (elite creatures drop higher rarities), seeded chests at points of interest and trial rewards (uses the 16d layout; chests are saved once opened), and a camp forge recipe that crafts gear from deposits and absorbed materials. Merchants and currency are added with M5 trade.

### Effects on later steps
19 draws all three races, the weapon types and gear looks. 21 becomes the reference-style presentation of the skill tree, fusion window, paper doll/equipment and bag (the "assistant" panel is dropped). 24 balances races, levels, tree, fusion and gear together.

## Requested after 17e (user, 2026-10-13): world and item expansion — planned as M4.5 after 17g

- **Reference use:** the Farever database (items) and Siagarta map (world) on metaforge.app are inspiration. Allowed: category lists, slot/socket/rarity structure, stat-range shapes and progression curves as balance benchmarks, the overall world theme. Not allowed: copying or lightly renaming item names, descriptions, icons/art, or the exact map layout. User agreed ("don't 1:1 copy name, stat and image").
- **Proposed steps (to confirm):** W1 region map and region travel (bridges, coastlines, the clearing as the start region; seeds keep working per region); W2 currency and merchants (pulls the M5 merchant work forward); W3 quests with ferry vouchers as rewards; W4 ferry NPCs on each coastline (pay currency or a voucher; host-authoritative transfer of the whole character with save/rejoin safety); W5 own ship (buy from a shipwright or craft at a camp dock from materials; sailing movement, docking, ship saved per character); W6+ item categories: tools (gathering yields), consumables, mounts (speed, summon/dismount), runes and augments (sockets on gear; slot/rarity rules like 17e).
- **Network/save notes:** every region change and ship state is host-authoritative and saved with versioned migrations; friends in different regions of the same hosted world need region-scoped snapshots — a real architectural step to plan before W1.

## Added after approval (user decisions, 2026-10-13)

### 16b — Healing on absorb (Claude) — **Done**

After the step-16 playtest showed the trial was too hard without any HP recovery, the user chose healing that scales with the absorbed creature: Easy 15, Standard 25, Elite 40 HP restored gradually over 10 s (`Health.start_regen`, `TIER_STATS.absorb_heal`). A new heal replaces the running one only if it restores more; healing is capped at max HP, ends on defeat, runs only on the host and is saved (`health.regen_rate/regen_left`, schema v11). Trial creatures cannot be absorbed, so trials still cannot be farmed for healing.

### 16c — Worlds, save slots and menus (user step A, Claude) — **Done**

**Status 2026-10-13:** implemented on `claude/roadmap-16c-worlds-menus` as described below. Title menu is the main scene; F8 panel removed; pause menu on Esc; schema v12 world meta (`name`, `seed`, `created`, `last_played`; optional in validation for hand-built test documents, always written by hosted worlds).

A working, unstyled title flow before the art steps (final presentation remains step 22): New World (name + optional seed), Load World (list of save slots with name, seed and last-played time), Join (address), Quit. Every world is always saved; playing alone means running as a local host with nobody connected, so the pause menu's **Open to friends** simply starts accepting joins without a restart. The pause menu also offers Resume and Save & Quit. Replaces the F8 host/join panel. Must keep host authority, private reconnect identities, autosave/backup behavior, 8-player cap and existing save migration; per-world save files under `user://worlds/`.

### 16d — Seeded worlds (user step B) — **Done**

**Status 2026-10-13:** implemented on `claude/roadmap-16d-seeded-worlds`. `WorldLayout.generate(seed)`: seed 0 = the reference map; otherwise one `RandomNumberGenerator` in a fixed order places the trial stone (4 candidate spots) and ally start (4 spots), camp deposits 40–80 px around the camp clear of building sites (amount 8), creatures by distance band from the spawn and away from camp/stone (difficulty weights: first Gnasher Easy/Standard, second Easy/Standard/Elite, Thornback Standard/Elite), outlying deposits ≥ 220 px out with 8–12 each, then 2–3 rocks and 6–10 trees off roads, camp, spawn and every point of interest with ≥ 64 px spacing. Whole-pixel positions. Worlds from before 16d keep the reference map via `meta.seeded = false` (v13).

Each world stores a seed. The map layout, spawn and camp site stay fixed; the seed deterministically places resource deposits (positions/amounts), creatures (placement and difficulty), points of interest (trial stone, ally start, from designed candidate spots) and decorations (trees/rocks) while keeping every route, deposit and point of interest reachable. The same seed always produces the same world; the seed is saved, validated and shown in the menu. Static IDs stay stable so saves, ownership and conservation rules keep working. The extra "something else" tick was accidental (user, 2026-10-13); the seed covers exactly these four groups.

## Updated naming and mimic rules (user decisions, 2026-10-13)

These supersede earlier Slime-only mimicry and flat naming-cost wording: naming costs 80% of the character’s maximum Magicules (rounded to whole Magicules). Mimicry unlocks at Slime level 1, Demon level 5 and Human level 20, while analysis evidence, payment, cooldown and terrain rules still apply. The gear-sources implementation remains in progress separately.

### Codex 24b review qualification (2026-10-14)

`codex/fix-balance-review-edges` fixes group-HP/credit migration, single-DoT caster attribution and disconnected-source errors. It corrects absorption duration in the regenerated probe: the projected mean is about 11.7 h to level 20. The original 11.4 h report above is historical evidence from Claude's initial model. Isolated fights reset health/resources; travel is assumed, so this is a pacing estimate. Adopt/acknowledge the correction before closing acceptance or beginning dependent currency work. Transient effect timers interrupt on reload; disconnected qualifying characters currently lack deferred XP awards. LAN and human-feel validation remain outside the bot evidence.
