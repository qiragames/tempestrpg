extends Node2D
## SVE feedback 2026-10-22: the weapon is held in the hand (it used to float beside the character
## inside a glow) and moves with each strike. Every weapon icon is drawn diagonally (tip to the
## top left, grip bottom right), so the icon is turned around its grip until the tip points the
## right way. Per weapon type:
##   sword, dagger, scythe  a swing through an arc in front
##   spear                  a thrust forward and back
##   staff                  a cast: raised back, then flicked forward with a spark at the tip
##   bow                    held out and pulled back
##   fist                   one gauntlet on each hand; the hands punch in turn
## The strike starts when MeleeAttack's flash starts (host, guests and replicas alike).
## Epic and better keep their sparks, rising from the tip.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const ELEMENTS := preload("res://scripts/items/element_catalogue.gd")
const EFFECTS := preload("res://scripts/visual/effects.gd")
## Seconds a strike's motion takes, per type.
const MOTION := {"sword": 0.24, "dagger": 0.16, "scythe": 0.34, "spear": 0.22, "staff": 0.3, "bow": 0.3, "fist": 0.14}
## Drawn size (px) per type; long weapons are longer.
const SIZE := {"sword": 10.0, "dagger": 7.0, "scythe": 12.0, "spear": 13.0, "staff": 12.0, "bow": 10.0, "fist": 5.0}
## Where the hand holds the icon (a fraction along its diagonal from the grip corner).
const GRIP := {"sword": 0.18, "dagger": 0.2, "scythe": 0.3, "spear": 0.38, "staff": 0.3, "bow": 0.5, "fist": 0.5}
## The icon's own tip direction: diagonal up-left (scythes: their blade end, down-left).
const ICON_ANGLE := -3.0 * PI / 4.0
const ICON_ANGLES := {"scythe": 3.0 * PI / 4.0}

var player: Node2D
var _texture: Texture2D
var _key := ""
var _kind := "sword"
var _rarity := 0
var _t := 1.0
var _aim := Vector2.RIGHT
var _last_flash := 0.0
var _punches := 0
var _fx: CPUParticles2D

func _init(owner_player: Node2D) -> void:
    player = owner_player
    name = "WeaponHand"
    z_as_relative = true

func _process(delta: float) -> void:
    var item: Dictionary = player.equipped_weapon() if player.has_method("equipped_weapon") else {}
    var shown: bool = not item.is_empty() and _may_show()
    visible = shown
    if not shown:
        _set_fx({})
        _key = ""
        return
    var key := "%s:%d" % [item.base, int(item.rarity)]
    if key != _key:
        _key = key
        _texture = GEAR.icon_texture(item.base, int(item.rarity))
        _kind = String(GEAR.BASES[item.base].get("weapon", "sword"))
        if not MOTION.has(_kind):
            _kind = "sword"
        _rarity = int(item.rarity)
        _set_fx(item)
    var melee: Node = player.get_node_or_null("MeleeAttack")
    if melee != null:
        if melee.flash_left > _last_flash + 0.001:
            _t = 0.0
            _aim = melee.direction if melee.direction != Vector2.ZERO else player.facing
            _punches += 1
        _last_flash = melee.flash_left
    _t = minf(1.0, _t + delta / float(MOTION[_kind]))
    # Facing up the weapon is behind the body, otherwise in front of it.
    z_index = -1 if player.facing.y < -0.6 and absf(player.facing.x) < 0.5 else 1
    queue_redraw()

func _may_show() -> bool:
    var health: Node = player.get_node_or_null("Health")
    if health == null or health.current <= 0 or player.get("exhaustion_active") or not String(player.get("gather_id")).is_empty():
        return false
    return player.form == player.FORMS.BASE

## The hand a weapon is held in, by facing (body-relative pixels; the sprite's feet are at 0).
func _hand(right: bool = true) -> Vector2:
    var facing: Vector2 = player.facing
    if absf(facing.x) >= 0.5:
        var side := signf(facing.x)
        return Vector2(4.0 * side, -2.0) if right else Vector2(-3.0 * side, -2.0)
    if facing.y < 0.0:
        return Vector2(-6.0, -3.0) if right else Vector2(6.0, -3.0)
    return Vector2(-6.0, -2.0) if right else Vector2(6.0, -2.0)

## The resting direction of the tip: up and a little forward.
func _rest() -> Vector2:
    var facing: Vector2 = player.facing
    var side: float = signf(facing.x) if absf(facing.x) >= 0.3 else (-1.0 if facing.y >= 0.0 else 1.0)
    return Vector2(0.45 * side, -1.0).normalized()

