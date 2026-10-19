extends Area2D

## Extract pad. When OPEN, stand on it and a ring fills over 3 s — extraction
## happens automatically when it completes. Leaving drains it; taking a hit
## resets it. Last-chance pads are red.

signal extract_requested
signal channel_changed(ratio: float)

const CHANNEL_TIME := 3.0

@export var pad_name: String = "Extract"

var open: bool = false
var player_inside: bool = false
var _channel: float = 0.0
var _t: float = 0.0
var _fired: bool = false
var last_chance: bool = false
var _ping_t: float = 0.0 ## >0 while the "new pad" ping ring expands

@onready var sprite: Sprite2D = $Sprite
@onready var label: Label = $Label

var _ring: Node2D
var _beam: Polygon2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label.add_theme_font_size_override("font_size", 13)
	label.offset_left = -90.0
	label.offset_right = 90.0
	_beam = Polygon2D.new()
	_beam.polygon = PackedVector2Array([Vector2(-26, 0), Vector2(26, 0), Vector2(14, -420), Vector2(-14, -420)])
	_beam.color = Color(1.0, 0.85, 0.4, 0.0)
	_beam.z_index = 5
	add_child(_beam)
	_ring = Node2D.new()
	_ring.z_index = 6
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	set_open(false)


func set_last_chance(on: bool) -> void:
	last_chance = on
	if sprite:
		sprite.self_modulate = Color(1.0, 0.45, 0.4) if on else Color.WHITE
	set_open(open)

## Taking a hit while channeling knocks you off the pad's count.
## Dev quick-test timers shrink windows below 3 s, so shrink the channel too.
func _need() -> float:
	return CHANNEL_TIME if not GameState.fast_timers else 0.5

func reset_channel() -> void:
	if _channel > 0.0 and not _fired:
		_channel = 0.0
		channel_changed.emit(0.0)
		Juice.float_text(global_position + Vector2(0, -60), "INTERRUPTED", Color(1, 0.4, 0.3), 14)

func set_open(is_open: bool) -> void:
	open = is_open
	if not open:
		_channel = 0.0
	if sprite:
		sprite.texture = load(
			"res://assets/sprites/props/extract_open.png" if open else "res://assets/sprites/props/extract_sealed.png"
		) as Texture2D
	if open:
		label.text = "%s · OPEN" % pad_name
		label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if last_chance else Color(1.0, 0.85, 0.35))
	else:
		label.text = "%s · OPENING SOON" % pad_name
		label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))


func _process(delta: float) -> void:
	_t += delta
	_beam.color = (Color(1.0, 0.35, 0.3) if last_chance else Color(1.0, 0.85, 0.4))
	_beam.color.a = (0.22 + 0.1 * sin(_t * 3.0)) if open else 0.06
	if open and player_inside and not _fired:
		_channel += delta
		channel_changed.emit(_channel / _need())
		if int(_channel * 10.0) % 3 == 0:
			Juice.burst(global_position + Vector2(randf_range(-40, 40), 10), Color(1, 0.85, 0.4, 0.8), 2, 60.0, 0.6)
		if _channel >= _need():
			_fired = true
			extract_requested.emit()
	elif _channel > 0.0:
		_channel = maxf(0.0, _channel - delta * 3.0)
		channel_changed.emit(_channel / _need())
	if open and player_inside and Input.is_action_just_pressed("interact") and not _fired:
		_fired = true
		extract_requested.emit()
	_ring.queue_redraw()


func _draw_ring() -> void:
	var r := 52.0
	if open:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		var rc := Color(1, 0.4, 0.3) if last_chance else Color(1, 0.85, 0.35)
		_ring.draw_arc(Vector2.ZERO, r + pulse * 6.0, 0.0, TAU, 48, Color(rc.r, rc.g, rc.b, 0.35 + 0.3 * pulse), 3.0, true)
	if _channel > 0.0:
		var k := clampf(_channel / _need(), 0.0, 1.0)
		_ring.draw_arc(Vector2.ZERO, r - 8.0, -PI * 0.5, -PI * 0.5 + TAU * k, 48, Color(0.45, 1.0, 0.6, 0.95), 8.0, true)


func try_touch_extract() -> bool:
	if open and player_inside and not _fired:
		_fired = true
		extract_requested.emit()
		return true
	return false


func is_channeling() -> bool:
	return _channel > 0.0


func get_channel_ratio() -> float:
	return clampf(_channel / _need(), 0.0, 1.0)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
