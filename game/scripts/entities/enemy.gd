extends CharacterBody2D

## Wasteland enemy — sheet-locked looks via EnemyDefs; combat archetypes:
##   raider  – keeps mid range, telegraphs then fires single shots
##   charger – sprints in, winds up, lunges for contact damage
##   brute   – slow tank, fires a 3-bullet spread
## Every attack has a visible wind-up so a good dash always beats it.

signal died

const BulletScene := preload("res://scenes/entities/bullet.tscn")
const PickupScene := preload("res://scenes/entities/powerup_pickup.tscn")
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

var _warn: Node2D
var _warn_alpha: float = 0.0
var _warn_scale_x: float = 1.0
var _shadow: Polygon2D

## Slightly larger than heroes (52) so wasteland sheet mobs read at survivor FOV.
const BODY_FOV_PX := 58.0

func _ensure_kinds() -> void:
	if KINDS.is_empty():
		KINDS = EnemyDefs.combat_kinds_table()

func _move_speed() -> float:
	return speed * (0.55 if _slow_left > 0.0 else 1.0) * _slow_mult


func _archetype() -> String:
	## Combat behavior bucket (raider / charger / brute). Kind id is the sheet slug.
	var a := str(_def.get("archetype", ""))
	if a != "":
		return a
	## Legacy ids
	if kind in ["charger", "brute", "raider"]:
		return kind
	return "raider"

var _dot_left: float = 0.0
var _dot_dps: float = 0.0
var _slow_left: float = 0.0
var _slow_mult: float = 1.0
var _mark_left: float = 0.0

func distract(seconds: float) -> void:
	## Bentley bark — cancel wind-up / lunge and pause aggression briefly.
	_distract_left = maxf(_distract_left, seconds)
	_windup_left = 0.0
	_lunge_left = 0.0
	_fire_cd = maxf(_fire_cd, seconds)
	if _warn:
		_warn_alpha = 0.0
		_warn.queue_redraw()


func apply_dot(dps: float, duration: float) -> void:
	_dot_dps = maxf(_dot_dps, dps)
	_dot_left = maxf(_dot_left, duration)


func apply_slow(mult: float, duration: float) -> void:
	_slow_mult = minf(_slow_mult, clampf(mult, 0.2, 1.0))
	_slow_left = maxf(_slow_left, duration)


func apply_mark(duration: float) -> void:
	_mark_left = maxf(_mark_left, duration)

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
	## Wind-up warning: drawn wedge (avoid Polygon2D triangulation failures on thin scales).
	_warn = Node2D.new()
	_warn.z_index = 2
	_warn.draw.connect(_draw_warn)
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
	## Sit above chunkier ~58px mob silhouettes at survivor FOV.
	hp_bar.offset_top = -42.0
	hp_bar.offset_bottom = -36.0
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
	_mark_left = maxf(0.0, _mark_left - delta)
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_mult = 1.0
	if _dot_left > 0.0:
		_dot_left -= delta
		hp -= _dot_dps * delta
		if hp_bar:
			hp_bar.visible = true
			hp_bar.value = hp
		if hp <= 0.0:
			_die()
			return
	## Dust Surge: enemies hit harder (already applied at spawn via dmg mult); keep tint.
	if GameState.has_event("dust_surge") and body:
		body.modulate = Color(1.2, 0.85, 0.75)
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
		velocity = velocity.move_toward(dir.orthogonal() * _move_speed() * 0.35, 700.0 * delta)
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
		_warn_alpha = 0.35 + 0.55 * k
		_warn_scale_x = 0.75 + 0.45 * k
		_warn.queue_redraw()
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta) + _knock
		move_and_slide()
		_knock = _knock.move_toward(Vector2.ZERO, 1400.0 * delta)
		_tick_walk_anim(delta, true)
		if _windup_left <= 0.0:
			_warn_alpha = 0.0
			_warn.queue_redraw()
			_attack(dir)
		return

	if _lunge_left > 0.0:
		_lunge_left -= delta
		velocity = _lunge_dir * _move_speed() * 3.4
		move_and_slide()
		## Refresh dist after the slide — lunge closes far more than the old 26px check.
		if _player != null and is_instance_valid(_player):
			dist = global_position.distance_to(_player.global_position)
		for i in range(get_slide_collision_count()):
			var col := get_slide_collision(i).get_collider()
			if col and col.is_in_group("player") and col.has_method("take_damage"):
				col.take_damage(damage, self)
				_lunge_left = 0.0
		## Contact radius covers player (14) + enemy body (~16) + lunge overshoot.
		const LUNGE_HIT_RANGE := 52.0
		if dist < LUNGE_HIT_RANGE and _player != null and _player.has_method("take_damage"):
			_player.take_damage(damage, self)
			_lunge_left = 0.0
		_tick_walk_anim(delta, true)
		return

	var chase := _move_speed()
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

