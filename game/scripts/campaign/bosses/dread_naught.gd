extends "res://scripts/campaign/bosses/boss_brain.gd"

## Dread Naught (Dead Signal): the war's last siege engine, still on standing
## orders. A wide shell barrage, scrap-hound drones out of its hull, and below
## half HP a ground-shaking stomp around itself.

func moves() -> Dictionary:
	return {
		"barrage": {"cd": 5.0, "first": 3.0, "wind": 0.8, "r": 52.0},
		"drones": {"cd": 15.0, "first": 8.0, "wind": 1.0, "r": 0.0},
		"stomp": {"cd": 7.0, "first": 2.0, "wind": 1.0, "r": 180.0, "phase": 2},
	}


func ready(id: String) -> bool:
	var p := player()
	if p == null:
		return false
	var d := p.global_position.distance_to(e.global_position)
	match id:
		"barrage":
			return d < 620.0
		"stomp":
			return d < 240.0
	return true


func aim(id: String) -> Vector2:
	if id == "stomp":
		return e.global_position + Vector2(0, 12)
	return super.aim(id)


func perform(id: String) -> void:
	match id:
		"barrage":
			fan(9 if phase == 1 else 13, 0.14, 380.0, 0.5)
			Juice.sfx_at("machine_shot", e.global_position, 0.0)
		"drones":
			summon("scrap_hound", 3 if phase == 1 else 4, 0.5, 140.0)
			say("beacon", "UNIT 7 DEPLOYING SUPPORT. HOLD THE LINE.")
		"stomp":
			blast(e.global_position + Vector2(0, 12), 180.0, 1.0, Color("ff4836"))


func on_phase() -> void:
	say("beacon", "HULL BREACH. STANDING ORDER 7 REMAINS IN EFFECT.")
