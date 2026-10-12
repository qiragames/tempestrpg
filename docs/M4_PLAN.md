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

## 13 — Skill catalogue and unlock ledger (Codex)

**Goal/dependencies:** after M4 approval, define stable tier/skill/unlock IDs and a per-character progression ledger while keeping Rending Bite behavior intact. This is the contract for later skills and assistant queries.

**Files/systems:** `data/skills/`, `scripts/skills/`, narrowly scoped skill intents in `scripts/network/game_session.gd`, `scripts/persistence/{state_codec,save_store}.gd`, skill/persistence tests. Publish the effect-dispatch/read-only-query contract before presentation work binds to it.

**Authority/save:** host owns acquisition, unlock evidence, slot assignment and activation; clients send owned intent/definition IDs. Save unlocked IDs, loadout and genuine personal evidence with a versioned migration from v6; never serialize executable paths supplied by clients. Validate all four tier labels and missing/invalid prerequisites.

**Done evidence:** old saves preserve skills/resources/loadout; forged/premature unlocks fail; duplicate/reconnect acquisition is idempotent; eight-character ownership stays separate. Existing combat/absorption/network suites pass. Locked Ultimate remains unavailable.

## 14 — Second specimen and one Extra upgrade (Codex)

**Goal/dependencies:** requires 13. Add one modest variant encounter with a distinct specimen and second Common skill. Suggested low-scope upgrade: existing Rending Bite plus a second analyzed trait unlocks an Extra piercing strike; final names/numbers remain proposals.

**Files/systems:** a new specimen/skill definition and modular encounter scene, `scripts/enemies/`, skill effect dispatcher, absorption definition lookup and world encounter wiring; codecs/validation only for the newly added persistent entities/effects.

**Authority/save:** host validates combat, drops, corpse reservation, analysis and exact unlock combination. Persist stable encounter/specimen IDs, knowledge and consumed-world state; single awards under simultaneous absorption. Temporary strike/cooldown state follows the existing recovery contract.

**Done evidence:** both Common skills and the Extra can actually be earned/used; unsupported combinations fail; two players cannot claim the same corpse twice; save/reload preserves claims and unlocks. Use placeholders until 19.

## 15 — First mimic form (Codex)

**Goal/dependencies:** requires 13–14. Unlock one analyzed creature form, allow transform/revert with an explicit Magicule cost, and give it one bounded movement/attack difference.

**Files/systems:** `scripts/forms/`, player movement/ability dispatch, explicit form intent, form definitions, character codec/schema and tests. Retain player identity and camera; expose visual form ID for 19.

**Authority/save:** host checks genuine specimen knowledge, alive/awake state, cost and safe collision placement. Persist selected/unlocked form IDs and any gameplay timers/modifiers. Transformation never refills HP/Magicules, clears naming exhaustion or alters inventory/character ownership. Reversion must work if a shape would overlap terrain; choose safe placement rules before coding.

**Done evidence:** form changes are replicated to two clients, old characters migrate to Slime, resources/cooldowns survive switching and reconnect, blocked transformations fail without charging, and death/respawn retain an explicit safe-form policy.

## 16 — Personal trial, one Unique and future Ultimate gate (Codex)

**Goal/dependencies:** requires 13–15. Add one small trial using the existing map/encounter foundations, unlock one Unique synthesis from its personal completion and the required Extra. Suggested Unique: Predator Focus, a costed modifier to the next analysis, with limits defined before implementation. Ultimate remains locked behind future ascension.

**Files/systems:** bounded encounter/trial definitions, `scripts/skills/`, analysis effect contract and personal progression; narrowly scoped world/authority/save extensions and tests. This is one trial and one Unique, not a quest system or a full boss campaign.

**Authority/save:** host records completion once for qualifying participants under explicit attribution rules; spectators/reconnecting guests do not inherit it. Save personal trial and mastery IDs plus timed/one-use effect state; bound analysis modifier and consumption rules so interrupt/reload cannot duplicate a benefit.

**Done evidence:** trial can be completed legitimately; unauthorized/duplicate rewards and cross-character unlocks fail; interrupted analysis obeys the chosen paid-benefit rules; Unique works once per activation; Ultimate is visibly and mechanically locked until real ascension exists.

