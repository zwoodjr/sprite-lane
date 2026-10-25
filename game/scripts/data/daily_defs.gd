class_name DailyDefs
extends RefCounted

## Wander extras: the Daily Run and the weekly Dust modifiers' calendar.
##
## DAILY RUN — one fixed seed per calendar day (the device's local date), so
## everyone who plays that day drops into the same map, pads, events and
## spawns. To keep scores comparable the day also fixes the tier (Drift), the
## survivor and the pet; the run always carries the week's Dust modifiers
## (DustModDefs) and no Dust Pacts. The FIRST finished attempt of the day is
## the one that counts; later attempts are practice (shown, never counted).
##
## SCORE (0 if you go down):
##   scrap hauled  = (stipend + bag) × loot multiplier  (no hangar / gear bonuses)
##   + kills × KILL_POINTS
##   + seconds survived × TIME_POINTS
## Hangar ranks don't enter the score; gear and kit still matter, as in any run.

const TIER_ID := "drift"
const KILL_POINTS := 2
const TIME_POINTS := 1
## Days kept in the daily board (the save prunes older ones).
const BOARD_DAYS := 30
## Pets everyone owns (mech pets must be built, so they never get rolled).
const DAILY_PETS: Array = ["noel", "bentley", "lillie"]
const SEED_SALT := "wanderer-daily-"


## FNV-1a 32-bit of a string: stable on every platform and Godot version
## (String.hash() isn't promised to be).
static func fnv32(s: String) -> int:
	var h := 2166136261
	for b in s.to_utf8_buffer():
		h = h ^ int(b)
		h = (h * 16777619) & 0xFFFFFFFF
	return h


## The day's run seed (never 0: 0 means "roll a fresh one").
static func seed_for(date: String) -> int:
	var h := fnv32(SEED_SALT + date)
	return h if h != 0 else 1


static func _rng(date: String, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_for(date) * 31 + salt
	return r


## The survivor everyone plays that day.
static func hero_for(date: String) -> String:
	var ids: Array = CharacterDefs.PLAYABLE_IDS
	return str(ids[_rng(date, 11).randi_range(0, ids.size() - 1)])


static func pet_for(date: String) -> String:
	return str(DAILY_PETS[_rng(date, 23).randi_range(0, DAILY_PETS.size() - 1)])


## Score parts for a finished run. `hauled`, `kills`, `seconds`, `extracted`.
static func score_parts(hauled: int, kills: int, seconds: float, extracted: bool) -> Dictionary:
	var k := kills * KILL_POINTS
	var t := int(floor(maxf(seconds, 0.0))) * TIME_POINTS
	var total := hauled + k + t if extracted else 0
	return {"scrap": hauled, "kills": k, "kill_n": kills, "time": t, "seconds": int(floor(maxf(seconds, 0.0))),
		"extracted": extracted, "total": total}


static func fmt_time(seconds: float) -> String:
	var s := int(floor(maxf(seconds, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]


## --- Calendar ---------------------------------------------------------------

static func date_unix(date: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(date + "T12:00:00"))


static func date_add(date: String, days: int) -> String:
	return Time.get_date_string_from_unix_time(date_unix(date) + days * 86400)


## ISO-8601 week key ("2026-W43"): weeks start Monday; week 1 holds the
## year's first Thursday.
static func iso_week(date: String) -> String:
	var t := date_unix(date)
	var wd := int(Time.get_datetime_dict_from_unix_time(t)["weekday"]) ## 0 = Sunday
	var mon_based := (wd + 6) % 7 ## 0 = Monday
	var thu := t + (3 - mon_based) * 86400
	var y := int(Time.get_datetime_dict_from_unix_time(thu)["year"])
	var jan1 := int(Time.get_unix_time_from_datetime_string("%04d-01-01T12:00:00" % y))
	var week := (thu - jan1) / (86400 * 7) + 1
	return "%04d-W%02d" % [y, week]


## Monday's date of the week `date` falls in.
static func week_start(date: String) -> String:
	var wd := int(Time.get_datetime_dict_from_unix_time(date_unix(date))["weekday"])
	return date_add(date, -((wd + 6) % 7))


## Short shareable result card (plain text, fits a message).
static func share_text(entry: Dictionary) -> String:
	var hero := str(CharacterDefs.get_character(str(entry.get("hero", ""))).get("display_name", entry.get("hero", "")))
	var lines: PackedStringArray = []
	lines.append("WANDERER DAILY · %s" % str(entry.get("date", "")))
	lines.append("Score %d · %s" % [int(entry.get("score", 0)), "EXTRACTED" if bool(entry.get("extracted", false)) else "WENT DOWN"])
	lines.append("%s · %s · %d kills · %s" % [hero, str(ModeDefs.get_mode(TIER_ID)["display_name"]),
		int(entry.get("kills", 0)), fmt_time(float(entry.get("seconds", 0)))])
	var mods: Array = entry.get("mods", [])
	if not mods.is_empty():
		lines.append("Dust: " + ", ".join(PackedStringArray(mods.map(func(m: Variant) -> String: return DustModDefs.mod_name(str(m))))))
	if bool(entry.get("practice", false)):
		lines.append("(practice run)")
	return "\n".join(lines)
