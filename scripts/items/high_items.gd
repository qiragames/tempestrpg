extends RefCounted
## Gear for levels 21-50 (M7b: the level cap rose to 50, but the item expansion stops at 20). Every
## level 16-20 base (not uniques or set pieces) gets ten stronger tiers (every three levels) that keep its art, type,
## element and rarity floor; their stats follow the generator's level scaling (+4.5% per level)
## from the source's level to the tier's. Creatures, chests and forging pick them by level like
## any base. No preloads besides the generated bases (GearCatalogue preloads this file).
const SOURCE := preload("res://scripts/items/item_bases.gd")
## [item level, name prefix]
## User request: new gear every two to three levels above 20 (the 24/30/36/42/48 tiers keep their
## IDs, so saved items stay valid).
const TIERS := [[21, "Stormtouched"], [24, "Steppeforged"], [27, "Windwrought"], [30, "Gloomwrought"], [33, "Duskforged"], [36, "Jadecarved"], [39, "Cloudforged"], [42, "Starforged"], [45, "Celestial"], [48, "Ascendant"]]
const FROM_LEVEL := 16

static var BASES: Dictionary = _build()

static func scale_for(from_level: int, to_level: int) -> float:
    return (1.0 + 0.045 * (to_level - 1)) / (1.0 + 0.045 * (from_level - 1))

static func _build() -> Dictionary:
    var all := {}
    var ids: Array = SOURCE.BASES.keys()
    ids.sort()
    for id in ids:
        var spec: Dictionary = SOURCE.BASES[id]
        if spec.has("unique") or spec.has("set") or int(spec.get("level", 1)) < FROM_LEVEL:
            continue
        for tier in TIERS:
            var factor := scale_for(int(spec.level), int(tier[0]))
            var stats := {}
            for stat in spec.stats:
                var span: Array = spec.stats[stat]
                if float(span[1]) <= 0.0:
                    # Penalties (e.g. heavy armour's speed) stay as they are.
                    stats[stat] = span.duplicate()
                elif stat == "regen":
                    stats[stat] = [snappedf(float(span[0]) * factor, 0.1), snappedf(float(span[1]) * factor, 0.1)]
                else:
                    stats[stat] = [int(round(float(span[0]) * factor)), int(round(float(span[1]) * factor))]
            var base: Dictionary = spec.duplicate(true)
            base["name"] = "%s %s" % [tier[1], spec.name]
            base["level"] = int(tier[0])
            base["stats"] = stats
            base["tier"] = tier[1]
            all["t%d_%s" % [tier[0], id]] = base
    return all
