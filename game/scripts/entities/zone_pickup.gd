extends Node2D

## Depth E7 zone pickups: bunker key, flare, air filter, power cell. Walk over it
## to take it; ZoneTwists decides what it does (via GameState run state).

const ICON := "res://assets/sprites/depth/icons/zone_%s.png"
const PICK_R := 34.0
const LABEL := {"key": "BUNKER KEY", "flare": "FLARE", "filter": "AIR FILTER", "power_cell": "POWER CELL"}
const COLOR := {"key": Color(1.0, 0.85, 0.45), "flare": Color(1.0, 0.55, 0.35), "filter": Color(0.75, 0.95, 0.55), "power_cell": Color(0.5, 0.9, 1.0)}

var kind: String = "key"
var _t: float = 0.0
var _sprite: Sprite2D
var _player: Node2D


func _ready() -> void:
	add_to_group("zone_pickups")
	add_to_group("map_markers")
	set_meta("map_color", COLOR.get(kind, Color.WHITE))
	z_index = 1
	_sprite = Sprite2D.new()
	var path := ICON % kind
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		_sprite.scale = Vector2.ONE * (36.0 / float(_sprite.texture.get_width()))
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_t += delta
	_sprite.position = Vector2(0, -12.0 + sin(_t * 3.0) * 3.0)
	_sprite.modulate = Color(1, 1, 1) * (1.0 + 0.3 * maxf(0.0, sin(_t * 2.4)))
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return
	if _player.global_position.distance_to(global_position) < PICK_R:
		take()


func take() -> void:
	var tw := get_tree().get_first_node_in_group("zone_twists")
	if tw != null and tw.has_method("on_pickup"):
		tw.call("on_pickup", kind, global_position)
	Juice.float_text(global_position + Vector2(0, -40), str(LABEL.get(kind, kind.to_upper())), COLOR.get(kind, Color.WHITE), 17)
	Juice.sfx("pickup")
	Juice.burst(global_position, COLOR.get(kind, Color.WHITE), 12, 120.0, 0.4)
	queue_free()
