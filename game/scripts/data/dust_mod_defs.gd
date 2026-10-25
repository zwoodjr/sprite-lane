class_name DustModDefs
extends RefCounted

## Weekly Dust modifiers. Each ISO week (DailyDefs.iso_week) rolls 1–2 of
## these from a seed derived from the week key, so every player sees the same
## ones. The Daily Run always carries them; normal Wander runs can opt in for
## the listed payout bonus ("loot", added to the extract payout multiplier).
##
## Effects reuse existing systems:
##   "fx"      — same keys as the Dust Pacts (GameState.pact_fx), plus
##               hero_damage / move / dash_cd / scrap / run_xp.
##   "twists"  — zone twists switched on for the run (zone_twists.gd).
##   "raiders" — raider crews on every tier, first one early (match controller).
##   "elites"  — elites from the first minutes, always in pairs.
## "clash": never rolled in the same week as these.

const MODS := {
	"heavy_dust": {"name": "Heavy Dust", "desc": "Visibility down: you won't see them until they're close. Loot +25%.",
		"loot": 0.25, "twists": ["shroud"], "clash": ["blackout_nights"], "icon": "hud_threat"},
	"blackout_nights": {"name": "Blackout Nights", "desc": "Night on every zone. Stay in the light, grab flares. Loot +25%.",
		"loot": 0.25, "twists": ["night"], "clash": ["heavy_dust"], "icon": "hud_threat"},
	"scrap_rain": {"name": "Scrap Rain", "desc": "Kills shower 50% more scrap, but enemies have +15% HP.",
		"loot": 0.0, "fx": {"scrap": 1.5, "enemy_hp": 1.15}, "icon": "cur_scrap"},
	"raider_week": {"name": "Raider Week", "desc": "Raider crews roam every tier and turn up early. Loot +20%.",
		"loot": 0.2, "raiders": true, "icon": "hud_kills"},
	"glass_hero": {"name": "Glass Hero", "desc": "Half max HP, +40% damage. Loot +15%.",
		"loot": 0.15, "fx": {"max_hp": 0.5, "hero_damage": 1.4}, "clash": ["dry_wells"], "icon": "hud_kills"},
	"elite_pairs": {"name": "Elite Pairs", "desc": "Elites hunt from the first minutes, always two at once. Loot +20%.",
		"loot": 0.2, "elites": true, "icon": "hud_kills"},
	"swarm_season": {"name": "Swarm Season", "desc": "30% more enemies; run XP +25%. Loot +10%.",
		"loot": 0.1, "fx": {"spawn": 1.3, "run_xp": 1.25}, "icon": "hud_threat"},
	"tight_windows": {"name": "Tight Windows", "desc": "Extract windows close 3 s sooner. Loot +15%.",
		"loot": 0.15, "fx": {"window": -3.0}, "icon": "hud_timer"},
	"dry_wells": {"name": "Dry Wells", "desc": "Enemies drop no healing tonics. Loot +20%.",
		"loot": 0.2, "fx": {"no_tonics": 1.0}, "clash": ["glass_hero"], "icon": "hud_loot"},
	"tailwind": {"name": "Tailwind", "desc": "+15% move speed, dashes recharge 20% faster, but enemies hit 15% harder.",
		"loot": 0.05, "fx": {"move": 0.15, "dash_cd": 0.8, "enemy_damage": 1.15}, "icon": "hud_timer"},
}
## Pact-style keys that add (everything else multiplies).
const ADD_KEYS: Array = ["window", "no_tonics", "window_elite", "move"]
const RAIDER_FIRST := 75.0
const RAIDER_MIN_TIER := 3
const ELITE_FIRST := 90.0
const SALT := "wanderer-dust-"


static func ids() -> Array:
	var out: Array = MODS.keys()
	out.sort()
	return out


static func mod(id: String) -> Dictionary:
	return MODS.get(id, {})


static func mod_name(id: String) -> String:
	return str(mod(id).get("name", id))


## The week's modifiers (1–2 ids), deterministic per ISO week key.
static func for_week(week_key: String) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = DailyDefs.fnv32(SALT + week_key)
	var pool := ids()
	## Two most weeks, one about every third week.
	var n := 1 if r.randi_range(0, 2) == 0 else 2
	var out: Array = []
	var guard := 0
	while out.size() < n and guard < 50:
		guard += 1
		var id := str(pool[r.randi_range(0, pool.size() - 1)])
		if id in out:
			continue
		var ok := true
		for o in out:
			if id in (mod(str(o)).get("clash", []) as Array) or str(o) in (mod(id).get("clash", []) as Array):
				ok = false
		if ok:
			out.append(id)
	return out


static func for_date(date: String) -> Array:
	return for_week(DailyDefs.iso_week(date))


## Payout bonus for a set of modifiers (added to the extract multiplier).
static func loot_bonus(mods: Array) -> float:
	var b := 0.0
	for id in mods:
		b += float(mod(str(id)).get("loot", 0.0))
	return b


static func fx_of(mods: Array, key: String) -> float:
	var add := key in ADD_KEYS
	var v := 0.0 if add else 1.0
	for id in mods:
		var fx: Dictionary = mod(str(id)).get("fx", {})
		if fx.has(key):
			v = v + float(fx[key]) if add else v * float(fx[key])
	return v


static func twists_of(mods: Array) -> Array:
	var out: Array = []
	for id in mods:
		for t in mod(str(id)).get("twists", []):
			if not t in out:
				out.append(t)
	return out


static func has_flag(mods: Array, flag: String) -> bool:
	for id in mods:
		if bool(mod(str(id)).get(flag, false)):
			return true
	return false
