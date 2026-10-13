extends RefCounted
## Seeded world layout. The map scheme is fixed (roads, pond, camp site, borders); the seed only
## decides deposits, creature placement/difficulty, points of interest and decorations.
## Seed 0 is the hand-made reference map, so worlds saved before seeds existed keep their layout.
## Same seed = same layout on every machine: one RandomNumberGenerator, fixed call order, whole pixels.
const CAMP := preload("res://scripts/settlement/first_camp.gd")
const TRIAL := preload("res://scripts/trials/proving_trial.gd")

const WORLD := Rect2(0, 0, 960, 640)
const POND := Rect2(624, 112, 160, 96)
const ROADS: Array[Rect2] = [Rect2(0, 304, 960, 56), Rect2(464, 304, 40, 336)]
const SPAWN := Vector2(480, 340)
## Saved worlds reference these stable IDs; only their positions/amounts/difficulty vary.
const CREATURE_IDS := ["gnasher_1", "gnasher_2", "thornback_1"]
const ALLY_ID := "ally_goblin_1"
const CLASSIC := {
    "seed": 0,
    "stone": TRIAL.STONE,
    "ally": Vector2(220, 360),
    "creatures": {
        "gnasher_1": {"position": Vector2(620, 360), "difficulty": 1},
        "gnasher_2": {"position": Vector2(840, 420), "difficulty": 1},
        "thornback_1": {"position": Vector2(880, 560), "difficulty": 1},
    },
    "rocks": [Rect2(440, 250, 32, 24), Rect2(304, 400, 40, 24)],
    "trees": [Vector2(160, 144), Vector2(240, 192), Vector2(352, 112), Vector2(544, 160), Vector2(816, 288), Vector2(176, 464), Vector2(576, 496), Vector2(752, 480)],
}
## Candidate spots for points of interest. Each keeps the trial arena and its spawns inside the map.
const STONE_SPOTS: Array[Vector2] = [Vector2(480, 100), Vector2(170, 120), Vector2(800, 520), Vector2(150, 520)]
const ALLY_SPOTS: Array[Vector2] = [Vector2(220, 360), Vector2(260, 420), Vector2(250, 250), Vector2(440, 430)]
## [Easy, Standard, Elite] weights per creature: the first is gentle, the Thornback is never easy.
const DIFFICULTY_WEIGHTS := {"gnasher_1": [1.0, 1.0, 0.0], "gnasher_2": [1.0, 3.0, 1.0], "thornback_1": [0.0, 7.0, 3.0]}
## Creature distance from the spawn, so later creatures sit farther out.
const CREATURE_RANGE := {"gnasher_1": Vector2(150, 300), "gnasher_2": Vector2(250, 480), "thornback_1": Vector2(330, 620)}
const NEAR_IDS := ["wood_1", "wood_2", "stone_1"]
const OUTLYING_IDS := ["wood_3", "stone_2", "stone_3"]
const MARGIN := 32.0

## The seed a world is laid out with. Worlds made before seeded layouts (v12 and older) keep the
## reference map they were generated with: their meta says `seeded: false`.
static func seed_of(meta: Dictionary) -> int:
    return int(meta.get("seed", 0)) if meta.get("seeded", false) else 0

## Map label for menus.
static func describe(meta: Dictionary) -> String:
    return "seed %d" % int(meta.get("seed", 0)) if meta.get("seeded", false) else "original map"

