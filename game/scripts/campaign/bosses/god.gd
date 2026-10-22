extends "res://scripts/campaign/bosses/boss_brain.gd"

## The Wasteland God (Dustfall): the heart of the Dust given a body. Pulses of
## Dust around itself, Dust falling on the hero (three marked spots), wraiths
## called out of the storm; below half HP it does everything faster and its
## spores choke the ground.

var _lines_done: Dictionary = {}


func moves() -> Dictionary:
	return {
		"pulse": {"cd": 7.0, "first": 4.0, "wind": 1.1, "r": 230.0},
		"fall": {"cd": 5.0, "first": 2.0, "wind": 1.0, "r": 85.0},
		"call": {"cd": 15.0, "first": 9.0, "wind": 1.0, "r": 0.0},
		"spores": {"cd": 6.0, "first": 1.0, "wind": 0.8, "r": 110.0, "phase": 2},
	}


func ready(id: String) -> bool:
	var p := player()
	if p == null:
		return false
	var d := p.global_position.distance_to(e.global_position)
	match id:
		"pulse":
			return d < 300.0
		"fall", "spores":
			return d < 700.0
	return true


func aim(id: String) -> Vector2:
	if id == "pulse":
		return e.global_position + Vector2(0, 12)
	return super.aim(id)


func perform(id: String) -> void:
	match id:
		"pulse":
			blast(e.global_position + Vector2(0, 12), 230.0, 1.0, Color("ffc040"))
		"fall":
			## The marked spot, then two more around the hero a beat later.
			blast(_at, 85.0, 0.8, Color("ffc040"))
			var p := player()
			if p:
				for i in range(2):
					var at2 := p.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(90.0, 180.0)
					RunFx.ring(e.get_parent(), at2, 85.0, Color("ff4836"), 0.7, 4.0)
					var tw := e.create_tween()
					tw.tween_interval(0.7)
					tw.tween_callback(func() -> void:
						if is_instance_valid(e):
							blast(at2, 85.0, 0.8, Color("ffc040")))
		"call":
			summon("ash_wraiths", 2 if phase == 1 else 3, 0.5, 170.0)
			if phase == 2:
				summon("apocalypse_wraith", 1, 0.35, 120.0)
		"spores":
			e.call("_spore_cloud", _at, 110.0, 6.0, float(e.get("damage")) * 0.4)


func tick(en: Node2D, delta: float) -> bool:
	var r := float(en.get("hp")) / maxf(1.0, float(en.get("max_hp")))
	if r < 0.75 and not _lines_done.has("75"):
		_lines_done["75"] = true
		say("dust", "YOU CARRY MY SHARDS IN YOUR POCKETS. YOU HAVE ALWAYS BEEN MINE.")
	if r < 0.25 and not _lines_done.has("25"):
		_lines_done["25"] = true
		say("dust", "WITHOUT ME THE PLAGUE RETURNS. I AM THE CURE THAT ATE THE WORLD.")
	return super.tick(en, delta)


func on_phase() -> void:
	say("helm", "It's cracking! Whatever you do, don't stop now!")
