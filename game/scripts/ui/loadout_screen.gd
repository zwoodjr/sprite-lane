class_name LoadoutScreen
extends "res://scripts/ui/menu_base.gd"

## Gear screen: equip a survivor from the shared stash (brief Part 7).
## Top: survivor switcher. Grid: weapon + 2 mods, 6 armor, 3 accessories.
## Below: tap a slot to pick from fitting stash items (equip / unequip /
## insure / awaken a Vial); with no slot picked it shows stats + set bonuses.

const FRAME := "res://assets/sprites/icons/frames/frame_%s.png"

var _hero: String = ""
var _slot: String = ""
var _hero_label: Label
var _grid: GridContainer
var _left: VBoxContainer
var _right: VBoxContainer
var _doll_hero: StripAnim
const LEFT_SLOTS := ["head", "shoulders", "chest", "legs"]
const RIGHT_SLOTS := ["hands", "boots", "charm", "vial"]
const BOTTOM_SLOTS := ["weapon", "mod1", "mod2", "patch"]
const SLOT_PX := 112.0
var _scroll: ScrollContainer
var _list: VBoxContainer


func build(c: VBoxContainer) -> void:
	c.add_theme_constant_override("separation", 16)
	_hero = GameState.selected_character_id
	c.add_child(header("GEAR", _back))

	## Paper doll: armour on the left, accessories on the right, weapon + mods
	## under the hero, who stands in the middle at an integer scale.
	var doll := HBoxContainer.new()
	doll.add_theme_constant_override("separation", 16)
	c.add_child(doll)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 8)
	doll.add_child(_left)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	doll.add_child(mid)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	mid.add_child(hr)
	var prev := UiTheme.big_button("<", UiTheme.LINE, 64, 24)
	prev.custom_minimum_size.x = 64
	prev.pressed.connect(cycle_hero.bind(-1))
	hr.add_child(prev)
	_hero_label = UiTheme.head_label("", UiTheme.T_H2, UiTheme.AMBER)
	_hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hero_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_label.clip_text = true
	hr.add_child(_hero_label)
	var nxt := UiTheme.big_button(">", UiTheme.LINE, 64, 24)
	nxt.custom_minimum_size.x = 64
	nxt.pressed.connect(cycle_hero.bind(1))
	hr.add_child(nxt)
	_doll_hero = StripAnim.make("", 256, 8.0)
	_doll_hero.custom_minimum_size = Vector2(256, 256)
	_doll_hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_doll_hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(_doll_hero)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 8)
	doll.add_child(_right)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 8)
	c.add_child(_grid)

	_scroll = ScrollContainer.new()
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
		GameState.selected_character_id = _hero
		GameState.save_profile()
		if GameState.loadout_from == "prep":
			GameState.go_prep()
		elif from_select:
			GameState.go_character_select()
		else:
			GameState.go_mode_select())
	c.add_child(deploy)
	refresh()


func _back() -> void:
	if GameState.loadout_from == "prep":
		GameState.go_prep()
	elif GameState.loadout_from == "character_select":
		GameState.go_character_select()
	else:
		GameState.go_hangar()


func cycle_hero(step: int) -> void:
	var ids: Array = CharacterDefs.PLAYABLE_IDS
	var i := ids.find(_hero)
	_hero = str(ids[(i + step + ids.size()) % ids.size()])
	_slot = ""
	refresh()


func set_hero(h: String) -> void:
	if CharacterDefs.is_playable(h):
		_hero = h
		_slot = ""
		refresh()


func select_slot(sl: String) -> void:
	_slot = "" if _slot == sl else sl
	refresh()


func refresh() -> void:
	_hero_label.text = str(CharacterDefs.get_character(_hero).get("display_name", _hero)).to_upper()
	_doll_hero.set_strip("res://assets/sprites/characters/%s/%s_idle.png" % [_hero, _hero])
	var eq := GameState.equipped_items(_hero)
	for pair in [[_left, LEFT_SLOTS], [_right, RIGHT_SLOTS], [_grid, BOTTOM_SLOTS]]:
		var box: Container = pair[0]
		for ch in box.get_children():
			box.remove_child(ch)
			ch.queue_free()
		for sl in pair[1]:
			box.add_child(_slot_tile(str(sl), eq.get(sl, {})))
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	if _slot == "":
		_build_summary(eq)
	else:
		_build_picker(eq)
	_scroll.scroll_vertical = 0


