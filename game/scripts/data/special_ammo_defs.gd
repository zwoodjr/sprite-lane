class_name SpecialAmmoDefs
extends RefCounted

## Timed special ammo (Master Brief Part 4). Mag + reload only; effects last ~15s.


static func all() -> Array[Dictionary]:
	return [
		{
			"id": "incendiary",
			"name": "Incendiary",
			"desc": "Shots set enemies on fire",
			"color": Color(1.0, 0.45, 0.2),
			"duration": 15.0,
			"dot": 4.0,
			"dot_ticks": 3,
		},
		{
			"id": "shock",
			"name": "Shock",
			"desc": "Shots briefly stun",
			"color": Color(0.45, 0.75, 1.0),
			"duration": 15.0,
			"stun": 0.55,
		},
		{
			"id": "explosive",
			"name": "Explosive",
			"desc": "Small blast on impact",
			"color": Color(1.0, 0.75, 0.25),
			"duration": 15.0,
			"splash_radius": 55.0,
			"splash_mult": 0.45,
		},
		{
			"id": "frost",
			"name": "Frost",
			"desc": "Shots slow enemies",
			"color": Color(0.55, 0.85, 1.0),
			"duration": 15.0,
			"slow": 0.55,
			"slow_sec": 1.4,
		},
	]


static func get_by_id(id: String) -> Dictionary:
	for a in all():
		if str(a["id"]) == id:
			return a.duplicate(true)
	return {}


static func random_ammo(rng: RandomNumberGenerator = null) -> Dictionary:
	var pool := all()
	if pool.is_empty():
		return {}
	var i := rng.randi_range(0, pool.size() - 1) if rng else randi() % pool.size()
	return pool[i].duplicate(true)


## Duration / drop odds scale with Hangar Ammo Bench rank.
static func duration_for_rank(base: float, ammo_bench_rank: int) -> float:
	return base * (1.0 + 0.12 * float(ammo_bench_rank))


static func drop_chance(ammo_bench_rank: int) -> float:
	if ammo_bench_rank <= 0:
		return 0.0
	return clampf(0.04 + 0.03 * float(ammo_bench_rank), 0.04, 0.18)
