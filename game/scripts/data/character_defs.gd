class_name CharacterDefs
extends RefCounted

## Sheet-look roster (locked crops) with Wanderer names.
## Source: wasteland-select-white-bg.jpg slots 1–8.

const ASH_ROOK_ID := "ash_rook"
const VESPER_THORN_ID := "vesper_thorn"
const PEBBLE_ID := "pebble"
const BOLT_JUNO_ID := "bolt_juno"
const CINDER_ID := "sister_cinder"
const QUILL_MARROW_ID := "quill_marrow"
const NYX_CALDERA_ID := "nyx_caldera"
const HELM_WISP_ID := "helm_wisp"

## Legacy alias — old saves / scripts that still say rook_vex.
const ROOK_ID := ASH_ROOK_ID

const PLAYABLE_IDS: Array[String] = [
	ASH_ROOK_ID,
	VESPER_THORN_ID,
	PEBBLE_ID,
	BOLT_JUNO_ID,
	CINDER_ID,
	QUILL_MARROW_ID,
	NYX_CALDERA_ID,
	HELM_WISP_ID,
]

## Deprecated stubs kept so old profile keys resolve without crashing.
const FUTURE_IDS: Array[String] = []


static func all_characters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in PLAYABLE_IDS:
		out.append(get_character(id))
	return out


static func all_known_ids() -> Array[String]:
	return PLAYABLE_IDS.duplicate()


static func is_playable(char_id: String) -> bool:
	var id := _canonicalize(char_id)
	return id in PLAYABLE_IDS


static func get_character(char_id: String) -> Dictionary:
	var id := _canonicalize(char_id)
	var table := _table()
	if table.has(id):
		return (table[id] as Dictionary).duplicate(true)
	return (table[ASH_ROOK_ID] as Dictionary).duplicate(true)


## Bottle-cap ability button art per hero (HD pack ui/btn_ability_*.png).
const ABILITY_ICONS := {
	ASH_ROOK_ID: "rook_rush",
	VESPER_THORN_ID: "vesper_vial_shot",
	PEBBLE_ID: "pebble_maul_slam",
	BOLT_JUNO_ID: "juno_overload",
	CINDER_ID: "cinder_heal",
	QUILL_MARROW_ID: "quill_dissect",
	NYX_CALDERA_ID: "nyx_blade_rush",
	HELM_WISP_ID: "helm_drone",
}


static func ability_icon_path(char_id: String) -> String:
	var id := _canonicalize(char_id)
	return "res://assets/sprites/ui/btn_ability_%s.png" % str(ABILITY_ICONS.get(id, "rook_rush"))


static func _canonicalize(char_id: String) -> String:
	if char_id == "rook_vex":
		return ASH_ROOK_ID
	return char_id


