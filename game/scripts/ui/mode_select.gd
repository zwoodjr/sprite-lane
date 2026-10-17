extends "res://scripts/ui/menu_base.gd"

const ModeDefs = preload("res://scripts/data/mode_defs.gd")
const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")

var _cards: Dictionary = {}
var _fast: Button


func build(c: VBoxContainer) -> void:
	var portrait := MobileLayout.is_portrait()
	c.add_child(header("CHOOSE A RUN", GameState.go_main_menu))
	c.add_child(UiTheme.body_label("Pick how long and how dangerous. Longer runs pay more per extract and give more chances to get greedy.", 15 if portrait else 16, UiTheme.TEXT_DIM))
	var row: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	row.add_theme_constant_override("separation", 14 if portrait else 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(row)
	for mode in ModeDefs.all_modes():
		row.add_child(_mode_card(mode, portrait))
	## Locked tiers preview (designed, not built yet)
	var locked := card(Color(0.3, 0.25, 0.2), Color(0.1, 0.08, 0.06, 0.7))
	locked.custom_minimum_size = Vector2(0 if portrait else 190, 120 if portrait else 0)
	var lv := VBoxContainer.new()
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	locked.add_child(lv)
	lv.add_child(UiTheme.title_label("HARD+", 28, Color(0.5, 0.42, 0.35)))
	var ll := UiTheme.body_label("Coming soon.\nTougher enemies, fewer windows, bigger payouts.", 14, Color(0.55, 0.48, 0.4))
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(ll)
	row.add_child(locked)

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
	bottom.add_child(_fast)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	var next := UiTheme.big_button("CHOOSE CHARACTER ›", UiTheme.AMBER, 64, 22)
	next.custom_minimum_size.x = 240 if portrait else 320
	next.pressed.connect(GameState.go_character_select)
	bottom.add_child(next)
	_refresh()


func _mode_card(mode: Dictionary, portrait: bool = false) -> Control:
	var id := str(mode["id"])
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if portrait:
		b.custom_minimum_size = Vector2(0, 200)
	b.pressed.connect(func() -> void:
		GameState.selected_mode_id = id
		GameState.save_profile()
		Juice.sfx("ui_tap")
		_refresh()
	)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	v.add_theme_constant_override("separation", 6)
	b.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var name := UiTheme.title_label(str(mode["display_name"]).to_upper(), 40)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	var mins := UiTheme.body_label("~%d min" % int(mode["target_minutes"]), 22, UiTheme.TEXT, false)
	mins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(mins)
	## Phase timeline
	var tl := Control.new()
	tl.custom_minimum_size = Vector2(0, 26)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.draw.connect(_draw_timeline.bind(tl, mode))
	v.add_child(tl)
	var legend := HBoxContainer.new()
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_constant_override("separation", 14)
	for item in [["■ sealed", Color(0.55, 0.4, 0.25)], ["■ extract open", Color(0.45, 0.95, 0.55)], ["■ last chance", Color(0.95, 0.4, 0.3)]]:
		var ll := UiTheme.body_label(str(item[0]), 13, item[1], false)
		ll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend.add_child(ll)
	v.add_child(legend)
	var windows := 0
	for p in mode["phases"]:
		if bool(p["extract_open"]):
			windows += 1
	var lines := [
		"%d chances to extract" % windows,
		"Enemies at %d%% strength" % int(float(mode["enemy_hp"]) * 100.0),
		"Payout ×%.2f" % float(mode["payout_mult"]),
		"%d gear slots insured (kept even if you wipe)" % int(mode["insurance_slots"]),
	]
	for line in lines:
		var l := UiTheme.body_label("• " + line, 16)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	var tick := UiTheme.body_label("", 18, UiTheme.TEAL)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tick)
	_cards[id] = {"button": b, "tick": tick}
	return b


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
		var col := UiTheme.AMBER if on else UiTheme.LINE
		var bg := Color(0.24, 0.17, 0.1, 0.95) if on else Color(0.14, 0.1, 0.075, 0.9)
		for s in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(s, UiTheme.box(bg, col, 20, 4 if on else 2, 18))
		(_cards[id]["tick"] as Label).text = "✓ SELECTED" if on else ""
	_fast.text = "Dev: quick-test timers %s" % ("ON (12%)" if GameState.fast_timers else "OFF")
