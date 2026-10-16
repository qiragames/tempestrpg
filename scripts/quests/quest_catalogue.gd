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
const MAP := preload("res://scripts/world/world_map.gd")

## Story characters and quest givers: [name, sprite, town ("" = fixed tile), tile offset from the
## town's plaza (or the tile itself)].
const NPCS := {
    "orrin": ["Orrin the Astronomer", "npc_orrin", "brookhaven", Vector2(-3, 1.5)],
    "hilde": ["Hilde the Baker", "npc_hilde", "brookhaven", Vector2(-1, 3)],
    "rowan": ["Old Rowan", "npc_rowan", "thornhollow", Vector2(-2, 1)],
    "nessa": ["Nessa the Fisher", "npc_nessa", "mirrorwick", Vector2(-2, 1)],
    "maren": ["Captain Maren", "npc_maren", "harrowmere", Vector2(-3, 1.5)],
    "alric": ["Brother Alric", "npc_alric", "harrowmere", Vector2(-1, 3)],
    "vex": ["Vex of the Eclipse Court", "npc_vex", "", Vector2(246, 70)],
    "ulla": ["Chief Ulla", "npc_ulla", "rimeholm", Vector2(-3, 1.5)],
    "steward": ["The Sultan's Steward", "npc_steward", "dunemarch", Vector2(-3, 1.5)],
    "bram": ["Farmer Bram", "npc_bram", "amberhold", Vector2(-3, 1.5)],
    "moss": ["Mother Moss", "npc_moss", "bogsend", Vector2(-3, 1.5)],
    "kaito": ["Sensei Kaito", "npc_kaito", "hanamura", Vector2(-3, 1.5)],
    "ignis": ["Forgemaster Ignis", "npc_ignis", "cinderport", Vector2(-3, 1.5)],
    "temur": ["Khan Temur", "npc_temur", "galehaven", Vector2(-3, 1.5)],
    "morwen": ["Morwen of Witchwood", "npc_morwen", "gloomhollow", Vector2(-3, 1.5)],
    "lin": ["Sage Lin", "npc_lin", "highwind", Vector2(-3, 1.5)],
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
            {"type": "kill", "kind": "", "region": "The First Clearing", "count": 3, "text": "Defend yourself: defeat 3 creatures in the First Clearing", "say": [["Lumi", "Not bad for someone who can't remember their own name!"]]},
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
}

static func is_main(id: String) -> bool:
    return id.begins_with("main_")

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
    return MAP.to_world(Vector2(MAP.town(spec[2])[3]) + spec[3]) + Vector2(8, 8)

## Quests a giver offers (in catalogue order; the main story first).
static func offered_by(npc: String) -> Array:
    var list: Array = []
    for id in all():
        if all()[id].giver == npc:
            list.append(id)
    return list
