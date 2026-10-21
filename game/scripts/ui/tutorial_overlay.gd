extends Control

## First-run, non-blocking tutorial. Each step waits for the player to
## actually do the thing (move, shoot, dash…) and points at where to do it.
## Marks GameState.tutorial_done when finished or when the run ends.

## Cold open (audit #9): the run starts quiet — no enemies and a frozen clock —
## until the player has moved; then a few weak mobs walk in for the attack
## lesson (MatchController.release_cold_open). One prompt at a time, short.
const STEPS := [
	{"id": "move", "text": "Drag on the left side to move.", "target": "left"},
	{"id": "shoot", "text": "Enemies incoming! You attack on your own — just steer close.", "target": ""},
	{"id": "dash", "text": "Tap DASH to dodge. You can't be hurt mid-dash.", "target": "dash"},
	{"id": "fight", "text": "Red marks on the ground = an attack is coming. Step out!", "target": ""},
	{"id": "nav", "text": "Arrows on the screen edge point to the extract pads.", "target": "timer"},
	{"id": "wait_open", "text": "Survive and loot until the pads open.", "target": ""},
	{"id": "extract", "text": "Pads are open! Stand on one to get out with your loot.", "target": ""},
]

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

func setup(hud: Node) -> void:
	_hud = hud
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UiTheme.plate("panel_hi", 18.0, Color(1, 1, 1, 0.96)))
	add_child(_panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_counter = UiTheme.body_label("", 15, UiTheme.AMBER)
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_counter)
	_text = UiTheme.body_label("", 21)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.custom_minimum_size = Vector2(400, 0)
	v.add_child(_text)
	_bar = ProgressBar.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.custom_minimum_size = Vector2(400, 6)
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
	_counter.text = "%d / %d" % [mini(_step + 1, STEPS.size()), STEPS.size()]
	Juice.sfx("ui_tap")
	_panel.modulate.a = 0.0
	_panel.create_tween().tween_property(_panel, "modulate:a", 1.0, 0.25)
	queue_redraw()

func _finish() -> void:
	GameState.tutorial_done = true
	GameState.save_profile()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
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
	_panel.position = Vector2(vp.x * 0.5 - _panel.size.x * 0.5, vp.y * 0.70 - _panel.size.y)
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

func _draw() -> void:
	var target := str(STEPS[_step]["target"])
	if target == "":
		return
	var vp := get_viewport_rect().size
	var m := MobileLayout.control_safe_margin()
	var lh := bool(GameState.settings.get("left_handed", false))
	var pos := Vector2.ZERO
	var r := 70.0
	match target:
		"left":
			## Point at the ghost MOVE stick itself: a finger dot sweeps inside
			## it (no second stick / ring drawn — audit #9).
			var tc := get_tree().get_first_node_in_group("touch_controls")
			pos = tc.call("_ghost_pos") if tc and tc.has_method("_ghost_pos") else Vector2(vp.x * 0.26, vp.y * 0.8)
			var swipe := Vector2(cos(_t * 1.6), sin(_t * 1.6) * 0.6) * 34.0
			draw_circle(pos + swipe, 15.0, Color(1, 0.9, 0.7, 0.6))
			draw_arc(pos + swipe, 15.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 2.0, true)
			return
		"right":
			pos = Vector2(vp.x * 0.72, vp.y * 0.72)
			r = 100.0
		"dash":
			pos = m.position + Vector2(m.size.x - 92, m.size.y - 96)
			r = 58.0
		"timer":
			pos = Vector2(vp.x * 0.5, m.position.y + 40)
			r = 70.0
	if lh and target in ["right", "dash"]:
		pos.x = vp.x - pos.x
	var k := 0.5 + 0.5 * sin(_t * 5.0)
	draw_arc(pos, r + k * 10.0, 0.0, TAU, 48, Color(1, 0.8, 0.35, 0.5 + 0.4 * k), 4.0, true)
	draw_arc(pos, r + 18.0 + k * 14.0, 0.0, TAU, 48, Color(1, 0.8, 0.35, 0.2 * (1.0 - k)), 3.0, true)
	## Little finger-drag hint for the sticks
	if target in ["left", "right"]:
		var swipe := Vector2(cos(_t * 1.6), sin(_t * 1.6) * 0.6) * 46.0
		draw_circle(pos + swipe, 18.0, Color(1, 0.9, 0.7, 0.55))
		draw_arc(pos + swipe, 18.0, 0.0, TAU, 24, Color(1, 1, 1, 0.7), 2.0, true)
