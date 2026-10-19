extends CanvasLayer

## Phone controls. All touches are routed here (true multi-touch):
##   - Floating MOVE stick: appears under the thumb anywhere in the left 60% of
##     the screen (right 60% when left-handed), base follows the thumb past the
##     rim, 10% dead zone, eased speed curve (full near the rim), fades on release.
##   - Right thumb: big DASH + smaller ABILITY bottle caps with cooldown rings.
##   - Pause cap in the top corner.
## Attacks are automatic (closest enemy in weapon range), so there's no FIRE.

const ActionButton = preload("res://scripts/ui/action_button.gd")

const BASE_STICK_RADIUS := 84.0
const KNOB_RADIUS := 34.0
const DEADZONE := 0.10      ## fraction of the radius ignored
const FULL_AT := 0.95       ## deflection for full speed (near the rim)
const CURVE := 1.6          ## >1 = finer control at small deflections
const STICK_ZONE_FRAC := 0.60
## Ignore stick starts in the top HUD band.
const TOP_BAND_FRAC := 0.16
const FADE_TIME := 0.35

@onready var root: Control = $Root
@onready var stick_draw: Control = $Root/StickDraw

var stick_radius: float = BASE_STICK_RADIUS

var btn_dash: Control
var btn_ability: Control
var btn_pause: Control
var _buttons: Array[Control] = []

var _move_id: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_knob: Vector2 = Vector2.ZERO
var _move_active: bool = false
var _fade: float = 0.0 ## 1 while held, decays after release

var _left_handed: bool = false
var _idle_t: float = 0.0
var _player: Node = null

func _ready() -> void:
	layer = 20
	## ALWAYS so finger-up events that happen while a menu has the tree paused
	## still release the stick / buttons (otherwise they stay "held" on resume).
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stick_draw.set("host", self)
	_left_handed = bool(GameState.settings.get("left_handed", false))
	stick_radius = BASE_STICK_RADIUS * float(GameState.settings.get("stick_scale", 1.0))

	btn_dash = _make_button("DASH", 62.0, UiTheme.TEAL, "res://assets/sprites/ui/btn_dash.png")
	btn_ability = _make_button("ABILITY", 44.0, UiTheme.AMBER,
		CharacterDefs.ability_icon_path(GameState.selected_character_id))
	btn_pause = _make_button("II", 24.0, Color(0.75, 0.68, 0.58), "res://assets/sprites/ui/btn_pause.png")

	btn_dash.pressed_down.connect(TouchInput.pulse_dash)
	btn_ability.pressed_down.connect(TouchInput.pulse_ability)
	btn_pause.pressed_down.connect(TouchInput.pulse_pause)

	_layout()
	get_viewport().size_changed.connect(_layout)
	TouchInput.sticks_cleared.connect(_reset_touches)
	if not TouchInput.touch_primary:
		## Desktop: keyboard. Keep pause visible, hide thumb controls.
		for b in [btn_dash, btn_ability]:
			b.visible = false

func _make_button(text: String, r: float, tint: Color, icon_path: String = "") -> Control:
	var b: Control = Control.new()
	b.set_script(ActionButton)
	b.set("label_text", text)
	b.set("radius", r)
	b.set("tint", tint)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.set("icon", load(icon_path))
	root.add_child(b)
	_buttons.append(b)
	return b

func _exit_tree() -> void:
	if TouchInput.sticks_cleared.is_connected(_reset_touches):
		TouchInput.sticks_cleared.disconnect(_reset_touches)
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
	## Bottom-right thumb cluster (mirrored when left-handed): big DASH in the
	## corner, ABILITY up-and-left of it.
	_place(btn_dash, Vector2(w - 78, h - 92))
	_place(btn_ability, Vector2(w - 186, h - 150))
	_place(btn_pause, Vector2(w - 26, 28), false)

func _place(b: Control, center: Vector2, mirror: bool = true) -> void:
	var c := center
	if mirror and _left_handed:
		c.x = MobileLayout.control_safe_margin().size.x - center.x
	var r := float(b.get("radius"))
	b.size = Vector2(r * 2.0, r * 2.0)
	b.pivot_offset = b.size * 0.5
	b.position = c - b.size * 0.5

func _reset_touches() -> void:
	for b in _buttons:
		if bool(b.get("held")):
			b.call("release")
	if _move_active:
		_move_active = false
	_move_id = -1
	if stick_draw:
		stick_draw.queue_redraw()

## --- Input routing -------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if get_tree().paused:
		## Menus own input while paused; only track lifts so nothing sticks.
		if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
			_end_touch((event as InputEventScreenTouch).index)
		return
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
	if not _in_stick_zone(pos) or _move_id >= 0:
		return false
	_move_id = index
	_move_origin = pos
	_move_knob = pos
	_move_active = true
	_fade = 1.0
	TouchInput.set_move(Vector2.ZERO)
	Juice.haptic(8)
	stick_draw.queue_redraw()
	return true

func _in_stick_zone(pos: Vector2) -> bool:
	var vp := get_viewport().get_visible_rect().size
	if pos.y < vp.y * TOP_BAND_FRAC:
		return false
	if _left_handed:
		return pos.x > vp.x * (1.0 - STICK_ZONE_FRAC)
	return pos.x < vp.x * STICK_ZONE_FRAC

