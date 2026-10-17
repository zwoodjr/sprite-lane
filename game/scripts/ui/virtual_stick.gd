extends Control

## Floating virtual stick. Press anywhere in the pad → drag for direction.

signal stick_changed(vector: Vector2, active: bool)

@export var stick_radius: float = 56.0
@export var knob_radius: float = 22.0
@export var deadzone: float = 0.12
@export var base_color: Color = Color(1, 1, 1, 0.18)
@export var knob_color: Color = Color(0.95, 0.82, 0.45, 0.75)
@export var label_text: String = ""

var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _vector: Vector2 = Vector2.ZERO
var _active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	queue_redraw()


func get_vector() -> Vector2:
	return _vector


func is_active() -> bool:
	return _active


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _touch_index < 0:
			_touch_index = st.index
			_origin = st.position
			_knob = _origin
			_active = true
			_update_vector(_origin)
			accept_event()
		elif not st.pressed and st.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _touch_index:
			_update_vector(sd.position)
			accept_event()
	## Mouse fallback for editor testing without a device
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _touch_index < 0:
				_touch_index = 999
				_origin = mb.position
				_knob = _origin
				_active = true
				_update_vector(_origin)
				accept_event()
			elif not mb.pressed and _touch_index == 999:
				_release()
				accept_event()
	elif event is InputEventMouseMotion and _touch_index == 999:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_update_vector(mm.position)
			accept_event()


func _update_vector(local_pos: Vector2) -> void:
	var delta := local_pos - _origin
	var max_r := stick_radius
	if delta.length() > max_r:
		delta = delta.limit_length(max_r)
	_knob = _origin + delta
	var v := delta / max_r
	if v.length() < deadzone:
		_vector = Vector2.ZERO
	else:
		_vector = v.limit_length(1.0)
	stick_changed.emit(_vector, true)
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_active = false
	_vector = Vector2.ZERO
	_knob = _origin
	stick_changed.emit(Vector2.ZERO, false)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	## Resting ring in the middle of the pad when idle
	var base_c := _origin if _active else center
	var knob_c := _knob if _active else center
	draw_circle(base_c, stick_radius, base_color)
	draw_arc(base_c, stick_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
	draw_circle(knob_c, knob_radius, knob_color)
	if label_text != "":
		draw_string(ThemeDB.fallback_font, base_c + Vector2(-20, stick_radius + 18), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.55))
