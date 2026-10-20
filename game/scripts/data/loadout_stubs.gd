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


## Weapon data. Combat reads:
##   trigger_range — world px; the hero only attacks when the closest on-screen
##                   enemy is inside it (10% hysteresis keeps the current target)
##   muzzle        — projectile spawn offset from the hero centre, facing right
##                   (x is mirrored with facing). Later replaced by weapon-tip JSON.
##   projectile    — bullet look: rocket / slug / tracer / smg / pistol
##   melee         — {shape: arc|line, ...}: swing instead of shooting; damage is
##                   applied once per swing at the impact moment (windup seconds).
##                   Melee survival kit: lifesteal (fraction of damage dealt healed),
##                   resist (damage taken ×), guard_on_hit (seconds of half damage
##                   after a swing lands). A dash ends with the swing ready
##                   (dash-cancel into swing).
static func _weapon_table() -> Dictionary:
	return {
		CharacterDefs.ASH_ROOK_ID: {
			"id": "scrap_boom",
			"name": "Scrap Boom",
			"category": "Launcher",
			"damage": 34,
			"fire_rate": 1.6,
			"spread_deg": 3.0,
			"projectile_speed": 520.0,
			"lifetime": 0.95,
			"mag_size": 5,
			"reload_time": 2.2,
			"splash_radius": 72.0,
			"splash_mult": 0.55,
			"trigger_range": 380.0,
			"muzzle": Vector2(24, -10),
			"projectile": "rocket",
			"recoil": 10.0,
			"bullet_knock": 120.0,
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
			"spread_deg": 0.6,
			"projectile_speed": 1150.0,
			"lifetime": 0.6,
			"mag_size": 3,
			"reload_time": 2.0,
			"splash_radius": 0.0,
			"trigger_range": 470.0,
			"muzzle": Vector2(24, 6),
			"projectile": "slug",
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
			"damage": 36,
			"fire_rate": 1.25,
			"mag_size": 0,
			"reload_time": 0.0,
			"trigger_range": 70.0,
			"muzzle": Vector2(14, -4),
			"melee": {
				"shape": "arc", "arc_deg": 140.0, "radius": 80.0,
				"windup": 0.16, "knockback": 420.0, "shake": 0.14,
				"lifesteal": 0.10, "resist": 0.75, "guard_on_hit": 0.5,
				"smear": Color(1.0, 0.85, 0.7),
			},
			"recoil": 0.0,
			"shake": 0.0,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "heavy_head", "name": "Heavy Head", "effect": "wide smash"},
			],
		},
		CharacterDefs.BOLT_JUNO_ID: {
			"id": "chain_gauntlet",
			"name": "Chain Gauntlet",
			"category": "Gauntlet",
			"damage": 19,
			"fire_rate": 2.2,
			"mag_size": 0,
			"reload_time": 0.0,
			"trigger_range": 150.0,
			"muzzle": Vector2(14, 0),
			"melee": {
				"shape": "line", "length": 140.0, "width": 34.0,
				"windup": 0.1, "knockback": 240.0, "shake": 0.05,
				"lifesteal": 0.06, "resist": 0.85, "guard_on_hit": 0.3,
				"smear": Color(1.0, 0.55, 0.4),
			},
			"recoil": 0.0,
			"shake": 0.0,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "flail_links", "name": "Flail Links", "effect": "long lash"},
			],
		},
		CharacterDefs.QUILL_MARROW_ID: {
			## New art: Quill fights with a bayonet knife (no gun in the strips),
			## so the weapon is a fast forward stab-slash instead of the old SMG.
			"id": "bayonet_knife",
			"name": "Bayonet Knife",
			"category": "Melee",
			"damage": 15,
			"fire_rate": 2.8,
			"mag_size": 0,
			"reload_time": 0.0,
			"trigger_range": 75.0,
			"muzzle": Vector2(16, 2),
			"melee": {
				"shape": "arc", "arc_deg": 100.0, "radius": 72.0,
				"windup": 0.08, "knockback": 50.0, "shake": 0.03,
				"lifesteal": 0.10, "resist": 0.8, "guard_on_hit": 0.35,
				"smear": Color(0.95, 0.9, 0.8),
			},
			"recoil": 0.0,
			"shake": 0.0,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "spray_port", "name": "Long Lug", "effect": "wider slash"},
			],
		},
		CharacterDefs.NYX_CALDERA_ID: {
			"id": "dual_dustblades",
			"name": "Dual Dustblades",
			"category": "Blades",
			"damage": 12,
			"fire_rate": 4.0,
			"mag_size": 0,
			"reload_time": 0.0,
			"trigger_range": 70.0,
			"muzzle": Vector2(12, 0),
			"melee": {
				"shape": "arc", "arc_deg": 100.0, "radius": 72.0,
				"windup": 0.05, "knockback": 25.0, "shake": 0.0,
				"lifesteal": 0.12, "resist": 0.8, "guard_on_hit": 0.35,
				"alternate_deg": 22.0,
				"smear": Color(0.75, 0.9, 1.0),
			},
			"recoil": 0.0,
			"shake": 0.0,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "twin_edge", "name": "Twin Edge", "effect": "alternating slashes"},
			],
		},
		CharacterDefs.CINDER_ID: {
			"id": "suppressor_ar",
			"name": "Suppressor AR",
			"category": "Rifle",
			"damage": 12,
			"fire_rate": 7.5,
			"spread_deg": 3.5,
			"projectile_speed": 860.0,
			"lifetime": 0.6,
			"mag_size": 30,
			"reload_time": 1.6,
			"trigger_range": 400.0,
			"muzzle": Vector2(18, -14),
			"projectile": "tracer",
			"recoil": 4.5,
			"shake": 0.03,
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
			"spread_deg": 2.5,
			"projectile_speed": 880.0,
			"lifetime": 0.6,
			"mag_size": 10,
			"reload_time": 1.25,
			"trigger_range": 420.0,
			"muzzle": Vector2(17, -10),
			"projectile": "pistol",
			## Helm's drones (count grows with the Extra Drone run pick; max 4).
			"drone_count": 1,
			"drone_max": 4,
			"drone_range": 380.0,
			"drone_interval": 0.9,
			"drone_damage": 8.0,
			"recoil": 5.0,
			"shake": 0.04,
			"weapon_xp": 0,
			"weapon_level": 1,
			"attachments": [
				{"id": "rig_link", "name": "Rig Link", "effect": "drone link"},
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
