extends CharacterBody2D

## Wasteland enemy with a few data-driven archetypes.
##   raider  – keeps mid range, telegraphs then fires single shots
##   charger – sprints in, winds up, lunges for contact damage
##   brute   – slow tank, fires a 3-bullet spread
## Every attack has a visible wind-up so a good dash always beats it.

signal died

const BulletScene := preload("res://scenes/entities/bullet.tscn")

const KINDS := {
	"raider": {
		"hp": 40.0, "speed": 115.0, "damage": 8.0, "range": 300.0, "pref": 190.0,
		"cooldown": 1.3, "windup": 0.38, "scale": 1.0, "tint": Color(1, 1, 1), "sprite": "res://assets/sprites/enemies/raider.png",
		"scrap": Vector2i(1, 3), "xp": 3,
	},
	"charger": {
		"hp": 28.0, "speed": 170.0, "damage": 14.0, "range": 140.0, "pref": 0.0,
		"cooldown": 1.6, "windup": 0.45, "scale": 1.0, "tint": Color(1, 1, 1), "sprite": "res://assets/sprites/enemies/charger.png",
		"scrap": Vector2i(1, 2), "xp": 3,
	},
	"brute": {
		"hp": 130.0, "speed": 70.0, "damage": 7.0, "range": 330.0, "pref": 230.0,
		"cooldown": 2.0, "windup": 0.6, "scale": 1.0, "tint": Color(1, 1, 1), "sprite": "res://assets/sprites/enemies/brute.png",
		"scrap": Vector2i(3, 6), "xp": 8,
	},
}

var kind: String = "raider"
var hp: float = 40.0
var max_hp: float = 40.0
var damage: float = 8.0
var speed: float = 110.0
var _def: Dictionary = {}
var _fire_cd: float = 0.0
var _windup_left: float = 0.0
var _lunge_left: float = 0.0
var _lunge_dir: Vector2 = Vector2.ZERO
var _knock: Vector2 = Vector2.ZERO
var _strafe_sign: float = 1.0
var _player: Node2D
var _dead: bool = false
var _spawn_in: float = 0.35
var _bob_t: float = 0.0

@onready var body: Sprite2D = $Body
@onready var hp_bar: ProgressBar = $HpBar

var _warn: Polygon2D
var _shadow: Polygon2D


func setup(spawn_pos: Vector2, hp_mult: float, dmg_mult: float, spd_mult: float = 1.0, kind_id: String = "raider") -> void:
	global_position = spawn_pos
	kind = kind_id if KINDS.has(kind_id) else "raider"
	_def = KINDS[kind]
	max_hp = float(_def["hp"]) * hp_mult
	hp = max_hp
	damage = float(_def["damage"]) * dmg_mult
	speed = float(_def["speed"]) * spd_mult * randf_range(0.92, 1.08)
	_fire_cd = randf_range(0.6, 1.6)
	_strafe_sign = -1.0 if randf() < 0.5 else 1.0
	if is_inside_tree():
		_apply_look()


