# TempestRPG

A Godot **4.6.3** / GDScript prototype for a top-down pixel-art Isekai RPG.

## Screenshots

Current state of this branch, captured by the visible playtest (`tests/visual_playtest.gd`, 640 × 360). Updated with every roadmap step; all 166 captures are in `docs/playtest/` with `docs/playtest/log.md`.

<table>
<tr><td align="center"><img src="docs/playtest/166_map_labels.png" width="400" alt="The world map fits its frame; names never overlap"><br><sub>The world map fits its frame; names never overlap</sub></td><td align="center"><img src="docs/playtest/165_log_tall.png" width="400" alt="The log box: − / + and 30 lines to scroll; loot on the ground; Shift sprint"><br><sub>The log box: − / + and 30 lines to scroll; loot on the ground; Shift sprint</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/162_house_inside.png" width="400" alt="Your house: furnish it (bed, trophy, stove…)"><br><sub>Your house: furnish it (bed, trophy, stove…)</sub></td><td align="center"><img src="docs/playtest/161_house_outside.png" width="400" alt="Your own house in the village"><br><sub>Your own house in the village</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/159_arena_match.png" width="400" alt="Duels and arena matches: fight inside the ring"><br><sub>Duels and arena matches: fight inside the ring</sub></td><td align="center"><img src="docs/playtest/160_arena_window.png" width="400" alt="The arena window and board"><br><sub>The arena window and board</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/158_guild_bank.png" width="400" alt="The guild hall: bank, level, perks and weekly quests"><br><sub>The guild hall: bank, level, perks and weekly quests</sub></td><td align="center"><img src="docs/playtest/157_guild_hall.png" width="400" alt="A Guild Hall in your village"><br><sub>A Guild Hall in your village</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/156_guild_window.png" width="400" alt="Guilds: the guild window (P → Guild)"><br><sub>Guilds: the guild window (P → Guild)</sub></td><td align="center"><img src="docs/playtest/155_guild_chat.png" width="400" alt="Guild tag above your head; chat in the log"><br><sub>Guild tag above your head; chat in the log</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/154_class_staff.png" width="400" alt="The Mage: staff bolts and class skills on the hotbar"><br><sub>The Mage: staff bolts and class skills on the hotbar</sub></td><td align="center"><img src="docs/playtest/43_equipment_card.png" width="400" alt="The pixel UI: equipment window and item card"><br><sub>The pixel UI: equipment window and item card</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/153_classes.png" width="400" alt="Classes: the old master teaches seven classes"><br><sub>Classes: the old master teaches seven classes</sub></td><td align="center"><img src="docs/playtest/152_class_master.png" width="400" alt="The old master lives in your settlement"><br><sub>The old master lives in your settlement</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/151_storage.png" width="400" alt="Storage: settlement and city storage"><br><sub>Storage: settlement and city storage</sub></td><td align="center"><img src="docs/playtest/150_storage_hall.png" width="400" alt="Storage at a major city's town hall"><br><sub>Storage at a major city's town hall</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/148_army.png" width="400" alt="Armies: your soldiers follow you"><br><sub>Armies: your soldiers follow you</sub></td><td align="center"><img src="docs/playtest/147_keys.png" width="400" alt="Gamepad support and key rebinding"><br><sub>Gamepad support and key rebinding</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/146_pets_window.png" width="400" alt="Pets: hatch eggs, choose who follows you"><br><sub>Pets: hatch eggs, choose who follows you</sub></td><td align="center"><img src="docs/playtest/145_pet_following.png" width="400" alt="A pet trotting along"><br><sub>A pet trotting along</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/143_cooking.png" width="400" alt="New professions: Cooking, Enchanting, Tailoring"><br><sub>New professions: Cooking, Enchanting, Tailoring</sub></td><td align="center"><img src="docs/playtest/142_treasure_goblin.png" width="400" alt="World event: a treasure goblin"><br><sub>World event: a treasure goblin</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/141_invasion.png" width="400" alt="World event: a town invasion"><br><sub>World event: a town invasion</sub></td><td align="center"><img src="docs/playtest/140_meteor_shower.png" width="400" alt="World event: a meteor shower"><br><sub>World event: a meteor shower</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/139_trading.png" width="400" alt="Trading with a friend"><br><sub>Trading with a friend</sub></td><td align="center"><img src="docs/playtest/138_dungeon_lever.png" width="400" alt="A dungeon lever and the locked vault"><br><sub>A dungeon lever and the locked vault</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/136_dungeon_traps.png" width="400" alt="Dungeons: spike traps on the rope bridges"><br><sub>Dungeons: spike traps on the rope bridges</sub></td><td align="center"><img src="docs/playtest/137_dungeon_door.png" width="400" alt="The sealed boss door: pull both levers"><br><sub>The sealed boss door: pull both levers</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/135_tier_looks.png" width="400" alt="Each gear tier has its own look (21–48)"><br><sub>Each gear tier has its own look (21–48)</sub></td><td align="center"><img src="docs/playtest/52_pause_open.png" width="400" alt="Multiplayer by invite codes only (Esc menu)"><br><sub>Multiplayer by invite codes only (Esc menu)</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/133_title.png" width="400" alt="Titles: Leviathan Catcher above your head"><br><sub>Titles: Leviathan Catcher above your head</sub></td><td align="center"><img src="docs/playtest/134_achievements.png" width="400" alt="The achievements window (Y)"><br><sub>The achievements window (Y)</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/131_eclipse_wyrm.png" width="400" alt="The final raid boss: the Eclipse Wyrm"><br><sub>The final raid boss: the Eclipse Wyrm</sub></td><td align="center"><img src="docs/playtest/132_ending_choice.png" width="400" alt="The ending: Moonwarden or Eclipse Sovereign"><br><sub>The ending: Moonwarden or Eclipse Sovereign</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/127_quest_dialog.png" width="400" alt="Quest givers: dialogue with portraits"><br><sub>Quest givers: dialogue with portraits</sub></td><td align="center"><img src="docs/playtest/128_story_speech.png" width="400" alt="The story speaks: Lumi, the star-sprite"><br><sub>The story speaks: Lumi, the star-sprite</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/126_quest_giver.png" width="400" alt="Brookhaven: ! quest givers and the bounty board"><br><sub>Brookhaven: ! quest givers and the bounty board</sub></td><td align="center"><img src="docs/playtest/129_quest_log.png" width="400" alt="The quest log (O)"><br><sub>The quest log (O)</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/123_night.png" width="400" alt="Night falls: soft lights in the dark"><br><sub>Night falls: soft lights in the dark</sub></td><td align="center"><img src="docs/playtest/125_weather_gloom_mist.png" width="400" alt="Weather: gloom mist over Gloomveil"><br><sub>Weather: gloom mist over Gloomveil</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/121_dungeon_hall.png" width="400" alt="Inside a dungeon: cave halls over chasms"><br><sub>Inside a dungeon: cave halls over chasms</sub></td><td align="center"><img src="docs/playtest/122_dungeon_boss.png" width="400" alt="A dungeon boss guards a rich chest"><br><sub>A dungeon boss guards a rich chest</sub></td></tr>
<tr><td align="center"><img src="docs/playtest/118_gloomveil.png" width="400" alt="Gloomveil: the purple, gloomy land (levels 28-33)"><br><sub>Gloomveil: the purple, gloomy land (levels 28-33)</sub></td><td align="center"><img src="docs/playtest/119_jade.png" width="400" alt="The Jade Terraces: rice paddies and bamboo (34-40)"><br><sub>The Jade Terraces: rice paddies and bamboo (34-40)</sub></td></tr>
</table>

