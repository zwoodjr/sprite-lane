extends CanvasLayer

## Twin-stick mobile UX: floating sticks under the finger.
## Left half of screen → MOVE (origin = touch-down). Right half → AIM.
## Lift → hide/reset. Multi-touch independent.
## Uses _unhandled_input so Buttons still receive taps first.

const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")

@export var stick_radius: float = 88.0
@export var knob_radius: float = 36.0
@export var deadzone: float = 0.14
@export var response_power: float = 1.25

@onready var root: Control = $Root
@onready var stick_draw: Control = $Root/StickDraw
@onready var btn_fire: Button = $Root/FireBtn
@onready var btn_extract: Button = $Root/Actions/ExtractBtn
@onready var btn_ability: Button = $Root/Actions/AbilityBtn
@onready var btn_mount: Button = $Root/Actions/MountBtn
@onready var btn_pause: Button = $Root/PauseBtn
@onready var btn_auto: Button = $Root/AutoAimBtn
@onready var btn_fill: Button = $Root/FillBtn

var _move_id: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_knob: Vector2 = Vector2.ZERO
var _move_vec: Vector2 = Vector2.ZERO
var _move_ghost: Vector2 = Vector2.ZERO
var _move_active: bool = false

var _aim_id: int = -1
var _aim_origin: Vector2 = Vector2.ZERO
var _aim_knob: Vector2 = Vector2.ZERO
var _aim_vec: Vector2 = Vector2.ZERO
var _aim_ghost: Vector2 = Vector2.ZERO
var _aim_active: bool = false


func _ready() -> void:
	layer = 20
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stick_draw.set("host", self)
	_style_buttons()
	_apply_safe()
	visible = true
	btn_fire.button_down.connect(func() -> void: TouchInput.set_fire_held(true))
	btn_fire.button_up.connect(func() -> void: TouchInput.set_fire_held(false))
	btn_extract.pressed.connect(func() -> void: TouchInput.pulse_extract())
	btn_ability.pressed.connect(func() -> void: TouchInput.pulse_ability())
	btn_mount.pressed.connect(func() -> void: TouchInput.pulse_mount())
	btn_pause.pressed.connect(func() -> void: TouchInput.pulse_pause())
	btn_auto.pressed.connect(_toggle_auto_aim)
	btn_fill.pressed.connect(_toggle_fill)
	_refresh_auto_label()
	get_viewport().size_changed.connect(_apply_safe)


func _exit_tree() -> void:
	TouchInput.clear_sticks()
	TouchInput.set_fire_held(false)


func _style_buttons() -> void:
	for b: Button in [btn_fire, btn_extract, btn_ability, btn_mount, btn_pause, btn_auto, btn_fill]:
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_fire.add_theme_font_size_override("font_size", 28)
	btn_fire.modulate = Color(1.0, 0.55, 0.28, 1.0)


func _apply_safe() -> void:
	var m := MobileLayout.control_safe_margin()
	var win := DisplayServer.window_get_size()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = m.position.x
	root.offset_top = m.position.y
	root.offset_right = -(win.x - (m.position.x + m.size.x))
	root.offset_bottom = -(win.y - (m.position.y + m.size.y))


