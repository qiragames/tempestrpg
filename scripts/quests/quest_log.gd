extends Node2D
## Quests in the world (M9c): the quest givers and bounty boards (drawn on every peer, with "!"
## for something new and "?" for something to hand in), and the host's quest rules — accepting,
## progress from game events (defeats, bosses, catches, gathering, crafting, dungeons) and from
## where characters stand (places, the camp, a night lived through), handing in and rewards.
## Each character's quests live in progression.quests: {id: {"s": step, "c": count, "done": bool,
## "n": night seen, "again": world time a bounty returns}} (saved with the character).
const QUESTS := preload("res://scripts/quests/quest_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const AUTHORITY := preload("res://scripts/network/authority.gd")
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
const DAY := preload("res://scripts/world/day_night.gd")
## M9e: achievements count the same game events.
const ACH := preload("res://scripts/progression/achievements.gd")

var world: Node2D
var _npcs: Dictionary = {}
var _check_left := 0.0
## Boards and markers draw above the y-sorted world.
var _overlay: Node2D

func _init(owner_world: Node2D = null) -> void:
    world = owner_world
    name = "Quests"
    y_sort_enabled = true

func _ready() -> void:
    _overlay = Node2D.new()
    _overlay.name = "Markers"
    _overlay.z_index = 5
    _overlay.draw.connect(_draw_overlay)
    add_child(_overlay)
    for id in QUESTS.NPCS:
        var npc := Node2D.new()
        npc.name = id
        npc.position = QUESTS.npc_position(id)
        var body := SPRITES.make(QUESTS.NPCS[id][1])
        npc.add_child(body)
        SPRITES.play(body, "idle_down")
        add_child(npc)
        _npcs[id] = npc

func session() -> Node:
    return get_node("/root/GameSession")

func world_time() -> float:
    return float(world.progression.get("world_time", 0.0)) if world != null else 0.0

static func quests_of(actor: Node) -> Dictionary:
    if not actor.progression.get("quests") is Dictionary:
        actor.progression["quests"] = {}
    return actor.progression.quests

static func entry(actor: Node, id: String) -> Dictionary:
    var value: Variant = quests_of(actor).get(id)
    return value if value is Dictionary else {}

static func active(actor: Node, id: String) -> bool:
    var state := entry(actor, id)
    return not state.is_empty() and not bool(state.get("done", false))

static func finished(actor: Node, id: String) -> bool:
    return bool(entry(actor, id).get("done", false))

## Whether a character may take a quest now.
func available(actor: Node, id: String) -> bool:
    var quest := QUESTS.quest(id)
    if quest.is_empty() or int(actor.progression.get("level", 1)) < int(quest.level):
        return false
    for required in quest.requires:
        if not finished(actor, required):
            return false
    var state := entry(actor, id)
    if state.is_empty():
        return true
    return quest.kind == "bounty" and bool(state.get("done", false)) and world_time() >= float(state.get("again", 0.0))

## The current step of an active quest ({} if none).
static func current_step(actor: Node, id: String) -> Dictionary:
    var quest := QUESTS.quest(id)
    var state := entry(actor, id)
    if quest.is_empty() or state.is_empty() or bool(state.get("done", false)):
        return {}
    var index := int(state.get("s", 0))
    return quest.steps[index] if index < quest.steps.size() else {}

## "Defeat 3 creatures (2/3)" for the HUD and the log.
static func objective(actor: Node, id: String) -> String:
    var step := current_step(actor, id)
    if step.is_empty():
        return ""
    var count := int(step.get("count", 0))
    if count > 1 and step.type != "bring":
        return "%s (%d/%d)" % [step.text, int(entry(actor, id).get("c", 0)), count]
    if step.type == "bring":
        return "%s (%d/%d)" % [step.text, mini(count, actor.get_node("Inventory").count_of(step.item)), count]
    return step.text

func _near(actor: Node2D, npc: String) -> bool:
    return npc == QUESTS.LUMI or actor.global_position.distance_to(QUESTS.npc_position(npc)) <= QUESTS.TALK_REACH

## The giver or board a character stands at ("" if none).
func nearest_npc(actor: Node2D) -> String:
    var best := ""
    var distance := QUESTS.TALK_REACH + 0.1
    var places: Array = QUESTS.NPCS.keys()
    for town in QUESTS.BOARD_TOWNS:
        places.append("board_" + town)
    for id in places:
        if QUESTS.is_staged(id) and not waiting_for(actor, id):
            continue
        var at: Vector2 = QUESTS.npc_position(id)
        var gap := actor.global_position.distance_to(at)
        if gap < distance:
            best = id
            distance = gap
    return best

## Whether one of a character's quests waits for them to talk to someone (staged characters show
## only then).
static func waiting_for(actor: Node, npc: String) -> bool:
    for id in quests_of(actor):
        if active(actor, id) and current_step(actor, id).get("type") == "talk" and current_step(actor, id).get("npc") == npc:
            return true
    return false

## The quest waiting for a decision ("" if none) — M9d, the story's ending.
static func choice_pending(actor: Node) -> String:
    for id in quests_of(actor):
        if active(actor, id) and current_step(actor, id).get("type") == "choice":
            return id
    return ""

## Host: decide (an option's key) for the quest waiting on a choice.
func choose(actor: Node2D, key: String) -> bool:
    if not AUTHORITY.can_mutate(actor):
        return false
    var id := choice_pending(actor)
    if id.is_empty():
        return false
    for option in current_step(actor, id).options:
        if option[1] == key:
            var state := entry(actor, id)
            state["pick"] = key
            _grant(actor, option[2])
            _advance(actor, id)
            session().queue_save()
            return true
    return false

## Host: take a quest at its giver.
func accept(actor: Node2D, id: String) -> bool:
    if not AUTHORITY.can_mutate(actor) or not available(actor, id):
        return false
    var quest := QUESTS.quest(id)
    if not _near(actor, quest.giver):
        return false
    quests_of(actor)[id] = {"s": 0, "c": 0, "done": false}
    session().notify_character(actor.character_id, "Quest accepted: %s." % quest.title)
    _check_places(actor)
    session().queue_save()
    return true

## Host: talk to someone — finishes "talk" steps for them and hands in "bring" steps to the giver.
func talk(actor: Node2D, npc: String) -> bool:
    if not AUTHORITY.can_mutate(actor) or not _near(actor, npc):
        return false
    var moved := false
    for id in quests_of(actor).keys():
        if not active(actor, id):
            continue
        var quest := QUESTS.quest(id)
        if quest.is_empty():
            continue
        while true:
            var step := current_step(actor, id)
            if step.is_empty():
                break
            if step.type == "talk" and step.npc == npc:
                _advance(actor, id)
                moved = true
            elif step.type == "bring" and quest.giver == npc and actor.get_node("Inventory").count_of(step.item) >= int(step.count):
                actor.get_node("Inventory").discard(StringName(step.item), int(step.count))
                _advance(actor, id)
                moved = true
            else:
                break
    if moved:
        session().queue_save()
    return moved

## Host: a game event for a character (see QuestCatalogue for the step types).
func on_event(actor: Node, kind: String, data: Dictionary) -> void:
    if not AUTHORITY.can_mutate(actor) or not is_instance_valid(actor):
        return
    ACH.record(actor, kind, data)
    # M14b: members' deeds count towards their guild's weekly quests.
    if world.get("guilds") != null:
        world.guilds.on_event(actor, kind, data)
    if world.get("dungeon_features") != null:
        world.dungeon_features.on_event(actor, kind, data)
    if world.get("events") != null:
        world.events.on_event(actor, kind, data)
    if world.get("pets") != null:
        world.pets.on_event(actor, kind, data)
    _quest_event(actor, kind, data)
    unlock(actor)

## Host: unlock new achievements (with a message for each).
func unlock(actor: Node) -> void:
    for id in ACH.check(actor):
        var spec: Array = ACH.ACHIEVEMENTS[id]
        session().notify_character(actor.character_id, "Achievement unlocked: %s!%s" % [spec[0], " New title: %s (Y)." % spec[3] if not String(spec[3]).is_empty() else ""])
        session().queue_save()

## Host: wear an unlocked achievement's title ("" takes it off).
func wear_title(actor: Node, id: String) -> bool:
    if not AUTHORITY.can_mutate(actor) or not (id.is_empty() or (ACH.has(actor, id) and not ACH.title_of(id).is_empty())):
        return false
    actor.progression["title"] = id
    session().queue_save()
    return true

func _quest_event(actor: Node, kind: String, data: Dictionary) -> void:
    for id in quests_of(actor).keys():
        var step := current_step(actor, id)
        if step.is_empty() or step.type != kind:
            continue
        var counts := false
        match kind:
            "kill":
                counts = (String(step.kind).is_empty() or step.kind == data.get("kind", "")) and (String(step.region).is_empty() or step.region == data.get("region", ""))
            "boss":
                counts = step.id == data.get("id", "")
            "dungeon":
                counts = step.id == data.get("id", "")
            "catch":
                counts = String(step.fish).is_empty() or step.fish == data.get("fish", "")
            "gather":
                counts = String(step.resource).is_empty() or step.resource == data.get("resource", "")
            "craft":
                counts = String(step.item).is_empty() or step.item == data.get("item", "")
        if not counts:
            continue
        var state := entry(actor, id)
        state["c"] = int(state.get("c", 0)) + int(data.get("amount", 1))
        if int(state.c) >= int(step.get("count", 1)):
            _advance(actor, id)
        session().queue_save()

## Next step (or done: rewards).
func _advance(actor: Node, id: String) -> void:
    var quest := QUESTS.quest(id)
    var state := entry(actor, id)
    state["s"] = int(state.get("s", 0)) + 1
    state["c"] = 0
    state["n"] = false
    if int(state.s) >= quest.steps.size():
        _complete(actor, id)
    else:
        session().notify_character(actor.character_id, "%s: %s" % [quest.title, quest.steps[int(state.s)].text])

func _complete(actor: Node, id: String) -> void:
    var quest := QUESTS.quest(id)
    var state := entry(actor, id)
    state["done"] = true
    if quest.kind == "bounty":
        state["again"] = world_time() + QUESTS.BOUNTY_SECONDS
        ACH.record(actor, "bounty", {})
        if world.get("guilds") != null:
            world.guilds.on_event(actor, "bounty", {})
    _grant(actor, quest.get("reward", {}))
    session().notify_character(actor.character_id, "Quest complete: %s!" % quest.title)

## Rewards: XP, Zeni, items, profession XP, a random piece of gear of a rarity, a unique.
func _grant(actor: Node, reward: Dictionary) -> void:
    if int(reward.get("xp", 0)) > 0:
        actor.gain_experience(int(reward.xp), "quest")
    if int(reward.get("zeni", 0)) > 0:
        actor.gain_zeni(int(reward.zeni), "quest")
    for item in reward.get("items", {}):
        actor.get_node("Inventory").add_material(item, int(reward.items[item]))
    for profession in reward.get("pro", {}):
        actor.gain_profession_xp(profession, int(reward.pro[profession]))
    if reward.has("gear"):
        var rng: RandomNumberGenerator = world.loot_rng
        var sources := preload("res://scripts/items/gear_sources.gd")
        var gear := preload("res://scripts/items/gear_catalogue.gd")
        var rarity := int(reward.gear)
        var item: Dictionary = gear.roll(sources._base(rng, [], rarity, int(actor.progression.get("level", 1))), rarity, rng)
        if not actor.add_item(item):
            world.drop_gear(item, actor.global_position + Vector2(0, 12), "", actor.character_id)
    if reward.has("unique"):
        var gear := preload("res://scripts/items/gear_catalogue.gd")
        var base: Dictionary = gear.BASES[reward.unique]
        var item: Dictionary = gear.roll(reward.unique, int(base.get("min_rarity", 5)), world.loot_rng)
        if not actor.add_item(item):
            world.drop_gear(item, actor.global_position + Vector2(0, 12), "", actor.character_id)

## Host: places, the camp and nights (checked twice a second).
func _check_places(actor: Node2D) -> void:
    for id in quests_of(actor).keys():
        var step := current_step(actor, id)
        if step.is_empty():
            continue
        match step.type:
            "reach":
                if actor.global_position.distance_to(MAP.to_world(step.tile)) <= float(step.radius) * MAP.TILE:
                    _advance(actor, id)
            "camp":
                if world.get("camp") != null and actor.global_position.distance_to(world.camp.SITE) <= 90.0:
                    _advance(actor, id)
            "night":
                var state := entry(actor, id)
                if DAY.is_night(world_time()):
                    state["n"] = true
                elif bool(state.get("n", false)):
                    _advance(actor, id)

func _process(delta: float) -> void:
    if world == null:
        return
    _overlay.queue_redraw()
    if session().replica_world:
        return
    _check_left -= delta
    if _check_left > 0.0:
        return
    _check_left = 0.5
    for actor in world.get_children():
        if actor is CharacterBody2D and actor.is_in_group("player") and actor.get_node("Health").current > 0:
            # Everyone's story starts with Lumi.
            if entry(actor, "main_0").is_empty():
                quests_of(actor)["main_0"] = {"s": 0, "c": 0, "done": false}
            _check_places(actor)
            # M9e: lands visited; level, Zeni, professions and quests unlock achievements too.
            ACH.record(actor, "region", {"region": MAP.region_name(actor.global_position)})
            unlock(actor)

## "!" (something to take), "?" (something to hand in) above givers for this peer's character.
func marker(actor: Node, npc: String) -> String:
    for id in quests_of(actor):
        if not active(actor, id):
            continue
        var step := current_step(actor, id)
        var quest := QUESTS.quest(id)
        if (step.get("type") == "talk" and step.get("npc") == npc) or (step.get("type") == "bring" and quest.get("giver") == npc and actor.get_node("Inventory").count_of(step.item) >= int(step.count)):
            return "?"
    for id in QUESTS.offered_by(npc):
        if available(actor, id):
            return "!"
    return ""

func _draw_overlay() -> void:
    var me: Node2D = world.get_local_player() if world != null else null
    if not is_instance_valid(me):
        return
    var font := ThemeDB.fallback_font
    for town in QUESTS.BOARD_TOWNS:
        var at: Vector2 = QUESTS.npc_position("board_" + town)
        if at.distance_to(me.global_position) > 700.0:
            continue
        # A wooden notice board with pinned papers.
        _overlay.draw_rect(Rect2(at + Vector2(-9, -16), Vector2(18, 12)), Color("8a6440"))
        _overlay.draw_rect(Rect2(at + Vector2(-8, -15), Vector2(16, 10)), Color("b58a5a"))
        for paper in [Vector2(-6, -14), Vector2(-1, -13), Vector2(3, -14)]:
            _overlay.draw_rect(Rect2(at + paper, Vector2(4, 5)), Color("f0e6c8"))
        _overlay.draw_line(at + Vector2(-7, -4), at + Vector2(-7, 4), Color("6b4a2b"), 2.0)
        _overlay.draw_line(at + Vector2(7, -4), at + Vector2(7, 4), Color("6b4a2b"), 2.0)
        _draw_marker(at + Vector2(0, -22), marker(me, "board_" + town), font)
    # M9e: worn titles above characters' heads.
    for character in world.get_children():
        if character is CharacterBody2D and character.is_in_group("player") and character.visible and character.global_position.distance_to(me.global_position) < 400.0:
            var title := ACH.worn_title(character)
            if not title.is_empty():
                var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
                var spot: Vector2 = character.global_position + Vector2(-width / 2.0, -26)
                _overlay.draw_string_outline(font, spot, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.05, 0.04, 0.02))
                _overlay.draw_string(font, spot, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("ffe08a"))
    for id in _npcs:
        var npc: Node2D = _npcs[id]
        # The Court's people show themselves only to whoever has come to face them.
        npc.visible = not QUESTS.is_staged(id) or waiting_for(me, id)
        if npc.visible and npc.position.distance_to(me.global_position) < 700.0:
            _draw_marker(npc.position + Vector2(0, -22), marker(me, id), font)

func _draw_marker(at: Vector2, mark: String, font: Font) -> void:
    if mark.is_empty():
        return
    var colour := Color("ffd84a") if mark == "!" else Color("8fe8ff")
    var bob := sin(Time.get_ticks_msec() / 250.0) * 1.5
    _overlay.draw_string_outline(font, at + Vector2(-3, bob), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0.05, 0.04, 0.02))
    _overlay.draw_string(font, at + Vector2(-3, bob), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, colour)
