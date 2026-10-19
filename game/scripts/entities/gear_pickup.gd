class_name GearPickup
extends Node2D

## A gear / material drop on the ground: the item icon in its rarity frame with
## a soft glow and a light beam for Epic+. Walk close (or let it magnet in) to
## pick it up. Gear goes to GameState.run_loot (kept only on extract).

const PICK_R := 30.0
const MAGNET_R := 110.0
const MAGNET_SPEED := 420.0
const ICON_WORLD := 30.0

var item: Dictionary = {}
var material_id: String = ""
var material_n: int = 0
var _player: Node2D
var _t: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _icon: Sprite2D
var _frame: Sprite2D
var _beam: Polygon2D


static func spawn(parent: Node, pos: Vector2, it: Dictionary) -> GearPickup:
	if parent == null:
		return null
	var g := GearPickup.new()
	g.item = it
	g.position = pos
	g._vel = Vector2(randf_range(-1, 1), randf_range(-1.4, -0.6)).normalized() * randf_range(120.0, 180.0)
	parent.add_child.call_deferred(g)
	return g


static func spawn_material(parent: Node, pos: Vector2, id: String, n: int) -> GearPickup:
	if parent == null:
		return null
	var g := GearPickup.new()
	g.material_id = id
	g.material_n = n
	g.position = pos
	g._vel = Vector2(randf_range(-1, 1), -1.0).normalized() * 140.0
	parent.add_child.call_deferred(g)
	return g


func _ready() -> void:
	add_to_group("gear_drops")
	z_index = 2
	var rar := str(item.get("rarity", "epic" if material_id != "" else "common"))
	var col: Color = GearDefs.RARITY_COLOR.get(rar, Color.WHITE)
	if rar in ["epic", "legendary"]:
		_beam = Polygon2D.new()
		_beam.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(-2, -90), Vector2(2, -90), Vector2(6, 0)])
		_beam.color = Color(col.r, col.g, col.b, 0.35)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_beam.material = add
		_beam.z_index = -1
		add_child(_beam)
	_frame = Sprite2D.new()
	var fpath := "res://assets/sprites/icons/frames/frame_%s.png" % rar
	if ResourceLoader.exists(fpath) and material_id == "":
		_frame.texture = load(fpath)
		_frame.scale = Vector2.ONE * (ICON_WORLD * 1.25 / float(_frame.texture.get_width()))
	add_child(_frame)
	_icon = Sprite2D.new()
	var ipath := str(item.get("icon", "")) if material_id == "" else str(GearDefs.MATERIAL_ICON.get(material_id, ""))
	if ipath != "" and ResourceLoader.exists(ipath):
		_icon.texture = load(ipath)
		_icon.scale = Vector2.ONE * (ICON_WORLD / float(maxi(_icon.texture.get_width(), _icon.texture.get_height())))
	add_child(_icon)
	Juice.burst(global_position, col, 12, 140.0, 0.4)


func _physics_process(delta: float) -> void:
	_t += delta
	## Pop out, settle, then bob.
	if _vel.length() > 5.0:
		position += _vel * delta
		_vel = _vel.move_toward(Vector2.ZERO, 520.0 * delta)
	_icon.position.y = sin(_t * 4.0) * 3.0 - 4.0
	_frame.position = _icon.position
	if _beam:
		_beam.modulate.a = 0.6 + 0.4 * sin(_t * 3.0)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	if _t < 0.35:
		return
	var to := _player.global_position - global_position
	var d := to.length()
	if d < PICK_R:
		_collect()
	elif d < MAGNET_R + GameState.pickup_radius_bonus():
		global_position += to.normalized() * MAGNET_SPEED * delta


func _collect() -> void:
	if material_id != "":
		GameState.add_run_material(material_id, material_n)
		Juice.float_text(global_position + Vector2(0, -30), "+%d %s" % [material_n, GearDefs.MATERIAL_NAME.get(material_id, material_id)], Color(1.0, 0.6, 0.5), 16)
	else:
		GameState.add_run_loot(item)
		var rar := str(item.get("rarity", "common"))
		Juice.float_text(global_position + Vector2(0, -30), str(item.get("name", "Gear")), GearDefs.RARITY_COLOR.get(rar, Color.WHITE), 17 if rar in ["epic", "legendary"] else 14)
	Juice.sfx("pickup")
	Juice.haptic(20)
	queue_free()


## Rolls a normal kill / crate drop and spawns it (chance scaled by Dust tier).
static func maybe_drop(parent: Node, pos: Vector2, chance: float) -> void:
	var tier := int(GameState.get_mode().get("tier", 1))
	var c := chance * (1.0 + GearDefs.DROP_TIER_STEP * float(tier - 1))
	if randf() >= c:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	spawn(parent, pos, GearDefs.roll_drop(tier, GameState.selected_character_id, GameState.gear_luck(), rng))


## Elite / boss kill rewards (Part 3).
static func drop_role_reward(parent: Node, pos: Vector2, role: String, kind: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tier := int(GameState.get_mode().get("tier", 1))
	var rw := GearDefs.roll_role_reward(role, kind, tier, GameState.selected_character_id, GameState.gear_luck(), rng)
	var i := 0
	for it in rw["items"]:
		spawn(parent, pos + Vector2(cos(i * 2.1), sin(i * 2.1)) * 18.0, it)
		i += 1
	var mats: Dictionary = rw["materials"]
	for m in mats.keys():
		spawn_material(parent, pos + Vector2(0, 16), str(m), int(mats[m]))
