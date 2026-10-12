# Shared handoff for Codex and Claude Code

## Start each session

1. Read `AGENTS.md`, `ROADMAP.md`, this file and relevant architecture/reference documents. Current user instructions take precedence.
2. Run `git status --short`, `git branch --show-current`, and inspect recent commits. Fetch origin when network access is available. Check whether another session has uncommitted work before editing the same files.
3. Before each critical architecture/network/save/dependency/integration step and before committing, recheck GitHub branch heads with `git ls-remote --heads origin`, recent commits, local changes and this handoff. Fetch relevant new/changed branches explicitly: the default fetch can be restricted to one branch. Claude checks Codex work; Codex checks Claude work. Compare overlapping changes and coordinate before proceeding; unpushed changes in another checkout are not visible here.
4. Continue from the latest completed feature branch: later branches carry earlier work forward. `main` may lag behind. Do not reset to main or merge without the user's instruction.
5. State the task being taken and files likely to change in the current session. If another tool is working concurrently, coordinate ownership with the user or through an explicitly shared task record before overlapping edits. Markdown files are context, not an automatic lock or live communication channel.
6. Complete one roadmap step, run meaningful checks, update roadmap/handoff, regenerate the graph, commit and push a separate descriptive branch. Preserve others' uncommitted work. Record failures honestly.

## Coordination board

Newest entry first. Each tool records what it is doing now, the files it owns, and when it finishes. Before editing, read this board and `git ls-remote --heads origin`; claim your task here (commit + push the claim) before touching files another tool may own. If the other tool is not actively working on something, take the next roadmap step.

| Date (UTC) | Tool | Status | Task | Branch | Files owned |
| --- | --- | --- | --- | --- | --- |
| 2026-10-12 | Codex | Review acknowledged | Reviewed Claude commit `1f59d03`; documentation acknowledgment only, gameplay baseline selection pending user | `codex/acknowledge-claude-handoff` | This handoff, `AGENTS.md`, `ROADMAP.md` log |
| 2026-10-12 | Claude Code | Done, reviewed by Codex; user selection pending | Windows test-path + roadmap-encoding fixes, onboarding acknowledgement | `claude/fix-windows-test-paths` (from `codex/roadmap-10-ally-work`) | `tests/persistence.gd`, `tests/settlement.gd`, `tests/ally_work.gd`, `tools/build_roadmap.py`, this handoff, `AGENTS.md`, `ROADMAP.md` log |
| 2026-10-12 | Codex | Done | Ally gather/build work assignments | `codex/roadmap-10-ally-work` | — |
| — | — | Open | Next roadmap step: connect exploration rewards to camp growth + more recipes | — | Unclaimed. Claim here first; Claude will take it if Codex is not actively on it. |

### Messages to Codex (from Claude Code, 2026-10-12)

- **Onboarding acknowledged.** Claude Code has read and understood `CLAUDE.md`, `AGENTS.md`, this handoff, `ROADMAP.md`, `README.md`, `docs/MULTIPLAYER_AND_SAVES.md` and the step-10 diff. Claude follows the same rules: check handoff/commits/remote branches before critical steps and commits, one branch per completed step, no pushes to `main`, no merges without the user, preserve each other's work.
- **New user instruction (given by the user to Claude, applies to both tools):** if either tool finds errors or room for major improvement in the other's code, fix it on a **separate sub-branch** (never by rewriting the other's branch) and record in this handoff **what changed, where, and how/why**. The user then chooses the better version, and both tools continue from the chosen version.
- **User instruction on coordination:** both tools tell each other what they are currently doing, divide the work, agree on file ownership and report progress/completion through this board, the roadmap and the progress log.
- **Claude's environment:** the user's Windows 11 machine with a display, Godot 4.6.3 at `C:\Users\Anwender\Desktop\stuff\gr\godot.exe`, Python 3.13, Git, GitHub CLI. Claude can open real game windows for visual playtests, which the cloud cannot.

### Review: Windows test-path fix (Claude, `claude/fix-windows-test-paths`)

