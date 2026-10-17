extends CharacterBody2D

signal died
signal health_changed(current: float, maximum: float)
signal buffs_changed(buffs: Dictionary)
signal ammo_changed(ammo: int, mag: int, reloading: bool)
signal dashed
signal ability_used(name: String)

const BulletScene := preload("res://scenes/entities/bullet.tscn")

## --- Movement feel (tuned for thumbs) ---
@export var base_speed: float = 235.0
@export var accel: float = 2400.0       ## px/s² toward target velocity
@export var decel: float = 3000.0       ## px/s² when the stick is released
@export var turn_boost: float = 1.8     ## extra accel when reversing direction
@export var base_max_hp: float = 100.0

## --- Dash ---
const DASH_SPEED := 760.0
const DASH_TIME := 0.16
const DASH_IFRAMES := 0.24
const DASH_COOLDOWN := 1.3

var max_hp: float = 100.0
var hp: float = 100.0
var damage_mult: float = 1.0
var move_mult: float = 1.0
var firerate_mult: float = 1.0
var resist_mult: float = 1.0

var _fire_cd: float = 0.0
var _reload_left: float = 0.0
var _ammo: int = 24
var _ability_cd: float = 0.0
var _post_heal_left: float = 0.0
var _rush_left: float = 0.0
var _last_stitch_available: bool = false
var _mounted: bool = false
var _oos_timer: float = 0.0
var _iframes: float = 0.0
var _dash_left: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _step_t: float = 0.0
var _bob_t: float = 0.0
var _recoil: float = 0.0
var _flash_left: float = 0.0
var _last_aim: Vector2 = Vector2.RIGHT
var _char: Dictionary = {}
var _weapon: Dictionary = {}
var _mount: Dictionary = {}
var _armor: Dictionary = {}
var _buffs: Dictionary = {}  ## id -> {time_left, def}
var _ability: Dictionary = {}

@onready var body: Sprite2D = $Body
@onready var gun: Node2D = $Gun
@onready var mount_visual: Sprite2D = $MountVisual
@onready var label: Label = $NameLabel
@onready var camera: Camera2D = $Camera2D

var _gun_poly: Polygon2D
var _muzzle: Polygon2D
var _shadow: Polygon2D
var _aim_line: Line2D


func _ready() -> void:
	add_to_group("player")
	_apply_loadout()
	hp = max_hp
	health_changed.emit(hp, max_hp)
	mount_visual.visible = false
	mount_visual.texture = load("res://assets/sprites/mounts/skateboard.png")
	_build_visuals()
	if camera.has_method("set_target"):
		camera.call("set_target", self)


func _apply_loadout() -> void:
	_char = GameState.get_character()
	_weapon = GameState.weapon
	_mount = GameState.mount
	_armor = GameState.armor
	_ability = _char.get("ability", {})
	_refresh_run_stats(true)
	_last_stitch_available = bool(_char.get("has_last_stitch", false))
	body.texture = load(str(_char.get("sprite", "res://assets/sprites/characters/rook_vex.png"))) as Texture2D
	label.text = str(_char.get("display_name", "Wanderer"))
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", _char.get("accent", Color(0.9, 0.8, 0.5)))
	if not GameState.loadout_changed.is_connected(_on_loadout_changed):
		GameState.loadout_changed.connect(_on_loadout_changed)


func _on_loadout_changed() -> void:
	## In-run upgrade pick or meta refresh mid-match.
	var old_max := max_hp
	_refresh_run_stats(false)
	if max_hp > old_max:
		hp = minf(max_hp, hp + (max_hp - old_max))
		health_changed.emit(hp, max_hp)
	ammo_changed.emit(_ammo, _mag_size(), _reload_left > 0.0)


