extends CanvasLayer

## Phone controls. All touches are routed here (true multi-touch):
##   Default (single stick): one floating MOVE stick (bottom zone / under thumb).
##     Run direction = aim + auto-fire. FIRE hold still works while idle.
##   Optional twin_stick: left half MOVE, right half AIM (push past ~⅓ to fire).
## Left-handed mode mirrors the button cluster (and stick halves in twin mode).

const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")
const ActionButton = preload("res://scripts/ui/action_button.gd")

const BASE_STICK_RADIUS := 92.0
const KNOB_RADIUS := 38.0
const MOVE_DEADZONE := 0.08
const AIM_DEADZONE := 0.12
## Single-stick: ignore stick starts in the top HUD band.
const SINGLE_STICK_TOP_FRAC := 0.32

@onready var root: Control = $Root
@onready var stick_draw: Control = $Root/StickDraw

var stick_radius: float = BASE_STICK_RADIUS

var btn_fire: Control
var btn_dash: Control
var btn_ability: Control
var btn_mount: Control
var btn_pause: Control
var _buttons: Array[Control] = []

var _move_id: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_knob: Vector2 = Vector2.ZERO
var _move_active: bool = false

var _aim_id: int = -1
var _aim_origin: Vector2 = Vector2.ZERO
var _aim_knob: Vector2 = Vector2.ZERO
var _aim_active: bool = false
var _aim_vec: Vector2 = Vector2.ZERO

var _left_handed: bool = false
var _twin: bool = false
var _idle_t: float = 0.0
var _player: Node = null


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_PAUSABLE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stick_draw.set("host", self)
	_left_handed = bool(GameState.settings.get("left_handed", false))
	_twin = bool(GameState.settings.get("twin_stick", false))
	stick_radius = BASE_STICK_RADIUS * float(GameState.settings.get("stick_scale", 1.0))

	btn_fire = _make_button("FIRE", "hold", 56.0, UiTheme.RUST)
	btn_dash = _make_button("DASH", "", 46.0, UiTheme.TEAL)
	btn_ability = _make_button("ABILITY", "", 46.0, UiTheme.AMBER)
	btn_mount = _make_button("MOUNT", "", 36.0, Color(0.6, 0.6, 0.75))
	btn_pause = _make_button("II", "", 30.0, Color(0.75, 0.68, 0.58))

	btn_fire.pressed_down.connect(func() -> void: TouchInput.set_fire_held(true))
	btn_fire.released.connect(func() -> void: TouchInput.set_fire_held(false))
	btn_dash.pressed_down.connect(TouchInput.pulse_dash)
	btn_ability.pressed_down.connect(TouchInput.pulse_ability)
	btn_mount.pressed_down.connect(TouchInput.pulse_mount)
	btn_pause.pressed_down.connect(TouchInput.pulse_pause)

	_layout()
	get_viewport().size_changed.connect(_layout)
	if not TouchInput.touch_primary:
		## Desktop: keyboard + mouse. Keep pause visible, hide thumb controls.
		for b in [btn_fire, btn_dash, btn_ability, btn_mount]:
			b.visible = false


func _make_button(text: String, sub: String, r: float, tint: Color) -> Control:
	var b: Control = Control.new()
	b.set_script(ActionButton)
	b.set("label_text", text)
	b.set("sub_text", sub)
	b.set("radius", r)
	b.set("tint", tint)
	root.add_child(b)
	_buttons.append(b)
	return b


func _exit_tree() -> void:
	TouchInput.clear_sticks()


func _layout() -> void:
	var m := MobileLayout.control_safe_margin()
	var win := get_viewport().get_visible_rect().size
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = m.position.x
	root.offset_top = m.position.y
	root.offset_right = -(win.x - (m.position.x + m.size.x))
	root.offset_bottom = -(win.y - (m.position.y + m.size.y))
	var w := m.size.x
	var h := m.size.y
	## Portrait-friendly cluster: bottom-right (mirrored when left-handed).
	## FIRE stays available for idle hold; smaller so it doesn't crowd DASH/ABILITY.
	_place(btn_fire, Vector2(w - 78, h - 210))
	_place(btn_dash, Vector2(w - 92, h - 96))
	_place(btn_ability, Vector2(w - 200, h - 78))
	_place(btn_mount, Vector2(w - 188, h - 188))
	_place(btn_pause, Vector2(w - 34, 36), false)