func _drag_touch(index: int, pos: Vector2) -> bool:
	if index == _move_id:
		## Base follows the thumb past the rim → never "run out" of stick.
		var d := pos - _move_origin
		if d.length() > stick_radius:
			_move_origin = pos - d.normalized() * stick_radius
		_move_knob = pos
		TouchInput.set_move(stick_vector(_move_origin, pos, stick_radius))
		stick_draw.queue_redraw()
		return true
	for b in _buttons:
		if int(b.get("touch_index")) == index:
			## Slide off a button → release it.
			if not b.call("hit", pos, 1.8):
				b.call("release")
			return true
	return false

## Pure mapping (also used by tests): 10% dead zone, eased curve, full speed near the rim,
## direction is exact (instant turns), magnitude linear in between.
static func stick_vector(origin: Vector2, tip: Vector2, radius: float) -> Vector2:
	var raw := (tip - origin) / maxf(radius, 1.0)
	var mag := raw.length()
	if mag < DEADZONE:
		return Vector2.ZERO
	var t := clampf((mag - DEADZONE) / (FULL_AT - DEADZONE), 0.0, 1.0)
	return raw / mag * maxf(0.18, pow(t, CURVE))

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
	return false

## --- Per-frame state from the player (cooldowns, availability) -------------

func _process(delta: float) -> void:
	_idle_t += delta
	if not _move_active and _fade > 0.0:
		_fade = maxf(0.0, _fade - delta / FADE_TIME)
		stick_draw.queue_redraw()
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		btn_dash.set("cooldown_ratio", _player.call("get_dash_cooldown_ratio"))
		btn_ability.set("cooldown_ratio", _player.call("get_ability_cooldown_ratio"))
		btn_ability.set("label_text", str(_player.call("get_ability_short_name")))
		btn_ability.set("disabled", not bool(_player.call("has_ability")))
	if not _move_active and GameState.settings.get("show_hints", true):
		stick_draw.queue_redraw()

## Called from StickDraw._draw().
func paint_sticks(c: Control) -> void:
	var o := c.get_global_transform_with_canvas().origin
	var tint := Color(0.92, 0.88, 0.78)
	if _fade > 0.0:
		_paint_one(c, _move_origin - o, _move_knob - o, tint, _fade)
	elif TouchInput.touch_primary and GameState.settings.get("show_hints", true):
		_paint_ghost(c, _ghost_pos() - o, tint, "MOVE")

func _ghost_pos() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var p := Vector2(vp.x * 0.26, vp.y * 0.80)
	if _left_handed:
		p.x = vp.x - p.x
	return p

func _paint_ghost(c: Control, center: Vector2, tint: Color, text: String) -> void:
	var a := 0.12 + 0.05 * sin(_idle_t * 2.2)
	var base := UiTheme.tex("stick_base")
	var knob := UiTheme.tex("stick_knob")
	if base and knob:
		c.draw_texture_rect(base, Rect2(center - Vector2.ONE * stick_radius, Vector2.ONE * stick_radius * 2.0), false, Color(1, 1, 1, a * 2.6))
		var kr := KNOB_RADIUS * 0.9
		c.draw_texture_rect(knob, Rect2(center - Vector2.ONE * kr, Vector2.ONE * kr * 2.0), false, Color(1, 1, 1, a * 2.6))
	else:
		c.draw_arc(center, stick_radius, 0.0, TAU, 64, Color(tint.r, tint.g, tint.b, a * 1.6), 2.0, true)
		c.draw_circle(center, KNOB_RADIUS * 0.8, Color(tint.r, tint.g, tint.b, a))
	var font: Font = UiTheme.font_button
	var fs := 16
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string(font, center + Vector2(-w * 0.5, stick_radius + 22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(tint.r, tint.g, tint.b, a * 3.0))

func _paint_one(c: Control, origin: Vector2, knob: Vector2, tint: Color, alpha: float) -> void:
	var k := origin + (knob - origin).limit_length(stick_radius)
	var base_t := UiTheme.tex("stick_base")
	var knob_t := UiTheme.tex("stick_knob")
	if base_t and knob_t:
		## Brass bezel ring + steel bottle-cap knob (painted kit art).
		c.draw_texture_rect(base_t, Rect2(origin - Vector2.ONE * stick_radius, Vector2.ONE * stick_radius * 2.0), false, Color(1, 1, 1, alpha * 0.8))
		c.draw_arc(origin, stick_radius * FULL_AT, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, alpha * 0.22), 1.5, true)
		c.draw_circle(k + Vector2(0, 4), KNOB_RADIUS * 0.9, Color(0, 0, 0, 0.3 * alpha))
		var kr := KNOB_RADIUS * 1.08
		c.draw_texture_rect(knob_t, Rect2(k - Vector2.ONE * kr, Vector2.ONE * kr * 2.0), false, Color(1, 1, 1, alpha))
		return
	c.draw_circle(origin, stick_radius, Color(0.05, 0.03, 0.02, alpha * 0.22))
	c.draw_arc(origin, stick_radius, 0.0, TAU, 64, Color(tint.r, tint.g, tint.b, alpha * 0.5), 3.0, true)
	## Full-speed ring (60%) so the thumb learns how little travel it needs.
	c.draw_arc(origin, stick_radius * FULL_AT, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, alpha * 0.18), 1.5, true)
	c.draw_circle(k + Vector2(0, 3), KNOB_RADIUS, Color(0, 0, 0, 0.25 * alpha))
	c.draw_circle(k, KNOB_RADIUS, Color(tint.r, tint.g, tint.b, alpha * 0.85))
	c.draw_arc(k, KNOB_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, alpha * 0.55), 2.0, true)
