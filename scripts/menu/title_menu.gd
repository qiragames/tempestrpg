extends Control
## Functional title menu (final presentation follows in step 22): new world with name and seed,
## saved worlds, join a friend, quit. Every world is hosted and saved; solo play opens no port.
const RACES := preload("res://scripts/races/race_catalogue.gd")
const REGISTRY := preload("res://scripts/menu/world_registry.gd")
## Tests point this at a temporary folder.
var worlds_dir: String = REGISTRY.DEFAULT_DIR
var _panels: Dictionary = {}
var _status: Label
var _name_field: LineEdit
var _new_race: OptionButton
var _join_race: OptionButton
var _seed_field: LineEdit
var _address_field: LineEdit
var _world_list: ItemList
var _play: Button
var _worlds: Array = []
@onready var session: Node = get_node("/root/GameSession")

func _ready() -> void:
    # Shared interface look (step 21); the full title/pause flow is step 22.
    preload("res://scripts/ui/ui_style.gd").install()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var back := ColorRect.new()
    back.color = Color("0f1a24")
    back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(back)
    var title := _label("TEMPEST RPG", Vector2(0, 34), Vector2(640, 40), self, 28)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", Color("a6ebdc"))
    var subtitle := _label("Prototype · placeholder title screen", Vector2(0, 74), Vector2(640, 18), self, 10)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status = _label("", Vector2(40, 318), Vector2(560, 32), self, 10)
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _build_main()
    _build_new()
    _build_load()
    _build_join()
    _show("main")

func _panel(id: String) -> Panel:
    var panel := Panel.new()
    panel.position = Vector2(170, 104)
    panel.size = Vector2(300, 206)
    panel.add_theme_stylebox_override("panel", preload("res://scripts/ui/ui_style.gd").box())
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
    var panel := _panel("main")
    var entries := [["New World", func(): _show("new")], ["Load World", func(): _show("load")], ["Join a Friend", func(): _show("join")], ["Quit", func(): get_tree().quit()]]
    for index in range(entries.size()):
        _button(entries[index][0], Vector2(14, 16 + index * 46), Vector2(272, 36), panel, entries[index][1])

func _build_new() -> void:
    var panel := _panel("new")
    _label("NEW WORLD", Vector2(14, 10), Vector2(272, 20), panel, 13)
    _label("Name", Vector2(14, 34), Vector2(272, 16), panel, 10)
    _name_field = _field("My World", Vector2(14, 50), panel)
    _name_field.max_length = REGISTRY.NAME_LENGTH
    _label("Seed (empty = random, numbers or any text)", Vector2(14, 84), Vector2(272, 16), panel, 10)
    _seed_field = _field("random", Vector2(14, 100), panel)
    _new_race = _race_picker(Vector2(14, 130), panel)
    _button("Create and play", Vector2(14, 158), Vector2(170, 32), panel, create_world)
    _button("Back", Vector2(190, 158), Vector2(96, 32), panel, func(): _show("main"))

func _build_load() -> void:
    var panel := _panel("load")
    _label("SAVED WORLDS", Vector2(14, 10), Vector2(272, 20), panel, 13)
    _world_list = ItemList.new()
    _world_list.position = Vector2(14, 34)
    _world_list.size = Vector2(272, 116)
    _world_list.add_theme_font_size_override("font_size", 10)
    _world_list.item_selected.connect(func(_index): _play.disabled = not _selected_ok())
    _world_list.item_activated.connect(func(_index): load_selected())
    panel.add_child(_world_list)
    _play = _button("Play", Vector2(14, 158), Vector2(170, 32), panel, load_selected)
    _button("Back", Vector2(190, 158), Vector2(96, 32), panel, func(): _show("main"))

func _build_join() -> void:
    var panel := _panel("join")
    _label("JOIN A FRIEND", Vector2(14, 10), Vector2(272, 20), panel, 13)
    _label("Your friend opens their world to friends (Esc → Open to friends) and tells you their address.", Vector2(14, 34), Vector2(272, 44), panel, 10)
    _address_field = _field("e.g. 192.168.1.10", Vector2(14, 84), panel)
    _label("Race for a new character (returning characters keep theirs)", Vector2(14, 114), Vector2(272, 14), panel, 9)
    _join_race = _race_picker(Vector2(14, 128), panel)
    _button("Join", Vector2(14, 158), Vector2(170, 32), panel, join_world)
    _button("Back", Vector2(190, 158), Vector2(96, 32), panel, func(): _show("main"))

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
    for key in _panels:
        _panels[key].visible = key == id
    _status.text = ""
    if id == "load":
        refresh_worlds()

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

func join_world() -> void:
    var address := _address_field.text.strip_edges()
    if address.is_empty():
        _status.text = "Enter your friend's address first."
        return
    _launch({"mode": "join", "address": address, "race": RACES.ORDER[_join_race.selected]})

func _launch(request: Dictionary) -> void:
    session.pending_launch = request
    get_tree().change_scene_to_file(session.WORLD_SCENE)
