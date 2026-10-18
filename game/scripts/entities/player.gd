extends CharacterBody2D

signal died
signal health_changed(current: float, maximum: float)
signal buffs_changed(buffs: Dictionary)
signal ammo_changed(ammo: int, mag: int, reloading: bool)
signal dashed
signal ability_used(name: String)
## Fired when this player actually loses HP to an enemy (pets listen — Noel enrages).
signal attacked(attacker: Node)

const BulletScene := preload("res://scenes/entities/bullet.tscn")
const DroneScene := preload("res://scenes/entities/drone.tscn")
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
var _burst_left: int = 0
var _burst_gap_left: float = 0.0
var _drone_cd: float = 1.0
var _scrap_drone_cd: float = 0.8
var _mine_cd: float = 0.0
var _blade_angle: float = 0.0
var _shield_charges: int = 0
var _shield_recharge: float = 0.0
var _stealth_left: float = 0.0
var _planted_t: float = 0.0 ## Bell Tower charge while standing still
var _quarry_hits: int = 0
var _supply_cd: float = 18.0
var _firewalk_spots: Array = [] ## recent fire trail positions
var _drone: Node2D = null ## visible scrap / wingman companion

@onready var body: Sprite2D = $Body
@onready var gun: Node2D = $Gun
@onready var mount_visual: Sprite2D = $MountVisual
@onready var label: Label = $NameLabel
@onready var camera: Camera2D = $Camera2D

## Sheet-detail heroes at survivor portrait FOV (~1/14 of 720-wide).
## Slightly larger heroes for readability (Phase 1).
const BODY_FOV_PX := 60.0
var _body_base_scale: float = 1.0
var _walk: RefCounted = UnitAnim.new()
var _attack_flash: float = 0.0

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
	_refresh_mount_visual()
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
		## If using atlas, region width is what matters.
		if body.texture is AtlasTexture:
			tw = (body.texture as AtlasTexture).region.size.x
		else:
			tw = float(body.texture.get_width())
			## Full walk strip? use one cell.
			if tw >= 192.0:
				tw = 96.0
	_body_base_scale = BODY_FOV_PX / maxf(tw, 1.0)
	body.scale = Vector2.ONE * _body_base_scale
	_walk.set_base_scale(_body_base_scale)

func _refresh_mount_visual() -> void:
	var mid := str(_mount.get("id", "skateboard"))
	var path := "res://assets/sprites/mounts/%s.png" % mid
	if not ResourceLoader.exists(path):
		path = "res://assets/sprites/mounts/skateboard.png"
	mount_visual.texture = load(path)


