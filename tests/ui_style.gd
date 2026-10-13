extends SceneTree
## Reference-style interface (step 21): one shared theme, the status card's live values (HP,
## Magicules, XP, race/form portrait), item and gear icons, layout without overlaps at 640x360,
## and windows that cover the HUD completely.
const UI := preload("res://scripts/ui/ui_style.gd")
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const SOURCES := preload("res://scripts/items/gear_sources.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("_run")
func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func _frames(count: int = 3) -> void:
    for _i in range(count):
        await physics_frame
        await process_frame

func _run() -> void:
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var hud: CanvasLayer = world.get_node("HUD")
    var actor = world.get_local_player()
    # --- Theme
    _check(UI.installed and UI.theme() == UI.theme() and ThemeDB.get_default_theme().get_stylebox("panel", "Panel").border_color == UI.GOLD, "One shared theme is installed for every interface")
    var frame: StyleBoxFlat = UI.theme().get_stylebox("panel", "Panel")
    _check(frame.border_color == UI.GOLD and frame.bg_color.a > 0.9 and UI.box("assistant").border_color == UI.CYAN, "Panels are dark with gold trim; analysis uses cyan")
    var button := Button.new()
    hud.add_child(button)
    _check(button.get_theme_stylebox("hover").border_color == UI.GOLD_LIGHT and button.get_theme_stylebox("focus").border_color == UI.CYAN, "Buttons highlight in gold on hover and show a cyan keyboard focus")
    button.queue_free()
    # --- Status card
    actor.get_node("Health").take_damage(30)
    actor.get_node("Magicules")._current = 40.0
    actor.get_node("Magicules").changed.emit(40.0, actor.get_node("Magicules").maximum)
    actor.progression.experience = 30
    await _frames(2)
    _check(hud._hp_bar.value == actor.get_node("Health").current and hud._hp_bar.max_value == actor.get_node("Health").maximum and hud.get_node("Health").text.contains("70"), "The HP bar and its text follow the character's health")
    _check(is_equal_approx(hud.get_node("MagiculeBar").value, actor.get_node("Magicules").current) and hud.get_node("MagiculeBar").value < actor.get_node("Magicules").maximum, "The Magicule bar follows the character's Magicules")
    _check(hud._xp_bar.max_value == LEVELING.xp_for_level(2) - LEVELING.xp_for_level(1) and hud._xp_bar.value == 30 - LEVELING.xp_for_level(1), "The XP bar shows progress towards the next level")
    _check(hud._hp_bar.size.y == 11 and hud.get_node("MagiculeBar").size.y == 11 and hud._xp_bar.size.y == 5, "Bars keep their slim sizes (no text-height inflation)")
    _check(hud._portrait.texture == load("res://scripts/visual/sprite_library.gd").frames("slime").get_frame_texture("idle_down", 0) and hud._name.text == "Slime", "The portrait and name show the character's race")
    actor.get_node("SkillBook").record_analysis(&"forest_gnasher")
    actor.form_cooldown = 0.0
    actor.get_node("Magicules")._current = actor.get_node("Magicules").maximum
    actor.try_transform("gnasher")
    await _frames(2)
    _check(hud._name.text.contains("form") and hud._portrait.modulate == actor.MIMIC_TINT and hud._portrait_id == "gnasher", "A mimic form shows in the portrait (own colours) and the name")
    actor.form_cooldown = 0.0
    actor.try_transform("slime")
    actor.choose_race("Demon")
    await _frames(2)
    _check(hud._portrait_id == "demon" and hud._name.text == "Demon", "Changing race updates the portrait")
    # --- Layout: no overlaps at 640x360
    var rects: Dictionary = {"status": Rect2(4, 4, 226, 66), "analysis": Rect2(446, 40, 190, 82), "hotbar": Rect2(176, 288, 304, 52), "log": Rect2(4, 266, 166, 72), "controls": Rect2(0, 338, 640, 22)}
    var screen := Rect2(0, 0, 640, 360)
    var layout_ok := true
    for a in rects:
        layout_ok = layout_ok and screen.encloses(rects[a])
        for b in rects:
            if a < b and not (a == "controls" and b == "hotbar") and not (a == "controls" and b == "log"):
                layout_ok = layout_ok and not rects[a].intersects(rects[b])
    for slot in hud._slots:
        layout_ok = layout_ok and rects.hotbar.encloses(slot.get_rect())
    _check(layout_ok, "HUD blocks fit the 640x360 screen without overlapping")
    _check(hud.get_node("Health").get_index() < hud._modal.get_index() and hud.get_node("Magicules").get_index() < hud.gear_panel.get_index(), "Windows cover the whole HUD, including the bar texts")
    # --- Icons
    actor.get_node("Inventory").add_specimen(load("res://data/specimens/forest_gnasher.tres"))
    await _frames(2)
    _check(hud._items.item_count == 1 and hud._items.get_item_icon(0) == UI.icon("gnasher_essence") and UI.icon("thornback_quill") != null, "Bag materials show their icons")
    var icons_ok := true
    for base in GEAR.BASES:
        for rarity in range(5):
            icons_ok = icons_ok and UI.gear_icon({"base": base, "rarity": rarity}) != null
    _check(icons_ok, "Every gear base has an icon for every rarity")
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    var item: Dictionary = SOURCES.roll_chest(rng)
    actor.add_item(item)
    actor.equip(item.id, hud.gear_panel.target_slot(item))
    hud.gear_panel.open()
    await _frames(2)
    var slot: String = hud.gear_panel.target_slot(item)
    _check(hud.gear_panel._slot_buttons[slot].icon == UI.gear_icon(item) and hud.gear_panel._items.get_item_icon(0) == UI.gear_icon(item), "Worn and owned gear show their base and rarity icon")
    _check(hud.menu_open() and not hud._modal.visible, "The equipment window is modal")
    hud.gear_panel.close()
    # --- Hotbar
    _check(hud._slots[0].text == "Empty" and hud._slots[0].disabled, "Empty hotbar slots read Empty and are disabled")
    world.queue_free()
    await _frames()
    print("UI style checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
