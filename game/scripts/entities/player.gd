extends CharacterBody2D

signal died
signal health_changed(current: float, maximum: float)
signal buffs_changed(buffs: Dictionary)
signal ammo_changed(ammo: int, mag: int, reloading: bool)
signal dashed
signal ability_used(name: String)
## Fired when this player actually loses HP to an enemy (pets listen — Noel enrages).
signal attacked(attacker: Node)
## Fired when the player takes damage (HUD red edge flash).
signal hurt(amount: float)

const BulletScene := preload("res://scenes/entities/bullet.tscn")
const DroneScript := preload("res://scripts/entities/helm_drone.gd")
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
## Invulnerability after taking a hit (prevents shotgun-stacked damage).
const HURT_IFRAMES := 0.5
## Targeting: keep the current target unless another is 10% closer, and keep it
## until it leaves trigger_range × (1 + hysteresis).
const TARGET_HYSTERESIS := 0.10
## Rough enemy body radius added to melee reach (centre-to-centre distances).
const ENEMY_BODY_R := 16.0

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
var _oos_timer: float = 0.0
var _iframes: float = 0.0
var _dash_left: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _step_t: float = 0.0
var _flash_left: float = 0.0
var _attack_hold: float = 0.0 ## >0 shortly after an attack (slows, faces target)
var _last_aim: Vector2 = Vector2.RIGHT
var _facing_left: bool = false
var _char: Dictionary = {}
var _weapon: Dictionary = {}
var _armor: Dictionary = {}
var _buffs: Dictionary = {}  ## id -> {time_left, def}
var _ability: Dictionary = {}
var _target: Node2D = null
var _swing_left: float = -1.0 ## counts down to the melee impact moment
var _swing_dir: Vector2 = Vector2.RIGHT
var _swing_index: int = 0
var _drones: Array = []

@onready var body: Sprite2D = $Body
@onready var gun: Node2D = $Gun
@onready var label: Label = $NameLabel
@onready var camera: Camera2D = $Camera2D

## Sheet-detail heroes at survivor portrait FOV (~1/14 of 720-wide).
const BODY_FOV_PX := 52.0
var _body_base_scale: float = 1.0
var _walk: RefCounted = UnitAnim.new()
var _attack_flash: float = 0.0

var _muzzle_flash: Polygon2D
var _shadow: Polygon2D

func _ready() -> void:
	add_to_group("player")
	_apply_loadout()
	hp = max_hp
	health_changed.emit(hp, max_hp)
	_build_visuals()
	if camera.has_method("set_target"):
		camera.call("set_target", self)
	_sync_drones.call_deferred()

func _apply_loadout() -> void:
	_char = GameState.get_character()
	_weapon = GameState.weapon
	_armor = GameState.armor
	_ability = _char.get("ability", {})
	_refresh_run_stats(true)
	_last_stitch_available = bool(_char.get("has_last_stitch", false))
	var still_path := str(_char.get("sprite", "res://assets/sprites/characters/ash_rook.png"))
	var still := load(still_path) as Texture2D
	body.texture = still
	var walk_path := still_path.replace(".png", "_walk.png")
	_walk.setup_from_walk_path(walk_path, still)
	_sync_body_fov_scale()
	label.text = str(_char.get("display_name", "Wanderer"))
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", _char.get("accent", Color(0.9, 0.8, 0.5)))
	if not GameState.loadout_changed.is_connected(_on_loadout_changed):
		GameState.loadout_changed.connect(_on_loadout_changed)

func _sync_body_fov_scale() -> void:
	## Walk frames are 96×96 cells; stills may vary — normalize to FOV footprint.
	var tw := 96.0
	if body.texture != null:
		if body.texture is AtlasTexture:
			tw = (body.texture as AtlasTexture).region.size.x
		else:
			tw = float(body.texture.get_width())
			if tw >= 192.0:
				tw = 96.0
	_body_base_scale = BODY_FOV_PX / maxf(tw, 1.0)
	body.scale = Vector2.ONE * _body_base_scale
	_walk.set_base_scale(_body_base_scale)

func _on_loadout_changed() -> void:
	## In-run upgrade pick or meta refresh mid-match.
	var old_max := max_hp
	_refresh_run_stats(false)
	if max_hp > old_max:
		hp = minf(max_hp, hp + (max_hp - old_max))
		health_changed.emit(hp, max_hp)
	ammo_changed.emit(_ammo, _mag_size(), _reload_left > 0.0)
	_sync_drones()

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
	move_mult = float(_char.get("move_speed_mult", 1.0)) \
		* (1.0 + float(rm.get("move", 0.0))) \
		* (1.0 + GameState.move_speed_bonus())
	firerate_mult = 1.0 + float(rm.get("firerate", 0.0))
	if reset_ammo:
		_ammo = _mag_size()

