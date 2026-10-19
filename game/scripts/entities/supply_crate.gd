extends Node2D

## Helm's Supply Drop: a crate parachutes in near the hero; walking over it
## grants a random special ammo for UpgradeDefs.AMMO_DURATION seconds.

const DROP_TEX := "res://assets/sprites/pickups/supply_crate_drop.png"
const CRATE_TEX := "res://assets/sprites/pickups/supply_crate.png"
const FALL_TIME := 1.4
const FALL_HEIGHT := 260.0

var _age: float = 0.0
var _sprite: Sprite2D
var _shadow: Polygon2D
var _drop_frames: Array[Texture2D] = []
var _landed: bool = false


func _ready() -> void:
	add_to_group("supply_crates")
	z_index = 2
	_drop_frames = RunFx.frames(DROP_TEX, 2)
	_shadow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(14):
		var a := TAU * i / 14.0
		pts.append(Vector2(cos(a) * 14.0, sin(a) * 5.0 + 10.0))
	_shadow.polygon = pts
	_shadow.color = Color(0, 0, 0, 0.3)
	_shadow.z_index = -3
	add_child(_shadow)
	_sprite = Sprite2D.new()
	if not _drop_frames.is_empty():
		_sprite.texture = _drop_frames[0]
		_sprite.scale = Vector2.ONE * (64.0 / float(_drop_frames[0].get_width()))
		_sprite.offset = Vector2(0, -float(_drop_frames[0].get_height()) * 0.42)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_age += delta
	if not _landed:
		var k := clampf(_age / FALL_TIME, 0.0, 1.0)
		_sprite.position = Vector2(sin(_age * 3.0) * 6.0 * (1.0 - k), -FALL_HEIGHT * (1.0 - k))
		_shadow.scale = Vector2.ONE * (0.4 + 0.6 * k)
		if not _drop_frames.is_empty():
			_sprite.texture = _drop_frames[int(_age * 4.0) % _drop_frames.size()]
		if k >= 1.0:
			_land()
		return
	if _age > UpgradeDefs.CRATE_LIFE:
		queue_free()
		return
	_sprite.position.y = -2.0 + sin(_age * 4.0) * 1.5
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and p.global_position.distance_to(global_position) <= UpgradeDefs.CRATE_PICK_R + 14.0:
		p.call("apply_powerup", RunFx.ammo_def(RunFx.random_ammo_id()))
		queue_free()


func _land() -> void:
	_landed = true
	if ResourceLoader.exists(CRATE_TEX):
		_sprite.texture = load(CRATE_TEX)
		_sprite.scale = Vector2.ONE * (34.0 / float(_sprite.texture.get_width()))
		_sprite.offset = Vector2(0, -float(_sprite.texture.get_height()) * 0.4)
	_sprite.position = Vector2.ZERO
	Juice.dust_puff(global_position + Vector2(0, 8), 10)
	Juice.sfx("pickup", -6.0)