## 17 — Analysis assistant model (Codex)

**Goal/dependencies:** requires 13–14. Expose factual specimen traits, known skills, unlock requirements, current form and resource/recovery advice through a read-only analysis model. It supplies the Great Sage-inspired panel in 21.

**Files/systems:** `scripts/analysis/`, specimen/skill read APIs and tests; keep `scripts/ui/game_hud.gd` and render/layout files free for Claude. This is deterministic game analysis, not an external AI service.

**Authority/save:** derive suggestions from authoritative character/world state; validate any later requested action through existing host intents. Never grant rewards through the panel. Save only genuinely earned discoveries if added; explanatory text and UI selection are local and need no world persistence.

**Done evidence:** the model distinguishes unknown/known traits, locked tiers, interrupted analysis and exhausted state; each client sees its own discoveries; advice matches actual costs/timers and never invents gear/quests/stats.

## 18 — Prepare sprite, tileset and UI assets (Claude; parallel lane)

**Goal/dependencies:** M4 approval; can run alongside 13–17. Prepare a small usable export set from the seven preserved references at 640×360 without touching gameplay files.

**Files/systems:** `assets/references/index.json` for provenance additions, `assets/source/`, `assets/game/{sprites,world,ui}/`, preparation notes. Preserve original JPEG/PNG/WebP bytes. Record atlas cells, animation ordering/timing, pivots, transparency and intended use.

**Authority/save:** visual-only resources, no progression/save mutations. Assets use stable named paths; rendered labels/stats remain dynamic. The chart has no explicitly labeled Forest Gnasher row: agree a suitable stand-in or prepare a matching sprite rather than silently changing its creature identity. JPEG/chart labels/backgrounds require cleanup; approve poor-quality slices before integration.

**Done evidence:** inspect slime, goblin/Hobgoblin and Gnasher/form candidates, one small forest atlas/props set and reusable frame/icon pieces; nearest-filter export preview at ×2 and ×3; originals/index checksums retained. Actual scene integration is 19–22.

## 19 — Character/enemy sprites and mimic presentation (Claude)

**Goal/dependencies:** requires 15–16 and 18 so gameplay/form contracts are stable. Bind prepared art to idle/walk/attack/death, evolution and transform states.

**Files/systems:** character/ally/enemy render child scenes/scripts and prepared sprite resources. Coordinate renderer adapters separately from Codex's state components; do not rewrite attack/health/form authority while replacing drawings.

**Authority/save:** consume replicated actor/race/form/action state. Local animations are presentation only; they cannot inflict damage, spend resources or finish analysis. Persist semantic IDs, not frame numbers or animation node paths.

**Done evidence:** visible captures of all relevant states at ×2/×3, consistent feet/pivots/z-order, readable attack telegraph; headless tests confirm costs/attack timing unchanged and clients see the same forms/evolution.

## 20 — Forest and village tiles/props (Claude)

**Goal/dependencies:** requires 18–19. Replace the initial clearing visuals with a small tile/prop slice while preserving encounter/camp/deposit IDs and routes.

**Files/systems:** `assets/game/world/`, TileSet/TileMapLayer resources, `scenes/world/forest.tscn`, world drawing/collision presentation, structure render resources. Keep walkable routes and doors; canopy art must not block paths.

**Authority/save:** collisions used by the host and replicas must agree. Save world IDs and dynamic built/depleted flags as today; static tile art needs no per-character state. Explicit migration required if gameplay locations or saved world geometry become incompatible.

**Done evidence:** replay the full slice around terrain/buildings; all deposits reachable, no trapped spawn or misaligned hut footprints; visual depth/occlusion checks and authoritative collision/LOS/network regressions pass.

## 21 — Reference-style HUD, assistant and storage UI (Claude)

**Goal/dependencies:** requires 17–18 and 20. Bring gold/dark/cyan styling into implemented panels at 640×360, bind the assistant model, and improve material-bag readability.

**Files/systems:** `scripts/ui/`, dedicated UI scenes/themes, HUD nodes and `assets/game/ui/`. Bind to 13/17 APIs. Show portrait, HP/Magicules, hotbar/cooldowns, live camp/assistant messages and current material inventory; add other panels only if backed by real systems.

