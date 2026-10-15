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
    return false

static func set_flag(key: String, on: bool) -> void:
    match key:
        "speed": speed = on
        "xp": xp = on
        "loot": loot = on
        "zeni": zeni = on
        "god": god = on

static func reset() -> void:
    speed = false
    xp = false
    loot = false
    zeni = false
    god = false
