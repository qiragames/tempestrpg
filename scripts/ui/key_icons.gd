extends RefCounted
## Key and mouse icons (user request: "always show the proper keybind as an icon where it
## belongs"): the icon of whatever key or mouse button an action is bound to right now, from
## Kenney's Input Prompts Pixel sheet (CC0, assets/game/ui/input/). Wide keys (Shift, Ctrl, Tab...)
## are two or three tiles. Mouse buttons 4 and up show the mouse with their number on it.
const SHEET := preload("res://assets/game/ui/input/prompts.png")
const TILE := 16
const COLUMNS := 34
## Bindings: keyboard keys are physical keycodes; mouse buttons are MOUSE_BASE + button index.
const MOUSE_BASE := 1 << 26

## keycode → [tile index, width in tiles]
const KEYS := {
    KEY_ESCAPE: [17, 1], KEY_F1: [18, 1], KEY_F2: [19, 1], KEY_F3: [20, 1], KEY_F4: [21, 1], KEY_F5: [22, 1], KEY_F6: [23, 1],
    KEY_F7: [24, 1], KEY_F8: [25, 1], KEY_F9: [26, 1], KEY_F10: [27, 1], KEY_F11: [28, 1], KEY_F12: [29, 1], KEY_QUOTELEFT: [30, 1],
    KEY_1: [51, 1], KEY_2: [52, 1], KEY_3: [53, 1], KEY_4: [54, 1], KEY_5: [55, 1], KEY_6: [56, 1], KEY_7: [57, 1], KEY_8: [58, 1],
    KEY_9: [59, 1], KEY_0: [60, 1], KEY_MINUS: [61, 1], KEY_PLUS: [62, 1], KEY_EQUAL: [63, 1], KEY_BACKSPACE: [66, 2],
    KEY_Q: [85, 1], KEY_W: [86, 1], KEY_E: [87, 1], KEY_R: [88, 1], KEY_T: [89, 1], KEY_Y: [90, 1], KEY_U: [91, 1], KEY_I: [92, 1],
    KEY_O: [93, 1], KEY_P: [94, 1], KEY_BRACKETLEFT: [95, 1], KEY_BRACKETRIGHT: [96, 1], KEY_BACKSLASH: [99, 1],
    KEY_A: [120, 1], KEY_S: [121, 1], KEY_D: [122, 1], KEY_F: [123, 1], KEY_G: [124, 1], KEY_H: [125, 1], KEY_J: [126, 1],
    KEY_K: [127, 1], KEY_L: [128, 1], KEY_APOSTROPHE: [129, 1], KEY_SEMICOLON: [132, 1], KEY_ENTER: [134, 2], KEY_KP_ENTER: [134, 2],
    KEY_Z: [155, 1], KEY_X: [156, 1], KEY_C: [157, 1], KEY_V: [158, 1], KEY_B: [159, 1], KEY_N: [160, 1], KEY_M: [161, 1],
    KEY_COMMA: [162, 1], KEY_PERIOD: [163, 1], KEY_SLASH: [165, 1],
    KEY_UP: [166, 1], KEY_RIGHT: [167, 1], KEY_DOWN: [168, 1], KEY_LEFT: [169, 1],
    KEY_ALT: [187, 2], KEY_TAB: [189, 2], KEY_DELETE: [191, 2], KEY_END: [193, 2], KEY_NUMLOCK: [195, 2],
    KEY_CTRL: [221, 2], KEY_CAPSLOCK: [223, 2], KEY_HOME: [225, 2], KEY_PAGEUP: [227, 2], KEY_PAGEDOWN: [229, 2],
    KEY_SPACE: [235, 3], KEY_SHIFT: [255, 2], KEY_INSERT: [257, 2], KEY_PRINT: [259, 2], KEY_SCROLLLOCK: [261, 2], KEY_PAUSE: [263, 2],
}
## mouse button → tile index (others: the plain mouse with the number drawn on).
const MOUSE := {MOUSE_BUTTON_LEFT: 77, MOUSE_BUTTON_RIGHT: 78, MOUSE_BUTTON_MIDDLE: 79, MOUSE_BUTTON_WHEEL_UP: 80, MOUSE_BUTTON_WHEEL_DOWN: 81}
const MOUSE_PLAIN := 76
const BLANK_KEY := 101
## 3 × 5 digits for the side buttons.
const DIGITS := {
    "4": ["1.1", "1.1", "111", "..1", "..1"], "5": ["111", "1..", "111", "..1", "111"], "6": ["111", "1..", "111", "1.1", "111"],
    "7": ["111", "..1", ".1.", ".1.", ".1."], "8": ["111", "1.1", "111", "1.1", "111"], "9": ["111", "1.1", "111", "..1", "111"],
}

