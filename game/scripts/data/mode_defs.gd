class_name ModeDefs
extends RefCounted

## Dust-thickness difficulty tiers (Master Brief Part 5 / Phase 2 + 8).
## Haze replaces Easy; Drift replaces Medium. Tiers 3–10 unlock by extracting below.

const HAZE_ID := "haze"
const DRIFT_ID := "drift"
const EASY_ID := HAZE_ID ## legacy alias
const MEDIUM_ID := DRIFT_ID ## legacy alias

const TIER_TABLE := [
	{"id": "haze", "tier": 1, "display_name": "Haze", "enemy": 0.85, "payout": 0.75, "keep": 0.10, "loot_cap": 2.5, "target_minutes": 5, "first_window": 90.0, "gap": 75.0, "open": 20.0, "windows": 3},
	{"id": "drift", "tier": 2, "display_name": "Drift", "enemy": 1.0, "payout": 1.0, "keep": 0.15, "loot_cap": 3.0, "target_minutes": 8, "first_window": 120.0, "gap": 90.0, "open": 15.0, "windows": 4},
	{"id": "smog", "tier": 3, "display_name": "Smog", "enemy": 1.15, "payout": 1.25, "keep": 0.20, "loot_cap": 3.0, "target_minutes": 9, "first_window": 120.0, "gap": 95.0, "open": 14.0, "windows": 4},
	{"id": "pall", "tier": 4, "display_name": "Pall", "enemy": 1.30, "payout": 1.5, "keep": 0.25, "loot_cap": 3.0, "target_minutes": 10, "first_window": 125.0, "gap": 100.0, "open": 13.0, "windows": 4},
	{"id": "blight", "tier": 5, "display_name": "Blight", "enemy": 1.50, "payout": 1.8, "keep": 0.30, "loot_cap": 3.0, "target_minutes": 11, "first_window": 130.0, "gap": 105.0, "open": 12.0, "windows": 4},
	{"id": "shroud", "tier": 6, "display_name": "Shroud", "enemy": 1.70, "payout": 2.1, "keep": 0.35, "loot_cap": 3.0, "target_minutes": 12, "first_window": 135.0, "gap": 110.0, "open": 11.0, "windows": 4},
	{"id": "choke", "tier": 7, "display_name": "Choke", "enemy": 1.95, "payout": 2.5, "keep": 0.40, "loot_cap": 3.0, "target_minutes": 12, "first_window": 140.0, "gap": 115.0, "open": 10.0, "windows": 4},
	{"id": "blackout", "tier": 8, "display_name": "Blackout", "enemy": 2.20, "payout": 3.0, "keep": 0.45, "loot_cap": 3.0, "target_minutes": 13, "first_window": 145.0, "gap": 120.0, "open": 9.0, "windows": 4},
	{"id": "deadfall", "tier": 9, "display_name": "Deadfall", "enemy": 2.50, "payout": 3.5, "keep": 0.50, "loot_cap": 3.0, "target_minutes": 14, "first_window": 150.0, "gap": 125.0, "open": 8.0, "windows": 4},
	{"id": "dustfall", "tier": 10, "display_name": "Dustfall", "enemy": 3.0, "payout": 4.5, "keep": 0.55, "loot_cap": 3.0, "target_minutes": 15, "first_window": 155.0, "gap": 130.0, "open": 7.0, "windows": 4},
]


static func _canonicalize(mode_id: String) -> String:
	match mode_id:
		"easy":
			return HAZE_ID
		"medium":
			return DRIFT_ID
		_:
			return mode_id


static func all_modes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in TIER_TABLE:
		out.append(get_mode(str(row["id"])))
	return out


static func playable_modes(highest_unlocked_tier: int) -> Array[Dictionary]:
	## Phase 2 ships 1–2; Phase 8 unlocks 3–10 after extracting below.
	var out: Array[Dictionary] = []
	for row in TIER_TABLE:
		var t := int(row["tier"])
		if t <= 2 or t <= highest_unlocked_tier:
			out.append(get_mode(str(row["id"])))
	return out


static func get_tier_row(mode_id: String) -> Dictionary:
	var id := _canonicalize(mode_id)
	for row in TIER_TABLE:
		if str(row["id"]) == id:
			return row
	return TIER_TABLE[0]


static func get_mode(mode_id: String) -> Dictionary:
	var row := get_tier_row(mode_id)
	var enemy := float(row["enemy"])
	var tier := int(row["tier"])
	return {
		"id": str(row["id"]),
		"tier": tier,
		"display_name": str(row["display_name"]),
		"target_minutes": int(row["target_minutes"]),
		"length_scale": 1.0,
		"tl_step_size": 1.0,
		"enemy_hp": enemy,
		"enemy_damage": enemy,
		"spawn_density": 0.85 + enemy * 0.15 if tier == 1 else enemy,
		"payout_mult": float(row["payout"]),
		"keep_on_death": float(row["keep"]),
		"loot_mult_cap": float(row["loot_cap"]),
		"insurance_slots": 3 if tier == 1 else 2,
		"elites": tier >= 3,
		"bosses": tier >= 5,
		"dual_elites": tier >= 8,
		"phases": _build_phases(row),
	}


static func _build_phases(row: Dictionary) -> Array[Dictionary]:
	## First window at first_window, then gap between opens; each open lasts `open` seconds.
	var first := float(row["first_window"])
	var gap := float(row["gap"])
	var open := float(row["open"])
	var windows := int(row["windows"])
	var phases: Array[Dictionary] = []
	phases.append({
		"id": "lockout", "label": "Lockout", "duration": first,
		"extract_open": false, "is_last": false,
	})
	for i in range(windows):
		var is_last := i == windows - 1
		phases.append({
			"id": "window_%d" % (i + 1),
			"label": "Last Chance" if is_last else "Extract Window %d" % (i + 1),
			"duration": open,
			"extract_open": true,
			"is_last": is_last,
		})
		if not is_last:
			## Seal duration = gap between windows minus the open we just finished.
			var seal := maxf(20.0, gap - open)
			phases.append({
				"id": "seal_%d" % (i + 1),
				"label": "Sealed",
				"duration": seal,
				"extract_open": false,
				"is_last": false,
			})
	return phases


## Threat Level multipliers (Drift baseline). Climbs with loot multiplier / time survived.
static func tl_table(tl: int) -> Dictionary:
	match clampi(tl, 0, 5):
		0:
			return {"hp": 1.0, "damage": 1.0, "spawn": 1.0, "payout": 1.0}
		1:
			return {"hp": 1.12, "damage": 1.08, "spawn": 1.15, "payout": 1.15}
		2:
			return {"hp": 1.28, "damage": 1.18, "spawn": 1.35, "payout": 1.35}
		3:
			return {"hp": 1.48, "damage": 1.32, "spawn": 1.55, "payout": 1.6}
		4:
			return {"hp": 1.7, "damage": 1.48, "spawn": 1.8, "payout": 1.9}
		_:
			return {"hp": 2.0, "damage": 1.7, "spawn": 2.1, "payout": 2.3}
