extends RefCounted
## Validate before applying; temp + rename replaces the primary atomically.

const VERSION := 41
const PILE := preload("res://scripts/pickups/item_pile.gd")
const FORMS := preload("res://scripts/forms/form_catalogue.gd")
const SKILLS := preload("res://scripts/skills/skill_catalogue.gd")
## Initial saved state of the v8 encounter; matches scenes/world/forest.tscn.
const THORNBACK := {"id": "thornback_1", "kind": "thornback", "position": [880.0, 560.0], "home": [880.0, 560.0], "difficulty": 1, "hp": 30, "maximum_hp": 30, "immunity": 0.0, "state": 0, "state_time": 0.0, "target": ""}
const CAMP := preload("res://scripts/settlement/first_camp.gd")
const LAYOUT := preload("res://scripts/world/world_layout.gd")
const REGION := preload("res://scripts/world/region_content.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
const RACES := preload("res://scripts/races/race_catalogue.gd")
const TREE := preload("res://scripts/skills/skill_tree.gd")
const CLASS_SKILLS := preload("res://scripts/skills/class_skills.gd")
const RESPAWNER := preload("res://scripts/world/respawner.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const SOURCES := preload("res://scripts/items/gear_sources.gd")
const ALLY := preload("res://scripts/allies/goblin_ally.gd")
const MAX_BYTES := 4 * 1024 * 1024
const CODEC := preload("res://scripts/persistence/state_codec.gd")
const TRADE := preload("res://scripts/trade/trade_catalogue.gd")
const WORLD_TRADE := preload("res://scripts/trade/world_trade.gd")
const HARBOURS := preload("res://scripts/travel/world_harbours.gd")
const PARTY := preload("res://scripts/party/world_party.gd")
const GUILDS := preload("res://scripts/guilds/world_guilds.gd")
const HOUSING := preload("res://scripts/housing/world_housing.gd")
const KI_REALM := preload("res://scripts/realm/ki_realm.gd")
const SIEGE := preload("res://scripts/nation/siege.gd")
const REALM := preload("res://scripts/realm/realm_catalogue.gd")
const TRAVEL := preload("res://scripts/travel/travel_catalogue.gd")
const UPGRADES := preload("res://scripts/items/upgrade_catalogue.gd")

static func _number(value: Variant, low: float, high: float, whole: bool = false) -> bool:
    if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
        return false
    return is_finite(float(value)) and value >= low and value <= high and (not whole or value == floor(value))

## Anywhere in the archipelago (M4.5a; the clearing's 0..960 x 0..640 lies inside it, so older
## saves stay valid without migration).
static func _position(value: Variant) -> bool:
    var world: Rect2 = preload("res://scripts/world/world_map.gd").bounds()
    return value is Array and value.size() == 2 and _number(value[0], world.position.x, world.end.x) and _number(value[1], world.position.y, world.end.y)

static func _id(value: Variant, empty: bool = false) -> bool:
    if not value is String or value.length() > 64 or (value.is_empty() and not empty):
        return false
    for character in value:
        if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":
            return false
    return true

static func _plain(value: Variant, depth: int = 0) -> bool:
    if depth > 8:
        return false
    if value is Dictionary:
        if value.size() > 256:
            return false
        for key in value:
            if not key is String or key.length() > 128 or not _plain(value[key], depth + 1):
                return false
        return true
    if value is Array:
        if value.size() > 1024:
            return false
        for item in value:
            if not _plain(item, depth + 1):
                return false
        return true
    if value is String:
        return value.length() <= 512
    return value == null or value is bool or _number(value, -1000000000, 1000000000)

static func validate_player(state: Variant, id: String) -> bool:
    if state is Dictionary and state.has("death_left") and not _number(state.death_left, 0, 5):
        return false
    if not state is Dictionary or state.get("id") != id or not _id(id):
        return false
    if not _position(state.get("position")) or not _number(state.get("move_speed"), 1, 1000):
        return false
    var exhaustion = state.get("exhaustion")
    if not exhaustion is Dictionary or not exhaustion.get("active") is bool or not _number(exhaustion.get("remaining"), 0, 60):
        return false
    if not exhaustion.active and exhaustion.remaining != 0:
        return false
    var facing = state.get("facing")
    if not facing is Array or facing.size() != 2 or not _number(facing[0], -1, 1) or not _number(facing[1], -1, 1):
        return false
    var health = state.get("health")
    var pool = state.get("magicules")
    if not health is Dictionary or not pool is Dictionary:
        return false
    if not _number(health.get("maximum"), 1, 1000000, true) or not _number(health.get("current"), 0, health.maximum, true) or not _number(health.get("immunity"), 0, 60) or not _number(health.get("immunity_seconds"), 0, 60) or not _number(health.get("regen_rate"), 0, 10) or not _number(health.get("regen_left"), 0, 10) or not _number(health.get("regen_carry"), 0, 0.999999999):
        return false
    if not _number(pool.get("maximum"), 1, 1000000) or not _number(pool.get("current"), 0, pool.maximum) or not _number(pool.get("regen"), 0, 1000) or not _number(pool.get("regen_delay"), 0, 60) or not _number(pool.get("delay"), 0, 60) or not pool.get("enabled") is bool:
        return false
    var known = state.get("skill_ids")
    var slots = state.get("slots")
    if not known is Array or known.size() > CODEC.SKILLS.size() or not slots is Array or slots.size() != 8:
        return false
    var seen: Dictionary = {}
    for skill in known:
        if not skill is String or not CODEC.SKILLS.has(skill) or seen.has(skill):
            return false
        seen[skill] = true
    var equipped := {}
    for slot in slots:
        if not slot is String or (slot != "" and ((not seen.has(slot) and not TREE.SKILLS.has(slot) and not CLASS_SKILLS.SKILLS.has(slot)) or equipped.has(slot))):
            return false
        equipped[slot] = true
    # Every saved skill must follow from this character's own unlock evidence.
    if not SKILLS.evidence_valid(state.get("skill_evidence"), known) or not SKILLS.justified(known, state.skill_evidence):
        return false
    # The saved form must be unlocked by this character's evidence; defeated characters are always base.
    var form = state.get("form")
    if not form is Dictionary or form.size() != 2 or not form.get("id") is String or not FORMS.unlocked(form.id, state.skill_evidence) or not _number(form.get("cooldown"), 0, FORMS.CHANGE_COOLDOWN):
        return false
    if health.current == 0 and form.id != FORMS.BASE:
        return false
    var bag = state.get("inventory")
    if not bag is Dictionary or not _number(bag.get("capacity"), 1, 10000, true) or not bag.get("counts") is Dictionary:
        return false
    var total: int = 0
    for item in bag.counts:
        if not TRADE.bag_item(String(item)) or not _number(bag.counts[item], 1, bag.capacity, true):
            return false
        total += int(bag.counts[item])
    if total > bag.capacity or not _number(state.get("attack_recovery"), 0, 60):
        return false
    var analysis = state.get("analysis")
    if not analysis is Dictionary or not _id(analysis.get("target"), true) or not _number(analysis.get("remaining"), 0, 60) or not _number(analysis.get("focus"), 0, 20):
        return false
    var progression = state.get("progression")
    # Level, experience and unspent skill points must agree with the level curve (v14).
    if not progression is Dictionary or not _plain(progression) or not LEVELING.valid(progression) or not RACES.valid(progression.get("race")):
        return false
    # Skill tree (v15): nodes of this race in order, activations of learned skills, exact point total.
    if not TREE.valid(progression, known):
        return false
    var granted: Array = TREE.granted_skills(progression.tree.nodes) + CLASS_SKILLS.granted(progression)
    for slot in slots:
        if slot != "" and not slot in granted and not TREE.activated(slot, progression.tree.active):
            return false
    # Apply the same Slime-only mimic gate to restored state and network snapshots.
    if form.id != FORMS.BASE and not RACES.can_mimic(progression.race, int(progression.level)):
        return false
    if not progression.get("quests") is Dictionary or not progression.get("equipment") is Dictionary:
        return false
    # M15: duel and arena records.
    if not preload("res://scripts/pvp/world_duels.gd").valid_record(progression):
        return false
    # M12b: classes (known, a subclass only from level 20 and different from the class).
    if not preload("res://scripts/progression/class_catalogue.gd").valid(progression):
        return false
    # M12a: spent attribute points (never more than the level gives).
    if not preload("res://scripts/progression/attributes.gd").valid(progression):
        return false
    # Storage (after 1.0): settlement and city boxes of known shape and contents.
    if not preload("res://scripts/settlement/storage.gd").valid(progression):
        return false
    # M11f: pets (known, owned once) and the one following.
    if not preload("res://scripts/pets/pet_catalogue.gd").valid(progression):
        return false
    # M9e: achievements (known ids: true), stats (counters and short lists of names) and the worn title.
    var achievements_catalogue := preload("res://scripts/progression/achievements.gd")
    if progression.has("achievements"):
        if not progression.achievements is Dictionary:
            return false
        for achievement in progression.achievements:
            if achievements_catalogue.ACHIEVEMENTS.has(String(achievement)) and not progression.achievements[achievement] is bool:
                return false
    if progression.has("stats"):
        if not progression.stats is Dictionary:
            return false
        for stat in progression.stats:
            var value: Variant = progression.stats[stat]
            if String(stat) in achievements_catalogue.LISTS:
                if not value is Array or value.size() > achievements_catalogue.LIST_LIMIT or not value.all(func(entry): return entry is String and entry.length() <= 48):
                    return false
            elif not _number(value, 0, 1e9, true):
                return false
    if progression.has("title"):
        if not progression.title is String:
            return false
        if not progression.title.is_empty() and (achievements_catalogue.title_of(progression.title).is_empty() or not (progression.get("achievements") is Dictionary and bool(progression.achievements.get(progression.title, false)))):
            return false
    # M9c: quest progress (entries of known quests: step within the quest, counts, flags).
    var quest_catalogue := preload("res://scripts/quests/quest_catalogue.gd")
    for quest_id in progression.quests:
        var known_quest: Dictionary = quest_catalogue.quest(String(quest_id))
        if known_quest.is_empty():
            continue
        var progress: Variant = progression.quests[quest_id]
        if not progress is Dictionary or not _number(progress.get("s"), 0, known_quest.steps.size(), true) or not _number(progress.get("c"), 0, 1000000, true) or not progress.get("done") is bool:
            return false
        if progress.has("again") and not _number(progress.again, 0, 1e12):
            return false
        if progress.has("pick") and not progress.pick in ["moonwarden", "sovereign"]:
            return false
    # Zeni (v23): a whole number in the purse.
    if not _number(progression.get("zeni"), 0, TRADE.MAX_ZENI, true):
        return false
    # Travel and items (v24): ship and ferry pass, tools by tier, owned mounts (riding one of
    # them), installed augments within the level's slots, an optional cast line.
    if not HARBOURS.valid_progression(progression):
        return false
    var tools: Variant = progression.get("tools")
    if not tools is Dictionary or tools.size() != TRAVEL.TOOLS.size():
        return false
    for tool in TRAVEL.TOOLS:
        if not _number(tools.get(tool), 0, 3, true):
            return false
    var mounts: Variant = progression.get("mounts")
    if not mounts is Array or mounts.size() > TRAVEL.MOUNTS.size() or mounts.any(func(id): return not id is String or not TRAVEL.MOUNTS.has(id)) or mounts.size() != _unique(mounts):
        return false
    if not progression.get("mount") is String or (not progression.mount.is_empty() and not progression.mount in mounts):
        return false
    var augments: Variant = progression.get("augments")
    if not augments is Array or augments.size() > UPGRADES.augment_slots(int(progression.get("level", 1))) or augments.any(func(id): return not id is String or not UPGRADES.is_augment(id)) or augments.size() != _unique(augments):
        return false
    # The Ki Realm (v26): learned transformations (one of them active), wish bonus points
    # (checked with the level), the champion's title.
    var auras: Variant = progression.get("auras")
    if not auras is Array or auras.any(func(id): return not id is String or not REALM.AURAS.has(id)) or auras.size() != _unique(auras):
        return false
    if not progression.get("aura") is String or (not progression.aura.is_empty() and not progression.aura in auras) or not progression.get("champion") is bool:
        return false
    # Professions (v32): experience per profession within the curve.
    if not preload("res://scripts/professions/profession_catalogue.gd").valid(progression.get("professions")):
        return false
    # The fish log (v32): caught fish by kind.
    var fish_log: Variant = progression.get("fish_log")
    if not fish_log is Dictionary:
        return false
    for fish in fish_log:
        if not fish is String or not TRAVEL.FISH.has(fish) or not _number(fish_log[fish], 1, 1000000000, true):
            return false
    var fishing: Variant = state.get("fishing", [])
    if not fishing is Array or not fishing.size() in [0, 2] or fishing.any(func(value): return not (value is float or value is int) or not is_finite(float(value)) or absf(float(value)) > 60.0):
        return false
    # Gear (v18): valid items, equipment slots pointing at owned items that fit, sane cooldowns.
    if not GEAR.valid_gear(state.get("gear"), progression.equipment):
        return false
    # Chests opened by this character (v19): IDs are the same in every seed.
    if not SOURCES.valid_opened(progression.get("chests"), LAYOUT.ALL_CHEST_IDS):
        return false
    # Discovered hidden elites (M7c; optional).
    if progression.has("elites"):
        var elites: Variant = progression.elites
        var bosses := preload("res://scripts/bosses/boss_catalogue.gd")
        if not elites is Array or elites.size() > bosses.ELITES.size() or elites.any(func(id): return not id is String or not bosses.ELITES.has(id)) or elites.size() != _unique(elites):
            return false
    # Discovered hidden leveling spots (v21; optional for older characters).
    if progression.has("spots"):
        var spots: Variant = progression.spots
        if not spots is Array or spots.size() > REGION.SPOTS.size():
            return false
        var found := {}
        for spot_id in spots:
            if not spot_id is String or found.has(spot_id) or not REGION.SPOTS.any(func(spot): return spot[0] == spot_id):
                return false
            found[spot_id] = true
    return true

static func valid_meta(meta: Variant) -> bool:
    # M10: "imports" (guests may bring their own characters) is optional.
    if not meta is Dictionary or meta.size() != (6 if meta.has("imports") else 5) or not meta.get("name") is String or not meta.get("seeded") is bool:
        return false
    if meta.has("imports") and not meta.imports is bool:
        return false
    var name: String = meta.name
    if name.strip_edges().is_empty() or name.length() > 32 or name != name.strip_edges():
        return false
    for character in name:
        if character.unicode_at(0) < 32:
            return false
    return _number(meta.get("seed"), 0, 2147483647, true) and _number(meta.get("created"), 0, 100000000000, true) and _number(meta.get("last_played"), 0, 100000000000, true)

static func validate(data: Variant) -> bool:
    if not data is Dictionary or data.get("version") != VERSION or not _id(data.get("world_id")):
        return false
    if not data.get("players") is Dictionary or not data.players.has("host") or data.players.size() > 256:
        return false
    var item_ids: Dictionary = {}
    for id in data.players:
        if not validate_player(data.players[id], id):
            return false
        for item in data.players[id].gear.items:
            if item_ids.has(item.id):
                return false
            item_ids[item.id] = true
        var hash_value = data.players[id].get("token_hash", "")
        if not hash_value is String or (id != "host" and (hash_value.length() != 64 or not hash_value.is_valid_hex_number(false))):
            return false
    # World meta (save-slot name, seed, dates). Written by every hosted world; optional for hand-built test documents.
    if data.has("meta") and not valid_meta(data.meta):
        return false
    # The camp's deposits (positions/amounts) come from the seed; no meta means the reference map.
    var deposits: Dictionary = LAYOUT.generate(LAYOUT.seed_of(data.meta)).deposits if data.has("meta") else CAMP.DEPOSITS
    if not CAMP.valid_state(data.get("camp"), data.players, deposits):
        return false
    if not data.get("progression") is Dictionary or not _plain(data.progression):
        return false
    if not data.get("enemies") is Array or data.enemies.size() > 1024 or not data.get("pickups") is Array or data.pickups.size() > 1024:
        return false
    var ids: Dictionary = {}
    if not data.get("allies") is Array or data.allies.size() > 256:
        return false
    var names: Dictionary = {}
    for ally in data.allies:
        if not ally is Dictionary or not _id(ally.get("id")) or ids.has(ally.id) or not _position(ally.get("position")) or not _id(ally.get("owner"), true):
            return false
        if not ally.owner.is_empty() and not data.players.has(ally.owner):
            return false
        if not ally.get("name") is String:
            return false
        if ally.name.is_empty():
            if ally.get("race") != "Goblin" or ally.get("maximum_hp") != 30 or ally.get("power") != 4 or ally.get("speed") != 45:
                return false
        elif not ALLY.valid_name(ally.name) or ally.owner.is_empty() or ally.get("race") != "Hobgoblin" or ally.get("maximum_hp") != 60 or ally.get("power") != 8 or ally.get("speed") != 65:
            return false
        var work = ally.get("work")
        if not work is Dictionary or work.size() != 3 or work.get("role") not in ["follow", "gather", "build"] or not work.get("target") is String or not _number(work.get("remaining"), 0, 4):
            return false
        if work.role == "follow":
            if work.target != "" or work.remaining != 0:
                return false
        elif ally.name.is_empty() or not data.camp.founded:
            return false
        elif work.role == "gather":
            if (work.target != "" and (not deposits.has(work.target) or deposits[work.target].outlying)) or work.remaining > ALLY.GATHER_SECONDS:
                return false
        elif not CAMP.STRUCTURES.has(work.target):
            return false
        if not ally.name.is_empty():
            if names.has(ally.name.to_lower()):
                return false
            names[ally.name.to_lower()] = true
        ids[ally.id] = true
    for enemy in data.enemies:
        if not enemy is Dictionary or not _id(enemy.get("id")) or ids.has(enemy.id) or not CODEC.known_kind(enemy.get("kind")) or not _position(enemy.get("position")) or not _position(enemy.get("home")):
            return false
        ids[enemy.id] = true
        if not _number(enemy.get("difficulty"), 0, 2, true) or not _number(enemy.get("maximum_hp"), 1, 1000000, true) or not _number(enemy.get("hp"), 0, enemy.maximum_hp, true) or not _number(enemy.get("immunity"), 0, 60) or not _number(enemy.get("state"), 0, 4, true) or not _number(enemy.get("state_time"), 0, 60) or not _id(enemy.get("target"), true):
            return false
        if (enemy.hp == 0) != (enemy.state == 4):
            return false
        if enemy.has("group_scaled") and not enemy.group_scaled is bool:
            return false
        if enemy.has("status") and not enemy.status in ["", "slow", "root", "stun", "dot"]:
            return false
        var credit: Variant = enemy.get("credit", {})
        if not credit is Dictionary or credit.size() > 256:
            return false
        var credited := 0
        for character in credit:
            if not _id(character) or not _number(credit[character], 1, enemy.maximum_hp, true):
                return false
            credited += int(credit[character])
        if credited > enemy.maximum_hp:
            return false
    # Pending respawns (v17): known kinds, never for a living creature, one entry per ID.
    if not data.get("respawns") is Array or data.respawns.size() > RESPAWNER.MAX_PENDING:
        return false
    var respawning: Dictionary = {}
    for entry in data.respawns:
        if not entry is Dictionary or entry.size() != 5 or not _id(entry.get("id")) or respawning.has(entry.id) or not CODEC.known_kind(entry.get("kind")) or not _number(entry.get("difficulty"), 0, 2, true) or not _position(entry.get("home")) or not _number(entry.get("remaining"), 0, RESPAWNER.RESPAWN_SECONDS):
            return false
        if data.enemies.any(func(enemy): return enemy.id == entry.id and enemy.hp > 0):
            return false
        # Only a defeated creature may share its ID with a pending respawn.
        if ids.has(entry.id) and not data.enemies.any(func(enemy): return enemy.id == entry.id):
            return false
        respawning[entry.id] = true
    # Ground loot (v19).
    if not data.get("loot") is Array or data.loot.size() > SOURCES.MAX_LOOT:
        return false
    for entry in data.loot:
        if not SOURCES.valid_loot(entry) or not _position(entry.position) or ids.has(entry.id) or respawning.has(entry.id):
            return false
        if item_ids.has(entry.item.id):
            return false
        item_ids[entry.item.id] = true
        ids[entry.id] = true
    for pickup in data.pickups:
        if not pickup is Dictionary or pickup.size() != 5 or not _id(pickup.get("id")) or ids.has(pickup.id) or respawning.has(pickup.id) or not _position(pickup.get("position")) or not _number(pickup.get("amount"), 0.000001, 1000000):
            return false
        if not _id(pickup.get("owner"), true) or not _number(pickup.get("claim_until"), 0, 1e12):
            return false
        ids[pickup.id] = true
    # Defeated characters' bags (v21).
    if not data.get("piles") is Array or data.piles.size() > PILE.MAX_PILES:
        return false
    for pile in data.piles:
        if not PILE.valid(pile) or not _position(pile.position) or ids.has(pile.id) or not _id(pile.owner, true):
            return false
        for item in pile.items:
            if item_ids.has(item.id):
                return false
            item_ids[item.id] = true
        ids[pile.id] = true
    # Merchants' stock and the travelling merchant's schedule (v23).
    if not WORLD_TRADE.valid_state(data.get("trade")):
        return false
    # Ship invitations and crews (v24).
    if not HARBOURS.valid_state(data.get("harbours")):
        return false
    # M16: houses and inn rooms (v41) of this world's characters.
    if not HOUSING.valid_state(data.get("housing"), data.players):
        return false
    # M14a: guilds (v40) of this world's characters.
    if not GUILDS.valid_state(data.get("guilds"), data.players):
        return false
    # Parties and party invitations of this world's characters (v25).
    if not PARTY.valid_state(data.get("party")):
        return false
    for party in data.party.parties.values():
        if party.members.any(func(id): return not data.players.has(id)):
            return false
    # The wish orbs and the tournament (v26).
    if not KI_REALM.valid_state(data.get("realm")):
        return false
    # The monster horde's siege (v30).
    if not SIEGE.valid_state(data.get("siege")):
        return false
    return true

static func migrate(data: Variant) -> Variant:
    if not data is Dictionary:
        return null
    # The first draft schema lacked progression dictionaries and loadout state.
    if data.get("version") == 0:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 1
        data["progression"] = data.get("progression", {"quests": {}, "settlements": {}, "world_time": 0.0})
        for state in data.get("players", {}).values():
            if not state is Dictionary or not state.get("skill_ids", []) is Array:
                return null
            state["progression"] = state.get("progression", {"level": 1, "experience": 0, "race": "Slime", "quests": {}, "equipment": {}})
            state["slots"] = state.get("slots", [state.get("skill_ids", [])[0] if not state.get("skill_ids", []).is_empty() else "", "", ""])
    if data.get("version") == 1:
        data = data.duplicate(true)
        data.version = 2
        data["allies"] = data.get("allies", [{"id": "ally_goblin_1", "position": [220.0, 360.0], "owner": "", "name": "", "race": "Goblin", "maximum_hp": 30, "power": 4, "speed": 45.0}])
    if data.get("version") == 2:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 3
        for state in data.players.values():
            if not state is Dictionary:
                return null
            state["exhaustion"] = state.get("exhaustion", {"active": false, "remaining": 0.0})
    if data.get("version") == 3:
        data = data.duplicate(true)
        data.version = 4
        data["camp"] = data.get("camp", CAMP.initial_state())
    if data.get("version") == 4:
        if not data.get("allies") is Array:
            return null
        data = data.duplicate(true)
        data.version = 5
        for ally in data.allies:
            if not ally is Dictionary:
                return null
            ally["work"] = ally.get("work", {"role": "follow", "target": "", "remaining": 0.0})
    # v6 adds untouched outlying deposits, essence stock and the storehouse/shrine.
    if data.get("version") == 5:
        if not data.get("camp") is Dictionary or not data.camp.get("deposits") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 6
        var fresh: Dictionary = CAMP.initial_state()
        for key in ["essence", "essence_offered", "storehouse", "shrine"]:
            data.camp[key] = data.camp.get(key, fresh[key])
        for id in fresh.deposits:
            data.camp.deposits[id] = data.camp.deposits.get(id, fresh.deposits[id])
    # v7 adds per-character unlock evidence. Rebuild only the analyses implied by skills the
    # character actually knows; never invent trials, mastery or ascensions.
    if data.get("version") == 6:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 7
        for state in data.players.values():
            if not state is Dictionary or not state.get("skill_ids", []) is Array:
                return null
            var evidence: Dictionary = SKILLS.empty_evidence()
            for skill in state.get("skill_ids", []):
                var rule: Dictionary = SKILLS.RULES.get(skill, {})
                if rule.has("analysis") and not rule.analysis in evidence.analyzed:
                    evidence.analyzed.append(rule.analysis)
            state["skill_evidence"] = state.get("skill_evidence", evidence)
    # v8 adds the Thornback Gnasher encounter to existing worlds, alive and at home.
    if data.get("version") == 7:
        if not data.get("enemies") is Array:
            return null
        data = data.duplicate(true)
        data.version = 8
        var present := false
        for enemy in data.enemies:
            present = present or (enemy is Dictionary and enemy.get("id") == THORNBACK.id)
        if not present:
            data.enemies.append(THORNBACK.duplicate(true))
    # v9 adds each character's mimic form; everyone starts as the base form.
    if data.get("version") == 8:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 9
        for state in data.players.values():
            if not state is Dictionary:
                return null
            state["form"] = state.get("form", {"id": FORMS.BASE, "cooldown": 0.0})
    # v10: a fourth hotbar slot and the armed Predator Focus timer.
    if data.get("version") == 9:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 10
        for state in data.players.values():
            if not state is Dictionary or not state.get("slots") is Array or not state.get("analysis") is Dictionary:
                return null
            while state.slots.size() < 4:
                state.slots.append("")
            state.analysis["focus"] = state.analysis.get("focus", 0.0)
    # v11: gradual healing from absorbed vitality.
    if data.get("version") == 10:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 11
        for state in data.players.values():
            if not state is Dictionary or not state.get("health") is Dictionary:
                return null
            state.health["regen_rate"] = state.health.get("regen_rate", 0.0)
            state.health["regen_left"] = state.health.get("regen_left", 0.0)
    # v12: save-slot meta. Older single-slot worlds get a neutral name and seed 0.
    if data.get("version") == 11:
        data = data.duplicate(true)
        data.version = 12
        data["meta"] = data.get("meta", {"name": "Earlier world", "seed": 0, "created": 0, "last_played": 0})
        # Fractional healing progress is saved from v12 on (Codex review of 16b).
        if not data.get("players") is Dictionary:
            return null
        for state in data.players.values():
            if not state is Dictionary or not state.get("health") is Dictionary:
                return null
            state.health["regen_carry"] = state.health.get("regen_carry", 0.0)
    # v13 lays worlds out from their seed (16d). Existing worlds were generated on the reference
    # map, so they keep it: `seeded: false` (their seed is still shown and kept).
    if data.get("version") == 12:
        if data.has("meta") and not data.meta is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 13
        if data.has("meta"):
            data.meta["seeded"] = data.meta.get("seeded", false)
    # v14 makes experience and levels real (step 17). Keep each character's level (raising
    # experience to that level's threshold if needed) and grant one skill point per level above 1.
    if data.get("version") == 13:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 14
        for state in data.players.values():
            if not state is Dictionary or not state.get("progression") is Dictionary:
                return null
            var progression: Dictionary = state.progression
            if not _number(progression.get("level"), 1, 1000, true) or not _number(progression.get("experience"), 0, 1000000000, true):
                return null
            var level: int = mini(int(progression.level), LEVELING.OLD_LEVEL_CAP)
            # Bracket keys: dot assignment would add a StringName key, which saves reject.
            # The step-17 curve this version was written for (v22 converts to the 24b curve).
            progression["experience"] = clampi(int(progression.experience), LEVELING.old_xp_for_level(level), LEVELING.old_xp_for_level(LEVELING.OLD_LEVEL_CAP))
            progression["level"] = LEVELING.old_level_for(progression.experience)
            progression["skill_points"] = progression.level - 1
    # v15 adds the skill tree (17c). Every level now grants a point (level 1 included), so each
    # character gains one; skills they could already use stay active for free.
    if data.get("version") == 14:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 15
        for state in data.players.values():
            if not state is Dictionary or not state.get("progression") is Dictionary or not state.get("skill_ids") is Array:
                return null
            state.progression["skill_points"] = int(state.progression.get("skill_points", 0)) + 1
            state.progression["tree"] = {"nodes": [], "active": state.skill_ids.duplicate(), "free": state.skill_ids.duplicate()}
    # v16 (17d): Extra skills come only from fusion and replace their two skills. Characters who
    # held an Extra together with its parts keep the Extra; the parts become its (splittable)
    # components. Activations move to the parts: both count as activated (free if newly added),
    # and a paid activation of the Extra itself is refunded.
    if data.get("version") == 15:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 16
        for state in data.players.values():
            if not state is Dictionary or not state.get("skill_ids") is Array or not state.get("slots") is Array or not state.get("progression") is Dictionary or not state.progression.get("tree") is Dictionary:
                return null
            var tree: Dictionary = state.progression.tree
            if not tree.get("active") is Array or not tree.get("free") is Array:
                return null
            for fused in SKILLS.RULES:
                if not SKILLS.is_fused(fused) or not fused in state.skill_ids:
                    continue
                for part in SKILLS.components(fused):
                    state.skill_ids.erase(part)
                    var slot: int = state.slots.find(part)
                    if slot >= 0:
                        state.slots[slot] = ""
                    if not part in tree.active:
                        tree.active.append(part)
                        tree.free.append(part)
                if fused in tree.active:
                    if not fused in tree.free:
                        state.progression["skill_points"] = int(state.progression.get("skill_points", 0)) + 1
                    tree.active.erase(fused)
                    tree.free.erase(fused)
    # v17 (17d2): creatures respawn. Seeded creatures that were absorbed (missing) or lie defeated
    # get a pending respawn at their home, so older worlds are not left empty.
    if data.get("version") == 16:
        if not data.get("enemies") is Array:
            return null
        data = data.duplicate(true)
        data.version = 17
        var layout: Dictionary = LAYOUT.generate(LAYOUT.seed_of(data.meta) if data.get("meta") is Dictionary else 0)
        var respawns: Array = []
        for id in LAYOUT.CREATURE_IDS:
            var saved: Variant = null
            for enemy in data.enemies:
                if enemy is Dictionary and enemy.get("id") == id:
                    saved = enemy
            if saved != null and saved.get("hp") != 0:
                continue
            var spot: Dictionary = layout.creatures[id]
            respawns.append({"id": id, "kind": "thornback" if id.begins_with("thornback") else "gnasher", "difficulty": int(saved.difficulty) if saved != null else int(spot.difficulty), "home": saved.home if saved != null else [spot.position.x, spot.position.y], "remaining": RESPAWNER.RESPAWN_SECONDS})
        data["respawns"] = respawns
    # v18 (17e): gear. Every character starts with no items; the reserved equipment dictionary
    # was always empty, so it is reset to {} (no item could be referenced before).
    if data.get("version") == 17:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 18
        for state in data.players.values():
            if not state is Dictionary or not state.get("progression") is Dictionary:
                return null
            state["gear"] = {"items": [], "cooldowns": {}}
            state.progression["equipment"] = {}
    # v19 (17g): ground loot, the camp forge and per-character opened chests.
    if data.get("version") == 18:
        if not data.get("players") is Dictionary or not data.get("camp") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 19
        data["loot"] = []
        data.camp["forge"] = false
        for state in data.players.values():
            if not state is Dictionary or not state.get("progression") is Dictionary:
                return null
            state.progression["chests"] = []
    # v20 (M4.5b): the regions' content. Untouched region deposits and fresh region creatures are
    # added to older worlds (nothing else changes; opened chests stay as they are).
    if data.get("version") == 19:
        if not data.get("camp") is Dictionary or not data.camp.get("deposits") is Dictionary or not data.get("enemies") is Array:
            return null
        data = data.duplicate(true)
        data.version = 20
        for id in REGION.deposits():
            data.camp.deposits[id] = data.camp.deposits.get(id, REGION.deposits()[id].amount)
        for entry in REGION.CREATURES:
            if not data.enemies.any(func(enemy): return enemy is Dictionary and enemy.get("id") == entry[0]):
                data.enemies.append(_legacy_region_enemy(entry))
    # v21 (24a): owners on loot and Magicule drops (none before), item piles, refilling region
    # deposits and the hidden leveling spots' creatures.
    if data.get("version") == 20:
        if not data.get("camp") is Dictionary or not data.get("enemies") is Array or not data.get("pickups") is Array:
            return null
        data = data.duplicate(true)
        data.version = 21
        for list in [data.get("loot", []), data.pickups]:
            for entry in list:
                if entry is Dictionary:
                    entry["owner"] = ""
                    entry["claim_until"] = 0.0
        data["piles"] = []
        data.camp["refills"] = {}
        data.camp["refill_left"] = {}
        for entry in REGION.spot_creatures():
            if not data.enemies.any(func(enemy): return enemy is Dictionary and enemy.get("id") == entry[0]):
                data.enemies.append(_legacy_region_enemy(entry))
    # v22 (24b): the new XP curve. Every character keeps its level, skill points and its progress
    # within the level (as a fraction of the old span); creatures' HP grows with their level.
    if data.get("version") == 21:
        if not data.get("players") is Dictionary or not data.get("enemies") is Array:
            return null
        data = data.duplicate(true)
        data.version = 22
        for state in data.players.values():
            if not state is Dictionary or not state.get("progression") is Dictionary:
                return null
            var progression: Dictionary = state.progression
            if not _number(progression.get("level"), 1, LEVELING.OLD_LEVEL_CAP, true) or not _number(progression.get("experience"), 0, 1000000000, true):
                return null
            var level: int = int(progression.level)
            if level >= LEVELING.OLD_LEVEL_CAP:
                progression["experience"] = LEVELING.xp_for_level(LEVELING.OLD_LEVEL_CAP)
                continue
            var old_floor: int = LEVELING.old_xp_for_level(level)
            var old_span: int = LEVELING.old_xp_for_level(level + 1) - old_floor
            var fraction: float = clampf(float(int(progression.experience) - old_floor) / float(old_span), 0.0, 0.999)
            var new_floor: int = LEVELING.xp_for_level(level)
            progression["experience"] = new_floor + int(floor(fraction * (LEVELING.xp_for_level(level + 1) - new_floor)))
        var gnasher := preload("res://scripts/enemies/forest_gnasher.gd")
        for enemy in data.enemies:
            if not enemy is Dictionary or not _number(enemy.get("difficulty"), 0, 2, true) or not enemy.get("id") is String:
                return null
            var full: int = gnasher.scaled_health(int(enemy.difficulty), REGION.level_of(enemy.id, int(enemy.difficulty)))
            if not _number(enemy.get("maximum_hp"), 1, 1000000, true) or not _number(enemy.get("hp"), 0, enemy.maximum_hp, true):
                return null
            var old_max: int = int(enemy.maximum_hp)
            var new_max: int = int(round(full * float(old_max) / gnasher.TIER_STATS[int(enemy.difficulty)].health))
            var factor: float = float(new_max) / old_max
            enemy["maximum_hp"] = new_max
            enemy["hp"] = maxi(1, int(round(int(enemy.hp) * factor))) if int(enemy.hp) > 0 else 0
            if enemy.get("credit") is Dictionary:
                for character in enemy.credit:
                    if not _number(enemy.credit[character], 1, old_max, true):
                        return null
                    enemy.credit[character] = int(floor(float(enemy.credit[character]) * factor))
    # v23 (M4.5c): an empty purse and no read scrolls for every character, the camp's stall,
    # smithy and staff, the merchants' state, and the new regions' creatures.
    if data.get("version") == 22:
        if not data.get("players") is Dictionary or not data.get("camp") is Dictionary or not data.get("enemies") is Array:
            return null
        data = data.duplicate(true)
        data.version = 23
        for state in data.players.values():
            if not state is Dictionary or not state.get("progression") is Dictionary or not state.get("skill_evidence") is Dictionary:
                return null
            state.progression["zeni"] = state.progression.get("zeni", 0)
            state.skill_evidence["scrolls"] = state.skill_evidence.get("scrolls", [])
        data.camp["stall"] = data.camp.get("stall", false)
        data.camp["smithy"] = data.camp.get("smithy", false)
        data.camp["staff"] = data.camp.get("staff", {"trader": false, "smith": false})
        data["trade"] = data.get("trade", WORLD_TRADE.initial_state())
        for entry in REGION.all_creatures():
            if not data.enemies.any(func(enemy): return enemy is Dictionary and enemy.get("id") == entry[0]):
                data.enemies.append(REGION.fresh_enemy(entry))
    # v24 (M4.5d): no ship, pass, tools, mounts or augments yet; the camp's tool yield; harbours.
    if data.get("version") == 23:
        if not data.get("players") is Dictionary or not data.get("camp") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 24
        for state in data.players.values():
            if not state is Dictionary or not state.get("progression") is Dictionary:
                return null
            var defaults := {"ship": {"owned": false, "at": ""}, "ferry_pass_until": 0.0, "tools": {"axe": 0, "pickaxe": 0, "rod": 0}, "mounts": [], "mount": "", "augments": []}
            for key in defaults:
                state.progression[key] = state.progression.get(key, defaults[key])
        data.camp["tool_yield"] = data.camp.get("tool_yield", {"wood": 0, "stone": 0})
        data["harbours"] = data.get("harbours", HARBOURS.initial_state())
    # v25 (M4.6): no parties yet.
    if data.get("version") == 24:
        data = data.duplicate(true)
        data.version = 25
        data["party"] = data.get("party", PARTY.initial_state())
    # v26 (M4.7): no transformations, wish points or titles yet; the orbs at their first spots.
    if data.get("version") == 25:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 26
        for state in data.players.values():
            if not state is Dictionary or not state.get("progression") is Dictionary:
                return null
            var defaults := {"auras": [], "aura": "", "bonus_points": 0, "champion": false}
            for key in defaults:
                state.progression[key] = state.progression.get(key, defaults[key])
        data["realm"] = data.get("realm", KI_REALM.initial_state())
    # v27 (M5a): the camp has no nation yet (no name, banner, tier or placed buildings).
    if data.get("version") == 26:
        if not data.get("camp") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 27
        data.camp["nation"] = data.camp.get("nation", preload("res://scripts/nation/nation_catalogue.gd").initial_state())
    # v28 (M5b): no citizens, fields or food yet.
    if data.get("version") == 27:
        if not data.get("camp") is Dictionary or not data.camp.get("nation") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 28
        var fresh: Dictionary = preload("res://scripts/nation/nation_catalogue.gd").initial_state()
        for key in fresh:
            if not data.camp.nation.has(key):
                data.camp.nation[key] = fresh[key]
    # v29 (M5c): citizens without jobs; no goods, treasury or caravan yet.
    if data.get("version") == 28:
        if not data.get("camp") is Dictionary or not data.camp.get("nation") is Dictionary or not data.camp.nation.get("citizens") is Array:
            return null
        data = data.duplicate(true)
        data.version = 29
        var blank: Dictionary = preload("res://scripts/nation/nation_catalogue.gd").initial_state()
        for key in blank:
            if not data.camp.nation.has(key):
                data.camp.nation[key] = blank[key]
        for citizen in data.camp.nation.citizens:
            if citizen is Dictionary and not citizen.has("job"):
                citizen["job"] = ""
    # v30 (M5d): no siege yet.
    if data.get("version") == 29:
        data = data.duplicate(true)
        data.version = 30
        data["siege"] = data.get("siege", SIEGE.initial_state())
    # v31 (user request: a much bigger Ki Realm): realm creatures move to their new homes, the
    # new ones arrive, and characters standing in the old small realm move to Dome City.
    if data.get("version") == 30:
        if not data.get("enemies") is Array or not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 31
        var map := preload("res://scripts/world/world_map.gd")
        var realm_catalogue := preload("res://scripts/realm/realm_catalogue.gd")
        var old_realm := Rect2i(-398, -254, 246, 166)
        for entry in REGION.all_creatures():
            var home: Vector2 = REGION.at(entry[2])
            if not map.REALM_RECT.has_point(map.to_tile(home)):
                continue
            var found := false
            for enemy in data.enemies:
                if enemy is Dictionary and enemy.get("id") == entry[0]:
                    enemy.position = [home.x, home.y]
                    enemy.home = [home.x, home.y]
                    found = true
            if not found:
                data.enemies.append(REGION.fresh_enemy(entry).merged({"credit": {}, "group_scaled": false, "status": ""}))
            for pending in data.get("respawns", []):
                if pending is Dictionary and pending.get("id") == entry[0]:
                    pending.home = [home.x, home.y]
        var arrival: Vector2 = map.to_world(realm_catalogue.ARRIVAL_TILE)
        for state in data.players.values():
            if state is Dictionary and state.get("position") is Array and state.position.size() == 2:
                var tile := map.to_tile(Vector2(float(state.position[0]), float(state.position[1])))
                if old_realm.has_point(tile):
                    state.position = [arrival.x, arrival.y]
    # v32 (M6a): no profession experience yet; bags grow to 100 units.
    if data.get("version") == 31:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 32
        for state in data.players.values():
            if not state is Dictionary or not state.get("progression") is Dictionary:
                return null
            if not state.progression.get("professions") is Dictionary:
                state.progression["professions"] = preload("res://scripts/professions/profession_catalogue.gd").initial_state()
            if not state.progression.get("fish_log") is Dictionary:
                state.progression["fish_log"] = {}
            if state.get("inventory") is Dictionary and (state.inventory.get("capacity") is int or state.inventory.get("capacity") is float):
                state.inventory["capacity"] = maxi(100, int(state.inventory.capacity))
    # v33 (M7a): the raid bosses arrive at their arenas.
    if data.get("version") == 32:
        if not data.get("enemies") is Array:
            return null
        data = data.duplicate(true)
        data.version = 33
        var bosses := preload("res://scripts/bosses/boss_catalogue.gd")
        for id in bosses.RAID:
            if not data.enemies.any(func(enemy): return enemy is Dictionary and enemy.get("id") == id):
                data.enemies.append(fresh_boss(id))
    # v34 (M7b): the Eastern Reaches' creatures and bosses arrive; the Ki Realm's creatures (and
    # its bosses) move up to their new levels (living ones at full health for it).
    if data.get("version") == 33:
        if not data.get("enemies") is Array:
            return null
        data = data.duplicate(true)
        data.version = 34
        var map := preload("res://scripts/world/world_map.gd")
        var gnasher := preload("res://scripts/enemies/forest_gnasher.gd")
        var bosses := preload("res://scripts/bosses/boss_catalogue.gd")
        for entry in REGION.all_creatures():
            if not data.enemies.any(func(enemy): return enemy is Dictionary and enemy.get("id") == entry[0]):
                data.enemies.append(REGION.fresh_enemy(entry).merged({"credit": {}, "group_scaled": false, "status": ""}))
        for id in bosses.RAID:
            if not data.enemies.any(func(enemy): return enemy is Dictionary and enemy.get("id") == id):
                data.enemies.append(fresh_boss(id))
        for enemy in data.enemies:
            if not enemy is Dictionary or not enemy.get("home") is Array or enemy.home.size() != 2 or int(enemy.get("hp", 0)) <= 0:
                continue
            if not map.in_realm(Vector2(float(enemy.home[0]), float(enemy.home[1]))):
                continue
            var full: int = int(fresh_boss(enemy.id).maximum_hp) if bosses.is_boss(enemy.id) else gnasher.scaled_health(int(enemy.get("difficulty", 1)), REGION.level_of(enemy.id, int(enemy.get("difficulty", 1))))
            enemy["maximum_hp"] = full
            enemy["hp"] = full
            enemy["credit"] = {}
            enemy["group_scaled"] = false
    # v35 (M7c): the hidden elites, the dungeons' creatures and bosses arrive.
    if data.get("version") == 34:
        if not data.get("enemies") is Array:
            return null
        data = data.duplicate(true)
        data.version = 35
        var all_bosses := preload("res://scripts/bosses/boss_catalogue.gd")
        for entry in REGION.all_creatures():
            if not data.enemies.any(func(enemy): return enemy is Dictionary and enemy.get("id") == entry[0]):
                data.enemies.append(REGION.fresh_enemy(entry).merged({"credit": {}, "group_scaled": false, "status": ""}))
        for id in all_bosses.all_ids():
            if not data.enemies.any(func(enemy): return enemy is Dictionary and enemy.get("id") == id):
                data.enemies.append(fresh_boss(id))
    # v36 (M9b): the night stalkers arrive.
    if data.get("version") == 35:
        if not data.get("enemies") is Array:
            return null
        data = data.duplicate(true)
        data.version = 36
        for entry in REGION.night_creatures():
            if not data.enemies.any(func(enemy): return enemy is Dictionary and enemy.get("id") == entry[0]):
                data.enemies.append(REGION.fresh_enemy(entry).merged({"credit": {}, "group_scaled": false, "status": ""}))
    # v37 (M9d): the Eclipse Wyrm, the story's final boss, waits beneath the Sage Spire.
    if data.get("version") == 36:
        if not data.get("enemies") is Array:
            return null
        data = data.duplicate(true)
        data.version = 37
        if not data.enemies.any(func(enemy): return enemy is Dictionary and enemy.get("id") == "boss_eclipse_wyrm"):
            data.enemies.append(fresh_boss("boss_eclipse_wyrm"))
    # v38 (M11e): Cooking, Enchanting and Tailoring start at 0 for every character.
    if data.get("version") == 37:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 38
        for id in data.players:
            var state: Variant = data.players[id]
            if state is Dictionary and state.get("progression") is Dictionary and state.progression.get("professions") is Dictionary:
                for profession in ["cooking", "enchanting", "tailoring"]:
                    if not state.progression.professions.has(profession):
                        state.progression.professions[profession] = 0
    # v39 (M13b): the hotbar has eight slots; the four saved ones keep their places.
    if data.get("version") == 38:
        if not data.get("players") is Dictionary:
            return null
        data = data.duplicate(true)
        data.version = 39
        for id in data.players:
            var state: Variant = data.players[id]
            if state is Dictionary and state.get("slots") is Array and state.slots.size() == 4:
                state.slots.append_array(["", "", "", ""])
    # v40 (M14a): guilds.
    if data.get("version") == 39:
        data = data.duplicate(true)
        data.version = 40
        data["guilds"] = GUILDS.initial_state()
    # v41 (M16): houses and inn rooms.
    if data.get("version") == 40:
        data = data.duplicate(true)
        data.version = 41
        data["housing"] = HOUSING.initial_state()
    return data

## Saved enemy entry for a raid boss at full health in its arena (v33 and new worlds).
static func fresh_boss(id: String) -> Dictionary:
    var bosses := preload("res://scripts/bosses/boss_catalogue.gd")
    var gnasher := preload("res://scripts/enemies/forest_gnasher.gd")
    var spot: Vector2 = bosses.centre(id)
    var health: int = int(round(gnasher.scaled_health(2, bosses.level(id)) * bosses.health_factor(id)))
    return {"id": id, "kind": id, "position": [spot.x, spot.y], "home": [spot.x, spot.y], "difficulty": 2, "hp": health, "maximum_hp": health, "immunity": 0.0, "state": 0, "state_time": 0.0, "target": "", "credit": {}, "group_scaled": false, "status": ""}

static func _unique(values: Array) -> int:
    var seen := {}
    for value in values:
        seen[value] = true
    return seen.size()

## Entries introduced by older migrations must start on the old HP scale;
## the final v21->v22 step applies level/group scaling exactly once.
static func _legacy_region_enemy(entry: Array) -> Dictionary:
    var fresh := REGION.fresh_enemy(entry)
    fresh.maximum_hp = preload("res://scripts/enemies/forest_gnasher.gd").TIER_STATS[int(entry[3])].health
    fresh.hp = fresh.maximum_hp
    return fresh

static func _read(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null or file.get_length() > MAX_BYTES:
        return {}
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK:
        return {}
    var data: Variant = migrate(parser.data)
    return data if validate(data) else {}

static func load_world(path: String) -> Dictionary:
    var primary := _read(path)
    if not primary.is_empty():
        return {"ok": true, "data": primary, "recovered": false}
    var backup := _read(path + ".bak")
    if not backup.is_empty():
        return {"ok": true, "data": backup, "recovered": true}
    return {"ok": false, "data": {}, "recovered": false}

static func write_world(path: String, data: Dictionary) -> Error:
    if not validate(data):
        return ERR_INVALID_DATA
    var absolute := ProjectSettings.globalize_path(path)
    var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
    if error != OK:
        return error
    var temporary := absolute + ".tmp"
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(data))
    file.flush()
    error = file.get_error()
    file.close()
    if error != OK:
        return error
    if FileAccess.file_exists(absolute):
        # Preserve a valid previous save; never replace a good backup with corrupt data.
        if not _read(absolute).is_empty():
            error = DirAccess.copy_absolute(absolute, absolute + ".bak.tmp")
            if error == OK:
                error = DirAccess.rename_absolute(absolute + ".bak.tmp", absolute + ".bak")
            if error != OK:
                return error
        elif _read(absolute + ".bak").is_empty():
            return ERR_FILE_CORRUPT
    return DirAccess.rename_absolute(temporary, absolute)