static var _cache: Dictionary = {}

static func is_mouse(code: int) -> bool:
    return code >= MOUSE_BASE

static func code_of_event(event: InputEvent) -> int:
    if event is InputEventKey:
        return int(event.physical_keycode) if event.physical_keycode != 0 else int(event.keycode)
    if event is InputEventMouseButton:
        return MOUSE_BASE + int(event.button_index)
    return 0

## The binding an action shows: its first keyboard key or mouse button (0 for none).
static func code_of(action: String) -> int:
    if not InputMap.has_action(action):
        return 0
    for event in InputMap.action_get_events(action):
        var code := code_of_event(event)
        if code != 0:
            return code
    return 0

## "F", "Shift", "Mouse 4", "Left click"...
static func name_of(code: int) -> String:
    if code <= 0:
        return "—"
    if is_mouse(code):
        var button := code - MOUSE_BASE
        return {MOUSE_BUTTON_LEFT: "Left click", MOUSE_BUTTON_RIGHT: "Right click", MOUSE_BUTTON_MIDDLE: "Middle click", MOUSE_BUTTON_WHEEL_UP: "Wheel up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel down"}.get(button, "Mouse %d" % button)
    return OS.get_keycode_string(code)

## The icon for a binding (null for none). Unknown keys get a blank key (the HUD writes the name).
static func icon(code: int) -> Texture2D:
    if code <= 0:
        return null
    if _cache.has(code):
        return _cache[code]
    var texture: Texture2D
    if is_mouse(code):
        var button := code - MOUSE_BASE
        if MOUSE.has(button):
            texture = _tile(MOUSE[button], 1)
        else:
            texture = _numbered_mouse(str(button))
    else:
        var spec: Array = KEYS.get(code, [BLANK_KEY, 1])
        texture = _tile(int(spec[0]), int(spec[1]))
    _cache[code] = texture
    return texture

## True when the icon shows the key itself (otherwise draw its name beside a blank key).
static func has_own_icon(code: int) -> bool:
    return code > 0 and (is_mouse(code) or KEYS.has(code))

static func action_icon(action: String) -> Texture2D:
    return icon(code_of(action))

static func _tile(index: int, width: int) -> Texture2D:
    var atlas := AtlasTexture.new()
    atlas.atlas = SHEET
    atlas.region = Rect2((index % COLUMNS) * TILE, (index / COLUMNS) * TILE, TILE * width, TILE)
    return atlas

static func _numbered_mouse(number: String) -> Texture2D:
    var image: Image = SHEET.get_image().get_region(Rect2i((MOUSE_PLAIN % COLUMNS) * TILE, (MOUSE_PLAIN / COLUMNS) * TILE, TILE, TILE))
    image.convert(Image.FORMAT_RGBA8)
    var glyph: Array = DIGITS.get(number.right(1), DIGITS["4"])
    for row in range(5):
        for column in range(3):
            if String(glyph[row])[column] == "1":
                image.set_pixel(6 + column, 9 + row, Color("2a2f45"))
    return ImageTexture.create_from_image(image)

## A small icon that follows an action's binding (it checks twice a second).
class Badge extends TextureRect:
    var action := ""
    var _code := -1
    var _clock := 0.0

    func _init(bound_action: String = "", height: float = 16.0) -> void:
        action = bound_action
        stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        custom_minimum_size = Vector2(height, height)
        size = Vector2(height, height)
        refresh()

    func refresh() -> void:
        var code: int = preload("res://scripts/ui/key_icons.gd").code_of(action)
        if code == _code:
            return
        _code = code
        texture = preload("res://scripts/ui/key_icons.gd").icon(code)
        tooltip_text = preload("res://scripts/ui/key_icons.gd").name_of(code)
        # Wide keys (Shift, Space...) keep their shape.
        if texture != null:
            var ratio: float = texture.get_width() / float(texture.get_height())
            custom_minimum_size.x = custom_minimum_size.y * ratio
            size.x = custom_minimum_size.x

    func _process(delta: float) -> void:
        _clock -= delta
        if _clock <= 0.0:
            _clock = 0.5
            refresh()
