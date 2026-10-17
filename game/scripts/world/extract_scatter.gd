class_name ExtractScatter
extends RefCounted

## Place extract pads each run near landmarks, away from spawn.


static func roll_positions(run_seed: int, landmarks: Array, count: int = 3) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 2654435761 + 7
	var picks: Array[Dictionary] = []
	if landmarks.is_empty():
		## Fallback ring if landmarks missing
		for i in range(count):
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(1000.0, 2400.0)
			picks.append({
				"name": "Extract %d" % (i + 1),
				"position": Vector2(cos(ang), sin(ang)) * dist,
			})
		return picks

	var candidates: Array = landmarks.duplicate()
	## Shuffle
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var used: Array[Vector2] = []
	for lm in candidates:
		if picks.size() >= count:
			break
		var pos: Vector2 = lm["position"]
		## Offset beside landmark so pad is readable, not buried in props
		var offset := Vector2(rng.randf_range(-80, 80), rng.randf_range(-80, 80))
		var p := pos + offset
		if p.length() < 650.0:
			continue ## too close to spawn
		var ok := true
		for u in used:
			if u.distance_to(p) < 500.0:
				ok = false
				break
		if not ok:
			continue
		used.append(p)
		picks.append({
			"name": "%s Pad" % str(lm.get("name", "Extract")),
			"position": p,
			"landmark": str(lm.get("name", "")),
		})

	## Ensure at least `count`
	while picks.size() < count:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(1100.0, 2800.0)
		var p2 := Vector2(cos(ang), sin(ang)) * dist
		picks.append({"name": "Dust Pad %d" % (picks.size() + 1), "position": p2})
	return picks