func _on_loadout_changed() -> void:
	## In-run upgrade pick or meta refresh mid-match.
	_mount = GameState.mount
	_refresh_mount_visual()
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
	move_mult = float(_char.get("move_speed_mult", 1.0)) \
		* (1.0 + float(rm.get("move", 0.0))) \
		* (1.0 + GameState.move_speed_bonus())
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
	var prev_rush := _rush_left
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_ability_cd = maxf(0.0, _ability_cd - delta)
	_post_heal_left = maxf(0.0, _post_heal_left - delta)
	_rush_left = maxf(0.0, _rush_left - delta)
	## Aftershock: RUSH ends in an explosion.
	if prev_rush > 0.0 and _rush_left <= 0.0 and float(GameState.run_mods.get("class_aftershock", 0.0)) > 0.0:
		_slam_nearby(110.0, 42.0)
		Juice.float_text(global_position + Vector2(0, -36), "AFTERSHOCK", UiTheme.AMBER, 16)
	_iframes = maxf(0.0, _iframes - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_flash_left = maxf(0.0, _flash_left - delta)
	_drone_cd = maxf(0.0, _drone_cd - delta)
	_scrap_drone_cd = maxf(0.0, _scrap_drone_cd - delta)
	_mine_cd = maxf(0.0, _mine_cd - delta)
	_supply_cd = maxf(0.0, _supply_cd - delta)
	_stealth_left = maxf(0.0, _stealth_left - delta)
	if _stealth_left <= 0.0 and modulate.a < 0.99:
		modulate.a = 1.0
	## Bell Tower: charge while standing still.
	if velocity.length() < 25.0 and float(GameState.run_mods.get("class_bell", 0.0)) > 0.0:
		_planted_t = minf(3.0, _planted_t + delta)
	else:
		_planted_t = maxf(0.0, _planted_t - delta * 2.0)
	## Iron Tonic shield recharge.
	if float(GameState.run_mods.get("shield", 0.0)) > 0.0:
		if _shield_charges <= 0:
			_shield_recharge -= delta
			if _shield_recharge <= 0.0:
				_shield_charges = 1
				_shield_recharge = 12.0
				Juice.float_text(global_position + Vector2(0, -30), "SHIELD", Color(0.7, 0.85, 1.0), 14)
	if _burst_left > 0:
		_burst_gap_left = maxf(0.0, _burst_gap_left - delta)
		if _burst_gap_left <= 0.0 and _reload_left <= 0.0 and _dash_left <= 0.0:
			_fire_one_shot(false)
			_burst_left -= 1
			if _burst_left > 0:
				_burst_gap_left = float(_weapon.get("burst_gap", 0.05))
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			_ammo = _mag_size()
			ammo_changed.emit(_ammo, _mag_size(), false)
	_tick_drone_assist()
	_tick_scrap_drone()
	_tick_spore_mines(delta)
	_tick_orbit_blades(delta)
	_tick_bayonet()
	_tick_supply_drop()
	_tick_firewalk_damage(delta)

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
			if float(GameState.run_mods.get("firewalk", 0.0)) > 0.0:
				_stamp_firewalk()
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
	## Face travel when running; face aim when standing / firing.
	if velocity.length() > 40.0 and not TouchInput.is_firing():
		body.flip_h = velocity.x < 0.0
	else:
		body.flip_h = _last_aim.x < 0.0
	gun.z_index = -1 if _last_aim.y < -0.3 else 1
	## Show aim guide while twin-stick aiming, or while single-stick run-firing.
	var show_guide := TouchInput.aim_vector.length() > 0.01
	if TouchInput.is_single_stick() and TouchInput.is_move_aiming() and TouchInput.is_auto_fire():
		show_guide = true
	_aim_line.visible = show_guide
	var want_fire := TouchInput.is_firing() and _reload_left <= 0.0 and _dash_left <= 0.0
	## Auto-fire only when an enemy is on screen (no dumping mag into empty dust).
	if want_fire and TouchInput.is_auto_fire() and not TouchInput.fire_held and not TouchInput.aim_stick_firing:
		if not _has_on_screen_enemy():
			want_fire = false
			## Idle / no target: start reload instead of dry-firing the mag empty.
			if _ammo < _mag_size() and _reload_left <= 0.0 and velocity.length() < 40.0:
				_start_reload()
	if want_fire:
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
	_attack_flash = maxf(0.0, _attack_flash - delta)
	var moving := velocity.length() > 30.0 and not _mounted
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
	var m := 1.0
	if _buffs.has("damage"):
		m *= 1.45
	if _buffs.has("vial"):
		m *= float(_ability.get("damage_mult", 1.35))
	return m

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
	_dash_cd = DASH_COOLDOWN * GameState.dash_cooldown_mult()
	## Dust Lungs (endurance stub) stretches dash i-frames modestly.
	_iframes = maxf(_iframes, DASH_IFRAMES * GameState.endurance_iframe_mult())
	## Second Wind: dashing heals a little.
	var heal_amt := float(GameState.run_mods.get("dash_heal", 0.0))
	if heal_amt > 0.0 and hp > 0.0:
		hp = minf(max_hp, hp + heal_amt)
		health_changed.emit(hp, max_hp)
		Juice.float_text(global_position + Vector2(0, -28), "+%d" % int(heal_amt), UiTheme.TEAL, 14)
	## Back Way Out: brief invisibility.
	if float(GameState.run_mods.get("class_stealth", 0.0)) > 0.0:
		_stealth_left = maxf(_stealth_left, 2.0)
		modulate.a = 0.35
	## Firewalk trail stamped during dash in _update_movement.
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
	return _dash_cd / cd if cd > 0.0 else 0.0

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
			## Station ranks + Sanctuary class pick deepen the heal.
			amt *= 1.0 + 0.08 * float(GameState.station_rank(str(_char.get("id", ""))))
			hp = minf(max_hp, hp + amt)
			_post_heal_left = float(_char.get("post_heal_duration", 0.0))
			health_changed.emit(hp, max_hp)
			Juice.float_text(global_position + Vector2(0, -34), "+%d" % int(amt), UiTheme.TEAL, 22)
			Juice.burst(global_position, UiTheme.TEAL, 18, 140.0, 0.6)
			if float(GameState.run_mods.get("class_sanctuary", 0.0)) > 0.0:
				_spawn_heal_puddle()
			if float(GameState.run_mods.get("class_burn", 0.0)) > 0.0 and hp < max_hp * 0.85:
				_burn_nearby(120.0, 12.0)
		"rattle_rush":
			_rush_left = float(_ability.get("duration", 3.0))
			_iframes = maxf(_iframes, 0.3)
			Juice.burst(global_position, UiTheme.AMBER, 16, 160.0, 0.5)
			for crate in get_tree().get_nodes_in_group("breakables"):
				if crate is Node2D and global_position.distance_to((crate as Node2D).global_position) < 900.0:
					if crate.has_method("ping"):
						crate.call("ping")
		"overload":
			_do_overload()
		"vial_shot":
			_buffs["vial"] = float(_ability.get("duration", 4.0))
			Juice.burst(global_position, Color(0.7, 0.4, 0.95), 14, 120.0, 0.45)
		"maul_slam":
			_rush_left = float(_ability.get("duration", 0.6))
			_iframes = maxf(_iframes, 0.25)
			_slam_nearby(90.0, 36.0)
		"shadow_cut":
			_rush_left = float(_ability.get("duration", 0.7))
			_iframes = maxf(_iframes, 0.45)
			modulate.a = 0.35
			Juice.burst(global_position, Color(0.4, 0.5, 0.9), 12, 100.0, 0.35)
		"rig_assist":
			_buffs["rapid"] = float(_ability.get("duration", 4.0))
			_buffs["speed"] = float(_ability.get("duration", 4.0))
			## Summon / refresh visible wingman drone + supply ammo crate.
			_ensure_drone("wingman", float(_weapon.get("drone_assist_damage", 10.0)) * 1.15, 0.7, 12.0)
			GameState.activate_special_ammo(GameState.roll_special_ammo())
			Juice.float_text(global_position + Vector2(0, -40), "WINGMAN!", UiTheme.AMBER, 16)
		"blade_rush":
			_rush_left = float(_ability.get("duration", 0.55))
			_iframes = maxf(_iframes, 0.2)
		_:
			_rush_left = float(_ability.get("duration", 0.0))
	Juice.sfx("ability")
	ability_used.emit(str(_ability.get("name", "Ability")))


func _do_overload() -> void:
	var radius := float(_ability.get("radius", 160.0))
	var dmg := float(_ability.get("damage", 28.0)) * damage_mult
	var stun := float(_ability.get("stun", 0.9))
	var arcs := int(_ability.get("arcs", 4))
	if float(GameState.run_mods.get("class_livewire", 0.0)) > 0.0:
		arcs += 3
		radius *= 1.2
	Juice.burst(global_position, Color(0.45, 0.8, 1.0), 28, radius, 0.55)
	Juice.shake(0.22)
	var hit: Array = []
	for n in get_tree().get_nodes_in_group("enemies"):
		if hit.size() >= arcs:
			break
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		if global_position.distance_to(e.global_position) > radius:
			continue
		hit.append(e)
		if e.has_method("take_damage"):
			e.call("take_damage", dmg, (e.global_position - global_position).normalized())
		if e.has_method("distract"):
			e.call("distract", stun)


func _slam_nearby(radius: float, dmg: float) -> void:
	Juice.burst(global_position, Color(0.95, 0.55, 0.4), 20, radius * 1.2, 0.45)
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		if global_position.distance_to(e.global_position) > radius:
			continue
		if e.has_method("take_damage"):
			e.call("take_damage", dmg * damage_mult, (e.global_position - global_position).normalized())
		if e.has_method("distract"):
			e.call("distract", 0.7)


func _burn_nearby(radius: float, dmg: float) -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		if global_position.distance_to(e.global_position) > radius:
			continue
		if e.has_method("take_damage"):
			e.call("take_damage", dmg, Vector2.ZERO)


func _spawn_heal_puddle() -> void:
	## Lightweight: burst heal aura once more after a short delay.
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if not is_instance_valid(self) or hp <= 0.0:
			return
		hp = minf(max_hp, hp + 10.0)
		health_changed.emit(hp, max_hp)
		Juice.burst(global_position, UiTheme.TEAL, 10, 80.0, 0.4)
	)

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
	var view := _camera_view_rect().grow(24.0)
	var best: Vector2 = Vector2.ZERO
	var best_score := INF
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		if not view.has_point(e.global_position):
			continue
		var to := e.global_position - global_position
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
	## Auto-aim must not target off-screen enemies.
	var best: Node2D = _nearest_on_screen_enemy(max_d)
	if best == null:
		return Vector2.ZERO
	return (best.global_position - global_position).normalized()


