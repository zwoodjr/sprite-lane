extends CharacterBody2D

signal died
signal health_changed(current: float, maximum: float)

const BulletScene := preload("res://scenes/entities/bullet.tscn")

@export var base_speed: float = 220.0
@export var base_max_hp: float = 100.0

var max_hp: float = 100.0
var hp: float = 100.0
var damage_mult: float = 1.0
var move_mult: float = 1.0
var firerate_mult: float = 1.0

var _fire_cd: float = 0.0
var _reload_left: float = 0.0
var _ammo: int = 24
var _heal_cd: float = 0.0
var _post_heal_left: float = 0.0
var _last_stitch_available: bool = false
var _mounted: bool = false
var _oos_timer: float = 0.0
var _char: Dictionary = {}
var _weapon: Dictionary = {}
var _mount: Dictionary = {}
var _armor: Dictionary = {}

@onready var body: Polygon2D = $Body
@onready var gun: Polygon2D = $Gun
@onready var mount_visual: Polygon2D = $MountVisual
@onready var label: Label = $NameLabel


func _ready() -> void:
	add_to_group("player")
	_apply_loadout()
	hp = max_hp
	health_changed.emit(hp, max_hp)
	mount_visual.visible = false


func _apply_loadout() -> void:
	_char = GameState.get_character()
	_weapon = GameState.weapon
	_mount = GameState.mount
	_armor = GameState.armor
	max_hp = base_max_hp + float(_char.get("max_hp_bonus", 0)) + float(_armor.get("flat_armor", 0)) * 0.5
	damage_mult = float(_char.get("damage_mult", 1.0))
	move_mult = float(_char.get("move_speed_mult", 1.0))
	_ammo = int(_weapon.get("mag_size", 24))
	_last_stitch_available = bool(_char.get("has_last_stitch", false))
	body.color = _char.get("color", Color.WHITE)
	gun.color = _char.get("accent", Color.YELLOW)
	label.text = str(_char.get("display_name", "Wanderer"))


func _physics_process(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_reload_left = maxf(0.0, _reload_left - delta)
	_heal_cd = maxf(0.0, _heal_cd - delta)
	_post_heal_left = maxf(0.0, _post_heal_left - delta)
	if _post_heal_left <= 0.0:
		firerate_mult = 1.0

	var dir := TouchInput.get_move()
	var speed := base_speed * move_mult
	if _mounted and float(_mount.get("fuel", 0)) > 0.0:
		speed *= float(_mount.get("speed_mult", 1.4))
		_mount["fuel"] = float(_mount["fuel"]) - float(_mount.get("fuel_burn", 4.0)) * delta
		if float(_mount["fuel"]) <= 0.0:
			_mounted = false
			mount_visual.visible = false
	velocity = dir * speed
	move_and_slide()

	var aim_dir := _aim_direction()
	if aim_dir.length() > 0.01:
		gun.rotation = aim_dir.angle()

	if Input.is_action_just_pressed("mount_toggle") or TouchInput.consume_mount():
		_toggle_mount()
	if Input.is_action_just_pressed("ability") or TouchInput.consume_ability():
		_try_ability()
	if TouchInput.is_firing() and _reload_left <= 0.0:
		_try_shoot()
	if _ammo <= 0 and _reload_left <= 0.0:
		_start_reload()

	## Out-of-combat armor regen stub
	if velocity.length() < 10.0:
		_oos_timer += delta
	else:
		_oos_timer = 0.0
	if _oos_timer > 1.5 and hp < max_hp:
		hp = minf(max_hp, hp + float(_armor.get("regen_oos", 0.0)) * delta)
		health_changed.emit(hp, max_hp)


func _toggle_mount() -> void:
	if not bool(_mount.get("usable", false)):
		return
	if float(_mount.get("fuel", 0)) <= 0.0:
		return
	_mounted = not _mounted
	mount_visual.visible = _mounted
	GameState.mount["mounted"] = _mounted


func _try_ability() -> void:
	## Sister Cinder Field Draught
	if float(_char.get("heal_amount", 0)) <= 0.0:
		return
	if _heal_cd > 0.0:
		return
	hp = minf(max_hp, hp + float(_char["heal_amount"]))
	_heal_cd = float(_char.get("heal_cd", 12.0))
	firerate_mult = float(_char.get("post_heal_firerate_mult", 1.0))
	_post_heal_left = float(_char.get("post_heal_duration", 0.0))
	health_changed.emit(hp, max_hp)


func _aim_direction() -> Vector2:
	## Manual AIM stick wins.
	if TouchInput.aim_vector.length() > 0.01:
		return TouchInput.aim_vector
	## Phone default: auto-aim nearest enemy while holding FIRE.
	if TouchInput.auto_aim and TouchInput.is_firing():
		var nearest := _nearest_enemy_dir()
		if nearest.length() > 0.01:
			return nearest
	## Mouse aim (PC / editor); ignore while thumb-firing so last tap doesn't skew aim.
	if not TouchInput.fire_held:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 1.0:
			return to_mouse.normalized()
	return Vector2.RIGHT.rotated(gun.rotation)


func _nearest_enemy_dir() -> Vector2:
	var best: Node2D = null
	var best_d := 99999.0
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var d := global_position.distance_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n as Node2D
	if best == null or best_d > 520.0:
		return Vector2.ZERO
	return (best.global_position - global_position).normalized()


func _try_shoot() -> void:
	var rate := float(_weapon.get("fire_rate", 8.0)) * firerate_mult
	var interval := 1.0 / maxf(0.1, rate)
	if _fire_cd > 0.0:
		return
	if _ammo <= 0:
		_start_reload()
		return
	_fire_cd = interval
	_ammo -= 1
	var bullet: Area2D = BulletScene.instantiate()
	var aim := _aim_direction()
	var spread := deg_to_rad(float(_weapon.get("spread_deg", 6.0)))
	aim = aim.rotated(randf_range(-spread, spread))
	bullet.setup(
		global_position + aim * 18.0,
		aim,
		float(_weapon.get("projectile_speed", 720.0)),
		float(_weapon.get("damage", 12)) * damage_mult,
		true
	)
	get_tree().current_scene.add_child(bullet)
	## Weapon XP stub
	GameState.weapon["weapon_xp"] = int(GameState.weapon.get("weapon_xp", 0)) + 1
	if int(GameState.weapon["weapon_xp"]) >= 20 * int(GameState.weapon.get("weapon_level", 1)):
		GameState.weapon["weapon_level"] = int(GameState.weapon.get("weapon_level", 1)) + 1


func _start_reload() -> void:
	_reload_left = float(_weapon.get("reload_time", 1.4))
	_ammo = int(_weapon.get("mag_size", 24))


func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0 and _last_stitch_available:
		_last_stitch_available = false
		hp = 1.0
		health_changed.emit(hp, max_hp)
		return
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()
		queue_free()


func is_mounted() -> bool:
	return _mounted


func get_ammo_text() -> String:
	if _reload_left > 0.0:
		return "REL…"
	return "%d/%d" % [_ammo, int(_weapon.get("mag_size", 24))]


func get_mount_text() -> String:
	if not bool(_mount.get("usable", false)):
		return "Mount: locked"
	var fuel := int(float(_mount.get("fuel", 0)))
	return "%s %s (%d fuel)" % [
		"ON" if _mounted else "OFF",
		str(_mount.get("name", "Mount")),
		fuel,
	]
