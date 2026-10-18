class_name LoadoutStubs
extends RefCounted

## Thin architecture stubs so Armor / Weapons / Pets match the design.
## Shallow effects only — enough for the MVP vertical slice.

static func default_armor() -> Dictionary:
	return {
		"set_id": "scrap_sentinel",
		"set_name": "Scrap Sentinel",
		"pieces": {
			"helm": {"name": "Dust Visor", "rarity": "Common", "armor": 4},
			"chest": {"name": "Oilplate Vest", "rarity": "Uncommon", "armor": 10},
			"legs": {"name": "Rivet Greaves", "rarity": "Common", "armor": 6},
		},
		"set_bonus_3": "+2 HP/s out of combat (stub)",
		"flat_armor": 20,
		"regen_oos": 2.0,
	}


## Fallback only — prefer weapon_for_character(selected id).
static func default_weapon() -> Dictionary:
	return weapon_for_character(CharacterDefs.NYX_CALDERA_ID)


## Per-hero kit. Values are intentionally wide so RoF / mag read on-device.
static func weapon_for_character(char_id: String) -> Dictionary:
	var id := char_id
	if id == "rook_vex":
		id = CharacterDefs.ASH_ROOK_ID
	var table := _weapon_table()
	if table.has(id):
		return (table[id] as Dictionary).duplicate(true)
	return (table[CharacterDefs.NYX_CALDERA_ID] as Dictionary).duplicate(true)


static func _weapon_table() -> Dictionary:
	return {
		CharacterDefs.ASH_ROOK_ID: {
			"id": "scrap_boom",
			"name": "Scrap Boom",
			"category": "Launcher",
			"damage": 34,
			"fire_rate": 1.6,
			"spread_deg": 8.0,
			"projectile_speed": 480.0,
			"lifetime": 0.95,
			"mag_size": 5,
			"reload_time": 2.2,
			"splash_radius": 88.0,
			"splash_mult": 0.55,
			"recoil": 10.0,
			"shake": 0.07,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "blast_collar", "name": "Blast Collar", "effect": "splash radius"},
			],
		},
		CharacterDefs.VESPER_THORN_ID: {
			"id": "vial_rifle",
			"name": "Vial Rifle",
			"category": "Sniper",
			"damage": 48,
			"fire_rate": 1.05,
			"spread_deg": 1.2,
			"projectile_speed": 1100.0,
			"lifetime": 1.35,
			"mag_size": 3,
			"reload_time": 2.0,
			"splash_radius": 0.0,
			"recoil": 8.0,
			"shake": 0.06,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "steady_scope", "name": "Steady Scope", "effect": "spread −"},
			],
		},
		CharacterDefs.PEBBLE_ID: {
			"id": "scrap_maul",
			"name": "Scrap Maul",
			"category": "Melee",
			"damage": 30,
			"fire_rate": 2.4,
			"spread_deg": 14.0,
			"projectile_speed": 320.0,
			"lifetime": 0.16,
			"mag_size": 8,
			"reload_time": 1.1,
			"splash_radius": 52.0,
			"splash_mult": 0.4,
			"close_bonus_range": 100.0,
			"close_bonus_mult": 1.4,
			"recoil": 7.0,
			"shake": 0.055,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "heavy_head", "name": "Heavy Head", "effect": "close smash"},
			],
		},
		CharacterDefs.BOLT_JUNO_ID: {
			"id": "chain_gauntlet",
			"name": "Chain Gauntlet",
			"category": "Gauntlet",
			"damage": 11,
			"fire_rate": 3.2,
			"spread_deg": 10.0,
			"projectile_speed": 640.0,
			"lifetime": 0.55,
			"mag_size": 18,
			"reload_time": 1.5,
			"burst_count": 3,
			"burst_gap": 0.055,
			"recoil": 4.0,
			"shake": 0.03,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "flail_links", "name": "Flail Links", "effect": "3-hit chain"},
			],
		},
		CharacterDefs.CINDER_ID: {
			"id": "bayonet_smg",
			"name": "Bayonet SMG",
			"category": "SMG",
			"damage": 7,
			"fire_rate": 13.5,
			"spread_deg": 9.0,
			"projectile_speed": 700.0,
			"lifetime": 0.85,
			"mag_size": 40,
			"reload_time": 1.55,
			"recoil": 3.0,
			"shake": 0.02,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "spray_port", "name": "Spray Port", "effect": "high RoF"},
			],
		},
		CharacterDefs.QUILL_MARROW_ID: {
			"id": "dual_dustblades",
			"name": "Dual Dustblades",
			"category": "Blades",
			"damage": 7,
			"fire_rate": 10.5,
			"spread_deg": 16.0,
			"projectile_speed": 380.0,
			"lifetime": 0.14,
			"mag_size": 28,
			"reload_time": 0.9,
			"pellets": 2,
			"close_bonus_range": 80.0,
			"close_bonus_mult": 1.25,
			"recoil": 2.5,
			"shake": 0.025,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "twin_edge", "name": "Twin Edge", "effect": "dual slash"},
			],
		},
		CharacterDefs.NYX_CALDERA_ID: {
			"id": "suppressor_ar",
			"name": "Suppressor AR",
			"category": "Rifle",
			"damage": 13,
			"fire_rate": 7.5,
			"spread_deg": 4.5,
			"projectile_speed": 780.0,
			"lifetime": 1.0,
			"mag_size": 30,
			"reload_time": 1.6,
			"recoil": 4.5,
			"shake": 0.035,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "muzzle_brake", "name": "Muzzle Brake", "effect": "spread −1°"},
			],
		},
		CharacterDefs.HELM_WISP_ID: {
			"id": "pilot_sidearm",
			"name": "Pilot Sidearm",
			"category": "Pistol",
			"damage": 16,
			"fire_rate": 4.2,
			"spread_deg": 3.5,
			"projectile_speed": 820.0,
			"lifetime": 1.05,
			"mag_size": 10,
			"reload_time": 1.25,
			"drone_assist_interval": 1.8,
			"drone_assist_damage": 8.0,
			"recoil": 5.0,
			"shake": 0.04,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "rig_link", "name": "Rig Link", "effect": "drone assist stub"},
			],
		},
	}


static func default_pet(pet_id: String = "") -> Dictionary:
	var id := pet_id if pet_id != "" else PetDefs.default_id()
	var pet := PetDefs.get_pet(id)
	pet["active"] = true
	return pet

static func available_pets() -> Array[Dictionary]:
	return PetDefs.all_pets()
