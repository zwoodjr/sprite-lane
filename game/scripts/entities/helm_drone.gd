extends Node2D

## Helm Wisp's support drone. Hovers beside the hero and shoots the closest
## on-screen enemy to ITSELF within drone_range. With several drones, each takes
## the closest target no other drone has claimed (falls back to a shared one).

const BulletScene := preload("res://scenes/entities/bullet.tscn")
const HOVER_TEX := "res://assets/sprites/characters/helm_drone_hover.png"
const FIRE_TEX := "res://assets/sprites/characters/helm_drone_fire.png"
const WORLD_SIZE := 40.0 ## on-screen size in world px (art is 96 px)

var _player: Node2D
var _slot: int = 0
var _count: int = 1
var _range: float = 380.0
var _interval: float = 0.9
var _damage: float = 8.0
var _cd: float = 0.6
var _target: Node2D = null
var _t: float = 0.0
var _fire_anim: float = 0.0
var _sprite: Sprite2D
var _hover_frames: Array[Texture2D] = []
var _fire_frames: Array[Texture2D] = []
## >0: temporary drone (Helm's DRONE call) that leaves after this many seconds.
var temp_left: float = -1.0
## Scrap Drone (non-Helm heroes) gets a brass tint so it reads as salvage.
var tint: Color = Color.WHITE


func setup(player: Node2D, slot: int, weapon: Dictionary) -> void:
	_player = player
	_slot = slot
	_range = float(weapon.get("drone_range", 380.0))
	_interval = float(weapon.get("drone_interval", 0.9))
	_damage = float(weapon.get("drone_damage", 8.0))
	_cd = 0.4 + 0.2 * slot
	global_position = player.global_position + _slot_offset()


func set_slot(slot: int, count: int) -> void:
	_slot = slot
	_count = maxi(1, count)


func get_target() -> Node2D:
	return _target if _target != null and is_instance_valid(_target) else null


func _ready() -> void:
	add_to_group("drones")
	z_index = 5
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * (WORLD_SIZE / 96.0)
	add_child(_sprite)
	_hover_frames = _slice(HOVER_TEX, 4)
	_fire_frames = _slice(FIRE_TEX, 2)
	if _hover_frames.size() > 0:
		_sprite.texture = _hover_frames[0]
	_sprite.modulate = tint
	if temp_left > 0.0:
		Juice.burst(global_position, Color(0.5, 1.0, 0.85), 12, 120.0, 0.4)
	var shadow := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(12):
		var a := TAU * i / 12.0
		pts.append(Vector2(cos(a) * 9.0, sin(a) * 3.0 + 26.0))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.25)
	shadow.z_index = -6
	add_child(shadow)


func _slice(path: String, n: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if not ResourceLoader.exists(path):
		return out
	var tex := load(path) as Texture2D
	var fw := tex.get_width() / n
	for i in range(n):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, tex.get_height())
		out.append(at)
	return out


## Formation: fan over the hero's shoulders (1 → right shoulder, 4 → arc).
func _slot_offset() -> Vector2:
	var spread := 0.0 if _count <= 1 else lerpf(-1.0, 1.0, float(_slot) / float(_count - 1))
	var ang := -PI * 0.5 + spread * 1.2 + (0.7 if _count == 1 else 0.0)
	return Vector2(cos(ang) * 42.0, sin(ang) * 30.0 - 8.0)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		queue_free()
		return
	_t += delta
	_cd = maxf(0.0, _cd - delta)
	if temp_left > 0.0:
		temp_left -= delta
		if temp_left <= 0.0:
			Juice.burst(global_position, Color(0.5, 1.0, 0.85), 10, 100.0, 0.35)
			queue_free()
			return
		_sprite.modulate.a = 0.5 + 0.5 * absf(sin(_t * 10.0)) if temp_left < 1.0 else 1.0
	_fire_anim = maxf(0.0, _fire_anim - delta)
	var want := _player.global_position + _slot_offset() + Vector2(0, sin(_t * 3.0 + _slot) * 3.0)
	global_position = global_position.lerp(want, clampf(delta * 8.0, 0.0, 1.0))
	_target = _pick_target()
	if _target != null:
		_sprite.flip_h = _target.global_position.x < global_position.x
		if _cd <= 0.0:
			_fire()
	else:
		_sprite.flip_h = bool(_player.get("_facing_left"))
	## Animation
	if _fire_anim > 0.0 and _fire_frames.size() > 0:
		_sprite.texture = _fire_frames[int(_fire_anim * 20.0) % _fire_frames.size()]
	elif _hover_frames.size() > 0:
		_sprite.texture = _hover_frames[int(_t * 10.0) % _hover_frames.size()]


func _claimed_by_other(e: Node2D) -> bool:
	if _player == null or not _player.has_method("get_drones"):
		return false
	for d in _player.call("get_drones"):
		if d == self or not is_instance_valid(d):
			continue
		if d.call("get_target") == e:
			return true
	return false


func _pick_target() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	var shared: Node2D = null
	var shared_d := INF
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		var d := global_position.distance_to(e.global_position)
		if d > _range:
			continue
		if not _on_screen(e.global_position):
			continue
		if _claimed_by_other(e):
			if d < shared_d:
				shared_d = d
				shared = e
			continue
		if d < best_d:
			best_d = d
			best = e
	return best if best != null else shared


func _on_screen(world_pos: Vector2) -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var p: Vector2 = vp.get_canvas_transform() * world_pos
	return vp.get_visible_rect().grow(-6.0).has_point(p)


func _fire() -> void:
	## Wingman / DRONE call overclock speed every drone up.
	var rate := float(_player.call("drone_rate_mult")) if _player.has_method("drone_rate_mult") else 1.0
	_cd = _interval / maxf(0.2, rate)
	_fire_anim = 0.12
	var aim := (_target.global_position - global_position).normalized()
	var dmg := _damage * float(_player.get("damage_mult"))
	var bullet: Area2D = BulletScene.instantiate()
	bullet.setup(global_position + aim * 14.0, aim, 900.0, dmg, true, _player, 0.6, 0.0, 0.0)
	bullet.set("style", "drone")
	bullet.set("src_tag", "drone")
	if _player.has_method("special_ammo"):
		bullet.set("ammo", str(_player.call("special_ammo")))
	get_tree().current_scene.add_child(bullet)
	Juice.sfx("shot", -12.0)
