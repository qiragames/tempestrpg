extends Panel
## Character-first start (user request): pick one of your characters on a detailed overview —
## a big animated model with its gear around it, stats and class, progress (professions, titles,
## playtime, last played) — then play its world or join a friend with it; or make a new character
## (name and race) and then create a world for it or join a friend. Every world's own character
## is one entry here; deleting a character deletes its world.
const STORE := preload("res://scripts/persistence/save_store.gd")
const REGISTRY := preload("res://scripts/menu/world_registry.gd")
const RACES := preload("res://scripts/races/race_catalogue.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const SPRITES := preload("res://scripts/visual/sprite_library.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const CLASSES := preload("res://scripts/progression/class_catalogue.gd")
const ATTRIBUTES := preload("res://scripts/progression/attributes.gd")
const PRO := preload("res://scripts/professions/profession_catalogue.gd")
const ACH := preload("res://scripts/progression/achievements.gd")
const NAMES := preload("res://scripts/progression/character_names.gd")
const RECT := Rect2(12, 62, 616, 238)

var menu: Control
## [{path, world, meta, record}] — record is {} for a damaged world.
var characters: Array = []
var list: ItemList
var model: AnimatedSprite2D
var model_well: Panel
var gear_cells: Array = []
var details: RichTextLabel
var name_field: LineEdit
var race_picker: OptionButton
var play: Button
var join: Button
var delete: Button
var rename: Button
var heading: Label
var _confirm_delete := false

func _init(owner_menu: Control) -> void:
    menu = owner_menu
    name = "CharacterScreen"
    position = RECT.position
    size = RECT.size
    add_theme_stylebox_override("panel", UI.ornate())
    heading = UI.heading(menu._label("YOUR CHARACTERS", Vector2(12, 8), Vector2(300, 20), self, 13))
    list = ItemList.new()
    list.position = Vector2(12, 32)
    list.size = Vector2(170, 168)
    list.add_theme_font_size_override("font_size", 10)
    list.item_selected.connect(func(_index): _show_selected())
    list.item_activated.connect(func(_index): play_selected())
    add_child(list)
    # The model in a round well, the worn gear in small slots around it.
    model_well = Panel.new()
    model_well.position = Vector2(192, 32)
    model_well.size = Vector2(150, 168)
    model_well.add_theme_stylebox_override("panel", UI.box("slot"))
    add_child(model_well)
    model = AnimatedSprite2D.new()
    model.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    model.position = Vector2(75, 96)
    model.scale = Vector2(4, 4)
    model_well.add_child(model)
    for index in range(GEAR.SLOTS.size()):
        var cell := TextureRect.new()
        cell.size = Vector2(20, 20)
        cell.position = Vector2(4 if index < 4 else 126, 8 + (index % 4) * 24)
        cell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        model_well.add_child(cell)
        gear_cells.append(cell)
    details = RichTextLabel.new()
    details.name = "Details"
    details.bbcode_enabled = true
    details.position = Vector2(352, 32)
    details.size = Vector2(252, 128)
    details.add_theme_font_size_override("normal_font_size", 9)
    details.scroll_active = true
    add_child(details)
    name_field = menu._field("Name (up to 16 letters)", Vector2(352, 162), self)
    name_field.size = Vector2(160, 24)
    name_field.max_length = NAMES.MAX_LENGTH
    rename = menu._button("Save name", Vector2(518, 162), Vector2(86, 24), self, save_name)
    race_picker = menu._race_picker(Vector2(352, 134), self)
    race_picker.size = Vector2(252, 24)
    play = menu._button("Play", Vector2(12, 206), Vector2(110, 24), self, play_selected)
    join = menu._button("Join a Friend", Vector2(128, 206), Vector2(130, 24), self, join_selected)
    delete = menu._button("Delete", Vector2(264, 206), Vector2(90, 24), self, delete_selected)
    menu._button("Back", Vector2(514, 206), Vector2(90, 24), self, func(): menu._show("main"))

func refresh() -> void:
    characters = []
    for entry in REGISTRY.list(menu.worlds_dir):
        var record: Dictionary = {}
        var meta: Dictionary = {}
        if entry.ok:
            var loaded: Dictionary = STORE.load_world(entry.path)
            var host: Variant = loaded.get("data", {}).get("players", {}).get("host")
            record = host if host is Dictionary and host.get("progression") is Dictionary else {}
            meta = loaded.get("data", {}).get("meta", {})
        characters.append({"path": entry.path, "world": entry.name, "meta": meta, "record": record, "last_played": entry.last_played})
    list.clear()
    list.add_item("+ New character")
    for entry in characters:
        if entry.record.is_empty():
            list.add_item("(damaged world: %s)" % entry.world)
            continue
        var progression: Dictionary = entry.record.progression
        list.add_item("%s · Lv %d %s" % [NAMES.display(progression), int(progression.get("level", 1)), String(progression.get("race", "Slime"))])
    list.select(1 if characters.size() > 0 else 0)
    _show_selected()

func selected_index() -> int:
    var picked := list.get_selected_items()
    return int(picked[0]) - 1 if not picked.is_empty() else -1

func selected() -> Dictionary:
    var index := selected_index()
    return characters[index] if index >= 0 and index < characters.size() else {}

func _show_selected() -> void:
    _confirm_delete = false
    delete.text = "Delete"
    var entry := selected()
    var making := selected_index() < 0
    race_picker.visible = making
    play.text = "Create a World" if making else "Play"
    join.disabled = false
    delete.disabled = making or entry.is_empty()
    if making:
        heading.text = "NEW CHARACTER"
        name_field.text = ""
        name_field.visible = true
        rename.visible = false
        _set_model(String(RACES.ORDER[race_picker.selected]), {}, [])
        details.text = "[color=#%s]A new character[/color]\nGive it a name and choose its race, then create a world for it or join a friend (as a new character in their world)." % UI.GOLD_LIGHT.to_html(false)
        play.disabled = false
        return
    heading.text = "YOUR CHARACTERS"
    var record: Dictionary = entry.get("record", {})
    if record.is_empty():
        details.text = "This world's save is damaged and cannot be loaded."
        play.disabled = true
        join.disabled = true
        name_field.visible = false
        rename.visible = false
        _set_model("Slime", {}, [])
        return
    play.disabled = false
    var progression: Dictionary = record.progression
    var unnamed := NAMES.of(progression).is_empty()
    name_field.visible = unnamed
    rename.visible = unnamed
    name_field.text = ""
    _set_model(String(progression.get("race", "Slime")), progression.get("equipment", {}), record.get("gear", {}).get("items", []))
    details.text = describe(entry)

## The overview text for a character.
func describe(entry: Dictionary) -> String:
    var record: Dictionary = entry.record
    var progression: Dictionary = record.progression
    var gold := UI.GOLD_LIGHT.to_html(false)
    var lines: Array = []
    lines.append("[color=#%s]%s[/color]%s" % [gold, NAMES.display(progression), "  (no name yet — name it below)" if NAMES.of(progression).is_empty() else ""])
    var chosen := CLASSES.chosen(progression)
    var class_text: String = "No class yet" if chosen.main.is_empty() else CLASSES.CLASSES[chosen.main][0] + (" / " + CLASSES.CLASSES[chosen.sub][0] if not chosen.sub.is_empty() else "")
    lines.append("Level %d %s · %s" % [int(progression.get("level", 1)), String(progression.get("race", "Slime")), class_text])
    var health: Dictionary = record.get("health", {})
    var magicules: Dictionary = record.get("magicules", {})
    lines.append("HP %d · Magicules %d · Zeni %d" % [int(health.get("maximum", 0)), int(magicules.get("maximum", 0)), int(progression.get("zeni", 0))])
    var attributes: Array = []
    for key in ATTRIBUTES.KEYS:
        attributes.append("%s %d" % [ATTRIBUTES.SHORT[key], ATTRIBUTES.value(progression, key)])
    lines.append(" · ".join(attributes) + " · gear score %d" % gear_score(progression.get("equipment", {}), record.get("gear", {}).get("items", [])))
    var crafts: Array = []
    for profession in PRO.PROFESSIONS:
        var level: int = PRO.level_of(progression, profession)
        if level > 1:
            crafts.append([level, "%s %d" % [PRO.PROFESSIONS[profession][0], level]])
    crafts.sort_custom(func(a, b): return a[0] > b[0])
    lines.append("Crafts: " + (", ".join(crafts.slice(0, 4).map(func(entry_craft): return entry_craft[1])) if not crafts.is_empty() else "none yet"))
    var earned: int = progression.get("achievements", {}).size() if progression.get("achievements") is Dictionary else 0
    var title := String(progression.get("title", ""))
    lines.append("Achievements %d%s · pets %d" % [earned, " · title: " + ACH.title_of(title) if not title.is_empty() else "", progression.get("pets", []).size() if progression.get("pets") is Array else 0])
    var seconds := int(float(progression.get("playtime", 0.0)))
    var when: String = Time.get_datetime_string_from_unix_time(int(entry.last_played), true) if int(entry.last_played) > 0 else "never"
    lines.append("Played %dh %02dm · last %s" % [seconds / 3600, (seconds / 60) % 60, when.left(16)])
    lines.append("Home world: %s" % entry.world)
    return "\n".join(lines)

static func gear_score(equipment: Dictionary, items: Array) -> int:
    var total := 0.0
    for slot in equipment:
        for item in items:
            if item is Dictionary and item.get("id") == equipment[slot] and GEAR.BASES.has(item.get("base", "")):
                total += (10.0 + 8.0 * float(GEAR.BASES[item.base].get("level", 1))) * GEAR.RARITY_SCALE[int(item.rarity)]
    return int(round(total))

func _set_model(race: String, equipment: Dictionary, items: Array) -> void:
    var body: String = {"Slime": "slime", "Human": "human", "Demon": "demon"}.get(race, "slime")
    model.sprite_frames = SPRITES.frames(body)
    var animation := "idle_down" if model.sprite_frames.has_animation("idle_down") else "idle"
    model.play(animation)
    for index in range(GEAR.SLOTS.size()):
        var slot: String = GEAR.SLOTS[index]
        var texture: Texture2D = null
        for item in items:
            if item is Dictionary and item.get("id") == equipment.get(slot, ""):
                texture = UI.gear_icon(item)
        gear_cells[index].texture = texture

func _process(_delta: float) -> void:
    if visible and selected_index() < 0 and model.sprite_frames != null:
        # The new character's model follows the race picker.
        var body: String = {"Slime": "slime", "Human": "human", "Demon": "demon"}.get(String(RACES.ORDER[race_picker.selected]), "slime")
        if model.sprite_frames != SPRITES.frames(body):
            _set_model(String(RACES.ORDER[race_picker.selected]), {}, [])

func _new_name() -> String:
    return NAMES.clean(name_field.text)

func play_selected() -> void:
    if selected_index() < 0:
        if _new_name().is_empty():
            menu._status.text = "Give your new character a name first."
            return
        menu.start_new_character(_new_name(), race_picker.selected)
        return
    var entry := selected()
    if entry.get("record", {}).is_empty():
        return
    if NAMES.of(entry.record.progression).is_empty():
        if _new_name().is_empty():
            menu._status.text = "Name your character first (below the overview)."
            return
        save_name()
    menu._launch({"mode": "host", "path": entry.path, "listen": false})

func join_selected() -> void:
    if selected_index() < 0:
        if _new_name().is_empty():
            menu._status.text = "Give your new character a name first."
            return
        menu.join_as_new(_new_name(), race_picker.selected)
        return
    var entry := selected()
    if entry.get("record", {}).is_empty():
        return
    if NAMES.of(entry.record.progression).is_empty() and not _new_name().is_empty():
        save_name()
    menu.join_as_own(entry.path)

## Write the typed name into the character's world.
func save_name() -> void:
    var entry := selected()
    var name := _new_name()
    if entry.is_empty() or name.is_empty():
        menu._status.text = "Type a name first."
        return
    var loaded: Dictionary = STORE.load_world(entry.path)
    if not loaded.get("ok", false):
        menu._status.text = "Could not open that world."
        return
    var data: Dictionary = loaded.data.duplicate(true)
    data.players.host.progression["name"] = name
    if STORE.write_world(entry.path, data) != OK:
        menu._status.text = "Could not save the name."
        return
    var index := list.get_selected_items()[0]
    refresh()
    list.select(index)
    _show_selected()
    menu._status.text = "Named %s." % name

## Delete asks twice; it removes the character's world (and its backup).
func delete_selected() -> void:
    var entry := selected()
    if entry.is_empty():
        return
    if not _confirm_delete:
        _confirm_delete = true
        delete.text = "Really?"
        menu._status.text = "Click Delete again to delete %s and the world \"%s\" for good." % [NAMES.display(entry.record.progression) if not entry.record.is_empty() else "this character", entry.world]
        return
    for path in [entry.path, entry.path + ".bak", entry.path.get_basename() + ".bak"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path)
    menu._status.text = "Deleted."
    refresh()
