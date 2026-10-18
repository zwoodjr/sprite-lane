extends "res://scripts/ui/menu_base.gd"

## Meta scrap shop — permanent upgrades between runs.

var _scrap_label: Label
var _list: VBoxContainer

func build(c: VBoxContainer) -> void:
	c.add_child(header("HANGAR", GameState.go_main_menu))
	var intro := UiTheme.body_label(
		"Spend banked scrap on permanent upgrades. In-run levels never carry — only what you buy here sticks after a wipe.",
		15, UiTheme.TEXT_DIM
	)
	c.add_child(intro)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	c.add_child(top)
	_scrap_label = UiTheme.title_label("SCRAP %d" % GameState.account_scrap, 36, UiTheme.AMBER)
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.add_child(_scrap_label)
	var prestige := UiTheme.body_label(
		"Account Lv %d  ·  soft gate for higher tiers" % GameState.account_level,
		16, UiTheme.TEXT_DIM, false
	)
	prestige.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(prestige)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_rebuild()

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 14)
	c.add_child(bottom)
	var play := UiTheme.big_button("DEPLOY", UiTheme.AMBER, 72, 26)
	play.custom_minimum_size.x = 280
	play.pressed.connect(GameState.go_mode_select)
	bottom.add_child(play)
	var menu := UiTheme.big_button("MENU", UiTheme.LINE, 72, 20)
	menu.pressed.connect(GameState.go_main_menu)
	bottom.add_child(menu)

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_scrap_label.text = "SCRAP %d" % GameState.account_scrap
	for entry in Progression.hangar_catalog():
		_list.add_child(_row(entry))

func _row(entry: Dictionary) -> PanelContainer:
	var id := str(entry["id"])
	var rank := GameState.meta_rank(id)
	var max_r := int(entry.get("max_rank", 1))
	var need_lv := int(entry.get("min_account_level", 1))
	var cost := Progression.hangar_cost(entry, rank)
	var locked_lv := GameState.account_level < need_lv
	var maxed := rank >= max_r

	var p := card(UiTheme.LINE if not locked_lv else Color(0.3, 0.25, 0.2), Color(0.11, 0.08, 0.055, 0.9))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(UiTheme.body_label(str(entry["name"]), 20, UiTheme.AMBER if not locked_lv else UiTheme.TEXT_DIM, false))
	var desc := str(entry.get("desc", ""))
	if locked_lv:
		desc += "  ·  needs Account Lv %d" % need_lv
	info.add_child(UiTheme.body_label(desc, 14, UiTheme.TEXT_DIM))
	info.add_child(UiTheme.body_label("Rank %d / %d" % [rank, max_r], 13, UiTheme.TEAL, false))

	var btn: Button
	if maxed:
		btn = UiTheme.big_button("MAXED", UiTheme.LINE, 64, 18)
		btn.disabled = true
	elif locked_lv:
		btn = UiTheme.big_button("LOCKED", UiTheme.LINE, 64, 18)
		btn.disabled = true
	else:
		btn = UiTheme.big_button("%d SCRAP" % cost, UiTheme.TEAL if GameState.account_scrap >= cost else UiTheme.RUST, 64, 18)
		btn.disabled = GameState.account_scrap < cost
		btn.pressed.connect(func() -> void:
			if GameState.try_buy_hangar(id):
				Juice.sfx("pickup")
				_rebuild()
			else:
				Juice.sfx("ui_tap")
		)
	btn.custom_minimum_size.x = 160
	h.add_child(btn)
	return p
