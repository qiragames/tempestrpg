extends RefCounted
## Classes (M12b, user design): the old master in your settlement lets you choose a main class and,
## from level 20, a subclass. A class allows its weapon type; the main class also teaches its two
## class skills (M12c: one when chosen, one at level 25). Every weapon needs its class as main or
## subclass (classless characters may use weapons up to Rare); every item needs its level;
## Legendary and Mythic items also need attributes. Kept per character in progression.classes
## {"main": id or "", "sub": id or ""}.
const GEAR := preload("res://scripts/items/gear_catalogue.gd")
const ATTRIBUTES := preload("res://scripts/progression/attributes.gd")

## id → [name, weapon type, main attribute, second attribute, description]
const CLASSES := {
    "assassin": ["Assassin", "dagger", "dex", "str", "Quick daggers, critical strikes and shadows."],
    "warrior": ["Warrior", "sword", "str", "vit", "Swords, a strong arm and a thick skin."],
    "lancer": ["Lancer", "spear", "str", "dex", "Spears that reach through a whole line of foes."],
    "reaper": ["Reaper", "scythe", "str", "int", "Wide scythe sweeps that harvest crowds."],
    "archer": ["Archer", "bow", "dex", "str", "Bows: strike from far away."],
    "mage": ["Mage", "staff", "int", "vit", "Staffs that hurl magic bolts; the strongest skills."],
    "monk": ["Monk", "fist", "dex", "vit", "Fist weapons and a flurry of blows."],
}
const ORDER := ["warrior", "assassin", "lancer", "reaper", "archer", "mage", "monk"]
const SUB_LEVEL := 20
## Classless characters may use weapons up to this rarity (Rare).
const CLASSLESS_RARITY := 2
## Changing a class or subclass (once chosen) costs this many Zeni per character level; so does
## resetting the attribute points.
const CHANGE_PER_LEVEL := 100
## Attribute requirements of Legendary (4) and Mythic (5) pieces, as shares of the item level:
## weapons ask for their class's main attribute (Mythic also the second); armour for Vitality and
## jewellery for Intelligence, a little less.
const NEEDS := {4: [0.5, 0.0], 5: [0.9, 0.25]}
const GEAR_NEEDS := {4: 0.35, 5: 0.6}
## Older suites that test items, weapons and trading (not classes) switch the requirements off.
static var enforced := true

static func chosen(progression: Dictionary) -> Dictionary:
    var stored: Variant = progression.get("classes")
    return {"main": String(stored.get("main", "")) if stored is Dictionary else "", "sub": String(stored.get("sub", "")) if stored is Dictionary else ""}

static func class_for_weapon(weapon: String) -> String:
    for id in CLASSES:
        if CLASSES[id][1] == weapon:
            return id
    return ""

static func change_price(progression: Dictionary) -> int:
    return CHANGE_PER_LEVEL * int(progression.get("level", 1))

## What an item asks of its wearer: {"level": n, "class": id or "", "attributes": {key: n}}.
static func requirements(item: Dictionary) -> Dictionary:
    var spec: Dictionary = GEAR.BASES.get(item.get("base", ""), {})
    var level: int = int(spec.get("level", 1))
    var result := {"level": level, "class": "", "attributes": {}}
    var rarity: int = int(item.get("rarity", 0))
    if spec.has("weapon"):
        result["class"] = class_for_weapon(String(spec.weapon))
        if NEEDS.has(rarity) and not String(result["class"]).is_empty():
            var info: Array = CLASSES[result["class"]]
            result.attributes[info[2]] = int(round(level * float(NEEDS[rarity][0])))
            if float(NEEDS[rarity][1]) > 0.0:
                result.attributes[info[3]] = int(round(level * float(NEEDS[rarity][1])))
    elif GEAR_NEEDS.has(rarity):
        var key := "int" if spec.get("slot", "") == "accessory" else "vit"
        result.attributes[key] = int(round(level * float(GEAR_NEEDS[rarity])))
    return result

## Why a character cannot use an item ("" when they can).
static func problem(progression: Dictionary, item: Dictionary) -> String:
    if not enforced:
        return ""
    var needs := requirements(item)
    if int(progression.get("level", 1)) < int(needs.level):
        return "Needs level %d." % int(needs.level)
    var mine := chosen(progression)
    var wanted: String = String(needs["class"])
    if not wanted.is_empty():
        if mine.main.is_empty() and mine.sub.is_empty():
            if int(item.get("rarity", 0)) > CLASSLESS_RARITY:
                return "Choose a class at the master in your settlement to use %s weapons above Rare." % CLASSES[wanted][0].to_lower()
        elif wanted != mine.main and wanted != mine.sub:
            return "Only a %s (class or subclass) can use this." % CLASSES[wanted][0]
    for key in needs.attributes:
        if ATTRIBUTES.value(progression, key) < int(needs.attributes[key]):
            return "Needs %s %d." % [ATTRIBUTES.SHORT[key], int(needs.attributes[key])]
    return ""

## "Lv 48 · Archer · DEX 43, STR 12" for item cards.
static func requirement_text(item: Dictionary) -> String:
    var needs := requirements(item)
    var parts: Array = ["Lv %d" % int(needs.level)]
    if not String(needs["class"]).is_empty():
        parts.append(CLASSES[needs["class"]][0])
    for key in needs.attributes:
        parts.append("%s %d" % [ATTRIBUTES.SHORT[key], int(needs.attributes[key])])
    return " · ".join(parts)

static func valid(progression: Dictionary) -> bool:
    if not progression.has("classes"):
        return true
    var stored: Variant = progression.classes
    if not stored is Dictionary or stored.size() != 2 or not stored.get("main") is String or not stored.get("sub") is String:
        return false
    for key in ["main", "sub"]:
        if not String(stored[key]).is_empty() and not CLASSES.has(stored[key]):
            return false
    if not String(stored.sub).is_empty() and (String(stored.main).is_empty() or stored.sub == stored.main or int(progression.get("level", 1)) < SUB_LEVEL):
        return false
    return true