func is_melee() -> bool:
	return _weapon.has("melee")

func _mag_size() -> int:
	if is_melee():
		return 0
	return int(_weapon.get("mag_size", 24)) + int(GameState.run_mods.get("mag", 0.0))

func _build_visuals() -> void:
	## Soft ground shadow (no coloured ring — reads as a bar at survivor zoom).
	_shadow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * 15.0, sin(a) * 5.0 + 22.0))
	_shadow.polygon = pts
	_shadow.color = Color(0.05, 0.03, 0.02, 0.32)
	_shadow.z_index = -1
	add_child(_shadow)
	move_child(_shadow, 0)
	## Muzzle flash (a 4-point star, additive) placed at the per-hero muzzle.
	_muzzle_flash = Polygon2D.new()
	_muzzle_flash.polygon = PackedVector2Array([
		Vector2(-3, 0), Vector2(0, -5), Vector2(16, 0), Vector2(0, 5),
	])
	_muzzle_flash.color = Color(1.0, 0.85, 0.45, 0.95)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_muzzle_flash.material = add
	_muzzle_flash.visible = false
	gun.add_child(_muzzle_flash)
	gun.z_index = 2

## Helm's drones: count = weapon base + Extra Drone run picks (max 4).
func _sync_drones() -> void:
	if not is_inside_tree():
		return
	var base := int(_weapon.get("drone_count", 0))
	if base <= 0:
		return
	var want := clampi(base + int(GameState.run_mods.get("drones", 0.0)), 0, int(_weapon.get("drone_max", 4)))
	while _drones.size() < want:
		var d := Node2D.new()
		d.set_script(DroneScript)
		get_parent().add_child(d)
		d.call("setup", self, _drones.size(), _weapon)
		_drones.append(d)
	for d in _drones:
		if is_instance_valid(d):
			d.call("set_slot", _drones.find(d), want)

func get_drones() -> Array:
	return _drones

## =============================================================================
func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_tick_buffs(delta)
	_update_movement(delta)
	_update_combat(delta)
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
	_attack_hold = maxf(0.0, _attack_hold - delta)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			_ammo = _mag_size()
			ammo_changed.emit(_ammo, _mag_size(), false)

func is_attacking() -> bool:
	return _attack_hold > 0.0

func _current_speed() -> float:
	var s := base_speed * move_mult * _buff_move()
	if _rush_left > 0.0:
		s *= float(_ability.get("speed_mult", 1.3))
	## Slightly slower while attacking so dodging is a choice, not automatic.
	if _attack_hold > 0.0:
		s *= 0.9
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

func _update_actions() -> void:
	if Input.is_action_just_pressed("ability") or TouchInput.consume_ability():
		_try_ability()
	if TouchInput.consume_dash():
		_try_dash()

func _update_regen(delta: float) -> void:
	if velocity.length() < 10.0 and _attack_hold <= 0.0:
		_oos_timer += delta
	else:
		_oos_timer = 0.0
	if _oos_timer > 1.5 and hp < max_hp:
		hp = minf(max_hp, hp + float(_armor.get("regen_oos", 0.0)) * delta)
		health_changed.emit(hp, max_hp)

func _facing_dir() -> Vector2:
	return Vector2.LEFT if _facing_left else Vector2.RIGHT

func _update_visuals(delta: float) -> void:
	_attack_flash = maxf(0.0, _attack_flash - delta)
	var moving := velocity.length() > 30.0
	## Face the target while attacking, otherwise face where you run.
	if _attack_hold > 0.0 and absf(_last_aim.x) > 0.05:
		_facing_left = _last_aim.x < 0.0
	elif absf(velocity.x) > 20.0:
		_facing_left = velocity.x < 0.0
	body.flip_h = _facing_left
	## 4-frame walk strip + procedural bob/lean (sheet look locked).
	_walk.tick(body, velocity if moving else Vector2.ZERO, delta, {
		"move_thresh": 30.0,
		"speed_ref": base_speed,
		"bob_amp": 3.5,
		"attack": _attack_flash > 0.0,
	})
	if moving:
		_step_t += delta
		if _step_t > 0.26:
			_step_t = 0.0
			Juice.dust_puff(global_position + Vector2(0, 18), 3)
	_muzzle_flash.visible = _flash_left > 0.0
	if _muzzle_flash.visible:
		_muzzle_flash.position = _muzzle_offset()
		_muzzle_flash.rotation = _last_aim.angle()
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
		dir = velocity.normalized() if velocity.length() > 20.0 else _facing_dir()
	_dash_dir = dir.normalized()
	_dash_left = DASH_TIME
	_dash_cd = DASH_COOLDOWN * GameState.dash_cooldown_mult()
	## Dust Lungs (endurance stub) stretches dash i-frames modestly.
	_iframes = maxf(_iframes, DASH_IFRAMES * GameState.endurance_iframe_mult())
	Juice.sfx("dash")
	Juice.dust_puff(global_position + Vector2(0, 16), 8)
	dashed.emit()

