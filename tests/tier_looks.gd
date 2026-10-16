extends SceneTree
## Distinct looks for the high gear tiers (M11): every tier has its own palette, the art differs
## from the source and between tiers, the highest tiers glow beyond the silhouette, textures are
## cached, other items keep their art.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const LOOKS := preload("res://scripts/items/tier_looks.gd")
const HIGH := preload("res://scripts/items/high_items.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _image(texture: Texture2D) -> Image:
    var image := texture.get_image()
    image.convert(Image.FORMAT_RGBA8)
    return image

func _opaque(image: Image) -> int:
    var count := 0
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            if image.get_pixel(x, y).a > 0.01:
                count += 1
    return count

func _run() -> void:
    _check(HIGH.TIERS.all(func(tier): return LOOKS.has_look(tier[1])), "Every gear tier has a look")
    var source := _image(GEAR.icon_texture("sword_080", 0))
    var seen: Array = [source.get_data()]
    var distinct := true
    for tier in HIGH.TIERS:
        var id := "t%d_sword_080" % tier[0]
        var image := _image(GEAR.icon_texture(id, 0))
        distinct = distinct and not image.get_data() in seen
        seen.append(image.get_data())
    _check(distinct, "Each tier's art differs from the source and from every other tier")
    _check(GEAR.icon_texture("t30_sword_080", 0) == GEAR.icon_texture("t30_sword_080", 3), "Tier textures are made once and cached")
    _check(_opaque(_image(GEAR.icon_texture("t48_sword_080", 0))) > _opaque(_image(GEAR.icon_texture("t45_sword_080", 0))) and _opaque(_image(GEAR.icon_texture("t45_sword_080", 0))) > _opaque(_image(GEAR.icon_texture("t39_sword_080", 0))), "The highest tiers glow beyond the silhouette (Ascendant most)")
    _check(_opaque(_image(GEAR.icon_texture("t21_sword_080", 0))) == _opaque(source), "Lower tiers keep the silhouette")
    _check(GEAR.icon_texture("sword_080", 0) is AtlasTexture, "Items without a tier keep their own art")
    print("Tier look checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
