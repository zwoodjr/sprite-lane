extends "res://scripts/ui/menu_base.gd"

const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

var _reset_confirm: bool = false


func build(c: VBoxContainer) -> void:
	c.add_child(header("SETTINGS", GameState.go_main_menu))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)
	var panel: VBoxContainer = VBoxContainer.new()
	panel.set_script(SettingsPanel)
	v.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var tut := UiTheme.big_button("REPLAY TUTORIAL", UiTheme.TEAL, 56, 18)
	tut.pressed.connect(func() -> void:
		GameState.tutorial_done = false
		GameState.save_profile()
		tut.text = "TUTORIAL ON FOR NEXT RUN ✓"
	)
	row.add_child(tut)
	var reset := UiTheme.big_button("RESET PROGRESS", UiTheme.RUST, 56, 18)
	reset.pressed.connect(func() -> void:
		if not _reset_confirm:
			_reset_confirm = true
			reset.text = "TAP AGAIN TO WIPE SAVE"
			return
		GameState.reset_profile()
		reset.text = "PROGRESS RESET ✓"
	)
	row.add_child(reset)
	if MobileLayout.is_desktop():
		var fill := UiTheme.big_button("FULLSCREEN", UiTheme.LINE, 56, 18)
		fill.pressed.connect(func() -> void:
			DisplayFit.toggle_fill_screen()
			fill.text = "FULLSCREEN ✓" if DisplayFit.is_filled() else "FULLSCREEN"
		)
		row.add_child(fill)