func _place(b: Control, center: Vector2, mirror: bool = true) -> void:
	var c := center
	if mirror and _left_handed:
		c.x = MobileLayout.control_safe_margin().size.x - center.x
	var r := float(b.get("radius"))
	b.size = Vector2(r * 2.0, r * 2.0)
	b.pivot_offset = b.size * 0.5
	b.position = c - b.size * 0.5


## --- Input routing -------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _begin_touch(st.index, st.position):
				get_viewport().set_input_as_handled()
		else:
			if _end_touch(st.index):
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _drag_touch(sd.index, sd.position):
			get_viewport().set_input_as_handled()


func _begin_touch(index: int, pos: Vector2) -> bool:
	## Buttons first (pick the closest one under the finger).
	var best: Control = null
	var best_d := INF
	for b in _buttons:
		if b.call("hit", pos):
			var d: float = (b.call("center_global") as Vector2).distance_to(pos)
			if d < best_d:
				best_d = d
				best = b
	if best:
		best.call("press", index)
		return true
	if not TouchInput.touch_primary:
		return false  ## desktop mouse emulation: don't spawn sticks

	if _twin:
		return _begin_twin(index, pos)
	return _begin_single(index, pos)


func _begin_single(index: int, pos: Vector2) -> bool:
	var vp := get_viewport().get_visible_rect().size
	## Keep top HUD clear; stick lives in the lower play field (survivor-style).
	if pos.y < vp.y * SINGLE_STICK_TOP_FRAC:
		return false
	if _move_id >= 0:
		return false
	_move_id = index
	_move_origin = pos
	_move_knob = pos
	_move_active = true
	TouchInput.set_move(Vector2.ZERO)
	stick_draw.queue_redraw()
	return true


func _begin_twin(index: int, pos: Vector2) -> bool:
	var half := get_viewport().get_visible_rect().size.x * 0.5
	var on_move_side := pos.x < half
	if _left_handed:
		on_move_side = not on_move_side
	if on_move_side:
		if _move_id >= 0:
			return false
		_move_id = index
		_move_origin = pos
		_move_knob = pos
		_move_active = true
		TouchInput.set_move(Vector2.ZERO)
	else:
		if _aim_id >= 0:
			return false
		_aim_id = index
		_aim_origin = pos
		_aim_knob = pos
		_aim_active = true
		_aim_vec = Vector2.ZERO
		TouchInput.set_aim(Vector2.ZERO)
	stick_draw.queue_redraw()
	return true


func _drag_touch(index: int, pos: Vector2) -> bool:
	if index == _move_id:
		_move_origin = _follow_origin(_move_origin, pos)
		var v := _vector_from(_move_origin, pos, MOVE_DEADZONE)
		_move_knob = _move_origin + (pos - _move_origin).limit_length(stick_radius)
		TouchInput.set_move(v)
		stick_draw.queue_redraw()
		return true
	if index == _aim_id:
		_aim_origin = _follow_origin(_aim_origin, pos)
		_aim_vec = _vector_from(_aim_origin, pos, AIM_DEADZONE)
		_aim_knob = _aim_origin + (pos - _aim_origin).limit_length(stick_radius)
		TouchInput.set_aim(_aim_vec)
		stick_draw.queue_redraw()
		return true
	for b in _buttons:
		if int(b.get("touch_index")) == index:
			## Slide off a button → release it (except FIRE, which stays held).
			if b != btn_fire and not b.call("hit", pos, 1.8):
				b.call("release")
			return true
	return false


func _end_touch(index: int) -> bool:
	for b in _buttons:
		if int(b.get("touch_index")) == index:
			b.call("release")
			return true
	if index == _move_id:
		_move_id = -1
		_move_active = false
		TouchInput.set_move(Vector2.ZERO)
		stick_draw.queue_redraw()
		return true
	if index == _aim_id:
		_aim_id = -1
		_aim_active = false
		_aim_vec = Vector2.ZERO
		TouchInput.set_aim(Vector2.ZERO)
		stick_draw.queue_redraw()
		return true
	return false


## Dynamic stick: if the thumb drifts past the ring, the ring follows it,
## so you never "run out" of stick and reversing direction is instant.
func _follow_origin(origin: Vector2, tip: Vector2) -> Vector2:
	var d := tip - origin
	if d.length() > stick_radius:
		return tip - d.normalized() * stick_radius
	return origin


func _vector_from(origin: Vector2, tip: Vector2, deadzone: float) -> Vector2:
	var raw := (tip - origin) / stick_radius
	var mag := raw.length()
	if mag < deadzone:
		return Vector2.ZERO
	var t := clampf((mag - deadzone) / (1.0 - deadzone), 0.0, 1.0)
	## Slight ease-out: small pushes still move you at a usable pace.
	t = 1.0 - pow(1.0 - t, 1.6)
	return raw.normalized() * t


