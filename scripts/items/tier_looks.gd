extends RefCounted
## Distinct looks for the high gear tiers (user request: each tier should look different, not only
## carry another name). The ten tiers of levels 21-48 reuse their source item's art; this recolours
## it in the tier's own palette — storm blue, steppe gold, wind teal, gloom violet, dusk ember,
## jade, cloud silver — and the three highest tiers also shine: a glowing edge (Starforged,
## Celestial) and a brighter double glow (Ascendant). Icons in every window and the weapon in
## your character's hand use the same textures (GearCatalogue.icon_texture). Built once per item
## base on demand, cached for the session.

## Tier name: [palette colour, how strongly the art takes it (0-1), glow colour (alpha 0 = none),
## glow width (px)].
const LOOKS := {
    "Stormtouched": [Color(0.45, 0.72, 1.0), 0.7, Color(0, 0, 0, 0), 0],
    "Steppeforged": [Color(0.98, 0.76, 0.34), 0.7, Color(0, 0, 0, 0), 0],
    "Windwrought": [Color(0.5, 0.96, 0.86), 0.7, Color(0, 0, 0, 0), 0],
    "Gloomwrought": [Color(0.72, 0.45, 1.0), 0.75, Color(0, 0, 0, 0), 0],
    "Duskforged": [Color(1.0, 0.46, 0.32), 0.75, Color(0, 0, 0, 0), 0],
    "Jadecarved": [Color(0.38, 0.95, 0.6), 0.75, Color(0, 0, 0, 0), 0],
    "Cloudforged": [Color(0.93, 0.96, 1.0), 0.65, Color(0, 0, 0, 0), 0],
    "Starforged": [Color(0.55, 0.58, 1.0), 0.75, Color(0.7, 0.75, 1.0, 0.6), 1],
    "Celestial": [Color(1.0, 0.94, 0.62), 0.75, Color(1.0, 0.95, 0.7, 0.75), 1],
    "Ascendant": [Color(1.0, 0.55, 0.88), 0.8, Color(1.0, 0.8, 0.95, 0.9), 2],
}

static var _cache: Dictionary = {}

static func has_look(tier: String) -> bool:
    return LOOKS.has(tier)

## The recoloured texture for a tier piece (source texture → tier palette and glow).
static func texture(key: String, tier: String, source: Texture2D) -> Texture2D:
    if source == null or not LOOKS.has(tier):
        return source
    if _cache.has(key):
        return _cache[key]
    var image: Image = source.get_image()
    if image == null:
        return source
    if image.is_compressed():
        image.decompress()
    image.convert(Image.FORMAT_RGBA8)
    var result := recolour(image, tier)
    var made := ImageTexture.create_from_image(result)
    _cache[key] = made
    return made

## The tier's palette (outlines and near-black stay; light and shade are kept) and its glow.
static func recolour(image: Image, tier: String) -> Image:
    var look: Array = LOOKS[tier]
    var tint: Color = look[0]
    var strength: float = look[1]
    var out: Image = image.duplicate()
    var width := out.get_width()
    var height := out.get_height()
    for y in range(height):
        for x in range(width):
            var pixel := out.get_pixel(x, y)
            if pixel.a <= 0.01:
                continue
            var light := pixel.r * 0.3 + pixel.g * 0.59 + pixel.b * 0.11
            if light < 0.16 and pixel.s < 0.25:
                continue
            var shaded := Color(tint.r * (0.3 + light * 0.95), tint.g * (0.3 + light * 0.95), tint.b * (0.3 + light * 0.95), pixel.a)
            out.set_pixel(x, y, pixel.lerp(shaded, strength))
    var glow: Color = look[2]
    if glow.a > 0.0:
        for ring in range(int(look[3])):
            var edge: Array = []
            for y in range(height):
                for x in range(width):
                    if out.get_pixel(x, y).a > 0.01:
                        continue
                    for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                        var near: Vector2i = Vector2i(x, y) + offset
                        if near.x >= 0 and near.y >= 0 and near.x < width and near.y < height and out.get_pixel(near.x, near.y).a > 0.5:
                            edge.append(Vector2i(x, y))
                            break
            var fade: float = glow.a * (1.0 if ring == 0 else 0.5)
            for spot in edge:
                out.set_pixel(spot.x, spot.y, Color(glow.r, glow.g, glow.b, fade))
    return out
