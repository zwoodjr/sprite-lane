class_name CharacterDefs
extends RefCounted

## Data-driven character table. MVP playable = Rook + Cinder only.
## Future roster IDs are stubbed (locked) so adding a character is mostly data.

const ROOK_ID := "rook_vex"
const CINDER_ID := "sister_cinder"

## Playable in MVP character select.
const PLAYABLE_IDS: Array[String] = [ROOK_ID, CINDER_ID]

## Long-term roster stubs (≥10). Unique abilities + specialized gear unlocks TBD in design.
## Do not expose locked entries in UI until implemented.
const FUTURE_IDS: Array[String] = [
	"ash_kestrel",
	"quill_marrow",
	"iron_brig",
	"salt_widow",
	"glow_wick",
	"tinker_mole",
	"red_circuit",
	"dust_oracle",
]


static func all_characters() -> Array[Dictionary]:
	## MVP select list only.
	var out: Array[Dictionary] = []
	for id in PLAYABLE_IDS:
		out.append(get_character(id))
	return out


static func all_known_ids() -> Array[String]:
	var out: Array[String] = []
	out.append_array(PLAYABLE_IDS)
	out.append_array(FUTURE_IDS)
	return out


static func is_playable(char_id: String) -> bool:
	return char_id in PLAYABLE_IDS


static func get_character(char_id: String) -> Dictionary:
	var table := _table()
	if table.has(char_id):
		return (table[char_id] as Dictionary).duplicate(true)
	## Fallback Rook
	return (table[ROOK_ID] as Dictionary).duplicate(true)


static func _table() -> Dictionary:
	return {
		ROOK_ID: {
			"id": ROOK_ID,
			"display_name": "Rook Vex",
			"fantasy": "Wasteland scavenger — smells Scrap before the smoke clears",
			"playable": true,
			"sprite": "res://assets/sprites/characters/rook_vex.png",
			"color": Color(0.55, 0.62, 0.45),
			"accent": Color(0.90, 0.72, 0.28),
			"perks": [
				{"id": "pocket_rattle", "name": "Pocket Rattle", "desc": "+rare-drop weight while Stay Bonus ticks."},
				{"id": "strip_stash", "name": "Strip & Stash", "desc": "Slightly faster loot / move when near crates."},
				{"id": "second_glance", "name": "Second Glance", "desc": "Free crate ping each extract window."},
			],
			"equipment_unlocks": [], ## specialized gear hooks later
			"move_speed_mult": 1.06,
			"max_hp_bonus": 0,
			"damage_mult": 1.05,
			"heal_amount": 0,
			"heal_cd": 999.0,
			"post_heal_firerate_mult": 1.0,
			"post_heal_duration": 0.0,
			"has_last_stitch": false,
			"loot_weight_bonus": 0.15,
			"interact_speed_mult": 1.2,
		},
		CINDER_ID: {
			"id": CINDER_ID,
			"display_name": "Sister Cinder",
			"fantasy": "Road sawbones — bandage, tonic, and bolt-gun triage",
			"playable": true,
			"sprite": "res://assets/sprites/characters/sister_cinder.png",
			"color": Color(0.85, 0.45, 0.35),
			"accent": Color(0.35, 0.75, 0.55),
			"perks": [
				{"id": "field_draught", "name": "Field Draught", "desc": "Q: self-heal tonic (CD)."},
				{"id": "steady_hands", "name": "Steady Hands", "desc": "After heal: brief fire-rate bump."},
				{"id": "last_stitch", "name": "Last Stitch", "desc": "Once/run: survive a lethal hit at 1 HP."},
			],
			"equipment_unlocks": [],
			"move_speed_mult": 0.98,
			"max_hp_bonus": 15,
			"damage_mult": 0.95,
			"heal_amount": 28,
			"heal_cd": 12.0,
			"post_heal_firerate_mult": 1.25,
			"post_heal_duration": 3.0,
			"has_last_stitch": true,
			"loot_weight_bonus": 0.0,
			"interact_speed_mult": 1.0,
		},
		## --- Locked stubs (not in select UI) ---
		"ash_kestrel": _stub("ash_kestrel", "Ash Kestrel", "Outrider — convoy ghost"),
		"quill_marrow": _stub("quill_marrow", "Quill Marrow", "Alchemist-gunner"),
		"iron_brig": _stub("iron_brig", "Iron Brig", "Scrap bulwark"),
		"salt_widow": _stub("salt_widow", "Salt Widow", "Long-range dust sniper"),
		"glow_wick": _stub("glow_wick", "Glow Wick", "Lantern mystic"),
		"tinker_mole": _stub("tinker_mole", "Tinker Mole", "Trapwright"),
		"red_circuit": _stub("red_circuit", "Red Circuit", "Jury-rigged drone caller"),
		"dust_oracle": _stub("dust_oracle", "Dust Oracle", "Threat-reader"),
	}


static func _stub(id: String, name: String, fantasy: String) -> Dictionary:
	return {
		"id": id,
		"display_name": name,
		"fantasy": fantasy,
		"playable": false,
		"sprite": "res://assets/sprites/characters/rook_vex.png",
		"color": Color(0.5, 0.5, 0.5),
		"accent": Color(0.7, 0.7, 0.7),
		"perks": [],
		"equipment_unlocks": [],
		"move_speed_mult": 1.0,
		"max_hp_bonus": 0,
		"damage_mult": 1.0,
		"heal_amount": 0,
		"heal_cd": 999.0,
		"post_heal_firerate_mult": 1.0,
		"post_heal_duration": 0.0,
		"has_last_stitch": false,
		"loot_weight_bonus": 0.0,
		"interact_speed_mult": 1.0,
		"locked": true,
	}
