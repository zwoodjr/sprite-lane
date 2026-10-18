extends Control

## Large floating virtual stick. Touch anywhere in the pad → origin follows thumb.

signal stick_changed(vector: Vector2, active: bool)

@export var stick_radius: float = 82.0
@export var knob_radius: float = 34.0
@export var deadzone: float = 0.14 ## snappy start without twitch at rest
@export var response_power: float = 1.2 ## mild curve — responsive but not linear jitter
@export var idle_alpha: float = 0.22
@export var active_alpha: float = 0.92
@export var base_color: Color = Color(1, 1, 1, 1)
@export var knob_color: Color = Color(0.95, 0.82, 0.45, 1)
@export var label_text: String = ""

var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _vector: Vector2 = Vector2.ZERO
var _smoothed: Vector2 = Vector2.ZERO
var _active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)
	set_process(true)
	queue_redraw()


func get_vector() -> Vector2:
	return _vector


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	## Smooth stick output so thumbs don't jitter aim/move
	var target := _vector if _active else Vector2.ZERO
	var prev_len := _smoothed.length()
	## Slightly snappier follow so release doesn't feel floaty on iPhone.
	_smoothed = _smoothed.lerp(target, clampf(delta * 22.0, 0.0, 1.0))
	if _smoothed.length() < 0.025:
		_smoothed = Vector2.ZERO
	if _active or prev_len > 0.01 or _smoothed.length() > 0.01:
		stick_changed.emit(_smoothed, _active)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _touch_index < 0:
			_begin(st.index, st.position)
			accept_event()
		elif not st.pressed and st.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _touch_index:
			_update_vector(sd.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _touch_index < 0:
				_begin(999, mb.position)
				accept_event()
			elif not mb.pressed and _touch_index == 999:
				_release()
				accept_event()
	elif event is InputEventMouseMotion and _touch_index == 999:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_update_vector(mm.position)
			accept_event()


func _begin(index: int, local_pos: Vector2) -> void:
	_touch_index = index
	_origin = local_pos
	_knob = local_pos
	_active = true
	_update_vector(local_pos)


func _update_vector(local_pos: Vector2) -> void:
	var delta := local_pos - _origin
	var max_r := stick_radius
	if delta.length() > max_r:
		delta = delta.limit_length(max_r)
	_knob = _origin + delta
	var raw := delta / max_r
	var mag := raw.length()
	if mag < deadzone:
		_vector = Vector2.ZERO
	else:
		## Remap deadzone → 1, then apply soft response curve for fine aim
		var t := (mag - deadzone) / (1.0 - deadzone)
		t = pow(clampf(t, 0.0, 1.0), response_power)
		_vector = raw.normalized() * t
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_active = false
	_vector = Vector2.ZERO
	_knob = size * 0.5
	_origin = _knob
	stick_changed.emit(Vector2.ZERO, false)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var base_c := _origin if _active else center
	var knob_c := _knob if _active else center
	var a := active_alpha if _active else idle_alpha
	var ring := Color(base_color.r, base_color.g, base_color.b, a * 0.35)
	var fill := Color(base_color.r, base_color.g, base_color.b, a * 0.22)
	var knob := Color(knob_color.r, knob_color.g, knob_color.b, a)
	## Outer hit-zone hint (full pad)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.04 if not _active else 0.08), true)
	draw_circle(base_c, stick_radius, fill)
	draw_arc(base_c, stick_radius, 0.0, TAU, 64, ring, 3.0, true)
	draw_circle(knob_c, knob_radius, knob)
	draw_arc(knob_c, knob_radius, 0.0, TAU, 32, Color(1, 1, 1, a * 0.5), 2.0, true)
	if label_text != "":
		var col := Color(1, 1, 1, 0.4 if not _active else 0.75)
		draw_string(ThemeDB.fallback_font, Vector2(12, 22), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
