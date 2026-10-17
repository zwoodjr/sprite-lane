class_name CharacterDefs
extends RefCounted

const ROOK_ID := "rook_vex"
const CINDER_ID := "sister_cinder"

static func all_characters() -> Array[Dictionary]:
	return [get_character(ROOK_ID), get_character(CINDER_ID)]


static func get_character(char_id: String) -> Dictionary:
	match char_id:
		CINDER_ID:
			return {
				"id": CINDER_ID,
				"display_name": "Sister Cinder",
				"fantasy": "Road sawbones — bandage, tonic, and bolt-gun triage",
				"color": Color(0.85, 0.45, 0.35),
				"accent": Color(0.35, 0.75, 0.55),
				"perks": [
					{"id": "field_draught", "name": "Field Draught", "desc": "Q: self-heal tonic (CD)."},
					{"id": "steady_hands", "name": "Steady Hands", "desc": "After heal: brief fire-rate bump."},
					{"id": "last_stitch", "name": "Last Stitch", "desc": "Once/run: survive a lethal hit at 1 HP."},
				],
				## Simple MVP stat tweaks
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
			}
		_:
			return {
				"id": ROOK_ID,
				"display_name": "Rook Vex",
				"fantasy": "Wasteland scavenger — smells Scrap before the smoke clears",
				"color": Color(0.55, 0.62, 0.45),
				"accent": Color(0.90, 0.72, 0.28),
				"perks": [
					{"id": "pocket_rattle", "name": "Pocket Rattle", "desc": "+rare-drop weight while Stay Bonus ticks."},
					{"id": "strip_stash", "name": "Strip & Stash", "desc": "Slightly faster loot / move when near crates."},
					{"id": "second_glance", "name": "Second Glance", "desc": "Free crate ping each extract window."},
				],
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
			}
