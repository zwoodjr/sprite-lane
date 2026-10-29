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


## --- Extract economy (Part 6 targets: ~250 scrap a Drift extract, ~1,500+ on
## Blackout; a weekend of ~25 runs maxes a station + a couple of shared upgrades).
## Bag value = scrap picked up × BAG_SCRAP_VALUE + kills × BAG_KILL_VALUE
##   + medicine crates × MedicineDefs.MEDICINE_SCRAP, with diminishing returns
##   above BAG_KNEE (see bag_curve). Death keeps death_keep of it.
## Extract pays (BAG_STIPEND + bag) × loot multiplier × tier payout × set/pact
## bonuses, plus flat bonuses (radio jobs, Ambush Bounty) × tier payout × BONUS_SCALE.
const BAG_STIPEND := 30
const BAG_SCRAP_VALUE := 0.3
const BAG_KILL_VALUE := 0.35
const BONUS_SCALE := 0.4
## Diminishing returns: above BAG_KNEE the bag counts as KNEE × (bag/KNEE)^BAG_EXP,
## so a huge late-tier bag doesn't multiply into a five-figure payout (loot ×,
## tier payout and boss bonus already reward staying).
const BAG_KNEE := 100.0
const BAG_EXP := 0.6
## Every scrap-find bonus (Scrap Press, gear, Scavenger's Eye, Fortune, quirk,
## Field Salvager 2) adds together, capped here — they used to multiply.
const FIND_MULT_CAP := 2.0


static func bag_curve(raw: float) -> float:
	if raw <= BAG_KNEE:
		return raw
	return BAG_KNEE * pow(raw / BAG_KNEE, BAG_EXP)


