extends Node2D

## A hidden lore page (Depth E3, Quill's Field Notes). Not on the minimap — a
## faint flutter and glow give it away. Kept the moment you pick it up.

const PICK_R := 34.0

var page_id: String = ""
var _t: float = 0.0
var _sprite: Sprite2D
var _player: Node2D


func _ready() -> void:
	add_to_group("lore_pages")
	z_index = 1
	_sprite = Sprite2D.new()
	if ResourceLoader.exists(BestiaryDefs.PAGE_ICON):
		_sprite.texture = load(BestiaryDefs.PAGE_ICON)
		_sprite.scale = Vector2.ONE * (30.0 / float(_sprite.texture.get_width()))
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_t += delta
	## Flutters in the wind, glints now and then.
	_sprite.position = Vector2(sin(_t * 1.7) * 3.0, -10.0 + sin(_t * 2.3) * 3.0)
	_sprite.rotation = sin(_t * 2.0) * 0.25
	_sprite.modulate = Color(1, 1, 1) * (1.0 + 0.35 * maxf(0.0, sin(_t * 1.3)))
	if _player == null or not is_instance_valid(_player) or not _player.is_in_group("player"):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return
	if _player.global_position.distance_to(global_position) < PICK_R:
		if GameState.find_page(page_id):
			var pg := BestiaryDefs.page(page_id)
			Juice.float_text(global_position + Vector2(0, -36), "LORE PAGE", Color(0.95, 0.88, 0.7), 18)
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_toast"):
				hud.call("show_toast", "Found a page: \"%s\" — read it in the Logbook" % str(pg.get("title", "")), Color(0.95, 0.88, 0.7))
			Juice.sfx("pickup")
		queue_free()
