class_name PetDefs
extends RefCounted

## MVP pet roster. One active pet per run (selected at deploy).
## Style: wasteland sheet (same detail bar as heroes/mobs) — not Noel chibi.
## Roster: Noel · Bentley · Lillie.

const NOEL_ID := "noel"
const BENTLEY_ID := "bentley"
const LILLIE_ID := "lillie"


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


static func default_id() -> String:
	return NOEL_ID