func _unhandled_input(event: InputEvent) -> void:
	## Prefer ScreenTouch/Drag (includes mouse→touch emulation from project settings).
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin_touch(st.index, st.position)
		else:
			_end_touch(st.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_drag_touch(sd.index, sd.position)
		get_viewport().set_input_as_handled()


func _begin_touch(index: int, screen_pos: Vector2) -> void:
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if screen_pos.x < half:
		if _move_id >= 0:
			return
		_move_id = index
		_move_origin = screen_pos
		_move_knob = screen_pos
		_move_ghost = screen_pos
		_move_active = true
		_move_vec = Vector2.ZERO
		TouchInput.set_move(Vector2.ZERO)
	else:
		if _aim_id >= 0:
			return
		_aim_id = index
		_aim_origin = screen_pos
		_aim_knob = screen_pos
		_aim_ghost = screen_pos
		_aim_active = true
		_aim_vec = Vector2.ZERO
		TouchInput.set_aim(Vector2.ZERO, false)
	stick_draw.queue_redraw()


func _drag_touch(index: int, screen_pos: Vector2) -> void:
	if index == _move_id:
		var delta := screen_pos - _move_origin
		if delta.length() > stick_radius * 1.35:
			_move_origin = screen_pos - delta.limit_length(stick_radius)
		_move_vec = _vector_from(_move_origin, screen_pos)
		_move_knob = _move_origin + _move_vec.limit_length(1.0) * stick_radius
		TouchInput.set_move(_move_vec)
	elif index == _aim_id:
		var delta2 := screen_pos - _aim_origin
		if delta2.length() > stick_radius * 1.35:
			_aim_origin = screen_pos - delta2.limit_length(stick_radius)
		_aim_vec = _vector_from(_aim_origin, screen_pos)
		_aim_knob = _aim_origin + _aim_vec.limit_length(1.0) * stick_radius
		TouchInput.set_aim(_aim_vec, false)
	stick_draw.queue_redraw()


func _end_touch(index: int) -> void:
	if index == _move_id:
		_move_ghost = _move_origin
		_move_id = -1
		_move_active = false
		_move_vec = Vector2.ZERO
		TouchInput.set_move(Vector2.ZERO)
	elif index == _aim_id:
		_aim_ghost = _aim_origin
		_aim_id = -1
		_aim_active = false
		_aim_vec = Vector2.ZERO
		TouchInput.set_aim(Vector2.ZERO, false)
	stick_draw.queue_redraw()


func _vector_from(origin: Vector2, tip: Vector2) -> Vector2:
	var delta := tip - origin
	if delta.length() > stick_radius:
		delta = delta.limit_length(stick_radius)
	var raw := delta / stick_radius
	var mag := raw.length()
	if mag < deadzone:
		return Vector2.ZERO
	var t := (mag - deadzone) / (1.0 - deadzone)
	t = pow(clampf(t, 0.0, 1.0), response_power)
	return raw.normalized() * t


## Called from StickDraw._draw() — must use c.draw_* on that control.
func paint_sticks(c: Control) -> void:
	var origin_offset := c.get_global_transform_with_canvas().origin
	if not _move_active and _move_ghost != Vector2.ZERO:
		_paint_one(c, _move_ghost - origin_offset, _move_ghost - origin_offset, false, Color(0.85, 0.9, 0.7), 0.14)
	if not _aim_active and _aim_ghost != Vector2.ZERO:
		_paint_one(c, _aim_ghost - origin_offset, _aim_ghost - origin_offset, false, Color(0.95, 0.55, 0.35), 0.14)
	if _move_active:
		_paint_one(c, _move_origin - origin_offset, _move_knob - origin_offset, true, Color(0.85, 0.9, 0.7), 0.92)
	if _aim_active:
		_paint_one(c, _aim_origin - origin_offset, _aim_knob - origin_offset, true, Color(0.95, 0.55, 0.35), 0.95)


func _paint_one(c: Control, origin: Vector2, knob: Vector2, active: bool, tint: Color, alpha: float) -> void:
	var fill := Color(tint.r, tint.g, tint.b, alpha * 0.25)
	var ring := Color(tint.r, tint.g, tint.b, alpha * 0.5)
	var knob_col := Color(tint.r, tint.g, tint.b, alpha)
	c.draw_circle(origin, stick_radius, fill)
	c.draw_arc(origin, stick_radius, 0.0, TAU, 64, ring, 3.0, true)
	var k := knob if active else origin
	c.draw_circle(k, knob_radius, knob_col)
	c.draw_arc(k, knob_radius, 0.0, TAU, 32, Color(1, 1, 1, alpha * 0.45), 2.0, true)


func _toggle_auto_aim() -> void:
	TouchInput.auto_aim = not TouchInput.auto_aim
	_refresh_auto_label()


func _refresh_auto_label() -> void:
	btn_auto.text = "AUTO-AIM: ON" if TouchInput.auto_aim else "AUTO-AIM: OFF"


func _toggle_fill() -> void:
	DisplayFit.toggle_fill_screen()
	btn_fill.text = "FILL ✓" if DisplayFit.is_filled() else "FILL"
