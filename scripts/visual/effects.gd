extends RefCounted
## One-shot visual effects (step 23): animated sprites from assets/game/sprites/fx that play once
## above the characters and free themselves. Cosmetic only: never touches hit timing, line of
## sight or rewards. With reduced effects on, only the short hit flash and the slash arcs remain.
## [sheet, frame width, frames per second]
const SHEETS := {
    "hit_spark": ["res://assets/game/sprites/fx/hit_spark.png", 32, 24.0],
    "ring": ["res://assets/game/sprites/fx/ring.png", 32, 14.0],
    "sparkle": ["res://assets/game/sprites/fx/sparkle.png", 30, 18.0],
    "aura": ["res://assets/game/sprites/fx/aura.png", 25, 12.0],
    "boost": ["res://assets/game/sprites/fx/boost.png", 53, 14.0],
    "smoke": ["res://assets/game/sprites/fx/smoke.png", 32, 14.0],
    "slash": ["res://assets/game/sprites/fx/slash.png", 32, 20.0],
    "claw": ["res://assets/game/sprites/fx/claw.png", 32, 20.0],
}
## Kept with reduced effects (they show the action itself, not decoration).
const ESSENTIAL := ["hit_spark", "slash", "claw"]
static var reduced := false
static var _frames: Dictionary = {}
## Effects spawned (id → count), for tests and the playtest log.
static var spawned: Dictionary = {}

static func frames(id: String) -> SpriteFrames:
    if _frames.has(id):
        return _frames[id]
    var spec: Array = SHEETS[id]
    var sheet: Texture2D = load(spec[0])
    var built := SpriteFrames.new()
    built.set_animation_loop("default", false)
    built.set_animation_speed("default", spec[2])
    for index in range(sheet.get_width() / spec[1]):
        var atlas := AtlasTexture.new()
        atlas.atlas = sheet
        atlas.region = Rect2(index * spec[1], 0, spec[1], sheet.get_height())
        built.add_frame("default", atlas)
    _frames[id] = built
    return built

## Play effect `id` at `at` under `parent` (the world). `angle` rotates directional effects;
## `loop` keeps it running until freed by the caller (analysis aura). Returns the sprite or null.
static func spawn(parent: Node, id: String, at: Vector2, angle: float = 0.0, loop: bool = false) -> AnimatedSprite2D:
    if parent == null or not parent.is_inside_tree() or (reduced and not id in ESSENTIAL):
        return null
    var sprite := AnimatedSprite2D.new()
    sprite.sprite_frames = frames(id)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = at
    sprite.rotation = angle
    sprite.z_index = 5
    sprite.set_meta("effect", id)
    if loop:
        sprite.sprite_frames = frames(id).duplicate()
        sprite.sprite_frames.set_animation_loop("default", true)
    else:
        sprite.animation_finished.connect(sprite.queue_free)
    parent.add_child(sprite)
    sprite.play("default")
    spawned[id] = int(spawned.get(id, 0)) + 1
    return sprite
