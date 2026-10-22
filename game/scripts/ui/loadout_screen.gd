class_name LoadoutScreen
extends "res://scripts/ui/menu_base.gd"

## Gear screen: equip a survivor from the shared stash (brief Part 7).
## Top: who you are equipping (the survivor you deploy as — switching here
## switches the deploy survivor too, so prep and the match always match).
## Paper doll: armour left, accessories right, weapon + mods + patch below.
## Below: no slot picked = stats + set progress (tap a set for its pieces);
## slot picked = fitting stash items, icon-led; tap one to compare, EQUIP.

var _hero: String = ""
var _slot: String = ""
var _preview: int = -1
var _sort: String = "rarity"
var _hero_label: Label
var _grid: GridContainer
var _left: VBoxContainer
var _right: VBoxContainer
var _doll_hero: StripAnim
var _doll: HBoxContainer
var _strip: GridContainer
const LEFT_SLOTS := ["head", "shoulders", "chest", "legs"]
const RIGHT_SLOTS := ["hands", "boots", "charm", "vial"]
const BOTTOM_SLOTS := ["weapon", "mod1", "mod2", "patch"]
const SLOT_PX := 112.0
const SORTS := {"rarity": "RARITY", "newest": "NEW", "set": "SET"}
var _scroll: ScrollContainer
var _list: VBoxContainer
var _popup: Control


func build(c: VBoxContainer) -> void:
	c.add_theme_constant_override("separation", 16)
	_hero = GameState.selected_character_id
	c.add_child(header("GEAR", _back))

	## Who: ‹ NAME › — the survivor you will deploy as.
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 16)
	c.add_child(hr)
	var prev := UiTheme.big_button("‹", UiTheme.LINE, 64, 32)
	prev.custom_minimum_size.x = 96
	prev.pressed.connect(cycle_hero.bind(-1))
	hr.add_child(prev)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_theme_constant_override("separation", 0)
	hr.add_child(who)
	var cap := UiTheme.head_label("EQUIPPING · YOU DEPLOY AS", UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_child(cap)
	_hero_label = UiTheme.head_label("", UiTheme.T_H1, UiTheme.AMBER)
	_hero_label.name = "HeroName"
	_hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_label.clip_text = true
	who.add_child(_hero_label)
	var nxt := UiTheme.big_button("›", UiTheme.LINE, 64, 32)
	nxt.custom_minimum_size.x = 96
	nxt.pressed.connect(cycle_hero.bind(1))
	hr.add_child(nxt)

	## Paper doll: armour on the left, accessories on the right, weapon + mods
	## under the hero, who stands in the middle at an integer scale.
	_doll = HBoxContainer.new()
	_doll.add_theme_constant_override("separation", 16)
	c.add_child(_doll)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 8)
	_doll.add_child(_left)
	_doll_hero = StripAnim.make("", 256, 8.0)
	_doll_hero.custom_minimum_size = Vector2(256, 256)
	_doll_hero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_doll_hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_doll.add_child(_doll_hero)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 8)
	_doll.add_child(_right)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 8)
	c.add_child(_grid)
	## Picking: the doll folds into a 2 x 6 strip so the list gets the room.
	_strip = GridContainer.new()
	_strip.name = "SlotStrip"
	_strip.columns = 6
	_strip.add_theme_constant_override("h_separation", 16)
	_strip.add_theme_constant_override("v_separation", 8)
	_strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_strip.visible = false
	c.add_child(_strip)

	_scroll = ScrollContainer.new()
	_scroll.name = "GearScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 18
	c.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)

	var from_select := GameState.loadout_from in ["character_select", "prep"]
	var deploy := UiTheme.big_button("DONE" if from_select else "DEPLOY", UiTheme.AMBER, 80, 32)
	deploy.pressed.connect(func() -> void:
		_sync_hero()
		if GameState.loadout_from == "prep":
			GameState.go_prep()
		elif from_select:
			GameState.go_character_select()
		else:
			GameState.go_mode_select())
	c.add_child(deploy)
	_sync_hero()
	refresh()


## The Gear survivor IS the deploy survivor: keep GameState in step so prep,
## character select and the match show / apply exactly this loadout.
func _sync_hero() -> void:
	if GameState.selected_character_id != _hero:
		GameState.selected_character_id = _hero
	GameState.reset_loadout_to_defaults()
	GameState.save_profile()


func _back() -> void:
	_sync_hero()
	if GameState.loadout_from == "prep":
		GameState.go_prep()
	elif GameState.loadout_from == "character_select":
		GameState.go_character_select()
	else:
		GameState.go_hangar()


func get_hero() -> String:
	return _hero


