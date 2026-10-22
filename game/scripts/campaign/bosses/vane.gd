extends "res://scripts/campaign/bosses/boss_brain.gd"

## Mother Vane (raider captain): fire bottles that leave burning ground, a
## rally that calls her crew in, and below half HP a shoulder-first charge.

func moves() -> Dictionary:
	return {
		"bottle": {"cd": 4.5, "first": 2.5, "wind": 0.8, "r": 90.0},
		"rally": {"cd": 16.0, "first": 9.0, "wind": 0.9, "r": 0.0},
		"charge": {"cd": 6.5, "first": 1.5, "wind": 0.7, "r": 60.0, "phase": 2},
	}


func ready(id: String) -> bool:
	var p := player()
	if p == null:
		return false
	var d := p.global_position.distance_to(e.global_position)
	match id:
		"bottle":
			return d < 560.0
		"charge":
			return d > 120.0 and d < 520.0
	return true


func perform(id: String) -> void:
	match id:
		"bottle":
			var g := Node2D.new()
			g.set_script(load(RunFx.GROUND_FX))
			g.set("mode", "flame")
			g.set("radius", 80.0)
			g.set("life", 5.0)
			g.set("value", float(e.get("damage")) * 0.5)
			g.position = _at
			e.get_parent().add_child(g)
			blast(_at, 90.0, 0.55, Color("ff4836"))
			Juice.sfx_at("explosion", _at, -6.0)
		"rally":
			summon("raider_grunt", 2 if phase == 1 else 3, 0.6, 150.0)
			var lines := ["Crew! On me!", "Bring me that medicine!", "Somebody shoot that dog!"]
			say("vane", str(lines[randi() % lines.size()]))
		"charge":
			var p := player()
			if p:
				dash(p.global_position - e.global_position, 640.0, 0.5)


func on_phase() -> void:
	say("vane", "You burned my camp. I'll burn your hangar down to the slab!")
