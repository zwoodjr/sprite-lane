extends "res://scripts/ui/menu_base.gd"


func build(c: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 36)
	c.add_child(row)

	## Left: title + actions
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	row.add_child(left)
	left.add_child(spacer())
	var title := UiTheme.title_label("WANDERER", 84)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(title)
	var tag := UiTheme.body_label("Drop in. Grab what you can. Get out before the dust takes you.", 19, UiTheme.TEXT)
	left.add_child(tag)
	left.add_child(spacer(false, 10))
	var first := not GameState.tutorial_done
	var play := UiTheme.big_button("PLAY" if not first else "PLAY  ·  tutorial on", UiTheme.AMBER, 84, 32)
	play.custom_minimum_size.x = 380
	play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	play.pressed.connect(GameState.go_mode_select)
	left.add_child(play)
	_pulse(play)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 12)
	left.add_child(sub)
	var how := UiTheme.big_button("HOW TO PLAY", UiTheme.TEAL, 60, 19)
	how.pressed.connect(GameState.go_how_to_play)
	sub.add_child(how)
	var set_b := UiTheme.big_button("SETTINGS", UiTheme.LINE, 60, 19)
	set_b.pressed.connect(GameState.go_settings)
	sub.add_child(set_b)
	if not OS.has_feature("mobile"):
		var quit := UiTheme.big_button("QUIT", UiTheme.LINE, 60, 19)
		quit.custom_minimum_size.x = 110
		quit.pressed.connect(func() -> void: get_tree().quit())
		sub.add_child(quit)
	left.add_child(spacer())

	## Right: profile card
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	row.add_child(right)
	right.add_child(spacer())
	var pc := card(UiTheme.LINE, Color(0.1, 0.075, 0.055, 0.86))
	right.add_child(pc)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	pc.add_child(pv)
	pv.add_child(UiTheme.body_label("YOUR WANDERER", 14, UiTheme.AMBER))
	_stat(pv, "Account XP", str(GameState.account_xp))
	_stat(pv, "Successful extracts", str(GameState.successful_extracts))
	_stat(pv, "Runs played", str(GameState.total_runs))
	_stat(pv, "Best payout", "%d scrap" % GameState.best_payout)
	_stat(pv, "Garage tokens", str(GameState.garage_tokens))
	var mount_name := "Skateboard" if GameState.mount_unlock_tier == 0 else "Scooter"
	_stat(pv, "Mount", mount_name)
	if GameState.mount_unlock_tier == 0:
		pv.add_child(UiTheme.body_label("Scooter unlocks after %d more extract(s)." % maxi(0, 3 - GameState.successful_extracts), 12, UiTheme.TEXT_DIM))
	right.add_child(spacer())


func _stat(parent: Control, k: String, v: String) -> void:
	var h := HBoxContainer.new()
	var kl := UiTheme.body_label(k, 16, UiTheme.TEXT_DIM, false)
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(kl)
	h.add_child(UiTheme.body_label(v, 16, UiTheme.TEXT, false))
	parent.add_child(h)


func _pulse(b: Control) -> void:
	await get_tree().process_frame
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween().set_loops()
	tw.tween_property(b, "scale", Vector2(1.03, 1.03), 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