## --- Per-frame state from the player (cooldowns, availability) -------------

func _process(delta: float) -> void:
	_idle_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		btn_dash.set("cooldown_ratio", _player.call("get_dash_cooldown_ratio"))
		btn_ability.set("cooldown_ratio", _player.call("get_ability_cooldown_ratio"))
		btn_ability.set("label_text", str(_player.call("get_ability_short_name")))
		btn_ability.set("disabled", not bool(_player.call("has_ability")))
		var mount_ok: bool = bool(_player.call("can_mount"))
		btn_mount.set("disabled", not mount_ok)
		btn_mount.set("label_text", "RIDE" if not _player.call("is_mounted") else "HOP OFF")
		if _twin:
			btn_fire.set("sub_text", "auto-aim" if GameState.settings.get("auto_aim", true) else "")
		else:
			btn_fire.set("sub_text", "idle" if GameState.settings.get("auto_fire", true) else "hold")
	if not _move_active and not _aim_active:
		stick_draw.queue_redraw()


## Called from StickDraw._draw().
func paint_sticks(c: Control) -> void:
	var o := c.get_global_transform_with_canvas().origin
	var move_tint := Color(0.85, 0.92, 0.75)
	var aim_tint := Color(0.98, 0.58, 0.36)
	if _move_active:
		_paint_one(c, _move_origin - o, _move_knob - o, move_tint, 0.95)
	elif TouchInput.touch_primary and GameState.settings.get("show_hints", true):
		var ghost := "MOVE · AIM" if not _twin else "MOVE"
		_paint_ghost(c, _ghost_pos(true) - o, move_tint, ghost)
	if _twin:
		if _aim_active:
			var firing := TouchInput.aim_stick_firing
			_paint_one(c, _aim_origin - o, _aim_knob - o, aim_tint, 0.95)
			if GameState.settings.get("aim_autofire", true):
				var ring_r := stick_radius * TouchInput.AIM_FIRE_THRESHOLD
				c.draw_arc(_aim_origin - o, ring_r, 0.0, TAU, 40, Color(1, 0.4, 0.2, 0.9 if firing else 0.35), 2.0, true)
		elif TouchInput.touch_primary and GameState.settings.get("show_hints", true):
			_paint_ghost(c, _ghost_pos(false) - o, aim_tint, "AIM + SHOOT" if GameState.settings.get("aim_autofire", true) else "AIM")


func _ghost_pos(move_side: bool) -> Vector2:
	var vp := c_vp()
	if not _twin:
		## Single stick: bottom-center, like the survivor ref.
		return Vector2(vp.x * 0.5, vp.y * 0.78)
	var left := Vector2(vp.x * 0.22, vp.y * 0.72)
	var right := Vector2(vp.x * 0.72, vp.y * 0.72)
	if _left_handed:
		left.x = vp.x - left.x
		right.x = vp.x - right.x
	return left if move_side else right


func c_vp() -> Vector2:
	return get_viewport().get_visible_rect().size


func _paint_ghost(c: Control, center: Vector2, tint: Color, text: String) -> void:
	var a := 0.16 + 0.06 * sin(_idle_t * 2.2)
	c.draw_arc(center, stick_radius, 0.0, TAU, 64, Color(tint.r, tint.g, tint.b, a * 1.6), 2.0, true)
	c.draw_circle(center, KNOB_RADIUS * 0.8, Color(tint.r, tint.g, tint.b, a))
	var font := ThemeDB.fallback_font
	var fs := 15
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string(font, center + Vector2(-w * 0.5, stick_radius + 22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(tint.r, tint.g, tint.b, a * 3.0))


func _paint_one(c: Control, origin: Vector2, knob: Vector2, tint: Color, alpha: float) -> void:
	c.draw_circle(origin, stick_radius, Color(tint.r, tint.g, tint.b, alpha * 0.16))
	c.draw_arc(origin, stick_radius, 0.0, TAU, 64, Color(tint.r, tint.g, tint.b, alpha * 0.55), 3.0, true)
	c.draw_line(origin, knob, Color(tint.r, tint.g, tint.b, alpha * 0.35), 6.0, true)
	c.draw_circle(knob + Vector2(0, 3), KNOB_RADIUS, Color(0, 0, 0, 0.25))
	c.draw_circle(knob, KNOB_RADIUS, Color(tint.r, tint.g, tint.b, alpha * 0.9))
	c.draw_arc(knob, KNOB_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, alpha * 0.55), 2.0, true)
