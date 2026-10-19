extends Node2D

## Depth E7 (Old Refinery): a locked bunker. Bring a key (elites carry them) to
## open it: scrap, a gear piece (rare+) and a shot at the tier's exclusive.

const TEX := "res://assets/sprites/depth/zone/bunker.png"
const TEX_OPEN := "res://assets/sprites/depth/zone/bunker_open.png"

var opened: bool = false
var _sprite: Sprite2D
var _label: Label
var _player: Node2D
var _hint_cd: float = 0.0


func _ready() -> void:
	add_to_group("bunkers")
	add_to_group("map_markers")
	set_meta("map_color", Color(1.0, 0.85, 0.45))
	_sprite = Sprite2D.new()
	if ResourceLoader.exists(TEX):
		_sprite.texture = load(TEX)
		_sprite.scale = Vector2.ONE * (120.0 / float(_sprite.texture.get_width()))
	_sprite.position = Vector2(0, -40)
	add_child(_sprite)
	_label = Label.new()
	_label.text = "LOCKED BUNKER"
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.position = Vector2(-60, -110)
	_label.size = Vector2(120, 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func _physics_process(delta: float) -> void:
	if opened:
		return
	_hint_cd = maxf(0.0, _hint_cd - delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return
	if _player.global_position.distance_to(global_position) < float(ZoneDefs.BUNKERS["open_r"]) + 30.0:
		if GameState.run_keys > 0:
			open_bunker()
		elif _hint_cd <= 0.0:
			_hint_cd = 3.0
			Juice.float_text(global_position + Vector2(0, -90), "Needs a key — elites carry them", Color(1.0, 0.85, 0.45), 14)


func open_bunker() -> bool:
	if opened or GameState.run_keys <= 0:
		return false
	GameState.run_keys -= 1
	opened = true
	remove_from_group("map_markers")
	if ResourceLoader.exists(TEX_OPEN):
		_sprite.texture = load(TEX_OPEN)
	_label.text = "OPENED"
	var parent := get_parent()
	var b: Dictionary = ZoneDefs.BUNKERS
	var r: Vector2i = b["scrap"]
	var sc := randi_range(r.x, r.y)
	LootDrop.spawn_burst(parent, global_position + Vector2(0, 10), "scrap", 6, float(sc))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tier := GameState.zone_tier()
	var it := GearDefs.roll_drop(tier, GameState.selected_character_id, GameState.gear_luck(), rng, "", "rare")
	if not it.is_empty():
		GearPickup.spawn(parent, global_position + Vector2(-26, 18), it)
	if not ZoneDefs.exclusive(tier).is_empty() and randf() < float(b["exclusive_chance"]):
		GearPickup.spawn(parent, global_position + Vector2(26, 18), GameState.make_exclusive(tier))
	Juice.sfx("extract_open")
	Juice.burst(global_position, Color(1.0, 0.85, 0.45), 24, 200.0, 0.6)
	Juice.float_text(global_position + Vector2(0, -100), "BUNKER OPEN", Color(1.0, 0.85, 0.45), 20)
	return true
