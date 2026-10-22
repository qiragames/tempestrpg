extends RefCounted
## The owner's mod menu (user request, private): only in the dev build (export feature
## "devtools") or when run from the Godot editor, and only for the character of the world's host
## (the host decides everything, so friends' games are never touched). Nothing here is saved:
## boosts reset when the game restarts.
static var speed := false
static var xp := false
static var loot := false
static var zeni := false
static var god := false
## Owner request: wear anything (no level, class or attribute requirements).
static var free_gear := false
## The weapons that are always Mythic (the type uniques, boss/elite/dungeon uniques, the story).
const MYTHIC_WEAPONS := ["sword_118", "dagger_124", "bow_102", "spear_096", "scythe_078", "staff_053", "fist_021", "boss_skylord_fan", "boss_apex_fang", "boss_overlord_edge", "boss_wyrmfang", "elite_alpha_reaper", "dungeon_jade_blade", "story_moonwarden_crescent", "story_eclipse_reaper"]

const SPEED_FACTOR := 3.0
const XP_FACTOR := 10
const ZENI_FACTOR := 10
## Super loot: every creature drops gear, mostly Epic and better.
const LOOT_RARITY := [0, 5, 15, 40, 30, 10]

static func available() -> bool:
    return OS.has_feature("devtools") or OS.has_feature("editor")

## Boosts apply to the host's own character only.
static func applies(actor: Node) -> bool:
    if not available() or actor == null or not ("character_id" in actor):
        return false
    var session: Node = Engine.get_main_loop().root.get_node_or_null("GameSession") if Engine.get_main_loop() is SceneTree else null
    return session != null and not session.replica_world and String(actor.character_id) == "host"

static func flag(key: String) -> bool:
    match key:
        "speed": return speed
        "xp": return xp
        "loot": return loot
        "zeni": return zeni
        "god": return god
        "free_gear": return free_gear
    return false

static func set_flag(key: String, on: bool) -> void:
    match key:
        "speed": speed = on
        "xp": xp = on
        "loot": loot = on
        "zeni": zeni = on
        "god": god = on
        "free_gear": free_gear = on

static func reset() -> void:
    speed = false
    xp = false
    loot = false
    zeni = false
    god = false
    free_gear = false

## Every always-Mythic weapon for the host's character: into the gear bag while there is room, the
## rest at their feet (theirs for an hour). Returns [in the bag, on the ground].
static func give_mythics(actor: Node) -> Array:
    if not applies(actor):
        return [0, 0]
    var gear := preload("res://scripts/items/gear_catalogue.gd")
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var bagged := 0
    var dropped := 0
    var world: Node = actor.get_parent()
    for index in range(MYTHIC_WEAPONS.size()):
        var base: String = MYTHIC_WEAPONS[index]
        if not gear.BASES.has(base):
            continue
        var item: Dictionary = gear.roll(base, 5, rng)
        if actor.add_item(item):
            bagged += 1
        elif world != null and world.has_method("drop_gear"):
            var spot: Vector2 = actor.global_position + Vector2.from_angle(TAU * index / MYTHIC_WEAPONS.size()) * 22.0
            if world.drop_gear(item, spot, "", actor.character_id, float(world.progression.get("world_time", 0.0)) + 3600.0) != null:
                dropped += 1
    return [bagged, dropped]

## Launch options for the owner (run from Godot with `-- --dev-mythics`): wear anything and get
## every Mythic weapon once the world is up.
static func apply_launch(actor: Node) -> void:
    if not available() or not "--dev-mythics" in OS.get_cmdline_user_args():
        return
    free_gear = true
    var result := give_mythics(actor)
    var session: Node = Engine.get_main_loop().root.get_node_or_null("GameSession")
    if session != null:
        session.notify_character(String(actor.character_id), "Mod menu: %d Mythic weapons in your bag, %d at your feet. Wear anything is on (F10)." % [result[0], result[1]])
        session.queue_save()