## Part 5 table: id, name, enemy HP, enemy damage, spawn density, payout,
## keep on death, blurb. Balance pass (Oct 2026): Haze–Blight never threatened
## (no hits in the first minute, 0 deaths, the campaign cleared first try), so
## the early tiers hit harder and come in thicker; Haze stays the gentle one.
const TIER_TABLE: Array = [
	["haze", "Haze", 1.0, 1.3, 1.0, 0.75, 0.10, "Thin dust. Forgiving windows — learn when to leave."],
	["drift", "Drift", 1.25, 1.55, 1.12, 1.0, 0.15, "Real pressure. Shorter windows, richer bags."],
	["smog", "Smog", 1.4, 1.65, 1.18, 1.25, 0.20, "Elites start hunting. They carry good gear."],
	["pall", "Pall", 1.55, 1.75, 1.24, 1.5, 0.25, "The sky goes grey at noon."],
	["blight", "Blight", 1.75, 1.85, 1.3, 1.8, 0.30, "Bosses walk the dust now."],
	["shroud", "Shroud", 1.8, 1.9, 1.32, 2.1, 0.35, "You hear them before you see them."],
	["choke", "Choke", 2.0, 1.95, 1.36, 2.3, 0.40, "Every breath costs something."],
	["blackout", "Blackout", 2.25, 2.05, 1.4, 2.6, 0.45, "Elites hunt in pairs."],
	["deadfall", "Deadfall", 2.55, 2.25, 1.45, 3.0, 0.50, "Nothing out here wants you to leave."],
	["dustfall", "Dustfall", 3.0, 2.6, 1.5, 3.6, 0.55, "Pay the dust its due."],
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
## Tiers open from the start; the rest unlock by extracting on the tier below.
const START_UNLOCKED := 2
## Balance pass: extracts needed on a tier (or harder) before the next one opens
## (index = tier - 1). One extract per tier opened Dustfall by career run ~10;
## this paces it to ~30 runs (21 extracts minimum from Drift up; a Monte Carlo
## career at the measured death rates lands at 26-40 runs, mean ~32).
const UNLOCK_EXTRACTS: Array = [1, 2, 2, 2, 3, 3, 3, 3, 3, 4]


static func unlock_extracts(tier: int) -> int:
	return int(UNLOCK_EXTRACTS[clampi(tier, 1, UNLOCK_EXTRACTS.size()) - 1])


static func _tiers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(TIER_TABLE.size()):
		var r: Array = TIER_TABLE[i]
		var tier := i + 1
		if tier == 1:
			out.append(_t(str(r[0]), str(r[1]), 1, 90.0, 75.0, 20.0, 3, 20.0, LOOT_CAP_HAZE, float(r[6]), float(r[2]), float(r[3]), float(r[4]), float(r[5]), 3, str(r[7])))
			continue
		var above := tier - 2
		var open := maxf(MIN_OPEN, DRIFT_OPEN + OPEN_STEP * above)
		out.append(_t(str(r[0]), str(r[1]), tier, DRIFT_FIRST + FIRST_STEP * above, DRIFT_EVERY + EVERY_STEP * above,
			open, int(WINDOWS_BY_TIER[i]), open, LOOT_CAP, float(r[6]), float(r[2]), float(r[3]), float(r[4]),
			float(r[5]), 2, str(r[7])))
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


## --- Ascension (post-Dustfall chase, Oct 2026) ----------------------------
## Dustfall again, ranked: each Ascension level keeps every rule below it and
## adds one more (forced Dust Pacts, then Greed from the drop), plus
## ASCENSION_LOOT payout per level on top of the pacts' own loot. A level
## opens by extracting on the one below (A1 after any Dustfall extract).
## Death keeps Dustfall's share (55%).
const ASCENSION_MAX := 10
const ASCENSION_LOOT := 0.1
## [name, pact id or "", greed at the drop, short rule text, extra fx]
## Ordered mild -> harsh from bot data (Dustfall, max Bunker + kit, leave at
## the first window): the old order flat-lined A3-A7 and walled at Greed 1.
const ASCENSION := [
	["A1", "no_mercy", 0, "No tonic drops", {}],
	["A2", "narrow_windows", 0, "Windows close 3 s sooner", {}],
	["A3", "hunted", 0, "An elite joins every window", {}],
	["A4", "thick_dust", 0, "Enemies +25% HP", {}],
	["A5", "hungry_dark", 0, "+25% more enemies", {}],
	["A6", "sharp_teeth", 0, "Enemies hit 20% harder", {}],
	["A7", "brittle_bones", 0, "-25% max HP", {}],
	["A8", "", 0, "Dust-hardened: enemies +15% HP and damage", {"enemy_hp": 1.15, "enemy_damage": 1.15}],
	["A9", "", 0, "Dust-hardened II: another +15% HP and damage", {"enemy_hp": 1.15, "enemy_damage": 1.15}],
	["A10", "", 1, "Greed 1 from the drop", {}],
]


## Extra multiplier for a pact_fx key at Ascension `lv` (A8 / A9 rules).
static func ascension_fx(lv: int, key: String) -> float:
	var v := 1.0
	for i in range(clampi(lv, 0, ASCENSION_MAX)):
		var fx: Dictionary = ASCENSION[i][4] if (ASCENSION[i] as Array).size() > 4 else {}
		if fx.has(key):
			v *= float(fx[key])
	return v


## Forced pacts for Ascension level `lv` (cumulative).
static func ascension_pacts(lv: int) -> Array:
	var out: Array = []
	for i in range(clampi(lv, 0, ASCENSION_MAX)):
		var p := str(ASCENSION[i][1])
		if p != "" and not p in out:
			out.append(p)
	return out


static func ascension_greed(lv: int) -> int:
	var g := 0
	for i in range(clampi(lv, 0, ASCENSION_MAX)):
		g = maxi(g, int(ASCENSION[i][2]))
	return g


## Payout added by the level itself (pacts add their own loot on top).
static func ascension_loot(lv: int) -> float:
	return ASCENSION_LOOT * float(clampi(lv, 0, ASCENSION_MAX))


## --- Greed pressure (difficulty pass, Oct 2026) ----------------------------
## Bots never died on Haze: 24/24 runs extracted, ~97% HP at the pad, even after
## staying three windows. Every extract window you let close now makes the
## rest of the run meaner: tougher, harder-hitting, denser mobs, a higher live
## cap, a punish wave the moment the window seals, and a Greed elite (every
## tier, not just Smog+). Values per window skipped, capped at GREED_MAX.
const GREED_MAX := 4
const GREED_HP := 0.45
const GREED_DAMAGE := 0.28
const GREED_SPAWN := 0.5
const GREED_CAP := 5
## Healing after you stay: each skipped window cuts all healing (tonics, regen,
## heals, lifesteal) so survivors can't top back up before the next pad.
const GREED_HEAL := 0.2
const GREED_HEAL_MIN := 0.3
## Punish wave on a skip: BASE + PER × windows skipped mobs, from two sides.
const GREED_WAVE_BASE := 6
const GREED_WAVE_PER := 4
## Live enemy soft cap (perf headroom from the overnight pass: 60-mob hordes
## hold frame budget). Last Extract keeps fewer but heavier T3 units.
const ENEMY_CAP := 18
const ENEMY_CAP_THREAT2 := 21
const ENEMY_CAP_LAST := 16
const ENEMY_CAP_MAX := 36


static func greed(skips: int) -> Dictionary:
	var s := clampi(skips, 0, GREED_MAX)
	return {
		"hp": 1.0 + GREED_HP * s,
		"damage": 1.0 + GREED_DAMAGE * s,
		"spawn": 1.0 + GREED_SPAWN * s,
		"cap": GREED_CAP * s,
		"heal": maxf(GREED_HEAL_MIN, 1.0 - GREED_HEAL * s),
	}


## Threat table with greed pressure folded in (what the match actually uses).
static func run_table(tl: int, skips: int) -> Dictionary:
	var t := tl_table(tl)
	var g := greed(skips)
	return {"hp": float(t["hp"]) * float(g["hp"]), "damage": float(t["damage"]) * float(g["damage"]),
		"spawn": float(t["spawn"]) * float(g["spawn"])}


## Threat Level multipliers. Higher tiers keep stacking.
static func tl_table(tl: int) -> Dictionary:
	var t := clampi(tl, 0, 8)
	return {
		"hp": 1.0 + 0.16 * t,
		"damage": 1.0 + 0.12 * t,
		"spawn": 1.0 + 0.2 * t,
	}
