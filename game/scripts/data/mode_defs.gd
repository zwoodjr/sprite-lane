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
const EXPOSED_TIERS := 2

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


static func _tiers() -> Array[Dictionary]:
	## id, name, first_window, window_every, window_open, windows (regular),
	## last_chance_open, loot_cap, death_keep, enemy hp/dmg, spawn density,
	## payout mult, insurance slots, blurb.
	return [
		_t(HAZE_ID, "Haze", 1, 90.0, 75.0, 20.0, 3, 20.0, 2.5, 0.10, 0.85, 0.85, 0.9, 0.75, 3,
			"Thin dust. Forgiving windows — learn when to leave."),
		_t(DRIFT_ID, "Drift", 2, 120.0, 90.0, 15.0, 4, 15.0, 3.0, 0.15, 1.0, 1.0, 1.0, 1.0, 2,
			"Real pressure. Shorter windows, richer bags."),
		_t("squall", "Squall", 3, 135.0, 95.0, 14.0, 4, 14.0, 3.2, 0.15, 1.15, 1.1, 1.1, 1.2, 2,
			"Gusts hide the pads."),
		_t("rustwind", "Rustwind", 4, 150.0, 100.0, 13.0, 4, 13.0, 3.4, 0.18, 1.3, 1.2, 1.15, 1.4, 2,
			"Rust raiders run the dunes."),
		_t("ashfall", "Ashfall", 5, 160.0, 105.0, 12.0, 5, 12.0, 3.6, 0.18, 1.45, 1.3, 1.2, 1.6, 2,
			"Burning sky, burning ground."),
		_t("blackout", "Blackout", 6, 170.0, 110.0, 12.0, 5, 12.0, 3.8, 0.2, 1.6, 1.4, 1.25, 1.85, 1,
			"Signal dead. Trust the arrows."),
		_t("glasstorm", "Glasstorm", 7, 180.0, 115.0, 11.0, 5, 11.0, 4.0, 0.2, 1.8, 1.5, 1.3, 2.1, 1,
			"Sand turned to knives."),
		_t("deadwind", "Deadwind", 8, 190.0, 120.0, 10.0, 6, 10.0, 4.3, 0.2, 2.0, 1.6, 1.35, 2.4, 1,
			"Nothing lives out here. Something does."),
		_t("maelstrom", "Maelstrom", 9, 200.0, 120.0, 10.0, 6, 10.0, 4.6, 0.22, 2.25, 1.75, 1.4, 2.75, 1,
			"The storm has a centre. Don't find it."),
		_t("dust_god", "Dust God", 10, 210.0, 125.0, 9.0, 6, 9.0, 5.0, 0.25, 2.5, 1.9, 1.5, 3.2, 0,
			"Pay the dust its due."),
	]


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
