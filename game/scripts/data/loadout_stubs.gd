class_name LoadoutStubs
extends RefCounted

## Thin architecture stubs so Armor / Weapons / Pets / Mounts match the design.
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
			## Part 7: Sister Cinder locks to rifle ("Censer" legendary).
			"id": "apothecary_rifle",
			"name": "Apothecary Rifle",
			"category": "Rifle",
			"damage": 12,
			"fire_rate": 6.5,
			"spread_deg": 5.0,
			"projectile_speed": 760.0,
			"lifetime": 1.0,
			"mag_size": 24,
			"reload_time": 1.65,
			"recoil": 4.0,
			"shake": 0.03,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "censer_chamber", "name": "Censer Chamber", "effect": "heal smoke stub"},
			],
		},
		CharacterDefs.QUILL_MARROW_ID: {
			## Part 7: Quill locks to bayonet SMG.
			"id": "bayonet_smg",
			"name": "Bayonet SMG",
			"category": "SMG",
			"damage": 8,
			"fire_rate": 12.0,
			"spread_deg": 8.0,
			"projectile_speed": 700.0,
			"lifetime": 0.85,
			"mag_size": 36,
			"reload_time": 1.45,
			"close_bonus_range": 70.0,
			"close_bonus_mult": 1.35,
			"recoil": 3.0,
			"shake": 0.02,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "field_notes", "name": "Field Notes", "effect": "weak-spot stub"},
			],
		},
		CharacterDefs.NYX_CALDERA_ID: {
			## Part 7: Nyx locks to twin blades.
			"id": "twin_debts_blades",
			"name": "Twin Blades",
			"category": "Blades",
			"damage": 9,
			"fire_rate": 11.0,
			"spread_deg": 14.0,
			"projectile_speed": 400.0,
			"lifetime": 0.14,
			"mag_size": 30,
			"reload_time": 0.85,
			"pellets": 2,
			"close_bonus_range": 85.0,
			"close_bonus_mult": 1.3,
			"recoil": 2.5,
			"shake": 0.025,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "smuggler_edge", "name": "Smuggler Edge", "effect": "backstab stub"},
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

static func default_mount(unlocked_tier: int = 0) -> Dictionary:
	var ladder := mount_ladder()
	var tier: int = clampi(unlocked_tier, 0, ladder.size() - 1)
	var mount: Dictionary = ladder[tier].duplicate(true)
	mount["unlocked_tier"] = unlocked_tier
	mount["mounted"] = false
	return mount

static func mount_ladder() -> Array[Dictionary]:
	return [
		{
			"tier": 0,
			"id": "skateboard",
			"name": "Skateboard",
			"speed_mult": 1.45,
			"fuel": 100.0,
			"fuel_burn": 4.0,
			"durability": 40,
			"usable": true,
			"unlock": "Survive first lockout once",
		},
		{
			"tier": 1,
			"id": "scooter",
			"name": "Scooter",
			"speed_mult": 1.7,
			"fuel": 120.0,
			"fuel_burn": 5.0,
			"durability": 55,
			"usable": false,
			"unlock": "3 successful extracts (stub — locked)",
		},
		{
			"tier": 2,
			"id": "dirt_bike",
			"name": "Dirt Bike",
			"speed_mult": 2.0,
			"fuel": 140.0,
			"fuel_burn": 7.0,
			"durability": 70,
			"usable": false,
			"unlock": "Scooter mastery + landmark clears (stub — locked)",
		},
	]

## Tank is not for players — kept behind unused flag only.
static func tank_entry() -> Dictionary:
	return {
		"id": "tank",
		"name": "Tank",
		"mythic_locked": true,
		"dev_only": true,
		"note": "Developer / owner flag only. Player ladder ends at APC (later).",
	}
