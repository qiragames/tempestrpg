extends RefCounted
## Controller support and key rebinding (M11g, user request "if easy"). Gamepad buttons and sticks
## are added to the game's actions at start (Xbox layout names; any standard pad works):
##   left stick / d-pad move · A strike · X interact (F) · Y absorb · LB/RB/LT/RT skills 1-4
##   B or Start pause / back · Back (View) bag · right stick click map · left stick click mimic.
## The keyboard keys of the main actions can be changed in Options → Keys; the choices live in
## user://settings.cfg ("keys" section) on this computer only and are applied at start.

## Rebindable actions in the Keys list: [action, label].
const REBINDABLE := [
    ["move_up", "Move up"], ["move_down", "Move down"], ["move_left", "Move left"], ["move_right", "Move right"], ["sprint", "Sprint"], ["dash", "Dash"],
    ["attack", "Strike"], ["absorb", "Absorb"], ["interact", "Interact / talk"], ["transform", "Mimic form"],
    ["skill_1", "Skill 1"], ["skill_2", "Skill 2"], ["skill_3", "Skill 3"], ["skill_4", "Skill 4"],
    ["skill_5", "Skill 5"], ["skill_6", "Skill 6"], ["skill_7", "Skill 7"], ["skill_8", "Skill 8"],
    ["use_draught", "Draught"], ["use_tonic", "Tonic"], ["gear_active", "Gear active"], ["mount", "Ride"],
    ["inventory", "Bag"], ["skill_tree", "Skill tree"], ["world_map", "World map"], ["quests", "Quests"],
    ["professions", "Professions"], ["party", "Party"], ["achievements", "Titles"], ["pets", "Pets"], ["army", "Army"],
]
## Gamepad: action → [buttons], and axes [action, axis, direction].
const BUTTONS := {
    "attack": [JOY_BUTTON_A], "interact": [JOY_BUTTON_X], "absorb": [JOY_BUTTON_Y],
    "skill_1": [JOY_BUTTON_LEFT_SHOULDER], "skill_2": [JOY_BUTTON_RIGHT_SHOULDER],
    "inventory": [JOY_BUTTON_BACK], "world_map": [JOY_BUTTON_RIGHT_STICK], "transform": [JOY_BUTTON_LEFT_STICK],
    "move_up": [JOY_BUTTON_DPAD_UP], "move_down": [JOY_BUTTON_DPAD_DOWN], "move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT],
    "ui_cancel": [JOY_BUTTON_START],
}
const AXES := [
    ["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0],
    ["move_up", JOY_AXIS_LEFT_Y, -1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0],
    ["skill_3", JOY_AXIS_TRIGGER_LEFT, 1.0], ["skill_4", JOY_AXIS_TRIGGER_RIGHT, 1.0],
]

## Add the gamepad events (once) and the saved key choices.
static func install(keys: Dictionary = {}) -> void:
    for action in BUTTONS:
        if not InputMap.has_action(action):
            continue
        for button in BUTTONS[action]:
            if not _has_button(action, button):
                var event := InputEventJoypadButton.new()
                event.button_index = button
                InputMap.action_add_event(action, event)
    for entry in AXES:
        if not InputMap.has_action(entry[0]) or _has_axis(entry[0], entry[1], entry[2]):
            continue
        var motion := InputEventJoypadMotion.new()
        motion.axis = entry[1]
        motion.axis_value = entry[2]
        InputMap.action_add_event(entry[0], motion)
    for action in keys:
        rebind(String(action), int(keys[action]))

static func _has_button(action: String, button: int) -> bool:
    return InputMap.action_get_events(action).any(func(event): return event is InputEventJoypadButton and event.button_index == button)

static func _has_axis(action: String, axis: int, direction: float) -> bool:
    return InputMap.action_get_events(action).any(func(event): return event is InputEventJoypadMotion and event.axis == axis and signf(event.axis_value) == signf(direction))

const ICONS := preload("res://scripts/ui/key_icons.gd")

## The action's binding: its first keyboard key (physical keycode) or mouse button
## (KeyIcons.MOUSE_BASE + button); 0 for none.
static func key_of(action: String) -> int:
    return ICONS.code_of(action)

static func key_name(action: String) -> String:
    return ICONS.name_of(key_of(action))

## Replace an action's keyboard keys and mouse buttons with one key or mouse button (user
## request: controls on mouse buttons too); gamepad events stay.
static func rebind(action: String, code: int) -> bool:
    if not InputMap.has_action(action) or code <= 0 or not REBINDABLE.any(func(entry): return entry[0] == action):
        return false
    if ICONS.is_mouse(code) and (code - ICONS.MOUSE_BASE < 1 or code - ICONS.MOUSE_BASE > 9):
        return false
    for event in InputMap.action_get_events(action):
        if event is InputEventKey or event is InputEventMouseButton:
            InputMap.action_erase_event(action, event)
    if ICONS.is_mouse(code):
        var button := InputEventMouseButton.new()
        button.button_index = code - ICONS.MOUSE_BASE
        InputMap.action_add_event(action, button)
    else:
        var key := InputEventKey.new()
        key.physical_keycode = code
        InputMap.action_add_event(action, key)
    return true

## Actions whose key is the same as another rebindable action's (to warn in the list).
static func clashes() -> Array:
    var seen := {}
    var clash: Array = []
    for entry in REBINDABLE:
        var key := key_of(entry[0])
        if key == 0:
            continue
        if seen.has(key):
            clash.append(entry[0])
            clash.append(seen[key])
        seen[key] = entry[0]
    return clash
