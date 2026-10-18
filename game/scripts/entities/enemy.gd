extends CharacterBody2D

## Wasteland enemy — sheet-locked looks via EnemyDefs; combat archetypes:
##   raider  – keeps mid range, telegraphs then fires single shots
##   charger – sprints in, winds up, lunges for contact damage
##   brute   – slow tank, fires a 3-bullet spread
## Every attack has a visible wind-up so a good dash always beats it.

signal died

const BulletScene := preload("res://scenes/entities/bullet.tscn")
const EnemyDefs = preload("res://scripts/data/enemy_defs.gd")
const UnitAnim = preload("res://scripts/fx/unit_anim.gd")

## Built from EnemyDefs (sheet crops). Legacy raider/charger/brute still resolve.
static var KINDS: Dictionary = {}

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
var _distract_left: float = 0.0
var _walk: RefCounted = UnitAnim.new()
var _attack_flash: float = 0.0
var _body_base_scale: float = 1.0

@onready var body: Sprite2D = $Body
@onready var hp_bar: ProgressBar = $HpBar

var _warn: Polygon2D
var _shadow: Polygon2D

const BODY_FOV_PX := 44.0


func _ensure_kinds() -> void:
	if KINDS.is_empty():
		KINDS = EnemyDefs.combat_kinds_table()


func _archetype() -> String:
	## Combat behavior bucket (raider / charger / brute). Kind id is the sheet slug.
	var a := str(_def.get("archetype", ""))
	if a != "":
		return a
	## Legacy ids
	if kind in ["charger", "brute", "raider"]:
		return kind
	return "raider"


func distract(seconds: float) -> void:
	## Bentley bark — cancel wind-up / lunge and pause aggression briefly.
	_distract_left = maxf(_distract_left, seconds)
	_windup_left = 0.0
	_lunge_left = 0.0
	_fire_cd = maxf(_fire_cd, seconds)
	if _warn:
		_warn.color.a = 0.0


func setup(spawn_pos: Vector2, hp_mult: float, dmg_mult: float, spd_mult: float = 1.0, kind_id: String = "rad_gator") -> void:
	global_position = spawn_pos
	_ensure_kinds()
	kind = kind_id if KINDS.has(kind_id) else "rad_gator"
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
	_ensure_kinds()
	if _def.is_empty():
		_def = KINDS.get("rad_gator", {})
	if body and body.texture == null:
		body.texture = load(str(_def.get("sprite", "res://assets/sprites/enemies/rad_gator.png")))
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
	_sync_body_scale()
	var spawn_scale := body.scale
	body.scale = spawn_scale * 0.6
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	tw.tween_property(body, "scale", spawn_scale, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Juice.dust_puff(global_position + Vector2(0, 14), 6)


func _apply_look() -> void:
	if body:
		var still_path := str(_def.get("sprite", "res://assets/sprites/enemies/rad_gator.png"))
		var still := load(still_path) as Texture2D
		body.texture = still
		body.self_modulate = _def.get("tint", Color.WHITE)
		var walk_path := still_path.replace(".png", "_walk.png")
		_walk.setup_from_walk_path(walk_path, still)
		_sync_body_scale()
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp


func _sync_body_scale() -> void:
	var tw := 96.0
	if body and body.texture != null:
		if body.texture is AtlasTexture:
			tw = (body.texture as AtlasTexture).region.size.x
		else:
			tw = float(body.texture.get_width())
			if tw >= 192.0:
				tw = 96.0
	var def_scale := float(_def.get("scale", 1.0))
	_body_base_scale = (BODY_FOV_PX / maxf(tw, 1.0)) * def_scale
	if body:
		body.scale = Vector2.ONE * _body_base_scale
	_walk.set_base_scale(_body_base_scale)


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
	_distract_left = maxf(0.0, _distract_left - delta)
	_attack_flash = maxf(0.0, _attack_flash - delta)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		_tick_walk_anim(delta, false)
		return
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player / maxf(dist, 0.001)

	if _distract_left > 0.0:
		velocity = velocity.move_toward(dir.orthogonal() * speed * 0.35, 700.0 * delta)
		move_and_slide()
		if body:
			body.modulate = Color(1.15, 1.05, 0.7)
		_tick_walk_anim(delta, false)
		return
	elif body:
		body.modulate = Color.WHITE

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
		_tick_walk_anim(delta, true)
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
				col.take_damage(damage, self)
				_lunge_left = 0.0
		if dist < 26.0 and _player.has_method("take_damage"):
			_player.take_damage(damage, self)
			_lunge_left = 0.0
		_tick_walk_anim(delta, true)
		return

	var chase := speed
	if _player.has_method("get_active_buffs") and (_player.get_active_buffs() as Dictionary).has("quiet") and dist > 220.0:
		chase *= 0.75
	var pref := float(_def["pref"])
	var want := Vector2.ZERO
	if _archetype() == "charger" or dist > pref:
		want = dir * chase
	elif dist < pref * 0.6:
		want = -dir * chase * 0.7
	else:
		want = dir.orthogonal() * chase * 0.55 * _strafe_sign
	want += _separation() * chase * 0.8
	velocity = velocity.move_toward(want, 900.0 * delta) + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	move_and_slide()
	_tick_walk_anim(delta, false)
	if dist <= float(_def["range"]) and _fire_cd <= 0.0:
		_windup_left = float(_def["windup"])
		if randf() < 0.3:
			_strafe_sign *= -1.0


func _tick_walk_anim(delta: float, attacking: bool) -> void:
	if body == null:
		return
	_walk.tick(body, velocity, delta, {
		"move_thresh": 20.0,
		"speed_ref": maxf(speed, 80.0),
		"bob_amp": 2.8,
		"attack": attacking or _attack_flash > 0.0,
	})


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
	_attack_flash = 0.14
	match _archetype():
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
	bullet.setup(global_position + dir * 18.0, dir, spd, damage, false, self)
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
		var resist := 0.35 if _archetype() == "brute" else 1.0
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
	Juice.shake(0.12 if _archetype() != "brute" else 0.3)
	if _archetype() == "brute":
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