## Smoother multiplayer, aim and dash, merchants, teleports (2026-10-22)

**Smoother multiplayer:** guests no longer lag — creature updates are applied only when they change (lookups were quadratic) and your own character moves at once on your screen while the host stays in charge. **Controls:** your character faces the mouse while you use it, and strikes, skills and dashes go where it points; **left click** strikes; **right click dashes** about three tiles for a third of the stamina (a moment of invulnerability). **Hotbar:** drag a skill onto another slot to swap, right click clears, the skill menu places skills and moves them along. **Health comes back** out of combat (1.5% a second after 6 s). **Ferry:** Sail pays the fare when you have no ticket. **Teleport scrolls:** each city's merchant sells "Scroll: <City>" — use it, click the glowing city on the map, arrive after 3 seconds (a hit cancels it). **Merchants** look like the equipment window (icon grid, item card, Buy / Sell / Sell all), and every kind of good has an icon. **Loot** shows whose it is and for how long once it has lain 10 s, and disappears after 10 minutes; **drop** bag things and loose gear at your feet. **Balance:** Epic loot 1.5×, Legendary 2× and Mythic 4× rarer; profession chances drop fast when you are far below the level (nothing beyond 10 levels). **Fixes:** the gear bag counted worn pieces (now 32 loose + 7 worn); salvaging works anywhere; any weapon up to Rare works aside from your class; the trade window's Zeni no longer jumps (and can be typed); the hotbar no longer sinks into the controls line.

## Characters first, short invites, salvage (2026-10-19)

**Characters first:** PLAY opens your characters (one per world) with a detailed overview — the animated model with its worn gear, level, race, class, HP, Magicules, Zeni, attributes, gear score, crafts, achievements, title, pets, playtime, last played and home world — then **Play** its world or **Join a Friend** with it (its race stays); **New character** takes a name and a race and then creates a world or joins a friend; unnamed characters are named there; Delete asks twice. **Names** show above every character's head (Options: Show my name) and in chat. **Short invite codes:** Invite a Friend gives one short code (TRPG-XXXXX-XXXXX); the friend pastes it and joins — no reply code, no router settings. The connection details are swapped by themselves through ntfy.sh (free, no account), encrypted with the code; play still goes directly between the PCs. Without the relay the long two-step codes still work (and they work again: they used to come out empty). **Salvage** (equipment window, at the Forge or in a town): a loose piece becomes bars, cloth or gems by its kind (more for rarer pieces; Legendary and Mythic also give Arcane Essence, which the Adamantite tools need); Salvage Commons clears the junk. **Mouse buttons and key icons:** Options → Keys binds any action to a key or a mouse button, and the hotbar, the controls line and the F prompt show the bound key or mouse as an icon (Kenney Input Prompts, CC0). **Map labels** sit on dark plates in gold and white, readable on any ground. **Pets:** Chiikawa (+6% XP), Hachiware (+6% Zeni, +2 defence) and Usagi (+10 speed). **Fixes:** the goblin is back at your side at once after you respawn or travel (so founding the camp works again); the Old Master is in every world from the start; joining with your own character no longer offers a race; one clearing tree could never be chopped; worlds whose merchants still sold the old Master tools were shown as damaged since v1.3 and load again.

## Everything in the world works (2026-10-19)

**If it's there, it works (user SVE recording):** every tree can be chopped and every rock, pebble and ore mined — the First Clearing's own trees and rocks too, which used to be scenery — and none can be walked through any more: the camp's deposits (and their stumps) are solid, pebbles have a footprint. Glowing mushrooms are picked for **Glowcap** (Alchemy: Glowcap Tonic). Every water can be fished, the smallest puddle too (casting looks a little further ahead and to the sides), but small water (under 120 connected tiles, like the clearing's pond) only holds Common and Uncommon fish, lakes up to Epic and the sea everything. The biggest lake, Mirror Lake, hides its own mythical **Glasswater Wyrm**. Tests: `tests/world_resources.gd` (23).

## Tool crafting (2026-10-19)

**Tool crafting (user request):** axes, pickaxes and fishing rods now have **seven tiers** — Basic, Bronze, Iron, Silver, Gold, Mithril, Adamantite (rods: Basic, Birch, Pine, Maple, Cherrywood, Ironwood, Jadewood). Town merchants sell the first two; every higher tier is crafted at the camp's Forge or in a town, one after the other, with the tool's own profession level (Woodcutting for axes, Mining for pickaxes, Fishing for rods: 5 / 10 / 18 / 25 / 32 / 40) and that level's materials (axes: logs + bars, pickaxes: ores + a log handle, rods: logs + fish). Crafting always succeeds and gives profession XP. Each tier needs fewer swings, gathers more, works faster and makes rare fish likelier and the reel zone wider; nothing is locked behind a tool (user choice). The Woodcutting, Mining and Fishing tabs show your tool, the next one with its ingredients and a Craft button, and the tiers after it. Save v43 turns the old Fine and Master tools into Iron and Gold, which work exactly as before. Tests: `tests/tool_crafting.gd` (25).

## Playtest fixes (2026-10-19)

**Loot on the ground:** gear from creatures, bosses and chests pops out in a little arc and lies beside them (bobbing, with its icon); walk over it, or press **F** within a short distance, to take it (claims still apply). **Sprint:** hold **Shift** to run 60% faster for 5 s; stamina refills in 4 s (an emptied bar must refill a quarter first) and shows as a small bar under your character while it is not full (rebindable; the host decides the speed). **Log box:** − and + make it smaller (title bar only) or bigger; the mouse wheel scrolls back through the last 30 lines. **World map:** fits inside its frame; names use the pixel font with a thin outline and are placed so they never overlap (zoom in for the rest). **First quest:** any 3 creatures count, not only those in the First Clearing. **Equipment window:** the stats sit in two columns inside their box; the feet slot is called **Boots**. **Starter tools:** new characters carry a basic axe, pickaxe and fishing rod (save v42 hands them to existing ones). **Leveling:** double XP up to level 5. **Art:** the half-cut houses (`house_a` drawn 48 of 64 px) are whole again; boulders block more than their bottom edge, so you no longer walk into them. Classless characters keep using weapons up to Rare (level and attributes still apply). Tests: `tests/sve_fixes.gd` (32).

