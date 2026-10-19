extends RefCounted
## Quests (M9c, user decisions in docs/M4_PLAN.md M9): the main story "The Shattered Moon", one-time
## side quests from quest givers in the towns and villages, and repeatable bounties on each town's
## board. Pure data and rules; QuestLog runs them on the host.
##
## A quest is a list of steps done in order; when the last one is done the quest completes and pays
## out. Step types:
##   talk   {npc}                  — talk to someone (dialogue "say")
##   bring  {item, count}          — hand items to the quest's giver (taken when you talk to them)
##   kill   {kind, region, count}  — defeat creatures (kind and/or region may be "")
##   boss   {id}                   — take part in defeating a boss (raid, elite or dungeon boss)
##   reach  {tile, radius}         — stand near a place (tiles)
##   camp   {}                     — reach the camp site in the First Clearing
##   dungeon {id}                  — go down into a dungeon
##   night  {}                     — live through a night (see darkness fall, then dawn)
##   catch  {fish, count}          — land fish ("" = any)
##   gather {resource, count}      — gather logs, ores or herbs ("" = any)
##   craft  {item, count}          — craft (smelt, forge, brew) something ("" = anything)
##   choice {npc, options}         — decide (M9d: the story's ending); options [[label, key, reward, say]]
const MAP := preload("res://scripts/world/world_map.gd")

## Story characters and quest givers: [name, sprite, town ("" = fixed tile, "dungeon:<id>" = that
## dungeon's deepest chamber), tile offset from the town's plaza (or the tile itself), staged].
## Staged characters (the Court's) only show — and can only be spoken to — while one of your
## quests waits for you to talk to them.
const NPCS := {
    "orrin": ["Orrin the Astronomer", "npc_orrin", "brookhaven", Vector2(-3, 1.5)],
    "hilde": ["Hilde the Baker", "npc_hilde", "brookhaven", Vector2(-1, 3)],
    "rowan": ["Old Rowan", "npc_rowan", "thornhollow", Vector2(-2, 1)],
    "nessa": ["Nessa the Fisher", "npc_nessa", "mirrorwick", Vector2(-2, 1)],
    "maren": ["Captain Maren", "npc_maren", "harrowmere", Vector2(-3, 1.5)],
    "alric": ["Brother Alric", "npc_alric", "harrowmere", Vector2(-1, 3)],
    "vex": ["Vex of the Eclipse Court", "npc_vex", "", Vector2(246, 70), true],
    "vex_grotto": ["Vex of the Eclipse Court", "npc_vex", "dungeon:jade_grotto", Vector2(2, 2), true],
    "regent": ["The Pale Regent", "npc_regent", "dungeon:ember_depths", Vector2(0, 2), true],
    "regent_spire": ["The Pale Regent", "npc_regent", "", Vector2(-760, -94), true],
    "ulla": ["Chief Ulla", "npc_ulla", "rimeholm", Vector2(-3, 1.5)],
    "steward": ["The Sultan's Steward", "npc_steward", "dunemarch", Vector2(-3, 1.5)],
    "bram": ["Farmer Bram", "npc_bram", "amberhold", Vector2(-3, 1.5)],
    "moss": ["Mother Moss", "npc_moss", "bogsend", Vector2(-3, 1.5)],
    "kaito": ["Sensei Kaito", "npc_kaito", "hanamura", Vector2(-3, 1.5)],
    "ignis": ["Forgemaster Ignis", "npc_ignis", "cinderport", Vector2(-3, 1.5)],
    "temur": ["Khan Temur", "npc_temur", "galehaven", Vector2(-3, 1.5)],
    "morwen": ["Morwen of Witchwood", "npc_morwen", "gloomhollow", Vector2(-3, 1.5)],
    "lin": ["Sage Lin", "npc_lin", "highwind", Vector2(-3, 1.5)],
    # M9d: more quest givers.
    "inspector": ["Inspector Holt", "npc_inspector", "saltwick", Vector2(-2, 1)],
    "princess": ["Princess Sora", "npc_princess", "hanamura", Vector2(-1, 3)],
    "hunter": ["Huntress Kesh", "npc_hunter", "galehaven", Vector2(-1, 3)],
}
## Lumi travels with you (no place of its own); "talk" steps with Lumi complete when its words are read.
const LUMI := "lumi"
const LUMI_NAME := "Lumi"
## Towns with a bounty board (left of the plaza's north side).
const BOARD_OFFSET := Vector2(-3, -1.5)
const BOARD_TOWNS := ["brookhaven", "harrowmere", "rimeholm", "dunemarch", "bogsend", "amberhold", "cinderport", "hanamura", "galehaven", "gloomhollow", "highwind", "dome_city"]
## How far (px) a character must stand to talk to someone or read a board.
const TALK_REACH := 34.0
## Bounties come back one game day after they were turned in.
const BOUNTY_SECONDS := 1440.0

