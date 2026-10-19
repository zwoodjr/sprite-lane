class_name HaulPickup
extends Node2D

## Something to carry home in the backpack (Depth Update E1): an ingredient
## (herb / plague gland / Dust shard / machine oil) or a heavy medicine crate.
## Picked up only while the pack has room; banked on extract, lost on death.
## Medicine crates show on the minimap (group "map_markers").

const ICON_WORLD := 24.0
const CRATE_WORLD := 46.0
const PICK_R := 26.0
const MAGNET_R := 90.0
const MAGNET_SPEED := 360.0
const CRATE_TEX := "res://assets/sprites/depth/world/medicine_crate.png"
const LIFETIME := 90.0

var id: String = "herb"
var n: int = 1
## Dropped from the pack: not picked up again until the hero has walked away.
var dropped: bool = false
var _player: Node2D
var _t: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _sprite: Sprite2D
var _full_cd: float = 0.0
var _left_once: bool = false
var map_color: Color = Color(1.0, 0.4, 0.35)


static func spawn(parent: Node, pos: Vector2, item_id: String, count: int = 1, pop: bool = true) -> HaulPickup:
	if parent == null or not MedicineDefs.INGREDIENTS.has(item_id):
		return null
	var h := HaulPickup.new()
	h.id = item_id
	h.n = count
	h.position = pos
	if pop:
		h._vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(70.0, 140.0)
	parent.add_child.call_deferred(h)
	return h


## Kill drops by faction; elites / bosses also drop Dust shards and maybe medicine.
static func drop_kill(parent: Node, pos: Vector2, faction: String, role: String) -> void:
	var table: Dictionary = MedicineDefs.KILL_DROP.get(faction, {})
	for k in table.keys():
		if randf() < float(table[k]):
			spawn(parent, pos, str(k))
	var rd: Dictionary = MedicineDefs.ROLE_DROP.get(role, {})
	for k in rd.keys():
		for i in range(int(rd[k])):
			spawn(parent, pos + Vector2(randf_range(-12, 12), randf_range(-8, 8)), str(k))
	if role == "elite" and randf() < MedicineDefs.ELITE_MEDICINE_CHANCE:
		spawn(parent, pos + Vector2(0, 14), "medicine")
	elif role == "boss":
		for i in range(MedicineDefs.BOSS_MEDICINE):
			spawn(parent, pos + Vector2(14 * i, 18), "medicine")


func _ready() -> void:
	add_to_group("haul")
	z_index = -1 if id == "medicine" else 1
	_sprite = Sprite2D.new()
	var path := CRATE_TEX if id == "medicine" else MedicineDefs.icon_path(id)
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		var world := CRATE_WORLD if id == "medicine" else ICON_WORLD
		_sprite.scale = Vector2.ONE * (world / float(maxi(_sprite.texture.get_width(), _sprite.texture.get_height())))
	add_child(_sprite)
	if id == "medicine":
		add_to_group("map_markers")
		add_to_group("medicine_crates")


func is_medicine() -> bool:
	return id == "medicine"


func _physics_process(delta: float) -> void:
	_t += delta
	_full_cd = maxf(0.0, _full_cd - delta)
	if _t > LIFETIME and id != "medicine":
		queue_free()
		return
	if _vel.length() > 4.0:
		position += _vel * delta
		_vel = _vel.move_toward(Vector2.ZERO, 300.0 * delta)
	if id == "medicine":
		## Heavy: sits still, a soft red pulse so it reads as precious.
		_sprite.position = Vector2(0, -CRATE_WORLD * 0.32)
		_sprite.modulate = Color(1.0 + 0.12 * sin(_t * 3.0), 1.0, 1.0)
	else:
		_sprite.position = Vector2(0, -6 + sin(_t * 4.0) * 2.0)
	if _player == null or not is_instance_valid(_player) or not _player.is_in_group("player"):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	if _t < 0.35:
		return
	var to := _player.global_position - global_position
	var d := to.length()
	if dropped and not _left_once:
		if d > MAGNET_R:
			_left_once = true
		return
	var room := GameState.pack_has_room(id, n)
	if d < (MedicineDefs.CRATE_PICK_R if id == "medicine" else PICK_R):
		if room:
			_collect()
		elif _full_cd <= 0.0:
			_full_cd = 2.5
			Juice.float_text(global_position + Vector2(0, -34), "PACK FULL", UiTheme.RUST, 14)
		return
	if room and id != "medicine" and d < MAGNET_R + GameState.pickup_radius_bonus():
		global_position += to.normalized() * MAGNET_SPEED * delta


func _collect() -> void:
	if not GameState.add_to_pack(id, n):
		return
	var col: Color = MedicineDefs.INGREDIENTS[id].get("color", Color.WHITE)
	if id == "medicine":
		Juice.float_text(global_position + Vector2(0, -44), "MEDICINE", col, 20)
		Juice.burst(global_position, col, 16, 160.0, 0.5)
		Juice.sfx("pickup", 0.0)
		Juice.haptic(30)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_toast"):
			hud.call("show_toast", "Medicine in the pack — it's heavy, and the plague can smell it" if GameState.smells_medicine() else "Medicine in the pack", col)
	else:
		Juice.float_text(global_position + Vector2(0, -26), "+%d %s" % [n, MedicineDefs.item_name(id)], col, 13)
		Juice.sfx("pickup", -10.0, 0.2)
	queue_free()
