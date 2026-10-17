class_name PowerupDefs
extends RefCounted

## Temporary buff pool — timed, not permanent unlocks.

const POOL := [
	{"id": "speed", "name": "Dust Wake", "duration": 12.0, "color": Color(0.35, 0.75, 0.4), "sprite": "res://assets/sprites/pickups/speed.png"},
	{"id": "damage", "name": "Scrap Teeth", "duration": 12.0, "color": Color(0.85, 0.35, 0.25), "sprite": "res://assets/sprites/pickups/damage.png"},
	{"id": "rapid", "name": "Hot Bolt", "duration": 10.0, "color": Color(0.9, 0.7, 0.25), "sprite": "res://assets/sprites/pickups/rapid.png"},
	{"id": "shield", "name": "Copper Guard", "duration": 10.0, "color": Color(0.35, 0.55, 0.9), "sprite": "res://assets/sprites/pickups/shield.png"},
	{"id": "heal", "name": "Field Draught+", "duration": 0.1, "color": Color(0.3, 0.85, 0.5), "sprite": "res://assets/sprites/pickups/heal.png", "instant_heal": 35.0},
	{"id": "magnet", "name": "Scrap Magnet", "duration": 14.0, "color": Color(0.75, 0.6, 0.25), "sprite": "res://assets/sprites/pickups/magnet.png"},
	{"id": "quiet", "name": "Soft Steps", "duration": 12.0, "color": Color(0.55, 0.55, 0.7), "sprite": "res://assets/sprites/pickups/quiet.png"},
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
