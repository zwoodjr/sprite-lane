extends CanvasLayer

## Mid-run level-up: pick one temporary loadout upgrade. Pauses the tree.

signal chosen(upgrade: Dictionary)

const Progression = preload("res://scripts/data/progression.gd")

var _root: Control
var _open: bool = false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	if not GameState.run_level_up.is_connected(_on_level_up):
		GameState.run_level_up.connect(_on_level_up)


func _on_level_up(new_level: int, choices: Array) -> void:
	open(new_level, choices)


func open(new_level: int, choices: Array) -> void:
	if _open:
		return
	if choices.is_empty():
		choices = Progression.roll_run_choices(2)
	## Headless / fast-timer bots: auto-pick so the match doesn't stall paused.
	if GameState.fast_timers and choices.size() > 0:
		GameState.apply_run_upgrade(choices[0])
		chosen.emit(choices[0])
		return
	_open = true
	get_tree().paused = true
	_root.visible = true
	for c in _root.get_children():
		c.queue_free()

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.03, 0.02, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.box(Color(0.14, 0.1, 0.07, 0.96), UiTheme.AMBER, 20, 3, 22))
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(UiTheme.title_label("RUN LEVEL %d" % new_level, 42, UiTheme.AMBER))
	var sub := UiTheme.body_label("Pick a loadout boost for this run only — resets when you extract or wipe.", 16, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)

	for u in choices:
		row.add_child(_choice_btn(u))

	Juice.sfx("ui_tap")
	Juice.haptic(35)


func _choice_btn(upgrade: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(240, 120)
	b.text = "%s\n%s" % [str(upgrade.get("name", "?")), str(upgrade.get("desc", ""))]
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_LIGHT, UiTheme.TEAL, 16, 3))
	b.add_theme_stylebox_override("hover", UiTheme.box(Color(0.28, 0.22, 0.14), UiTheme.AMBER, 16, 3))
	b.add_theme_stylebox_override("pressed", UiTheme.box(Color(0.35, 0.26, 0.14), UiTheme.AMBER, 16, 4))
	b.pressed.connect(func() -> void: _pick(upgrade))
	return b


func _pick(upgrade: Dictionary) -> void:
	GameState.apply_run_upgrade(upgrade)
	Juice.sfx("pickup")
	Juice.haptic(25)
	chosen.emit(upgrade)
	close()


func close() -> void:
	_open = false
	_root.visible = false
	for c in _root.get_children():
		c.queue_free()
	get_tree().paused = false
