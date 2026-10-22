extends "res://scripts/campaign/bosses/boss_brain.gd"

## Rad Gator Matriarch (Cathedral of Ash): the gators' mother, brood sacs on
## her back. Spits a fan of plague, hatches her brood, and below half HP she
## lobs bile that leaves a burning plague pool.

func moves() -> Dictionary:
	return {
		"spit": {"cd": 5.0, "first": 3.0, "wind": 0.7, "r": 48.0},
		"brood": {"cd": 14.0, "first": 7.0, "wind": 1.1, "r": 150.0},
		"bile": {"cd": 6.5, "first": 2.0, "wind": 0.9, "r": 96.0, "phase": 2},
	}


func ready(id: String) -> bool:
	var p := player()
	if p == null:
		return false
	var d := p.global_position.distance_to(e.global_position)
	match id:
		"spit":
			return d < 520.0
		"bile":
			return d < 600.0
	return true


func aim(id: String) -> Vector2:
	if id == "brood":
		return e.global_position + Vector2(0, 12)
	return super.aim(id)


func perform(id: String) -> void:
	match id:
		"spit":
			fan(5 if phase == 1 else 7, 0.17, 330.0, 0.6)
			Juice.mob_sfx("attack", e, 0.0)
		"brood":
			summon("rad_gator", 3 if phase == 1 else 4, 0.35, 130.0)
			RunFx.ring(e.get_parent(), e.global_position + Vector2(0, 12), 150.0, Color("9ccf3e"), 0.4, 5.0)
			Juice.mob_sfx("roar", e)
		"bile":
			e.call("_spore_cloud", _at, 96.0, 5.0, float(e.get("damage")) * 0.45)
			blast(_at, 96.0, 0.7, Color("9ccf3e"))


func on_phase() -> void:
	say("cinder", "She's tearing open. Mind the bile, it eats through boots!")
	Juice.mob_sfx("roar", e)
