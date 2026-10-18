extends "res://scripts/ui/menu_base.gd"

## Meta scrap shop — permanent upgrades between runs.
## Touch-first ScrollContainer: rows must not eat drag; list width drives autowrap height.

var _scrap_label: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _scroll_y_keep: int = 0


func build(c: VBoxContainer) -> void:
	var portrait := MobileLayout.is_portrait()
	c.add_child(header("HANGAR", GameState.go_main_menu))
	## Short copy on portrait so the catalog keeps vertical room under Xogot chrome.
	var intro := UiTheme.body_label(
		"Banked scrap → permanent upgrades. In-run levels never carry." if portrait
		else "Spend banked scrap on permanent upgrades. In-run levels never carry — only what you buy here sticks after a wipe. Costs stretch so a few extracts won't dump the tree.",
		14 if portrait else 15, UiTheme.TEXT_DIM
	)
	c.add_child(intro)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16 if portrait else 24)
	c.add_child(top)
	_scrap_label = UiTheme.title_label("SCRAP %d" % GameState.account_scrap, 30 if portrait else 36, UiTheme.AMBER)
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.add_child(_scrap_label)
	var prestige := UiTheme.body_label(
		"Account Lv %d  ·  soft gate" % GameState.account_level if portrait
		else "Account Lv %d  ·  soft gate for higher tiers" % GameState.account_level,
		14 if portrait else 16, UiTheme.TEXT_DIM, false
	)
	prestige.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(prestige)

	_scroll = ScrollContainer.new()
	_scroll.name = "HangarScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	## Distinguish tap-to-buy from drag-to-scroll on skill rows.
	_scroll.scroll_deadzone = 18
	_scroll.clip_contents = true
	c.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	## Do not expand-fill height inside the scroller — content must be taller than the viewport.
	_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.add_child(_list)
	_scroll.resized.connect(_sync_list_width)
	_rebuild()

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 14)
	c.add_child(bottom)
	## Slightly shorter CTAs on portrait — Xogot Play toolbar eats bottom pixels.
	var btn_h := 64 if portrait else 72
	var play := UiTheme.big_button("DEPLOY", UiTheme.AMBER, btn_h, 24 if portrait else 26)
	play.custom_minimum_size.x = 240 if portrait else 280
	play.pressed.connect(GameState.go_mode_select)
	bottom.add_child(play)
	var menu := UiTheme.big_button("MENU", UiTheme.LINE, btn_h, 18 if portrait else 20)
	menu.pressed.connect(GameState.go_main_menu)
	bottom.add_child(menu)


func _sync_list_width() -> void:
	if _scroll == null or _list == null:
		return
	var bar_w := 0.0
	var vbar := _scroll.get_v_scroll_bar()
	if vbar != null and vbar.visible:
		bar_w = vbar.get_combined_minimum_size().x
	var w := _scroll.size.x - bar_w
	if w > 1.0:
		_list.custom_minimum_size.x = w


func _clamp_scroll() -> void:
	if _scroll == null:
		return
	_sync_list_width()
	var vbar := _scroll.get_v_scroll_bar()
	if vbar == null:
		_scroll.scroll_vertical = 0
		return
	var max_y := maxi(0, int(vbar.max_value - vbar.page))
	_scroll.scroll_vertical = clampi(_scroll_y_keep, 0, max_y)
	_scroll_y_keep = _scroll.scroll_vertical


func _clear_list() -> void:
	## queue_free keeps old rows for a frame → doubled height / stuck scroll after buy.
	var kids := _list.get_children()
	for c in kids:
		_list.remove_child(c)
		c.free()


func _rebuild() -> void:
	if _scroll != null:
		_scroll_y_keep = _scroll.scroll_vertical
	_clear_list()
	_scrap_label.text = "SCRAP %d" % GameState.account_scrap
	for entry in Progression.hangar_catalog_visible():
		_list.add_child(_row(entry))
	## End pad so the last skill clears thumbs / home indicator / Xogot chrome when scrolled down.
	var pad := Control.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.custom_minimum_size = Vector2(0, 36 if MobileLayout.is_portrait() else 16)
	_list.add_child(pad)
	_sync_list_width()
	call_deferred("_clamp_scroll")


func _row(entry: Dictionary) -> PanelContainer:
	var id := str(entry["id"])
	var rank := GameState.meta_rank(id)
	var max_r := int(entry.get("max_rank", 1))
	var need_lv := int(entry.get("min_account_level", 1))
	var cost := Progression.hangar_cost(entry, rank)
	var locked_lv := GameState.account_level < need_lv
	var maxed := rank >= max_r

	var p := card(UiTheme.LINE if not locked_lv else Color(0.3, 0.25, 0.2), Color(0.11, 0.08, 0.055, 0.9))
	## PASS: drag on the card body scrolls the list; only the buy button captures taps.
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.mouse_force_pass_scroll_events = true
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)

	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_PASS
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
	btn.custom_minimum_size.x = 140 if MobileLayout.is_portrait() else 160
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_force_pass_scroll_events = true
	h.add_child(btn)
	return p
