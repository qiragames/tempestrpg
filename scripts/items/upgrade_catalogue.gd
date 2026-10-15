extends RefCounted
## Runes and augments (M4.5d, user decisions). Runes go into gear sockets (by rarity: Common 0,
## Uncommon 0, Rare 1, Epic 1, Legendary 2) at the camp Smithy; replacing a rune destroys the old
## one. Augments are permanent character upgrades in slots unlocked by level (1 at 5, 2 at 10,
## 3 at 15), installed at the camp's Essence Shrine for Zeni (the replaced one returns to the bag).
## Both are bag goods until used.
const SOCKETS := [0, 0, 1, 1, 2, 3]
## rune → [name, stat (gear stat) or passive ("lifesteal", "thorns"), value, price]
const RUNES := {
    "rune_vigor": ["Rune of Vigor", "hp", 12.0, 260],
    "rune_focus": ["Rune of Focus", "magicules", 10.0, 260],
    "rune_swift": ["Rune of Swiftness", "speed", 5.0, 300],
    "rune_might": ["Rune of Might", "strike", 2.0, 340],
    "rune_ward": ["Rune of Warding", "defense", 1.0, 360],
    "rune_flow": ["Rune of Flow", "regen", 0.3, 300],
    "rune_leech": ["Rune of Leeching", "lifesteal", 1.0, 520],
    "rune_thorns": ["Rune of Thorns", "thorns", 1.0, 520],
}
const PASSIVE_RUNES := ["lifesteal", "thorns"]
## Chance an Elite drops a rune for its top damage dealer.
const ELITE_RUNE_CHANCE := 0.06
const SMITHY_REACH := 60.0

## augment → [name, stat, value, price]. "absorb" shortens analysis (share).
const AUGMENTS := {
    "aug_vitality": ["Vitality Augment", "hp", 20.0, 900],
    "aug_reservoir": ["Reservoir Augment", "magicules", 20.0, 900],
    "aug_stride": ["Stride Augment", "speed", 8.0, 1100],
    "aug_iron": ["Iron Skin Augment", "defense", 2.0, 1400],
    "aug_flow": ["Flow Augment", "regen", 0.5, 1100],
    "aug_might": ["Might Augment", "strike", 3.0, 1300],
    "aug_absorb": ["Absorber Augment", "absorb", 0.25, 1000],
}
const AUGMENT_LEVELS := [5, 10, 15]
const INSTALL_COST := 100
const SHRINE_REACH := 60.0

static func sockets(rarity: int) -> int:
    return SOCKETS[clampi(rarity, 0, SOCKETS.size() - 1)]

static func augment_slots(level: int) -> int:
    var slots := 0
    for needed in AUGMENT_LEVELS:
        if level >= needed:
            slots += 1
    return slots

static func is_rune(id: String) -> bool:
    return RUNES.has(id)

static func is_augment(id: String) -> bool:
    return AUGMENTS.has(id)

static func describe(id: String) -> String:
    var entry: Array = RUNES[id] if RUNES.has(id) else AUGMENTS[id]
    var stat: String = entry[1]
    if stat in PASSIVE_RUNES:
        return "%s: socket into gear (camp Smithy) — %s." % [entry[0], {"lifesteal": "heal 1 HP per strike that hits", "thorns": "reflect 1 damage when bitten"}[stat]]
    if stat == "absorb":
        return "%s: install at the Essence Shrine — analysis takes 25%% less time." % entry[0]
    var amount: String = ("%.1f" % entry[2]) if entry[2] != floor(entry[2]) else str(int(entry[2]))
    var text: String = {"hp": "+%s max HP", "magicules": "+%s max Magicules", "speed": "+%s speed", "strike": "+%s strike damage", "defense": "+%s defense", "regen": "+%s Magicules/s"}[stat] % amount
    return "%s: %s — %s." % [entry[0], "socket into gear (camp Smithy)" if RUNES.has(id) else "install at the Essence Shrine (permanent)", text]