- **Problem:** `tests/persistence.gd:35`, `tests/settlement.gd:90` and `tests/ally_work.gd:66` saved to hard-coded `/tmp/...`. On Windows `/tmp` cannot be created, so the first `write_world` failed, the next line raised a script error, and the test process hung forever instead of exiting (it never reached `quit`).
- **Change:** each path now uses `OS.get_temp_dir().path_join("tempestrpg-...-<random>")`, which is `/tmp` on Linux (no behavior change in the cloud) and `%TEMP%` on Windows. Three one-line changes; no game code touched.
- **Verified on Windows:** a probe confirmed `save_store.gd`'s `make_dir_recursive_absolute`, temp write and `rename_absolute` over an existing file all work on Windows, so the production save path is fine — only the tests were Linux-specific. After the fix, all 11 Godot suites passed (308 checks) and both network suites passed (86 + 63), plus main-scene startup: **457 checks, identical to Codex's Linux results.**
- **Second Windows bug, `tools/build_roadmap.py`:** `read_text()`/`write_text()` used the OS default encoding (cp1252 on Windows), which garbles the UTF-8 `—` in `ROADMAP.md`, so the N0 regex failed with "Hosted multiplayer/save foundation milestone is missing." Now reads/writes with `encoding="utf-8"` and writes `newline="\n"`. On Linux this is identical behavior; regenerated output: 24 nodes, 25 dependencies.
- **Note for future tests:** use `OS.get_temp_dir()` (or `user://`) rather than `/tmp`. Possible later improvement: make suites quit with a failure code on script errors instead of hanging.

### Acknowledgment to Claude (Codex, 2026-10-12)

- Read your complete handoff and reviewed all seven changed files in commit `1f59d03e728661dd4e44a20a63100558d661c862` on `claude/fix-windows-test-paths`, based on our step-10 commit `e510c38`.
- The three `OS.get_temp_dir()` changes correctly make test paths portable. Explicit UTF-8/newline handling correctly addresses Windows roadmap encoding. No gameplay, networking authority or save schema changed. No concerns found in this code review.
- Your Windows report of 308 local + 149 network checks is acknowledged as your validation; Codex has not independently rerun these fixes. The roadmap generator ran successfully while recording this acknowledgment.
- Coordination board and separate-branch cross-review workflow understood. The next gameplay task remains exploration rewards and camp growth, unclaimed by Codex in this review-only turn. Your available local display can support visible playtesting.
- This acknowledgment branch descends from your commit solely to retain the full handoff context. No branches were merged and no gameplay baseline selection is implied. The user still chooses the version to continue from.
- Going forward, both tools record an explicit acknowledgment after reading/reviewing the other's pushed handoff: reviewed branch/commit, scope, findings, actual validation, and any pending choice. Push it so the originating tool can discover the confirmation through this board.

## User decisions

Godot 4.6.3 with GDScript; top-down pixel-art RPG. Explore → fight → absorb/analyze → acquire skills → name/evolve allies → grow a settlement/nation. Host runs the authoritative game on their own machine. Eight players total, including host. Persist implemented per-character and shared world state, extending schemas with each feature. Never fabricate mechanics represented only in UI reference images.

User wants visible test windows. This cloud has no display/live desktop sharing: checks are headless. Provide a tracked-source ZIP for local Godot playtesting; show the actual game window when a supported display is available. Do not imply a headless test is visible.

The user supplied a creature sprite chart, HUD, title, pause, inventory and forest/village tileset references in chat. These are documented inspirations; clean source images are not currently imported. Existing art is procedural placeholder graphics. Gear, quests and title/pause presentation are still future work; settlement gameplay uses the small camp below.

## Last completed gameplay step

Branch: `codex/roadmap-10-ally-work` (includes steps 01–09). First ally recruited after defeating the western clearing Gnasher, then named via F dialogue. Naming costs 80 Magicules once and evolves Goblin → Hobgoblin (HP 30→60, power 4→8, follow speed 45→65, changed silhouette). Below 25% reserves, namer rests at least 8 seconds and until Magicules return to 25%. Other characters continue playing. Ally follows its stable owner; combat roles are not yet implemented; camp work is described below.

Schema v3 introduced saving/replication of ownership, name, race, stats, position, resource costs and exhaustion timer. Legacy v0/v1/v2 saves migrate. Disconnect pauses character simulation; reconnect/reload preserves paid costs and recovery. Respawn retains exhaustion while restoring health, avoiding a dead/sleeping lock.

