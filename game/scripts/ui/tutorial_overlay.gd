extends Control

## First-run, non-blocking tutorial. Each step waits for the player to
## actually do the thing (move, shoot, dash…) and points at where to do it.
## Marks GameState.tutorial_done when finished or when the run ends.

## Cold open (audit #9): the run starts quiet — no enemies and a frozen clock —
## until the player has moved; then a few weak mobs walk in for the attack
## lesson (MatchController.release_cold_open). One prompt at a time, short.
## Style bible + Track D: worn plate, a 48-px set icon per step, the step
## counter as a pixel readout, Barlow body at 20, sizes on the 8-px grid and
## pixel-ring pointers (2-frame pulse, no anti-aliasing).
const STEPS := [
	{"id": "move", "head": "MOVE", "icon": "set_stick", "text": "Drag on the left side to move.", "target": "left"},
	{"id": "shoot", "head": "ATTACK", "icon": "hud_kills", "text": "Enemies incoming! You attack on your own. Just steer close.", "target": ""},
	{"id": "dash", "head": "DASH", "icon": "up_dust_runner", "text": "Tap DASH to dodge. You can't be hurt mid-dash.", "target": "dash"},
	{"id": "fight", "head": "DANGER", "icon": "hud_threat", "text": "Red marks on the ground mean an attack is coming. Step out!", "target": ""},
	{"id": "nav", "head": "EXTRACT", "icon": "cur_extract", "text": "Arrows on the screen edge point to the extract pads.", "target": "timer"},
	{"id": "wait_open", "head": "SURVIVE", "icon": "hud_timer", "text": "Survive and loot until the pads open.", "target": ""},
	{"id": "extract", "head": "GET OUT", "icon": "cur_extract", "text": "Pads are open! Stand on one to get out with your loot.", "target": ""},
]
const PANEL_W := 480.0
const RING := Color("ffc040")
const RING_DARK := Color("a8520f")
const INK := Color("140c0e")
const BONE := Color("e9dfc9")

var _hud: Node
var _step: int = 0
var _progress: float = 0.0
var _step_t: float = 0.0
var _t: float = 0.0
var _start_pos: Vector2 = Vector2.ZERO
var _start_kills: int = 0
var _dashed: bool = false
var _panel: PanelContainer
var _text: Label
var _counter: Label
var _bar: ProgressBar
var _icon: TextureRect
var _head: Label

func setup(hud: Node) -> void:
	_hud = hud
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UiTheme.plate("panel_hi", 16.0))
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	_panel.add_child(row)
	_icon = IconSet.rect("set_stick", 48)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	row.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	_head = UiTheme.head_label("", UiTheme.T_H3, UiTheme.AMBER)
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_head)
	_counter = UiTheme.pixel_label("", UiTheme.PX_S, UiTheme.TEXT_DIM)
	_counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_counter)
	_text = UiTheme.body_label("", UiTheme.T_BODY)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	_bar = ProgressBar.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	UiTheme.skin_bar(_bar, UiTheme.AMBER)
	v.add_child(_bar)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_signal("dashed"):
		p.dashed.connect(func() -> void: _dashed = true)
	_enter(0)

func event(id: String) -> void:
	if id == "extract_open":
		_enter(STEPS.size() - 1)

func _enter(i: int) -> void:
	if i == 1 and _hud and _hud.get_parent() and _hud.get_parent().has_method("release_cold_open"):
		_hud.get_parent().call("release_cold_open")
	_step = i
	_progress = 0.0
	_step_t = 0.0
	_dashed = false
	_start_kills = GameState.kills
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p:
		_start_pos = p.global_position
	var s: Dictionary = STEPS[_step]
	_text.text = str(s["text"])
	_head.text = str(s["head"])
	_icon.texture = IconSet.tex(str(s["icon"]), true)
	_counter.text = "%d/%d" % [mini(_step + 1, STEPS.size()), STEPS.size()]
	Juice.sfx("ui_tap")
	_panel.modulate.a = 0.0
	## 4-step pop-in (no smooth fade).
	var tw := _panel.create_tween()
	for a in [0.25, 0.5, 0.75, 1.0]:
		tw.tween_property(_panel, "modulate:a", a, 0.0)
		tw.tween_interval(0.05)
	queue_redraw()