func _camera_view_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		## Fallback: generous circle around the player.
		return Rect2(global_position - Vector2(400, 700), Vector2(800, 1400))
	var vp := get_viewport().get_visible_rect().size
	var half := (vp / cam.zoom) * 0.5
	var center: Vector2 = cam.get_screen_center_position() if cam.has_method("get_screen_center_position") else cam.global_position
	return Rect2(center - half, half * 2.0)


func _has_on_screen_enemy() -> bool:
	return _nearest_on_screen_enemy(2400.0) != null


func _nearest_on_screen_enemy(max_d: float) -> Node2D:
	var view := _camera_view_rect().grow(24.0)
	var best: Node2D = null
	var best_d := max_d
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		if not view.has_point(e.global_position):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _try_shoot() -> void:
	if _fire_cd > 0.0 or _burst_left > 0:
		return
	if _ammo <= 0:
		_start_reload()
		return
	var rate := float(_weapon.get("fire_rate", 8.0)) * _buff_firerate()
	_fire_cd = 1.0 / maxf(0.1, rate)
	var burst := maxi(1, int(_weapon.get("burst_count", 1)))
	_fire_one_shot(true)
	if burst > 1 and _ammo > 0:
		_burst_left = mini(burst - 1, _ammo)
		_burst_gap_left = float(_weapon.get("burst_gap", 0.05))