First camp implemented: B menu, site (350,350), free founding with owned evolved ally within 80 pixels, living/awake actor within 55 pixels. Shared finite wood_1/wood_2 (8 each), stone_1 (8), gather range 36; hut_1 costs 12 wood/6 stone and has collision/safe footprint checks. Top-level schema-v4 camp state is separate from reserved progression.settlements; migration preserves prior worlds. Host-only transactions prevent concurrent duplication, clients receive collision/state, saves retain depletion and construction.

Current step adds B menu owner-only Gather/Build/Follow assignments. Gather walks to remaining deposits and works 3s each, skips depleted targets, and returns to follow. Build walks to camp, works 4s, waits for clear hut footprint, consumes recipe once on completion, and returns to follow. Recall cancels unfinished work without charges. Citizens keep working if owner disconnects/dies while host is running. Schema-v5 persists work role/target/remaining time and migrates old allies to Follow. Clients never simulate jobs. `first_camp.harvest/complete_hut` provide shared single completion for manual and worker actions. Movement is straight-line with collision; obstacles can block jobs until recall/reposition, and no navigation mesh/pathfinding exists.

Next goal: M3 connect exploration rewards to camp growth and add recipes. Current world deposits are finite, one hut recipe; no agriculture, replenishing production, housing bonuses or free placement. Preserve conservation, authority and migrations with the next feature.

## Architecture and constraints

- `GameSession` autoload (`scripts/network/game_session.gd`) owns ENet sessions, peer→stable-character binding, validated intents, snapshots and saves. Host + seven guests, UDP 24560 default, no peer relay.
- `scripts/network/authority.gd` rejects mutations on client replicas. Components use runtime `/root/GameSession` lookup; compile-time autoload references in preloaded scripts break custom SceneTree test loading.
- World resolves stable entity/character IDs. Player-owned health, Magicules, inventory, skill book, analysis and exhaustion must stay bound to an explicit actor. Never trust client costs, positions, HP, ownership or rewards.
- `scripts/persistence/state_codec.gd` captures/applies plain state; `save_store.gd` validates/migrates and atomically writes with a valid backup. Extend capture, restore, validation, migration and snapshots together. Saves and private resume profiles never enter Git, logs or ZIPs.
- Replicas do not simulate gameplay/resource ticks. Host menus block only that player's input; offline menus pause. Snapshots omit credential hashes. Networking currently tested on loopback; WAN, encryption, prediction and adverse-network playtests remain pending.
- Progression dictionaries reserve level/experience/equipment/quests/settlements but not all those mechanics exist. README and roadmap distinguish implemented behavior.

## Validation

Use Godot 4.6.3. Cloud: `source /workspace/.tempestrpg/env.sh` exports `GODOT_BIN` and writable XDG directories outside the repo. Local: set `GODOT_BIN` to the installed executable. Windows: the GUI `godot.exe` detaches from the console, so capture output by redirecting stdout/stderr (e.g. PowerShell `Start-Process -NoNewWindow -Wait -RedirectStandardOutput`) and use `python` instead of `python3`. From repo root:

```bash
"$GODOT_BIN" --headless --path . --editor --import
for suite in smoke combat magicules drops absorption skills_storage persistence allies naming settlement ally_work; do
  "$GODOT_BIN" --headless --path . --fixed-fps 60 --script "tests/$suite.gd" || exit 1
done
python3 tests/network_integration.py
python3 tests/network_settlement.py
"$GODOT_BIN" --headless --path . --quit-after 120
python3 tools/build_roadmap.py
```

Latest validation: 308 local checks (including 35 worker) and 149 network checks (86 general + 63 camp) passed, plus main-scene startup.

Check logs for engine/script errors as well as exit status. Network tests start actual processes and use private temporary profiles; never print raw credentials. Test new meaningful behavior rather than duplicating implementation. Visual tests remain outstanding. Environment installation/start instructions are saved as a cloud configuration draft; publishing happens in environment settings.

## Finish and transfer

Update this file's completed branch/feature/next goal and actual test evidence; update `ROADMAP.md` and regenerate `ROADMAP.html`. Include any unresolved failures or migration requirements. Keep `CLAUDE.md` concise and point it here; use `AGENTS.md` for common rules so the tools do not get contradictory copies. Both tools must read this handoff, including Codex after Claude makes changes.