func _refresh_run_stats(reset_ammo: bool) -> void:
	var rm: Dictionary = GameState.run_mods
	max_hp = base_max_hp \
		+ float(_char.get("max_hp_bonus", 0)) \
		+ float(_armor.get("flat_armor", 0)) * 0.5 \
		+ GameState.starting_hp_bonus() \
		+ float(rm.get("max_hp", 0.0))
	damage_mult = float(_char.get("damage_mult", 1.0)) \
		* (1.0 + GameState.starting_damage_bonus()) \
		* (1.0 + float(rm.get("damage", 0.0)))
	move_mult = float(_char.get("move_speed_mult", 1.0)) * (1.0 + float(rm.get("move", 0.0)))
	firerate_mult = 1.0 + float(rm.get("firerate", 0.0))
	if reset_ammo:
		_ammo = _mag_size()


func _mag_size() -> int:
	return int(_weapon.get("mag_size", 24)) + int(GameState.run_mods.get("mag", 0.0))


func _build_visuals() -> void:
	## "You are here" ring in the character's accent color (find yourself fast).
	_shadow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * 19.0, sin(a) * 8.0 + 17.0))
	_shadow.polygon = pts
	var acc: Color = _char.get("accent", Color(0.9, 0.7, 0.3))
	_shadow.color = Color(acc.r, acc.g, acc.b, 0.35)
	_shadow.z_index = -1
	add_child(_shadow)
	move_child(_shadow, 0)
	## Gun barrel (rotates with aim)
	_gun_poly = Polygon2D.new()
	_gun_poly.polygon = PackedVector2Array([Vector2(6, -3), Vector2(26, -3), Vector2(26, 3), Vector2(6, 3)])
	_gun_poly.color = Color(0.22, 0.2, 0.19)
	gun.add_child(_gun_poly)
	var stripe := Polygon2D.new()
	stripe.polygon = PackedVector2Array([Vector2(10, -3), Vector2(16, -3), Vector2(16, 3), Vector2(10, 3)])
	stripe.color = _char.get("accent", Color(0.9, 0.7, 0.3))
	_gun_poly.add_child(stripe)
	_muzzle = Polygon2D.new()
	_muzzle.polygon = PackedVector2Array([Vector2(26, 0), Vector2(36, -7), Vector2(46, 0), Vector2(36, 7)])
	_muzzle.color = Color(1.0, 0.85, 0.4, 0.95)
	_muzzle.visible = false
	gun.add_child(_muzzle)
	## Faint aim guide while the aim stick is held
	_aim_line = Line2D.new()
	_aim_line.width = 2.0
	_aim_line.default_color = Color(1.0, 0.6, 0.35, 0.28)
	_aim_line.points = PackedVector2Array([Vector2(30, 0), Vector2(260, 0)])
	_aim_line.visible = false
	gun.add_child(_aim_line)
	gun.z_index = 1


## =============================================================================
func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_tick_buffs(delta)
	_update_movement(delta)
	_update_aim_and_fire(delta)
	_update_actions()
	_update_regen(delta)
	_update_visuals(delta)


