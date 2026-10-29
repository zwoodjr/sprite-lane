extends "res://scripts/campaign/bosses/boss_brain.gd"

## The Dust Warden (Wander, last window, Blight+): its own dust pulse still
## runs (enemy._tick_warden); on top of that it lunges across the pads in a
## sand dash, calls dust hounds out of the ground and, below half HP, drops a
## storm ring on the hero that you have to leave.

func moves() -> Dictionary:
	return {
		"sand_dash": {"cd": 5.5, "first": 3.0, "wind": 0.75, "r": 56.0},
		"hounds": {"cd": 14.0, "first": 6.0, "wind": 0.9, "r": 0.0},
		"storm_ring": {"cd": 7.5, "first": 2.0, "wind": 1.2, "r": 150.0, "phase": 2},
	}


func ready(id: String) -> bool:
	var p := player()
	if p == null:
		return false
	var d := p.global_position.distance_to(e.global_position)
	match id:
		"sand_dash":
			return d > 140.0 and d < 560.0
		"storm_ring":
			return d < 620.0
	return true


func perform(id: String) -> void:
	var p := player()
	match id:
		"sand_dash":
			if p:
				dash(p.global_position - e.global_position, 820.0, 0.45)
		"hounds":
			summon("scrap_hound", 3 if phase == 1 else 5, 0.45, 150.0)
		"storm_ring":
			blast(_at, 150.0, 1.3, Color(0.85, 0.7, 0.35))


func on_phase() -> void:
	say("helm", "Helm: The Warden's cracking — it's pulling the storm in. Move!")
