extends Node2D
## Dungeon variety (M11b, user request): spike traps on the rope bridges, two levers that open the
## sealed door of the boss chamber, a locked vault opened with the dungeon's key (the Keeper of the
## second hall may drop it) and a Heroic mode chosen at the cave mouth (creatures and boss eight
## levels stronger, a Legendary piece from the heroic boss). The host keeps each dungeon's state in
## the world's progression ("dungeons": {id: {"levers": [bool, bool], "heroic": bool, "empty":
## seconds nobody was inside}}) — so it reaches every peer with the snapshots and is saved; when a
## dungeon has been empty for a minute its levers fall back and its mode is chosen anew. Traps run on
## the shared world time (every peer draws the same thing).
const DUNGEONS := preload("res://scripts/dungeons/dungeon_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const AUTHORITY := preload("res://scripts/network/authority.gd")

const REACH := 28.0
## Spike traps: a cycle, the warning before the spikes and how long they stay up.
const TRAP_CYCLE := 3.0
const TRAP_WARN := 0.7
const TRAP_UP := 0.5
## Share of the maximum health a trap takes (more in Heroic).
const TRAP_DAMAGE := 0.1
const TRAP_DAMAGE_HEROIC := 0.15
const KEY_CHANCE := 0.5
const RESET_SECONDS := 60.0

var world: Node2D
var _doors: Dictionary = {}
var _hit_cooldown: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _init(owner_world: Node2D = null) -> void:
    world = owner_world
    name = "DungeonFeatures"
    z_index = 1
    _rng.randomize()

func _ready() -> void:
    # The sealed doors: a wall across the bridge into each boss chamber while it is closed.
    for id in DUNGEONS.ORDER:
        var door := StaticBody2D.new()
        door.name = "Door_" + id
        door.collision_layer = 1
        var shape := CollisionShape2D.new()
        var rect := RectangleShape2D.new()
        rect.size = Vector2(DUNGEONS.BRIDGE_WIDTH * MAP.TILE + 8, 10)
        shape.shape = rect
        door.add_child(shape)
        door.position = door_position(id)
        add_child(door)
        _doors[id] = door

## --- Places (world positions).
static func lever_position(id: String, index: int) -> Vector2:
    var side := -6.0 if index == 0 else 6.0
    return _open_spot(DUNGEONS.rooms(id)[1 + index][0], [Vector2(side, -4), Vector2(-side, -4), Vector2(side, 4), Vector2(0, -5)])

static func vault_position(id: String) -> Vector2:
    return _open_spot(DUNGEONS.rooms(id)[1][0], [Vector2(6, 5), Vector2(-6, 5), Vector2(0, 5), Vector2(5, -5)])

## The first of a room's candidate spots that is open floor (world position of its tile centre).
static func _open_spot(centre: Vector2, offsets: Array) -> Vector2:
    for offset in offsets:
        var tile: Vector2 = centre + offset
        if not MAP.solid(int(tile.x), int(tile.y)):
            return MAP.to_world(tile) + Vector2(8, 8)
    return MAP.to_world(centre) + Vector2(8, 8)

static func door_position(id: String) -> Vector2:
    var chamber: Array = DUNGEONS.rooms(id)[3]
    return MAP.to_world(chamber[0] + Vector2(0, -chamber[1].y - 1)) + Vector2(8, 8)

## Trap spots: the middle of every long rope-bridge stretch, [centre, horizontal?].
static func traps(id: String) -> Array:
    var all: Array = []
    for rect in DUNGEONS.bridges(id):
        if rect.size.x >= 6:
            all.append([MAP.to_world(Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y + rect.size.y / 2.0)), false])
        elif rect.size.y >= 6:
            all.append([MAP.to_world(Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y + rect.size.y / 2.0)), true])
    return all

static func key_item(id: String) -> String:
    return "key_" + id

static func is_key(item: String) -> bool:
    return item.begins_with("key_") and DUNGEONS.DUNGEONS.has(item.trim_prefix("key_"))

static func key_name(item: String) -> String:
    return "%s Key" % DUNGEONS.DUNGEONS[item.trim_prefix("key_")][0]

