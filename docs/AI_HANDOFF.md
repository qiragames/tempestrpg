# Shared handoff for Codex and Claude Code

## Start each session

1. Read `AGENTS.md`, `ROADMAP.md`, this file and relevant architecture/reference documents. Current user instructions take precedence.
2. Run `git status --short`, `git branch --show-current`, and inspect recent commits. Fetch origin when network access is available. Check whether another session has uncommitted work before editing the same files.
3. Before each critical architecture/network/save/dependency/integration step and before committing, recheck GitHub branch heads with `git ls-remote --heads origin`, recent commits, local changes and this handoff. Fetch relevant new/changed branches explicitly: the default fetch can be restricted to one branch. Claude checks Codex work; Codex checks Claude work. Compare overlapping changes and coordinate before proceeding; unpushed changes in another checkout are not visible here.
4. Continue from the latest completed feature branch: later branches carry earlier work forward. `main` may lag behind. Do not reset to main or merge without the user's instruction.
5. State the task being taken and files likely to change in the current session. If another tool is working concurrently, coordinate ownership with the user or through an explicitly shared task record before overlapping edits. Markdown files are context, not an automatic lock or live communication channel.
6. Complete one roadmap step, run meaningful checks, update roadmap/handoff, regenerate the graph, commit and push a separate descriptive branch. Preserve others' uncommitted work. Record failures honestly.

## User decisions

Godot 4.6.3 with GDScript; top-down pixel-art RPG. Explore → fight → absorb/analyze → acquire skills → name/evolve allies → grow a settlement/nation. Host runs the authoritative game on their own machine. Eight players total, including host. Persist implemented per-character and shared world state, extending schemas with each feature. Never fabricate mechanics represented only in UI reference images.

User wants visible test windows. This cloud has no display/live desktop sharing: checks are headless. Provide a tracked-source ZIP for local Godot playtesting; show the actual game window when a supported display is available. Do not imply a headless test is visible.

The user supplied a creature sprite chart, HUD, title, pause, inventory and forest/village tileset references in chat. These are documented inspirations; clean source images are not currently imported. Existing art is procedural placeholder graphics. Gear, quests, title/pause presentation and settlement gameplay are still future work.

## Last completed gameplay step

Branch: `codex/roadmap-09-first-camp` (includes steps 01–08). First ally recruited after defeating the western clearing Gnasher, then named via F dialogue. Naming costs 80 Magicules once and evolves Goblin → Hobgoblin (HP 30→60, power 4→8, follow speed 45→65, changed silhouette). Below 25% reserves, namer rests at least 8 seconds and until Magicules return to 25%. Other characters continue playing. Ally follows its stable owner; combat/gathering roles are not yet implemented.

Schema v3 saves/replicates ownership, name, race, stats, position, resource costs and exhaustion timer. Legacy v0/v1/v2 saves migrate. Disconnect pauses character simulation; reconnect/reload preserves paid costs and recovery. Respawn retains exhaustion while restoring health, avoiding a dead/sleeping lock.

First camp implemented: B menu, site (350,350), free founding with owned evolved ally within 80 pixels, living/awake actor within 55 pixels. Shared finite wood_1/wood_2 (8 each), stone_1 (8), gather range 36; hut_1 costs 12 wood/6 stone and has collision/safe footprint checks. Top-level schema-v4 camp state is separate from reserved progression.settlements; migration preserves prior worlds. Host-only transactions prevent concurrent duplication, clients receive collision/state, saves retain depletion and construction.

Next goal: M3 ally work assignments for gathering/construction, then exploration/production and additional structures. First camp currently has manual gathering and one fixed hut recipe; no automatic workers, economy tick, housing bonuses or free placement yet. Extend authority, IDs, conservation and migrations with the next feature.

## Architecture and constraints

- `GameSession` autoload (`scripts/network/game_session.gd`) owns ENet sessions, peer→stable-character binding, validated intents, snapshots and saves. Host + seven guests, UDP 24560 default, no peer relay.
- `scripts/network/authority.gd` rejects mutations on client replicas. Components use runtime `/root/GameSession` lookup; compile-time autoload references in preloaded scripts break custom SceneTree test loading.
- World resolves stable entity/character IDs. Player-owned health, Magicules, inventory, skill book, analysis and exhaustion must stay bound to an explicit actor. Never trust client costs, positions, HP, ownership or rewards.
- `scripts/persistence/state_codec.gd` captures/applies plain state; `save_store.gd` validates/migrates and atomically writes with a valid backup. Extend capture, restore, validation, migration and snapshots together. Saves and private resume profiles never enter Git, logs or ZIPs.
- Replicas do not simulate gameplay/resource ticks. Host menus block only that player's input; offline menus pause. Snapshots omit credential hashes. Networking currently tested on loopback; WAN, encryption, prediction and adverse-network playtests remain pending.
- Progression dictionaries reserve level/experience/equipment/quests/settlements but not all those mechanics exist. README and roadmap distinguish implemented behavior.

## Validation

Use Godot 4.6.3. Cloud: `source /workspace/.tempestrpg/env.sh` exports `GODOT_BIN` and writable XDG directories outside the repo. Local: set `GODOT_BIN` to the installed executable. From repo root:

```bash
"$GODOT_BIN" --headless --path . --editor --import
for suite in smoke combat magicules drops absorption skills_storage persistence allies naming settlement; do
  "$GODOT_BIN" --headless --path . --fixed-fps 60 --script "tests/$suite.gd" || exit 1
done
python3 tests/network_integration.py
python3 tests/network_settlement.py
"$GODOT_BIN" --headless --path . --quit-after 120
python3 tools/build_roadmap.py
```

Latest validation: 273 local checks (including 34 settlement) and 128 network checks (86 general + 42 camp) passed, plus main-scene startup.

Check logs for engine/script errors as well as exit status. Network tests start actual processes and use private temporary profiles; never print raw credentials. Test new meaningful behavior rather than duplicating implementation. Visual tests remain outstanding. Environment installation/start instructions are saved as a cloud configuration draft; publishing happens in environment settings.

## Finish and transfer

Update this file's completed branch/feature/next goal and actual test evidence; update `ROADMAP.md` and regenerate `ROADMAP.html`. Include any unresolved failures or migration requirements. Keep `CLAUDE.md` concise and point it here; use `AGENTS.md` for common rules so the tools do not get contradictory copies. Both tools must read this handoff, including Codex after Claude makes changes.
