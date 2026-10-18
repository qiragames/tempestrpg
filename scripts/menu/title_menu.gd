extends Control
## Title screen after the user's reference (step 22): storm backdrop, logo, a framed menu with the
## slime marker. Continue opens the most recently played valid world; New Game creates a world
## (name, seed, race); Load Game lists saves (damaged ones shown, not loadable); Join a Friend;
## Settings (local display options); Credits; Quit. Every world is hosted and saved; solo play
## opens no port.
const RACES := preload("res://scripts/races/race_catalogue.gd")
const REGISTRY := preload("res://scripts/menu/world_registry.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const SETTINGS := preload("res://scripts/ui/settings.gd")
const MARKER := preload("res://scripts/ui/menu_marker.gd")
const MAIN := Rect2(40, 92, 200, 206)
const SUB := Rect2(24, 74, 300, 228)
## Third-party art credits (CREDITS.md). Kyrise's line is required by CC BY 4.0.
const CREDITS := [
    ["TempestRPG", "A private game by qiragames for friends. Built with Godot Engine 4.6 (MIT)."],
    ["Ninja Adventure Asset Pack", "Pixel-Boy and AAA · CC0 · characters, tiles, props, icons"],
    ["Pixel Crawler", "Anokolisa · creatures, crafting stations"],
    ["Gear icons", "Gear icons by Kyrise (https://kyrise.itch.io/) · CC BY 4.0"],
    ["16x16 Weapon RPG Icons", "Shade (merchant-shade) · scythe and spear icons"],
    ["Fantasy UI Borders", "Kenney (www.kenney.nl) · CC0 · ornamented frames"],
    ["Item icons", "7Soul1, Idylwild, babysamurai (OpenGameArt) · CC0 · weapons and armour"],
    ["UI assets pack", "Dogobongocat (dogobongocat.itch.io) · CC0 · panels, slots, bars; Toasty font"],
    ["m5x7 and m3x6", "Fonts by Daniel Linssen (managore.itch.io)"],
]
## Tests point this at a temporary folder.
var worlds_dir: String = REGISTRY.DEFAULT_DIR
var _panels: Dictionary = {}
var _first_focus: Dictionary = {}
var _status: Label
var _name_field: LineEdit
var _new_race: OptionButton
var _join_race: OptionButton
var _seed_field: LineEdit
var _address_field: LineEdit
## M10: join with a new character or one of your own worlds' characters.
var _join_character: OptionButton
var _own_characters: Array = []
var _world_list: ItemList
var _play: Button
var _worlds: Array = []
var _entries: Dictionary = {}
var _continue_hint: Label
var _marker: Control
var _current: String = ""
@onready var session: Node = get_node("/root/GameSession")

func _ready() -> void:
    UI.install()
    SETTINGS.apply(SETTINGS.load_settings())
    preload("res://scripts/pets/pet_followers.gd").egg_drops = true
    if has_node("/root/Audio"):
        get_node("/root/Audio").music("title")
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(load("res://scripts/menu/title_backdrop.gd").new())
    _build_logo()
    _status = _label("", Vector2(24, 304), Vector2(592, 16), self, 10)
    _outline(_status)
    _build_main()
    _build_new()
    _build_load()
    _build_join()
    _build_settings()
    _build_credits()
    _show("main")

func _outline(label: Label) -> Label:
    label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.06))
    label.add_theme_constant_override("outline_size", 4)
    return label

