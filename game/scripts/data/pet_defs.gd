class_name PetDefs
extends RefCounted

## MVP pet roster. One active pet per run (selected at deploy).
## Style: wasteland sheet (same detail bar as heroes/mobs) — not Noel chibi.
## Roster: Noel · Bentley · Lillie.

const NOEL_ID := "noel"
const BENTLEY_ID := "bentley"
const LILLIE_ID := "lillie"
## Depth E6: mech pets, rebuilt from Salvage Cores in the hangar Workshop.
const MECH_IDS: Array = ["mech_hound", "drone_bat", "rust_mule"]


static func all_pets() -> Array[Dictionary]:
	return [
		{
			"id": NOEL_ID,
			"name": "Noel",
			"kind": "animal",
			"branch": "Guard",
			"species": "merle doodle",
			"damage": 8,
			"loyalty": 70,
			"active": true,
			"equipable": true,
			"sprite": "res://assets/sprites/pets/noel/noel_idle.png",
			"anim": "res://assets/sprites/pets/noel/noel",
			"hd": 2.0,
			"follow_speed": 280.0,
			"bite_damage": 10.0,
			"bite_range": 42.0,
			"bite_cooldown": 0.55,
			"ability_id": "territorial_rampage",
			"ability_name": "Territorial Rampage",
			"ability_desc": "When you take a hit, Noel enrages and AOE-rampages until that attacker dies.",
			"rampage_aoe_radius": 110.0,
			"rampage_aoe_damage": 26.0,
			"rampage_tick": 0.32,
			## Kennel: seconds the rampage keeps going after the attacker dies,
			## and how many further attackers it chains to (HangarDefs.KENNEL).
			"rampage_linger": 0.0,
			"rampage_chain": 0,
			"rampage_speed_mult": 1.55,
			"note": "Merle curly doodle — grey/black/white. Super territorial.",
		},
		{
			"id": BENTLEY_ID,
			"name": "Bentley",
			"kind": "animal",
			"branch": "Scout",
			"species": "cream doodle",
			"damage": 5,
			"loyalty": 75,
			"active": true,
			"equipable": true,
			"sprite": "res://assets/sprites/pets/bentley/bentley_idle.png",
			"anim": "res://assets/sprites/pets/bentley/bentley",
			"hd": 2.0,
			"follow_speed": 265.0,
			"bite_damage": 7.0,
			"bite_range": 38.0,
			"bite_cooldown": 0.65,
			"ability_id": "talker_finder",
			"ability_name": "Talker & Finder",
			"ability_desc": "Hyena bark flags and distracts enemies (they take extra damage). Drops random finds at your feet — junk, scrap, or something great.",
			"bark_cooldown": 5.0,
			"bark_radius": 200.0,
			"bark_distract_sec": 1.4,
			"bark_stun": 0.0,
			"bark_mark_mult": 1.15,
			"bark_mark_time": 3.0,
			"find_cooldown": 9.0,
			"find_radius": 520.0,
			## Gift rolls: great (tonic / ammo / big scrap) > good (scrap pile) > junk.
			"gift_good": 0.2,
			"gift_great": 0.04,
			"gift_junk_scrap": Vector2i(1, 2),
			"gift_good_scrap": Vector2i(3, 6),
			"gift_great_scrap": Vector2i(10, 16),
			"note": "Jackal vibe — talker + scavenger.",
		},
		{
			"id": LILLIE_ID,
			"name": "Lillie",
			"kind": "animal",
			"branch": "Guard",
			"species": "ginger parti doodle",
			"damage": 12,
			"loyalty": 80,
			"active": true,
			"equipable": true,
			"sprite": "res://assets/sprites/pets/lillie/lillie_idle.png",
			"anim": "res://assets/sprites/pets/lillie/lillie",
			"hd": 2.0,
			"follow_speed": 240.0,
			"bite_damage": 8.0,
			"bite_range": 40.0,
			"bite_cooldown": 0.8,
			"ability_id": "ram_headbutt",
			"ability_name": "Ram Headbutt",
			"ability_desc": "Charging ram headbutt that stuns and knocks back. Kennel adds a damage trail, then an AoE blast.",
			"ram_cooldown": 6.5,
			"ram_speed": 520.0,
			"ram_range": 280.0,
			"ram_duration": 0.85,
			"ram_wake_damage": 14.0,
			"ram_wake_radius": 42.0,
			"ram_contact_radius": 48.0,
			"ram_impact_damage": 40.0,
			"ram_impact_radius": 95.0,
			"ram_stun": 0.7,
			"ram_knock": 420.0,
			## Kennel rank 2 / 3 (HangarDefs.KENNEL).
			"ram_trail": 0,
			"ram_blast": 0,
			"note": "Tank build — sturdy parti ginger/white.",
		},
		## --- Depth E6 mech pets (kind "mech": must be built in the Workshop first) ---
		{
			"id": "mech_hound",
			"name": "Mech Hound",
			"kind": "mech",
			"branch": "Hunter",
			"species": "rebuilt scrap hound",
			"damage": 10,
			"loyalty": 100,
			"active": true,
			"equipable": true,
			"sprite": "res://assets/sprites/pets/mech_hound/mech_hound_idle.png",
			"anim": "res://assets/sprites/pets/mech_hound/mech_hound",
			"frame_world": 66.0,
			"build_cores": 4,
			"build_scrap": 300,
			"follow_speed": 290.0,
			"bite_damage": 9.0,
			"bite_range": 42.0,
			"bite_cooldown": 0.6,
			"ability_id": "shock_pounce",
			"ability_name": "Shock Pounce",
			"ability_desc": "Pounces on a foe; the impact arcs shock to nearby enemies (machines take extra).",
			"ram_cooldown": 5.0,
			"ram_speed": 640.0,
			"ram_range": 260.0,
			"ram_duration": 0.55,
			"ram_contact_radius": 46.0,
			"ram_impact_damage": 30.0,
			"ram_stun": 0.45,
			"ram_knock": 220.0,
			"shock_chain": 2,
			"shock_damage": 16.0,
			"shock_range": 150.0,
			"note": "A scrap hound Helm pulled out of the dust and rewired to heel.",
		},
		{
			"id": "drone_bat",
			"name": "Drone Bat",
			"kind": "mech",
			"branch": "Scout",
			"species": "rotor-wing drone",
			"damage": 6,
			"loyalty": 100,
			"active": true,
			"equipable": true,
			"flying": true,
			"sprite": "res://assets/sprites/pets/drone_bat/drone_bat_idle.png",
			"anim": "res://assets/sprites/pets/drone_bat/drone_bat",
			"frame_world": 60.0,
			"build_cores": 5,
			"build_scrap": 350,
			"follow_speed": 320.0,
			"bite_damage": 5.0,
			"bite_range": 44.0,
			"bite_cooldown": 0.7,
			"ability_id": "strafe_run",
			"ability_name": "Strafe Run",
			"ability_desc": "Flies over walls; every few seconds it strafes the nearest enemies and marks them (+15% damage taken).",
			"strafe_cooldown": 4.5,
			"strafe_range": 320.0,
			"strafe_shots": 4,
			"strafe_damage": 7.0,
			"strafe_mark_mult": 1.15,
			"strafe_mark_time": 3.0,
			"note": "A gutted rad-bat frame with a rotor heart. Sees over everything.",
		},
		{
			"id": "rust_mule",
			"name": "Rust Mule",
			"kind": "mech",
			"branch": "Hauler",
			"species": "rebuilt iron horse",
			"damage": 12,
			"loyalty": 100,
			"active": true,
			"equipable": true,
			"sprite": "res://assets/sprites/pets/rust_mule/rust_mule_idle.png",
			"anim": "res://assets/sprites/pets/rust_mule/rust_mule",
			"frame_world": 78.0,
			"build_cores": 6,
			"build_scrap": 450,
			"follow_speed": 235.0,
			"bite_damage": 10.0,
			"bite_range": 46.0,
			"bite_cooldown": 0.9,
			"ability_id": "mortar_back",
			"ability_name": "Mortar Back",
			"ability_desc": "Carries +2 backpack room and lobs a mortar shell at the thickest crowd every few seconds.",
			"pack_bonus": 2,
			"mortar_cooldown": 7.0,
			"mortar_range": 380.0,
			"mortar_radius": 90.0,
			"mortar_damage": 34.0,
			"mortar_delay": 0.7,
			"note": "An iron horse with its furnace swapped for a mortar and a pack frame.",
		},
	]


static func get_pet(id: String) -> Dictionary:
	for p in all_pets():
		if str(p["id"]) == id:
			return p.duplicate(true)
	return all_pets()[0].duplicate(true)


static func is_equipable(id: String) -> bool:
	for p in all_pets():
		if str(p["id"]) == id:
			return bool(p.get("equipable", false))
	return false


static func is_mech(id: String) -> bool:
	return id in MECH_IDS


static func default_id() -> String:
	return NOEL_ID