func _tick_timers(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_ability_cd = maxf(0.0, _ability_cd - delta)
	_post_heal_left = maxf(0.0, _post_heal_left - delta)
	_rush_left = maxf(0.0, _rush_left - delta)
	_iframes = maxf(0.0, _iframes - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_flash_left = maxf(0.0, _flash_left - delta)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			_ammo = _mag_size()
			ammo_changed.emit(_ammo, _mag_size(), false)


func _current_speed() -> float:
	var s := base_speed * move_mult * _buff_move()
	if _rush_left > 0.0:
		s *= float(_ability.get("speed_mult", 1.3))
	if _mounted and float(_mount.get("fuel", 0)) > 0.0:
		s *= float(_mount.get("speed_mult", 1.4))
	## Slightly slower while shooting so dodging is a choice, not automatic.
	if TouchInput.is_firing() and not _mounted:
		s *= 0.88
	return s


func _update_movement(delta: float) -> void:
	var dir := TouchInput.get_move()
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _dash_dir * DASH_SPEED
		move_and_slide()
		if int(_dash_left * 60.0) % 2 == 0:
			_spawn_afterimage()
		return
	var target := dir * _current_speed()
	var rate := accel if dir.length() > 0.01 else decel
	## Reversing? Snap harder so it doesn't feel like ice.
	if dir.length() > 0.01 and velocity.length() > 10.0 and velocity.normalized().dot(dir.normalized()) < 0.2:
		rate *= turn_boost
	velocity = velocity.move_toward(target, rate * delta)
	move_and_slide()
	_try_mount_ram()
	if _mounted:
		_mount["fuel"] = float(_mount["fuel"]) - float(_mount.get("fuel_burn", 4.0)) * delta * (0.3 + dir.length())
		if float(_mount["fuel"]) <= 0.0:
			_set_mounted(false)


func _update_aim_and_fire(_delta: float) -> void:
	var aim_dir := _aim_direction()
	if aim_dir.length() > 0.01:
		_last_aim = aim_dir
	gun.rotation = lerp_angle(gun.rotation, _last_aim.angle(), 0.55)
	body.flip_h = _last_aim.x < 0.0
	gun.z_index = -1 if _last_aim.y < -0.3 else 1
	## Show aim guide while twin-stick aiming, or while single-stick run-firing.
	var show_guide := TouchInput.aim_vector.length() > 0.01
	if TouchInput.is_single_stick() and TouchInput.is_move_aiming() and TouchInput.is_auto_fire():
		show_guide = true
	_aim_line.visible = show_guide
	if TouchInput.is_firing() and _reload_left <= 0.0 and _dash_left <= 0.0:
		_try_shoot()
	if Input.is_action_just_pressed("reload") and _ammo < _mag_size() and _reload_left <= 0.0:
		_start_reload()


func _update_actions() -> void:
	if Input.is_action_just_pressed("mount_toggle") or TouchInput.consume_mount():
		_toggle_mount()
	if Input.is_action_just_pressed("ability") or TouchInput.consume_ability():
		_try_ability()
	if TouchInput.consume_dash():
		_try_dash()


func _update_regen(delta: float) -> void:
	if velocity.length() < 10.0 and not TouchInput.is_firing():
		_oos_timer += delta
	else:
		_oos_timer = 0.0
	if _oos_timer > 1.5 and hp < max_hp:
		hp = minf(max_hp, hp + float(_armor.get("regen_oos", 0.0)) * delta)
		health_changed.emit(hp, max_hp)


func _update_visuals(delta: float) -> void:
	var moving := velocity.length() > 30.0
	## Walk bob + squash
	if moving and not _mounted:
		_bob_t += delta * 14.0 * clampf(velocity.length() / base_speed, 0.5, 1.6)
		body.position.y = -absf(sin(_bob_t)) * 3.0
		body.scale = Vector2(1.0 + sin(_bob_t * 2.0) * 0.03, 1.0 - sin(_bob_t * 2.0) * 0.03)
		_step_t += delta
		if _step_t > 0.26:
			_step_t = 0.0
			Juice.dust_puff(global_position + Vector2(0, 18), 3)
	else:
		body.position.y = lerpf(body.position.y, 0.0, 0.3)
		body.scale = body.scale.lerp(Vector2.ONE, 0.3)
	## Recoil
	_recoil = lerpf(_recoil, 0.0, clampf(delta * 18.0, 0.0, 1.0))
	_gun_poly.position.x = -_recoil
	_muzzle.visible = _flash_left > 0.0
	## Blink during i-frames
	if _iframes > 0.0 and _dash_left <= 0.0:
		body.modulate.a = 0.45 if int(_iframes * 30.0) % 2 == 0 else 1.0
	else:
		body.modulate.a = 1.0


## =============================================================================
## Buffs

func _buff_move() -> float:
	return 1.35 if _buffs.has("speed") else 1.0


func _buff_damage() -> float:
	return 1.45 if _buffs.has("damage") else 1.0


func _buff_firerate() -> float:
	var f := firerate_mult
	if _post_heal_left > 0.0:
		f *= float(_char.get("post_heal_firerate_mult", 1.0))
	if _buffs.has("rapid"):
		f *= 1.75
	return f


func _tick_buffs(delta: float) -> void:
	var changed := false
	for id in _buffs.keys():
		_buffs[id]["time_left"] = float(_buffs[id]["time_left"]) - delta
		if float(_buffs[id]["time_left"]) <= 0.0:
			_buffs.erase(id)
			changed = true
	resist_mult = 0.55 if _buffs.has("shield") else 1.0
	if changed:
		buffs_changed.emit(_buffs)


func apply_powerup(def: Dictionary) -> void:
	var id := str(def.get("id", ""))
	Juice.sfx("pickup")
	Juice.haptic(15)
	Juice.burst(global_position, def.get("color", Color.WHITE), 16, 180.0, 0.5)
	Juice.float_text(global_position + Vector2(0, -30), str(def.get("name", "Boost")), def.get("color", Color.WHITE), 20)
	if id == "heal" or def.has("instant_heal"):
		var amt := float(def.get("instant_heal", 35.0))
		hp = minf(max_hp, hp + amt)
		health_changed.emit(hp, max_hp)
	var dur := float(def.get("duration", 10.0))
	if dur > 0.2:
		_buffs[id] = {"time_left": dur, "def": def}
	buffs_changed.emit(_buffs)
	if id == "magnet":
		GameState.add_scrap(randi_range(4, 8))


func get_active_buffs() -> Dictionary:
	return _buffs


## =============================================================================
## Dash

func _try_dash() -> void:
	if _dash_cd > 0.0 or _dash_left > 0.0:
		return
	var dir := TouchInput.get_move()
	if dir.length() < 0.1:
		dir = velocity.normalized() if velocity.length() > 20.0 else _last_aim
	_dash_dir = dir.normalized()
	_dash_left = DASH_TIME
	_dash_cd = DASH_COOLDOWN
	_iframes = maxf(_iframes, DASH_IFRAMES)
	Juice.sfx("dash")
	Juice.dust_puff(global_position + Vector2(0, 16), 8)
	dashed.emit()


func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = body.texture
	ghost.flip_h = body.flip_h
	ghost.global_position = body.global_position
	ghost.modulate = Color(0.6, 0.95, 0.85, 0.5)
	ghost.z_index = -1
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ghost.queue_free)


func get_dash_cooldown_ratio() -> float:
	return _dash_cd / DASH_COOLDOWN


## =============================================================================
## Mount

func _try_mount_ram() -> void:
	if not _mounted:
		return
	for i in range(get_slide_collision_count()):
		var collider := get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("breakables") and collider.has_method("take_damage"):
			collider.take_damage(40.0)


func can_mount() -> bool:
	return bool(_mount.get("usable", false)) and float(_mount.get("fuel", 0)) > 0.0


func _toggle_mount() -> void:
	if not _mounted and not can_mount():
		Juice.sfx("empty")
		return
	_set_mounted(not _mounted)


func _set_mounted(on: bool) -> void:
	_mounted = on
	mount_visual.visible = _mounted
	GameState.mount["mounted"] = _mounted
	if on:
		Juice.sfx("mount")
		Juice.dust_puff(global_position + Vector2(0, 16), 6)


func is_mounted() -> bool:
	return _mounted


## =============================================================================
## Ability (data-driven from character_defs "ability")

func has_ability() -> bool:
	return not _ability.is_empty()


func get_ability_short_name() -> String:
	return str(_ability.get("short", "ABILITY"))


func _ability_cooldown() -> float:
	var cd := float(_ability.get("cooldown", 12.0))
	var reduce := float(GameState.run_mods.get("ability_cd", 0.0))
	return cd * maxf(0.4, 1.0 - reduce)


func get_ability_cooldown_ratio() -> float:
	var cd := _ability_cooldown()
	return _ability_cd / cd if cd > 0.0 else 0.0


func _try_ability() -> void:
	if not has_ability():
		return
	if _ability_cd > 0.0:
		Juice.sfx("empty", -6.0)
		return
	_ability_cd = _ability_cooldown()
	match str(_ability.get("id", "")):
		"field_draught":
			var amt := float(_ability.get("heal", 28.0))
			hp = minf(max_hp, hp + amt)
			_post_heal_left = float(_char.get("post_heal_duration", 0.0))
			health_changed.emit(hp, max_hp)
			Juice.float_text(global_position + Vector2(0, -34), "+%d" % int(amt), UiTheme.TEAL, 22)
			Juice.burst(global_position, UiTheme.TEAL, 18, 140.0, 0.6)
		"rattle_rush":
			_rush_left = float(_ability.get("duration", 3.0))
			_iframes = maxf(_iframes, 0.3)
			Juice.burst(global_position, UiTheme.AMBER, 16, 160.0, 0.5)
			for crate in get_tree().get_nodes_in_group("breakables"):
				if crate is Node2D and global_position.distance_to((crate as Node2D).global_position) < 900.0:
					if crate.has_method("ping"):
						crate.call("ping")
		_:
			pass
	Juice.sfx("ability")
	ability_used.emit(str(_ability.get("name", "Ability")))


## =============================================================================
## Aiming & shooting

func _aim_direction() -> Vector2:
	## Single-stick survivor: run direction IS aim + fire vector (primary).
	if TouchInput.is_single_stick():
		var move := TouchInput.get_move()
		if move.length() >= TouchInput.MOVE_FIRE_THRESHOLD:
			return move.normalized()
		## Idle: keep last facing after you stop. Nearest-enemy only when
		## holding FIRE (or at spawn with no facing yet).
		if TouchInput.is_button_firing() and GameState.settings.get("auto_aim", true):
			var nearest := _nearest_enemy_dir(720.0)
			if nearest.length() > 0.01:
				return nearest
		if _last_aim.length() < 0.01 and GameState.settings.get("auto_aim", true):
			var spawn_aim := _nearest_enemy_dir(720.0)
			if spawn_aim.length() > 0.01:
				return spawn_aim
		## Desktop: mouse aim while idle + clicking
		if not TouchInput.touch_primary and TouchInput.is_firing():
			var to_mouse := get_global_mouse_position() - global_position
			if to_mouse.length() > 1.0:
				return to_mouse.normalized()
		return _last_aim

	## Twin-stick / legacy:
	## 1) Aim stick (with optional assist toward enemies near the aim line)
	if TouchInput.aim_vector.length() > 0.01:
		return _assisted(TouchInput.aim_vector)
	## 2) FIRE button → nearest enemy
	if TouchInput.is_button_firing() and GameState.settings.get("auto_aim", true):
		var nearest2 := _nearest_enemy_dir(720.0)
		if nearest2.length() > 0.01:
			return nearest2
	## 3) Desktop mouse
	if not TouchInput.touch_primary:
		var to_mouse2 := get_global_mouse_position() - global_position
		if to_mouse2.length() > 1.0:
			return to_mouse2.normalized()
	## 4) Otherwise face where you're moving
	if velocity.length() > 30.0 and not TouchInput.is_firing():
		return velocity.normalized()
	return _last_aim


func _assisted(stick: Vector2) -> Vector2:
	var strength := float(GameState.settings.get("aim_assist", 0.6))
	if strength <= 0.01:
		return stick
	var cone := deg_to_rad(8.0 + 14.0 * strength)
	var best: Vector2 = Vector2.ZERO
	var best_score := INF
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var to := (n as Node2D).global_position - global_position
		var d := to.length()
		if d > 620.0 or d < 1.0:
			continue
		var ang := absf(stick.angle_to(to))
		if ang > cone:
			continue
		var score := ang * 300.0 + d * 0.3
		if score < best_score:
			best_score = score
			best = to.normalized()
	if best == Vector2.ZERO:
		return stick
	return stick.slerp(best, 0.55 + 0.35 * strength).normalized()


func _nearest_enemy_dir(max_d: float) -> Vector2:
	var best: Node2D = null
	var best_d := max_d
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var d := global_position.distance_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n as Node2D
	if best == null:
		return Vector2.ZERO
	return (best.global_position - global_position).normalized()


func _try_shoot() -> void:
	if _fire_cd > 0.0:
		return
	if _ammo <= 0:
		_start_reload()
		return
	var rate := float(_weapon.get("fire_rate", 8.0)) * _buff_firerate()
	_fire_cd = 1.0 / maxf(0.1, rate)
	_ammo -= 1
	var aim := _last_aim
	var spread := deg_to_rad(float(_weapon.get("spread_deg", 6.0)))
	if _buffs.has("quiet"):
		spread *= 0.7
	## Tighter while standing still — rewards planting your feet.
	if velocity.length() < 30.0:
		spread *= 0.6
	aim = aim.rotated(randf_range(-spread, spread))
	var bullet: Area2D = BulletScene.instantiate()
	bullet.setup(
		global_position + aim * 28.0,
		aim,
		float(_weapon.get("projectile_speed", 720.0)),
		float(_weapon.get("damage", 12)) * damage_mult * _buff_damage(),
		true
	)
	get_tree().current_scene.add_child(bullet)
	_recoil = 5.0
	_flash_left = 0.045
	Juice.sfx("shot", -4.0)
	Juice.shake(0.035)
	ammo_changed.emit(_ammo, _mag_size(), false)
	GameState.weapon["weapon_xp"] = int(GameState.weapon.get("weapon_xp", 0)) + 1
	if int(GameState.weapon["weapon_xp"]) >= 20 * int(GameState.weapon.get("weapon_level", 1)):
		GameState.weapon["weapon_level"] = int(GameState.weapon.get("weapon_level", 1)) + 1
	if _ammo <= 0:
		_start_reload()


func _start_reload() -> void:
	if _reload_left > 0.0:
		return
	_reload_left = float(_weapon.get("reload_time", 1.4))
	Juice.sfx("reload")
	ammo_changed.emit(0, _mag_size(), true)


func get_reload_ratio() -> float:
	var t := float(_weapon.get("reload_time", 1.4))
	return 1.0 - _reload_left / t if _reload_left > 0.0 else 1.0


## =============================================================================
## Damage

func take_damage(amount: float) -> void:
	if _iframes > 0.0 or hp <= 0.0:
		return
	var dmg := amount * resist_mult
	hp -= dmg
	_iframes = 0.12
	Juice.sfx("hurt")
	Juice.shake(0.28)
	Juice.haptic(30)
	Juice.flash(body, Color(2.5, 0.6, 0.5), 0.15)
	Juice.float_text(global_position + Vector2(0, -30), "-%d" % int(round(dmg)), UiTheme.DANGER, 18)
	if hp <= 0.0 and _last_stitch_available:
		_last_stitch_available = false
		hp = 1.0
		_iframes = 1.2
		Juice.float_text(global_position + Vector2(0, -50), "LAST STITCH!", UiTheme.TEAL, 24)
		health_changed.emit(hp, max_hp)
		return
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		Juice.burst(global_position, Color(0.9, 0.3, 0.2), 30, 240.0, 0.7, 1.5)
		Juice.hitstop(0.12)
		remove_from_group("player")
		died.emit()
		set_physics_process(false)
		visible = false
		collision_layer = 0


func is_dashing() -> bool:
	return _dash_left > 0.0


## =============================================================================
## HUD text helpers

func get_ammo_text() -> String:
	if _reload_left > 0.0:
		return "RELOADING"
	return "%d / %d" % [_ammo, _mag_size()]


func get_ammo() -> int:
	return _ammo


func get_mag_size() -> int:
	return _mag_size()


func is_reloading() -> bool:
	return _reload_left > 0.0


func get_mount_text() -> String:
	if not bool(_mount.get("usable", false)):
		return "Mount locked"
	return "%s · %d fuel%s" % [str(_mount.get("name", "Mount")), int(float(_mount.get("fuel", 0))), " (riding)" if _mounted else ""]
