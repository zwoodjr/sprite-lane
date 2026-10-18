class_name LoadoutStubs
extends RefCounted

## Thin architecture stubs so Armor / Weapons / Pets / Mounts match the design.
## Shallow effects only — enough for the MVP vertical slice.

const PetDefs = preload("res://scripts/data/pet_defs.gd")

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


static func default_weapon() -> Dictionary:
	return {
		"id": "scrap_smg",
		"name": "Scrap SMG",
		"category": "SMG",
		"damage": 12,
		"fire_rate": 8.0,
		"spread_deg": 6.0,
		"projectile_speed": 720.0,
		"mag_size": 24,
		"reload_time": 1.4,
		"weapon_xp": 0,
		"weapon_level": 1,
		"attachments": [
			{"id": "muzzle_brake", "name": "Muzzle Brake", "effect": "spread −1°"},
		],
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
