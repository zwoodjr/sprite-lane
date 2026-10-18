extends Node2D

## Visible scrap / wingman drone — follows the player and fires at on-screen foes.
## Spawned by Helm's Wingman ability, Scrap Drone upgrade, or Helm's passive assist.

const BulletScene := preload("res://scenes/entities/bullet.tscn")
const BODY_FOV_PX := 28.0

var owner_player: Node2D = null
var damage: float = 8.0
var fire_interval: float = 0.9
var follow_radius: float = 48.0
var kind: String = "scrap" ## scrap | wingman

var _fire_cd: float = 0.4
var _bob_t: float = 0.0
var _life: float = -1.0 ## <0 = permanent for run; else timed (ability summon)

@onready var body: Sprite2D = $Body
@onready var label: Label = $NameLabel


func setup(player: Node2D, dmg: float = 8.0, interval: float = 0.9, drone_kind: String = "scrap", life: float = -1.0) -> void:
	owner_player = player
	damage = dmg
	fire_interval = interval
	kind = drone_kind
	_life = life
	if is_inside_tree():
		_apply_look()


func _ready() -> void:
	add_to_group("drones")
	_apply_look()
	if owner_player != null and is_instance_valid(owner_player):
		global_position = owner_player.global_position + Vector2(36, -28)


func _apply_look() -> void:
	if body == null:
		return
	if body.texture == null:
		body.texture = load("res://assets/sprites/props/scrap_drone.png")
	var tw := float(body.texture.get_width()) if body.texture else 64.0
	var sc := BODY_FOV_PX / maxf(tw, 1.0)
	body.scale = Vector2(sc, sc)
	if label:
		label.text = "WINGMAN" if kind == "wingman" else "DRONE"
		label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.75) if kind == "wingman" else Color(0.85, 0.8, 0.55))


func _physics_process(delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		queue_free()
		return
	if float(owner_player.get("hp")) <= 0.0:
		queue_free()
		return
	if _life > 0.0:
		_life -= delta
		if _life <= 0.0:
			Juice.burst(global_position, Color(0.6, 0.85, 0.7), 10, 80.0, 0.35)
			queue_free()
			return
	_bob_t += delta
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_follow(delta)
	_try_fire()


func _follow(delta: float) -> void:
	var facing := Vector2.RIGHT
	if owner_player.get("velocity") is Vector2 and (owner_player.velocity as Vector2).length() > 20.0:
		facing = (owner_player.velocity as Vector2).normalized()
	var side := facing.orthogonal() * (follow_radius if kind == "scrap" else 40.0)
	var goal := owner_player.global_position + side + Vector2(0, -22.0 + sin(_bob_t * 5.0) * 3.0)
	global_position = global_position.lerp(goal, clampf(delta * 7.0, 0.0, 1.0))
	if body:
		body.flip_h = facing.x < 0.0


func _try_fire() -> void:
	if _fire_cd > 0.0:
		return
	var foe := _nearest_foe(400.0)
	if foe == null:
		return
	_fire_cd = fire_interval
	var aim := (foe.global_position - global_position).normalized()
	if aim.length_squared() < 0.01:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var bullet: Area2D = BulletScene.instantiate()
	var src: Node = owner_player if owner_player != null else self
	bullet.setup(global_position + aim * 12.0, aim, 820.0, damage, true, src, 0.85, 0.0, 0.0)
	scene.add_child(bullet)
	Juice.sfx("shot", -12.0)


func _nearest_foe(radius: float) -> Node2D:
	var best: Node2D = null
	var best_d := radius * radius
	## Prefer on-screen enemies when the player exposes a camera helper.
	var view := Rect2()
	var use_view := false
	if owner_player != null and owner_player.has_method("_camera_view_rect"):
		view = owner_player.call("_camera_view_rect")
		use_view = view.size.x > 1.0
	for n in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(n) or not (n is Node2D):
			continue
		var e := n as Node2D
		if use_view and not view.has_point(e.global_position):
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func refresh_life(sec: float) -> void:
	_life = maxf(_life, sec)


func boost(dmg_mult: float = 1.25, interval_mult: float = 0.85) -> void:
	damage *= dmg_mult
	fire_interval = maxf(0.35, fire_interval * interval_mult)
