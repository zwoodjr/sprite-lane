class_name PetDefs
extends RefCounted

## MVP pet roster. One active pet per run (selected at deploy).

const NOEL_ID := "noel"
const DUST_HOUND_ID := "dust_hound"


static func all_pets() -> Array[Dictionary]:
	return [
		{
			"id": NOEL_ID,
			"name": "Noel",
			"kind": "animal",
			"branch": "Guard",
			"species": "dust terrier",
			"damage": 8,
			"loyalty": 70,
			"active": true,
			"equipable": true,
			"sprite": "res://assets/sprites/pets/noel.png",
			"sprite_rampage": "res://assets/sprites/pets/noel_rampage.png",
			"follow_speed": 280.0,
			"bite_damage": 10.0,
			"bite_range": 42.0,
			"bite_cooldown": 0.55,
			## Territorial Guard: enrage on player-hit until THAT attacker dies.
			"ability_id": "territorial_rampage",
			"ability_name": "Territorial Rampage",
			"ability_desc": "When you take a hit, Noel enrages and AOE-rampages until that attacker dies.",
			"rampage_aoe_radius": 110.0,
			"rampage_aoe_damage": 38.0,
			"rampage_tick": 0.28,
			"rampage_speed_mult": 1.55,
			"note": "Super territorial fluff-mask terrier. MVP signature pet.",
		},
		{
			"id": DUST_HOUND_ID,
			"name": "Dust Hound",
			"kind": "animal",
			"branch": "Hunt",
			"species": "scrap mutt",
			"damage": 6,
			"loyalty": 40,
			"active": true,
			"equipable": true,
			"sprite": "res://assets/sprites/pets/dust_hound.png",
			"sprite_rampage": "res://assets/sprites/pets/dust_hound.png",
			"follow_speed": 250.0,
			"bite_damage": 6.0,
			"bite_range": 38.0,
			"bite_cooldown": 0.7,
			"ability_id": "hunt_assist",
			"ability_name": "Hunt Assist",
			"ability_desc": "Follows and bites nearby hostiles. No enrage kit (MVP filler).",
			"rampage_aoe_radius": 0.0,
			"rampage_aoe_damage": 0.0,
			"rampage_tick": 1.0,
			"rampage_speed_mult": 1.0,
			"note": "MVP Hunt stub — lighter bites, no rampage.",
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
