extends RefCounted
## Item sets and unique abilities (item expansion part 3, user request).
## Sets: five Epic pieces per element (head, body, hands, feet, amulet; generated). Wearing two
## gives a themed stat; four add 15% weapon damage and make a weapon of the set's element act half
## as strong again. Bonuses use only stats derived live (strike, speed, defense), so saved maxima
## stay as they are.
## [name, element, two-piece bonus {stat: value}]
const SETS := {
    "emberlord": ["Emberlord's Regalia", "fire", {"strike": 3}],
    "rimewarden": ["Rimewarden's Plate", "frost", {"defense": 2}],
    "stormcaller": ["Stormcaller's Garb", "storm", {"speed": 8}],
    "nightstalker": ["Nightstalker's Shroud", "shadow", {"speed": 5, "strike": 1}],
    "dawnguard": ["Dawnguard Vestments", "holy", {"defense": 1, "strike": 1}],
    "wildheart": ["Wildheart Raiment", "nature", {"speed": 6}],
    "bloodbound": ["Bloodbound Mail", "blood", {"strike": 3}],
    "starweaver": ["Starweaver's Robes", "arcane", {"strike": 2, "speed": 3}],
}
const FOUR_DAMAGE := 0.15
const FOUR_ELEMENT := 1.5

## Unique abilities: name and what it does.
const ABILITIES := {
    "radiance": ["Radiance", "Every hit heals you and party members nearby for 5% of the damage"],
    "inferno": ["Inferno", "Every fourth hit explodes, burning creatures around the target for half the damage"],
    "executioner": ["Executioner", "Double damage to creatures below 30% health"],
    "overgrowth": ["Overgrowth", "25% chance to root the target for 1 s"],
    "bloodthirst": ["Bloodthirst", "Heals you for 12% of the damage"],
    "thunderlord": ["Thunderlord", "Lightning leaps to up to three more creatures"],
    "glacier": ["Glacier", "20% chance to freeze the target for 0.8 s"],
    "starfall": ["Starfall", "Every fifth hit calls a star that strikes everything around the target"],
    "eclipse": ["Eclipse", "Killing blows restore 15% of your health"],
    "windwalker": ["Windwalker", "+12 move speed"],
    "warden": ["Warden", "-4 damage taken per hit"],
    "berserker": ["Berserker", "+5 strike damage"],
    "phoenix": ["Phoenix", "Once every 2 minutes, a lethal hit leaves you at 1 HP instead"],
}
## Live stats some armour abilities give.
const ABILITY_STATS := {"windwalker": {"speed": 12}, "warden": {"defense": 4}, "berserker": {"strike": 5}}
const PHOENIX_COOLDOWN := 120.0

## Pieces of each set among equipped items.
static func counts(items: Array, bases: Dictionary) -> Dictionary:
    var result := {}
    for item in items:
        var set_id: String = String(bases[item.base].get("set", ""))
        if not set_id.is_empty():
            result[set_id] = int(result.get(set_id, 0)) + 1
    return result

## A live stat from sets (two pieces) and unique abilities.
static func bonus(items: Array, bases: Dictionary, stat: String) -> float:
    var total := 0.0
    var worn := counts(items, bases)
    for set_id in worn:
        if worn[set_id] >= 2:
            total += float(SETS[set_id][2].get(stat, 0))
    for item in items:
        var ability: String = String(bases[item.base].get("unique", ""))
        total += float(ABILITY_STATS.get(ability, {}).get(stat, 0))
    return total

## Weapon damage factor from four-piece sets.
static func damage_factor(items: Array, bases: Dictionary) -> float:
    var worn := counts(items, bases)
    return 1.0 + FOUR_DAMAGE * worn.values().filter(func(count): return count >= 4).size()

## How much stronger the weapon's element acts (four pieces of the same element's set).
static func element_factor(items: Array, bases: Dictionary, element: String) -> float:
    var worn := counts(items, bases)
    for set_id in worn:
        if worn[set_id] >= 4 and SETS[set_id][1] == element:
            return FOUR_ELEMENT
    return 1.0

static func has_ability(items: Array, bases: Dictionary, ability: String) -> bool:
    return items.any(func(item): return String(bases[item.base].get("unique", "")) == ability)

## The item card's lines for a set piece.
static func describe_set(set_id: String, worn: int = -1) -> String:
    if not SETS.has(set_id):
        return ""
    var parts: Array = []
    for stat in SETS[set_id][2]:
        parts.append("+%s %s" % [SETS[set_id][2][stat], stat])
    var title: String = "%s (%d/5)" % [SETS[set_id][0], worn] if worn >= 0 else "%s (5 pieces)" % SETS[set_id][0]
    return "Set: %s\n  2 pieces: %s\n  4 pieces: +%d%% weapon damage, %s weapons act 50%% stronger" % [title, ", ".join(parts), int(FOUR_DAMAGE * 100), SETS[set_id][1]]