func _fire_one_shot(counts_as_trigger: bool) -> void:
	if _ammo <= 0:
		_start_reload()
		return
	_ammo -= 1
	var pellets := maxi(1, int(_weapon.get("pellets", 1)))
	## Split Shot: every third shot fires three.
	var shot_n := int(GameState.weapon.get("_shot_count", 0)) + 1
	GameState.weapon["_shot_count"] = shot_n
	if float(GameState.run_mods.get("split", 0.0)) > 0.0 and shot_n % 3 == 0:
		pellets = maxi(pellets, 3)
	var base_spread := deg_to_rad(float(_weapon.get("spread_deg", 6.0)))
	if _buffs.has("quiet"):
		base_spread *= 0.7
	## Tighter while standing still — rewards planting your feet.
	if velocity.length() < 30.0:
		base_spread *= 0.6
	var crit_any := false
	var aim_for_fx := _last_aim
	for i in range(pellets):
		var aim := _last_aim
		var spread := base_spread
		if pellets > 1:
			## Dual blades / split: fan the pellets so they read.
			var fan := deg_to_rad(10.0 if pellets == 2 else 14.0)
			aim = aim.rotated(lerpf(-fan, fan, float(i) / float(maxi(1, pellets - 1))))
		aim = aim.rotated(randf_range(-spread, spread))
		aim_for_fx = aim
		var dmg := float(_weapon.get("damage", 12)) * damage_mult * _buff_damage()
		## Bell Tower: standing still charges stronger shots.
		if _planted_t > 0.5:
			dmg *= 1.0 + minf(0.6, _planted_t * 0.2)
		var close_r := float(_weapon.get("close_bonus_range", 0.0))
		if close_r > 0.0:
			var foe := _nearest_enemy_in_range(close_r)
			if foe != null:
				dmg *= float(_weapon.get("close_bonus_mult", 1.25))
		var crit := false
		if randf() < GameState.crit_chance():
			crit = true
			crit_any = true
			dmg *= 1.5 + GameState.crit_damage_bonus()
		var splash_r := float(_weapon.get("splash_radius", 0.0))
		var splash_m := float(_weapon.get("splash_mult", 0.5))
		var status: Dictionary = {}
		if not GameState.special_ammo.is_empty():
			status = GameState.special_ammo.duplicate(true)
			if str(status.get("id", "")) == "explosive":
				splash_r = maxf(splash_r, float(status.get("splash_radius", 55.0)))
				splash_m = maxf(splash_m, float(status.get("splash_mult", 0.45)))
		## Dust Rounds poison.
		if float(GameState.run_mods.get("poison", 0.0)) > 0.0:
			status = status.duplicate(true) if not status.is_empty() else {}
			if status.is_empty():
				status = {"id": "poison", "stacks": float(GameState.run_mods.get("poison", 1.0))}
			else:
				status["poison"] = true
				status["stacks"] = float(GameState.run_mods.get("poison", 1.0))
		## Marked class.
		if float(GameState.run_mods.get("class_mark", 0.0)) > 0.0:
			status = status.duplicate(true) if not status.is_empty() else {"id": "mark"}
			status["mark"] = 1.0
		var bullet: Area2D = BulletScene.instantiate()
		bullet.setup(
			global_position + aim * 28.0,
			aim,
			float(_weapon.get("projectile_speed", 720.0)),
			dmg,
			true,
			self,
			float(_weapon.get("lifetime", -1.0)),
			splash_r,
			splash_m
		)
		bullet.set("status_effect", status)
		bullet.set("pierce_left", int(GameState.run_mods.get("pierce", 0.0)))
		bullet.set("ricochet_left", int(GameState.run_mods.get("ricochet", 0.0)))
		get_tree().current_scene.add_child(bullet)
	## Quarry Slam: every few maul swings.
	if float(GameState.run_mods.get("class_quarry", 0.0)) > 0.0 and counts_as_trigger:
		_quarry_hits += 1
		if _quarry_hits >= 4:
			_quarry_hits = 0
			_slam_nearby(100.0, 30.0)
			Juice.float_text(global_position + Vector2(0, -34), "QUARRY", UiTheme.AMBER, 14)
	_recoil = float(_weapon.get("recoil", 5.0))
	_flash_left = 0.045
	_attack_flash = 0.12
	Juice.sfx("shot", -4.0)
	var shake := float(_weapon.get("shake", 0.035))
	Juice.shake(shake * (1.35 if crit_any else 1.0))
	if crit_any:
		Juice.float_text(global_position + aim_for_fx * 40.0, "CRIT", UiTheme.AMBER, 14)
	ammo_changed.emit(_ammo, _mag_size(), false)
	if counts_as_trigger:
		GameState.weapon["weapon_xp"] = int(GameState.weapon.get("weapon_xp", 0)) + 1
		if int(GameState.weapon["weapon_xp"]) >= 20 * int(GameState.weapon.get("weapon_level", 1)):
			GameState.weapon["weapon_level"] = int(GameState.weapon.get("weapon_level", 1)) + 1
	if _ammo <= 0:
		_burst_left = 0
		_start_reload()


