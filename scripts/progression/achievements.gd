extends RefCounted
## Achievements and titles (M9e, user decision in docs/M4_PLAN.md M9): milestones in fighting, the
## story, quests, professions, fishing, crafting and travel. Many give a title the character can
## wear (shown on the status card and above their head), e.g. "Leviathan Catcher" or "Master Miner".
## The host counts what characters do (QuestLog passes every game event on) and unlocks; each
## character keeps progression.achievements {id: true}, progression.stats (counters and lists) and
## progression.title (an unlocked achievement's id, or ""). Characters from older saves unlock what
## their level, professions, fish log and quests already show the first time they are checked.
const PRO := preload("res://scripts/professions/profession_catalogue.gd")
const FISHES := preload("res://scripts/professions/fish_catalogue.gd")
const BOSSES := preload("res://scripts/bosses/boss_catalogue.gd")
const DUNGEONS := preload("res://scripts/dungeons/dungeon_catalogue.gd")
const QUESTS := preload("res://scripts/quests/quest_catalogue.gd")

## Categories in the window's order.
const CATEGORIES := ["Combat", "Story", "Quests", "Professions", "Fishing", "Journey"]
## [name, description, category, title ("" = none), rule, target, what]
## Rules: stat (a counter), set (a list's size), has (a list holds what), level, pro (profession
## level), species (fish in the log), fish (one fish in the log), mythic (mythical fish in the log),
## quest (finished), sides (side quests finished), ending (the story's ending), zeni.
const ACHIEVEMENTS := {
    "first_blood": ["First Blood", "Defeat your first creature", "Combat", "", "stat", 1, "kills"],
    "hunter": ["Hunter", "Defeat 100 creatures", "Combat", "the Hunter", "stat", 100, "kills"],
    "slayer": ["Slayer", "Defeat 1,000 creatures", "Combat", "Slayer", "stat", 1000, "kills"],
    "nightbane": ["Nightbane", "Defeat 10 night stalkers", "Combat", "Nightbane", "stat", 10, "night_kills"],
    "elite_first": ["Something Big", "Defeat a hidden elite", "Combat", "", "set", 1, "elites"],
    "elite_all": ["Shadow of the Wilds", "Defeat all ten hidden elites", "Combat", "Elite Hunter", "set", 10, "elites"],
    "raid_first": ["Raider", "Help defeat a raid boss", "Combat", "Raider", "set", 1, "raids"],
    "raid_all": ["Raid Legend", "Help defeat every raid boss", "Combat", "Raid Legend", "set", 16, "raids"],
    "delver": ["Delver", "Defeat a dungeon's end boss", "Combat", "", "set", 1, "dungeons"],
    "dungeon_master": ["Dungeon Master", "Defeat all five dungeons' end bosses", "Combat", "Dungeon Master", "set", 5, "dungeons"],
    "heroic_first": ["Heroic Delver", "Defeat a dungeon's end boss on Heroic", "Combat", "", "set", 1, "heroic"],
    "heroic_all": ["The Heroic", "Defeat all five end bosses on Heroic", "Combat", "the Heroic", "set", 5, "heroic"],
    "wyrmslayer": ["Wyrmslayer", "Defeat the Eclipse Wyrm", "Combat", "Wyrmslayer", "has", 1, ["raids", "boss_eclipse_wyrm"]],
    "castaway": ["Washed Ashore", "Finish the Prologue", "Story", "the Castaway", "quest", 1, "main_0"],
    "first_shard": ["The First Shard", "Finish Chapter 1", "Story", "", "quest", 1, "main_1"],
    "shardseeker": ["Shardseeker", "Finish Chapter 3", "Story", "Shardseeker", "quest", 1, "main_3"],
    "star_reader": ["Rekindled", "Finish Chapter 5", "Story", "Star-Reader", "quest", 1, "main_5"],
    "moonwarden": ["Moonwarden", "Mend the moon", "Story", "Moonwarden", "ending", 1, "moonwarden"],
    "sovereign": ["Eclipse Sovereign", "Keep the moon's core", "Story", "Eclipse Sovereign", "ending", 1, "sovereign"],
    "helping_hand": ["Helping Hand", "Finish 5 side quests", "Quests", "", "sides", 5, ""],
    "good_samaritan": ["Good Samaritan", "Finish 20 side quests", "Quests", "Good Samaritan", "sides", 20, ""],
    "hero": ["Hero of the Realm", "Finish every side quest", "Quests", "Hero of the Realm", "sides", -1, ""],
    "bounty_10": ["Wanted", "Claim 10 bounties", "Quests", "", "stat", 10, "bounties"],
    "bounty_hunter": ["Bounty Hunter", "Claim 50 bounties", "Quests", "Bounty Hunter", "stat", 50, "bounties"],
    "woodcutting_25": ["Woodcutter", "Reach Woodcutting 25", "Professions", "", "pro", 25, "woodcutting"],
    "woodcutting_50": ["Master Lumberjack", "Reach Woodcutting 50", "Professions", "Master Lumberjack", "pro", 50, "woodcutting"],
    "mining_25": ["Miner", "Reach Mining 25", "Professions", "", "pro", 25, "mining"],
    "mining_50": ["Master Miner", "Reach Mining 50", "Professions", "Master Miner", "pro", 50, "mining"],
    "smithing_25": ["Smith", "Reach Smithing 25", "Professions", "", "pro", 25, "smithing"],
    "smithing_50": ["Master Smith", "Reach Smithing 50", "Professions", "Master Smith", "pro", 50, "smithing"],
    "alchemy_25": ["Alchemist", "Reach Alchemy 25", "Professions", "", "pro", 25, "alchemy"],
    "alchemy_50": ["Master Alchemist", "Reach Alchemy 50", "Professions", "Master Alchemist", "pro", 50, "alchemy"],
    "tireless": ["Tireless", "Gather 500 logs, ores and herbs", "Professions", "Tireless", "stat", 500, "gathered"],
    "artisan": ["Artisan", "Craft 100 things (bars, gear, potions)", "Professions", "Artisan", "stat", 100, "crafted"],
    "fishing_25": ["Fisher", "Reach Fishing 25", "Fishing", "", "pro", 25, "fishing"],
    "fishing_50": ["Master Angler", "Reach Fishing 50", "Fishing", "Master Angler", "pro", 50, "fishing"],
    "angler": ["Angler", "Land 100 fish", "Fishing", "Angler", "stat", 100, "fish"],
    "collector": ["Fish Collector", "Have 25 kinds of fish in your fish log", "Fishing", "Fish Collector", "species", 25, ""],
    "fish_log": ["Keeper of the Fish Log", "Have every fish in your fish log", "Fishing", "Keeper of the Fish Log", "species", -1, ""],
    "leviathan": ["Leviathan Catcher", "Land the Leviathan", "Fishing", "Leviathan Catcher", "fish", 1, "leviathan"],
    "kraken": ["Kraken Tamer", "Land the Kraken", "Fishing", "Kraken Tamer", "fish", 1, "kraken"],
    "myth_hunter": ["Myth Hunter", "Land all six mythical sea creatures", "Fishing", "Myth Hunter", "mythic", 6, ""],
    "level_10": ["Finding Your Feet", "Reach level 10", "Journey", "", "level", 10, ""],
    "level_25": ["Veteran", "Reach level 25", "Journey", "Veteran", "level", 25, ""],
    "level_50": ["Legend", "Reach level 50", "Journey", "Legend", "level", 50, ""],
    "tycoon": ["Tycoon", "Hold 100,000 Zeni", "Journey", "Tycoon", "zeni", 100000, ""],
    "wanderer": ["Wanderer", "Set foot in every land of the world", "Journey", "Wanderer", "set", 16, "regions"],
    "realm_walker": ["Realm Walker", "Find the hidden Ki Realm", "Journey", "Realm Walker", "has", 1, ["regions", "The Ki Realm"]],
}
## Lists characters collect (sets) and the most entries a list may hold.
const LISTS := ["elites", "raids", "dungeons", "regions", "heroic"]
const LIST_LIMIT := 64
## Regions that count for the Wanderer (the sea and the underground do not).
const SKIP_REGIONS := ["The Sapphire Sea", "The Underdeep"]