## The creature that may drop a dungeon's key: the elite of the second hall.
static func keeper(id: String) -> String:
    return "dg_%s_2_3" % id

## --- Shared state.
func state(id: String) -> Dictionary:
    if not world.progression.get("dungeons") is Dictionary:
        world.progression["dungeons"] = {}
    var all: Dictionary = world.progression.dungeons
    if not all.get(id) is Dictionary:
        all[id] = {"levers": [false, false], "heroic": false, "empty": 0.0}
    return all[id]

func door_open(id: String) -> bool:
    var levers: Variant = state(id).get("levers")
    return levers is Array and levers.size() == 2 and bool(levers[0]) and bool(levers[1])

func heroic(id: String) -> bool:
    return bool(state(id).get("heroic", false))

func inside(id: String) -> Array:
    return get_tree().get_nodes_in_group("player").filter(func(actor): return actor.get_parent() == world and DUNGEONS.at_tile(MAP.to_tile(actor.global_position)) == id)

## Trap phase at a world time: 0 resting, 1 warning, 2 spikes up.
static func trap_phase(time: float, index: int) -> int:
    var t := fposmod(time + index * 0.9, TRAP_CYCLE)
    if t >= TRAP_CYCLE - TRAP_UP:
        return 2
    if t >= TRAP_CYCLE - TRAP_UP - TRAP_WARN:
        return 1
    return 0

func world_time() -> float:
    return float(world.progression.get("world_time", 0.0))

## --- Host actions (the "dungeon" intent).
## What a character stands at: ["lever", id, index], ["vault", id] or [].
func nearest(actor: Node2D) -> Array:
    for id in DUNGEONS.ORDER:
        for index in range(2):
            if actor.global_position.distance_to(lever_position(id, index)) <= REACH:
                return ["lever", id, index]
        if actor.global_position.distance_to(vault_position(id)) <= REACH:
            return ["vault", id]
    return []

func pull(actor: Node2D, id: String, index: int) -> bool:
    if not AUTHORITY.can_mutate(actor) or not DUNGEONS.DUNGEONS.has(id) or index < 0 or index > 1 or actor.global_position.distance_to(lever_position(id, index)) > REACH + 4.0:
        return false
    var levers: Array = state(id).levers
    if bool(levers[index]):
        actor.session.notify_character(actor.character_id, "This lever is already down.")
        return false
    levers[index] = true
    for character in inside(id):
        character.session.notify_character(character.character_id, "The boss chamber's door grinds open!" if door_open(id) else "A lever clanks down somewhere (1 of 2). The other is in the other hall.")
    actor.session.queue_save()
    return true

func open_vault(actor: Node2D, id: String) -> bool:
    if not AUTHORITY.can_mutate(actor) or not DUNGEONS.DUNGEONS.has(id) or actor.global_position.distance_to(vault_position(id)) > REACH + 4.0:
        return false
    var bag: Node = actor.get_node("Inventory")
    if bag.count_of(key_item(id)) < 1:
        actor.session.notify_character(actor.character_id, "The vault is locked. The %s opens it — the Keeper of the second hall carries one now and then." % key_name(key_item(id)))
        return false
    bag.discard(StringName(key_item(id)), 1)
    var spec: Array = DUNGEONS.DUNGEONS[id]
    var level: int = int(spec[3][1]) + (DUNGEONS.HEROIC_LEVELS if heroic(id) else 0)
    var gear := preload("res://scripts/items/gear_catalogue.gd")
    var sources := preload("res://scripts/items/gear_sources.gd")
    var rarity := 4 if heroic(id) else 3
    var item: Dictionary = gear.roll(sources._base(_rng, [], rarity, level), rarity, _rng)
    if not actor.add_item(item):
        world.drop_gear(item, actor.global_position + Vector2(0, 12), "", actor.character_id)
    var zeni: int = preload("res://scripts/trade/trade_catalogue.gd").zeni_for(level, 2) * 15
    actor.gain_zeni(zeni, "vault")
    actor.session.notify_character(actor.character_id, "The vault opens: %s %s and %d Zeni!" % [gear.RARITIES[rarity], gear.display_name(item), zeni])
    actor.session.queue_save()
    return true

