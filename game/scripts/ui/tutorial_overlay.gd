extends Control

## First-run, non-blocking tutorial. Each step waits for the player to
## actually do the thing (move, shoot, dash…) and points at where to do it.
## Marks GameState.tutorial_done when finished or when the run ends.

const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")

const STEPS := [
	{"id": "move", "text": "Put your LEFT thumb anywhere on the left side and drag to MOVE.", "target": "left"},
	{"id": "shoot", "text": "Put your RIGHT thumb on the right side and drag to AIM. Push past the inner ring to SHOOT.", "target": "right"},
	{"id": "dash", "text": "Tap DASH to dodge. You're invincible for a split second — dash through bullets!", "target": "dash"},
	{"id": "fight", "text": "A red wedge means an enemy is about to attack. Take one down!", "target": ""},
	{"id": "nav", "text": "Gold arrows at the screen edge point to extract pads. They open when the top timer hits 0.", "target": "timer"},
	{"id": "wait_open", "text": "Survive and loot crates until the extract opens. Tap II any time for help.", "target": ""},
	{"id": "extract", "text": "EXTRACT OPEN! Walk onto a gold pad to leave — or stay longer to raise Threat for a bigger payout.", "target": ""},
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
	_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.08, 0.06, 0.04, 0.9), UiTheme.AMBER, 16, 3, 16))
	add_child(_panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_counter = UiTheme.body_label("", 12, UiTheme.AMBER)
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_counter)
	_text = UiTheme.body_label("", 17)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.custom_minimum_size = Vector2(440, 0)
	v.add_child(_text)
	_bar = ProgressBar.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.custom_minimum_size = Vector2(440, 6)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.AMBER, Color(0, 0, 0, 0), 3, 0, 0))
	v.add_child(_bar)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_signal("dashed"):
		p.dashed.connect(func() -> void: _dashed = true)
	_enter(0)


func event(id: String) -> void:
	if id == "extract_open":
		_enter(STEPS.size() - 1)


func _enter(i: int) -> void:
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
	_counter.text = "TUTORIAL  %d / %d" % [mini(_step + 1, STEPS.size()), STEPS.size()]
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
	## Bottom-center, between the thumbs — never over the character.
	_panel.position = Vector2(vp.x * 0.5 - _panel.size.x * 0.5, vp.y - _panel.size.y - 18.0)
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var id := str(STEPS[_step]["id"])
	match id:
		"move":
			if p:
				_progress = clampf(p.global_position.distance_to(_start_pos) / 220.0, 0.0, 1.0)
		"shoot":
			if TouchInput.is_firing():
				_progress += delta / 1.0
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
		Juice.sfx("pickup", -6.0)
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
			pos = Vector2(vp.x * 0.16, vp.y * 0.70)
			r = 100.0
		"right":
			pos = Vector2(vp.x * 0.62, vp.y * 0.62)
			r = 100.0
		"dash":
			pos = m.position + Vector2(m.size.x - 222, m.size.y - 58)
			r = 58.0
		"timer":
			pos = Vector2(vp.x * 0.5, m.position.y + 40)
			r = 70.0
	if lh and target in ["left", "right", "dash"]:
		pos.x = vp.x - pos.x
	var k := 0.5 + 0.5 * sin(_t * 5.0)
	draw_arc(pos, r + k * 10.0, 0.0, TAU, 48, Color(1, 0.8, 0.35, 0.5 + 0.4 * k), 4.0, true)
	draw_arc(pos, r + 18.0 + k * 14.0, 0.0, TAU, 48, Color(1, 0.8, 0.35, 0.2 * (1.0 - k)), 3.0, true)
	## Little finger-drag hint for the sticks
	if target in ["left", "right"]:
		var swipe := Vector2(cos(_t * 1.6), sin(_t * 1.6) * 0.6) * 46.0
		draw_circle(pos + swipe, 18.0, Color(1, 0.9, 0.7, 0.55))
		draw_arc(pos + swipe, 18.0, 0.0, TAU, 24, Color(1, 1, 1, 0.7), 2.0, true)
