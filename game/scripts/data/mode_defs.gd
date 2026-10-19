class_name ModeDefs
extends RefCounted

## Run tiers (stay-or-go). All 10 are data-driven; only `exposed` ones show in
## the mode select (Haze + Drift for now).
##
## Timeline per tier:
##   lockout (first_window s) → [window open window_open s → sealed] × windows
##   → LAST CHANCE (red, last_chance_open s) → Dust storm (run ends as a death).
## Windows open every `window_every` s (start to start).
## Loot multiplier: ×1.0, +loot_step every loot_every s, capped at loot_cap.
## Threat rises with the multiplier (see threat_for_mult).
## Death keeps `death_keep` of carried scrap; extract pays full × multiplier.

const HAZE_ID := "haze"
const DRIFT_ID := "drift"
## Legacy aliases (old saves / scripts).
const EASY_ID := HAZE_ID
const MEDIUM_ID := DRIFT_ID

## How many tiers players can pick right now.
const EXPOSED_TIERS := 10

const LOOT_STEP := 0.1
const LOOT_EVERY := 30.0
## Minimap ping / pads appear this long before a window opens.
const PING_LEAD := 10.0
## Elites / bosses (Part 3 + 5): from these tiers, on this schedule (seconds
## of run time, scaled by fast timers). Two elites at once from DOUBLE_ELITE.
const ELITE_FROM_TIER := 3
const BOSS_FROM_TIER := 5
const DOUBLE_ELITE_FROM_TIER := 8
const ELITE_FIRST := 180.0
const ELITE_EVERY := 120.0
const BOSS_FIRST := 240.0
const BOSS_EVERY := 300.0
## Dust storm: seconds of storm after the last chance closes before the wipe.
const STORM_SECONDS := 3.0


## Part 5 table: id, name, strength, payout, keep on death, blurb.
const TIER_TABLE: Array = [
	["haze", "Haze", 0.85, 0.75, 0.10, "Thin dust. Forgiving windows — learn when to leave."],
	["drift", "Drift", 1.0, 1.0, 0.15, "Real pressure. Shorter windows, richer bags."],
	["smog", "Smog", 1.15, 1.25, 0.20, "Elites start hunting. They carry good gear."],
	["pall", "Pall", 1.30, 1.5, 0.25, "The sky goes grey at noon."],
	["blight", "Blight", 1.50, 1.8, 0.30, "Bosses walk the dust now."],
	["shroud", "Shroud", 1.70, 2.1, 0.35, "You hear them before you see them."],
	["choke", "Choke", 1.95, 2.5, 0.40, "Every breath costs something."],
	["blackout", "Blackout", 2.20, 3.0, 0.45, "Elites hunt in pairs."],
	["deadfall", "Deadfall", 2.50, 3.5, 0.50, "Nothing out here wants you to leave."],
	["dustfall", "Dustfall", 3.00, 4.5, 0.55, "Pay the dust its due."],
]
## Window rule above Drift: each tier 1s shorter open, longer gap / first window.
const DRIFT_FIRST := 120.0
const DRIFT_EVERY := 90.0
const DRIFT_OPEN := 15.0
const OPEN_STEP := -1.0
const EVERY_STEP := 5.0
const FIRST_STEP := 5.0
const MIN_OPEN := 7.0
const WINDOWS_BY_TIER: Array = [3, 4, 4, 4, 5, 5, 5, 6, 6, 6]
const LOOT_CAP_HAZE := 2.5
const LOOT_CAP := 3.0
const SPAWN_STEP := 0.05
## Damage scales a little gentler than HP so high tiers stay dodgeable.
const DAMAGE_SHARE := 0.8
## Tiers open from the start; the rest unlock by extracting on the tier below.
const START_UNLOCKED := 2


static func _tiers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(TIER_TABLE.size()):
		var r: Array = TIER_TABLE[i]
		var tier := i + 1
		var strength := float(r[2])
		if tier == 1:
			out.append(_t(str(r[0]), str(r[1]), 1, 90.0, 75.0, 20.0, 3, 20.0, LOOT_CAP_HAZE, float(r[4]), strength, strength, 0.9, float(r[3]), 3, str(r[5])))
			continue
		var above := tier - 2
		var open := maxf(MIN_OPEN, DRIFT_OPEN + OPEN_STEP * above)
		var dmg := 1.0 + (strength - 1.0) * DAMAGE_SHARE
		out.append(_t(str(r[0]), str(r[1]), tier, DRIFT_FIRST + FIRST_STEP * above, DRIFT_EVERY + EVERY_STEP * above,
			open, int(WINDOWS_BY_TIER[i]), open, LOOT_CAP, float(r[4]), strength, dmg, 1.0 + SPAWN_STEP * above,
			float(r[3]), 2, str(r[5])))
	return out