func cycle_hero(step: int) -> void:
	var ids: Array = CharacterDefs.PLAYABLE_IDS
	var i := ids.find(_hero)
	_hero = str(ids[(i + step + ids.size()) % ids.size()])
	_slot = ""
	_preview = -1
	_sync_hero()
	refresh()


func set_hero(h: String) -> void:
	if CharacterDefs.is_playable(h):
		_hero = h
		_slot = ""
		_preview = -1
		_sync_hero()
		refresh()


func select_slot(sl: String) -> void:
	_slot = "" if _slot == sl else sl
	_preview = -1
	refresh()


## Tap a stash row: show its compare panel (tap again to fold it).
func preview_item(uid: int) -> void:
	_preview = -1 if _preview == uid else uid
	GameState.mark_seen(uid)
	_rebuild_list(true)


func set_sort(s: String) -> void:
	if SORTS.has(s):
		_sort = s
		_rebuild_list(false)


## uid of every item the doll shows (tests: what Gear shows = what deploys).
func shown_uids() -> Dictionary:
	var out := {}
	var eq := GameState.equipped_items(_hero)
	for sl in eq.keys():
		out[str(sl)] = int((eq[sl] as Dictionary).get("uid", -1))
	return out


func refresh() -> void:
	_hero_label.text = GearUi.hero_name(_hero).to_upper()
	_doll_hero.set_strip("res://assets/sprites/characters/%s/%s_idle.png" % [_hero, _hero])
	var eq := GameState.equipped_items(_hero)
	var picking := _slot != ""
	var was_picking := _strip.visible
	_doll.visible = not picking
	_grid.visible = not picking
	_strip.visible = picking
	var sets := [[_strip, GearDefs.LOADOUT_SLOTS, 96]] if picking else [[_left, LEFT_SLOTS, 112], [_right, RIGHT_SLOTS, 112], [_grid, BOTTOM_SLOTS, 112]]
	for box in [_left, _right, _grid, _strip]:
		for ch in box.get_children():
			box.remove_child(ch)
			ch.queue_free()
	for pair in sets:
		var box: Container = pair[0]
		for sl in pair[1]:
			box.add_child(_slot_tile(str(sl), eq.get(sl, {}), int(pair[2])))
	if picking != was_picking:
		var fade: Control = _strip if picking else _doll
		fade.modulate.a = 0.0
		fade.create_tween().tween_property(fade, "modulate:a", 1.0, 0.15)
	_rebuild_list(false)


func _rebuild_list(keep_scroll: bool) -> void:
	var y := _scroll.scroll_vertical
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	var eq := GameState.equipped_items(_hero)
	if _slot == "":
		_build_summary(eq)
	else:
		_build_picker(eq)
	if keep_scroll:
		_scroll.set_deferred("scroll_vertical", y)
	else:
		_scroll.scroll_vertical = 0


## Icon slot: the item's rarity well (or the slot's art, dimmed).
func _slot_tile(sl: String, item: Dictionary, px: int = 112) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.tooltip_text = GearDefs.SLOT_NAME.get(sl, sl)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(select_slot.bind(sl))
	var t := GearUi.tile(item, px, {"worn": false, "icon": _empty_icon(sl), "empty_alpha": 0.3})
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(t)
	if sl == _slot:
		var hi := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = UiTheme.AMBER
		sb.set_border_width_all(4)
		hi.add_theme_stylebox_override("panel", sb)
		hi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hi)
	if not item.is_empty() and int(GameState.insured.get(_hero, -1)) == int(item.get("uid", -2)):
		var ins := IconSet.rect("up_iron_tonic", 24)
		ins.position = Vector2(8, px - 32)
		b.add_child(ins)
	return b


func _empty_icon(sl: String) -> String:
	if sl == "weapon":
		var sts: Array = KitDefs.styles(_hero)
		return IconSet.style(_hero, str(sts[0]["id"])) if not sts.is_empty() else "slot_weapon"
	return IconSet.slot(sl)


## ---------------------------------------------------------------- summary