func _ready() -> void:
	add_to_group("enemies")
	if _def.is_empty():
		_def = KINDS["raider"]
	if body and body.texture == null:
		body.texture = load("res://assets/sprites/enemies/raider.png")
	## Wind-up warning: a pulsing red wedge toward the player.
	_warn = Polygon2D.new()
	_warn.polygon = PackedVector2Array([Vector2(16, -10), Vector2(70, 0), Vector2(16, 10)])
	_warn.color = Color(1.0, 0.25, 0.15, 0.0)
	_warn.z_index = 2
	add_child(_warn)
	_style_bar()
	_apply_look()
	## Spawn-in: rise out of the dust
	modulate.a = 0.0
	body.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	tw.tween_property(body, "scale", Vector2.ONE * float(_def.get("scale", 1.0)), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Juice.dust_puff(global_position + Vector2(0, 14), 6)


func _apply_look() -> void:
	if body:
		body.texture = load(str(_def.get("sprite", "res://assets/sprites/enemies/raider.png")))
		body.self_modulate = _def.get("tint", Color.WHITE)
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp


func _style_bar() -> void:
	if hp_bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.03, 0.02, 0.8)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.92, 0.35, 0.25)
	fill.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("background", bg)
	hp_bar.add_theme_stylebox_override("fill", fill)
	## Sit above chunky 48–64px silhouettes at survivor FOV.
	hp_bar.offset_top = -34.0
	hp_bar.offset_bottom = -28.0
	hp_bar.visible = false  ## only shown once damaged


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _spawn_in > 0.0:
		_spawn_in -= delta
		return
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		return
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player / maxf(dist, 0.001)

	## Wind-up in progress: hold still and telegraph.
	if _windup_left > 0.0:
		_windup_left -= delta
		_warn.rotation = dir.angle()
		var k := 1.0 - _windup_left / float(_def["windup"])
		_warn.color.a = 0.25 + 0.55 * k
		_warn.scale = Vector2(0.6 + 0.6 * k, 1.0)
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta) + _knock
		move_and_slide()
		_knock = _knock.move_toward(Vector2.ZERO, 1400.0 * delta)
		if _windup_left <= 0.0:
			_warn.color.a = 0.0
			_attack(dir)
		return

	if _lunge_left > 0.0:
		_lunge_left -= delta
		velocity = _lunge_dir * speed * 3.4
		move_and_slide()
		for i in range(get_slide_collision_count()):
			var col := get_slide_collision(i).get_collider()
			if col and col.is_in_group("player") and col.has_method("take_damage"):
				col.take_damage(damage)
				_lunge_left = 0.0
		if dist < 26.0 and _player.has_method("take_damage"):
			_player.take_damage(damage)
			_lunge_left = 0.0
		return

	var chase := speed
	if _player.has_method("get_active_buffs") and (_player.get_active_buffs() as Dictionary).has("quiet") and dist > 220.0:
		chase *= 0.75
	var pref := float(_def["pref"])
	var want := Vector2.ZERO
	if kind == "charger" or dist > pref:
		want = dir * chase
	elif dist < pref * 0.6:
		want = -dir * chase * 0.7
	else:
		want = dir.orthogonal() * chase * 0.55 * _strafe_sign
	want += _separation() * chase * 0.8
	velocity = velocity.move_toward(want, 900.0 * delta) + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	move_and_slide()
	if body:
		body.flip_h = dir.x < 0.0
		_bob_t += delta * 10.0
		body.position.y = -absf(sin(_bob_t)) * 2.0
	if dist <= float(_def["range"]) and _fire_cd <= 0.0:
		_windup_left = float(_def["windup"])
		if randf() < 0.3:
			_strafe_sign *= -1.0


func _separation() -> Vector2:
	var push := Vector2.ZERO
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == self or not (n is Node2D):
			continue
		var d := global_position - (n as Node2D).global_position
		var l := d.length()
		if l > 0.1 and l < 48.0:
			push += d / l * (1.0 - l / 48.0)
	return push.limit_length(1.0)


func _attack(dir: Vector2) -> void:
	_fire_cd = float(_def["cooldown"]) * randf_range(0.85, 1.2)
	match kind:
		"charger":
			_lunge_dir = dir
			_lunge_left = 0.22
			Juice.dust_puff(global_position + Vector2(0, 14), 5)
		"brute":
			for a in [-0.22, 0.0, 0.22]:
				_fire(dir.rotated(a), 360.0)
			Juice.sfx("enemy_shot", -2.0)
		_:
			_fire(dir, 430.0)
			Juice.sfx("enemy_shot", -6.0)


func _fire(dir: Vector2, spd: float) -> void:
	var bullet: Area2D = BulletScene.instantiate()
	bullet.setup(global_position + dir * 18.0, dir, spd, damage, false)
	get_tree().current_scene.add_child(bullet)


func take_damage(amount: float, from_dir: Vector2 = Vector2.ZERO) -> void:
	if _dead:
		return
	hp -= amount
	if hp_bar:
		hp_bar.visible = true
		hp_bar.value = hp
	Juice.flash(body, Color(4, 4, 4), 0.08)
	Juice.float_text(global_position + Vector2(0, -26), str(int(round(amount))), Color(1, 0.92, 0.6), 16)
	Juice.sfx("hit", -8.0)
	if from_dir.length() > 0.01:
		var resist := 0.35 if kind == "brute" else 1.0
		_knock += from_dir.normalized() * 220.0 * resist
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	var range_v: Vector2i = _def.get("scrap", Vector2i(1, 3))
	var scrap := GameState.add_scrap(randi_range(range_v.x, range_v.y))
	GameState.kills += 1
	GameState.add_run_xp(int(_def.get("xp", 3)))
	Juice.sfx("enemy_die", -2.0)
	Juice.burst(global_position, Color(0.95, 0.55, 0.3), 18, 220.0, 0.5)
	Juice.burst(global_position, Color(0.6, 0.5, 0.4, 0.8), 10, 90.0, 0.7, 1.6)
	Juice.float_text(global_position + Vector2(0, -40), "+%d scrap" % scrap, UiTheme.AMBER, 15)
	Juice.shake(0.12 if kind != "brute" else 0.3)
	if kind == "brute":
		Juice.hitstop(0.06)
	died.emit()
	collision_layer = 0
	_warn.visible = false
	hp_bar.visible = false
	var tw := create_tween().set_parallel(true)
	var sc := float(_def.get("scale", 1.0))
	tw.tween_property(body, "scale", Vector2(1.4, 0.2) * sc, 0.16)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)
