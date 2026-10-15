extends RefCounted
## The Ki Realm (M4.7, user plan; original names with obvious nods): who lives there, what the
## mentors teach, the transformations, the secret hermit's dialogue, the seven wish orbs and the
## tournament. Pure data; KiRealm (scripts/realm/ki_realm.gd) applies it on the host.
const MAP := preload("res://scripts/world/world_map.gd")

## --- Getting there
## The secret hermit hides in Sakura Vale (unmarked); the guide in Dome City sends you back.
const HERMIT_TILE := Vector2(640, -88)
const ARRIVAL_TILE := Vector2(-894, 66)
const GUIDE_TILE := Vector2(-890, 64)
const REQUIRED_LEVEL := 15
## The hermit's question and the answers he offers (only one is right).
const HERMIT_QUESTION := "The petals fall like stars tonight... Tell me, traveller: what do you seek?"
const HERMIT_ANSWERS := [
    "Just a quiet place to rest.",
    "Seven orbs, and the dragon who grants one wish.",
    "Do you sell bamboo?",
    "The strongest fighter under the heavens.",
]
const HERMIT_RIGHT := 1
const NPC_REACH := 34.0

## --- Mentors: [id, name, sprite, tile, kind ("skill" / "aura"), what, level, price, words]
const MENTORS := [
    ["turtle_sage", "Turtle Sage", "turtle_sage", Vector2(-1350, 252), "skill", "turtle_wave", 16, 2000, "Gather your ki in your palms... and release it all at once!"],
    ["spire_sage", "Spire Sage", "spire_sage", Vector2(-760, -104), "skill", "ki_blast", 15, 800, "You climbed my spire. Now learn to throw your ki like a stone."],
    ["guardian", "The Guardian", "guardian", Vector2(-764, -152), "skill", "spirit_orb", 18, 4000, "Borrow a little energy from every living thing, and shape it into one orb."],
    ["canyon_hermit", "Canyon Hermit", "canyon_hermit", Vector2(-740, 210), "skill", "ki_disc", 17, 1500, "Flatten your ki into a disc. It cuts through anything."],
    ["mountain_master", "Mountain Master", "mountain_master", Vector2(-1012, -176), "aura", "kaio_surge", 17, 3000, "Double your power for a moment — just do not overdo it."],
]

## --- Transformations (buff states): [name, damage factor, speed factor, Magicules per second,
## aura colour]. Kaio Surge from the Mountain Master; Golden Aura for the tournament champion;
## Golden Aura II from a wish.
const AURAS := {
    "kaio_surge": ["Kaio Surge", 1.3, 1.2, 4.0, Color(1.0, 0.25, 0.2)],
    "golden_aura": ["Golden Aura", 1.5, 1.3, 6.0, Color(1.0, 0.85, 0.25)],
    "golden_aura_2": ["Golden Aura II", 1.8, 1.35, 9.0, Color(1.0, 0.95, 0.55)],
}
const AURA_ORDER := ["kaio_surge", "golden_aura", "golden_aura_2"]

## --- The seven wish orbs: hidden spots (seven are used each time they scatter), the altar on
## the Guardian's Lookout, the wishes, and how long they rest after a wish.
const ORB_SPOTS := [
    Vector2(-1120, -60), Vector2(-1100, 40), Vector2(-960, -200), Vector2(-860, -190), Vector2(-640, -90),
    Vector2(-560, 40), Vector2(-690, 215), Vector2(-575, 232), Vector2(-870, 366), Vector2(-1356, 254),
    Vector2(-1180, 290), Vector2(-960, 180),
]
const ORB_COUNT := 7
const ORB_REACH := 26.0
const ALTAR_TILE := Vector2(-756, -150)
const WISHES := ["item", "zeni", "points", "aura"]
const WISH_ZENI := 20000
const WISH_POINTS := 3
const ORB_REST := 3600.0

static func orb_id(index: int) -> String:
    return "wish_orb_%d" % (index + 1)

static func is_orb(id: String) -> bool:
    return id.begins_with("wish_orb_") and id.trim_prefix("wish_orb_").is_valid_int() and int(id.trim_prefix("wish_orb_")) in range(1, ORB_COUNT + 1)

## --- The World Martial Grounds: five rounds in the ring; the champion's first win teaches the
## Golden Aura. [kind, tier, level]
const ROUNDS := [
    ["gi_fighter", 1, 16], ["monkey_brawler", 1, 17], ["android_scout", 2, 18], ["bio_android", 2, 19], ["demon_king", 2, 21],
]
const ENTRY_FEE := 500
const TOURNAMENT_LEVEL := 16
const PRIZE := 5000
const RING_RADIUS := 7.0
const ANNOUNCER_TILE := Vector2(-872, 365)

## --- Foes that live there (they cannot be analyzed): kind → name.
const FOES := {
    "raptor": "Raptor", "tyrant_rex": "Tyrant Rex", "gi_fighter": "Gi Fighter", "monkey_brawler": "Monkey Brawler",
    "android_scout": "Android Scout", "bio_android": "Bio-Android", "android_tank": "Android Tank", "demon_king": "Demon King",
}

static func mentor(id: String) -> Array:
    for entry in MENTORS:
        if entry[0] == id:
            return entry
    return []

static func ring_centre() -> Vector2:
    return MAP.to_world(Vector2(MAP.town("martial_grounds")[3]))