static func _table() -> Dictionary:
	return {
		ASH_ROOK_ID: {
			"id": ASH_ROOK_ID,
			"display_name": "Ash Rook",
			"fantasy": "Heavy ordnance scavenger — scrap boom, long wind-up",
			"playable": true,
			"sprite": "res://assets/sprites/characters/ash_rook/ash_rook.png",
			"anim": "res://assets/sprites/characters/ash_rook/ash_rook",
			"color": Color(0.75, 0.35, 0.28),
			"accent": Color(0.95, 0.55, 0.25),
			"perks": [
				{"id": "scrap_boom", "name": "Scrap Boom", "desc": "Launcher hits splash a little harder."},
				{"id": "pocket_rattle", "name": "Pocket Rattle", "desc": "+rare-drop weight while Stay Bonus ticks."},
				{"id": "second_glance", "name": "Second Glance", "desc": "Free crate ping each extract window."},
			],
			"equipment_unlocks": [],
			"ability": {
				"id": "rattle_rush", "name": "Rattle Rush", "short": "RUSH",
				"desc": "3s sprint burst + pings every crate within 90m.",
				"cooldown": 14.0, "duration": 3.0, "speed_mult": 1.45,
			},
			"move_speed_mult": 0.96,
			"max_hp_bonus": 10,
			"damage_mult": 1.12,
			"heal_amount": 0,
			"heal_cd": 999.0,
			"post_heal_firerate_mult": 1.0,
			"post_heal_duration": 0.0,
			"has_last_stitch": false,
			"loot_weight_bonus": 0.15,
			"interact_speed_mult": 1.15,
		},
		VESPER_THORN_ID: {
			"id": VESPER_THORN_ID,
			"display_name": "Vesper Thorn",
			"fantasy": "Dust-apothecary marksman — coated rounds from the belt vials",
			"playable": true,
			"sprite": "res://assets/sprites/characters/vesper_thorn/vesper_thorn.png",
			"anim": "res://assets/sprites/characters/vesper_thorn/vesper_thorn",
			"color": Color(0.55, 0.35, 0.70),
			"accent": Color(0.70, 0.45, 0.90),
			"perks": [
				{"id": "coated_rounds", "name": "Coated Rounds", "desc": "Shots apply a light DoT tick."},
				{"id": "steady_scope", "name": "Steady Scope", "desc": "Slightly longer effective range."},
			],
			"equipment_unlocks": [],
			"ability": {
				"id": "vial_shot", "name": "Vial Shot", "short": "COAT",
				"desc": "Next magazine deals bonus toxin damage for 4s.",
				"cooldown": 13.0, "duration": 4.0, "damage_mult": 1.35,
			},
			"move_speed_mult": 1.0,
			"max_hp_bonus": 0,
			"damage_mult": 1.08,
			"heal_amount": 0,
			"heal_cd": 999.0,
			"post_heal_firerate_mult": 1.0,
			"post_heal_duration": 0.0,
			"has_last_stitch": false,
			"loot_weight_bonus": 0.05,
			"interact_speed_mult": 1.0,
		},
		PEBBLE_ID: {
			"id": PEBBLE_ID,
			"display_name": "Pebble",
			"fantasy": "Small frame, oversized scrap hammer — crack the line",
			"playable": true,
			"sprite": "res://assets/sprites/characters/pebble/pebble.png",
			"anim": "res://assets/sprites/characters/pebble/pebble",
			"color": Color(0.85, 0.80, 0.75),
			"accent": Color(0.95, 0.45, 0.55),
			"perks": [
				{"id": "heavy_swing", "name": "Heavy Swing", "desc": "Melee-range shots hit harder."},
				{"id": "low_profile", "name": "Low Profile", "desc": "Slightly smaller hitbox feel (speed on)."},
			],
			"equipment_unlocks": [],
			"ability": {
				"id": "maul_slam", "name": "Maul Slam", "short": "SLAM",
				"desc": "Dash forward and smash — burst damage nearby foes.",
				"cooldown": 11.0, "duration": 0.6, "speed_mult": 1.6,
			},
			"move_speed_mult": 1.08,
			"max_hp_bonus": 5,
			"damage_mult": 1.15,
			"heal_amount": 0,
			"heal_cd": 999.0,
			"post_heal_firerate_mult": 1.0,
			"post_heal_duration": 0.0,
			"has_last_stitch": false,
			"loot_weight_bonus": 0.0,
			"interact_speed_mult": 1.05,
		},
		BOLT_JUNO_ID: {
			"id": BOLT_JUNO_ID,
			"display_name": "Bolt Juno",
			"fantasy": "Boosted scrap-fist + flail pull — yank, then punch",
			"playable": true,
			"sprite": "res://assets/sprites/characters/bolt_juno/bolt_juno.png",
			"anim": "res://assets/sprites/characters/bolt_juno/bolt_juno",
			"color": Color(0.80, 0.25, 0.22),
			"accent": Color(0.95, 0.40, 0.30),
			"perks": [
				{"id": "chain_pull", "name": "Chain Pull", "desc": "Abilities drag foes slightly closer."},
				{"id": "gauntlet", "name": "Gauntlet", "desc": "+armor feel via extra HP."},
			],
			"equipment_unlocks": [],
			"ability": {
				"id": "flail_yank", "name": "Flail Yank", "short": "YANK",
				"desc": "Pull nearest foe and punch — brief damage spike.",
				"cooldown": 12.0, "duration": 1.2, "damage_mult": 1.4,
			},
			"move_speed_mult": 1.02,
			"max_hp_bonus": 20,
			"damage_mult": 1.05,
			"heal_amount": 0,
			"heal_cd": 999.0,
			"post_heal_firerate_mult": 1.0,
			"post_heal_duration": 0.0,
			"has_last_stitch": false,
			"loot_weight_bonus": 0.0,
			"interact_speed_mult": 1.0,
		},
		CINDER_ID: {
			"id": CINDER_ID,
			"display_name": "Sister Cinder",
			"fantasy": "Field medic — medkit + suppressor rifle",
			"playable": true,
			"sprite": "res://assets/sprites/characters/sister_cinder/sister_cinder.png",
			"anim": "res://assets/sprites/characters/sister_cinder/sister_cinder",
			"color": Color(0.85, 0.45, 0.35),
			"accent": Color(0.35, 0.75, 0.55),
			"perks": [
				{"id": "field_draught", "name": "Field Draught", "desc": "Q: self-heal tonic (CD)."},
				{"id": "steady_hands", "name": "Steady Hands", "desc": "After heal: brief fire-rate bump."},
				{"id": "last_stitch", "name": "Last Stitch", "desc": "Once/run: survive a lethal hit at 1 HP."},
			],
			"equipment_unlocks": [],
			"ability": {
				"id": "field_draught", "name": "Field Draught", "short": "HEAL",
				"desc": "Drink a tonic: +28 HP, then fire 25% faster for 3s.",
				"cooldown": 12.0, "heal": 28.0,
			},
			"move_speed_mult": 0.98,
			"max_hp_bonus": 15,
			"damage_mult": 0.95,
			"heal_amount": 28,
			"heal_cd": 12.0,
			"post_heal_firerate_mult": 1.25,
			"post_heal_duration": 3.0,
			"has_last_stitch": true,
			## Brace Plate Hangar ranks apply at full strength for sawbones kits.
			"block_affinity": true,
			"loot_weight_bonus": 0.0,
			"interact_speed_mult": 1.0,
		},
		QUILL_MARROW_ID: {
			"id": QUILL_MARROW_ID,
			"display_name": "Quill Marrow",
			"fantasy": "Dustcoat cutthroat — bayonet knife, carve through the pack",
			"playable": true,
			"sprite": "res://assets/sprites/characters/quill_marrow/quill_marrow.png",
			"anim": "res://assets/sprites/characters/quill_marrow/quill_marrow",
			"color": Color(0.55, 0.42, 0.28),
			"accent": Color(0.90, 0.78, 0.40),
			"perks": [
				{"id": "suppress", "name": "Suppress", "desc": "Sustained fire slows nearby foes slightly."},
				{"id": "advance", "name": "Advance", "desc": "Moving while shooting loses less accuracy feel."},
			],
			"equipment_unlocks": [],
			"ability": {
				"id": "suppressing_fire", "name": "Suppressing Fire", "short": "SUPP",
				"desc": "5s fire-rate surge — lock the lane down.",
				"cooldown": 14.0, "duration": 5.0,
			},
			"move_speed_mult": 1.1,
			"max_hp_bonus": 0,
			"damage_mult": 1.1,
			"heal_amount": 0,
			"heal_cd": 999.0,
			"post_heal_firerate_mult": 1.0,
			"post_heal_duration": 0.0,
			"has_last_stitch": false,
			"loot_weight_bonus": 0.0,
			"interact_speed_mult": 1.0,
		},
		NYX_CALDERA_ID: {
			"id": NYX_CALDERA_ID,
			"display_name": "Nyx Caldera",
			"fantasy": "Twin dustblades — dance in close and carve",
			"playable": true,
			"sprite": "res://assets/sprites/characters/nyx_caldera/nyx_caldera.png",
			"anim": "res://assets/sprites/characters/nyx_caldera/nyx_caldera",
			"color": Color(0.30, 0.45, 0.75),
			"accent": Color(0.45, 0.65, 0.95),
			"perks": [
				{"id": "slash_dash", "name": "Slash Dash", "desc": "Dash leaves a brief damage trail."},
				{"id": "dustcoat", "name": "Dustcoat", "desc": "Slightly faster move."},
			],
			"equipment_unlocks": [],
			"ability": {
				"id": "blade_rush", "name": "Blade Rush", "short": "SLASH",
				"desc": "Dash through foes, damaging what you pass.",
				"cooldown": 10.0, "duration": 0.55, "speed_mult": 1.85,
			},
			"move_speed_mult": 0.97,
			"max_hp_bonus": 8,
			"damage_mult": 1.1,
			"heal_amount": 0,
			"heal_cd": 999.0,
			"post_heal_firerate_mult": 1.0,
			"post_heal_duration": 0.0,
			"has_last_stitch": false,
			"loot_weight_bonus": 0.0,
			"interact_speed_mult": 1.0,
		},
		HELM_WISP_ID: {
			"id": HELM_WISP_ID,
			"display_name": "Helm Wisp",
			"fantasy": "Pilot-rig drone assist + sidearm",
			"playable": true,
			"sprite": "res://assets/sprites/characters/helm_wisp/helm_wisp.png",
			"anim": "res://assets/sprites/characters/helm_wisp/helm_wisp",
			"color": Color(0.40, 0.55, 0.40),
			"accent": Color(0.55, 0.85, 0.55),
			"perks": [
				{"id": "drone_spot", "name": "Drone Spot", "desc": "Periodically reveals nearest crate."},
				{"id": "sidearm", "name": "Sidearm", "desc": "Slight fire-rate bump."},
			],
			"equipment_unlocks": [],
			"ability": {
				"id": "rig_assist", "name": "Rig Assist", "short": "DRONE",
				"desc": "Call a brief drone buff: +move and +fire rate for 4s.",
				"cooldown": 13.0, "duration": 4.0, "speed_mult": 1.25,
			},
			"move_speed_mult": 1.04,
			"max_hp_bonus": 0,
			"damage_mult": 1.0,
			"heal_amount": 0,
			"heal_cd": 999.0,
			"post_heal_firerate_mult": 1.0,
			"post_heal_duration": 0.0,
			"has_last_stitch": false,
			"loot_weight_bonus": 0.08,
			"interact_speed_mult": 1.1,
		},
	}