const QUESTS := {
    # --- Main story: The Shattered Moon.
    "main_0": {"title": "The Night the Sky Fell", "kind": "main", "giver": "lumi", "level": 1, "requires": [],
        "intro": [["Lumi", "You're awake! Easy now — the sea threw you onto this shore. I'm Lumi. I fell from the sky too, long ago... and lately something keeps calling me. Something broken."]],
        "steps": [
            {"type": "kill", "kind": "", "region": "", "count": 3, "text": "Defend yourself: defeat 3 creatures around the clearing", "say": [["Lumi", "Not bad for someone who can't remember their own name!"]]},
            {"type": "camp", "text": "Make camp before dark: reach the camp site in the clearing", "say": [["Lumi", "A fire, a roof... it's a start. Now — do you feel how fast the light is fading?"]]},
            {"type": "night", "text": "Live through your first night (from dusk until dawn)", "say": [["Lumi", "So dark... The nights weren't always like this. Not before the moon broke. The call comes from the west — from a town with a tower full of glass."]]},
            {"type": "talk", "npc": "orrin", "text": "Follow Lumi's pull to Brookhaven and find the astronomer Orrin", "say": [["Orrin the Astronomer", "A star-sprite! By the old charts... then the stories are true. Come in, come in — and mind the broken lens."]]},
        ],
        "reward": {"xp": 250, "zeni": 150, "gear": 1}},
    "main_1": {"title": "Lanterns of Brookhaven", "kind": "main", "giver": "orrin", "level": 3, "requires": ["main_0"],
        "intro": [["Orrin the Astronomer", "Ten years ago the moon cracked like an egg, and its pieces — the Moonshards — rained down on us. Your little friend can feel them. One fell in Thornwood, I'm sure of it: the creatures there have gone mad. But first my telescope — its frame is rotten through."]],
        "steps": [
            {"type": "bring", "item": "log_oak", "count": 3, "text": "Bring Orrin 3 Oak Logs (F at a tree)"},
            {"type": "bring", "item": "ore_copper", "count": 2, "text": "Bring Orrin 2 Copper Ore (F at an ore rock)", "say": [["Orrin the Astronomer", "Splendid! Now look — there, over Thornwood, the stars bend. Something down there is drinking their light."]]},
            {"type": "kill", "kind": "", "region": "Thornwood", "count": 6, "text": "Calm the maddened creatures of Thornwood (6)"},
            {"type": "dungeon", "id": "thornwood_hollow", "text": "Find the source: go down into Thornwood Hollow (the cave mouth in western Thornwood)"},
            {"type": "boss", "id": "dungeon_thornwood_hollow", "text": "Defeat Rootmaw, the Rotting King", "say": [["Lumi", "There — under the roots! It's glowing... a Moonshard! And this... a mask with a black sun on it?"]]},
            {"type": "talk", "npc": "orrin", "text": "Bring the Moonshard to Orrin", "say": [["Orrin the Astronomer", "The Eclipse Court. I prayed they were only a rumour. They gather the shards to keep the nights dark forever — and whoever holds the night holds the monsters. We must find the others first."]]},
        ],
        "reward": {"xp": 1500, "zeni": 600, "gear": 2}},
    "main_2": {"title": "The Keep in the Lake", "kind": "main", "giver": "orrin", "level": 8, "requires": ["main_1"],
        "intro": [["Orrin the Astronomer", "My old friend Captain Maren of Harrowmere writes of masked strangers rowing to Lakeward Keep by night, with lanterns that give no light. Go to her."]],
        "steps": [
            {"type": "talk", "npc": "maren", "text": "Speak with Captain Maren in Harrowmere", "say": [["Captain Maren", "Masks, lanterns that drink the light, singing at midnight. My guards won't go near that keep. You will? Then take the bridge to the islet — and be careful."]]},
            {"type": "reach", "tile": Vector2(246, 70), "radius": 8, "text": "Cross to Lakeward Keep on Mirror Lake's islet"},
            {"type": "kill", "kind": "thornback", "region": "", "count": 4, "text": "Break through the Court's beasts (4 Thornbacks)"},
            {"type": "boss", "id": "boss_quillback", "text": "Defeat Old Croaker, poisoned by the night lantern"},
            {"type": "talk", "npc": "vex", "text": "Confront the masked captain in the keep", "say": [["Vex of the Eclipse Court", "Too late, little castaway. The Pale Regent already holds three shards. Keep this one — for now. When the long night comes, remember my face."], ["Lumi", "He's gone... but he left the shard! Two, now. Let's get it to Orrin."]]},
            {"type": "talk", "npc": "orrin", "text": "Bring the second Moonshard to Orrin", "say": [["Orrin the Astronomer", "Three with the Regent, two with us. The race has truly begun. Rest a while — the road beyond the sea is long, and the frost clans and the desert will not wait."]]},
        ],
        "reward": {"xp": 6000, "zeni": 1500, "gear": 3}},
    "main_3": {"title": "Frost and Dust", "kind": "main", "giver": "orrin", "level": 12, "requires": ["main_2"],
        "intro": [["Orrin the Astronomer", "Two shards fell far apart: one into the ice above Rimeholm, one into the southern sands. Lumi trembles whenever I point the lens at either. Go north first — the frost clans know every cave."]],
        "steps": [
            {"type": "talk", "npc": "ulla", "text": "Ask Chief Ulla in Rimeholm about the cold light", "say": [["Chief Ulla", "A blue fire burns inside Frostfang Cavern since the sky broke. The cyclops there has grown fat on it. Take the east path past Glacierwatch."]]},
            {"type": "dungeon", "id": "frostfang_cavern", "text": "Climb down into Frostfang Cavern (east of Rimeholm)"},
            {"type": "boss", "id": "dungeon_frostfang_cavern", "text": "Defeat Frostfang, the Ice Cyclops", "say": [["Lumi", "The third shard! It's so cold it burns... Now the desert. I can hear the other one singing under the sand."]]},
            {"type": "talk", "npc": "steward", "text": "Travel to Dunemarch and speak with the Sultan's Steward", "say": [["The Sultan's Steward", "A falling star? Yes — it fell where the Dune Stalker hunts. Our riders will not go there. The Sultan would be... grateful."]]},
            {"type": "boss", "id": "elite_dune_stalker", "text": "Hunt the Dune Stalker in the southern sands", "say": [["Lumi", "Four! It was in its belly the whole time. Ugh. Let's never do that again."]]},
            {"type": "talk", "npc": "orrin", "text": "Bring both Moonshards to Orrin", "say": [["Orrin the Astronomer", "Four shards. Four! And the Court has three... Their ships were seen sailing for the Emberreach Isles. Whatever they search for there, we must reach it first."]]},
        ],
        "reward": {"xp": 30000, "zeni": 3000, "gear": 3}},
    "main_4": {"title": "The Tidebound Isles", "kind": "main", "giver": "orrin", "level": 15, "requires": ["main_3"],
        "intro": [["Orrin the Astronomer", "Forgemaster Ignis of Cinderport is an old friend and a grumpy one. If the Court is digging in his isles, he will know where. Take ship from the harbour — and keep Lumi close."]],
        "steps": [
            {"type": "talk", "npc": "ignis", "text": "Sail to Cinderport and find Forgemaster Ignis", "say": [["Forgemaster Ignis", "Masked fools have been carting lava salamanders into the Ember Depths for a week. My forge has gone cold from the fear in the air. Clear the isles and I'll show you the way down."]]},
            {"type": "kill", "kind": "", "region": "Emberreach Isles", "count": 10, "text": "Clear the Court's beasts from the Emberreach Isles (10)"},
            {"type": "dungeon", "id": "ember_depths", "text": "Go down into the Ember Depths"},
            {"type": "boss", "id": "dungeon_ember_depths", "text": "Defeat Magmaw, the Lava Wyrm", "say": [["Lumi", "The fifth shard is right there in the lava — wait. Someone's coming. I can't... I can't see..."]]},
            {"type": "talk", "npc": "regent", "text": "Face the pale figure in the deepest chamber", "say": [["The Pale Regent", "So this is the castaway Vex warned me about. You fight well for someone without a past. The shard is mine, as is the little star's light. Sleep, sprite."], ["Lumi", "...so... dim... I'm still here. Just... tired. Don't let him... have the rest..."]]},
            {"type": "talk", "npc": "orrin", "text": "Bring the dimmed Lumi back to Orrin", "say": [["Orrin the Astronomer", "He drank her light. The Regent holds four shards now, and we hold four. But the star-readers of the Goldwind Steppe once rekindled a fallen star — so the old charts say. Go east."]]},
        ],
        "reward": {"xp": 50000, "zeni": 5000, "gear": 3}},
    "main_5": {"title": "Where the Wind Turns Gold", "kind": "main", "giver": "orrin", "level": 22, "requires": ["main_4"],
        "intro": [["Orrin the Astronomer", "The ferry to the Eastern Reaches leaves from the far harbours. Find Khan Temur in Galehaven: his clans still keep the star-readers' songs."]],
        "steps": [
            {"type": "talk", "npc": "temur", "text": "Take the ferry east and find Khan Temur in Galehaven", "say": [["Khan Temur", "A dimmed star-sprite... The readers sing to such stars on the steppe at night. But the storm spirits answer the Court now. Silence them, and the readers will sing."]]},
            {"type": "kill", "kind": "", "region": "Goldwind Steppe", "count": 12, "text": "Silence the storm spirits of the Goldwind Steppe (12)"},
            {"type": "night", "text": "Spend a night on the steppe while the star-readers sing", "say": [["Lumi", "...warm. I can feel the stars again! I'm back — and I'm SO angry. There's a shard south of here, in the purple dark. The Regent left it with someone."]]},
            {"type": "talk", "npc": "morwen", "text": "Go south into Gloomveil and find Morwen in Gloomhollow", "say": [["Morwen of Witchwood", "The Bone Abbot keeps the Regent's shard in his catacombs, under the dusk that never lifts. I hate that monk. Kill him and I'll call it even."]]},
            {"type": "dungeon", "id": "gloom_catacombs", "text": "Go down into the Gloom Catacombs"},
            {"type": "boss", "id": "dungeon_gloom_catacombs", "text": "Defeat the Bone Abbot", "say": [["Lumi", "The sixth shard — and it's one of HIS. Five for us now, and three for him. Sage Lin of Jadehaven knows the old observatory... that's where the last one points."]]},
            {"type": "talk", "npc": "lin", "text": "Bring the shards to Sage Lin in Jadehaven", "say": [["Sage Lin", "Five shards in a castaway's pack, and a star-sprite angry enough to light a city. Rest. The Jade Observatory has been silent for a hundred years — and now its lens moves at night."]]},
        ],
        "reward": {"xp": 90000, "zeni": 9000, "gear": 4}},
    "main_6": {"title": "The Jade Observatory", "kind": "main", "giver": "lin", "level": 34, "requires": ["main_5"],
        "intro": [["Sage Lin", "The observatory's lens points down into the Jade Grotto. Something there pulls at the sky. Go carefully: the Court will be waiting."]],
        "steps": [
            {"type": "kill", "kind": "", "region": "Jade Terraces", "count": 12, "text": "Fight your way across the Jade Terraces (12)"},
            {"type": "dungeon", "id": "jade_grotto", "text": "Go down into the Jade Grotto"},
            {"type": "boss", "id": "dungeon_jade_grotto", "text": "Defeat the Jade Spirit Guardian", "say": [["Lumi", "It was guarding... nothing. The shard is gone. Someone took it — just now."]]},
            {"type": "talk", "npc": "vex_grotto", "text": "Confront Vex in the grotto's heart", "say": [["Vex of the Eclipse Court", "Sorry, castaway. The last shard is already on its way to the Regent. Want to know a secret? The moon's broken core never fell to the world — it fell into the hidden realm, onto the Sage Spire. That's where he's going."], ["Lumi", "He let us go again. He wants us there. Let's not disappoint him."]]},
            {"type": "talk", "npc": "lin", "text": "Tell Sage Lin what Vex said", "say": [["Sage Lin", "The Ki Realm... Few ever find the way: a hermit in Sakura Vale asks a single question. Answer truly, and he opens the path. You will need to be strong."]]},
        ],
        "reward": {"xp": 110000, "zeni": 12000, "gear": 4}},
    "main_7": {"title": "The Pale Regent", "kind": "main", "giver": "lin", "level": 40, "requires": ["main_6"],
        "intro": [["Sage Lin", "Go. Whatever you find on that spire, remember: you chose to walk this road, memories or not."]],
        "steps": [
            {"type": "reach", "tile": Vector2(-894, 66), "radius": 12, "text": "Find the way into the hidden Ki Realm (the hermit in Sakura Vale)", "say": [["Lumi", "This place hums with power. The core is close — up there, on the spire."]]},
            {"type": "reach", "tile": Vector2(-760, -95), "radius": 6, "text": "Climb to the foot of the Sage Spire"},
            {"type": "talk", "npc": "regent_spire", "text": "Face the Pale Regent beneath the Sage Spire", "say": [["The Pale Regent", "Ten years I chased the pieces of a broken sky. With the core and my four shards, I will be the night itself. Watch, castaway."], ["Lumi", "He's... changing! That's not a man any more!"]]},
            {"type": "boss", "id": "boss_eclipse_wyrm", "text": "Defeat the Eclipse Wyrm", "say": [["Lumi", "It's over. His shards are scattered on the stones — all seven, and the core between them. It's warm. It's waiting for someone to decide."]]},
            {"type": "choice", "npc": "lumi", "text": "Decide what becomes of the moon's core (open the quest log, O, if you closed it)",
                "options": [
                    ["Mend the moon: give the shards back to the sky (Moonwarden)", "moonwarden", {"unique": "story_moonwarden_crescent"}, [["Lumi", "Then let's give them back. ...I'll go with them, you know. Someone has to hold the pieces together. Don't look like that — every night, look up. I'll be the bright bit."], ["Lumi", "Thank you, Moonwarden. For all of it."]]],
                    ["Keep the core's power for yourself (Eclipse Sovereign)", "sovereign", {"unique": "story_eclipse_reaper"}, [["Lumi", "...You'd keep it? I understand. Someone has to be stronger than the dark — maybe that's you. Just... promise you'll remember who you were before."], ["Lumi", "The night is yours now, Sovereign. Try to be kind with it."]]],
                ]},
        ],
        "reward": {"xp": 150000, "zeni": 30000, "gear": 5}},
    # --- Side quests (one time each).
    "side_bread": {"title": "Bread for the Lantern Festival", "kind": "side", "giver": "hilde", "level": 2, "requires": [],
        "intro": [["Hilde the Baker", "The Lantern Festival is in three days and I've no mint for the honey bread! Bushes all around the clearing have it — just pick it, dear."]],
        "steps": [{"type": "bring", "item": "herb_mint", "count": 4, "text": "Bring Hilde 4 Meadow Mint (F at a bush)", "say": [["Hilde the Baker", "Oh, it smells like summer! Take a few draughts — my sister brews them."]]}],
        "reward": {"xp": 200, "zeni": 120, "items": {"healing_draught": 2}}},
    "side_larder": {"title": "A Thief in the Larder", "kind": "side", "giver": "hilde", "level": 3, "requires": ["side_bread"],
        "intro": [["Hilde the Baker", "Something's been at my sacks every night. Little claw marks, greedy little teeth... Gnashers! Would you thin them out?"]],
        "steps": [{"type": "kill", "kind": "gnasher", "region": "", "count": 5, "text": "Defeat 5 Gnashers"}, {"type": "talk", "npc": "hilde", "text": "Tell Hilde her larder is safe", "say": [["Hilde the Baker", "Bless you! The festival is saved."]]}],
        "reward": {"xp": 300, "zeni": 160}},
    "side_axe": {"title": "Old Rowan's Axe", "kind": "side", "giver": "rowan", "level": 3, "requires": [],
        "intro": [["Old Rowan", "My arms are too old for the axe now, but the village still needs wood for winter. Chop me ten oak logs and I'll teach you a trick or two."]],
        "steps": [{"type": "gather", "resource": "log_oak", "count": 10, "text": "Chop 10 Oak Logs"}, {"type": "talk", "npc": "rowan", "text": "Show Old Rowan your work", "say": [["Old Rowan", "Clean cuts. Let the axe fall, don't push it — there, you have it."]]}],
        "reward": {"xp": 350, "zeni": 200, "pro": {"woodcutting": 500}}},
    "side_quills": {"title": "The Quill Den", "kind": "side", "giver": "rowan", "level": 5, "requires": ["side_axe"],
        "intro": [["Old Rowan", "Thornbacks have made a den east of here. They shred the young trees. Drive them off."]],
        "steps": [{"type": "kill", "kind": "thornback", "region": "", "count": 3, "text": "Defeat 3 Thornbacks"}, {"type": "talk", "npc": "rowan", "text": "Return to Old Rowan", "say": [["Old Rowan", "The saplings thank you. So do my old bones."]]}],
        "reward": {"xp": 500, "zeni": 260, "gear": 1}},
    "side_rival": {"title": "Nessa's Rival", "kind": "side", "giver": "nessa", "level": 3, "requires": [],
        "intro": [["Nessa the Fisher", "Old Bertil swears he caught three lake trout in a morning. Three! Catch me three and I'll shut his mouth for good."]],
        "steps": [{"type": "catch", "fish": "trout", "count": 3, "text": "Catch 3 Lake Trout (a rod, F at a lake)"}, {"type": "talk", "npc": "nessa", "text": "Bring the catch to Nessa", "say": [["Nessa the Fisher", "Ha! Wait till Bertil sees these. Here — a fisher's secret: patience, and a wet line."]]}],
        "reward": {"xp": 300, "zeni": 220, "pro": {"fishing": 400}}},
    "side_nightglow": {"title": "Night Lights on the Lake", "kind": "side", "giver": "nessa", "level": 5, "requires": ["side_rival"],
        "intro": [["Nessa the Fisher", "On dark nights little lights dance under the water. My grandmother called them nightglow minnows. I've never caught one."]],
        "steps": [{"type": "catch", "fish": "nightglow_minnow", "count": 1, "text": "Catch a Nightglow Minnow (only at night)"}, {"type": "talk", "npc": "nessa", "text": "Show Nessa the Nightglow Minnow", "say": [["Nessa the Fisher", "It's real... It glows like a tiny lantern. Thank you."]]}],
        "reward": {"xp": 600, "zeni": 450}},
    "side_candles": {"title": "Candles for the Chapel", "kind": "side", "giver": "alric", "level": 6, "requires": [],
        "intro": [["Brother Alric", "The sick come to our chapel every night now. Healing draughts are worth more than prayers. Could you brew two?"]],
        "steps": [{"type": "craft", "item": "healing_draught", "count": 2, "text": "Brew 2 Healing Draughts (Alchemy, in a town)"}, {"type": "bring", "item": "healing_draught", "count": 2, "text": "Bring Brother Alric 2 Healing Draughts", "say": [["Brother Alric", "They will sleep easier tonight. Blessings on your hands."]]}],
        "reward": {"xp": 700, "zeni": 320, "pro": {"alchemy": 500}}},
    "side_oakfang": {"title": "The Beast of Thornwood", "kind": "side", "giver": "maren", "level": 9, "requires": [],
        "intro": [["Captain Maren", "Woodcutters speak of a Gnasher as big as a cart — they call it Old Oakfang. Hunt it before it hunts them."]],
        "steps": [{"type": "boss", "id": "elite_oakfang", "text": "Defeat Old Oakfang, hidden in Thornwood"}, {"type": "talk", "npc": "maren", "text": "Report to Captain Maren", "say": [["Captain Maren", "Old Oakfang, dead? The woodcutters will drink to you for a month."]]}],
        "reward": {"xp": 1500, "zeni": 800, "gear": 2}},
    "side_furs": {"title": "Furs for the Winter", "kind": "side", "giver": "ulla", "level": 11, "requires": [],
        "intro": [["Chief Ulla", "The winter never ends up here since the sky broke. The children need furs. Frost bears have the warmest."]],
        "steps": [{"type": "bring", "item": "frost_pelt", "count": 3, "text": "Bring Chief Ulla 3 Frost Pelts (absorb frost bears)", "say": [["Chief Ulla", "Warm as a hearth. Rimeholm will not forget this."]]}],
        "reward": {"xp": 1200, "zeni": 650}},
    "side_caravan": {"title": "The Sultan's Lost Caravan", "kind": "side", "giver": "steward", "level": 10, "requires": [],
        "intro": [["The Sultan's Steward", "A caravan of the Sultan vanished in the southern dunes. Vipers, the guides say. Find what is left of it."]],
        "steps": [{"type": "reach", "tile": Vector2(-280, 140), "radius": 8, "text": "Search the southern dunes for the caravan"}, {"type": "kill", "kind": "dune_viper", "region": "", "count": 4, "text": "Defeat 4 Dune Vipers"}, {"type": "talk", "npc": "steward", "text": "Report to the Sultan's Steward", "say": [["The Sultan's Steward", "So the sands keep what they take. The Sultan rewards honesty."]]}],
        "reward": {"xp": 1400, "zeni": 900}},
    "side_orchard": {"title": "Owls in the Orchard", "kind": "side", "giver": "bram", "level": 13, "requires": [],
        "intro": [["Farmer Bram", "Owls as big as dogs, eating my apples AND my chickens. Four of them roost in the orchard."]],
        "steps": [{"type": "kill", "kind": "amber_owl", "region": "", "count": 4, "text": "Defeat 4 Amber Owls"}, {"type": "talk", "npc": "bram", "text": "Tell Farmer Bram", "say": [["Farmer Bram", "Peace at last! Take this, and a basket of apples if you like."]]}],
        "reward": {"xp": 1600, "zeni": 900}},
    "side_brew": {"title": "Mother Moss's Brew", "kind": "side", "giver": "moss", "level": 15, "requires": [],
        "intro": [["Mother Moss", "Mirecap spores, child. Three of them. The marsh fever is spreading and my brew needs them."]],
        "steps": [{"type": "bring", "item": "mirecap_spore", "count": 3, "text": "Bring Mother Moss 3 Mirecap Spores (absorb mirecaps)", "say": [["Mother Moss", "Hm-hm. Good spores, fat ones. The fever will break."]]}],
        "reward": {"xp": 1700, "zeni": 850, "pro": {"alchemy": 1200}}},
    "side_ronin": {"title": "The Ronin's Challenge", "kind": "side", "giver": "kaito", "level": 16, "requires": [],
        "intro": [["Sensei Kaito", "A masterless warrior haunts the bamboo — the Bamboo Ronin. He defeated my best student. Prove your blade."]],
        "steps": [{"type": "boss", "id": "elite_bamboo_ronin", "text": "Defeat the Bamboo Ronin"}, {"type": "talk", "npc": "kaito", "text": "Return to Sensei Kaito", "say": [["Sensei Kaito", "Then the bamboo is quiet again. You have the stillness of a true swordsman."]]}],
        "reward": {"xp": 4000, "zeni": 2000, "gear": 3}},
    "side_fuel": {"title": "Fuel for the Forge", "kind": "side", "giver": "ignis", "level": 15, "requires": [],
        "intro": [["Forgemaster Ignis", "My forge eats coal like a dragon. Six lumps and I'll show you how a real smith heats steel."]],
        "steps": [{"type": "bring", "item": "ore_coal", "count": 6, "text": "Bring Forgemaster Ignis 6 Coal", "say": [["Forgemaster Ignis", "Ha! Now watch the colour of the metal, not the flame."]]}],
        "reward": {"xp": 2500, "zeni": 1200, "pro": {"smithing": 1500}}},
    "side_storm_eye": {"title": "The Eye Above the Steppe", "kind": "side", "giver": "temur", "level": 24, "requires": [],
        "intro": [["Khan Temur", "A great eye watches our herds from the storm clouds, and the horses go mad. My riders fear it. You do not?"]],
        "steps": [{"type": "boss", "id": "elite_storm_eye", "text": "Defeat the Storm Eye"}, {"type": "talk", "npc": "temur", "text": "Return to Khan Temur", "say": [["Khan Temur", "The herds are calm. Ride with us whenever you wish, friend of the clans."]]}],
        "reward": {"xp": 15000, "zeni": 5000, "gear": 3}},
    "side_nightshade": {"title": "Nightshade for the Witch", "kind": "side", "giver": "morwen", "level": 28, "requires": [],
        "intro": [["Morwen of Witchwood", "They call me a witch and then come begging for cures. Fine. Bring me five nightshade and I'll keep curing them."]],
        "steps": [{"type": "bring", "item": "herb_nightshade", "count": 5, "text": "Bring Morwen 5 Nightshade (Alchemy, Gloomveil's bushes)", "say": [["Morwen of Witchwood", "Fresh. Good. You're less useless than most."]]}],
        "reward": {"xp": 18000, "zeni": 5500, "pro": {"alchemy": 4000}}},
    "side_mist_carp": {"title": "Mist Over the Paddies", "kind": "side", "giver": "lin", "level": 34, "requires": [],
        "intro": [["Sage Lin", "When the mist lies on the paddies, the mist carp rise. The old ones say seeing one brings a good harvest."]],
        "steps": [{"type": "catch", "fish": "mist_carp", "count": 1, "text": "Catch a Mist Carp (only in fog or mist)"}, {"type": "talk", "npc": "lin", "text": "Show Sage Lin the Mist Carp", "say": [["Sage Lin", "A fine omen. May your harvest — whatever you sow — be full."]]}],
        "reward": {"xp": 30000, "zeni": 8000, "pro": {"fishing": 6000}}},
    # M9d: more side quests (about forty in all).
    "side_oven": {"title": "A New Oven Door", "kind": "side", "giver": "hilde", "level": 5, "requires": ["side_larder"],
        "intro": [["Hilde the Baker", "My oven door finally fell off. Two bronze bars would make a new one — the smith's furnace is in every town."]],
        "steps": [{"type": "craft", "item": "bar_bronze", "count": 2, "text": "Smelt 2 Bronze Bars (Smithing, in a town)"}, {"type": "bring", "item": "bar_bronze", "count": 2, "text": "Bring Hilde 2 Bronze Bars", "say": [["Hilde the Baker", "Shiny! The bread will rise like the sun now."]]}],
        "reward": {"xp": 900, "zeni": 300, "pro": {"smithing": 600}}},
    "side_smugglers": {"title": "The Smugglers' Beasts", "kind": "side", "giver": "inspector", "level": 7, "requires": [],
        "intro": [["Inspector Holt", "Smugglers keep beasts on the isle to scare off honest folk. Thin them out and report to Captain Maren — she owes me a favour."]],
        "steps": [{"type": "kill", "kind": "", "region": "Verdant Isle", "count": 6, "text": "Defeat 6 creatures on Verdant Isle"}, {"type": "talk", "npc": "maren", "text": "Report to Captain Maren in Harrowmere", "say": [["Captain Maren", "Holt sent you? Then the smugglers will have a quiet month. Good."]]}],
        "reward": {"xp": 1200, "zeni": 400}},
    "side_herring": {"title": "Evidence in the Nets", "kind": "side", "giver": "inspector", "level": 8, "requires": ["side_smugglers"],
        "intro": [["Inspector Holt", "The smugglers hide letters inside herring and toss them in the harbour. Catch me three Harrow Herring — let's read their mail."]],
        "steps": [{"type": "catch", "fish": "harrow_herring", "count": 3, "text": "Catch 3 Harrow Herring"}, {"type": "talk", "npc": "inspector", "text": "Bring the catch to Inspector Holt", "say": [["Inspector Holt", "\"Meet at the keep at midnight.\" Hm. Masks again. I don't like this at all."]]}],
        "reward": {"xp": 1500, "zeni": 500, "pro": {"fishing": 800}}},
    "side_crater": {"title": "Embers in the Crater", "kind": "side", "giver": "rowan", "level": 11, "requires": ["side_quills"],
        "intro": [["Old Rowan", "The crater beasts have been creeping toward the forest. One spark and Thornwood burns. Push them back."]],
        "steps": [{"type": "kill", "kind": "", "region": "Cinder Crater", "count": 6, "text": "Defeat 6 creatures in Cinder Crater"}, {"type": "talk", "npc": "rowan", "text": "Return to Old Rowan", "say": [["Old Rowan", "The wind smells of pine again, not smoke. Thank you."]]}],
        "reward": {"xp": 2500, "zeni": 700, "gear": 2}},
    "side_wisps": {"title": "Lights for the Long Winter", "kind": "side", "giver": "ulla", "level": 12, "requires": ["side_furs"],
        "intro": [["Chief Ulla", "Snow wisp motes glow for a whole winter. Four of them and the children won't be afraid of the dark."]],
        "steps": [{"type": "bring", "item": "wisp_mote", "count": 4, "text": "Bring Chief Ulla 4 Wisp Motes (absorb snow wisps)", "say": [["Chief Ulla", "Look at them glow. The longhouse will be bright all winter."]]}],
        "reward": {"xp": 2600, "zeni": 800}},
    "side_ice_fishing": {"title": "Ice Fishing", "kind": "side", "giver": "ulla", "level": 13, "requires": [],
        "intro": [["Chief Ulla", "Cut a hole in the ice, drop a line, wait. Two Glacier Cod feed a family for a week."]],
        "steps": [{"type": "catch", "fish": "glacier_cod", "count": 2, "text": "Catch 2 Glacier Cod in Frostpeak"}, {"type": "talk", "npc": "ulla", "text": "Bring the cod to Chief Ulla", "say": [["Chief Ulla", "Fat ones! You have frost in your blood after all."]]}],
        "reward": {"xp": 2800, "zeni": 900, "pro": {"fishing": 1500}}},
    "side_snowmane": {"title": "The Ghost of the Glacier", "kind": "side", "giver": "ulla", "level": 15, "requires": ["side_wisps"],
        "intro": [["Chief Ulla", "A white bear walks the glacier like a ghost — Snowmane. It took three of our hunters. End it."]],
        "steps": [{"type": "boss", "id": "elite_snowmane", "text": "Defeat Snowmane on the glacier"}, {"type": "talk", "npc": "ulla", "text": "Return to Chief Ulla", "say": [["Chief Ulla", "The hunters can rest. Rimeholm names you a friend of the clans."]]}],
        "reward": {"xp": 5000, "zeni": 1800, "gear": 3}},
    "side_shells": {"title": "Shells for the Bazaar", "kind": "side", "giver": "steward", "level": 9, "requires": [],
        "intro": [["The Sultan's Steward", "Scuttler shells polish into the finest bowls in the bazaar. Four, if you please."]],
        "steps": [{"type": "bring", "item": "scuttler_shell", "count": 4, "text": "Bring the Steward 4 Scuttler Shells (absorb sand scuttlers)", "say": [["The Sultan's Steward", "Excellent. The Sultan's table will shine."]]}],
        "reward": {"xp": 1800, "zeni": 900}},
    "side_moles": {"title": "Moles Under the Fields", "kind": "side", "giver": "bram", "level": 12, "requires": [],
        "intro": [["Farmer Bram", "Burrow moles! My pumpkins fall into holes overnight. Five of them, that's all I ask."]],
        "steps": [{"type": "kill", "kind": "burrow_mole", "region": "", "count": 5, "text": "Defeat 5 Burrow Moles"}, {"type": "talk", "npc": "bram", "text": "Tell Farmer Bram", "say": [["Farmer Bram", "My pumpkins thank you. So does my back."]]}],
        "reward": {"xp": 2600, "zeni": 800}},
    "side_ambercap": {"title": "The Harvest Tonic", "kind": "side", "giver": "bram", "level": 14, "requires": ["side_orchard"],
        "intro": [["Farmer Bram", "My wife swears by ambercap tonic for the harvest weeks. Five caps from the autumn bushes."]],
        "steps": [{"type": "bring", "item": "herb_ambercap", "count": 5, "text": "Bring Farmer Bram 5 Ambercap", "say": [["Farmer Bram", "That's the harvest saved twice over!"]]}],
        "reward": {"xp": 3200, "zeni": 1000, "pro": {"alchemy": 1200}}},
    "side_kappa": {"title": "Kappa in the Reeds", "kind": "side", "giver": "moss", "level": 16, "requires": [],
        "intro": [["Mother Moss", "Bog kappa pull fishermen into the water. Five of them, child, and the reeds will be quiet."]],
        "steps": [{"type": "kill", "kind": "bog_kappa", "region": "", "count": 5, "text": "Defeat 5 Bog Kappa"}, {"type": "talk", "npc": "moss", "text": "Return to Mother Moss", "say": [["Mother Moss", "Hm-hm. The fishermen will sing your name. Badly."]]}],
        "reward": {"xp": 4000, "zeni": 1200}},
    "side_fen_witch": {"title": "The Other Witch", "kind": "side", "giver": "moss", "level": 19, "requires": ["side_brew"],
        "intro": [["Mother Moss", "There's a witch in the fen who grows mirecaps in children's beds. Not a nice witch. Not like me."]],
        "steps": [{"type": "boss", "id": "elite_fen_witch", "text": "Defeat the Fen Witch"}, {"type": "talk", "npc": "moss", "text": "Return to Mother Moss", "say": [["Mother Moss", "One witch in this marsh is plenty. Take this — and wipe your boots."]]}],
        "reward": {"xp": 7000, "zeni": 2400, "gear": 3}},
    "side_lanterns": {"title": "Paper Lanterns", "kind": "side", "giver": "princess", "level": 15, "requires": [],
        "intro": [["Princess Sora", "The lantern festival needs new lanterns, and the best paper comes from the lantern spirits themselves. Four sheets?"]],
        "steps": [{"type": "bring", "item": "lantern_paper", "count": 4, "text": "Bring Princess Sora 4 Lantern Paper (absorb paper lanterns)", "say": [["Princess Sora", "They'll float over the river like a second sky."]]}],
        "reward": {"xp": 4000, "zeni": 1300}},
    "side_koi": {"title": "Koi for the Palace Pond", "kind": "side", "giver": "princess", "level": 16, "requires": ["side_lanterns"],
        "intro": [["Princess Sora", "The palace pond has lost its koi to a heron. Two koi would make my father smile again."]],
        "steps": [{"type": "catch", "fish": "koi", "count": 2, "text": "Catch 2 Koi in Sakura Vale"}, {"type": "talk", "npc": "princess", "text": "Bring the koi to Princess Sora", "say": [["Princess Sora", "Look at them shine! Father will be so pleased."]]}],
        "reward": {"xp": 4500, "zeni": 1500, "pro": {"fishing": 2000}}},
    "side_tea": {"title": "Blossom Tea", "kind": "side", "giver": "kaito", "level": 15, "requires": [],
        "intro": [["Sensei Kaito", "A swordsman's mind should be clear as blossom tea. Bring me five sakura petals and we will drink."]],
        "steps": [{"type": "bring", "item": "herb_sakura", "count": 5, "text": "Bring Sensei Kaito 5 Sakura Petals", "say": [["Sensei Kaito", "Sit. Breathe. Now — the tea."]]}],
        "reward": {"xp": 3800, "zeni": 1100, "pro": {"alchemy": 1500}}},
    "side_salamander": {"title": "Salamander Scales", "kind": "side", "giver": "ignis", "level": 18, "requires": [],
        "intro": [["Forgemaster Ignis", "Salamander scales make a quench that never cracks a blade. Three, and quickly — the forge waits for no one."]],
        "steps": [{"type": "bring", "item": "salamander_scale", "count": 3, "text": "Bring Forgemaster Ignis 3 Salamander Scales", "say": [["Forgemaster Ignis", "Ha! Listen to that hiss. Perfect."]]}],
        "reward": {"xp": 5500, "zeni": 1800}},
    "side_steel": {"title": "Steel for the Harbour", "kind": "side", "giver": "ignis", "level": 16, "requires": ["side_fuel"],
        "intro": [["Forgemaster Ignis", "The harbour chains are rusting through. Smelt three steel bars and I'll forge new ones."]],
        "steps": [{"type": "craft", "item": "bar_steel", "count": 3, "text": "Smelt 3 Steel Bars (Smithing 15)"}, {"type": "bring", "item": "bar_steel", "count": 3, "text": "Bring Forgemaster Ignis 3 Steel Bars", "say": [["Forgemaster Ignis", "Good grain. You'll make a smith yet."]]}],
        "reward": {"xp": 5000, "zeni": 1600, "pro": {"smithing": 3000}}},
    "side_gale": {"title": "The Gale Beasts", "kind": "side", "giver": "hunter", "level": 23, "requires": [],
        "intro": [["Huntress Kesh", "Gale beasts run down our horses in packs. Six pelts on the wall and the packs will think twice."]],
        "steps": [{"type": "kill", "kind": "gale_beast", "region": "", "count": 6, "text": "Defeat 6 Gale Beasts"}, {"type": "talk", "npc": "hunter", "text": "Return to Huntress Kesh", "say": [["Huntress Kesh", "Good hunting. You move like a steppe rider."]]}],
        "reward": {"xp": 9000, "zeni": 3000}},
    "side_sturgeon": {"title": "The Old Sturgeon", "kind": "side", "giver": "hunter", "level": 25, "requires": ["side_gale"],
        "intro": [["Huntress Kesh", "My father fished the steppe rivers for a sturgeon as long as a horse. He never caught one. Will you?"]],
        "steps": [{"type": "catch", "fish": "steppe_sturgeon", "count": 1, "text": "Catch a Steppe Sturgeon"}, {"type": "talk", "npc": "hunter", "text": "Show Huntress Kesh the sturgeon", "say": [["Huntress Kesh", "...It's real. He'd have laughed for a week. Thank you."]]}],
        "reward": {"xp": 10000, "zeni": 3500, "pro": {"fishing": 4000}}},
    "side_shades": {"title": "Shades in the Dusk", "kind": "side", "giver": "morwen", "level": 30, "requires": [],
        "intro": [["Morwen of Witchwood", "Shade spirits whisper outside my window all night. Six of them gone and I might sleep."]],
        "steps": [{"type": "kill", "kind": "shade_spirit", "region": "", "count": 6, "text": "Defeat 6 Shade Spirits"}, {"type": "talk", "npc": "morwen", "text": "Return to Morwen", "say": [["Morwen of Witchwood", "Quiet at last. Don't expect me to say thank you."]]}],
        "reward": {"xp": 14000, "zeni": 4500}},
    "side_nightweaver": {"title": "The Web Queen", "kind": "side", "giver": "morwen", "level": 32, "requires": ["side_nightshade"],
        "intro": [["Morwen of Witchwood", "Nightweaver has webbed the whole east wood. My herbs, my paths, my cat. Cut her down."]],
        "steps": [{"type": "boss", "id": "elite_nightweaver", "text": "Defeat Nightweaver"}, {"type": "talk", "npc": "morwen", "text": "Return to Morwen", "say": [["Morwen of Witchwood", "The cat came home. Fine. You're welcome in my hut. Wipe your feet."]]}],
        "reward": {"xp": 20000, "zeni": 6000, "gear": 4}},
    "side_lotus": {"title": "Jade Lotus", "kind": "side", "giver": "lin", "level": 36, "requires": [],
        "intro": [["Sage Lin", "The jade lotus opens only for the patient. Bring me four and I will brew a tea for clear thoughts."]],
        "steps": [{"type": "bring", "item": "herb_jade_lotus", "count": 4, "text": "Bring Sage Lin 4 Jade Lotus", "say": [["Sage Lin", "Patience, rewarded. Sit with me a while."]]}],
        "reward": {"xp": 18000, "zeni": 6000, "pro": {"alchemy": 5000}}},
    "side_cloud_serpent": {"title": "The Cloud Serpent", "kind": "side", "giver": "lin", "level": 38, "requires": ["side_mist_carp"],
        "intro": [["Sage Lin", "The Cloud Serpent was a spirit of good rain. Now it brings only storms. Free it — by defeating it."]],
        "steps": [{"type": "boss", "id": "elite_cloud_serpent", "text": "Defeat the Cloud Serpent"}, {"type": "talk", "npc": "lin", "text": "Return to Sage Lin", "say": [["Sage Lin", "Listen — soft rain on the terraces. It is at peace."]]}],
        "reward": {"xp": 30000, "zeni": 9000, "gear": 4}},
}