static func _t(id: String, name: String, tier: int, first: float, every: float, open: float,
		windows: int, last_open: float, loot_cap: float, keep: float, hp: float, dmg: float,
		spawn: float, payout: float, slots: int, blurb: String) -> Dictionary:
	return {
		"id": id, "display_name": name, "tier": tier,
		"first_window": first, "window_every": every, "window_open": open,
		"windows": windows, "last_chance_open": last_open,
		"loot_cap": loot_cap, "death_keep": keep,
		"enemy_hp": hp, "enemy_damage": dmg, "spawn_density": spawn,
		"payout_mult": payout, "insurance_slots": slots, "blurb": blurb,
		"tl_step_size": 1.0,
	}


static func canonical_id(mode_id: String) -> String:
	match mode_id:
		"easy":
			return HAZE_ID
		"medium":
			return DRIFT_ID
		"squall":
			return "smog"
		"rustwind":
			return "pall"
		"ashfall":
			return "blight"
		"glasstorm":
			return "choke"
		"deadwind":
			return "deadfall"
		"maelstrom", "dust_god":
			return "dustfall"
	return mode_id


static func all_tiers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in _tiers():
		out.append(_finish(t))
	return out


## Only the tiers players can pick.
static func all_modes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in all_tiers():
		if int(t["tier"]) <= EXPOSED_TIERS:
			out.append(t)
	return out


static func is_exposed(mode_id: String) -> bool:
	var m := get_mode(mode_id)
	return str(m["id"]) == canonical_id(mode_id) and int(m["tier"]) <= EXPOSED_TIERS


## Tier dict by tier number (1..10).
static func tier_mode(tier: int) -> Dictionary:
	for t in _tiers():
		if int(t["tier"]) == tier:
			return _finish(t)
	return _finish(_tiers()[0])


static func get_mode(mode_id: String) -> Dictionary:
	var id := canonical_id(mode_id)
	for t in _tiers():
		if str(t["id"]) == id:
			return _finish(t)
	return _finish(_tiers()[0])


## Adds the derived phase list + display minutes.
static func _finish(t: Dictionary) -> Dictionary:
	var m := t.duplicate(true)
	m["phases"] = build_phases(m)
	var total := 0.0
	for p in m["phases"]:
		total += float(p["duration"])
	m["target_minutes"] = int(ceil(total / 60.0))
	return m


static func build_phases(m: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var open := float(m["window_open"])
	var gap := maxf(5.0, float(m["window_every"]) - open)
	out.append({"id": "lockout", "label": "Lockout", "duration": float(m["first_window"]), "extract_open": false, "is_last": false})
	for i in range(int(m["windows"])):
		out.append({"id": "window_%d" % (i + 1), "label": "Extract Window %d" % (i + 1), "duration": open, "extract_open": true, "is_last": false})
		out.append({"id": "seal_%d" % (i + 1), "label": "Sealed", "duration": gap, "extract_open": false, "is_last": false})
	out.append({"id": "last_extract", "label": "Last Chance", "duration": float(m["last_chance_open"]), "extract_open": true, "is_last": true})
	return out


## Loot multiplier after `seconds` in the run.
static func loot_mult_at(m: Dictionary, seconds: float) -> float:
	var steps := floorf(maxf(seconds, 0.0) / LOOT_EVERY)
	return minf(1.0 + steps * LOOT_STEP, float(m.get("loot_cap", 2.5)))


## Threat rises with the multiplier: +1 per +0.5.
static func threat_for_mult(mult: float) -> int:
	return clampi(int(floor((mult - 1.0) / 0.5 + 0.001)), 0, 8)


## Threat Level multipliers. Higher tiers keep stacking.
static func tl_table(tl: int) -> Dictionary:
	var t := clampi(tl, 0, 8)
	return {
		"hp": 1.0 + 0.16 * t,
		"damage": 1.0 + 0.12 * t,
		"spawn": 1.0 + 0.2 * t,
	}
