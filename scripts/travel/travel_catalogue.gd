extends RefCounted
## Harbours, ferry tickets and passes, own ships, tools, fishing and mounts (M4.5d, user decisions
## in docs/M4_PLAN.md). Pure data and rules; WorldTrade / the player apply them on the host.
const MAP := preload("res://scripts/world/world_map.gd")

## --- Harbours and ships
## Ferry tickets: one trip to one harbour (a bag good "ticket_<harbour>"), priced by distance; or
## a pass for unlimited trips for an hour of world time. Your own ship (endgame, price only)
## replaces both and carries up to CREW_MAX characters in total.
const PASS_PRICE := 400
const PASS_SECONDS := 3600.0
const SHIP_PRICE := 40000
const CREW_MAX := 4
## Characters within this many pixels of the harbour can be invited aboard / sail along.
const CREW_RADIUS := 96.0
const INVITE_SECONDS := 120.0

static func ticket_id(harbour: String) -> String:
    return "ticket_" + harbour

static func ticket_harbour(id: String) -> String:
    var harbour := id.trim_prefix("ticket_")
    return harbour if id.begins_with("ticket_") and not MAP.harbour(harbour).is_empty() else ""

## A single ticket's price: a base fare plus the distance between the two piers.
static func fare(from: String, to: String) -> int:
    var distance: float = Vector2(MAP.harbour(from)[2]).distance_to(Vector2(MAP.harbour(to)[2]))
    return 20 + int(round(distance / 10.0))

## --- Tools: bought once, used automatically for their work (never equipped).
const TOOL_TIERS := ["", "Basic", "Fine", "Master"]
## tool → [name, price per tier (Basic, Fine, Master)]
const TOOLS := {
    "axe": ["Axe", [120, 600, 2400]],
    "pickaxe": ["Pickaxe", [120, 600, 2400]],
    "rod": ["Fishing Rod", [80, 450, 2000]],
}
## Extra share of wood (axe) or stone (pickaxe) when you gather a deposit, by tier.
const GATHER_BONUS := [0.0, 0.25, 0.5, 1.0]
## Fishing: seconds until a bite (Fishing 20 makes it 25% sooner).
const BITE_DELAY := [2.0, 5.0]
## Water must be within this many pixels in front of the character to fish.
const FISH_REACH := 30.0

static func tool_item(tool: String, tier: int) -> String:
    return "tool_%s_%d" % [tool, tier]

## [tool, tier] of a tool shop entry ("" when not a tool).
static func parse_tool(id: String) -> Array:
    var parts := id.split("_")
    if parts.size() != 3 or parts[0] != "tool" or not TOOLS.has(parts[1]) or not parts[2].is_valid_int():
        return ["", 0]
    var tier := int(parts[2])
    return [parts[1], tier] if tier >= 1 and tier <= 3 else ["", 0]

static func tool_price(tool: String, tier: int) -> int:
    return TOOLS[tool][1][tier - 1]

## Fish (M6b): the full catalogue lives in FishCatalogue; [name, price, where, level, rarity, weight].
const FISH := preload("res://scripts/professions/fish_catalogue.gd").FISH

static func is_fish(id: String) -> bool:
    return FISH.has(id)

## --- Mounts: bought at stables or tamed in the wild. [name, speed bonus, price (0 = tame
## only), sprite set, tame material, tame count, tame chance]
const MOUNTS := {
    "donkey": ["Donkey", 0.4, 600, "mount_donkey", "", 0, 0.0],
    "horse": ["Brown Horse", 0.6, 1500, "mount_horse", "", 0, 0.0],
    "black_horse": ["Black Horse", 0.7, 2600, "mount_black_horse", "", 0, 0.0],
    "wild_boar": ["Wild Boar", 0.6, 0, "mount_wild_boar", "owl_feather", 3, 0.35],
    "lion": ["Desert Lion", 0.8, 0, "mount_lion", "viper_scale", 3, 0.25],
}
const STABLE_MOUNTS := ["donkey", "horse", "black_horse"]
## Wild animals to tame: [id, mount, tile].
const WILD_MOUNTS := [
    ["wild_boar_1", "wild_boar", Vector2(80, 330)], ["wild_boar_2", "wild_boar", Vector2(290, 300)], ["wild_boar_3", "wild_boar", Vector2(150, 380)],
    ["lion_1", "lion", Vector2(-230, 60)], ["lion_2", "lion", Vector2(-70, 170)],
]
const TAME_REACH := 32.0
const TAME_COOLDOWN := 10.0

static func mount_item(mount: String) -> String:
    return "mount_" + mount
