extends RefCounted
## Animated bodies built from the prepared sheets in assets/game/sprites (step 19).
## Presentation only: collision shapes, timing, authority and saves never depend on it.
##
## Four-direction sets (Ninja Adventure): every sheet has one column per direction
## (down, up, left, right) and one row per frame, 16x16. Animations: idle_<dir>, walk_<dir>,
## attack_<dir>, dead.
## Side-view sets (Pixel Crawler): one row of frames (idle 32x32, run/death 64x64). Animations:
## idle, run, death; the art faces right, so a left-facing body is flipped.
const DIRECTIONS := ["down", "up", "left", "right"]
const FRAME := 16
## Feet of every body sit this many pixels below the node origin (matches the old placeholders).
const FEET_Y := 7.0
const FOUR := {
    "slime": {"walk": "res://assets/game/sprites/player_slime/slime_walk.png"},
    "human": {"idle": "res://assets/game/sprites/player_human/human_idle.png", "walk": "res://assets/game/sprites/player_human/human_walk.png", "attack": "res://assets/game/sprites/player_human/human_attack.png", "dead": "res://assets/game/sprites/player_human/human_dead.png"},
    "demon": {"idle": "res://assets/game/sprites/player_demon/demon_idle.png", "walk": "res://assets/game/sprites/player_demon/demon_walk.png", "attack": "res://assets/game/sprites/player_demon/demon_attack.png", "dead": "res://assets/game/sprites/player_demon/demon_dead.png"},
}
const SIDE := {
    "gnasher": {"idle": ["res://assets/game/sprites/gnasher/gnasher_idle.png", 32], "run": ["res://assets/game/sprites/gnasher/gnasher_run.png", 64], "death": ["res://assets/game/sprites/gnasher/gnasher_death.png", 64]},
    "thornback": {"idle": ["res://assets/game/sprites/thornback/thornback_idle.png", 32], "run": ["res://assets/game/sprites/thornback/thornback_run.png", 64], "death": ["res://assets/game/sprites/thornback/thornback_death.png", 64]},
    "goblin": {"idle": ["res://assets/game/sprites/ally_goblin/goblin_idle.png", 32], "run": ["res://assets/game/sprites/ally_goblin/goblin_run.png", 64]},
    "hobgoblin": {"idle": ["res://assets/game/sprites/hobgoblin/hobgoblin_idle.png", 32], "run": ["res://assets/game/sprites/hobgoblin/hobgoblin_run.png", 64]},
}
const SPEEDS := {"idle": 4.0, "walk": 8.0, "run": 10.0, "attack": 1.0, "dead": 1.0, "death": 10.0}

static var _cache: Dictionary = {}

static func has_set(id: String) -> bool:
    return FOUR.has(id) or SIDE.has(id)

static func is_side(id: String) -> bool:
    return SIDE.has(id)

## SpriteFrames for a body; per-animation foot offsets are stored as metadata "offsets".
static func frames(id: String) -> SpriteFrames:
    if _cache.has(id):
        return _cache[id]
    var built := SpriteFrames.new()
    built.remove_animation("default")
    var offsets: Dictionary = {}
    if FOUR.has(id):
        var set: Dictionary = FOUR[id]
        for kind in ["idle", "walk", "attack"]:
            var path: String = set.get(kind, set.walk)
            var sheet: Texture2D = load(path)
            var rows: int = sheet.get_height() / FRAME if set.has(kind) else 1
            for column in range(DIRECTIONS.size()):
                var name := "%s_%s" % [kind, DIRECTIONS[column]]
                built.add_animation(name)
                built.set_animation_speed(name, SPEEDS[kind])
                built.set_animation_loop(name, kind != "attack")
                for row in range(rows):
                    built.add_frame(name, _region(sheet, Rect2(column * FRAME, row * FRAME, FRAME, FRAME)))
                offsets[name] = Vector2(0, FEET_Y - FRAME / 2.0)
        built.add_animation("dead")
        built.set_animation_loop("dead", false)
        var dead: Texture2D = load(set.get("dead", set.walk))
        built.add_frame("dead", _region(dead, Rect2(0, 0, FRAME, FRAME)))
        offsets["dead"] = Vector2(0, FEET_Y - FRAME / 2.0)
    else:
        for kind in SIDE[id]:
            var entry: Array = SIDE[id][kind]
            var sheet: Texture2D = load(entry[0])
            var size: int = entry[1]
            built.add_animation(kind)
            built.set_animation_speed(kind, SPEEDS[kind])
            built.set_animation_loop(kind, kind != "death")
            for index in range(sheet.get_width() / size):
                built.add_frame(kind, _region(sheet, Rect2(index * size, 0, size, size)))
            offsets[kind] = Vector2(0, FEET_Y - (_feet(sheet, size) - size / 2.0))
    built.set_meta("offsets", offsets)
    _cache[id] = built
    return built

static func _region(sheet: Texture2D, rect: Rect2) -> AtlasTexture:
    var atlas := AtlasTexture.new()
    atlas.atlas = sheet
    atlas.region = rect
    return atlas

## Lowest opaque row of the first frame: the creature's feet inside its larger canvas.
static func _feet(sheet: Texture2D, size: int) -> float:
    var image: Image = sheet.get_image()
    if image.is_compressed():
        image.decompress()
    var used: Rect2i = image.get_region(Rect2i(0, 0, size, size)).get_used_rect()
    return float(used.position.y + used.size.y) if used.size.y > 0 else float(size)

static func direction_name(facing: Vector2) -> String:
    if absf(facing.x) > absf(facing.y):
        return "left" if facing.x < 0.0 else "right"
    return "up" if facing.y < 0.0 else "down"

## Switch animation (keeping the frame when only the direction changes) and its foot offset.
static func play(sprite: AnimatedSprite2D, animation: String) -> void:
    if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation):
        return
    if sprite.animation != animation:
        sprite.play(animation)
    elif not sprite.is_playing() and sprite.sprite_frames.get_animation_loop(animation):
        sprite.play(animation)
    var offsets: Dictionary = sprite.sprite_frames.get_meta("offsets", {})
    sprite.offset = offsets.get(animation, Vector2.ZERO)

static func make(id: String) -> AnimatedSprite2D:
    var sprite := AnimatedSprite2D.new()
    sprite.name = "Body"
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    # Behind the node's own drawing, so health bars, gear and effects stay on top.
    sprite.show_behind_parent = true
    sprite.sprite_frames = frames(id)
    return sprite