func _nearest_enemy_in_range(radius: float) -> Node2D:
	var best: Node2D = null
	var best_d := radius * radius
	for n in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(n) or not (n is Node2D):
			continue
		var e := n as Node2D
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _tick_drone_assist() -> void:
	## Helm passive / Wingman class: keep a visible drone flying with you.
	var wants := float(_weapon.get("drone_assist_interval", 0.0)) > 0.0 \
		or float(GameState.run_mods.get("class_wingman", 0.0)) > 0.0
	if not wants or hp <= 0.0:
		return
	var interval := float(_weapon.get("drone_assist_interval", 0.85))
	if interval <= 0.0:
		interval = 0.85
	var dmg := float(_weapon.get("drone_assist_damage", 8.0)) * damage_mult
	_ensure_drone("wingman", dmg, interval, -1.0)


func _tick_scrap_drone() -> void:
	var stacks := float(GameState.run_mods.get("drone", 0.0))
	if stacks <= 0.0 or hp <= 0.0:
		return
	var interval := 0.9 / (1.0 + 0.25 * stacks)
	var dmg := 7.0 * stacks * damage_mult
	_ensure_drone("scrap", dmg, interval, -1.0)


func _ensure_drone(kind: String, dmg: float, interval: float, life: float) -> void:
	if _drone != null and is_instance_valid(_drone):
		if _drone.has_method("setup"):
			_drone.call("setup", self, dmg, interval, kind, life if life > 0.0 else -1.0)
		if life > 0.0 and _drone.has_method("refresh_life"):
			_drone.call("refresh_life", life)
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	_drone = DroneScene.instantiate()
	scene.add_child(_drone)
	_drone.call("setup", self, dmg, interval, kind, life)
	Juice.burst(global_position + Vector2(30, -24), Color(0.55, 0.9, 0.75), 12, 90.0, 0.4)
	Juice.float_text(global_position + Vector2(0, -36), "DRONE ONLINE", UiTheme.TEAL, 14)


