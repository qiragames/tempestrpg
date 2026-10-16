extends Control
## The pets window (M11f, V): your pets with their portrait and bonus, which one follows you, and
## eggs waiting in your bag. Only the chosen pet's id (or Hatch) goes to the host (the "pet" intent).
const UI := preload("res://scripts/ui/ui_style.gd")
const PETS := preload("res://scripts/pets/pet_catalogue.gd")
const FRAME := Rect2(90, 24, 460, 312)

var hud: CanvasLayer
var _list: VBoxContainer
var _summary: Label
var _hatch: Button
var _paused_before := false

func _init(owner_hud: CanvasLayer) -> void:
    hud = owner_hud
    name = "PetsPanel"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.01, 0.02, 0.04, 0.8)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var frame := Panel.new()
    frame.position = FRAME.position
    frame.size = FRAME.size
    frame.add_theme_stylebox_override("panel", UI.ornate())
    add_child(frame)
    UI.heading(hud._label("PETS", FRAME.position + Vector2(14, 10), Vector2(200, 20), self, 14))
    var close: Button = hud._button("Close", FRAME.position + Vector2(FRAME.size.x - 92, 8), Vector2(80, 24), self)
    close.pressed.connect(close_panel)
    _summary = hud._label("", FRAME.position + Vector2(14, 34), Vector2(FRAME.size.x - 28, 14), self, 9)
    _summary.add_theme_color_override("font_color", UI.GOLD_LIGHT)
    _hatch = hud._button("Hatch an egg", FRAME.position + Vector2(FRAME.size.x - 150, 34), Vector2(136, 20), self)
    _hatch.add_theme_font_size_override("font_size", 9)
    _hatch.pressed.connect(func():
        hud.session.request_action("pet", {"operation": "hatch"})
        await get_tree().process_frame
        refresh()
    )
    var scroll := ScrollContainer.new()
    scroll.position = FRAME.position + Vector2(14, 60)
    scroll.size = Vector2(FRAME.size.x - 28, FRAME.size.y - 86)
    add_child(scroll)
    _list = VBoxContainer.new()
    _list.custom_minimum_size = Vector2(FRAME.size.x - 44, 0)
    _list.add_theme_constant_override("separation", 3)
    scroll.add_child(_list)
    hud._label("Mysterious Eggs drop now and then from creatures (more from elites and bosses) · V / Esc: close", FRAME.position + Vector2(14, FRAME.size.y - 22), Vector2(FRAME.size.x - 28, 14), self, 8).add_theme_color_override("font_color", UI.TEXT_DIM)
    hide()

func is_open() -> bool:
    return visible

func open() -> void:
    if hud.menu_open():
        return
    _paused_before = get_tree().paused
    if hud.session.active:
        hud.player.input_blocked = true
        hud.session.request_action("menu", {"open": true})
    else:
        get_tree().paused = true
    show()
    refresh()

func close_panel() -> void:
    if not visible:
        return
    hide()
    if hud.session.active:
        hud.player.input_blocked = false
        hud.session.request_action("menu", {"open": false})
    get_tree().paused = _paused_before

func refresh() -> void:
    for child in _list.get_children():
        child.queue_free()
    var progression: Dictionary = hud.player.progression
    var owned: Array = PETS.owned(progression)
    var following := PETS.active(progression)
    var eggs: int = hud.player.get_node("Inventory").count_of(PETS.EGG)
    _summary.text = "%d of %d pets · following you: %s · eggs: %d" % [owned.size(), PETS.ORDER.size(), PETS.PETS[following][0] if not following.is_empty() else "none", eggs]
    _hatch.disabled = eggs <= 0 or owned.size() >= PETS.ORDER.size()
    for id in PETS.ORDER:
        var row := HBoxContainer.new()
        row.custom_minimum_size = Vector2(FRAME.size.x - 44, 34)
        row.add_theme_constant_override("separation", 8)
        _list.add_child(row)
        var portrait := TextureRect.new()
        portrait.texture = PETS.face(id)
        portrait.custom_minimum_size = Vector2(30, 30)
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        var have: bool = id in owned
        portrait.modulate = Color.WHITE if have else Color(0, 0, 0, 0.6)
        row.add_child(portrait)
        var label: Label = hud._label("%s\n%s" % [PETS.PETS[id][0] if have else "???", PETS.PETS[id][1] if have else "Not hatched yet"], Vector2.ZERO, Vector2(10, 30), row, 9)
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.add_theme_color_override("font_color", UI.GOLD_LIGHT if id == following else (UI.TEXT if have else UI.TEXT_DIM))
        if have:
            var button: Button = hud._button("Following" if id == following else "Choose", Vector2.ZERO, Vector2(90, 22), row)
            button.custom_minimum_size = Vector2(90, 22)
            button.add_theme_font_size_override("font_size", 9)
            button.pressed.connect(func():
                hud.session.request_action("pet", {"operation": "choose", "id": "" if id == following else id})
                await get_tree().process_frame
                refresh()
            )

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if event.is_action_pressed("ui_cancel") or (event.is_action_pressed("pets") and not event.is_echo()):
        close_panel()
        get_viewport().set_input_as_handled()