## Heroic or normal: chosen by whoever enters an empty dungeon; creatures inside take the new level.
func choose_mode(id: String, wanted: bool) -> void:
    if heroic(id) == wanted or not inside(id).is_empty():
        return
    state(id)["heroic"] = wanted
    DUNGEONS.heroic[id] = wanted
    for enemy in get_tree().get_nodes_in_group("enemies"):
        var entity: String = String(enemy.get("entity_id"))
        if (entity.begins_with("dg_%s_" % id) or entity == DUNGEONS.boss_id(id)) and enemy.get_node("Health").current > 0 and enemy.has_method("set_difficulty"):
            enemy.set_difficulty(int(enemy.difficulty))

## Host: game events (passed on by QuestLog) — the Keeper's key, the heroic boss's prize.
func on_event(actor: Node, kind: String, data: Dictionary) -> void:
    if not AUTHORITY.can_mutate(actor):
        return
    var entity := String(data.get("id", ""))
    if kind == "kill":
        for id in DUNGEONS.ORDER:
            if entity == keeper(id) and _rng.randf() < KEY_CHANCE and actor.get_node("Inventory").add_material(key_item(id), 1) == 1:
                actor.session.notify_character(actor.character_id, "The Keeper dropped the %s! It opens the vault in the first hall." % key_name(key_item(id)))
    elif kind == "boss":
        for id in DUNGEONS.ORDER:
            if entity == DUNGEONS.boss_id(id) and heroic(id):
                var gear := preload("res://scripts/items/gear_catalogue.gd")
                var sources := preload("res://scripts/items/gear_sources.gd")
                var level: int = DUNGEONS.boss_level(id)
                var item: Dictionary = gear.roll(sources._base(_rng, [], 4, level), 4, _rng)
                if not actor.add_item(item):
                    world.drop_gear(item, actor.global_position + Vector2(0, 12), "", actor.character_id)
                actor.session.notify_character(actor.character_id, "Heroic victory! %s %s." % [gear.RARITIES[4], gear.display_name(item)])

func _physics_process(delta: float) -> void:
    if world == null:
        return
    # Every peer: the heroic levels (from the replicated progression) and the doors.
    for id in DUNGEONS.ORDER:
        var stored: Variant = world.progression.get("dungeons", {}).get(id) if world.progression.get("dungeons") is Dictionary else null
        DUNGEONS.heroic[id] = stored is Dictionary and bool(stored.get("heroic", false))
        var open: bool = stored is Dictionary and stored.get("levers") is Array and stored.levers.size() == 2 and bool(stored.levers[0]) and bool(stored.levers[1])
        _doors[id].get_child(0).set_deferred("disabled", open)
    if world.get_node("/root/GameSession").replica_world:
        return
    var time := world_time()
    for id in DUNGEONS.ORDER:
        var present := inside(id)
        var current := state(id)
        if present.is_empty():
            current["empty"] = float(current.get("empty", 0.0)) + delta
            if float(current.empty) >= RESET_SECONDS and (door_open(id) or bool(current.levers[0]) or bool(current.levers[1]) or heroic(id)):
                current["levers"] = [false, false]
                choose_mode(id, false)
        else:
            current["empty"] = 0.0
        # Spikes up: characters on a trap are hurt (once per spike).
        var spots := traps(id)
        for index in range(spots.size()):
            if trap_phase(time, index) != 2:
                continue
            for actor in present:
                var key := "%s:%s:%d" % [actor.character_id, id, index]
                if _hit_cooldown.get(key, 0.0) > time or actor.get_node("Health").current <= 0:
                    continue
                if _on_trap(actor.global_position, spots[index]):
                    _hit_cooldown[key] = time + TRAP_UP + 0.1
                    var health: Node = actor.get_node("Health")
                    health.take_damage(maxi(1, int(round(health.maximum * (TRAP_DAMAGE_HEROIC if heroic(id) else TRAP_DAMAGE)))), null)