func _build_logo() -> void:
    var presents := _outline(_label("qiragames PRESENTS", Vector2(330, 46), Vector2(290, 14), self, 10))
    presents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var tempest := _outline(_label("TEMPEST", Vector2(330, 58), Vector2(290, 60), self, 52))
    tempest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tempest.add_theme_color_override("font_color", Color("d9dde6"))
    tempest.add_theme_color_override("font_outline_color", Color("2a2238"))
    tempest.add_theme_constant_override("outline_size", 10)
    tempest.add_theme_color_override("font_shadow_color", UI.GOLD)
    tempest.add_theme_constant_override("shadow_offset_y", 3)
    var rpg := _outline(_label("RPG", Vector2(330, 112), Vector2(290, 48), self, 40))
    rpg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rpg.add_theme_color_override("font_color", Color("e0466a"))
    rpg.add_theme_color_override("font_outline_color", Color("3a1030"))
    rpg.add_theme_constant_override("outline_size", 8)
    var developer := _outline(_label("DEVELOPED BY qiragames", Vector2(0, 340), Vector2(640, 14), self, 9))
    developer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var version := _outline(_label("prototype build", Vector2(500, 340), Vector2(132, 14), self, 9))
    version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    version.add_theme_color_override("font_color", UI.TEXT_DIM)

func _panel(id: String, rect: Rect2 = SUB) -> Panel:
    var panel := Panel.new()
    panel.name = id.capitalize() + "Panel"
    panel.position = rect.position
    panel.size = rect.size
    panel.add_theme_stylebox_override("panel", UI.ornate())
    add_child(panel)
    _panels[id] = panel
    return panel

func _label(text: String, at: Vector2, size: Vector2, parent: Node, font_size: int = 11) -> Label:
    var label := Label.new()
    label.text = text
    label.position = at
    label.size = size
    label.add_theme_font_size_override("font_size", font_size)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(label)
    return label