func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = body.texture
	ghost.flip_h = body.flip_h
	ghost.scale = body.scale
	ghost.global_position = body.global_position
	ghost.modulate = Color(0.6, 0.95, 0.85, 0.5)
	ghost.z_index = -1
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ghost.queue_free)

func get_dash_cooldown_ratio() -> float:
	var cd := DASH_COOLDOWN * GameState.dash_cooldown_mult()
	return clampf(_dash_cd / cd, 0.0, 1.0) if cd > 0.0 else 0.0

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
	return clampf(_ability_cd / cd, 0.0, 1.0) if cd > 0.0 else 0.0

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
## Targeting & attacks (auto: fire / swing only when an enemy is in range)

func get_trigger_range() -> float:
	return float(_weapon.get("trigger_range", 400.0))

func get_target() -> Node2D:
	return _target if _target != null and is_instance_valid(_target) else null

## Muzzle offset in local space (x mirrored with facing).
func _muzzle_offset() -> Vector2:
	var m: Vector2 = _weapon.get("muzzle", Vector2(18, -4))
	return Vector2(-m.x if _facing_left else m.x, m.y)

func muzzle_global() -> Vector2:
	return global_position + _muzzle_offset()

## True when a world point is inside the visible screen (never target off-screen).
static func is_on_screen(node: Node2D, world_pos: Vector2, margin: float = 6.0) -> bool:
	var vp := node.get_viewport()
	if vp == null:
		return true
	var screen: Vector2 = vp.get_canvas_transform() * world_pos
	var r := vp.get_visible_rect()
	return screen.x >= r.position.x + margin and screen.y >= r.position.y + margin \
		and screen.x <= r.end.x - margin and screen.y <= r.end.y - margin

## Distance used for range checks: melee measures to the enemy's edge.
func _reach_dist(e: Node2D, from: Vector2) -> float:
	var d := from.distance_to(e.global_position)
	if is_melee():
		d -= ENEMY_BODY_R * float(e.get("body_scale") if "body_scale" in e else 1.0)
	return d

## Closest on-screen enemy within range; keeps the current target unless a new
## one is 10% closer (hysteresis) and drops it beyond range × 1.1.
func _pick_target(range_px: float) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		var d := _reach_dist(e, global_position)
		if d > range_px or d >= best_d:
			continue
		if not is_on_screen(self, e.global_position):
			continue
		best = e
		best_d = d
	var cur := get_target()
	if cur != null and cur.is_in_group("enemies") and is_on_screen(self, cur.global_position):
		var cd := _reach_dist(cur, global_position)
		if cd <= range_px * (1.0 + TARGET_HYSTERESIS):
			if best == null or best == cur or best_d > cd * (1.0 - TARGET_HYSTERESIS):
				return cur
	return best

func _update_combat(delta: float) -> void:
	## Pending melee impact lands even mid-dash (the swing already started).
	if _swing_left >= 0.0:
		_swing_left -= delta
		if _swing_left < 0.0:
			_melee_impact()
	if _dash_left > 0.0:
		return
	if Input.is_action_just_pressed("reload") and not is_melee() and _ammo < _mag_size() and _reload_left <= 0.0:
		_start_reload()
	## Re-evaluate the target every frame (cheap: ≤ ~14 mobs) — every shot uses the
	## closest one in range.
	_target = _pick_target(get_trigger_range())
	if _target == null:
		## Nothing in range: top the mag up so the next fight starts loaded.
		if not is_melee() and _reload_left <= 0.0 and _ammo < _mag_size():
			_start_reload()
		return
	var to := _target.global_position - global_position
	if to.length() > 0.5:
		_last_aim = to.normalized()
	_attack_hold = 0.35
	if _fire_cd > 0.0 or _swing_left >= 0.0:
		return
	if is_melee():
		_start_swing()
	else:
		_try_shoot()

