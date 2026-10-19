class_name PowerupDefs
extends RefCounted

## Small rare pool — temporary buffs only (not permanent unlocks).
## Trimmed from a larger set so drops stay meaningful.

const POOL := [
	## Tonic bottles are painted at 96 px (tools/paint_pass.py); sprite_world keeps them 48 px in the world.
	{"id": "speed", "name": "Dust Wake", "duration": 10.0, "color": Color(0.35, 0.75, 0.4), "sprite": "res://assets/sprites/pickups/speed.png", "sprite_world": 48.0},
	{"id": "damage", "name": "Scrap Teeth", "duration": 10.0, "color": Color(0.85, 0.35, 0.25), "sprite": "res://assets/sprites/pickups/damage.png", "sprite_world": 48.0},
	{"id": "shield", "name": "Copper Guard", "duration": 8.0, "color": Color(0.35, 0.55, 0.9), "sprite": "res://assets/sprites/pickups/shield.png", "sprite_world": 48.0},
	{"id": "heal", "name": "Field Draught+", "duration": 0.1, "color": Color(0.3, 0.85, 0.5), "sprite": "res://assets/sprites/pickups/heal.png", "sprite_world": 48.0, "instant_heal": 35.0},
]


static func random_powerup(rng: RandomNumberGenerator = null) -> Dictionary:
	var i: int
	if rng:
		i = rng.randi_range(0, POOL.size() - 1)
	else:
		i = randi() % POOL.size()
	return POOL[i].duplicate(true)


static func get_by_id(id: String) -> Dictionary:
	for p in POOL:
		if p["id"] == id:
			return p.duplicate(true)
	return POOL[0].duplicate(true)