static func title_of(id: String) -> String:
    return String(ACHIEVEMENTS[id][3]) if ACHIEVEMENTS.has(id) else ""

static func stats(actor: Node) -> Dictionary:
    if not actor.progression.get("stats") is Dictionary:
        actor.progression["stats"] = {}
    return actor.progression.stats

static func unlocked(actor: Node) -> Dictionary:
    if not actor.progression.get("achievements") is Dictionary:
        actor.progression["achievements"] = {}
    return actor.progression.achievements

static func has(actor: Node, id: String) -> bool:
    return bool(unlocked(actor).get(id, false))

## The title a character wears ("" for none).
static func worn_title(actor: Node) -> String:
    var id := String(actor.progression.get("title", ""))
    return title_of(id) if has(actor, id) else ""

static func _add(actor: Node, list: String, value: String) -> void:
    var all := stats(actor)
    if not all.get(list) is Array:
        all[list] = []
    if not value in all[list] and all[list].size() < LIST_LIMIT:
        all[list].append(value)

static func _count(actor: Node, stat: String, amount: int = 1) -> void:
    stats(actor)[stat] = int(stats(actor).get(stat, 0)) + amount

## Host: what a game event adds to a character's stats.
static func record(actor: Node, kind: String, data: Dictionary) -> void:
    match kind:
        "kill":
            _count(actor, "kills")
            if String(data.get("id", "")).begins_with("night_"):
                _count(actor, "night_kills")
        "boss":
            var id := String(data.get("id", ""))
            if BOSSES.is_raid(id):
                _add(actor, "raids", id)
            elif BOSSES.is_hidden_elite(id):
                _add(actor, "elites", id)
            elif BOSSES.is_boss(id):
                _add(actor, "dungeons", id)
                if DUNGEONS.heroic_bonus(id.trim_prefix("dungeon_")) > 0:
                    _add(actor, "heroic", id)
        "gather":
            _count(actor, "gathered", maxi(1, int(data.get("amount", 1))))
        "craft":
            _count(actor, "crafted", maxi(1, int(data.get("amount", 1))))
        "catch":
            _count(actor, "fish")
        "bounty":
            _count(actor, "bounties")
        "region":
            var region := String(data.get("region", ""))
            if not region.is_empty() and not region in SKIP_REGIONS:
                _add(actor, "regions", region)