## Icon slot: rarity-framed well, the item's icon (or the slot's, dimmed).
func _slot_tile(sl: String, item: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.tooltip_text = GearDefs.SLOT_NAME.get(sl, sl)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(select_slot.bind(sl))
	var rar := str(item.get("rarity", "common")) if not item.is_empty() else "common"
	var icon := IconSet.item(item) if not item.is_empty() else _empty_icon(sl)
	var well := UiTheme.icon_well(icon, rar, int(SLOT_PX))
	well.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if item.is_empty():
		(well.get_child(0).get_child(0) as Control).modulate = Color(1, 1, 1, 0.3)
	b.add_child(well)
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
		var ins := IconSet.rect("up_iron_tonic", 48)
		ins.position = Vector2(SLOT_PX - 52, 4)
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
	var keep_hero := GameState.selected_character_id
	GameState.selected_character_id = _hero
	GameState._compute_gear()
	var stats: Dictionary = GameState.gear.get("stats", {})
	var sets: Dictionary = GameState.gear.get("sets", {})
	var leg := GameState.gear_legendary()
	GameState.selected_character_id = keep_hero
	GameState._compute_gear()
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
	var set_text := PackedStringArray()
	for sid in sets.keys():
		var n := int(sets[sid])
		if GearDefs.GENERAL_SETS.has(sid):
			var g: Dictionary = GearDefs.GENERAL_SETS[sid]
			set_text.append("%s %d/6" % [g["name"], n])
			for i in range(GearDefs.GENERAL_THRESHOLDS.size()):
				var th := int(GearDefs.GENERAL_THRESHOLDS[i])
				set_text.append("   %s (%d) %s" % ["[x]" if n >= th else "[ ]", th, (g["bonus"] as Array)[i]])
		elif GearDefs.SURVIVOR_SETS.has(sid):
			var sv: Dictionary = GearDefs.SURVIVOR_SETS[sid]
			set_text.append("%s %d/3" % [sv["name"], n])
			for i in range(2):
				set_text.append("   %s (%d) %s" % ["[x]" if n >= i + 2 else "[ ]", i + 2, (sv["bonus"] as Array)[i]])
	if set_text.size():
		_list.add_child(_section("SETS", "\n".join(set_text)))
	if leg != "":
		_list.add_child(_section("LEGENDARY", "%s — %s" % [GearDefs.LEGENDARIES[leg]["name"], GearDefs.LEGENDARIES[leg]["desc"]]))
	var mats := HBoxContainer.new()
	mats.add_theme_constant_override("separation", 16)
	_list.add_child(mats)
	for pair in [["mat_dust_heart", str(GameState.material_count("dust_heart"))], ["mat_salvage_core", str(GameState.material_count("salvage_core"))],
			["camp_stash", "%d/%d" % [GameState.stash.size(), GameState.stash_capacity()]]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(IconSet.rect(str(pair[0]), 48))
		var l := UiTheme.pixel_label(str(pair[1]), UiTheme.PX_M, UiTheme.TEXT)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		mats.add_child(h)


func _note(t: String) -> Label:
	return UiTheme.body_label(t, UiTheme.T_SMALL, UiTheme.TEXT_DIM)


func _section(title: String, body: String) -> PanelContainer:
	var p := card(UiTheme.LINE, Color(0.11, 0.08, 0.055, 0.92))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(UiTheme.head_label(title, UiTheme.T_H3, UiTheme.AMBER))
	v.add_child(UiTheme.body_label(body, UiTheme.T_SMALL, UiTheme.TEXT))
	return p


## ---------------------------------------------------------------- picker

func _build_picker(eq: Dictionary) -> void:
	var cur: Dictionary = eq.get(_slot, {})
	_list.add_child(UiTheme.head_label(str(GearDefs.SLOT_NAME.get(_slot, _slot)).to_upper(), UiTheme.T_H2, UiTheme.AMBER))
	if not cur.is_empty():
		_list.add_child(_item_row(cur, true))
	var any := false
	for it in GameState.stash:
		if not GearDefs.fits(it, _slot, _hero):
			continue
		if int(it.get("uid", -1)) == int(cur.get("uid", -2)):
			continue
		_list.add_child(_item_row(it, false))
		any = true
	if not any:
		_list.add_child(_note("Nothing in the stash fits yet. Extract with gear to fill it."))


func _item_row(it: Dictionary, equipped: bool) -> PanelContainer:
	var rar := str(it.get("rarity", "common"))
	var col: Color = IconSet.rarity_color(rar)
	var p := card(col if equipped else UiTheme.LINE, Color(0.11, 0.08, 0.055, 0.92))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(h)
	h.add_child(item_icon(it, 112))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_theme_constant_override("separation", 1)
	h.add_child(info)
	info.add_child(UiTheme.head_label(str(it.get("name", "Item")), UiTheme.T_H3, col))
	info.add_child(UiTheme.body_label("\n".join(GearDefs.stat_lines(it)), UiTheme.T_SMALL, UiTheme.TEXT))
	var by := GameState.equipped_by(int(it.get("uid", -1)))
	if not equipped and not by.is_empty():
		info.add_child(UiTheme.body_label("On %s" % str(CharacterDefs.get_character(str(by[0])).get("display_name", by[0])), UiTheme.T_SMALL, UiTheme.RUST, false))
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(btns)
	var uid := int(it.get("uid", -1))
	if equipped:
		var un := UiTheme.big_button("REMOVE", UiTheme.LINE, 64, 20)
		un.custom_minimum_size.x = 136
		un.pressed.connect(func() -> void:
			GameState.unequip(_hero, _slot)
			refresh())
		btns.add_child(un)
		var insured := int(GameState.insured.get(_hero, -1)) == uid
		var ins := UiTheme.big_button("INSURED" if insured else "INSURE", UiTheme.TEAL, 64, 20)
		ins.custom_minimum_size.x = 136
		ins.pressed.connect(func() -> void:
			GameState.set_insured(_hero, -1 if insured else uid)
			refresh())
		btns.add_child(ins)
	else:
		var eqb := UiTheme.big_button("EQUIP", UiTheme.TEAL, 64, 20)
		eqb.custom_minimum_size.x = 136
		eqb.pressed.connect(func() -> void:
			if GameState.equip(_hero, _slot, uid):
				Juice.sfx("ui_equip")
			refresh())
		btns.add_child(eqb)
	if bool(it.get("needs_heart", false)) and not bool(it.get("charged", false)):
		var ch := UiTheme.big_button("AWAKEN", UiTheme.RUST, 64, 20)
		ch.custom_minimum_size.x = 136
		ch.disabled = GameState.material_count("dust_heart") <= 0
		ch.pressed.connect(func() -> void:
			GameState.charge_vial(uid)
			refresh())
		btns.add_child(ch)
	return p


## Item icon inside its rarity frame (shared with the Hangar stash grid).
static func item_icon(it: Dictionary, size: float) -> Control:
	var w := UiTheme.icon_well(IconSet.item(it), str(it.get("rarity", "common")), int(size))
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return w
