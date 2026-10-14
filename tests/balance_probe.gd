extends SceneTree
## Step 24b balance probe (user decision: bot playtests only). Bots fight real creatures with the
## game's own combat code (creature AI, bites, immunity, Magicule costs, skill effects) for every
## race, at every creature tier and level placed in the world, with basic strikes only and with the
## skill a character typically has at that point. From the measured fights it projects XP per hour
## for each leveling band (limited by kill speed and by respawns) and the hours to level 20, writes
## docs/balance/report.md and checks the M4 targets: 10-15 h to level 20, moderate difficulty.
const RACES := preload("res://scripts/races/race_catalogue.gd")
const LEVELING := preload("res://scripts/progression/leveling.gd")
const REGION := preload("res://scripts/world/region_content.gd")
const GNASHER_SCRIPT := preload("res://scripts/enemies/forest_gnasher.gd")
const GNASHER := preload("res://scenes/enemies/forest_gnasher.tscn")
const STEP := 1.0 / 60.0
const TIME_LIMIT := 60.0
## Seconds per kill outside the fight: finding and walking to the next creature (absorbing is
## added from the race's absorb time).
const TRAVEL := 8.0
## The bot keeps this share of its Magicules so it never collapses into recovery.
const RESERVE := 0.25
const TIER_NAMES := ["Easy", "Standard", "Elite"]
## Leveling bands: character levels, the regions a player farms there and the skill they have.
const BANDS := [
    {"name": "Clearing, Meadow and Beach", "from": 1, "to": 4, "regions": ["clearing", "meadow", "beach", "spot_meadow"], "skill": "thorn_lash"},
    {"name": "Lakeshore and Thornwood", "from": 4, "to": 9, "regions": ["lakeshore", "thornwood", "spot_lake", "spot_thornwood"], "skill": "rending_bite"},
    {"name": "Cinder Crater", "from": 9, "to": 20, "regions": ["crater", "spot_crater"], "skill": "piercing_fang"},
]
var checks := 0
var failures := 0
var world: Node2D
var actor: CharacterBody2D
var serial := 0
var lines: Array[String] = []

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

## The creatures of a region: [tier, level, respawn seconds] (the clearing uses its scene creatures).
func _creatures(region: String) -> Array:
    var found: Array = []
    if region == "clearing":
        for tier in range(3):
            found.append([tier, REGION.TIER_LEVELS[tier], REGION.RESPAWN_SECONDS[tier]])
        return found
    for entry in REGION.CREATURES:
        if String(entry[0]).begins_with(region + "_"):
            found.append([entry[3], REGION.level_of(entry[0], entry[3]), REGION.respawn_seconds(entry[0], entry[3])])
    for spot in REGION.SPOTS:
        if String(spot[0]).begins_with(region):
            for _i in range(spot[5]):
                found.append([spot[3], spot[4], REGION.RESPAWN_SECONDS[spot[3]] / REGION.SPOT_SPEEDUP])
    return found

## One real fight: the creature starts 60 px away and closes in; the bot holds its ground and
## strikes (or casts `skill` while it keeps its reserve) whenever it can reach.
func _fight(race: String, tier: int, level: int, skill: String) -> Dictionary:
    # A lost fight goes through the game's own respawn (it re-enables the Magicule pool).
    if actor.get_node("Health").current <= 0:
        actor.session.respawn_character(actor)
    actor.choose_race(race)
    actor.exhaustion_active = false
    actor.exhaustion_left = 0.0
    actor.position = Vector2(140, 600)
    actor.get_node("Health").immunity_left = 0.0
    var melee = actor.get_node("MeleeAttack")
    melee.cooldown_left = 0.0
    var pool = actor.get_node("Magicules")
    pool.regeneration_per_second = 6.0
    var book = actor.get_node("SkillBook")
    var data: Resource = load("res://data/skills/%s.tres" % skill) if skill != "" else null
    if data != null:
        book._known[StringName(skill)] = data
        if not skill in actor.progression.tree.active:
            actor.progression.tree.active.append(skill)
    serial += 1
    var enemy = GNASHER.instantiate()
    enemy.entity_id = "probe_%d" % serial
    enemy.position = actor.position + Vector2(60, 0)
    world.add_child(enemy)
    world.wire_enemy(enemy)
    enemy.set_difficulty(tier)
    enemy.level = level
    enemy.get_node("Health").maximum = GNASHER_SCRIPT.scaled_health(tier, level)
    enemy.get_node("Health").current = enemy.get_node("Health").maximum
    enemy.damage = GNASHER_SCRIPT.scaled_damage(tier, level)
    var creature_health = enemy.get_node("Health")
    var health = actor.get_node("Health")
    var elapsed := 0.0
    var engaged := -1.0
    var spent := 0.0
    var casts := 0
    var strikes := 0
    while elapsed < TIME_LIMIT and creature_health.current > 0 and health.current > 0:
        await physics_frame
        elapsed += STEP
        if actor.is_exhausted() or melee.cooldown_left > 0.0:
            continue
        var facing: Vector2 = actor.global_position.direction_to(enemy.global_position)
        if actor.global_position.distance_to(enemy.global_position) > 32.0:
            continue
        if engaged < 0.0:
            engaged = elapsed
        var before: float = pool.current
        if data != null and pool.current - data.magicule_cost >= pool.maximum * RESERVE and melee.attack_skill(facing, StringName(skill)):
            casts += 1
        elif pool.current >= melee.strike_cost() and melee.attack(facing):
            strikes += 1
        spent += maxf(0.0, before - pool.current)
    var result := {
        "won": creature_health.current <= 0, "died": health.current <= 0,
        "ttk": elapsed - maxf(engaged, 0.0), "hp_lost": health.maximum - health.current if health.current > 0 else health.maximum,
        "hp_share": 1.0 - float(health.current) / float(health.maximum), "spent": spent, "casts": casts, "strikes": strikes,
    }
    enemy.queue_free()
    await _frames(2)
    return result

