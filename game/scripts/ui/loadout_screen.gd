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
var _scroll: ScrollContainer
var _list: VBoxContainer


func build(c: VBoxContainer) -> void:
	c.add_theme_constant_override("separation", 10)
	_hero = GameState.selected_character_id
	c.add_child(header("GEAR", _back))

	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 10)
	c.add_child(hr)
	var prev := UiTheme.big_button("‹", UiTheme.LINE, 56, 28)
	prev.custom_minimum_size.x = 70
	prev.pressed.connect(cycle_hero.bind(-1))
	hr.add_child(prev)
	_hero_label = UiTheme.title_label("", 28, UiTheme.AMBER)
	_hero_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(_hero_label)
	var nxt := UiTheme.big_button("›", UiTheme.LINE, 56, 28)
	nxt.custom_minimum_size.x = 70
	nxt.pressed.connect(cycle_hero.bind(1))
	hr.add_child(nxt)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
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
	var deploy := UiTheme.big_button("DONE" if from_select else "DEPLOY", UiTheme.AMBER, 64, 22)
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
	_hero_label.text = str(CharacterDefs.get_character(_hero).get("display_name", _hero))
	for ch in _grid.get_children():
		_grid.remove_child(ch)
		ch.free()
	var eq := GameState.equipped_items(_hero)
	for sl in GearDefs.LOADOUT_SLOTS:
		_grid.add_child(_slot_tile(str(sl), eq.get(sl, {})))
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.free()
	if _slot == "":
		_build_summary(eq)
	else:
		_build_picker(eq)
	_scroll.scroll_vertical = 0


func _slot_tile(sl: String, item: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 112)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var rar := str(item.get("rarity", "common"))
	var sel := sl == _slot
	var border: Color = GearDefs.RARITY_COLOR.get(rar, UiTheme.LINE) if not item.is_empty() else UiTheme.LINE
	## Painted tile, tinted by rarity; selected slot glows brass.
	var sb := UiTheme.plate("tile_on", 6.0) if sel else UiTheme.plate("tile", 6.0, Color.WHITE.lerp(border, 0.55) if not item.is_empty() else Color(0.85, 0.85, 0.85))
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", UiTheme.plate("tile_on", 6.0))
	b.add_theme_stylebox_override("hover_pressed", UiTheme.plate("tile_on", 6.0))
	b.pressed.connect(select_slot.bind(sl))
	var ic := TextureRect.new()
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 18
	ic.offset_right = -18
	ic.offset_top = 8
	ic.offset_bottom = -30
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := str(item.get("icon", "")) if not item.is_empty() else _empty_icon(sl)
	if path != "" and ResourceLoader.exists(path):
		ic.texture = load(path)
	ic.modulate = Color(1, 1, 1, 1.0 if not item.is_empty() else 0.28)
	b.add_child(ic)
	var lab := Label.new()
	lab.text = GearDefs.SLOT_NAME.get(sl, sl).to_upper()
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", UiTheme.TEXT_DIM if item.is_empty() else (GearDefs.RARITY_COLOR.get(rar, UiTheme.TEXT) as Color))
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lab.offset_top = -26
	lab.offset_bottom = -4
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	if not item.is_empty() and int(GameState.insured.get(_hero, -1)) == int(item.get("uid", -2)):
		var ins := Label.new()
		ins.text = "INSURED"
		ins.add_theme_font_size_override("font_size", 11)
		ins.add_theme_color_override("font_color", UiTheme.TEAL)
		ins.position = Vector2(6, 2)
		ins.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ins)
	return b


func _empty_icon(sl: String) -> String:
	if sl == "weapon":
		return GearDefs.weapon_icon(_hero, "")
	if sl in ["mod1", "mod2"]:
		return "res://assets/sprites/icons/mods/icon_mod_grip.png" if GearDefs.is_melee_hero(_hero) else "res://assets/sprites/icons/mods/icon_mod_scope.png"
	return str(GearDefs.SLOT_ICON.get(sl, ""))


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
	_list.add_child(_note("Tap a slot to equip from the stash. Insure one item: it survives a death. Everything else you carried in is lost if you go down."))
	var lines := PackedStringArray()
	for s in stats.keys():
		lines.append_array(GearDefs.stat_lines({"stats": {s: stats[s]}}))
	_list.add_child(_section("STATS", ", ".join(lines) if lines.size() else "No gear bonuses yet."))
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
	_list.add_child(_section("SETS", "\n".join(set_text) if set_text.size() else "Wear 2+ pieces of a set for its bonus."))
	if leg != "":
		_list.add_child(_section("LEGENDARY", "%s — %s" % [GearDefs.LEGENDARIES[leg]["name"], GearDefs.LEGENDARIES[leg]["desc"]]))
	_list.add_child(_section("MATERIALS", "Dust Hearts %d · Salvage Cores %d · Stash %d/%d" % [
		GameState.material_count("dust_heart"), GameState.material_count("salvage_core"),
		GameState.stash.size(), GameState.stash_capacity()]))