func _tick_spore_mines(delta: float) -> void:
	if float(GameState.run_mods.get("mines", 0.0)) <= 0.0 or hp <= 0.0:
		return
	if velocity.length() < 40.0:
		return
	if _mine_cd > 0.0:
		return
	_mine_cd = 1.6 / float(GameState.run_mods.get("mines", 1.0))
	## Instant proximity mine: damages nearby foes.
	Juice.burst(global_position, Color(0.55, 0.9, 0.4), 10, 70.0, 0.35)
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		if global_position.distance_to(e.global_position) > 55.0:
			continue
		if e.has_method("take_damage"):
			e.call("take_damage", 14.0 * damage_mult, Vector2.ZERO)
		if e.has_method("apply_dot"):
			e.call("apply_dot", 4.0, 2.0)


func _tick_orbit_blades(delta: float) -> void:
	if float(GameState.run_mods.get("blades", 0.0)) <= 0.0 or hp <= 0.0:
		return
	_blade_angle += delta * 4.5
	var n_blades := int(GameState.run_mods.get("blades", 1.0))
	for i in range(n_blades):
		var ang := _blade_angle + TAU * float(i) / float(n_blades)
		var tip := global_position + Vector2(cos(ang), sin(ang)) * 58.0
		for n in get_tree().get_nodes_in_group("enemies"):
			if not (n is Node2D) or not is_instance_valid(n):
				continue
			var e := n as Node2D
			if tip.distance_to(e.global_position) > 28.0:
				continue
			if e.has_method("take_damage") and randf() < 0.08:
				e.call("take_damage", 6.0 * damage_mult, (e.global_position - global_position).normalized())


func _tick_bayonet() -> void:
	if float(GameState.run_mods.get("class_bayonet", 0.0)) <= 0.0 or hp <= 0.0:
		return
	if randf() > 0.12:
		return
	var foe := _nearest_enemy_in_range(55.0)
	if foe == null:
		return
	if foe.has_method("take_damage"):
		foe.call("take_damage", 10.0 * damage_mult, (foe.global_position - global_position).normalized())
		Juice.float_text(foe.global_position + Vector2(0, -20), "STAB", UiTheme.RUST, 12)


func _tick_supply_drop() -> void:
	if float(GameState.run_mods.get("class_supply", 0.0)) <= 0.0:
		return
	if _supply_cd > 0.0 or hp <= 0.0:
		return
	_supply_cd = 20.0
	GameState.activate_special_ammo(GameState.roll_special_ammo())
	Juice.float_text(global_position + Vector2(0, -44), "SUPPLY DROP", UiTheme.AMBER, 16)


func _stamp_firewalk() -> void:
	_firewalk_spots.append({"pos": global_position, "t": 1.4})
	if _firewalk_spots.size() > 12:
		_firewalk_spots.pop_front()
	Juice.burst(global_position, Color(1.0, 0.45, 0.2), 4, 40.0, 0.25)


func _tick_firewalk_damage(delta: float) -> void:
	if _firewalk_spots.is_empty():
		return
	var keep: Array = []
	for spot in _firewalk_spots:
		spot["t"] = float(spot["t"]) - delta
		if float(spot["t"]) <= 0.0:
			continue
		keep.append(spot)
		var pos: Vector2 = spot["pos"]
		for n in get_tree().get_nodes_in_group("enemies"):
			if not (n is Node2D) or not is_instance_valid(n):
				continue
			var e := n as Node2D
			if pos.distance_to(e.global_position) > 36.0:
				continue
			if e.has_method("take_damage") and randf() < 0.15:
				e.call("take_damage", 5.0 * damage_mult, Vector2.ZERO)
	_firewalk_spots = keep


