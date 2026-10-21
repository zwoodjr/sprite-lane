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
## Channel riser voice (stopped if the channel breaks).
var _chan_snd: Node = null
var last_chance: bool = false
## Military Base (Depth E7): a dead pad needs a power cell before it will channel.
var powered: bool = true
var _ping_t: float = 0.0 ## >0 while the "new pad" ping ring expands

@onready var sprite: Sprite2D = $Sprite
@onready var label: Label = $Label

var _ring: Node2D
var _beam: Polygon2D
var _core: Polygon2D
var _pxbeam: Node2D ## pixel beam strip at the pad (bone core, teal bands, motes)
const BEAM_H := 1500.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label.add_theme_font_size_override("font_size", 13)
	label.offset_left = -90.0
	label.offset_right = 90.0
	label.offset_top = 74.0
	label.offset_bottom = 100.0
	if sprite:
		sprite.scale = Vector2.ONE * UnitAnim.prop_scale(sprite.texture)
	## Sky-beam (audit #5): a tall additive light pillar, bright at the pad and
	## fading upward, so an open pad reads from well off-screen.
	_beam = Polygon2D.new()
	_beam.polygon = PackedVector2Array([Vector2(-44, 0), Vector2(44, 0), Vector2(26, -BEAM_H), Vector2(-26, -BEAM_H)])
	_beam.vertex_colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	_beam.color = Color(1.0, 0.85, 0.4, 0.0)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam.material = add
	_beam.z_as_relative = false
	_beam.z_index = 24
	add_child(_beam)
	_core = Polygon2D.new()
	_core.polygon = PackedVector2Array([Vector2(-12, 0), Vector2(12, 0), Vector2(6, -BEAM_H), Vector2(-6, -BEAM_H)])
	_core.vertex_colors = _beam.vertex_colors
	_core.material = add
	_core.z_as_relative = false
	_core.z_index = 24
	add_child(_core)
	_pxbeam = Juice.px_loop(self, "fx_beam", Vector2(0, 4)) as Node2D
	if _pxbeam:
		_pxbeam.z_as_relative = false
		_pxbeam.z_index = 24
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
	return (CHANNEL_TIME if not GameState.fast_timers else 0.5) * GameState.tonic_fx_mult("channel_mult")

func reset_channel() -> void:
	if _channel > 0.0 and not _fired:
		_channel = 0.0
		channel_changed.emit(0.0)
		Juice.float_text(global_position + Vector2(0, -60), "INTERRUPTED", Color(1, 0.4, 0.3), 14)
		_cancel_channel_sound()

func set_open(is_open: bool) -> void:
	open = is_open
	if not open:
		_channel = 0.0
	if sprite:
		sprite.texture = load(
			"res://assets/sprites/props_hd/extract_open.png" if open else "res://assets/sprites/props_hd/extract_sealed.png"
		) as Texture2D
		sprite.scale = Vector2.ONE * UnitAnim.prop_scale(sprite.texture)
	if open and not powered:
		label.text = "%s · NO POWER — bring a cell" % pad_name
		label.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
	elif open:
		label.text = "%s · OPEN" % pad_name
		label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if last_chance else Color(1.0, 0.85, 0.35))
	else:
		label.text = "%s · OPENING SOON" % pad_name
		label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))


func _process(delta: float) -> void:
	_t += delta
	## Extract is friendly: TEAL (bible §4); last chance goes SIGNAL red.
	var bc := Color(1.0, 0.35, 0.3) if last_chance else Color(0.36, 0.82, 0.75)
	if open and not powered:
		bc = Color(0.5, 0.8, 1.0)
	## Vertex colours carry the upward fade; modulate carries hue + pulse
	## (Polygon2D ignores .color once vertex_colors are set).
	_beam.modulate = Color(bc, (0.26 + 0.08 * sin(_t * 3.0)) if open else 0.0)
	_core.modulate = Color(bc.lerp(Color.WHITE, 0.4), (0.32 + 0.12 * sin(_t * 5.0)) if open else 0.0)
	_beam.visible = open
	if _pxbeam:
		_pxbeam.visible = open
		_pxbeam.modulate = Color(1.0, 0.45, 0.4) if last_chance else (Color(0.7, 0.85, 1.0) if not powered and open else Color.WHITE)
	_core.visible = open
	if open and player_inside and not powered and GameState.run_has_cell:
		set_powered(true)
		GameState.run_has_cell = false
		Juice.float_text(global_position + Vector2(0, -70), "POWERED!", Color(0.5, 0.9, 1.0), 18)
		Juice.sfx("ab_overload", -6.0)
	if open and player_inside and not _fired and powered:
		if _channel <= 0.05 and (_chan_snd == null or not is_instance_valid(_chan_snd) or not bool(_chan_snd.get("playing"))):
			_chan_snd = Juice.sfx("pad_channel")
			if _chan_snd:
				_chan_snd.set("pitch_scale", clampf(3.0 / maxf(_need(), 0.1), 0.7, 2.5))
		_channel += delta
		channel_changed.emit(_channel / _need())
		if int(_channel * 10.0) % 3 == 0:
			Juice.burst(global_position + Vector2(randf_range(-40, 40), 10), Color(1, 0.85, 0.4, 0.8), 2, 60.0, 0.6)
		if _channel >= _need():
			_fired = true
			extract_requested.emit()
	elif _channel > 0.0:
		if not _fired:
			_cancel_channel_sound()
		_channel = maxf(0.0, _channel - delta * 3.0)
		channel_changed.emit(_channel / _need())
	if open and powered and player_inside and Input.is_action_just_pressed("interact") and not _fired:
		_fired = true
		extract_requested.emit()
	_ring.queue_redraw()


func _cancel_channel_sound() -> void:
	if _chan_snd != null and is_instance_valid(_chan_snd) and bool(_chan_snd.get("playing")) and _chan_snd.get_meta("sid", "") == "pad_channel":
		_chan_snd.call("stop")
		Juice.sfx("pad_cancel")
	_chan_snd = null


func _draw_ring() -> void:
	var r := 70.0
	if open:
		## Ground light pooled on the pad.
		var gc := Color(1, 0.4, 0.3) if last_chance else Color(1, 0.85, 0.45)
		for i in 4:
			_ring.draw_circle(Vector2.ZERO, r * (1.0 - i * 0.2), Color(gc, 0.07))
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		var rc := Color(1, 0.4, 0.3) if last_chance else Color(1, 0.85, 0.35)
		_ring.draw_arc(Vector2.ZERO, r + pulse * 6.0, 0.0, TAU, 48, Color(rc.r, rc.g, rc.b, 0.35 + 0.3 * pulse), 3.0, true)
	if _channel > 0.0:
		var k := clampf(_channel / _need(), 0.0, 1.0)
		_ring.draw_arc(Vector2.ZERO, r - 8.0, -PI * 0.5, -PI * 0.5 + TAU * k, 48, Color(0.45, 1.0, 0.6, 0.95), 8.0, true)


func set_powered(on: bool) -> void:
	powered = on
	if sprite:
		sprite.modulate = Color.WHITE if on else Color(0.45, 0.48, 0.55)
	set_open(open)


func try_touch_extract() -> bool:
	if open and powered and player_inside and not _fired:
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
