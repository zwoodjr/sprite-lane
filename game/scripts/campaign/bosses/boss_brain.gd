extends RefCounted

## Base for the campaign's named bosses: special moves on cooldowns, each with
## a telegraphed wind-up (SIGNAL ring on the ground, bible §4) during which the
## boss holds still, then the move. Phase 2 below half HP. Subclasses fill
## MOVES ({id: {cd, wind, r, phase}}) and implement perform(id) / aim(id).

var e: Node2D
var mc: Node
var phase: int = 1
var _cd: Dictionary = {}
var _move: String = ""
var _wind: float = 0.0
var _wind_max: float = 1.0
var _at: Vector2 = Vector2.ZERO
var _r: float = 80.0
var _dash_left: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _dash_speed: float = 600.0
var _dash_hit: bool = false


func moves() -> Dictionary:
	return {}


func setup(enemy: Node2D, controller: Node) -> void:
	e = enemy
	mc = controller
	var m := moves()
	for k in m.keys():
		_cd[k] = float(m[k].get("first", m[k].get("cd", 6.0)))


func player() -> Node2D:
	return e.get_tree().get_first_node_in_group("player") as Node2D if e and e.is_inside_tree() else null


func tick(en: Node2D, delta: float) -> bool:
	if phase == 1 and float(en.get("hp")) < float(en.get("max_hp")) * 0.5:
		phase = 2
		on_phase()
	for k in _cd.keys():
		_cd[k] = float(_cd[k]) - delta
	if _dash_left > 0.0:
		_dash_left -= delta
		en.set("velocity", _dash_dir * _dash_speed)
		(en as CharacterBody2D).move_and_slide()
		var p := player()
		if p and not _dash_hit and p.global_position.distance_to(en.global_position) < 52.0 * float(en.get("body_scale")) and p.has_method("take_damage"):
			_dash_hit = true
			p.call("take_damage", float(en.get("damage")) * 1.2, en)
			Juice.shake(0.3)
		return true
	if _move != "":
		_wind -= delta
		var k2 := clampf(1.0 - _wind / _wind_max, 0.0, 1.0)
		if _r > 0.0:
			en.call("_show_telegraph", _at, _r, k2)
		en.set("velocity", Vector2.ZERO)
		(en as CharacterBody2D).move_and_slide()
		if _wind <= 0.0:
			var mv := _move
			_move = ""
			var tele: Node = en.get("_tele")
			if tele:
				(tele as CanvasItem).visible = false
			perform(mv)
		return true
	## Only between its normal attacks.
	if float(en.get("_windup_left")) > 0.0 or float(en.get("_lunge_left")) > 0.0 or bool(en.call("has_status", "stun")):
		return false
	var m := moves()
	for k in m.keys():
		var d: Dictionary = m[k]
		if float(_cd[k]) > 0.0 or int(d.get("phase", 1)) > phase:
			continue
		if not ready(str(k)):
			continue
		_cd[k] = float(d.get("cd", 6.0)) * (0.75 if phase == 2 else 1.0)
		_move = str(k)
		_wind_max = float(d.get("wind", 0.8))
		_wind = _wind_max
		_r = float(d.get("r", 80.0))
		_at = aim(str(k))
		en.call("_cancel_attack")
		var anim: Object = en.get("_anim")
		if anim and bool(anim.call("has_state", "windup")):
			anim.call("play_over", "windup", _wind_max)
		return true
	return false


## Override: can this move start now? (range checks etc.)
func ready(_id: String) -> bool:
	return true


## Override: where the telegraph sits (default: under the hero).
func aim(_id: String) -> Vector2:
	var p := player()
	return p.global_position if p else e.global_position


func perform(_id: String) -> void:
	pass


func on_phase() -> void:
	pass


func on_death(_en: Node2D) -> void:
	pass


## Shared bits ----------------------------------------------------------------

## A straight charge (the wind-up telegraph already showed the lane).
func dash(dir: Vector2, speed: float, time: float) -> void:
	_dash_dir = dir.normalized()
	_dash_speed = speed
	_dash_left = time
	_dash_hit = false
	Juice.dust_puff(e.global_position, 8)

func fan(n: int, spread: float, spd: float, dmg_k: float) -> void:
	var p := player()
	if p == null:
		return
	var origin: Vector2 = e.call("_atk_origin", 1)
	var aimv := (p.global_position - origin).normalized()
	for i in range(n):
		var a := (float(i) - float(n - 1) * 0.5) * spread
		e.call("_fire_from", origin, aimv.rotated(a), spd, float(e.get("damage")) * dmg_k)


func blast(at: Vector2, r: float, dmg_k: float, col: Color) -> void:
	RunFx.ring(e.get_parent(), at, r, col, 0.5, 6.0)
	Juice.burst(at, col, 24, r * 2.0, 0.6, 1.6)
	Juice.shake(0.3)
	var p := player()
	if p and p.global_position.distance_to(at) <= r and p.has_method("take_damage"):
		p.call("take_damage", float(e.get("damage")) * dmg_k, e)


func summon(kind: String, n: int, hp_k: float, r: float = 120.0) -> void:
	if mc == null or e.get_tree().get_nodes_in_group("enemies").size() > 16:
		return
	for i in range(n):
		var at: Vector2 = e.global_position + Vector2.RIGHT.rotated(TAU * float(i) / float(n) + randf()) * r
		var m: Node = mc.call("spawn_mob", kind, at, "", hp_k)
		if m:
			Juice.dust_puff(at, 10)


func say(who: String, text: String) -> void:
	if mc and mc.has_method("radio"):
		mc.call("radio", who, text)
