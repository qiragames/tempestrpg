extends Node2D
## The ways into and out of the dungeons (M7c): a cave mouth in each dungeon's region (drawn as a
## dark arch in a rock mound) and a way out in its entry room (a shaft of daylight). F next to
## one moves the character (host): in, to the entry room; out, back to the cave mouth. Drawn on
## every peer; nothing to save.
const DUNGEONS := preload("res://scripts/dungeons/dungeon_catalogue.gd")
const MAP := preload("res://scripts/world/world_map.gd")
const AUTHORITY := preload("res://scripts/network/authority.gd")

func _init() -> void:
    name = "DungeonGates"
    y_sort_enabled = true

static func mouth_position(id: String) -> Vector2:
    return MAP.to_world(DUNGEONS.DUNGEONS[id][2]) + Vector2(8, 8)

static func exit_position(id: String) -> Vector2:
    return MAP.to_world(DUNGEONS.exit_tile(id)) + Vector2(8, 8)

## ["enter" or "leave", dungeon id] for the gate a character stands at ([] for none).
func nearest(actor: Node2D) -> Array:
    for id in DUNGEONS.ORDER:
        if actor.global_position.distance_to(mouth_position(id)) <= DUNGEONS.GATE_REACH:
            return ["enter", id]
        if actor.global_position.distance_to(exit_position(id)) <= DUNGEONS.GATE_REACH:
            return ["leave", id]
    return []

func enter(actor: Node2D, id: String, heroic: bool = false) -> bool:
    if not AUTHORITY.can_mutate(actor) or not DUNGEONS.DUNGEONS.has(id) or actor.global_position.distance_to(mouth_position(id)) > DUNGEONS.GATE_REACH + 4.0:
        return false
    # M11b: whoever enters an empty dungeon chooses its mode; others join the mode it is in.
    var features: Node = get_parent().get("dungeon_features")
    if features != null:
        features.choose_mode(id, heroic)
    _move(actor, exit_position(id) + Vector2(0, 26))
    if get_parent().get("quests") != null:
        get_parent().quests.on_event(actor, "dungeon", {"id": id})
    var spec: Array = DUNGEONS.DUNGEONS[id]
    var bonus: int = DUNGEONS.heroic_bonus(id)
    actor.session.notify_character(actor.character_id, "You climb down into %s%s (levels %d-%d). %s waits in the deepest chamber behind a sealed door: pull the levers in both halls." % [spec[0], " — HEROIC" if bonus > 0 else "", int(spec[3][0]) + bonus, int(spec[3][1]) + bonus, spec[5]])
    return true

func leave(actor: Node2D, id: String) -> bool:
    if not AUTHORITY.can_mutate(actor) or not DUNGEONS.DUNGEONS.has(id) or actor.global_position.distance_to(exit_position(id)) > DUNGEONS.GATE_REACH + 4.0:
        return false
    _move(actor, mouth_position(id) + Vector2(0, 26))
    actor.session.notify_character(actor.character_id, "Back in the daylight.")
    return true

func _move(actor: Node2D, to: Vector2) -> void:
    if actor.has_method("dismount"):
        actor.dismount()
    if actor.has_method("stop_gather"):
        actor.stop_gather()
    actor.fishing_bite_in = -INF
    actor.global_position = to
    actor.velocity = Vector2.ZERO
    var world: Node = get_parent()
    if world != null and world.get("terrain") != null:
        world.terrain.ensure_props_at(to)
    actor.session.queue_save()

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var local: Node2D = get_parent().get_local_player() if get_parent() != null and get_parent().has_method("get_local_player") else null
    for id in DUNGEONS.ORDER:
        var mouth := mouth_position(id)
        var out := exit_position(id)
        if local == null or local.global_position.distance_to(mouth) < 700.0:
            # A rock mound with a dark arch.
            draw_colored_polygon(PackedVector2Array([mouth + Vector2(-20, 4), mouth + Vector2(-16, -14), mouth + Vector2(-6, -22), mouth + Vector2(8, -21), mouth + Vector2(18, -12), mouth + Vector2(21, 4)]), Color("6a6470"))
            draw_colored_polygon(PackedVector2Array([mouth + Vector2(-14, 4), mouth + Vector2(-12, -6), mouth + Vector2(-6, -12), mouth + Vector2(6, -12), mouth + Vector2(12, -6), mouth + Vector2(14, 4)]), Color("4a4450"))
            draw_colored_polygon(PackedVector2Array([mouth + Vector2(-9, 4), mouth + Vector2(-8, -4), mouth + Vector2(-3, -8), mouth + Vector2(3, -8), mouth + Vector2(8, -4), mouth + Vector2(9, 4)]), Color("0c0a10"))
            draw_string(ThemeDB.fallback_font, mouth + Vector2(-34, -26), DUNGEONS.DUNGEONS[id][0], HORIZONTAL_ALIGNMENT_CENTER, 68, 7, Color(1, 0.9, 0.7, 0.9))
        if local == null or local.global_position.distance_to(out) < 700.0:
            # A shaft of daylight with a rope ladder.
            draw_colored_polygon(PackedVector2Array([out + Vector2(-10, 6), out + Vector2(-5, -30), out + Vector2(5, -30), out + Vector2(10, 6)]), Color(1.0, 0.95, 0.7, 0.28))
            draw_line(out + Vector2(-3, 4), out + Vector2(-3, -26), Color("8a6440"), 1.0)
            draw_line(out + Vector2(3, 4), out + Vector2(3, -26), Color("8a6440"), 1.0)
            for step in range(6):
                draw_line(out + Vector2(-3, 2 - step * 5), out + Vector2(3, 2 - step * 5), Color("b58a5a"), 1.0)
            draw_string(ThemeDB.fallback_font, out + Vector2(-20, -32), "Way out", HORIZONTAL_ALIGNMENT_CENTER, 40, 7, Color(1, 0.95, 0.75, 0.9))
