extends "res://scripts/ui/menu_base.gd"


func build(c: VBoxContainer) -> void:
	var won := GameState.extracted
	c.add_child(spacer())
	var title := UiTheme.title_label("EXTRACTED" if won else "WIPED", 76, Color(0.55, 1.0, 0.6) if won else UiTheme.DANGER)
	c.add_child(title)
	var lines := GameState.result_summary.split("\n")
	var sub := UiTheme.body_label(lines[0] if won else lines[0], 19)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(sub)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	c.add_child(row)
	if won:
		_tile(row, "PAYOUT", "%d" % GameState.payout_this_run, UiTheme.AMBER)
	_tile(row, "XP", "+%d" % GameState.xp_this_run, UiTheme.TEAL)
	_tile(row, "KILLS", str(GameState.kills), UiTheme.TEXT)
	_tile(row, "SCRAP FOUND", str(GameState.scrap_found), UiTheme.TEXT)
	_tile(row, "THREAT", str(GameState.threat_level), UiTheme.RUST)
	_tile(row, "STAY BONUS", "×%.2f" % GameState.stay_bonus, UiTheme.TEXT)

	var note := ""
	if won:
		note = "Payout = (100 + scrap×2 + kills×5) × Stay bonus × Threat payout × mode. Skip a window next time for a bigger multiplier."
		if GameState.payout_this_run >= GameState.best_payout and GameState.payout_this_run > 0:
			note = "NEW BEST PAYOUT!  " + note
	else:
		note = lines[lines.size() - 1] if lines.size() > 1 else ""
		note += "\nTip: extract during an early window if you're low — a small payout beats losing your gear."
	var nl := UiTheme.body_label(note, 15, UiTheme.TEXT_DIM)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(nl)
	c.add_child(spacer())

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 14)
	c.add_child(btns)
	var again := UiTheme.big_button("RUN IT BACK", UiTheme.AMBER, 70, 24)
	again.custom_minimum_size.x = 280
	again.pressed.connect(GameState.go_match)
	btns.add_child(again)
	var change := UiTheme.big_button("CHANGE SETUP", UiTheme.TEAL, 70, 20)
	change.pressed.connect(GameState.go_mode_select)
	btns.add_child(change)
	var menu := UiTheme.big_button("MENU", UiTheme.LINE, 70, 20)
	menu.pressed.connect(GameState.go_main_menu)
	btns.add_child(menu)


func _tile(parent: Control, k: String, v: String, col: Color) -> void:
	var p := card(UiTheme.LINE, Color(0.12, 0.09, 0.065, 0.9))
	p.custom_minimum_size = Vector2(130, 0)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(vb)
	var val := UiTheme.title_label(v, 34, col)
	vb.add_child(val)
	var key := UiTheme.body_label(k, 12, UiTheme.TEXT_DIM)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(key)
	parent.add_child(p)
	## pop-in
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_interval(0.08 * parent.get_child_count())
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