## The world

The First Clearing is the start of an archipelago of about 10 × 11 screens (M4.5a): **Verdant Isle** with Thornwood (dense forest), Mirror Lake (a bridge to the ruined keep on its islet), Cinder Crater (ash, boulders, a lava pool) and its beaches; **Harrowmere**, the walled-town island across a long bridge; **Ambervale**, the autumn continent, and the volcanic **Emberreach Isles** across the sea (reachable once ferries and ships exist). The clearing's roads continue as paths, the HUD names the region you are in, and **M** (or the pause menu) opens the world map with your position. Coasts, lakes and lava block movement; bridges carry you across. The regions have their own content (M4.5b): 13 creatures that respawn (easy Gnashers in the meadows and on the beach, Gnashers and a Thornback in Thornwood and by Mirror Lake, Elites in Cinder Crater; Harrowmere is peaceful), six richer deposits (Thornwood wood, crater and lakeshore stone, meadow wood) that explorers gather into the camp's stock, and five chests — the keep's and the crater's give Rare or Epic gear. Tests: `tests/world_map.gd` (23), `tests/region_content.gd` (21).

## Weapons and armour (item expansion)

User request: hundreds of weapons and armour pieces with their own looks and names. **849 items**: 524 weapons (124 daggers, 120 swords, 104 bows, 96 spears, 80 scythes) and 325 armour and jewellery pieces, in **six rarities** — Common, Uncommon, Rare, Epic, Legendary and the new **Mythic** (×2.7, three passives, three rune sockets).