static func is_main(id: String) -> bool:
    return id.begins_with("main_")

## Court characters show only while a quest waits for you to speak to them.
static func is_staged(id: String) -> bool:
    return NPCS.has(id) and NPCS[id].size() > 4 and bool(NPCS[id][4])

## Bounties of a town's board (repeatable): generated from the town's region.
static func bounties(town: String) -> Array:
    var region_content := preload("res://scripts/world/region_content.gd")
    var pro := preload("res://scripts/professions/profession_catalogue.gd")
    var info: Array = MAP.town(town)
    var region: String = MAP.REGION_NAMES[info[2]]
    if region == "Harrowmere":
        region = "Verdant Isle"
    var range: Array = region_content.level_range(region)
    var level: int = range[0] if not range.is_empty() else 1
    var kinds := {}
    for entry in region_content.CREATURES:
        if MAP.region_name(region_content.at(entry[2])) == region:
            kinds[entry[1]] = int(kinds.get(entry[1], 0)) + 1
    var kind: String = ""
    for candidate in kinds:
        if kind.is_empty() or kinds[candidate] > kinds[kind]:
            kind = candidate
    var resource := ""
    for table in [pro.WOODS, pro.ORES]:
        for id in table:
            if region in table[id][5] and (resource.is_empty() or int(table[id][1]) < int(pro.WOODS.get(resource, pro.ORES.get(resource, [0, 99]))[1])):
                resource = id
    if resource.is_empty():
        resource = "log_oak"
    var leveling := preload("res://scripts/progression/leveling.gd")
    var trade := preload("res://scripts/trade/trade_catalogue.gd")
    var xp: int = leveling.defeat_xp(level, 1) * 8
    var zeni: int = trade.zeni_for(level, 1) * 10
    var all: Array = []
    all.append({"id": "bounty_%s_cull" % town, "title": "Bounty: Cull the Wilds of %s" % region, "kind": "bounty", "giver": "board_" + town, "level": maxi(1, level - 2), "requires": [], "intro": [["Bounty Board", "WANTED: 8 creatures of %s, defeated. Reward paid on return." % region]],
        "steps": [{"type": "kill", "kind": "", "region": region, "count": 8, "text": "Defeat 8 creatures in %s" % region}, {"type": "talk", "npc": "board_" + town, "text": "Collect the bounty at the board"}], "reward": {"xp": xp, "zeni": zeni}})
    if not kind.is_empty():
        all.append({"id": "bounty_%s_hunt" % town, "title": "Bounty: %s Hunt" % kind.replace("_", " ").capitalize(), "kind": "bounty", "giver": "board_" + town, "level": maxi(1, level - 2), "requires": [], "intro": [["Bounty Board", "WANTED: 5 %s. They have been troubling travellers." % kind.replace("_", " ").capitalize()]],
            "steps": [{"type": "kill", "kind": kind, "region": "", "count": 5, "text": "Defeat 5 %s" % kind.replace("_", " ").capitalize()}, {"type": "talk", "npc": "board_" + town, "text": "Collect the bounty at the board"}], "reward": {"xp": int(xp * 0.8), "zeni": int(zeni * 0.8)}})
    all.append({"id": "bounty_%s_supply" % town, "title": "Bounty: Supplies for %s" % info[1], "kind": "bounty", "giver": "board_" + town, "level": maxi(1, level - 2), "requires": [], "intro": [["Bounty Board", "WANTED: 5 %s for the town's stores." % pro.resource_info(resource)[0]]],
        "steps": [{"type": "bring", "item": resource, "count": 5, "text": "Bring 5 %s to the board" % pro.resource_info(resource)[0]}], "reward": {"xp": int(xp * 0.6), "zeni": int(zeni * 0.9), "pro": {pro.profession_for(resource): pro.xp_reward(int(pro.required_level(resource))) * 6}}})
    return all