func _build_summary(eq: Dictionary) -> void:
	## Totals from what this survivor has on (same maths as a deploy).
	GameState._compute_gear()
	var stats: Dictionary = GameState.gear.get("stats", {})
	var sets: Dictionary = GameState.gear.get("sets", {})
	var leg := GameState.gear_legendary()
	_list.add_child(_note("Tap a slot to equip. Insure one item to keep it through a death."))
	var lines := PackedStringArray()
	for s in stats.keys():
		lines.append_array(GearDefs.stat_lines({"stats": {s: stats[s]}}))
	if lines.size():
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 8)
		fl.add_theme_constant_override("v_separation", 8)
		for ln in lines:
			fl.add_child(UiTheme.chip(ln, UiTheme.TEAL))
		_list.add_child(fl)
	## Sets: one tappable row each (badge, n/total, pips) → set overview.
	for sid in sets.keys():
		_list.add_child(_set_row(str(sid), int(sets[sid])))
	if leg != "":
		var wi: Dictionary = eq.get("weapon", {})
		var p := card(UiTheme.AMBER, Color(0.11, 0.08, 0.055, 0.92))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		p.add_child(h)
		h.add_child(GearUi.tile(wi, 96, {"worn": false, "new": false}))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		v.add_child(UiTheme.head_label(str(GearDefs.LEGENDARIES[leg]["name"]).to_upper(), UiTheme.T_H2, UiTheme.AMBER))
		v.add_child(UiTheme.body_label(str(GearDefs.LEGENDARIES[leg]["desc"]), UiTheme.T_SMALL, UiTheme.TEXT))
		_list.add_child(p)
	var mats := HBoxContainer.new()
	mats.add_theme_constant_override("separation", 16)
	_list.add_child(mats)
	for pair in [["mat_dust_heart", str(GameState.material_count("dust_heart"))], ["mat_salvage_core", str(GameState.material_count("salvage_core"))],
			["camp_stash", "%d/%d" % [GameState.stash.size(), GameState.stash_capacity()]]]:
		var hh := HBoxContainer.new()
		hh.add_theme_constant_override("separation", 8)
		hh.add_child(IconSet.rect(str(pair[0]), 48))
		var l := UiTheme.pixel_label(str(pair[1]), UiTheme.PX_M, UiTheme.TEXT)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hh.add_child(l)
		mats.add_child(hh)


func _set_row(sid: String, n: int) -> Control:
	var total := GearDefs.set_total(sid)
	var p := card(UiTheme.LINE, Color(0.11, 0.08, 0.055, 0.92))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var hit := _hit_button(open_set.bind(sid))
	p.add_child(hit)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(GearUi.set_badge(sid, 64))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var t := UiTheme.head_label("%s  %d/%d" % [GearDefs.set_title(sid), n, total], UiTheme.T_H2, UiTheme.TEXT)
	t.clip_text = true
	v.add_child(t)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th: Array = GearDefs.set_thresholds(sid)
	for i in range(total):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(24, 16)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTheme.TEAL if i < n else Color("1f1a1d")
		sb.border_color = UiTheme.AMBER if (i + 1) in th else UiTheme.INK
		sb.set_border_width_all(2)
		pip.add_theme_stylebox_override("panel", sb)
		pips.add_child(pip)
	v.add_child(pips)
	var nx := GearUi.next_bonus(sid, n)
	if nx != "":
		var nl := UiTheme.body_label(nx, UiTheme.T_SMALL, UiTheme.TEXT_DIM)
		nl.max_lines_visible = 1
		v.add_child(nl)
	var more := UiTheme.head_label("›", UiTheme.T_H1, UiTheme.TEXT_DIM)
	more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(more)
	return p


## Transparent full-card button behind a row's content (content ignores the
## mouse, so taps land here; drags still scroll).
func _hit_button(cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.mouse_force_pass_scroll_events = true
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


func _note(t: String) -> Label:
	return UiTheme.body_label(t, UiTheme.T_SMALL, UiTheme.TEXT_DIM)


## ---------------------------------------------------------------- picker

func _build_picker(eq: Dictionary) -> void:
	var cur: Dictionary = eq.get(_slot, {})
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	_list.add_child(top)
	var hd := UiTheme.head_label(str(GearDefs.SLOT_NAME.get(_slot, _slot)).to_upper(), UiTheme.T_H2, UiTheme.AMBER)
	hd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hd)
	for s in SORTS.keys():
		var sb := UiTheme.big_button(str(SORTS[s]), UiTheme.AMBER if s == _sort else UiTheme.LINE, 64, 16)
		sb.custom_minimum_size.x = 96
		sb.pressed.connect(set_sort.bind(str(s)))
		top.add_child(sb)
	if not cur.is_empty():
		_list.add_child(_item_row(cur, true))
	var any := false
	for it in GameState.stash_view(_sort):
		if not GearDefs.fits(it, _slot, _hero):
			continue
		if int(it.get("uid", -1)) == int(cur.get("uid", -2)):
			continue
		_list.add_child(_item_row(it, false))
		any = true
	if not any:
		_list.add_child(_note("Nothing in the stash fits yet. Extract with gear to fill it."))


