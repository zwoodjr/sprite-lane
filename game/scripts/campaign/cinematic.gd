extends CanvasLayer

## Epilogue cinematic: the painted hangar (the same art as the Hangar screen)
## with Helm's plane outside the door, built from every layer at last. The
## story plays over it; takeoff() rolls the plane out and climbs it into the
## sunset. Covers the world and the run HUD while it's up.

const BACKDROP := "res://assets/sprites/hangar/backdrop.png"
const CANVAS := Vector2(1200, 750)

var _root: Control
var _art: Control
var _plane: Control
var _scale: float = 1.0
var _off: Vector2 = Vector2.ZERO
var _t: float = 0.0
var flying: bool = false


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color("140c0e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_art)
	var bd := TextureRect.new()
	bd.texture = load(BACKDROP)
	bd.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bd.stretch_mode = TextureRect.STRETCH_SCALE
	bd.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bd.name = "Backdrop"
	_art.add_child(bd)
	## Helm's plane: every layer, outside the door.
	_plane = Control.new()
	_plane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_plane)
	for i in range(1, 9):
		var pp := ZoneDefs.PLANE_LAYER % i
		if not ResourceLoader.exists(pp):
			continue
		var pl := TextureRect.new()
		pl.texture = load(pp)
		pl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pl.stretch_mode = TextureRect.STRETCH_SCALE
		pl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_plane.add_child(pl)
	## The heart's glow on the engine (power ending only).
	if GameState.campaign_flag_is("ending", "power"):
		var glow := _Glow.new()
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_plane.add_child(glow)
	_layout()
	get_viewport().size_changed.connect(_layout)


## Fill the screen height, centred on the hangar door.
func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_scale = maxf(vp.y * 0.62 / CANVAS.y, vp.x / CANVAS.x)
	var w := CANVAS * _scale
	_off = Vector2(vp.x * 0.5 - 600.0 * _scale, vp.y * 0.06)
	_art.position = _off
	_art.size = w
	(_art.get_node("Backdrop") as Control).size = w
	if not flying:
		var r := ZoneDefs.PLANE_RECT
		_plane.position = r.position * _scale
		_plane.size = r.size * _scale


func _process(delta: float) -> void:
	_t += delta


## Roll out, lift, climb into the sun and shrink away.
func takeoff() -> void:
	flying = true
	Juice.sfx("ab_drone", -2.0)
	var r := ZoneDefs.PLANE_RECT
	var start := r.position * _scale
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_plane, "position", start + Vector2(40, 6) * _scale, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_plane, "position", start + Vector2(180, -80) * _scale, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_plane, "rotation", -0.18, 1.2)
	tw.tween_property(_plane, "position", start + Vector2(520, -330) * _scale, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_plane, "scale", Vector2(0.25, 0.25), 1.6)
	tw.parallel().tween_property(_plane, "modulate:a", 0.0, 1.6).set_delay(0.6)
	Juice.shake(0.25)
	await tw.finished


class _Glow extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	## A DUST 3 light pool on the engine cowling (the only soft gradient kind).
	func _draw() -> void:
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		var c := Vector2(size.x * 0.9, size.y * 0.5)
		for i in range(4):
			draw_circle(c, size.y * (0.3 - i * 0.06), Color(1.0, 0.75, 0.25, (0.08 + 0.05 * k) * (i + 1) * 0.5))