static func generate(seed: int) -> Dictionary:
    if seed == 0:
        var classic: Dictionary = CLASSIC.duplicate(true)
        classic["deposits"] = CAMP.DEPOSITS.duplicate(true)
        return classic
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var layout := {"seed": seed}
    var taken: Array = []  # [point, radius] pairs every later placement keeps clear of
    layout.stone = STONE_SPOTS[rng.randi_range(0, STONE_SPOTS.size() - 1)]
    taken.append([layout.stone, 110.0])
    layout.ally = ALLY_SPOTS[rng.randi_range(0, ALLY_SPOTS.size() - 1)]
    taken.append([layout.ally, 24.0])
    # Near deposits ring the camp so allied workers (who stay within 100 px) can reach them.
    var deposits: Dictionary = {}
    for id in NEAR_IDS:
        var point := _pick(rng, CAMP.DEPOSITS[id].position, func(candidate: Vector2) -> bool:
            return candidate.distance_to(CAMP.SITE) >= 40 and candidate.distance_to(CAMP.SITE) <= 80 and _clear_of_structures(candidate, 14.0) and _clear(candidate, taken, 32.0) and not _in_pond(candidate, 16.0)
        , func() -> Vector2: return CAMP.SITE + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40, 80))
        deposits[id] = {"position": point, "resource": CAMP.DEPOSITS[id].resource, "amount": CAMP.DEPOSITS[id].amount, "outlying": false}
        taken.append([point, 0.0])
    # Creatures guard the wilds: never near the camp, the trial stone or each other.
    var creatures: Dictionary = {}
    for id in CREATURE_IDS:
        var band: Vector2 = CREATURE_RANGE[id]
        var point := _pick(rng, CLASSIC.creatures[id].position, func(candidate: Vector2) -> bool:
            var reach := candidate.distance_to(SPAWN)
            return reach >= band.x and reach <= band.y and candidate.distance_to(CAMP.SITE) >= 190 and candidate.distance_to(layout.stone) >= 230 and _clear(candidate, taken, 90.0) and not _in_pond(candidate, 20.0)
        , func() -> Vector2: return _anywhere(rng))
        creatures[id] = {"position": point, "difficulty": _weighted(rng, DIFFICULTY_WEIGHTS[id])}
        taken.append([point, 0.0])
    # Outlying deposits reward exploring; they are richer than the camp's and spread apart.
    var outlying: Array = []
    for id in OUTLYING_IDS:
        var point := _pick(rng, CAMP.DEPOSITS[id].position, func(candidate: Vector2) -> bool:
            return candidate.distance_to(CAMP.SITE) >= 220 and candidate.distance_to(SPAWN) >= 120 and _clear(candidate, taken, 60.0) and _clear(candidate, outlying, 140.0) and not _in_pond(candidate, 20.0)
        , func() -> Vector2: return _anywhere(rng))
        deposits[id] = {"position": point, "resource": CAMP.DEPOSITS[id].resource, "amount": rng.randi_range(8, 12), "outlying": true}
        outlying.append([point, 0.0])
    taken.append_array(outlying)
    layout.deposits = deposits
    layout.creatures = creatures
    # Decorations: spaced out and kept off roads, the camp and every point of interest,
    # so each obstacle is small and isolated and all routes stay open.
    var obstacles: Array = []
    var rocks: Array = []
    for index in range(rng.randi_range(2, 3)):
        var size := Vector2(rng.randi_range(7, 10) * 4, rng.randi_range(5, 6) * 4)
        var center := _decoration(rng, taken, obstacles)
        if center != Vector2.INF:
            rocks.append(Rect2((center - size / 2).round(), size))
            obstacles.append(center)
    var trees: Array = []
    for index in range(rng.randi_range(6, 10)):
        var point := _decoration(rng, taken, obstacles)
        if point != Vector2.INF:
            trees.append(point)
            obstacles.append(point)
    layout.rocks = rocks
    layout.trees = trees
    return layout

## Rejection sampling with a deterministic number of draws; falls back to the reference spot.
static func _pick(rng: RandomNumberGenerator, fallback: Vector2, ok: Callable, draw: Callable) -> Vector2:
    for attempt in range(300):
        var candidate: Vector2 = draw.call().round()
        if WORLD.grow(-MARGIN).has_point(candidate) and ok.call(candidate):
            return candidate
    return fallback

static func _anywhere(rng: RandomNumberGenerator) -> Vector2:
    return Vector2(rng.randf_range(WORLD.position.x, WORLD.end.x), rng.randf_range(WORLD.position.y, WORLD.end.y))

static func _decoration(rng: RandomNumberGenerator, taken: Array, obstacles: Array) -> Vector2:
    for attempt in range(300):
        var point := _anywhere(rng).round()
        if not WORLD.grow(-40).has_point(point) or _in_pond(point, 28.0) or point.distance_to(CAMP.SITE) < 120 or point.distance_to(SPAWN) < 70:
            continue
        var on_road := false
        for road in ROADS:
            on_road = on_road or road.grow(28).has_point(point)
        if on_road or not _clear(point, taken, 44.0):
            continue
        var spaced := true
        for other in obstacles:
            spaced = spaced and point.distance_to(other) >= 64
        if spaced:
            return point
    return Vector2.INF

static func _clear(point: Vector2, taken: Array, distance: float) -> bool:
    for entry in taken:
        if point.distance_to(entry[0]) < distance + entry[1]:
            return false
    return true

static func _clear_of_structures(point: Vector2, padding: float) -> bool:
    for id in CAMP.STRUCTURES:
        var structure: Dictionary = CAMP.STRUCTURES[id]
        if Rect2(structure.site - structure.size / 2, structure.size).grow(padding).has_point(point):
            return false
    return point.distance_to(CAMP.SITE) >= 30

static func _in_pond(point: Vector2, padding: float) -> bool:
    return POND.grow(padding).has_point(point)

static func _weighted(rng: RandomNumberGenerator, weights: Array) -> int:
    var roll: float = rng.randf() * (weights[0] + weights[1] + weights[2])
    for index in range(weights.size()):
        roll -= weights[index]
        if roll < 0 and weights[index] > 0:
            return index
    return 1