static func _side_ids() -> Array:
    return QUESTS.QUESTS.keys().filter(func(id): return QUESTS.QUESTS[id].kind == "side")

## [done so far, needed] for an achievement.
static func progress(actor: Node, id: String) -> Array:
    var spec: Array = ACHIEVEMENTS[id]
    var target := int(spec[5])
    var what = spec[6]
    var quests: Dictionary = actor.progression.get("quests", {}) if actor.progression.get("quests") is Dictionary else {}
    var log: Dictionary = actor.progression.get("fish_log", {}) if actor.progression.get("fish_log") is Dictionary else {}
    match String(spec[4]):
        "stat":
            return [int(stats(actor).get(what, 0)), target]
        "set":
            var list: Variant = stats(actor).get(what, [])
            return [list.size() if list is Array else 0, target]
        "has":
            var list: Variant = stats(actor).get(what[0], [])
            return [1 if list is Array and what[1] in list else 0, 1]
        "level":
            return [int(actor.progression.get("level", 1)), target]
        "pro":
            var professions: Dictionary = actor.progression.get("professions", {}) if actor.progression.get("professions") is Dictionary else {}
            return [PRO.level_for(int(professions.get(what, 0))), target]
        "species":
            return [log.size(), FISHES.FISH.size() if target < 0 else target]
        "fish":
            return [1 if log.has(what) else 0, 1]
        "mythic":
            return [log.keys().filter(func(fish): return FISHES.FISH.has(fish) and int(FISHES.FISH[fish][4]) >= 5).size(), target]
        "quest":
            return [1 if quests.get(what) is Dictionary and bool(quests[what].get("done", false)) else 0, 1]
        "sides":
            var sides := _side_ids()
            var done: int = sides.filter(func(side): return quests.get(side) is Dictionary and bool(quests[side].get("done", false))).size()
            return [done, sides.size() if target < 0 else target]
        "ending":
            var story: Variant = quests.get("main_7")
            return [1 if story is Dictionary and String(story.get("pick", "")) == what else 0, 1]
        "zeni":
            return [int(actor.progression.get("zeni", 0)), target]
    return [0, 1]

## Host: unlock everything a character has earned; returns the newly unlocked ids.
static func check(actor: Node) -> Array:
    var fresh: Array = []
    for id in ACHIEVEMENTS:
        if has(actor, id):
            continue
        var state := progress(actor, id)
        if int(state[0]) >= int(state[1]):
            unlocked(actor)[id] = true
            fresh.append(id)
    return fresh