func _item_row(it: Dictionary, equipped: bool) -> PanelContainer:
	var col := GearUi.color(it)
	var uid := int(it.get("uid", -1))
	var open := equipped or _preview == uid
	var p := card(col if open else UiTheme.LINE, Color(0.11, 0.08, 0.055, 0.92))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.name = "Row_%d" % uid
	if not equipped:
		p.add_child(_hit_button(preview_item.bind(uid)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	h.add_child(GearUi.tile(it, 112, {"worn": not equipped}))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 4)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(info)
	var nm := UiTheme.head_label(str(it.get("name", "Item")), UiTheme.T_H2, col)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(nm)
	info.add_child(GearUi.rarity_line(it))
	var by := GameState.equipped_by(uid)
	var sub := ""
	if equipped:
		sub = "EQUIPPED"
	elif not by.is_empty():
		sub = "On %s" % GearUi.hero_name(str(by[0]))
	else:
		var sl0 := GearDefs.stat_lines(it)
		sub = str(sl0[0]) if sl0.size() else ""
	if sub != "":
		var sl := UiTheme.body_label(sub, UiTheme.T_SMALL, UiTheme.TEAL if equipped else (UiTheme.RUST if not by.is_empty() else UiTheme.TEXT_DIM), false)
		sl.clip_text = true
		info.add_child(sl)
	var btn: Button
	if equipped:
		btn = UiTheme.big_button("REMOVE", UiTheme.LINE, 64, 20)
		btn.pressed.connect(func() -> void:
			GameState.unequip(_hero, _slot)
			GameState.reset_loadout_to_defaults()
			refresh())
	else:
		btn = UiTheme.big_button("EQUIP", UiTheme.TEAL, 64, 20)
		btn.pressed.connect(equip_item.bind(uid))
	btn.custom_minimum_size.x = 136
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.mouse_force_pass_scroll_events = true
	h.add_child(btn)
	if not open:
		return p
	## Open row: full stats, compare vs equipped, set progress, extras.
	var stats := UiTheme.body_label("\n".join(GearDefs.stat_lines(it)), UiTheme.T_SMALL, UiTheme.TEXT)
	v.add_child(stats)
	if not equipped:
		var cb := GearUi.compare_box(it, _hero)
		cb.modulate.a = 0.0
		cb.create_tween().tween_property(cb, "modulate:a", 1.0, 0.12)
		v.add_child(cb)
	var extra := HBoxContainer.new()
	extra.add_theme_constant_override("separation", 8)
	v.add_child(extra)
	var sid := str(it.get("set", ""))
	if sid != "":
		var sb := UiTheme.big_button("SET", UiTheme.LINE, 64, 20)
		sb.icon = IconSet.tex(IconSet.emblem(sid), false)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.custom_minimum_size.x = 0
		sb.pressed.connect(open_set.bind(sid))
		extra.add_child(sb)
	if equipped:
		var insured := int(GameState.insured.get(_hero, -1)) == uid
		var ins := UiTheme.big_button("INSURED" if insured else "INSURE", UiTheme.TEAL, 64, 20)
		ins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ins.custom_minimum_size.x = 0
		ins.pressed.connect(func() -> void:
			GameState.set_insured(_hero, -1 if insured else uid)
			refresh())
		extra.add_child(ins)
	if bool(it.get("needs_heart", false)) and not bool(it.get("charged", false)):
		var ch := UiTheme.big_button("AWAKEN", UiTheme.RUST, 64, 20)
		ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch.custom_minimum_size.x = 0
		ch.disabled = GameState.material_count("dust_heart") <= 0
		ch.pressed.connect(func() -> void:
			GameState.charge_vial(uid)
			GameState.reset_loadout_to_defaults()
			refresh())
		extra.add_child(ch)
	var locked := bool(it.get("locked", false))
	var lk := UiTheme.big_button("LOCKED" if locked else "LOCK", UiTheme.AMBER if locked else UiTheme.LINE, 64, 20)
	lk.icon = IconSet.tex("ui_lock", false)
	lk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lk.custom_minimum_size.x = 0
	lk.pressed.connect(func() -> void:
		GameState.toggle_lock(uid)
		_rebuild_list(true))
	extra.add_child(lk)
	return p


func equip_item(uid: int) -> bool:
	var ok := GameState.equip(_hero, _slot, uid)
	if ok:
		Juice.sfx("ui_equip")
		GameState.reset_loadout_to_defaults()
	_preview = -1
	refresh()
	return ok


## ---------------------------------------------------------------- popups

func open_set(sid: String) -> void:
	close_popup()
	var v := GearUi.overlay(self)
	_popup = v.get_meta("root")
	v.add_child(GearUi.set_overview(sid, _hero))
	var close := UiTheme.big_button("CLOSE", UiTheme.LINE, 64, 20)
	close.pressed.connect(close_popup)
	v.add_child(close)


func close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


## Item icon inside its rarity frame (results, older callers).
static func item_icon(it: Dictionary, size: float) -> Control:
	return GearUi.tile(it, int(size), {"worn": false})