func _run() -> void:
    world = load("res://scenes/world/forest.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await _frames()
    for enemy in get_nodes_in_group("enemies"):
        enemy.set_physics_process(false)
        enemy.position += Vector2(4000, 4000)
    actor = world.get_local_player()
    await _frames(2)
    # Every distinct creature (tier, level) placed in the world, fought by every race.
    var pairs: Array = []
    for band in BANDS:
        for region in band.regions:
            for creature in _creatures(region):
                var pair := [creature[0], creature[1], band.skill]
                if not pair in pairs:
                    pairs.append(pair)
    var results := {}
    for race in RACES.ORDER:
        for pair in pairs:
            results["%s|%d|%d|strikes" % [race, pair[0], pair[1]]] = await _fight(race, pair[0], pair[1], "")
            results["%s|%d|%d|skills" % [race, pair[0], pair[1]]] = await _fight(race, pair[0], pair[1], pair[2])
    _report_fights(pairs, results)
    _project(results)
    _write_report()
    world.queue_free()
    await _frames()
    print("Balance probe checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)

func _report_fights(pairs: Array, results: Dictionary) -> void:
    lines.append("## Fights")
    lines.append("")
    lines.append("Time to kill (s) and share of the character's HP lost, basic strikes only / with the band's skill. \"died\" means the creature won.")
    lines.append("")
    lines.append("| Creature | HP | Bite | " + " | ".join(RACES.ORDER) + " |")
    lines.append("| --- | --- | --- |" + " --- |".repeat(RACES.ORDER.size()))
    var all_won := true
    var easy_fast := true
    var elite_threat := false
    for pair in pairs:
        var cells: Array = []
        for race in RACES.ORDER:
            var cell: Array = []
            for loadout in ["strikes", "skills"]:
                var r: Dictionary = results["%s|%d|%d|%s" % [race, pair[0], pair[1], loadout]]
                cell.append("died" if r.died else ("%.1f s, %d%%" % [r.ttk, int(round(r.hp_share * 100.0))] if r.won else "timeout"))
                if loadout == "skills":
                    all_won = all_won and r.won
                    if pair[0] == 0:
                        easy_fast = easy_fast and r.ttk <= 5.0
                    if pair[0] == 2 and r.hp_share >= 0.15:
                        elite_threat = true
            cells.append(" / ".join(cell))
        lines.append("| %s L%d (%s) | %d | %d | %s |" % [TIER_NAMES[pair[0]], pair[1], pair[2], GNASHER_SCRIPT.scaled_health(pair[0], pair[1]), GNASHER_SCRIPT.scaled_damage(pair[0], pair[1]), " | ".join(cells)])
    lines.append("")
    _check(all_won, "Moderate: every race wins every creature of its leveling band one on one with its skill")
    _check(easy_fast, "Easy creatures fall within 5 s with a skill")
    _check(elite_threat, "Elites are a real threat: some race loses at least 15% of its HP to one")

func _project(results: Dictionary) -> void:
    lines.append("## Leveling projection")
    lines.append("")
    lines.append("Per kill: the measured fight with the band's skill, %d s finding the next creature and the race's absorb time. Kills per hour are capped by the respawns of the band's creatures (leveling spots respawn 3x faster). XP per kill is defeat plus absorption XP." % int(TRAVEL))
    lines.append("")
    lines.append("| Band | XP needed | " + " | ".join(RACES.ORDER) + " |")
    lines.append("| --- | --- |" + " --- |".repeat(RACES.ORDER.size()))
    var hours := {}
    var rates := {}
    for race in RACES.ORDER:
        hours[race] = 0.0
        rates[race] = []
    for band in BANDS:
        var creatures: Array = []
        for region in band.regions:
            creatures.append_array(_creatures(region))
        var needed: int = LEVELING.xp_for_level(band.to) - LEVELING.xp_for_level(band.from)
        var cells: Array = []
        for race in RACES.ORDER:
            var cycle := 0.0
            var xp := 0.0
            var respawn_cap := 0.0
            for creature in creatures:
                var r: Dictionary = results["%s|%d|%d|skills" % [race, creature[0], creature[1]]]
                cycle += r.ttk + TRAVEL + float(RACES.stats(race).absorb_time)
                xp += LEVELING.defeat_xp(creature[1], creature[0]) + LEVELING.absorb_xp(creature[1], creature[0])
                respawn_cap += 3600.0 / float(creature[2])
            cycle /= creatures.size()
            xp /= creatures.size()
            var kills: float = minf(3600.0 / cycle, respawn_cap)
            var band_hours: float = needed / (kills * xp)
            hours[race] += band_hours
            rates[race].append(kills * xp)
            cells.append("%.1f h (%d kills/h%s, %d XP/h)" % [band_hours, int(kills), ", respawn-capped" if kills >= respawn_cap - 0.01 else "", int(kills * xp)])
        lines.append("| %s (L%d-%d) | %d | %s |" % [band.name, band.from, band.to, needed, " | ".join(cells)])
    var totals: Array = []
    for race in RACES.ORDER:
        totals.append("**%.1f h**" % hours[race])
    lines.append("| **Level 1 to 20** | %d | %s |" % [LEVELING.max_experience(), " | ".join(totals)])
    lines.append("")
    var mean := 0.0
    for race in RACES.ORDER:
        mean += hours[race] / RACES.ORDER.size()
    print("Projected hours to level 20: ", hours)
    _check(mean >= 10.0 and mean <= 15.0, "Pace: the races average 10-15 h of focused play to level 20 (%.1f h)" % mean)
    var spread_ok := true
    for race in RACES.ORDER:
        spread_ok = spread_ok and absf(hours[race] - mean) <= mean * 0.25
    _check(spread_ok, "No race levels more than 25% faster or slower than the average")
    # The plan's milestones (M4_PLAN 24): level 2 after ~4 creatures, 5 ~30 min, 10 ~3 h, 20 ~12 h.
    var easy_kill: int = LEVELING.defeat_xp(1, 0) + LEVELING.absorb_xp(1, 0)
    lines.append("Milestones (average of the races): level 2 after %d Easy creatures; " % ceili(float(LEVELING.xp_for_level(2)) / easy_kill) + ", ".join([5, 10, 15, 20].map(func(level): return "level %d after %s" % [level, _clock(_hours_to(rates, level))])) + ".")
    lines.append("")
    _check(LEVELING.xp_for_level(2) <= 5 * easy_kill, "Fast start: level 2 after at most 5 Easy creatures")
    _check(_hours_to(rates, 5) >= 0.25 and _hours_to(rates, 5) <= 1.0, "Level 5 after about 30 min (%s)" % _clock(_hours_to(rates, 5)))
    _check(_hours_to(rates, 10) >= 2.0 and _hours_to(rates, 10) <= 4.0, "Level 10 after about 3 h (%s)" % _clock(_hours_to(rates, 10)))

## Average hours (over the races) from level 1 to `level` at each band's measured XP per hour.
func _hours_to(rates: Dictionary, level: int) -> float:
    var total := 0.0
    for race in RACES.ORDER:
        for index in range(BANDS.size()):
            var band: Dictionary = BANDS[index]
            var top: int = mini(level, band.to)
            if top > band.from:
                total += float(LEVELING.xp_for_level(top) - LEVELING.xp_for_level(band.from)) / rates[race][index]
    return total / RACES.ORDER.size()

func _clock(hours: float) -> String:
    return "%d min" % int(round(hours * 60.0)) if hours < 1.0 else "%.1f h" % hours

func _write_report() -> void:
    var head: Array[String] = [
        "# Balance report (step 24b)",
        "",
        "Generated by `tests/balance_probe.gd` (headless bots with the game's own combat code; rerun it after any number change). Creature HP grows 30% and bites 8% per level above the tier's base level; skills deal 12 x (cost / 2)^0.75; XP per defeat is (10 + 2.5 x level) x tier factor; levels need 100 x (level - 1)^2.8 XP.",
        "",
    ]
    head.append_array(lines)
    var path := ProjectSettings.globalize_path("res://docs/balance/report.md")
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string("\n".join(head))
    file.close()