static var _all: Dictionary = {}

## Every quest (story, side and all bounties) by id.
static func all() -> Dictionary:
    if _all.is_empty():
        _all = QUESTS.duplicate(true)
        for town in BOARD_TOWNS:
            for quest in bounties(town):
                _all[quest.id] = quest
    return _all

static func quest(id: String) -> Dictionary:
    return all().get(id, {})

## Who someone is: [name, sprite] (boards and Lumi included).
static func npc_name(id: String) -> String:
    if id == LUMI:
        return LUMI_NAME
    if id.begins_with("board_"):
        return "Bounty Board"
    return NPCS[id][0] if NPCS.has(id) else id

## Where someone stands (world position); Vector2.INF for Lumi.
static func npc_position(id: String) -> Vector2:
    if id.begins_with("board_"):
        var town: Array = MAP.town(id.trim_prefix("board_"))
        return MAP.to_world(Vector2(town[3]) + BOARD_OFFSET) + Vector2(8, 8)
    if not NPCS.has(id):
        return Vector2.INF
    var spec: Array = NPCS[id]
    if String(spec[2]).is_empty():
        return MAP.to_world(spec[3]) + Vector2(8, 8)
    if String(spec[2]).begins_with("dungeon:"):
        var chamber: Array = preload("res://scripts/dungeons/dungeon_catalogue.gd").rooms(String(spec[2]).trim_prefix("dungeon:"))[3]
        return MAP.to_world(Vector2(chamber[0]) + spec[3]) + Vector2(8, 8)
    return MAP.to_world(Vector2(MAP.town(spec[2])[3]) + spec[3]) + Vector2(8, 8)

## Quests a giver offers (in catalogue order; the main story first).
static func offered_by(npc: String) -> Array:
    var list: Array = []
    for id in all():
        if all()[id].giver == npc:
            list.append(id)
    return list
