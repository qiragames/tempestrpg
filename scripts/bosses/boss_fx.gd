extends Node2D
## Raid boss telegraphs and arenas (M7a). The host adds zones (a circle, a ring, a line) with a
## wind-up; every peer draws them as red areas that fill up until they strike; when one ends, the
## host damages every living character inside it. Zones travel in snapshots ("boss_fx", always
## sent, not saved). Arenas of living bosses are outlined when a character is near.
const BOSS := preload("res://scripts/bosses/boss_catalogue.gd")
const AUTHORITY := preload("res://scripts/network/authority.gd")

## [{boss, shape, at: [x, y], size, extra: [x, y], left, total, damage}]
var zones: Array = []
var _callbacks: Dictionary = {}

func _init() -> void:
    name = "BossFx"
    z_index = 2

func add_zone(boss: Node2D, shape: String, at: Vector2, size: float, extra: Vector2, seconds: float, damage: int) -> void:
    zones.append({"boss": boss.entity_id, "shape": shape, "at": [at.x, at.y], "size": size, "extra": [extra.x, extra.y], "left": seconds, "total": seconds, "damage": damage})
    queue_redraw()

## Run `callback` when this boss's current zones strike (a charge's dash).
func on_resolve(boss: Node2D, callback: Callable) -> void:
    _callbacks[boss.entity_id] = callback

func clear_boss(boss: Node2D) -> void:
    zones = zones.filter(func(zone): return zone.boss != boss.entity_id)
    _callbacks.erase(boss.entity_id)
    queue_redraw()

## Whether a point is inside a zone.
static func inside(zone: Dictionary, point: Vector2) -> bool:
    var at := Vector2(zone.at[0], zone.at[1])
    var size: float = zone.size
    match zone.shape:
        "circle":
            return point.distance_to(at) <= size
        "ring":
            var distance := point.distance_to(at)
            return distance <= size and distance >= float(zone.extra[0])
        "line":
            var end := Vector2(zone.extra[0], zone.extra[1])
            var along := end - at
            var t := clampf((point - at).dot(along) / maxf(1.0, along.length_squared()), 0.0, 1.0)
            return point.distance_to(at + along * t) <= size / 2.0
    return false

func _physics_process(delta: float) -> void:
    if zones.is_empty():
        return
    var host := AUTHORITY.can_mutate(self)
    var struck: Array = []
    for zone in zones:
        zone.left = float(zone.left) - delta
        if zone.left <= 0.0:
            struck.append(zone)
    for zone in struck:
        zones.erase(zone)
        if host:
            _strike(zone)
    queue_redraw()

func _strike(zone: Dictionary) -> void:
    var world: Node = get_parent()
    var boss: Node = world.entity_by_id(zone.boss) if world != null and world.has_method("entity_by_id") else null
    if boss == null or boss.state == boss.State.DEFEATED:
        return
    for actor in get_tree().get_nodes_in_group("player"):
        if actor.get_node("Health").current > 0 and inside(zone, actor.global_position):
            actor.get_node("Health").take_damage(int(zone.damage), boss)
    var effects := preload("res://scripts/visual/effects.gd")
    effects.spawn(world, "ring", Vector2(zone.at[0], zone.at[1]))
    if _callbacks.has(zone.boss) and not zones.any(func(other): return other.boss == zone.boss):
        var callback: Callable = _callbacks[zone.boss]
        _callbacks.erase(zone.boss)
        if callback.is_valid():
            callback.call()

## Snapshot part.
func state() -> Array:
    return zones.duplicate(true)

func apply(data: Variant) -> void:
    zones = data.duplicate(true) if data is Array else []
    queue_redraw()

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    # Arenas of living bosses near a character of this peer.
    var world: Node = get_parent()
    var local: Node2D = world.get_local_player() if world != null and world.has_method("get_local_player") else null
    for boss in get_tree().get_nodes_in_group("raid_bosses"):
        if boss.state == boss.State.DEFEATED or not BOSS.is_boss(boss.entity_id):
            continue
        var centre := BOSS.centre(boss.entity_id)
        var radius := BOSS.radius(boss.entity_id)
        if local == null or local.global_position.distance_to(centre) > radius + 240.0:
            continue
        var steps := 48
        for index in range(steps):
            if index % 2 == 0:
                draw_arc(centre, radius, TAU * index / steps, TAU * (index + 1) / steps, 3, Color(1.0, 0.75, 0.3, 0.55), 1.5)
    for zone in zones:
        var at := Vector2(zone.at[0], zone.at[1])
        var fill: float = 1.0 - clampf(float(zone.left) / maxf(0.01, float(zone.total)), 0.0, 1.0)
        var edge := Color(1.0, 0.25, 0.2, 0.85)
        var area := Color(1.0, 0.2, 0.15, 0.18 + 0.22 * fill)
        match zone.shape:
            "circle":
                draw_circle(at, zone.size, area)
                draw_circle(at, zone.size * fill, Color(1.0, 0.2, 0.15, 0.25))
                draw_arc(at, zone.size, 0, TAU, 32, edge, 1.5)
            "ring":
                var inner: float = zone.extra[0]
                draw_arc(at, (zone.size + inner) / 2.0, 0, TAU, 48, area, zone.size - inner)
                draw_arc(at, zone.size, 0, TAU, 48, edge, 1.5)
                draw_arc(at, inner, 0, TAU, 32, edge, 1.5)
            "line":
                var end := Vector2(zone.extra[0], zone.extra[1])
                draw_line(at, end, area, zone.size)
                var side: Vector2 = (end - at).normalized().orthogonal() * float(zone.size) / 2.0
                draw_line(at + side, end + side, edge, 1.5)
                draw_line(at - side, end - side, edge, 1.5)
                draw_line(at, at.lerp(end, fill), Color(1.0, 0.2, 0.15, 0.3), zone.size)
