extends CanvasLayer

## In-run pause: Resume · How to play · Settings · Abandon run.
## Pauses the tree; this layer keeps processing.

const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const HelpViewer = preload("res://scripts/ui/help_viewer.gd")
var _dim: ColorRect
var _frame: MarginContainer
var _content: Control
var _confirm_abandon: bool = false

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.04, 0.03, 0.02, 0.78)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_frame = MarginContainer.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)

func open() -> void:
	if GameState.run_finished:
		return
	get_tree().paused = true
	TouchInput.clear_sticks()
	visible = true
	_show_main()

func close() -> void:
	get_tree().paused = false
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()

func _set_content(c: Control) -> void:
	for ch in _frame.get_children():
		ch.queue_free()
	var m := MobileLayout.control_safe_margin()
	var vp := get_viewport().get_visible_rect().size
	_frame.add_theme_constant_override("margin_left", int(m.position.x + vp.x * 0.06))
	_frame.add_theme_constant_override("margin_right", int(vp.x - m.position.x - m.size.x + vp.x * 0.06))
	_frame.add_theme_constant_override("margin_top", int(m.position.y + 10))
	_frame.add_theme_constant_override("margin_bottom", int(vp.y - m.position.y - m.size.y + 10))
	_frame.add_child(c)
	_content = c

func _show_main() -> void:
	_confirm_abandon = false
	var center := CenterContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(380, 0)
	center.add_child(v)
	v.add_child(UiTheme.title_label("PAUSED", 48))
	var info := UiTheme.body_label("%s · %s · Threat %d · Scrap %d" % [
		GameState.get_character().get("display_name", ""),
		GameState.get_mode().get("display_name", ""),
		GameState.threat_level,
		GameState.scrap_found,
	], 15, UiTheme.TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var resume := UiTheme.big_button("RESUME", UiTheme.TEAL, 70, 26)
	resume.pressed.connect(close)
	v.add_child(resume)
	var help := UiTheme.big_button("HOW TO PLAY", UiTheme.AMBER, 58, 20)
	help.pressed.connect(_show_help)
	v.add_child(help)
	var settings := UiTheme.big_button("SETTINGS", UiTheme.AMBER, 58, 20)
	settings.pressed.connect(_show_settings)
	v.add_child(settings)
	var quit := UiTheme.big_button("ABANDON RUN", UiTheme.RUST, 58, 20)
	quit.pressed.connect(func() -> void:
		if not _confirm_abandon:
			_confirm_abandon = true
			quit.text = "TAP AGAIN — counts as a wipe"
			return
		if not GameState.run_finished:
			GameState.on_wipe()
			GameState.result_summary = "Abandoned the run.\n" + GameState.result_summary
		GameState.go_result()
	)
	v.add_child(quit)
	_set_content(center)

func _show_help() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var viewer: VBoxContainer = VBoxContainer.new()
	viewer.set_script(HelpViewer)
	viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewer.finished.connect(_show_main)
	v.add_child(viewer)
	var back := UiTheme.big_button("BACK TO PAUSE", UiTheme.LINE, 50, 18)
	back.pressed.connect(_show_main)
	v.add_child(back)
	_set_content(v)

func _show_settings() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_child(UiTheme.title_label("SETTINGS", 34))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var back := UiTheme.big_button("DONE", UiTheme.TEAL, 52, 20)
	back.pressed.connect(_show_main)
	head.add_child(back)
	v.add_child(head)
	v.add_child(UiTheme.body_label("Layout changes (stick size, left-handed) apply next run.", 13, UiTheme.TEXT_DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var panel: VBoxContainer = VBoxContainer.new()
	panel.set_script(SettingsPanel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	v.add_child(scroll)
	_set_content(v)
