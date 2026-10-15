extends SceneTree
## Item cards (step 21b, user's tooltip reference): rarity frame and colours, badges, weapon DPS and
## speed, stat rows with green bonuses / red penalties and roll ranges, passives and active only
## where the item has them, place footer, rebuild only on change, and the equipment window's card.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const UI := preload("res://scripts/ui/ui_style.gd")
const CARD := preload("res://scripts/ui/item_card.gd")
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
    var holder := Control.new()
    root.add_child(holder)
    var rng := RandomNumberGenerator.new()
    rng.seed = 21
    var scythe: Dictionary = GEAR.roll("field_scythe", 4, rng)
    var mail: Dictionary = GEAR.roll("scale_mail", 1, rng)
    var hood: Dictionary = GEAR.roll("cloth_hood", 0, rng)
    var card: PanelContainer = CARD.new()
    holder.add_child(card)
    # --- Legendary weapon
    card.show_item(scythe, "In the bag")
    await _frames(2)
    var gold := Color(GEAR.RARITY_COLORS[4])
    var name_label: Label = card.find_child("Name", true, false)
    _check(card.get_theme_stylebox("panel").border_color == gold and name_label.get_theme_color("font_color") == gold and name_label.text == "Field Scythe", "The card and the name take the rarity colour")
    _check(card.find_child("RarityBadge", true, false).text == "LEGENDARY" and card.find_child("TypeBadge", true, false).text == "SCYTHE", "Rarity and type badges")
    _check((card.find_child("Icon", true, false) as TextureRect).texture == UI.gear_icon(scythe), "The item's own icon sits in the rarity frame")
    var expected_dps := roundi(float(scythe.stats.damage) / GEAR.WEAPONS.scythe.recovery)
    _check(card.find_child("Dps", true, false).text == str(expected_dps) and card.find_child("Speed", true, false).text == "Slow scythe · 1.3 hits/s", "Weapons show DPS (damage x hits per second) and attack speed")
    var text: String = card.plain_text()
    var passives_ok := true
    for passive in scythe.passives:
        passives_ok = passives_ok and text.contains(GEAR.PASSIVES[passive])
    _check(passives_ok and scythe.passives.size() == 2 and text.contains("Active (G): " + GEAR.ACTIVES[scythe.active].name), "Legendary items list both passives and the active")
    var span: Array = GEAR.stat_range("field_scythe", "damage", 4)
    _check(text.contains("Weapon damage") and text.contains("%d  (%d to %d)" % [int(scythe.stats.damage), int(span[0]), int(span[1])]), "Stat rows show the value and its roll range for this rarity")
    var longest: Dictionary = scythe.duplicate(true)
    longest.passives = ["lifesteal", "thorns"]
    longest.active = "barrier"
    card.show_item(longest, "In the bag")
    await _frames(2)
    _check(is_equal_approx(card.size.x, CARD.WIDTH) and card.size.y <= CARD.MAX_HEIGHT, "The longest card (Legendary weapon, longest passives, active) fits 176 x %d: %s" % [CARD.MAX_HEIGHT, card.size])
    # --- Penalties in red, bonuses in green
    card.show_item(mail, "Worn: Body")
    await _frames(2)
    var stats: GridContainer = card.find_child("Stats", true, false)
    var colours := {}
    for index in range(0, stats.get_child_count(), 2):
        colours[stats.get_child(index).text] = stats.get_child(index + 1).get_theme_color("font_color")
    _check(colours["Move speed"] == CARD.BAD and colours["Max HP"] == CARD.GOOD and colours["Damage taken"] == CARD.GOOD, "Penalties are red; bonuses (including less damage taken) are green")
    _check(stats.get_child_count() == mail.stats.size() * 2 and card.plain_text().contains("Worn: Body") and card.find_child("Dps", true, false) == null, "One row per stat, the place footer, and no DPS on armor")
    # --- Common: just its stat
    card.show_item(hood)
    await _frames(2)
    _check(card.find_child("Active", true, false) == null and not card.plain_text().contains("•") and card.find_child("Stats", true, false).get_child_count() == 2, "Common items show only their stat, no passives or active")
    var first: Node = card.find_child("Name", true, false)
    card.show_item(hood)
    _check(card.find_child("Name", true, false) == first, "Showing the same item again does not rebuild the card")
    card.show_item({})
    _check(not card.visible, "No item, no card")
    holder.queue_free()
    # --- Equipment window
    var world: Node2D = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    var actor = world.get_local_player()
    var hud = world.get_node("HUD")
    actor.add_item(scythe)
    actor.add_item(hood)
    actor.equip(hood.id, "head")
    hud.gear_panel.open()
    hud.gear_panel._hovered = scythe.id
    await _frames(2)
    _check(hud.gear_panel.card.visible and hud.gear_panel.card.item.id == scythe.id and hud.gear_panel.card.plain_text().contains("In the bag") and not hud.gear_panel._details.visible, "Hovering an item in the grid shows its card")
    hud.gear_panel._hovered = hood.id
    await _frames(2)
    _check(hud.gear_panel.card.item.id == hood.id and hud.gear_panel.card.plain_text().contains("Worn: Head"), "Hovering another item (or a worn slot) previews its card")
    _check(not hud.gear_panel.card.get_rect().intersects(hud.gear_panel._equip.get_rect()), "The card never covers the Equip button")
    hud.gear_panel.close()
    world.queue_free()
    await _frames()
    print("Item card checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