func _button(text: String, at: Vector2, size: Vector2, parent: Node, action: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.position = at
    button.size = size
    button.add_theme_font_size_override("font_size", 11)
    button.pressed.connect(action)
    parent.add_child(button)
    return button

func _field(placeholder: String, at: Vector2, parent: Node) -> LineEdit:
    var field := LineEdit.new()
    field.placeholder_text = placeholder
    field.position = at
    field.size = Vector2(272, 28)
    field.add_theme_font_size_override("font_size", 11)
    parent.add_child(field)
    return field

func _build_main() -> void:
    var panel := _panel("main", MAIN)
    var entries := [
        ["new", "NEW GAME", func(): _show("new")],
        ["continue", "CONTINUE", continue_last],
        ["load", "LOAD GAME", func(): _show("load")],
        ["join", "JOIN A FRIEND", func(): refresh_join_characters(); _show("join")],
        ["settings", "SETTINGS", func(): _show("settings")],
        ["credits", "CREDITS", func(): _show("credits")],
        ["quit", "QUIT", func(): get_tree().quit()],
    ]
    for index in range(entries.size()):
        var button := _button(entries[index][1], Vector2(12, 8 + index * 27), Vector2(176, 25), panel, entries[index][2])
        UI.menu_entry(button)
        _entries[entries[index][0]] = button
    _continue_hint = _outline(_label("", Vector2(MAIN.position.x, MAIN.end.y + 2), Vector2(260, 14), self, 9))
    _continue_hint.add_theme_color_override("font_color", UI.CYAN)
    _marker = MARKER.new(_entries.values())
    add_child(_marker)
    _first_focus["main"] = _entries.new

func _build_new() -> void:
    var panel := _panel("new")
    UI.heading(_label("NEW WORLD", Vector2(14, 10), Vector2(272, 20), panel, 13))
    _label("Name", Vector2(14, 34), Vector2(272, 16), panel, 10)
    _name_field = _field("My World", Vector2(14, 50), panel)
    _name_field.max_length = REGISTRY.NAME_LENGTH
    _label("Seed (empty = random, numbers or any text)", Vector2(14, 84), Vector2(272, 16), panel, 10)
    _seed_field = _field("random", Vector2(14, 100), panel)
    _new_race = _race_picker(Vector2(14, 134), panel)
    _button("Create and play", Vector2(14, 170), Vector2(170, 32), panel, create_world)
    _button("Back", Vector2(190, 170), Vector2(96, 32), panel, func(): _show("main"))
    _first_focus["new"] = _name_field

func _build_load() -> void:
    var panel := _panel("load")
    UI.heading(_label("SAVED WORLDS", Vector2(14, 10), Vector2(272, 20), panel, 13))
    _world_list = ItemList.new()
    _world_list.position = Vector2(14, 34)
    _world_list.size = Vector2(272, 128)
    _world_list.add_theme_font_size_override("font_size", 10)
    _world_list.item_selected.connect(func(_index): _play.disabled = not _selected_ok())
    _world_list.item_activated.connect(func(_index): load_selected())
    panel.add_child(_world_list)
    _play = _button("Play", Vector2(14, 170), Vector2(170, 32), panel, load_selected)
    _button("Back", Vector2(190, 170), Vector2(96, 32), panel, func(): _show("main"))
    _first_focus["load"] = _world_list

func _build_join() -> void:
    var panel := _panel("join")
    UI.heading(_label("JOIN A FRIEND", Vector2(14, 10), Vector2(272, 20), panel, 13))
    _label("Paste your friend's invite code (they make it in Esc → Invite a Friend).", Vector2(14, 34), Vector2(272, 30), panel, 10)
    _address_field = _field("invite code (TRPG1-…)", Vector2(14, 64), panel)
    _label("Character: a new one for their world, or one of yours (if they allow it)", Vector2(14, 96), Vector2(272, 14), panel, 9)
    _join_character = OptionButton.new()
    _join_character.position = Vector2(14, 110)
    _join_character.size = Vector2(272, 22)
    _join_character.add_theme_font_size_override("font_size", 9)
    panel.add_child(_join_character)
    _join_race = _race_picker(Vector2(14, 138), panel)
    _button("Join", Vector2(14, 170), Vector2(170, 32), panel, join_world)
    _button("Back", Vector2(190, 170), Vector2(96, 32), panel, func(): _show("main"))
    _first_focus["join"] = _address_field

func _build_settings() -> void:
    var panel := _panel("settings", Rect2(SUB.position.x, SUB.position.y - 6, SUB.size.x, 280))
    _first_focus["settings"] = SETTINGS.build(panel, func(): _show("main"))

func _build_credits() -> void:
    var panel := _panel("credits")
    UI.heading(_label("CREDITS", Vector2(14, 10), Vector2(180, 20), panel, 13))
    # M13: one scrolling list in the pixel fonts (pack names in gold).
    var list := RichTextLabel.new()
    list.name = "CreditList"
    list.bbcode_enabled = true
    list.scroll_active = true
    list.position = Vector2(14, 34)
    list.size = Vector2(272, 184)
    list.add_theme_font_size_override("normal_font_size", 9)
    var text := ""
    for entry in CREDITS:
        text += "[color=#%s]%s[/color]\n%s\n" % [UI.GOLD_LIGHT.to_html(false), entry[0], entry[1]]
    list.text = text
    panel.add_child(list)
    _first_focus["credits"] = _button("Back", Vector2(198, 8), Vector2(88, 22), panel, func(): _show("main"))

## Slime, Human or Demon with a one-line summary of its racial ability.
func _race_picker(at: Vector2, parent: Node) -> OptionButton:
    var picker := OptionButton.new()
    picker.position = at
    picker.size = Vector2(272, 24)
    picker.add_theme_font_size_override("font_size", 10)
    for id in RACES.ORDER:
        var stats: Dictionary = RACES.RACES[id]
        picker.add_item("%s · HP %d · Magicules %d · %s" % [id, stats.hp, stats.magicules, stats.ability.get_slice(":", 0)])
    picker.select(0)
    parent.add_child(picker)
    return picker

func _show(id: String) -> void:
    _current = id
    for key in _panels:
        _panels[key].visible = key == id
    _status.text = ""
    _marker.visible = id == "main"
    _continue_hint.visible = id == "main"
    _marker.set_process(id == "main")
    if id == "main":
        _refresh_continue()
    if id == "load":
        refresh_worlds()
    if _first_focus.has(id):
        _focus.call_deferred(_first_focus[id])

## Deferred focus, skipped if the menu left the tree meanwhile (e.g. a world was launched).
func _focus(control: Control) -> void:
    if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
        control.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
    # Esc steps back from any sub-menu.
    if event.is_action_pressed("ui_cancel") and _current != "main":
        _show("main")
        get_viewport().set_input_as_handled()

## The most recently played world that loads (damaged saves are skipped), or {}.
func last_world() -> Dictionary:
    for world in REGISTRY.list(worlds_dir):
        if world.ok:
            return world
    return {}

func _refresh_continue() -> void:
    var last := last_world()
    _entries["continue"].disabled = last.is_empty()
    _continue_hint.text = "Continue: %s · %s" % [last.name, last.map] if not last.is_empty() else ""
    if _first_focus.main == _entries["continue"] and last.is_empty():
        _first_focus.main = _entries.new
    elif not last.is_empty():
        _first_focus.main = _entries["continue"]

func continue_last() -> void:
    var last := last_world()
    if last.is_empty():
        _status.text = "No saved world to continue. Start a new game first."
        return
    _launch({"mode": "host", "path": last.path, "listen": false})

func refresh_worlds() -> void:
    _worlds = REGISTRY.list(worlds_dir)
    _world_list.clear()
    for world in _worlds:
        var when: String = Time.get_datetime_string_from_unix_time(world.last_played, true) if world.last_played > 0 else "never"
        _world_list.add_item("%s · %s · %s" % [world.name, world.map, when] if world.ok else "%s · damaged, cannot load" % world.name)
    if not _worlds.is_empty():
        _world_list.select(0)
    _play.disabled = not _selected_ok()
    if _worlds.is_empty():
        _status.text = "No saved worlds yet. Create a new world first."

func _selected_ok() -> bool:
    var selected := _world_list.get_selected_items()
    return not selected.is_empty() and _worlds[selected[0]].ok

func create_world() -> void:
    var name: String = REGISTRY.clean_name(_name_field.text)
    if name.is_empty():
        name = "My World"
    var seed: int = REGISTRY.parse_seed(_seed_field.text)
    var path: String = REGISTRY.new_world_path(name, worlds_dir)
    _launch({"mode": "host", "path": path, "listen": false, "meta": REGISTRY.new_meta(name, seed), "race": RACES.ORDER[_new_race.selected]})

func load_selected() -> void:
    if not _selected_ok():
        return
    _launch({"mode": "host", "path": _worlds[_world_list.get_selected_items()[0]].path, "listen": false})

## The join screen's character choices: a new character, then this computer's own characters.
func refresh_join_characters() -> void:
    _own_characters = preload("res://scripts/network/character_import.gd").own_characters(worlds_dir)
    _join_character.clear()
    _join_character.add_item("New character (race below)")
    for entry in _own_characters:
        _join_character.add_item("%s, level %d — from \"%s\"" % [entry.race, entry.level, entry.world])
    _join_character.select(0)

func join_world() -> void:
    var code := _address_field.text.strip_edges()
    if code.is_empty():
        _status.text = "Paste your friend's invite code first."
        return
    var codes := preload("res://scripts/network/join_codes.gd")
    if not codes.is_code(code) or codes.decode(code).is_empty():
        _status.text = "That is not a complete invite code — ask your friend for it again (Esc → Invite a Friend)."
        return
    var request := {"mode": "join_code", "code": code, "race": RACES.ORDER[_join_race.selected]}
    var choice: int = _join_character.selected if _join_character != null else 0
    if choice > 0 and choice - 1 < _own_characters.size():
        request["import"] = _own_characters[choice - 1].path
    _launch(request)

func _launch(request: Dictionary) -> void:
    session.pending_launch = request
    get_tree().change_scene_to_file(session.WORLD_SCENE)
