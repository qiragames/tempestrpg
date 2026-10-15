extends RefCounted
## Fish (M6b, user decisions in docs/M4_PLAN.md M6): about forty fish by region and water with six
## rarities — Common, Uncommon, Rare, Epic, Legendary and Mythical sea creatures that merchants pay
## a fortune for. A bite picks the fish; the reel-in minigame decides the catch: the green zone is
## your chance per press (Fishing level against the fish's level, soft gate), rarer fish need more
## hits in a row and move faster. Pure data and rules; Player runs a catch on the host.
const PRO := preload("res://scripts/professions/profession_catalogue.gd")

const RARITIES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical"]
const RARITY_COLOURS := [Color("d8d8d8"), Color("7ee07e"), Color("6fb8ff"), Color("c07aff"), Color("ffb84a"), Color("ff5e8a")]
## How often each rarity bites (relative), the hits a catch needs and the marker's speed.
const RARITY_WEIGHT := [100.0, 40.0, 12.0, 4.0, 1.0, 0.12]
const HITS := [1, 1, 2, 2, 3, 4]
const SPEED := [0.7, 0.8, 0.95, 1.1, 1.25, 1.45]
## Misses a fish forgives and the seconds it fights before it escapes.
const MISSES := 2
const REEL_SECONDS := 9.0

## [name, buy price (selling pays 30%), where, required level, rarity, weight within its rarity]
## where: "any", "lake", "sea", a region name (any of its water), or "lake@Region"/"sea@Region".
const FISH := {
    # Common.
    "minnow": ["Minnow", 8, "any", 1, 0, 10],
    "trout": ["Lake Trout", 16, "lake", 1, 0, 10],
    "sea_bass": ["Sea Bass", 18, "sea", 1, 0, 10],
    "sardine": ["Sardine", 10, "sea", 2, 0, 8],
    "perch": ["Perch", 14, "lake", 3, 0, 8],
    "mackerel": ["Mackerel", 15, "sea", 3, 0, 8],
    "carp": ["Carp", 20, "lake", 5, 0, 6],
    "herring": ["Herring", 18, "sea", 6, 0, 6],
    "catfish": ["Catfish", 26, "lake", 8, 0, 5],
    # Uncommon: the regions' own fish.
    "mirror_trout": ["Mirror Trout", 28, "Mirror Lake", 5, 1, 10],
    "thorn_pike": ["Thorn Pike", 24, "Thornwood", 6, 1, 10],
    "harrow_herring": ["Harrow Herring", 26, "Harrowmere", 6, 1, 10],
    "sand_eel": ["Sand Eel", 28, "Sunscorch Desert", 9, 1, 10],
    "sunfish": ["Sunfish", 34, "Sunscorch Desert", 10, 1, 8],
    "glacier_cod": ["Glacier Cod", 30, "Frostpeak", 10, 1, 10],
    "ice_pike": ["Ice Pike", 40, "lake@Frostpeak", 12, 1, 8],
    "amber_perch": ["Amber Perch", 30, "Ambervale", 13, 1, 10],
    "koi": ["Koi", 36, "Sakura Vale", 15, 1, 10],
    "blossom_minnow": ["Blossom Minnow", 30, "Sakura Vale", 14, 1, 8],
    "bog_eel": ["Bog Eel", 32, "Mirewood Marsh", 15, 1, 10],
    "mud_crab": ["Mud Crab", 38, "Mirewood Marsh", 16, 1, 8],
    "ember_eel": ["Ember Eel", 42, "Emberreach Isles", 18, 1, 10],
    "lava_crab": ["Lava Crab", 55, "Emberreach Isles", 20, 1, 8],
    "ki_carp": ["Ki Carp", 120, "The Ki Realm", 38, 1, 10],
    # Rare.
    "salmon": ["Salmon", 70, "lake", 15, 2, 10],
    "tuna": ["Bluefin Tuna", 80, "sea", 18, 2, 10],
    "swordfish": ["Swordfish", 90, "sea", 20, 2, 8],
    "lionfish": ["Lionfish", 95, "sea", 22, 2, 6],
    "frost_salmon": ["Frost Salmon", 110, "Frostpeak", 22, 2, 10],
    "dune_ray": ["Dune Ray", 120, "Sunscorch Desert", 24, 2, 10],
    "spirit_koi": ["Spirit Koi", 160, "Sakura Vale", 28, 2, 10],
    "bog_lurker": ["Bog Lurker", 170, "Mirewood Marsh", 30, 2, 10],
    "magma_ray": ["Magma Ray", 200, "Emberreach Isles", 32, 2, 10],
    "ki_marlin": ["Ki Marlin", 300, "The Ki Realm", 44, 2, 10],
    # Epic.
    "golden_carp": ["Golden Carp", 160, "any", 12, 3, 10],
    "moonfish": ["Moonfish", 400, "sea", 30, 3, 8],
    "crystal_eel": ["Crystal Eel", 450, "lake", 34, 3, 8],
    "storm_shark": ["Storm Shark", 600, "sea", 38, 3, 6],
    # Legendary.
    "coelacanth": ["Ancient Coelacanth", 1500, "sea", 42, 4, 10],
    "jade_dragonfish": ["Jade Dragonfish", 2000, "Sakura Vale", 45, 4, 10],
    "sun_marlin": ["Sun Marlin", 1800, "sea@Sunscorch Desert", 43, 4, 10],
    # Mythical sea creatures (user request): very rare, worth a fortune.
    "kraken": ["Kraken", 30000, "sea", 40, 5, 10],
    "leviathan": ["Leviathan", 40000, "sea", 45, 5, 6],
    "frost_wyrm": ["Frost Wyrm", 35000, "Frostpeak", 42, 5, 10],
    "phoenix_eel": ["Phoenix Eel", 38000, "Emberreach Isles", 44, 5, 10],
    "abyss_serpent": ["Abyss Serpent", 36000, "Mirewood Marsh", 43, 5, 10],
    "shenlong_koi": ["Shenlong Koi", 60000, "The Ki Realm", 48, 5, 10],
}