**Authority/save:** local-player binding and UI focus remain local; all action buttons use validated host intents. Online menus never pause other players. Pure layout/selection has no save requirement; chosen loadout is already host-owned under 13.

**Done evidence:** actual values match host snapshots; keyboard/mouse focus, contrast, tooltips and modal exclusivity work; no overlap at ×2/×3. Visual multiplayer test shows each guest's own inventory/skills. Reference sample levels, gear, currency, minimap and quests are not fabricated into gameplay.

## 22 — Title and pause flow (Claude)

**Goal/dependencies:** requires 21. Implement New offline sandbox, Continue/Host saved world, Join and a usable pause overlay using stored references.

**Files/systems:** dedicated title/pause scenes and scripts, application entry flow, session lifecycle adapters and UI assets. Keep domain save/network logic in `GameSession`; shared-file handoff required if it needs modification.

**Authority/save:** offline pause freezes simulation; hosted pause blocks only that character. Host quit saves the world before shutdown; guest quit disconnects without writing host saves. Continue loads only a real valid world with existing backup/corruption handling. No invented multi-slot Load Game until implemented. Local audio/display preferences may use separate local configuration, never world progression.

**Done evidence:** visible New/Continue/Join/Resume/Quit loop, keyboard focus, corrupt-save handling, reconnect identity retained, host versus guest exit behavior verified, and no hidden menu grants free HP/resources.

## 23 — Audio and combat/analysis VFX (Claude)

**Goal/dependencies:** requires 16, 19 and 21. Add a small coherent set of strikes, pickups, analysis, naming/evolution, shrine and UI cues with independent volume/mute controls.

**Files/systems:** `assets/game/audio/`, audio buses, effect scenes and presentation event adapters; coordinate any authoritative event hook with Codex before touching network components.

**Authority/save:** host decides outcomes; replicated event IDs prevent duplicate sounds/effects on retries/snapshots. Cosmetic particles/audio do not change hit timing/LOS or rewards. Preferences are local; gameplay effect timers still belong to host saves. Support headless/muted operation.

**Done evidence:** visible/listened playtest confirms clear cues, no repeated snapshot audio, no permanently stuck VFX after reconnect, readable reduced-effects/mute mode, no simulation regressions.

## 24 — Balance and M4 acceptance (Claude visible tests; Codex authority checks)

**Goal/dependencies:** requires 14–17 and 19–23. Playtest the approved skill/form/settlement loop, tune bounded values from recorded evidence and decide whether M4 is ready for nation-scale work.

**Files/systems:** gameplay definitions/configs and targeted fixes on separate reviewed branches, `docs/playtest/`, tests, roadmap and handoff. Assign each tuning/fix file before concurrent edits; no broad refactor bundled with balance.

**Authority/save:** keep ownership, single resource transactions and compatible saves across balance changes. Define how existing upgraded stats/timers migrate rather than silently resetting characters. Include guest disconnect/reconnect, exhausted/dead actors and old-save restore.

**Done evidence:** user-visible full slice and eight-total-player checks, meaningful cost/recovery/cooldown measurements, Extra/Unique unlock evidence, form/assistant/UI usability, host save/reload, no duplicate rewards/audio. Validate real LAN with the user's machines; WAN/encryption remain separately scoped. Record unresolved issues and user feedback before marking M4 Done.

## Parallel work and approval

The user approved this plan on 2026-10-12. The approval node is Done; 13 (Codex) and 18 (Claude) are Next and can start in parallel after each tool pushes its ownership claim. All other steps wait for their stated dependencies. Update the plan if priorities/rules change. Plan approval does not merge branches automatically.

Claim file ownership in `docs/AI_HANDOFF.md` and push the claim before work. During 13–17, Claude owns only asset preparation (18); Codex owns skill/form/analysis/authority/save files. Integration 19 waits for stable form/trial contracts. Assistant-model work (17) can proceed beside sprite/map presentation provided no world/HUD adapters overlap. Claude owns shared UI/world presentation for 20–22; Codex reviews/verifies released steps rather than editing the same files. Exchange exact branch/commit acknowledgments and use the user-selected integrated baseline before dependent work. Both tools recheck new remote commits at critical steps and approximately every ten minutes during long active tasks.