func mod_bullet_damage(base: float, body: Node, dir: Vector2) -> float:
	var dmg := base
	## Double Cross: hits from behind deal triple.
	if float(GameState.run_mods.get("class_backstab", 0.0)) > 0.0 and body is Node2D:
		var e := body as Node2D
		var to_me := (global_position - e.global_position).normalized()
		var facing := dir ## approximate: if we're shooting into their back
		## Prefer enemy velocity as facing if available.
		if "velocity" in e and e.velocity is Vector2 and (e.velocity as Vector2).length() > 10.0:
			facing = (e.velocity as Vector2).normalized()
		if facing.dot(to_me) > 0.35:
			dmg *= 3.0
	## Field Notes: stronger vs kinds you've killed.
	if body.get("kind") != null:
		dmg *= GameState.field_notes_mult(str(body.get("kind")))
	return dmg


func _start_reload() -> void:
	if _reload_left > 0.0:
		return
	_burst_left = 0
	_reload_left = float(_weapon.get("reload_time", 1.4))
	Juice.sfx("reload")
	ammo_changed.emit(0, _mag_size(), true)

func get_reload_ratio() -> float:
	var t := float(_weapon.get("reload_time", 1.4))
	return 1.0 - _reload_left / t if _reload_left > 0.0 else 1.0

## =============================================================================
## Damage

func _reset_extract_channels() -> void:
	for pad in get_tree().get_nodes_in_group("extract_pads"):
		if pad.has_method("reset_channel"):
			pad.call("reset_channel")
	## Also scan by class if group missing.
	for n in get_tree().get_nodes_in_group("extract"):
		if n.has_method("reset_channel"):
			n.call("reset_channel")


func take_damage(amount: float, attacker: Node = null) -> void:
	if _iframes > 0.0 or hp <= 0.0:
		return
	## Dust Sidestep — full avoid (soft-capped in GameState).
	if randf() < GameState.dodge_chance():
		_iframes = 0.35
		Juice.float_text(global_position + Vector2(0, -30), "DODGE", UiTheme.TEAL, 16)
		Juice.sfx("dash", -8.0)
		return
	## Iron Tonic: shield blocks one hit.
	if _shield_charges > 0:
		_shield_charges = 0
		_shield_recharge = 12.0
		_iframes = maxf(_iframes, 0.4)
		Juice.float_text(global_position + Vector2(0, -30), "SHIELD!", Color(0.7, 0.85, 1.0), 16)
		Juice.burst(global_position, Color(0.6, 0.8, 1.0), 12, 100.0, 0.35)
		return
	## Stealth: enemies lose track — ignore hits while stealthed.
	if _stealth_left > 0.0:
		Juice.float_text(global_position + Vector2(0, -28), "MISSED", UiTheme.TEAL, 14)
		return
	var dmg := float(amount) * resist_mult
	## Pebble tank: resist knockback/chip via knockback_resist as DR softener.
	var kb := float(_char.get("knockback_resist", 0.0))
	if kb > 0.0:
		dmg *= 1.0 - kb * 0.25
	## Brace Plate — half damage on proc (full rate with block_affinity kits).
	if randf() < GameState.block_chance():
		dmg *= 0.5
		Juice.float_text(global_position + Vector2(0, -42), "BLOCK", UiTheme.AMBER, 14)
	## Unbreakable class pick: reduced damage below half HP.
	if float(GameState.run_mods.get("class_unbreakable", 0.0)) > 0.0 and hp < max_hp * 0.5:
		dmg *= 0.65
	## Set bonus DR (Plague Doctor / Demolition / etc. via armor tags).
	dmg *= GameState.set_damage_taken_mult()
	hp -= dmg
	## Fair hits: ~0.5s i-frames so one mistake isn't a full wipe (was 0.12s).
	_iframes = 0.5
	## Hit while extracting resets pad channel.
	_reset_extract_channels()
	if attacker != null and is_instance_valid(attacker) and attacker != self:
		attacked.emit(attacker)
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