static func is_fish(id: String) -> bool:
    return FISH.has(id)

static func bites_here(id: String, region: String, lake: bool) -> bool:
    var where: String = FISH[id][2]
    if where == "any":
        return true
    if where == "lake":
        return lake
    if where == "sea":
        return not lake
    if where.begins_with("lake@"):
        return lake and where.trim_prefix("lake@") == region
    if where.begins_with("sea@"):
        return not lake and where.trim_prefix("sea@") == region
    return where == region

## The fish that bites (host): rarity weights, raised for rare fish by the rod and Fishing
## milestones (30: ×1.5 Rare and better, 40: ×2 Mythical).
static func pick(region: String, lake: bool, rod: int, level: int, rng: RandomNumberGenerator) -> String:
    var pool: Array = []
    var total := 0.0
    for id in FISH:
        if not bites_here(id, region, lake):
            continue
        var rarity: int = FISH[id][4]
        var weight: float = RARITY_WEIGHT[rarity] * float(FISH[id][5]) / 10.0
        if rarity >= 2:
            weight *= 1.0 + 0.25 * clampi(rod, 0, 3)
            if level >= 30:
                weight *= 1.5
        if rarity == 5 and level >= 40:
            weight *= 2.0
        pool.append([id, weight])
        total += weight
    var roll := rng.randf() * total
    for entry in pool:
        roll -= entry[1]
        if roll <= 0.0:
            return entry[0]
    return "minnow"

## The reel's green zone as a share of the bar: the catch chance per press (shown).
static func zone(level: int, id: String, rod: int) -> float:
    var bonus := 0.03 * clampi(rod, 0, 3) + (0.1 if level >= 50 else 0.0)
    return clampf(PRO.chance(level, int(FISH[id][3]), bonus) * 0.6, 0.06, 0.6)

## Marker position 0..1 (back and forth) after `t` seconds at `speed` sweeps per second.
static func marker(t: float, speed: float) -> float:
    var phase := fmod(t * speed, 2.0)
    return phase if phase <= 1.0 else 2.0 - phase

static func xp_for(id: String) -> int:
    return PRO.xp_reward(int(FISH[id][3])) * (1 + int(FISH[id][4]))

## Rows for the professions window: [name, required level, where, rarity].
static func entries() -> Array:
    var rows: Array = []
    for id in FISH:
        rows.append([FISH[id][0], int(FISH[id][3]), String(FISH[id][2]).replace("lake@", "lakes of ").replace("sea@", "sea off "), int(FISH[id][4]), id])
    return rows