func _try_shoot() -> void:
	if _reload_left > 0.0:
		return
	if _ammo <= 0:
		_start_reload()
		return
	var rate := float(_weapon.get("fire_rate", 8.0)) * _buff_firerate()
	_fire_cd = 1.0 / maxf(0.1, rate)
	_fire_one_shot()

func _roll_damage() -> Array:
	var dmg := float(_weapon.get("damage", 12)) * damage_mult * _buff_damage()
	var crit := false
	if randf() < GameState.crit_chance():
		crit = true
		dmg *= 1.5 + GameState.crit_damage_bonus()
	return [dmg, crit]

func _fire_one_shot() -> void:
	_ammo -= 1
	var origin := muzzle_global()
	var aim := _last_aim
	var tgt := get_target()
	if tgt != null:
		var from_muzzle := tgt.global_position - origin
		if from_muzzle.length() > 24.0:
			aim = from_muzzle.normalized()
	var spread := deg_to_rad(float(_weapon.get("spread_deg", 3.0)))
	if _buffs.has("quiet"):
		spread *= 0.7
	aim = aim.rotated(randf_range(-spread, spread))
	var roll := _roll_damage()
	var bullet: Area2D = BulletScene.instantiate()
	bullet.setup(
		origin,
		aim,
		float(_weapon.get("projectile_speed", 720.0)),
		float(roll[0]),
		true,
		self,
		float(_weapon.get("lifetime", -1.0)),
		float(_weapon.get("splash_radius", 0.0)),
		float(_weapon.get("splash_mult", 0.5))
	)
	bullet.set("style", str(_weapon.get("projectile", "pistol")))
	bullet.set("crit", bool(roll[1]))
	get_tree().current_scene.add_child(bullet)
	_flash_left = 0.05
	_attack_flash = 0.12
	Juice.sfx("shot", -4.0)
	Juice.shake(float(_weapon.get("shake", 0.035)))
	ammo_changed.emit(_ammo, _mag_size(), false)
	GameState.weapon["weapon_xp"] = int(GameState.weapon.get("weapon_xp", 0)) + 1
	if _ammo <= 0:
		_start_reload()

## --- Melee -------------------------------------------------------------------

func _start_swing() -> void:
	var m: Dictionary = _weapon["melee"]
	var rate := float(_weapon.get("fire_rate", 1.0)) * _buff_firerate()
	_fire_cd = 1.0 / maxf(0.1, rate)
	_swing_dir = _last_aim
	var alt := deg_to_rad(float(m.get("alternate_deg", 0.0)))
	if alt > 0.0:
		## Twin blades: alternate the slash left / right of the target line.
		_swing_dir = _swing_dir.rotated(alt if _swing_index % 2 == 0 else -alt)
	_swing_index += 1
	_swing_left = float(m.get("windup", 0.1))
	_attack_flash = 0.18
	Juice.sfx("dash", -10.0, 0.2)

## Damage is applied once, at the impact moment, to every enemy in the hitbox.
func _melee_impact() -> void:
	_swing_left = -1.0
	var m: Dictionary = _weapon["melee"]
	var shape := str(m.get("shape", "arc"))
	var hits := 0
	var any_crit := false
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n) or not n.has_method("take_damage"):
			continue
		var e := n as Node2D
		if not _in_melee_box(e, shape, m):
			continue
		var roll := _roll_damage()
		any_crit = any_crit or bool(roll[1])
		var dir := (e.global_position - global_position).normalized()
		e.call("take_damage", float(roll[0]), dir, float(m.get("knockback", 200.0)), bool(roll[1]))
		hits += 1
	for n in get_tree().get_nodes_in_group("breakables"):
		if n is Node2D and is_instance_valid(n) and n.has_method("take_damage") and _in_melee_box(n as Node2D, shape, m):
			n.call("take_damage", float(_weapon.get("damage", 12)) * damage_mult)
	_spawn_smear(shape, m)
	if hits > 0:
		Juice.hitstop(0.05)
		Juice.sfx("hit", -2.0)
		var sh := float(m.get("shake", 0.0))
		if sh > 0.0:
			Juice.shake(sh * (1.3 if any_crit else 1.0))
		GameState.weapon["weapon_xp"] = int(GameState.weapon.get("weapon_xp", 0)) + 1

