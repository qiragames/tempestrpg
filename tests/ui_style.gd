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
    # The equipment window is shown with random chest gear; class rules (M12b) are not the point here.
    preload("res://scripts/progression/class_catalogue.gd").enforced = false
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
    var hud: CanvasLayer = world.get_node("HUD")
    var actor = world.get_local_player()
    # --- Theme
    _check(UI.installed and UI.theme() == UI.theme() and ThemeDB.get_default_theme().get_stylebox("panel", "Panel").get_script() == UI.PIXEL_BOX and ThemeDB.get_default_theme().default_font == UI.font("body"), "One shared theme (pixel frames, pixel font) is installed for every interface")
    var frame = UI.theme().get_stylebox("panel", "Panel")
    _check(frame.texture != null and frame.tint.a > 0.9 and UI.ornate("hud").tint.a < 0.9 and UI.ornate("assistant").tint.g > UI.ornate("assistant").tint.r and UI.ornate("card", Color.RED).accent == Color.RED, "Windows use the navy pixel frame (HUD blocks see-through); analysis is tinted teal; cards take the rarity colour")
    _check(UI.font("body").fixed_size == 16 and UI.font("small").fixed_size == 16 and UI.font("head").fixed_size == 14, "The pixel fonts are drawn at their native sizes")
    var button := Button.new()
    hud.add_child(button)
    _check(button.get_theme_stylebox("hover").tint.r > button.get_theme_stylebox("normal").tint.r and button.get_theme_stylebox("focus").border_color == UI.CYAN, "Buttons light up on hover and show a cyan keyboard focus")
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
    _check(hud._hp_bar.size.y == 12 and hud.get_node("MagiculeBar").size.y == 12 and hud._xp_bar.size.y == 6, "Bars keep the pack's bar sizes (no text-height inflation)")
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
    # --- Layout: no overlaps at 640x360 (at full HUD size; smaller sizes shrink toward the corners)
    hud.apply_hud_settings({"hud": 1.0, "controls": true})
    await _frames(1)
    var rects: Dictionary = {"status": Rect2(4, 4, 226, 66), "analysis": Rect2(486, 40, 150, 82), "hotbar": Rect2(176, 288, 304, 52), "log": Rect2(4, 266, 166, 72), "controls": Rect2(0, 338, 640, 22)}
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
    hud.apply_hud_settings({"hud": 0.75, "controls": false})
    await _frames(1)
    var small_ok: bool = not hud.get_node("Controls").visible and not hud.get_node("BottomBar").visible
    for slot in hud._slots:
        small_ok = small_ok and screen.encloses(slot.get_global_rect()) and slot.get_global_rect().size.x < 70.0
    small_ok = small_ok and screen.encloses(hud.get_node("Minimap").get_global_rect()) and hud.get_node("Minimap").get_global_rect().end.x > 620.0
    _check(small_ok, "At 75% the HUD shrinks toward its corners (still on screen) and the controls line can be hidden")
    hud.apply_hud_settings({"hud": 1.0, "controls": true})
    _check(hud.get_node("Health").get_index() < hud._modal.get_index() and hud.get_node("Magicules").get_index() < hud.gear_panel.get_index(), "Windows cover the whole HUD, including the bar texts")
    # --- Icons
    actor.get_node("Inventory").add_specimen(load("res://data/specimens/forest_gnasher.tres"))
    await _frames(2)
    _check(hud.bag_cells().size() == 1 and hud.bag_cells()[0].icon == UI.icon("gnasher_essence") and UI.icon("thornback_quill") != null, "Bag materials show their icons")
    var icons_ok := true
    for base in GEAR.BASES:
        for rarity in range(5):
            icons_ok = icons_ok and UI.gear_icon({"base": base, "rarity": rarity}) != null
    _check(icons_ok, "Every gear base has an icon for every rarity")
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    var item: Dictionary = SOURCES.roll_chest(rng)
    actor.add_item(item)
    # The slot is chosen before equipping (afterwards a ring's target is the other ring slot).
    var slot: String = hud.gear_panel.target_slot(item)
    actor.equip(item.id, slot)
    hud.gear_panel.open()
    await _frames(2)
    var spare: Dictionary = SOURCES.roll_chest(rng)
    actor.add_item(spare)
    await _frames(2)
    _check(hud.gear_panel._slot_cells[slot].item_id == item.id and hud.gear_panel._slot_cells[slot].texture != null and hud.gear_panel._grid[0].item_id == spare.id and hud.gear_panel._grid[0].texture != null, "Worn gear sits in its slot and owned gear in the grid, both with their icons")
    _check(hud.menu_open() and not hud._modal.visible, "The equipment window is modal")
    hud.gear_panel.close()
    # --- Hotbar
    _check(hud._slots.size() == 8 and hud._slots[0].text == "" and hud._slots[0].disabled, "Eight hotbar slots; empty ones are blank and disabled")
    world.queue_free()
    await _frames()
    print("UI style checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
