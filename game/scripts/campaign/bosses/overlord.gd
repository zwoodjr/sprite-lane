extends "res://scripts/campaign/bosses/boss_brain.gd"

## Mutant Overlord (Quarantine): a war machine with the plague grown all through
## it. Spore clouds under the hero, a brood of crawlers, and below half HP a
## flesh-and-steel slam.

func moves() -> Dictionary:
	return {
		"spores": {"cd": 6.0, "first": 3.0, "wind": 0.9, "r": 100.0},
		"brood": {"cd": 14.0, "first": 7.0, "wind": 1.0, "r": 0.0},
		"slam": {"cd": 6.5, "first": 2.0, "wind": 0.9, "r": 200.0, "phase": 2},
	}


func ready(id: String) -> bool:
	var p := player()
	if p == null:
		return false
	var d := p.global_position.distance_to(e.global_position)
	match id:
		"spores":
			return d < 640.0
		"slam":
			return d < 260.0
	return true


func aim(id: String) -> Vector2:
	if id == "slam":
		return e.global_position + Vector2(0, 12)
	return super.aim(id)


func perform(id: String) -> void:
	match id:
		"spores":
			e.call("_spore_cloud", _at, 100.0, 6.0, float(e.get("damage")) * 0.4)
			blast(_at, 100.0, 0.5, Color("9ccf3e"))
		"brood":
			summon("chimera_rat" if phase == 1 else "ash_wraiths", 3, 0.45, 150.0)
		"slam":
			blast(e.global_position + Vector2(0, 12), 200.0, 1.1, Color("ff4836"))


func on_phase() -> void:
	say("quill", "Its plating is splitting! The flesh underneath is the weak point. Hit it while it's open!")
