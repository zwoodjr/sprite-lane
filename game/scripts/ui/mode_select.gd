extends "res://scripts/ui/menu_base.gd"

var _cards: Dictionary = {}

func build(c: VBoxContainer) -> void:
	var portrait := MobileLayout.is_portrait()
	c.add_child(header("CHOOSE A RUN", GameState.go_main_menu))
	c.add_child(UiTheme.body_label(
		"How thick is the Dust? Higher tiers pay more — and keep more on death — but hit harder.",
		15 if portrait else 16, UiTheme.TEXT_DIM
	))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(scroll)
	var row: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	row.add_theme_constant_override("separation", 12 if portrait else 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)

	var unlocked := GameState.highest_tier_unlocked
	for mode in ModeDefs.all_modes():
		var tier := int(mode.get("tier", 1))
		## Ship 1–2 always; 3–10 after extracting the tier below.
		var open := tier <= 2 or tier <= unlocked
		row.add_child(_mode_card(mode, portrait, open))

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	c.add_child(bottom)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	var next := UiTheme.big_button("CHOOSE CHARACTER ›", UiTheme.AMBER, 64, 22)
	next.custom_minimum_size.x = 240 if portrait else 320
	next.pressed.connect(GameState.go_character_select)
	bottom.add_child(next)
	_refresh()

func _mode_card(mode: Dictionary, portrait: bool, unlocked: bool) -> Control:
	var id := str(mode["id"])
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if portrait:
		b.custom_minimum_size = Vector2(0, 150)
	else:
		b.custom_minimum_size = Vector2(200, 220)
	b.disabled = not unlocked
	if unlocked:
		b.pressed.connect(func() -> void:
			GameState.selected_mode_id = id
			GameState.save_profile()
			Juice.sfx("ui_tap")
			_refresh()
		)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)
	var title := UiTheme.title_label("%d · %s" % [int(mode["tier"]), str(mode["display_name"]).to_upper()], 28 if portrait else 32)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)
	if not unlocked:
		var lock := UiTheme.body_label("Locked — extract on the tier below", 13, Color(0.6, 0.5, 0.4))
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(lock)
	else:
		var lines := [
			"Enemies %d%% · Payout ×%.2f" % [int(float(mode["enemy_hp"]) * 100.0), float(mode["payout_mult"])],
			"Keep %d%% scrap on death" % int(float(mode["keep_on_death"]) * 100.0),
			"Loot cap ×%.1f · ~%d min" % [float(mode["loot_mult_cap"]), int(mode["target_minutes"])],
		]
		if bool(mode.get("elites", false)):
			lines.append("Elites in the mix")
		if bool(mode.get("bosses", false)):
			lines.append("Bosses can appear")
		for line in lines:
			var l := UiTheme.body_label("• " + line, 14)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(l)
	var tick := UiTheme.body_label("", 16, UiTheme.TEAL)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tick)
	_cards[id] = {"button": b, "tick": tick, "unlocked": unlocked}
	return b

func _refresh() -> void:
	for id in _cards.keys():
		var on: bool = id == GameState.selected_mode_id
		var b: Button = _cards[id]["button"]
		var unlocked: bool = bool(_cards[id]["unlocked"])
		var col := UiTheme.AMBER if on else UiTheme.LINE
		var bg := Color(0.24, 0.17, 0.1, 0.95) if on else Color(0.14, 0.1, 0.075, 0.9)
		if not unlocked:
			bg = Color(0.08, 0.06, 0.05, 0.85)
			col = Color(0.35, 0.28, 0.22)
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(s, UiTheme.box(bg, col, 18, 3 if on else 2, 14))
		(_cards[id]["tick"] as Label).text = "✓ SELECTED" if on and unlocked else ""