func _finish() -> void:
	GameState.tutorial_done = true
	GameState.save_profile()
	var tw := create_tween()
	for a in [0.75, 0.5, 0.25, 0.0]:
		tw.tween_interval(0.1)
		tw.tween_property(self, "modulate:a", a, 0.0)
	tw.tween_callback(queue_free)

func _exit_tree() -> void:
	## Seeing the tutorial once (even partially) is enough.
	if not GameState.tutorial_done:
		GameState.tutorial_done = true
		GameState.save_profile()

func _process(delta: float) -> void:
	_t += delta
	_step_t += delta
	var vp := get_viewport_rect().size
	_panel.reset_size()
	## Above the thumb zone (stick + DASH/ABILITY caps), below the hero.
	_panel.position = (Vector2(vp.x * 0.5 - _panel.size.x * 0.5, vp.y * 0.70 - _panel.size.y) / 8.0).floor() * 8.0
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var id := str(STEPS[_step]["id"])
	match id:
		"move":
			if p:
				_progress = clampf(p.global_position.distance_to(_start_pos) / 220.0, 0.0, 1.0)
		"shoot":
			if p and bool(p.call("is_attacking")):
				_progress += delta / 1.0
			else:
				_progress += delta / 8.0
		"dash":
			if _dashed:
				_progress = 1.0
		"fight":
			_progress = 1.0 if GameState.kills > _start_kills else _step_t / 30.0
		"nav":
			_progress = _step_t / 7.0
		"wait_open":
			_progress = 0.0  ## advanced by the extract_open event
		"extract":
			_progress = _step_t / 9.0
	_bar.value = clampf(_progress, 0.0, 1.0)
	_bar.visible = id != "wait_open"
	if _progress >= 1.0:
		Juice.sfx("pick_rare", -6.0)
		if _step >= STEPS.size() - 1:
			_finish()
			set_process(false)
		else:
			_enter(_step + 1)
	queue_redraw()

## Pixel ring (no AA): 4-px BRASS/DUST band with an INK edge.
func _ring(pos: Vector2, r: float, col: Color) -> void:
	r = roundf(r / 2.0) * 2.0
	draw_arc(pos, r + 3.0, 0.0, TAU, 48, INK, 2.0, false)
	draw_arc(pos, r, 0.0, TAU, 48, col, 4.0, false)


## Finger dot: a chunky BONE disc with an INK rim, snapped to the 2-px texel.
func _finger(pos: Vector2, r: float) -> void:
	pos = (pos / 2.0).floor() * 2.0
	draw_circle(pos, r + 2.0, INK, true, -1.0, false)
	draw_circle(pos, r, Color(BONE, 0.75), true, -1.0, false)


func _draw() -> void:
	var target := str(STEPS[_step]["target"])
	if target == "":
		return
	var vp := get_viewport_rect().size
	var m := MobileLayout.control_safe_margin()
	var lh := bool(GameState.settings.get("left_handed", false))
	var pos := Vector2.ZERO
	var r := 72.0
	## Bible telegraph pulse: 2 frames at 4 fps (hard steps, no sine glow).
	var beat := int(_t * 4.0) % 2
	match target:
		"left":
			## Point at the ghost MOVE stick itself: a finger dot sweeps inside it.
			var tc := get_tree().get_first_node_in_group("touch_controls")
			pos = tc.call("_ghost_pos") if tc and tc.has_method("_ghost_pos") else Vector2(vp.x * 0.26, vp.y * 0.8)
			var swipe := Vector2(cos(_t * 1.6), sin(_t * 1.6) * 0.6) * 32.0
			_finger(pos + swipe, 14.0)
			return
		"right":
			pos = Vector2(vp.x * 0.72, vp.y * 0.72)
			r = 96.0
		"dash":
			pos = m.position + Vector2(m.size.x - 92, m.size.y - 96)
			r = 56.0
		"timer":
			pos = Vector2(vp.x * 0.5, m.position.y + 40)
			r = 72.0
	if lh and target in ["right", "dash"]:
		pos.x = vp.x - pos.x
	_ring(pos, r + 8.0 * beat, RING if beat == 0 else RING_DARK)
	if target in ["left", "right"]:
		var swipe := Vector2(cos(_t * 1.6), sin(_t * 1.6) * 0.6) * 48.0
		_finger(pos + swipe, 16.0)