func _in_melee_box(e: Node2D, shape: String, m: Dictionary) -> bool:
	var to := e.global_position - global_position
	var body_r := ENEMY_BODY_R * float(e.get("body_scale") if "body_scale" in e else 1.0)
	if shape == "line":
		var along := to.dot(_swing_dir)
		var side := absf(to.cross(_swing_dir))
		return along > -body_r and along <= float(m.get("length", 140.0)) + body_r \
			and side <= float(m.get("width", 30.0)) * 0.5 + body_r
	var d := to.length()
	if d > float(m.get("radius", 70.0)) + body_r:
		return false
	if d < body_r + 14.0:
		return true ## overlapping the hero — always caught
	var half := deg_to_rad(float(m.get("arc_deg", 120.0))) * 0.5
	return absf(_swing_dir.angle_to(to)) <= half + asin(clampf(body_r / d, 0.0, 1.0))

## Swing smear: a fading sector (arc) or streak (line) along the hitbox.
func _spawn_smear(shape: String, m: Dictionary) -> void:
	var col: Color = m.get("smear", Color(1, 0.9, 0.75))
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	if shape == "line":
		var length := float(m.get("length", 140.0))
		var w := float(m.get("width", 30.0)) * 0.35
		pts = PackedVector2Array([Vector2(10, -w * 0.5), Vector2(length, -w * 0.15), Vector2(length + 8, 0), Vector2(length, w * 0.15), Vector2(10, w * 0.5)])
	else:
		var r := float(m.get("radius", 70.0))
		var half := deg_to_rad(float(m.get("arc_deg", 120.0))) * 0.5
		var steps := 12
		for i in range(steps + 1):
			var a := lerpf(-half, half, float(i) / steps)
			pts.append(Vector2(cos(a), sin(a)) * r)
		for i in range(steps, -1, -1):
			var a2 := lerpf(-half, half, float(i) / steps)
			## Crescent: inner edge bulges toward the tip.
			var inner := r * (0.55 + 0.3 * absf(a2) / maxf(half, 0.01))
			pts.append(Vector2(cos(a2), sin(a2)) * inner)
	poly.polygon = pts
	poly.color = Color(col.r, col.g, col.b, 0.75)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	poly.material = add
	poly.rotation = _swing_dir.angle()
	poly.position = Vector2(0, -4)
	poly.z_index = 3
	add_child(poly)
	var tw := poly.create_tween()
	tw.set_parallel(true)
	tw.tween_property(poly, "modulate:a", 0.0, 0.16)
	tw.tween_property(poly, "scale", Vector2(1.08, 1.08), 0.16)
	tw.chain().tween_callback(poly.queue_free)

func _start_reload() -> void:
	if _reload_left > 0.0 or is_melee():
		return
	_reload_left = float(_weapon.get("reload_time", 1.4))
	Juice.sfx("reload")
	ammo_changed.emit(0, _mag_size(), true)

func get_reload_ratio() -> float:
	var t := float(_weapon.get("reload_time", 1.4))
	return 1.0 - _reload_left / t if _reload_left > 0.0 and t > 0.0 else 1.0

## =============================================================================
## Damage

func take_damage(amount: float, attacker: Node = null) -> void:
	if _iframes > 0.0 or hp <= 0.0:
		return
	## Dust Sidestep — full avoid (soft-capped in GameState).
	if randf() < GameState.dodge_chance():
		_iframes = 0.2
		Juice.float_text(global_position + Vector2(0, -30), "DODGE", UiTheme.TEAL, 16)
		Juice.sfx("dash", -8.0)
		return
	var dmg := float(amount) * resist_mult
	## Brace Plate — half damage on proc (full rate with block_affinity kits).
	if randf() < GameState.block_chance():
		dmg *= 0.5
		Juice.float_text(global_position + Vector2(0, -42), "BLOCK", UiTheme.AMBER, 14)
	hp -= dmg
	_iframes = HURT_IFRAMES
	if attacker != null and is_instance_valid(attacker) and attacker != self:
		attacked.emit(attacker)
	hurt.emit(dmg)
	Juice.sfx("hurt")
	Juice.shake(0.28)
	Juice.haptic(30)
	Juice.flash(body, Color(2.5, 0.6, 0.5), 0.15)
	Juice.damage_number(global_position + Vector2(0, -30), dmg, false, UiTheme.DANGER)
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
		for d in _drones:
			if is_instance_valid(d):
				d.queue_free()
		_drones.clear()

func heal(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)

func is_dashing() -> bool:
	return _dash_left > 0.0

## =============================================================================
## HUD text helpers

func get_ammo_text() -> String:
	if is_melee():
		return ""
	if _reload_left > 0.0:
		return "RELOADING"
	return "%d / %d" % [_ammo, _mag_size()]

func get_ammo() -> int:
	return _ammo

func get_mag_size() -> int:
	return _mag_size()

func is_reloading() -> bool:
	return _reload_left > 0.0
