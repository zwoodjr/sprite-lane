class_name LootDrop
extends Node2D

## Kill loot that pops out of a dead mob and magnets to the hero:
##   scrap — brass scrap bolt (bag scrap)
##   xp    — amber Dust shard (run XP)
##   tonic — small health tonic
## Spawn with LootDrop.spawn_burst(...) from enemy.gd.

const TEX := {
	"scrap": "res://assets/sprites/drops/drop_scrap_bolt.png",
	"xp": "res://assets/sprites/drops/drop_dust_shard.png",
	"xp_big": "res://assets/sprites/drops/drop_dust_shard_big.png",
	"tonic": "res://assets/sprites/pickups/tonic_small.png",
}
## World-px sizes (tonic art is 56 px → ~22 in world).
const SIZE := {"scrap": 14.0, "xp": 12.0, "xp_big": 16.0, "tonic": 22.0}
const MAGNET_RADIUS := 120.0
const COLLECT_RADIUS := 18.0
const LIFETIME := 30.0

var kind: String = "scrap"
var value: float = 1.0
var _vel: Vector2 = Vector2.ZERO
var _height: float = 0.0
var _vz: float = 0.0
var _age: float = 0.0
var _magnet: bool = false
var _player: Node2D
var _sprite: Sprite2D


static func spawn_burst(parent: Node, at: Vector2, kind_id: String, count: int, total_value: float) -> void:
	if count <= 0 or parent == null:
		return
	var each := total_value / float(count)
	for i in range(count):
		var d := Node2D.new()
		d.set_script(load("res://scripts/entities/loot_drop.gd"))
		d.set("kind", kind_id)
		d.set("value", each)
		d.position = at
		parent.add_child.call_deferred(d)


func _ready() -> void:
	add_to_group("loot")
	z_index = -1
	var key := kind
	if kind == "xp" and value >= 6.0:
		key = "xp_big"
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path: String = TEX.get(key, TEX["scrap"])
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		_sprite.scale = Vector2.ONE * (float(SIZE.get(key, 14.0)) / float(_sprite.texture.get_width()))
	add_child(_sprite)
	## Pop out of the corpse.
	var ang := randf() * TAU
	_vel = Vector2(cos(ang), sin(ang)) * randf_range(60.0, 150.0)
	_vz = randf_range(150.0, 230.0)
	_player = get_tree().get_first_node_in_group("player") as Node2D


## Pulled in from further away (Bentley's sniff, magnet buffs).
func magnetize() -> void:
	_magnet = true


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	if _player == null or not is_instance_valid(_player) or not _player.is_in_group("player"):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	## Pop arc
	if _height > 0.0 or _vz > 0.0:
		_vz -= 700.0 * delta
		_height = maxf(0.0, _height + _vz * delta)
		if _height <= 0.0:
			_vz = 0.0
		position += _vel * delta
		_vel = _vel.move_toward(Vector2.ZERO, 260.0 * delta)
	_sprite.position = Vector2(0, -_height + sin(_age * 5.0) * 1.5)
	if _player == null or _age < 0.3:
		return
	var to := _player.global_position - global_position
	var d := to.length()
	var radius := MAGNET_RADIUS + GameState.pickup_radius_bonus()
	if _player.has_method("get_active_buffs") and (_player.call("get_active_buffs") as Dictionary).has("magnet"):
		radius *= 3.0
	if d < radius:
		_magnet = true
	if _magnet:
		var spd := 260.0 + 900.0 * clampf(_age * 0.5, 0.0, 1.0)
		global_position += to.normalized() * minf(d, spd * delta)
		if d < COLLECT_RADIUS:
			_collect()


func _collect() -> void:
	match kind:
		"scrap":
			GameState.add_scrap(maxi(1, int(round(value))))
			Juice.sfx("pick_scrap")
		"xp":
			GameState.add_run_xp(maxi(1, int(round(value))))
			Juice.sfx("pick_xp")
		"tonic":
			if _player.has_method("heal"):
				_player.call("heal", value)
			GameState.cleanse_exposure(MedicineDefs.TONIC_PICKUP_CLEANSE)
			Juice.float_text(_player.global_position + Vector2(0, -36), "+%d" % int(value), UiTheme.TEAL, 16)
			Juice.sfx("pick_tonic")
			Juice.fx("fx_heal_small", _player.global_position + Vector2(0, 12), {"follow": _player})
	queue_free()
