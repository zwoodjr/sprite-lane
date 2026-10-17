class_name ModeDefs
extends RefCounted

## Easy baseline timings (seconds). Medium = Easy × 2 with Window 3 inserted.
## See docs/game-design.md — Timing table.

const EASY_ID := "easy"
const MEDIUM_ID := "medium"

static func all_modes() -> Array[Dictionary]:
	return [get_mode(EASY_ID), get_mode(MEDIUM_ID)]


static func get_mode(mode_id: String) -> Dictionary:
	match mode_id:
		MEDIUM_ID:
			return {
				"id": MEDIUM_ID,
				"display_name": "Medium",
				"target_minutes": 10,
				"length_scale": 2.0,
				"tl_step_size": 1.0,
				"enemy_hp": 1.0,
				"enemy_damage": 1.0,
				"spawn_density": 1.0,
				"payout_mult": 1.0,
				"insurance_slots": 2,
				"phases": _medium_phases(),
			}
		_:
			return {
				"id": EASY_ID,
				"display_name": "Easy",
				"target_minutes": 5,
				"length_scale": 1.0,
				"tl_step_size": 0.85,
				"enemy_hp": 0.85,
				"enemy_damage": 0.85,
				"spawn_density": 0.9,
				"payout_mult": 0.75,
				"insurance_slots": 3,
				"phases": _easy_phases(),
			}


static func _easy_phases() -> Array[Dictionary]:
	return [
		{"id": "lockout", "label": "Lockout", "duration": 90.0, "extract_open": false, "is_last": false},
		{"id": "window_1", "label": "Extract Window 1", "duration": 25.0, "extract_open": true, "is_last": false},
		{"id": "seal_1", "label": "Sealed", "duration": 40.0, "extract_open": false, "is_last": false},
		{"id": "window_2", "label": "Extract Window 2", "duration": 25.0, "extract_open": true, "is_last": false},
		{"id": "final_seal", "label": "Final Seal", "duration": 30.0, "extract_open": false, "is_last": false},
		{"id": "last_extract", "label": "Last Extract", "duration": 35.0, "extract_open": true, "is_last": true},
	]


static func _medium_phases() -> Array[Dictionary]:
	return [
		{"id": "lockout", "label": "Lockout", "duration": 180.0, "extract_open": false, "is_last": false},
		{"id": "window_1", "label": "Extract Window 1", "duration": 50.0, "extract_open": true, "is_last": false},
		{"id": "seal_1", "label": "Sealed", "duration": 80.0, "extract_open": false, "is_last": false},
		{"id": "window_2", "label": "Extract Window 2", "duration": 50.0, "extract_open": true, "is_last": false},
		{"id": "seal_2", "label": "Sealed", "duration": 90.0, "extract_open": false, "is_last": false},
		{"id": "window_3", "label": "Extract Window 3", "duration": 40.0, "extract_open": true, "is_last": false},
		{"id": "final_seal", "label": "Final Seal", "duration": 50.0, "extract_open": false, "is_last": false},
		{"id": "last_extract", "label": "Last Extract", "duration": 50.0, "extract_open": true, "is_last": true},
	]


## Threat Level multipliers (Medium baseline). Mode tl_step_size softens/steepens.
static func tl_table(tl: int) -> Dictionary:
	match clampi(tl, 0, 3):
		0:
			return {"hp": 1.0, "damage": 1.0, "spawn": 1.0, "payout": 1.0}
		1:
			return {"hp": 1.15, "damage": 1.10, "spawn": 1.20, "payout": 1.25}
		2:
			return {"hp": 1.35, "damage": 1.25, "spawn": 1.45, "payout": 1.55}
		_:
			return {"hp": 1.60, "damage": 1.45, "spawn": 1.75, "payout": 2.25}