func _draw() -> void:
    if _texture == null:
        return
    if _kind == "fist":
        _draw_fists()
        return
    var hand := _hand()
    var tip := _rest()
    var reach := 0.0
    var swinging := _t < 1.0
    var ease := 1.0 - pow(1.0 - _t, 3.0)
    if swinging:
        var aim_angle := _aim.angle()
        match _kind:
            "spear":
                tip = _aim
                reach = 9.0 * sin(PI * _t)
            "staff":
                # Raised back, then flicked forward past the aim, and back to rest.
                var angle: float = lerp_angle(aim_angle - 1.3, aim_angle + 0.25, ease)
                tip = Vector2.from_angle(angle)
            "bow":
                tip = _aim.rotated(PI / 2.0)
                reach = 2.0 - 4.0 * sin(PI * _t)
            _:
                var sweep := 2.1 if _kind == "scythe" else (1.2 if _kind == "dagger" else 1.7)
                var angle: float = aim_angle - sweep + 2.0 * sweep * ease
                tip = Vector2.from_angle(angle)
                reach = 3.0 * sin(PI * _t)
        hand += _aim * reach
    if _kind == "bow" and not swinging:
        # The bow is held upright, its arc forward.
        var side: float = signf(player.facing.x) if absf(player.facing.x) >= 0.3 else 1.0
        tip = Vector2(side, 0.0).rotated(PI / 2.0) if absf(player.facing.x) >= 0.3 else player.facing.rotated(PI / 2.0)
    _draw_held(hand, tip, float(SIZE[_kind]), float(GRIP[_kind]))
    var tip_point := hand + tip * float(SIZE[_kind]) * (1.0 - float(GRIP[_kind])) * 1.3
    if is_instance_valid(_fx):
        _fx.position = tip_point
    # The staff's cast: a short spark at the tip at the end of the flick.
    if _kind == "staff" and swinging and _t > 0.45:
        var glow := Color(_colour(), 0.9 * (1.0 - _t))
        draw_circle(tip_point, 2.5 + 2.0 * (1.0 - _t), glow)
        draw_circle(tip_point, 1.2, Color(1, 1, 1, 0.9 * (1.0 - _t)))
    # A faint trail behind swung blades.
    if swinging and _kind in ["sword", "dagger", "scythe"] and _t < 0.8:
        var length := float(SIZE[_kind]) * 1.1
        var sweep := 2.1 if _kind == "scythe" else (1.2 if _kind == "dagger" else 1.7)
        var start := _aim.angle() - sweep
        draw_arc(hand, length, start, start + 2.0 * sweep * ease, 12, Color(1, 1, 1, 0.35 * (1.0 - _t)), 1.5)

## Draws the icon so its grip sits at `hand` and its tip points along `tip`.
func _draw_held(hand: Vector2, tip: Vector2, size: float, grip: float) -> void:
    var icon_angle: float = ICON_ANGLES.get(_kind, ICON_ANGLE)
    var rotation_angle := tip.angle() - icon_angle
    # The grip point inside the icon square (size x size, centred on 0): along the diagonal
    # from the corner opposite the tip.
    var corner := Vector2(signf(cos(icon_angle)), signf(sin(icon_angle))) * size / 2.0
    var grip_point := (-corner).lerp(corner, grip)
    draw_set_transform(hand, rotation_angle, Vector2.ONE)
    draw_texture_rect(_texture, Rect2(-grip_point - Vector2(size, size) / 2.0, Vector2(size, size)), false)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Fist weapons: one gauntlet on each hand; a strike throws the next hand forward.
func _draw_fists() -> void:
    var size: float = SIZE.fist
    for right in [true, false]:
        var hand := _hand(right)
        var striking: bool = _t < 1.0 and (_punches % 2 == 0) == right
        if striking:
            hand += _aim * 8.0 * sin(PI * _t)
        var flip := -1.0 if hand.x < 0.0 else 1.0
        draw_set_transform(hand, 0.0, Vector2(flip, 1.0))
        draw_texture_rect(_texture, Rect2(-Vector2(size, size) / 2.0, Vector2(size, size)), false)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    if is_instance_valid(_fx):
        _fx.position = _hand(true)

func _colour() -> Color:
    var item: Dictionary = player.equipped_weapon()
    if item.is_empty():
        return Color.WHITE
    var element: String = String(GEAR.BASES[item.base].get("element", ""))
    return ELEMENTS.color(element) if not element.is_empty() else Color(GEAR.RARITY_COLORS[clampi(int(item.rarity), 0, GEAR.RARITY_COLORS.size() - 1)])

## Epic and up: sparks rise from the tip (more and bigger for Legendary and Mythic).
func _set_fx(item: Dictionary) -> void:
    var rarity: int = int(item.rarity) if not item.is_empty() else 0
    if rarity < 3 or EFFECTS.reduced:
        if is_instance_valid(_fx):
            _fx.queue_free()
        _fx = null
        return
    if not is_instance_valid(_fx):
        _fx = CPUParticles2D.new()
        _fx.name = "WeaponFx"
        _fx.local_coords = false
        _fx.direction = Vector2.UP
        _fx.spread = 40.0
        _fx.gravity = Vector2(0, -18)
        _fx.initial_velocity_min = 4.0
        _fx.initial_velocity_max = 12.0
        _fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
        _fx.emission_sphere_radius = 2.5
        add_child(_fx)
    var colour := _colour()
    _fx.amount = [0, 0, 0, 5, 10, 18][clampi(rarity, 0, 5)]
    _fx.lifetime = 0.5 + 0.12 * rarity
    _fx.scale_amount_min = 0.7
    _fx.scale_amount_max = 0.9 + 0.3 * (rarity - 3)
    var ramp := Gradient.new()
    ramp.set_color(0, Color(colour.lightened(0.3), 0.9))
    ramp.set_color(1, Color(colour, 0.0))
    _fx.color_ramp = ramp
    _fx.emitting = true
