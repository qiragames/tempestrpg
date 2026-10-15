extends RefCounted
## Day, night and weather (user request: a day/night cycle and weather — rain, snow in Frostpeak,
## sandstorms and more). Everything follows from the shared world time, so every peer sees the same
## hour and the same weather without any extra replication or saving.
##
## A game day lasts DAY_SECONDS of world time (one game hour per real minute). Each region's weather
## changes every WEATHER_HOURS game hours, picked from its own table by a hash of region and period.
## Night: creatures bite 15% harder and give 10% more XP. Rain and storms make fish bite sooner,
## sandstorms slow walking a little, fog and mist let creatures notice characters later.
const DAY_SECONDS := 1440.0
## The world starts in the morning.
const START_HOUR := 8.0
const WEATHER_HOURS := 3.0
const NIGHT_DAMAGE := 1.15
const NIGHT_XP := 1.1

## Ambient light through the day: [hour, colour].
const AMBIENT := [
    [0.0, Color(0.32, 0.36, 0.58)], [4.5, Color(0.34, 0.38, 0.6)], [6.0, Color(0.92, 0.70, 0.62)],
    [7.5, Color(1.0, 1.0, 1.0)], [17.5, Color(1.0, 1.0, 1.0)], [19.0, Color(0.98, 0.72, 0.58)],
    [20.5, Color(0.55, 0.48, 0.72)], [22.0, Color(0.32, 0.36, 0.58)], [24.0, Color(0.32, 0.36, 0.58)],
]

## [name, ambient tint, symbol]
const WEATHER := {
    "clear": ["Clear", Color(1, 1, 1), "☀"],
    "rain": ["Rain", Color(0.82, 0.86, 0.95), "☂"],
    "storm": ["Thunderstorm", Color(0.62, 0.66, 0.8), "⚡"],
    "snow": ["Snow", Color(0.93, 0.96, 1.0), "❄"],
    "sandstorm": ["Sandstorm", Color(1.0, 0.86, 0.62), "≋"],
    "fog": ["Fog", Color(0.86, 0.88, 0.9), "≡"],
    "ashfall": ["Ashfall", Color(0.85, 0.72, 0.66), "✦"],
    "gloom_mist": ["Gloom Mist", Color(0.8, 0.68, 0.95), "≡"],
    "monsoon": ["Monsoon", Color(0.78, 0.86, 0.84), "☂"],
}
## Weather weights by region name (anything not listed: clear, rain, storm).
const REGION_WEATHER := {
    "The First Clearing": {"clear": 6, "rain": 3, "storm": 1, "fog": 1},
    "Verdant Isle": {"clear": 6, "rain": 3, "storm": 1, "fog": 1},
    "Thornwood": {"clear": 5, "rain": 3, "storm": 1, "fog": 2},
    "Mirror Lake": {"clear": 5, "rain": 3, "fog": 3},
    "Harrowmere": {"clear": 5, "rain": 4, "storm": 1},
    "Cinder Crater": {"clear": 5, "ashfall": 4},
    "Frostpeak": {"clear": 4, "snow": 6},
    "Sunscorch Desert": {"clear": 7, "sandstorm": 3},
    "Ambervale": {"clear": 5, "rain": 3, "fog": 2},
    "Mirewood Marsh": {"rain": 4, "fog": 4, "clear": 2},
    "Sakura Vale": {"clear": 6, "rain": 3, "fog": 1},
    "Emberreach Isles": {"clear": 4, "ashfall": 5},
    "Goldwind Steppe": {"clear": 6, "storm": 2, "sandstorm": 2},
    "Gloomveil": {"gloom_mist": 5, "rain": 3, "fog": 2},
    "Jade Terraces": {"clear": 4, "monsoon": 4, "fog": 3},
    "The Ki Realm": {"clear": 7, "rain": 2, "storm": 1},
    "The Sapphire Sea": {"clear": 6, "rain": 3, "storm": 2},
}
const INDOORS := ["The Underdeep"]

## Game hour 0..24.
static func hour(world_time: float) -> float:
    return fposmod(START_HOUR + world_time / DAY_SECONDS * 24.0, 24.0)

static func day(world_time: float) -> int:
    return int(floor((START_HOUR / 24.0 * DAY_SECONDS + world_time) / DAY_SECONDS)) + 1

static func is_night(world_time: float) -> bool:
    var h := hour(world_time)
    return h >= 21.0 or h < 5.0

## 0 by day, 1 at full night (dusk and dawn in between): how much the lights glow.
static func darkness(world_time: float) -> float:
    var colour := ambient(world_time)
    return clampf((1.0 - colour.v) / 0.38, 0.0, 1.0)

static func ambient(world_time: float) -> Color:
    var h := hour(world_time)
    for index in range(AMBIENT.size() - 1):
        var a: Array = AMBIENT[index]
        var b: Array = AMBIENT[index + 1]
        if h >= a[0] and h <= b[0]:
            return Color(a[1]).lerp(b[1], (h - a[0]) / maxf(0.001, b[0] - a[0]))
    return Color.WHITE

static func clock_text(world_time: float) -> String:
    var h := hour(world_time)
    return "Day %d · %02d:%02d" % [day(world_time), int(h), int(fmod(h, 1.0) * 60.0)]

## Weather already worked out: {"region:period": id} (cleared now and then).
static var _cache: Dictionary = {}

## The weather of a region at a world time (deterministic on every peer).
static func weather(region_name: String, world_time: float) -> String:
    if region_name in INDOORS:
        return "clear"
    var period := int(floor(world_time / (DAY_SECONDS / 24.0 * WEATHER_HOURS)))
    var key := "%s:%d" % [region_name, period]
    if _cache.has(key):
        return _cache[key]
    if _cache.size() > 512:
        _cache.clear()
    var picked := _pick(region_name, period)
    _cache[key] = picked
    return picked

static func _pick(region_name: String, period: int) -> String:
    var table: Dictionary = REGION_WEATHER.get(region_name, {"clear": 6, "rain": 3, "storm": 1})
    var total := 0
    for id in table:
        total += int(table[id])
    var roll: int = absi(hash("%s:%d" % [region_name, period])) % total
    for id in table:
        roll -= int(table[id])
        if roll < 0:
            return id
    return "clear"

static func is_wet(weather_id: String) -> bool:
    return weather_id in ["rain", "storm", "monsoon"]

## Walking speed factor in a weather.
static func speed_factor(weather_id: String) -> float:
    return 0.9 if weather_id == "sandstorm" else 1.0

## How far creatures notice characters in a weather.
static func detection_factor(weather_id: String) -> float:
    return 0.7 if weather_id in ["fog", "gloom_mist", "sandstorm"] else 1.0

## Fish bite delay factor in a weather.
static func bite_factor(weather_id: String) -> float:
    return 0.75 if is_wet(weather_id) else 1.0
