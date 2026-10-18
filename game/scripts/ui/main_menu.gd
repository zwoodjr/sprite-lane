extends "res://scripts/ui/menu_base.gd"

func build(c: VBoxContainer) -> void:
	var portrait := MobileLayout.is_portrait()
	var row: BoxContainer
	if portrait:
		row = VBoxContainer.new()
	else:
		row = HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24 if portrait else 36)
	c.add_child(row)

	## Title + actions
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	row.add_child(left)
	if not portrait:
		left.add_child(spacer())
	var title := UiTheme.title_label("WANDERER", 72 if portrait else 84)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(title)
	var tag := UiTheme.body_label("Drop in. Grab what you can. Get out before the dust takes you.", 17 if portrait else 19, UiTheme.TEXT)
	left.add_child(tag)
	left.add_child(spacer(false, 8))
	var first := not GameState.tutorial_done
	var play := UiTheme.big_button("PLAY" if not first else "PLAY  ·  tutorial on", UiTheme.AMBER, 84, 32)
	play.custom_minimum_size.x = 280 if portrait else 380
	play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if not portrait else Control.SIZE_EXPAND_FILL
	play.pressed.connect(GameState.go_mode_select)
	left.add_child(play)
	_pulse(play)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 10)
	left.add_child(sub)
	var hangar := UiTheme.big_button("HANGAR", UiTheme.TEAL, 56, 18)
	hangar.pressed.connect(GameState.go_hangar)
	sub.add_child(hangar)
	var how := UiTheme.big_button("HOW TO PLAY", UiTheme.LINE, 56, 18)
	how.pressed.connect(GameState.go_how_to_play)
	sub.add_child(how)
	var set_b := UiTheme.big_button("SETTINGS", UiTheme.LINE, 56, 18)
	set_b.pressed.connect(GameState.go_settings)
	sub.add_child(set_b)
	if not OS.has_feature("mobile"):
		var quit := UiTheme.big_button("QUIT", UiTheme.LINE, 56, 18)
		quit.custom_minimum_size.x = 100
		quit.pressed.connect(func() -> void: get_tree().quit())
		sub.add_child(quit)
	if not portrait:
		left.add_child(spacer())

	## Progression card
	var right := VBoxContainer.new()
	if not portrait:
		right.custom_minimum_size = Vector2(320, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	if not portrait:
		right.add_child(spacer())
	var pc := card(UiTheme.LINE, Color(0.1, 0.075, 0.055, 0.86))
	right.add_child(pc)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	pc.add_child(pv)
	pv.add_child(UiTheme.body_label("YOUR WANDERER", 14, UiTheme.AMBER))

	_stat(pv, "Banked scrap", str(GameState.account_scrap))

	var ab: Dictionary = GameState.account_bar_state()
	_stat(pv, "Account level", "Lv %d (prestige)" % int(ab["level"]))
	var xp_row := VBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 2)
	pv.add_child(xp_row)
	var xp_bar := ProgressBar.new()
	xp_bar.min_value = 0.0
	xp_bar.max_value = 1.0
	xp_bar.value = float(ab["ratio"])
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 18)
	xp_bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.TEAL, Color(0, 0, 0, 0), 6, 0, 0))
	xp_bar.add_theme_stylebox_override("background", UiTheme.box(Color(0.08, 0.06, 0.05, 0.9), UiTheme.LINE, 6, 2, 0))
	xp_row.add_child(xp_bar)
	xp_row.add_child(UiTheme.body_label(
		"%d / %d XP to next · gates Hangar tiers" % [int(ab["into"]), int(ab["need"])],
		12, UiTheme.TEXT_DIM, false
	))

	_stat(pv, "Successful extracts", str(GameState.successful_extracts))
	_stat(pv, "Best payout", "%d scrap" % GameState.best_payout)

	var ranks: PackedStringArray = PackedStringArray()
	for id in GameState.meta_upgrades.keys():
		ranks.append("%s %d" % [str(id).replace("_", " "), int(GameState.meta_upgrades[id])])
	if ranks.size() > 0:
		pv.add_child(UiTheme.body_label("Hangar: " + ", ".join(ranks), 12, UiTheme.TEAL))
	else:
		pv.add_child(UiTheme.body_label("Hangar empty — extract scrap, then Upgrade.", 12, UiTheme.TEXT_DIM))

	var mount_name := "Skateboard" if GameState.mount_unlock_tier == 0 else "Scooter"
	_stat(pv, "Mount", mount_name)
	if GameState.mount_unlock_tier == 0:
		pv.add_child(UiTheme.body_label(
			"Scooter unlocks after %d more extract(s)." % maxi(0, 3 - GameState.successful_extracts),
			12, UiTheme.TEXT_DIM
		))
	if not portrait:
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