## Half size of a trap plate: across the whole bridge, a tile and a half along it.
static func trap_half(trap: Array) -> Vector2:
    var across: float = DUNGEONS.BRIDGE_WIDTH * MAP.TILE / 2.0
    var along: float = MAP.TILE * 0.75
    return Vector2(across, along) if trap[1] else Vector2(along, across)

static func _on_trap(position: Vector2, trap: Array) -> bool:
    var centre: Vector2 = trap[0]
    var half := trap_half(trap)
    return absf(position.x - centre.x) <= half.x and absf(position.y - centre.y) <= half.y

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var me: Node2D = world.get_local_player() if world != null and world.has_method("get_local_player") else null
    if me == null:
        return
    var here := DUNGEONS.at_tile(MAP.to_tile(me.global_position))
    if here.is_empty():
        return
    var time := world_time()
    var font := ThemeDB.fallback_font
    # Spike traps: plates; during the warning the spikes peek out, then stand up red-tipped.
    var spots := traps(here)
    for index in range(spots.size()):
        var centre: Vector2 = spots[index][0]
        var half := trap_half(spots[index])
        draw_rect(Rect2(centre - half, half * 2.0), Color(0.18, 0.16, 0.2, 0.9))
        var phase := trap_phase(time, index)
        var step := 6.0
        var x := -half.x + 3.0
        while x < half.x - 1.0:
            var y := -half.y + 3.0
            while y < half.y - 1.0:
                var at := centre + Vector2(x, y)
                if phase == 0:
                    draw_circle(at, 1.0, Color(0.35, 0.33, 0.38))
                else:
                    var tall := 3.0 if phase == 1 else 6.0
                    draw_colored_polygon(PackedVector2Array([at + Vector2(-1.5, 1), at + Vector2(1.5, 1), at + Vector2(0, 1 - tall)]), Color(0.75, 0.75, 0.8) if phase == 1 else Color(0.85, 0.3, 0.3))
                y += step
            x += step
    # Levers.
    var stored: Dictionary = state(here)
    for index in range(2):
        var at := lever_position(here, index)
        draw_rect(Rect2(at + Vector2(-6, -2), Vector2(12, 6)), Color("4a4450"))
        var down: bool = bool(stored.levers[index])
        draw_line(at, at + (Vector2(6, -6) if down else Vector2(-6, -10)), Color("b58a5a"), 2.0)
        draw_circle(at + (Vector2(6, -6) if down else Vector2(-6, -10)), 2.5, Color("d04040") if not down else Color("40c060"))
        draw_string(font, at + Vector2(-16, -16), "Lever", HORIZONTAL_ALIGNMENT_CENTER, 32, 8, Color(1, 0.9, 0.7, 0.9))
    # The vault.
    var vault := vault_position(here)
    draw_rect(Rect2(vault + Vector2(-9, -8), Vector2(18, 13)), Color("6a5030"))
    draw_rect(Rect2(vault + Vector2(-9, -8), Vector2(18, 4)), Color("8a6a40"))
    draw_rect(Rect2(vault + Vector2(-2, -3), Vector2(4, 5)), Color("e0c060"))
    draw_string(font, vault + Vector2(-20, -12), "Locked vault", HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(1, 0.9, 0.7, 0.9))
    # The sealed door (iron bars) until both levers are down.
    if not door_open(here):
        var door := door_position(here)
        var width: float = DUNGEONS.BRIDGE_WIDTH * MAP.TILE + 8
        draw_rect(Rect2(door + Vector2(-width / 2.0, -6), Vector2(width, 10)), Color("3a3640"))
        var bar := -width / 2.0 + 3.0
        while bar < width / 2.0:
            draw_line(door + Vector2(bar, -10), door + Vector2(bar, 4), Color("8a8a96"), 2.0)
            bar += 6.0
        draw_string(font, door + Vector2(-40, -14), "Sealed: pull both levers", HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(1, 0.8, 0.6, 0.95))
    if heroic(here):
        draw_string(font, me.global_position + Vector2(-30, -40), "HEROIC", HORIZONTAL_ALIGNMENT_CENTER, 60, 8, Color(1, 0.45, 0.35, 0.9))