func _draw_warn() -> void:
	if _warn_alpha <= 0.01:
		return
	var sx := maxf(_warn_scale_x, 0.7)
	var tip := Vector2(72.0 * sx, 0.0)
	var left := Vector2(14.0, -12.0)
	var right := Vector2(14.0, 12.0)
	## Bright outline flash so telegraphs read on dusty ground.
	_warn.draw_colored_polygon(
		PackedVector2Array([left - Vector2(2, 0), tip + Vector2(4, 0), right - Vector2(2, 0)]),
		Color(1.0, 0.95, 0.55, _warn_alpha * 0.55)
	)
	_warn.draw_colored_polygon(
		PackedVector2Array([left, tip, right]),
		Color(1.0, 0.22, 0.12, _warn_alpha)
	)


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
	var dmg := amount
	## Vesper Marked: take extra from all sources.
	if _mark_left > 0.0:
		dmg *= 1.25
	## Short Circuit: stunned machines take double.
	if float(GameState.run_mods.get("class_short", 0.0)) > 0.0 and _distract_left > 0.0:
		if kind.contains("cyber") or kind.contains("mech") or kind.contains("jugger") or kind.contains("naught") or kind.contains("iron"):
			dmg *= 2.0
	hp -= dmg
	if hp_bar:
		hp_bar.visible = true
		hp_bar.value = hp
	Juice.flash(body, Color(4, 4, 4), 0.08)
	Juice.float_text(global_position + Vector2(0, -26), str(int(round(dmg))), Color(1, 0.92, 0.6), 16)
	Juice.sfx("hit", -8.0)
	if from_dir.length() > 0.01:
		var resist := 0.35 if _archetype() == "brute" else 1.0
		_knock += from_dir.normalized() * 220.0 * resist
		## Rubble Wall: knocked foes slam into neighbors.
		if float(GameState.run_mods.get("class_rubble", 0.0)) > 0.0:
			_rubble_slam(from_dir)
	if hp <= 0.0:
		_die()


func _rubble_slam(from_dir: Vector2) -> void:
	var tip := global_position + from_dir.normalized() * 48.0
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == self or not is_instance_valid(n) or not (n is Node2D):
			continue
		var e := n as Node2D
		if tip.distance_to(e.global_position) > 40.0:
			continue
		if e.has_method("take_damage"):
			e.call("take_damage", 8.0, from_dir)

func _spawn_health_drop() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pickup: Area2D = PickupScene.instantiate()
	scene.add_child(pickup)
	pickup.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-8, 8))
	var heal := PowerupDefs.get_by_id("heal")
	heal["instant_heal"] = 12.0
	heal["name"] = "Scrap Salve"
	pickup.call("setup", heal)


func _spawn_toxic_cloud() -> void:
	## Damages the player while they stand in it — step out.
	var cloud := Area2D.new()
	cloud.collision_layer = 0
	cloud.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 70.0
	shape.shape = circle
	cloud.add_child(shape)
	var life := {"t": 4.0}
	cloud.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.call("take_damage", 6.0, self)
	)
	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(cloud)
	cloud.global_position = global_position
	Juice.burst(global_position, Color(0.45, 0.9, 0.35), 16, 100.0, 0.7)
	var tw := cloud.create_tween()
	tw.tween_interval(4.0)
	tw.tween_callback(cloud.queue_free)


func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	var range_v: Vector2i = _def.get("scrap", Vector2i(1, 3))
	var scrap := GameState.add_scrap(randi_range(range_v.x, range_v.y))
	GameState.kills += 1
	GameState.note_kill_kind(kind)
	GameState.add_run_xp(int(_def.get("xp", 3)))
	Juice.sfx("enemy_die", -2.0)
	Juice.burst(global_position, Color(0.95, 0.55, 0.3), 18, 220.0, 0.5)
	Juice.burst(global_position, Color(0.6, 0.5, 0.4, 0.8), 10, 90.0, 0.7, 1.6)
	Juice.float_text(global_position + Vector2(0, -40), "+%d scrap" % scrap, UiTheme.AMBER, 15)
	## Small health drops from kills (Phase 1 fair-hits loop).
	if randf() < 0.22:
		_spawn_health_drop.call_deferred()
	## Rad Gator: toxic cloud on death — player must step out.
	if kind == "rad_gator":
		_spawn_toxic_cloud.call_deferred()
	## Elite / boss rewards.
	if kind == "cyber_juggernaut":
		var bundle: Dictionary = GearDefs.elite_reward_bundle()
		for g in bundle.get("gear", []):
			GameState.add_run_gear(g)
		Juice.float_text(global_position + Vector2(0, -56), "ELITE LOOT", UiTheme.AMBER, 16)
	elif kind in ["dread_naught", "mutant_overlord"]:
		GameState.record_boss_kill(kind)
		Juice.float_text(global_position + Vector2(0, -56), "BOSS DOWN ×+0.5", Color(1.0, 0.7, 0.3), 18)
	## Ammo Bench special-ammo drops.
	var bench := GameState.ammo_bench_rank()
	var drop_chance := 0.0 if bench <= 0 else clampf(0.04 + 0.03 * float(bench), 0.04, 0.18)
	if drop_chance > 0.0 and randf() < drop_chance:
		GameState.activate_special_ammo(GameState.roll_special_ammo())
		Juice.float_text(global_position + Vector2(0, -70), "SPECIAL AMMO", Color(0.5, 0.85, 1.0), 14)
	Juice.shake(0.12 if _archetype() != "brute" else 0.3)
	if _archetype() == "brute":
		Juice.hitstop(0.06)
	died.emit()
	collision_layer = 0
	if _warn:
		_warn.visible = false
	if hp_bar:
		hp_bar.visible = false
	var tw := create_tween().set_parallel(true)
	var sc := float(_def.get("scale", 1.0))
	tw.tween_property(body, "scale", Vector2(1.4, 0.2) * sc, 0.16)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)
