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
			"sprite": "res://assets/sprites/pets/noel.png",
			"sprite_accent": "res://assets/sprites/pets/noel_rampage.png",
			"follow_speed": 280.0,
			## Rebalance: Noel was clearly strongest — trim AOE, keep identity.
			"bite_damage": 8.0,
			"bite_range": 40.0,
			"bite_cooldown": 0.6,
			"ability_id": "territorial_rampage",
			"ability_name": "Territorial Rampage",
			"ability_desc": "When you take a hit, Noel enrages and AOE-rampages until that attacker dies.",
			"rampage_aoe_radius": 95.0,
			"rampage_aoe_damage": 28.0,
			"rampage_tick": 0.34,
			"rampage_speed_mult": 1.4,
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
			"sprite": "res://assets/sprites/pets/bentley.png",
			"sprite_accent": "res://assets/sprites/pets/bentley_alert.png",
			"follow_speed": 265.0,
			## Rebalance: Bentley was weakest — faster bark, longer reach, better finds.
			"bite_damage": 7.0,
			"bite_range": 38.0,
			"bite_cooldown": 0.65,
			"ability_id": "talker_finder",
			"ability_name": "Talker & Finder",
			"ability_desc": "Bark distracts nearby hostiles. Periodically pings crates and pulls pickups/scrap toward you.",
			"bark_cooldown": 4.2,
			"bark_radius": 230.0,
			"bark_distract_sec": 1.8,
			"find_cooldown": 5.5,
			"find_radius": 620.0,
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
			"sprite": "res://assets/sprites/pets/lillie.png",
			"sprite_accent": "res://assets/sprites/pets/lillie_charge.png",
			"follow_speed": 240.0,
			"bite_damage": 8.0,
			"bite_range": 40.0,
			"bite_cooldown": 0.8,
			"ability_id": "ram_headbutt",
			"ability_name": "Ram Headbutt",
			"ability_desc": "Charges a foe — damages enemies in the wake, then detonates AOE on impact.",
			"ram_cooldown": 6.5,
			"ram_speed": 520.0,
			"ram_range": 280.0,
			"ram_duration": 0.85,
			"ram_wake_damage": 14.0,
			"ram_wake_radius": 42.0,
			"ram_contact_radius": 48.0,
			"ram_impact_damage": 42.0,
			"ram_impact_radius": 95.0,
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