func _note(t: String) -> Label:
	return UiTheme.body_label(t, 14, UiTheme.TEXT_DIM)


func _section(title: String, body: String) -> PanelContainer:
	var p := card(UiTheme.LINE, Color(0.11, 0.08, 0.055, 0.92))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(UiTheme.body_label(title, 16, UiTheme.AMBER, false))
	v.add_child(UiTheme.body_label(body, 15, UiTheme.TEXT))
	return p


## ---------------------------------------------------------------- picker

func _build_picker(eq: Dictionary) -> void:
	var cur: Dictionary = eq.get(_slot, {})
	_list.add_child(_note("%s — tap EQUIP on a stash item." % GearDefs.SLOT_NAME.get(_slot, _slot)))
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
		_list.add_child(_note("Nothing in the stash fits this slot yet. Gear drops in runs and reaches the stash when you extract."))


func _item_row(it: Dictionary, equipped: bool) -> PanelContainer:
	var rar := str(it.get("rarity", "common"))
	var col: Color = GearDefs.RARITY_COLOR.get(rar, UiTheme.TEXT)
	var p := card(col if equipped else UiTheme.LINE, Color(0.11, 0.08, 0.055, 0.92))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(h)
	h.add_child(item_icon(it, 64))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_theme_constant_override("separation", 1)
	h.add_child(info)
	info.add_child(UiTheme.body_label(str(it.get("name", "Item")), 17, col, false))
	info.add_child(UiTheme.body_label("%s%s" % [GearDefs.RARITY_NAME.get(rar, rar), "  ·  equipped" if equipped else ""], 12, UiTheme.TEXT_DIM, false))
	info.add_child(UiTheme.body_label("\n".join(GearDefs.stat_lines(it)), 13, UiTheme.TEXT))
	var by := GameState.equipped_by(int(it.get("uid", -1)))
	if not equipped and not by.is_empty():
		info.add_child(UiTheme.body_label("On %s" % str(CharacterDefs.get_character(str(by[0])).get("display_name", by[0])), 12, UiTheme.RUST, false))
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(btns)
	var uid := int(it.get("uid", -1))
	if equipped:
		var un := UiTheme.big_button("REMOVE", UiTheme.LINE, 48, 15)
		un.custom_minimum_size.x = 118
		un.pressed.connect(func() -> void:
			GameState.unequip(_hero, _slot)
			refresh())
		btns.add_child(un)
		var insured := int(GameState.insured.get(_hero, -1)) == uid
		var ins := UiTheme.big_button("INSURED" if insured else "INSURE", UiTheme.TEAL, 48, 15)
		ins.custom_minimum_size.x = 118
		ins.pressed.connect(func() -> void:
			GameState.set_insured(_hero, -1 if insured else uid)
			refresh())
		btns.add_child(ins)
	else:
		var eqb := UiTheme.big_button("EQUIP", UiTheme.TEAL, 52, 17)
		eqb.custom_minimum_size.x = 118
		eqb.pressed.connect(func() -> void:
			if GameState.equip(_hero, _slot, uid):
				Juice.sfx("pickup")
			refresh())
		btns.add_child(eqb)
	if bool(it.get("needs_heart", false)) and not bool(it.get("charged", false)):
		var ch := UiTheme.big_button("AWAKEN", UiTheme.RUST, 48, 15)
		ch.custom_minimum_size.x = 118
		ch.disabled = GameState.material_count("dust_heart") <= 0
		ch.pressed.connect(func() -> void:
			GameState.charge_vial(uid)
			refresh())
		btns.add_child(ch)
	return p


## Item icon inside its rarity frame (shared with the Hangar stash grid).
static func item_icon(it: Dictionary, size: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fr := TextureRect.new()
	var fp := FRAME % str(it.get("rarity", "common"))
	if ResourceLoader.exists(fp):
		fr.texture = load(fp)
	fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(fr)
	var ic := TextureRect.new()
	var ip := str(it.get("icon", ""))
	if ip != "" and ResourceLoader.exists(ip):
		ic.texture = load(ip)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := size * 0.16
	ic.offset_left = pad
	ic.offset_top = pad
	ic.offset_right = -pad
	ic.offset_bottom = -pad
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(ic)
	return c
