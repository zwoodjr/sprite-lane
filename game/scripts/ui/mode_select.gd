extends "res://scripts/ui/menu_base.gd"

var _cards: Dictionary = {}
var _fast: Button

var _detail: VBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer

func build(c: VBoxContainer) -> void:
	var portrait := MobileLayout.is_portrait()
	c.add_theme_constant_override("separation", 10)
	c.add_child(header("CHOOSE THE DUST", GameState.go_main_menu))
	c.add_child(UiTheme.body_label("Ten tiers, named for how thick the Dust is. Extract on a tier to unlock the next.", 15 if portrait else 16, UiTheme.TEXT_DIM))
	if not GameState.is_tier_unlocked(int(GameState.get_mode()["tier"])):
		GameState.selected_mode_id = ModeDefs.HAZE_ID
	_detail = VBoxContainer.new()
	c.add_child(_detail)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 18
	c.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)
	for mode in ModeDefs.all_modes():
		_list.add_child(_tier_row(mode))

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	c.add_child(bottom)
	_fast = Button.new()
	_fast.toggle_mode = true
	_fast.focus_mode = Control.FOCUS_NONE
	_fast.button_pressed = GameState.fast_timers
	_fast.custom_minimum_size = Vector2(0, 52)
	_fast.add_theme_font_size_override("font_size", 14)
	_fast.toggled.connect(func(on: bool) -> void:
		GameState.fast_timers = on
		_refresh()
	)
	_fast.visible = GameState.dev_tools
	if not GameState.dev_tools:
		GameState.fast_timers = false
	bottom.add_child(_fast)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	var next := UiTheme.big_button("CHOOSE CHARACTER ›", UiTheme.AMBER, 64, 22)
	next.custom_minimum_size.x = 240 if portrait else 320
	next.pressed.connect(GameState.go_character_select)
	bottom.add_child(next)
	_refresh()
	## Bring the selected tier into view.
	await get_tree().process_frame
	var b: Variant = _cards.get(GameState.selected_mode_id, {}).get("button", null)
	if b is Control and is_instance_valid(b):
		_scroll.ensure_control_visible(b)


func select_tier(id: String) -> bool:
	var m := ModeDefs.get_mode(id)
	if not GameState.is_tier_unlocked(int(m["tier"])):
		Juice.sfx("empty", -6.0)
		return false
	GameState.selected_mode_id = str(m["id"])
	GameState.save_profile()
	Juice.sfx("ui_tap")
	_refresh()
	return true


## One compact row per tier; locked tiers say what opens them.
func _tier_row(mode: Dictionary) -> Control:
	var id := str(mode["id"])
	var tier := int(mode["tier"])
	var unlocked := GameState.is_tier_unlocked(tier)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 78)
	b.mouse_force_pass_scroll_events = true
	b.pressed.connect(func() -> void: select_tier(id))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	h.add_theme_constant_override("separation", 12)
	b.add_child(h)
	var num := UiTheme.title_label("%d" % tier, 30, UiTheme.AMBER if unlocked else Color(0.45, 0.38, 0.3))
	num.custom_minimum_size.x = 44
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(num)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var nm := UiTheme.body_label(str(mode["display_name"]).to_upper(), 22, UiTheme.TEXT if unlocked else Color(0.5, 0.44, 0.38), false)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	var sub := "Enemies %d%% · pays ×%.2f · death keeps %d%%" % [int(round(float(mode["enemy_hp"]) * 100.0)), float(mode["payout_mult"]), int(round(float(mode["death_keep"]) * 100.0))]
	if not unlocked:
		sub = "Locked — extract on %s to open" % str(ModeDefs.tier_mode(tier - 1)["display_name"])
	var sl := UiTheme.body_label(sub, 14, UiTheme.TEXT_DIM, false)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sl)
	var tags := PackedStringArray()
	if tier >= ModeDefs.ELITE_FROM_TIER:
		tags.append("ELITES x2" if tier >= ModeDefs.DOUBLE_ELITE_FROM_TIER else "ELITES")
	if tier >= ModeDefs.BOSS_FROM_TIER:
		tags.append("BOSSES")
	if tier <= GameState.best_tier_extracted:
		tags.append("CLEARED")
	var tg := UiTheme.body_label(" · ".join(tags), 13, UiTheme.RUST if unlocked else Color(0.45, 0.38, 0.3), false)
	tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tg)
	_cards[id] = {"button": b, "unlocked": unlocked}
	return b


## Detail card for the selected tier: timeline + the numbers that matter.
func _build_detail(mode: Dictionary) -> void:
	for ch in _detail.get_children():
		_detail.remove_child(ch)
		ch.free()
	var p := card(UiTheme.AMBER, Color(0.2, 0.14, 0.09, 0.95))
	_detail.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var name_l := UiTheme.title_label("%s · TIER %d" % [str(mode["display_name"]).to_upper(), int(mode["tier"])], 30)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	top.add_child(UiTheme.body_label("~%d min" % int(mode["target_minutes"]), 20, UiTheme.TEXT, false))
	v.add_child(UiTheme.body_label(str(mode.get("blurb", "")), 14, UiTheme.TEXT_DIM))
	var tl := Control.new()
	tl.custom_minimum_size = Vector2(0, 24)
	tl.draw.connect(_draw_timeline.bind(tl, mode))
	v.add_child(tl)
	var windows := 0
	for ph in mode["phases"]:
		if bool(ph["extract_open"]):
			windows += 1
	for line in [
		"First extract %d:%02d, then every %ds (open %ds) · %d windows + last chance" % [int(mode["first_window"]) / 60, int(mode["first_window"]) % 60, int(mode["window_every"]), int(mode["window_open"]), windows - 1],
		"Loot ×1.0 → ×%.1f · payout ×%.2f · death keeps %d%%" % [float(mode["loot_cap"]), float(mode["payout_mult"]), int(round(float(mode["death_keep"]) * 100.0))],
	]:
		v.add_child(UiTheme.body_label("• " + line, 15))


func _draw_timeline(c: Control, mode: Dictionary) -> void:
	var total := 0.0
	for p in mode["phases"]:
		total += float(p["duration"])
	var x := 0.0
	var w := c.size.x
	for p in mode["phases"]:
		var pw := float(p["duration"]) / total * w
		var col := Color(0.45, 0.95, 0.55) if bool(p["extract_open"]) else Color(0.55, 0.4, 0.25)
		if bool(p.get("is_last", false)):
			col = Color(0.95, 0.4, 0.3)
		c.draw_rect(Rect2(x + 1, 4, pw - 2, c.size.y - 8), col)
		x += pw

func _refresh() -> void:
	for id in _cards.keys():
		var on: bool = id == GameState.selected_mode_id
		var b: Button = _cards[id]["button"]
		var unlocked: bool = _cards[id]["unlocked"]
		var col := UiTheme.AMBER if on else (UiTheme.LINE if unlocked else Color(0.3, 0.25, 0.2))
		var bg := Color(0.24, 0.17, 0.1, 0.95) if on else (Color(0.14, 0.1, 0.075, 0.9) if unlocked else Color(0.09, 0.07, 0.05, 0.8))
		var kind := "panel_hi" if on else ("panel" if unlocked else "panel_steel")
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, UiTheme.plate(kind, 12.0, Color.WHITE if unlocked or on else Color(0.7, 0.7, 0.7)))
	_build_detail(GameState.get_mode())
	_fast.text = "Dev: quick-test timers %s" % ("ON (12%)" if GameState.fast_timers else "OFF")