- **Looks:** icons from three CC0 packs (7Soul1's 496 RPG icons, Idylwild's Arsenal and Armory, babysamurai's Super Epic Weapons) plus scythes drawn from parts; every source icon also comes in material and element colours (`tools/generate_items.py` builds the atlases and `scripts/items/item_bases.gd`). Your weapon is drawn in your hand.
- **Item levels and rarity:** plain pieces drop from Common, material variants from Uncommon, **elemental** ones from Rare, the glowing epic pieces from Epic. Drops, chests, the trial, the forge and merchants pick pieces near the source's level, so later regions give stronger gear.
- **Daggers:** a quick short stab (0.3 s).
- **Elements** (Rare and up, stronger with rarity): fire burns, frost slows, storm arcs to another creature, shadow sometimes hits twice as hard, holy heals you, nature poisons, blood bleeds and heals a little, arcane restores Magicules. Hits burst in the element's colour.
- **VFX:** Rare+ weapons glow, Epic+ throw sparks — more for Legendary and Mythic.
- **Sets:** eight five-piece sets (Emberlord's Regalia, Rimewarden's Plate, Stormcaller's Garb, Nightstalker's Shroud, Dawnguard Vestments, Wildheart Raiment, Bloodbound Mail, Starweaver's Robes): two pieces give a themed stat, four give +15% weapon damage and make a weapon of the same element act half as strong again.
- **Uniques:** 23 named Legendary/Mythic pieces with their own ability — e.g. *Dawnbreaker* (heals you and your party), *Cinderheart* (every fourth hit explodes), *Kingsbane* (double damage to weakened foes), *Skyrender* (lightning leaps to three more creatures), *Soulreaper* (kills heal), *Phoenix Plate* (survive one lethal hit every two minutes).

Tests: `tests/items.gd` (28).

## HUD size and the controls line

User request: the HUD was too big and the controls line should close completely. **Esc → Options → HUD size** (65 / 75 / 85 / 100 %, default 75 %) shrinks the always-on parts — status card, minimap, hotbar, messages, analysis box, titles, party frames — toward their own screen corner; windows keep their size. **F1** (or the Options checkbox) hides or shows the controls line, remembered on this computer. The game now draws at the window's resolution (stretch mode `canvas_items`, still the 640×360 layout with integer scaling), so smaller text stays sharp; playtest captures are saved at 960×540.

## Where saves are kept

Each player's worlds, character profiles, the server key and settings live in the game's own folder, **`%APPDATA%\TempestRPG`** (never next to the game, so a shared download carries nobody's saves). Versions before this kept them in Godot's shared folder (`%APPDATA%\Godotpp_userdata\TempestRPG`); the first start copies them over once (never overwriting newer files) and leaves the originals as a backup. Tests: `tests/save_folder.gd` (5).

## Playing with friends: the exe and the server

- **The game as an exe:** `godot --headless --path . --export-release "Windows Desktop" build/windows/TempestRPG.exe` builds `TempestRPG.exe` (everything inside, no installation) plus `TempestRPG.console.exe`; `tools/release/` holds `HOW TO PLAY.txt` to put next to them (`build/` is not committed). Needs the Godot 4.6.3 export templates. Run `tools/build_world_cache.gd` first: exported games trust the packed world cache. **Professions (L):** F at any tree or boulder chops or mines it; the prompt shows your success chance; Woodcutting and Mining level 1–50 with rarer woods and ores in harder regions. **Fishing:** cast with a rod (F facing water); when a fish bites, press F while the marker is in the green zone (the zone is your chance per press); 47 fish including six mythical sea creatures; the fish log is in the Professions window; merchants buy whole stacks (Sell all). **Quests and the story (M9c–d):** "The Shattered Moon" starts by itself with the star-sprite Lumi and runs through seven chapters to the Eclipse Wyrm below the Sage Spire, where you choose the ending (Moonwarden or Eclipse Sovereign, each with its own Mythic weapon); about forty side quests; quest givers in the towns show ! (a quest) or ? (something to hand in) — F talks to them; every town has a bounty board with repeatable bounties; O opens the quest log and the tracked objective sits under the minimap. **Housing (M16):** build Your House in the settlement and furnish it (a bed to rest, trophies, a stove, a wardrobe…), or rent an inn room in a major city. **Boss drops:** every boss has its own uniques and its own material (shown under the boss bar); forge the uniques from the material at Smithing. **Duels and the arena (M15):** P → Duel challenges a friend next to you (nobody dies, nothing is lost); an Arena in your village hosts best-of-three matches with an arena board. **Guilds and chat (M14a):** P → Guild founds a guild (1000 Zeni) with a name, tag and emblem; invite friends, give out ranks; the tag shows above your head. Build a **Guild Hall** in your village: F there opens the guild bank, the guild level and perks, and three weekly guild quests. Enter chats with the world, /g with your guild, /p with your party. **Pixel UI (M13):** panels, slots and bars from Dogobongocat's UI pack and the pixel fonts m5x7/m3x6 (Daniel Linssen) and Toasty; the look before it is the git tag `before-ui-overhaul`. **Classes and attributes (M12):** four attribute points per level (Strength, Dexterity, Intelligence, Vitality; + buttons in the equipment window); the old master in your settlement (F) teaches a class — Warrior, Assassin, Lancer, Reaper, Archer, Mage (staffs: a free magic bolt) or Monk (fist weapons: fast jabs) — with two class skills (the second at level 25), and from level 20 a subclass; every weapon needs its class (classless: up to Rare), Legendary and Mythic gear also attributes. **Storage:** build Vaults in your village (settlement storage, also opened at the town hall of every major city), or rent storage in a major city (only usable there). **Armies (M11h):** recruit soldiers in your village, command them with C (follow, hold, charge); they rise in rank by fighting. **Gamepad and keys (M11g):** any gamepad works; Options → Keys rebinds the keyboard. **Pets (M11f):** hatch Mysterious Eggs into ten animal companions with small bonuses; V chooses who follows you. **World events (M11d):** meteor showers, town invasions and treasure goblins appear near players every so often. **Trading (M11c):** P → Trade with a character next to you: put gear, items and Zeni on the table; when both are ready, everything changes hands. **Achievements and titles (M9e):** 46 achievements; Y shows them, and 34 titles (Leviathan Catcher, Master Miner, Wyrmslayer…) can be worn above your head. **Day, night and weather:** a 24-minute day with dark nights (creatures hit harder but give more XP), rain, storms, snow, sandstorms, fog and more by region; the clock and weather sit under the minimap. **Dungeons and hidden elites (M7c, M11b):** cave mouths in Thornwood, Frostpeak, the Emberreach Isles, Gloomveil and the Jade Terraces lead (F) into dungeons with creature halls, spike traps on the bridges, two levers that open the boss chamber, a vault for the dungeon's key, an end boss and a rich chest — choose Normal or Heroic (eight levels stronger, Legendary loot) when you enter an empty one; ten hidden elites roam the regions (marked on your map once found). **The Eastern Reaches (M7b):** by ferry to the Goldwind Steppe (levels 22–27), purple Gloomveil (28–33) and the Jade Terraces (34–40); the Ki Realm is now the endgame (entry level 36, creatures 40–48). **Raid bosses (M7a):** twelve bosses in marked arenas, one per region (two in the Ki Realm) — step out of the red zones before they land; everyone who helps gets their own loot. The level cap is 50; the world map shows each region's level range. **Cooking, Enchanting and Tailoring (M11e):** meals with long buffs (and more XP), runes for your sockets, light armour from creature materials. **Smithing and Alchemy:** pick herbs from bushes; in any town (or at the camp's Forge / Essence Shrine) open Professions (L) to smelt bars, forge gear and brew potions and elixirs — each recipe shows its chance. The owner's private build with the mod menu (F10) is the "Windows Dev" preset (`build/windows_dev/TempestRPG-Dev.exe`); it is only ever published as a draft release.
- **Playing together (M10, user decision):** invite codes are the only way. Every world is single player until its owner switches on **Multiplayer** in the Esc menu; **Invite a Friend** makes one code per friend, the friend pastes it into **Join a Friend** and sends back the reply code. Nothing to configure: the world runs on the owner's computer, no ports, no IP addresses, no server provider. The owner decides whether guests may bring **their own character** (Esc → Guests): it then travels with its level, skills, gear, items, Zeni, professions, fish log, achievements and quests, and is written back into the guest's own world on every autosave and when they leave (map discoveries stay with each world). Joining by address and the console server are gone from the game (developer builds keep them for the network tests).
- **Join codes (no router settings, no extra software):** Esc → **Invite with a code** → *New invite code* → send it to one friend; they paste it into **Join a Friend** and the game shows them a **reply code** to send back; paste it and press *Let them in*. One code per friend. The games connect directly (WebRTC; a public STUN server tells each side its Internet address). Works on most home networks; some strict networks (mobile hotspots, campus/company networks) block it. Codes contain your Internet address — share them only with friends. Needs `addons/webrtc_native` (official Godot WebRTC plugin 1.2.2, Windows x86_64 libraries; licences included).
- Tests: `python tests/network_server.py` (8 real-process checks: console server, owner as host, a friend, the owner leaving and returning), `python tests/network_codes.py` (6: a host and a friend connected only by swapping codes).

## Your nation (M5a)

- Press **N** once your camp is founded. The founder **names the nation** and picks its **banner** (eight colours, six emblems); the name shows in the HUD inside your settlement and on the world map, the banner on every banner pole you build.
- **Build freely:** pick a building and a ghost follows the mouse on the tile grid — green fits, red tells you why not (water, rock, trees, other buildings, deposits, someone standing there, outside the ring). Left click builds from the camp's shared stock, right click or Esc stops. **Demolish** tears a building down (its materials are lost).
- **Camp → village → town:** a village needs the Goblin Hut and Storehouse, four placed buildings (two houses and a well) and 30 wood + 20 stone; a town needs ten buildings, a Town Hall and a Watchtower, and 60 wood + 50 stone + 5 essence. Each tier widens the ring you can build in and unlocks buildings (Large House, Watchtower, Town Hall; the Lodge for towns). Rank up in the nation window at the camp flag.
- **Citizens (M5b):** homes come from the Goblin Hut (2), straw huts (1), houses (2), the Town Hall (2), large houses (4) and lodges (6). While a home is free and the store holds a day's food for everyone (newcomer included), a new citizen arrives every 90 s and walks about near their home. Tearing down a house sends its residents to another free home, or away. A town needs **6 citizens**.
- **Food (M5b):** place **fields** (4 wood, you can walk on them) and press **F** on one to plant **wheat** (2 min, 4 food), **carrots** (4 min, 9) or **pumpkins** (8 min, 20); F again when ripe harvests into the nation's food store. Every 5 minutes each citizen eats 1 food; after two hungry days a citizen leaves (and another each hungry day after). The nation window shows population, homes, food and the next newcomer.
- **Jobs (M5c):** open **Citizens & trade** from the nation window and give each citizen a job. **Workers** bring 1 wood or stone a minute; **farmers** tend three fields each (harvest what is ripe, plant carrots); **crafters** (2 per Workshop) make a trade good from 1 wood + 1 stone a minute; **merchants** (2 per Market) sell a good for 30 Zeni a minute into the **treasury**; **guards** (3 per Watchtower) shoot creatures inside your ring. Losing a workplace sends its citizens back to idle.
- **Caravans and the treasury (M5c):** at the camp flag, send a caravan with up to ten goods to a town (2–10 minutes there and back, 40 Zeni and more per good the further it goes); its merchant leads it. Anyone can take Zeni from the treasury at the flag.
- **Rival nations (M5d):** seven nations hold the archipelago's towns — the Verdant League (Brookhaven), Frost Clans (Rimeholm), Dune Sultanate (Dunemarch), Amber Crown (Amberhold), Mire Tribes (Bogsend), Sakura Shogunate (Hanamura) and Ember Dominion (Cinderport). Their banners fly in their capitals and on the world map, and you can talk to their leaders (F). For now they are neither friend nor foe; diplomacy comes later.
- **The siege (M5d):** once your settlement is a village with three citizens, a monster horde gathers every 30 minutes (the first after 15), or when you press **Face the horde** in the nation window at the flag. After a one-minute warning, three waves march on your flag from one side (the HUD shows the wave and breaches). Guards and characters fight them (normal XP and loot; they never respawn). Eight creatures reaching the flag lose the siege — half the food and half the treasury are plundered; beating every wave pays Zeni into the treasury. A reload calls a running siege off.
- Saves: schema **v30**.

Tests: `tests/nation.gd` (34), `tests/citizens.gd` (24), `tests/jobs.gd` (26), `tests/siege.gd` (20).

## The Ki Realm (M4.7)

A hidden island group far out at sea, inspired by a certain martial-arts anime (original names, obvious nods). It never shows on the normal world map; inside it, the map (M) shows only the realm.

- **The way in:** an old **hermit** sits unmarked in Sakura Vale. At **level 15+** he asks what you seek — pick the right answer (F to talk) and the world folds. The **realm guide** in Dome City sends you back.
- **Places:** **Dome City** (capsule-dome houses), **Hermit Atoll** across a long bridge, the **World Martial Grounds** (tournament ring) to the south, the **Sage Spire** with the **Guardian's Lookout** on top, **Raptor Gulch**, **Wasteland Canyon** with its mesas and the **Android Works**.
- **Foes** (they cannot be analysed): raptors and a tyrant rex, gi fighters and monkey brawlers, android scouts, tanks and a bio-android, and the Demon King; two leveling spots (Raptor Nest, Scrap Yard).
- **Mentors** teach for Zeni: **Ki Blast** (Spire Sage, fast long shot), **Turtle Wave** (Turtle Sage, long charged beam), **Ki Disc** (Canyon Hermit, piercing with bleed), **Spirit Orb** (the Guardian, huge area that stuns) and the **Kaio Surge** (Mountain Master). Activate learned skills in the skill tree (K).
- **Transformations** (**X** to power up / down): **Kaio Surge** (red, ×1.3 damage, ×1.2 speed), **Golden Aura** (×1.5 / ×1.3) and **Golden Aura II** (×1.8 / ×1.35). A flame aura shows for everyone; it drains Magicules every second and fades when they run out.
- **Seven wish orbs** lie at hidden spots (F picks one up; they cannot be sold or thrown away). Bring all seven to the **altar on the Guardian's Lookout** and wish for a **Legendary item**, **20,000 Zeni**, **3 skill points** or **the next transformation**. Then the orbs turn to stone and scatter to new spots after an hour of world time.
- **The tournament** (level 16, 500 Zeni): five bouts in the ring (Gi Fighter → Monkey Brawler → Android Scout → Bio-Android → Demon King). Falling or leaving the ring loses. The champion wins **5,000 Zeni**, and the first title brings the **Golden Aura**.
- **A continent of its own** (user request): the realm is nearly as big as the archipelago (about 900 × 640 tiles, west beyond its sea) — Dome City in the middle; Raptor Gulch, **Glacier Ridge** (snow), Sage Spire with the Guardian's Lookout, Android Works, Wasteland Canyon with its mesas, **Turtle Coast**; Hermit Atoll, the World Martial Grounds and the **Emerald Isles** across bridges; new villages **Pepper Village, Frostbite Hamlet, Iron Bastion, Mesa Outpost, Elder's Village**; 23 creatures (frost bears and snow wisps in the snow), four leveling spots (Raptor Nest, Scrap Yard, Glacier Den, Fighters' Pit); mentors, the twelve orb spots, the altar and the arena spread across it. Worlds from before move their realm creatures and anyone standing in the old small realm to the new one (save v31).
- The realm's own storyline comes later (user plan).
- Saves: schema **v26**.

Tests: `tests/ki_realm.gd` (38).

## Parties (M4.6)

- Press **P**: invite characters who are online (up to **4** in a party); they accept or decline in their own party window. The leader can remove members; anyone can leave (the next member leads).
- Fighting together: XP still needs your 10% damage share, plus **+10% XP per other member nearby**; the **Zeni** of a kill is **split evenly** among members nearby (items still go by damage rank).
- Members see each other's **HP and Magicules** under the status card and in their own colour on the **minimap and world map**; there is no friendly fire.
- Members sail along on an owner's **ship** without an invitation; press **F** beside a fallen member to **revive** them (a third of their HP) before they respawn; **leveling spots** respawn twice as fast while a party fights there (and spot creatures come back while you fight nearby).
- Saves: schema **v25**.

Tests: `tests/party.gd` (23).

## Harbours, ships, tools, mounts, runes and augments (M4.5d)

- **Harbours** in every region (9): a pier, a ferryman and, in Harrowmere, Amberhold and Cinderport, a shipwright. Press F at a harbour to open its map: pick a harbour, then sail — a short voyage plays across the map.
- **Ferry tickets** take you once to one harbour (price by distance, in your bag); a **ferry pass** (400 Zeni) allows unlimited trips for an hour of world time. Everyone needs their own ticket.
- **Your own ship** (endgame, 40,000 Zeni at a shipwright): no more tickets, summon it at any harbour, see it docked there, and invite up to three characters standing next to you aboard.
- **Tools** are never equipped — once bought from a town merchant they are used for their work: an **axe** or **pickaxe** gathers 25/50/100% more wood or stone (Basic/Fine/Master), a **fishing rod** lets you fish (F facing the water, F again when it bites); fish are sold to merchants, rarer ones with better rods.
- **Mounts:** buy a donkey or horse at the stables of Brookhaven, Amberhold and Dunemarch, or tame a wild boar (Ambervale) or desert lion (Sunscorch) with their favourite offering. **H** rides (+40-80% speed on land); a hit or an attack throws you off.
- **Runes** fit gear sockets (Rare and Epic 1, Legendary 2) at your camp's Smithy: HP, Magicules, speed, strike, defense, regeneration, leeching or thorns; replacing one destroys the old. Elites sometimes drop them; the travelling merchant sells them.
- **Augments** are permanent upgrades installed at your camp's Essence Shrine (100 Zeni): one slot at level 5, two at 10, three at 15; a full set returns the oldest to your bag.
- Saves: schema **v24**.

Tests: `tests/travel.gd` (44).

## A bigger world, towns and trade (M4.5c)

- **About 9x the world** (19,200 x 12,288 px). The **home continent** you walk is Verdant Isle grown together with **Frostpeak** (snow, igloos, a two-level mountain) in the north and the **Sunscorch Desert** (sand, palms, domed houses, mesas) in the west, plus Harrowmere over its bridge. Across the sea, reached **by ferry**: the southern continent of **Ambervale** (autumn) and **Mirewood Marsh** (mud, pools, dead trees), the island of **Sakura Vale** (cherry blossom, bamboo, pagoda-style houses, a hilltop shrine) and the **Emberreach Isles** with their volcano. Every region has a **town** (8) and **villages** (16) with buildings in its own style; the HUD names the place you are in, and the world map shows towns, villages and piers.
- **Verticality:** plateaus, mesas, the mountain and the volcano rise above the land. Their rims are ledges you cannot climb and their south faces rock walls; roads climb them over stairs.
- **New creatures:** two kinds per new region (Frost Bear, Snow Wisp, Dune Viper, Sand Scuttler, Bog Kappa, Mirecap, Bamboo Sprite, Paper Lantern, Amber Owl, Burrow Mole, Ember Flame, Salamander), each teaching its own skill when analyzed (Frost Maul, Chill Touch, Venom Fang, Sand Burst, Mire Grasp, Spore Cloud, Bamboo Thrust, Lantern Flare, Gale Wing, Burrow Strike, Ember Burst, Magma Bite) and leaving its own material. The home continent's are levels 8-13, the ferry lands' 12-20; two hidden leveling spots per region.
- **Zeni:** creatures drop it (split by damage share), chests hold it, merchants pay for what you sell (30% of the price). A defeat drops 10% of your Zeni into your pile.
- **Merchants:** one in every town (gear by the region's level, draughts and tonics, materials, now and then a skill scroll); restock every 15 minutes. Build a **Market Stall** and a **Smithy** at your camp and hire a trader (150 Zeni) and a gear smith (250 Zeni). A **travelling merchant** turns up now and then at a roadside somewhere in the world, unannounced and unmarked, with better wares.
- **Goods:** Healing Draught (Q) and Magicule Tonic (Z): +40 over 5 s, one per 20 s. **Scrolls** (read them from the bag) teach a creature's skill without analysis; four very rare ones teach skills found nowhere else (Tempest Edge, Glacial Nova, Meteor Fall, Phantom Step). Learned skills still need a point to activate.
- **Ferries:** stand on a pier and press F: 30 Zeni to sail to the pier across the sea.
- Saves: schema **v23** gives older characters an empty purse and older worlds the new merchants, camp staff and creatures.

Tests: `tests/trade.gd` (49), `tests/region_creatures.gd` (11), plus the grown world in `tests/world_map.gd` (26) and the balance probe's new bands.

## Playing together, defeat and the minimap (step 24a)

- **Defeat:** after 5 s you respawn at the camp flag (or the clearing's spawn before the camp is founded) with full HP and Magicules. You lose 10% of the XP span towards your next level (never a level), and your bag — materials and unequipped gear — stays behind as a pile where you fell. Equipped gear stays with you. Piles never expire; every defeat adds one. For 5 minutes only you can pick yours up, then anyone can.
- **Round minimap** (top right): terrain around you, you, friends, your ally, creatures, your piles (on the rim when far away), chests you haven't opened and leveling spots you have found. The world map (M) marks your piles and found spots too.
- **Fair rewards:** everyone who dealt at least 10% of a creature's damage gets its full XP and may absorb it; its Magicules are split by damage share into personal pickups, and its item goes to the top damage dealer (each owned for 5 minutes, then free for all). Creatures get +25% HP for every extra character nearby when a fight starts.
- **Creatures** have levels (shown above their health bar) and come back after 45 s (Easy), 90 s (Standard) or 3 min (Elite). Each creature region hides two **leveling spots** whose creatures return three times faster; they appear on your maps once you find them. Region deposits refill 15 minutes after you empty them.
- **Naming** costs 35% of your maximum Magicules plus 2.5% per level of the monster (at most 90%): the goblin (level 1) takes 37.5%, so it no longer exhausts you on its own.
- **Bow:** arrows really fly now and hit the first creature or wall they reach. Creature sprites are drawn at 75% so they match the characters.

Tests: `tests/balance_systems.gd` (32), plus updated leveling, naming, races, respawn, sprites, weapons and network checks.

## Numbers and balance (step 24b)

- **Basic strikes by race:** Slime 12 damage for 2 Magicules, Human 10 damage for free (and 25% faster recovery), Demon 14 damage for 4 Magicules. Weapons deal their own damage for every race.
- **Skills** hit harder the more they cost (12 × (cost / 2)^0.75: Thorn Lash 34 … Piercing Fang and Dark Lance 62) and each has an effect: **slow** (Thorn Lash, Dark Lance), **root** (Engulf), **stun** that cancels a creature's bite wind-up (Power Slash, Piercing Fang), **knockback** (Power Slash, Lunge), **area** (Acid Splash), **bleed/burn** over a few seconds (Acid Splash, Rending Bite, Engulf, Piercing Fang), **dash** (Lunge) and **drain** (Shadow Claw). Affected creatures are tinted for everyone (stunned yellow, rooted green, slowed blue, bleeding violet); the hotbar tooltip lists a skill's effects.
- **Creatures** get 30% more HP and 8% stronger bites per level above their tier's base, so Cinder Crater's Elites (levels 11–13) need your skills.
- **XP:** a defeat gives (10 + 2.5 × creature level) × 1 / 1.4 / 2 for Easy / Standard / Elite, an absorption half of that, the trial 1500. Levels need 100 × (level − 1)^2.8 XP in total: level 2 after about 5 creatures, level 5 after ~20 minutes, level 10 after ~2 hours, level 20 after ~11–12 hours of play (bot estimate in [`docs/balance/report.md`](docs/balance/report.md)).
- Older characters keep their level and skill points; their progress within the level carries over (schema **v22**).

Tests: `tests/skill_numbers.gd` (15) and the bot balance probe `tests/balance_probe.gd` (8 checks; it rewrites the report).

## Sound and effects

Every region has its own music (the clearing, Thornwood's dark forest, the mystical Mirror Lake, tense Cinder Crater, Harrowmere's village tune, a sea shanty on the bridge) and a running trial switches to fight music. The mix is deliberately minimal (user feedback): sounds are quiet and short, the same sound is spaced out instead of repeating, at most four effects ring at once, distant ones fade out and the music sits under them. Strikes swoosh with a slash arc, hits flash and thud, defeated creatures vanish in smoke, Gnasher bites show a claw, Magicule pickups chime, analysis glows on its target, and level-ups, new skills, chests, evolution and buildings have their own jingles and effects. Your friends' attacks now show their attack pose on your screen too. Settings (title or pause → Options): music and effects volume, mute and reduced effects — stored on your computer only. Tests: `tests/audio_vfx.gd` (22).

## Play

Open `project.godot` in Godot 4.6.3 and press **F5** to run the project. The game opens at the **title menu**: create a **New World** (name and optional seed), **Load World** from your saves, or **Join a Friend**. In a world, move with **WASD / arrow keys** (hold **Shift** to sprint), strike with **Space / J**, absorb with **E**, use hotbar slots with **1–8** or a click, open storage with **I**, open the skill tree with **K**, press **Esc** for the pause menu (Resume, Multiplayer, Invite a Friend, Save, Save & quit to title) and **F9** to save. **T** switches mimic form, **R** retries offline or respawns a defeated hosted character. Explore as a placeholder slime; trees, rocks, water, and the map edge have collision.

The game renders at a 640 × 360 base resolution (×2 = 1280 × 720 default window, ×3 = 1920 × 1080 fullscreen), integer scaling, nearest texture filtering, and a bounded player camera. Characters, creatures, the clearing and the interface use real pixel art (see Art below). One Forest Gnasher notices you within 180 pixels, chases at 55 pixels/second, and pauses for a 0.35-second bite windup. Dodge away while it turns orange. It recovers for 0.9 seconds before attacking again. Its basic AI can collide with terrain; pathfinding is not implemented.

The player has 100 HP and 0.65-second damage immunity. Bites deal 12 damage; aura-assisted directional strikes deal **12** damage for **2 Magicules** as a Slime (Human 10 for free, Demon 14 for 4) and have a 0.4-second cooldown. A strike spends its cost even if it misses. The shared Magicule pool starts at **100**, regenerates **6 per second** after **1.5 seconds** without successful spending, and is shown as a number and bar. Unaffordable strikes fail without damage or cooldown; moving remains free so you can retreat and recover. Cooldown rejection does not spend resources or postpone recovery. Defeat stops recovery; restarting restores the pool.

The two starting enemies have 30 HP each and visible health bars. Strike range and obstruction checks prevent attacks through terrain. Defeated creatures remain available for absorption; a defeated player must restart. Naming can cause temporary sleep; current numbers are prototype balance values.

## Absorption and analysis

After defeating the Gnasher, stand within 36 pixels of its body and press **E**. Analysis costs **12 Magicules** and takes **1.2 seconds** beside an unobstructed specimen. The analysis panel shows progress; completion consumes the body and learns the **Common Skill Rending Bite**. Duplicate specimens do not stack the same learned skill. Leaving range, moving behind terrain, or being defeated interrupts analysis: its cost is spent, but the corpse remains available. Magicule drops are independent of corpse absorption.

Skill/specimen definitions live in `data/skills` and `data/specimens`. Hosted characters persist their acquired skills and materials. The initial offline sandbox remains session-local; R resets that sandbox. Hosted multiplayer/save foundations are implemented (N0); first-ally naming/evolution is implemented (M2).

## Skill hotbar and dimensional storage

Analysis learns Rending Bite; press **K** and spend a skill point to activate it. Activation fills the first free hotbar slot. Use **1** or click its button for a directional **46-damage** strike that makes the creature bleed (15 more over 3 s), costing **12 Magicules**, with a **0.8-second cooldown**. It shares attack recovery with the basic strike so alternating keys cannot bypass cooldowns. Other slots fill as you activate acquired skills or buy tree skill nodes. The hotbar shows resource costs and cooldown state, and rejects use before acquisition, after defeat, or with insufficient Magicules. A second Gnasher in the clearing lets you try the acquired skill.

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
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/sprites.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/world_art.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/ui_style.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/item_card.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/title_pause.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/world_map.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/region_content.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/audio_vfx.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/balance_systems.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/balance_persistence.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/skill_numbers.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/balance_probe.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/trade.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/region_creatures.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/travel.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/party.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/ki_realm.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/nation.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/citizens.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/jobs.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/siege.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/items.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/balance_edges.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/quests.gd
"$GODOT_BIN" --headless --path . --fixed-fps 60 --script tests/achievements.gd
python3 tests/network_integration.py
python3 tests/network_settlement.py
python3 tests/network_forms.py
python3 tests/network_trial.py
python3 tests/network_worlds.py
"$GODOT_BIN" --headless --path . --quit-after 120
```

The checks validate import, 51 local gameplay/persistence/UI/visual suites (1438 checks including the bot balance probe) and 280 real multi-process networking checks (1718 total through the bigger Ki Realm on Windows; use `python3` on Linux or `python` on Windows). These exercise movement/collision, enemy behavior, strike rules, spending failures, HUD state, delayed regeneration, depletion/recovery, invalid values, resource bounds, tier rewards, pickup proximity/overflow/obstruction, defeat, and restart. The final command runs the actual main scene for 120 frames. To play visually on a computer with a display, run `godot --path .` or use the editor; headless mode provides automated validation. A scripted visible Windows playtest is recorded in `docs/playtest/`; manual usability and real-network playtests remain pending. Networking was tested on loopback with one host plus seven simultaneous guests; real LAN/WAN connectivity and performance on your machines still need playtesting.

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

**8 players total: 1 host + 7 guests.** Every world is single player until its owner switches on **Multiplayer** in the Esc menu. **Invite a Friend** makes an invite code for one friend; they paste it into **Join a Friend** and send back their reply code; the host pastes it and they are in. That is the only way to join (M10, user decision): no ports, no IP addresses, no server provider — the world runs on the owner's computer and the codes connect the games directly (WebRTC with public STUN). The owner can let guests bring their own characters (Esc → Guests; see the overview above).

The host owns movement, combat, drops, corpse claims, skills, inventories, and world saves. Clients send validated intentions. Enemies select nearby living players; each HUD and bag belongs to its local character. One player opening inventory does not pause everyone else. R respawns a defeated character with its learned skills, inventory, level and current Magicules retained; living characters cannot use respawn to reset health.

Save locations (Godot application user-data folder):

- `user://worlds/<world name>.json`: one file per world (save slot) with its name, seed, dates and all registered character records. An older `forest.json` appears in the list as "Earlier world".
- The adjacent `.bak`: previous valid save, used if the primary is corrupt.
- `user://profiles/characters.json`: each client’s private reconnect identities. Keep this file on that player’s machine; do not commit or share it. Losing it requires a new character rather than claiming another character’s ID.

Hosting loads the world if it exists; invalid saves with no valid backup are preserved and hosting stops. Saves use a versioned schema, validation, a temporary file and atomic rename. Saving happens on important reward/inventory/defeat changes, guest join/disconnect, **F9**, every **15 seconds**, and normal window close. A force-killed process can restore only its last completed save. Offline characters stop simulating. Disconnected or reloaded analysis channels are interrupted with no cost refund; their unconsumed corpse remains available.

Current saves cover stable world/character/entity IDs, positions/facing, implemented stats, HP and Magicules/recovery timers, learned skills/loadout, materials/capacity, attack recovery, enemy state, and remaining pickups. Character progression dictionaries include level/experience/race and reserved personal quest/equipment state; shared progression holds world time and quest/settlement dictionaries. XP, levels and unspent skill points are implemented; equipment and personal quest mechanics remain planned. The shared camp implements settlement founding, gathering, structures and ally work, while broader settlement progression remains planned. Each later feature must extend the validated schema rather than fabricate sample progression.

Developer builds (the editor and the network tests) still accept `--host`, `--join=<address>` and `--server` as a test harness over ENet; exported games ignore them.

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

After your character has analyzed a Forest Gnasher, press **T** to take **Gnasher Form** for **20 Magicules**: you move 30% faster and your basic strike deals 4 more damage (16 instead of 12). Skills keep their own damage. Press **T** again to turn back into a slime for free. Changing form has a 2-second cooldown, shown next to the form name in the HUD. The Gnasher body is slightly larger, so you need a little room away from walls to transform; if there is none, nothing is charged. Transforming never restores HP or Magicules and is impossible while asleep, defeated or in a menu. Defeat always turns you back into a slime. Each character's form is saved (schema **v9**; older characters start as slimes) and every player sees it. Tests: `tests/mimic_form.gd` (30) and `python3 tests/network_forms.py` (17 real-process checks).

## Proving Trial and the first Unique skill (placeholder story)

*The trial's name, texts and look are placeholders until the storyline is written.*

A stone stands in the north at **(480, 100)**. Once your character knows **Piercing Fang**, stand at the stone and press **F** to begin the **Proving Trial**: three trial creatures appear, and you have **60 seconds** to defeat them all while staying inside the faint circle. A banner at the top shows the creatures left and the time. Other players may help, but **only the character who started the trial is credited**. The trial fails if you are defeated, leave the circle, disconnect or run out of time, and you can simply try again. Trial creatures drop nothing and cannot be analyzed. A trial in progress is not saved: a host restart cancels it.

Completing it teaches the first **Unique** skill, **Predator Focus** (placeholder name), which goes into the new **4th hotbar slot (key 4)**. It costs 25 Magicules: your **next analysis within 20 seconds** reaches twice as far (72 px) and completes in 0.3 s instead of 1.2 s. It is used up when that analysis begins, so interrupting it gives nothing back, and it cannot be stacked. **Ultimate** skills stay locked until an ascension exists (planned for M6). Schema **v10** stores the fourth slot and an armed focus. Tests: `tests/trial_unique.gd` (40) and `python3 tests/network_trial.py` (22 real-process checks).

## Art

Characters and creatures use real pixel-art sprites (step 19): the Slime, Human and Demon walk, idle, attack and fall in four directions; Gnashers, Thornbacks, your goblin ally and the evolved Hobgoblin run and idle and play a death animation. Mimic forms show the creature's body in your own colours, Elite creatures are reddish and a little larger, and a Gnasher flashes red right before it bites. The clearing itself uses real tiles and props (step 20): grass, dirt roads, the pond, trees and boulders, the hut, storehouse, shrine, forge and campfire, deposits and chests; you walk behind tree canopies and buildings. The HUD and every window use one dark/gold theme after the reference (step 21): a status card with your portrait and HP, Magicule and XP bars, the cyan analysis box, a framed hotbar with key badges, and item/gear icons in the bag and equipment window. The title screen (step 22) has a storm backdrop, the logo and an ornamented menu with a slime marking your choice: **Continue** opens the world you played last (damaged saves are skipped), plus New Game, Load Game, Join a Friend, **Settings** (fullscreen, window size — saved on this computer only), **Credits** and Quit. **Esc** in a world opens the pause overlay: Resume, shortcuts into the bag/equipment, skill tree and fusion (closing them returns to the pause menu), Multiplayer, Invite a Friend, Guests, Save, Options and Save & quit, next to a card with your character and world (HP, Magicules, level, zone, world, map, players, world time). Windows and menus use ornamented gold frames (Kenney Fantasy UI Borders). Gear details are item cards (step 21b): framed in the rarity colour with badges, DPS and attack speed for weapons, green bonuses and red penalties with their roll ranges, passives and the active; hover an item or a worn slot to preview it. Art credits: `CREDITS.md`. Tests: `tests/sprites.gd` (24), `tests/world_art.gd` (16), `tests/ui_style.gd` (17), `tests/item_card.gd` (15), `tests/title_pause.gd` (31).

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
- **Human** — HP 120, Magicules 70. **Weapon mastery:** free basic strikes (10 damage) and every attack recovers 25% faster.
- **Demon** — HP 90, Magicules 130, a little faster. **Dark affinity:** skills deal 25% more damage and drain 20% of the damage dealt back as HP.

Everyone can absorb creatures and learn their skills; Humans and Demons just take longer (1.8 s instead of 1.2 s) and heal half as much from it. **Mimicry** comes to every race: Slimes from level 1, Demons from level 5, Humans only at the endgame (level 20). **Naming** an ally costs **80% of your maximum Magicules** (Slime 80, Human 56, Demon 104), so every race can name its first ally. Your race is kept with your character in that world. The art is placeholder until the sprite step. Tests: `tests/races.gd` (30).

## Experience and levels

You earn **XP** for defeating creatures (in the clearing Easy 13, Standard 21, Elite 40; more for higher-level creatures elsewhere), for every completed **absorption** (half of that) and for completing the **trial** (1500). Levels need 100, 696, 2167, 4850 … total XP, up to **level 20** for now (step 24b). Each level (level 1 included) gives **one skill point** for the skill tree (K). The top-right of the HUD shows your level, XP toward the next level and unspent points, and the System Voice announces level-ups. Only the player who earns XP gets it; trial creatures give no XP of their own. Saved with your character (schema **v14**). Tests: `tests/leveling.gd` (29).

## Healing: absorbed vitality

Hit points do not regenerate on their own. Completing an **absorption** heals you gradually over **10 seconds**, depending on the creature: **Easy 15 HP, Standard 25 HP, Elite 40 HP** (the Thornback is Standard). The HP display shows "+ healing" while it runs. A new absorption only replaces a running heal if it would restore more, healing never exceeds your maximum, and it stops if you are defeated. Trial creatures cannot be absorbed, so trials cannot be used to heal. Running heals are saved (schema **v11**). Tests: `tests/absorb_healing.gd` (21).

## Worlds, save slots and playing with friends

The title menu lists every saved world with its **name, seed and last-played date**; damaged files are shown as damaged instead of disappearing. **New World** asks for a name and a seed: leave the seed empty for a random one, type a number to use it directly, or type any text (it is turned into a number, like in Minecraft). The seed shapes the world: where the wood and stone piles are (and how rich the outlying ones are), where creatures wait and how strong they are, where the trial stone and the goblin start, and where trees and rocks grow. Roads, the pond, the camp and your spawn are always the same, and every place stays reachable on foot. The same seed always gives the same world, and friends who join see exactly what you see. Seed **0** is the original hand-made map; worlds saved before seeds existed keep it and show "original map". Tests: `tests/seeded_worlds.gd` (36). Each world gets its own file, so two worlds with the same name get separate slots.

**Every world is always saved.** Playing alone means you host the world without opening anything on the network (no firewall prompt). Press **Esc** for the pause menu: playing alone, it freezes the world; with friends connected, it only stops your own character. **Multiplayer** opens the running world to invite codes without a restart (M10: the only way to join) and switches back to single player. **Save & quit to title** saves and ends the session; joined players see **Leave to title** instead. When you load the world again it starts solo, and your friends' characters are kept, so they rejoin as themselves after you open it again. Command-line `--host` / `--join` remain only in developer builds (tests). Tests: `tests/worlds_menu.gd` (37) and `python3 tests/network_worlds.py` (18 real-process checks).
