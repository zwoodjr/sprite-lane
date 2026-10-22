extends "res://scripts/ui/menu_base.gd"

## Pre-run LOADOUT (Depth E5): pick the weapon style, ability version and
## quirk for this survivor, slot tonics, check gear — then deploy.

const PORTRAIT := "res://assets/sprites/portraits/%s.png"

var _scroll: ScrollContainer
var _list: VBoxContainer
var _hero: String = ""


func build(c: VBoxContainer) -> void:
	c.add_theme_constant_override("separation", 16)
	_hero = GameState.selected_character_id
	## Recompute the deploy kit so what this screen shows is what the match applies.
	GameState.reset_loadout_to_defaults()
	c.add_child(header("LOADOUT", GameState.go_character_select))
	_scroll = ScrollContainer.new()
	_scroll.name = "PrepScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 18
	c.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	c.add_child(bottom)
	var gear := UiTheme.big_button("GEAR", UiTheme.TEAL, 80, 24)
	gear.icon = IconSet.tex("slot_chest", false)
	gear.custom_minimum_size.x = 0
	gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear.size_flags_stretch_ratio = 0.6
	gear.pressed.connect(func() -> void: GameState.go_loadout("prep"))
	bottom.add_child(gear)
	var deploy := UiTheme.big_button("DEPLOY", UiTheme.AMBER, 80, 32)
	deploy.custom_minimum_size.x = 0
	deploy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deploy.pressed.connect(GameState.go_match)
	bottom.add_child(deploy)
	_rebuild()


func _rebuild() -> void:
	var keep := _scroll.scroll_vertical
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	var c := CharacterDefs.get_character(_hero)
	var rank := GameState.station_rank(_hero)
	## Who + where.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_list.add_child(top)
	var pr := TextureRect.new()
	pr.custom_minimum_size = Vector2(80, 80)
	pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(PORTRAIT % _hero):
		pr.texture = load(PORTRAIT % _hero)
	top.add_child(pr)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	top.add_child(tv)
	var nm := UiTheme.title_label(str(c.get("display_name", _hero)), UiTheme.T_TITLE, c.get("accent", UiTheme.AMBER))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(nm)
	tv.add_child(UiTheme.head_label(str(GameState.get_mode().get("display_name", "")).to_upper(), UiTheme.T_H3, UiTheme.TEXT_DIM))

	## Gear: exactly what this survivor deploys with (tap = Gear screen).
	_build_gear_row()

	## Weapon style.
	var cur_style := GameState.kit_style(_hero)
	var styles := KitDefs.styles(_hero)
	var row := _section("WEAPON STYLE")
	var sel: Dictionary = {}
	for i in range(styles.size()):
		var st: Dictionary = styles[i]
		var sid := str(st["id"])
		var unlocked := KitDefs.style_unlocked(_hero, sid, rank)
		var lock := "" if unlocked else "RANK %d" % int(KitDefs.STYLE_UNLOCK[i])
		row.add_child(_tile(IconSet.style(_hero, sid), sid == cur_style, lock, pick_style.bind(sid)))
		if sid == cur_style:
			sel = st
	_detail(str(sel.get("name", "")), str(sel.get("desc", "")))

	## Ability version.
	var base: Dictionary = c.get("ability", {})
	var cur_ab := GameState.kit_ability(_hero)
	row = _section("ABILITY")
	row.add_child(_tile(IconSet.ability(_hero, "a"), cur_ab == "a", "", pick_ability.bind("a")))
	var b: Dictionary = KitDefs.ABILITIES.get(_hero, {})
	if not b.is_empty():
		var lk := "" if rank >= KitDefs.ABILITY_B_RANK else "RANK %d" % KitDefs.ABILITY_B_RANK
		row.add_child(_tile(IconSet.ability(_hero, "b"), cur_ab == "b", lk, pick_ability.bind("b")))
	var ad: Dictionary = b if cur_ab == "b" and not b.is_empty() else base
	_detail(str(ad.get("name", "")), str(ad.get("desc", "")))

	## Quirk.
	var cur_q := GameState.kit_quirk(_hero)
	row = _section("QUIRK")
	row.add_child(_tile("", cur_q == "", "", pick_quirk.bind("")))
	for qid in KitDefs.quirks(_hero):
		row.add_child(_tile("quirk_" + str(qid), cur_q == str(qid), "", pick_quirk.bind(str(qid))))
	if cur_q == "":
		_detail("No quirk", "Play it straight.")
	else:
		var q := KitDefs.quirk(cur_q)
		_detail(str(q["name"]), str(q["desc"]))

	## Tonics.
	row = _section("TONICS  %d/%d" % [GameState.tonic_loadout.size(), GameState.tonic_slot_count()])
	var any := false
	var names: PackedStringArray = []
	for tid in MedicineDefs.TONIC_IDS:
		if GameState.tonic_count(str(tid)) <= 0:
			continue
		any = true
		var td: Dictionary = MedicineDefs.TONICS[str(tid)]
		var on := str(tid) in GameState.tonic_loadout
		var t := _tile("tonic_" + str(tid), on, "", pick_tonic.bind(str(tid)))
		var cnt := UiTheme.pixel_label("x%d" % GameState.tonic_count(str(tid)), UiTheme.PX_M, UiTheme.TEXT)
		cnt.position = Vector2(8, 104)
		t.add_child(cnt)
		row.add_child(t)
		if on:
			names.append(str(td["name"]))
	if not any:
		_detail("None brewed", "Cinder brews tonics in the Hangar.")
	else:
		_detail(", ".join(names) if not names.is_empty() else "Tap to slot", "")
	## Dust Pacts (Depth E7): stack rules against yourself for a bigger payout.
	if GameState.pacts_unlocked():
		_section("DUST PACTS  +%d%%" % int(round(GameState.pact_loot_bonus() * 100.0)))
		for pid in ZoneDefs.PACTS.keys():
			var pd: Dictionary = ZoneDefs.PACTS[pid]
			_list.add_child(_option(null, "%s  +%d%%" % [str(pd["name"]), int(round(float(pd["loot"]) * 100.0))], str(pd["desc"]), "",
				str(pid) in GameState.pacts, pick_pact.bind(str(pid)), false, "SWORN"))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 24)
	_list.add_child(pad)
	_scroll.set_deferred("scroll_vertical", keep)


## The 12 loadout slots as rarity wells (empty slots dimmed) + set chips.
func _build_gear_row() -> void:
	var eq := GameState.equipped_items(_hero)
	var l := UiTheme.head_label("GEAR  %d/%d" % [eq.size(), GearDefs.LOADOUT_SLOTS.size()], UiTheme.T_H3, UiTheme.AMBER)
	_list.add_child(l)
	var grid := GridContainer.new()
	grid.name = "PrepGear"
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	_list.add_child(grid)
	for sl in GearDefs.LOADOUT_SLOTS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.mouse_force_pass_scroll_events = true
		b.custom_minimum_size = Vector2(96, 96)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.pressed.connect(func() -> void: GameState.go_loadout("prep"))
		var t := GearUi.tile(eq.get(sl, {}), 96, {"worn": false, "new": false, "icon": IconSet.slot(str(sl)), "empty_alpha": 0.3})
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(t)
		grid.add_child(b)
	var sets := GameState.worn_set_counts(_hero)
	if not sets.is_empty():
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 8)
		fl.add_theme_constant_override("v_separation", 8)
		_list.add_child(fl)
		for sid in sets.keys():
			fl.add_child(UiTheme.chip("%s %d/%d" % [GearDefs.set_title(str(sid)), int(sets[sid]), GearDefs.set_total(str(sid))], UiTheme.TEXT, GearDefs.set_color(str(sid))))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	_list.add_child(gap)


## uids shown in the gear row, per slot (tests).
func gear_uids() -> Dictionary:
	var out := {}
	var eq := GameState.equipped_items(_hero)
	for sl in eq.keys():
		out[str(sl)] = int((eq[sl] as Dictionary).get("uid", -1))
	return out


## Section header + the tile row it returns.
func _section(t: String) -> HFlowContainer:
	var l := UiTheme.head_label(t, UiTheme.T_H3, UiTheme.AMBER)
	_list.add_child(l)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 16)
	row.add_theme_constant_override("v_separation", 16)
	_list.add_child(row)
	return row


## The chosen option's name + one line under its row.
func _detail(title: String, desc: String) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_list.add_child(v)
	if title != "":
		v.add_child(UiTheme.head_label(title, UiTheme.T_H2, UiTheme.TEXT))
	if desc != "":
		## Sits on the sunset backdrop: BONE with an INK edge (dim grey read as mud).
		var d := UiTheme.body_label(desc, UiTheme.T_SMALL, UiTheme.TEXT)
		d.add_theme_color_override("font_outline_color", UiTheme.INK)
		d.add_theme_constant_override("outline_size", 4)
		d.max_lines_visible = 2
		v.add_child(d)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	_list.add_child(gap)


## Square icon tile (136 px, 48-px icon at x2). Locked tiles show the
## Hangar rank that opens them.
func _tile(icon_id: String, on: bool, lock: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_force_pass_scroll_events = true
	b.custom_minimum_size = Vector2(136, 136)
	UiTheme.skin_tile(b, on, 4.0)
	b.disabled = lock != ""
	b.pressed.connect(cb)
	if icon_id != "":
		var ic := IconSet.rect(icon_id, 96)
		ic.position = Vector2(20, 20)
		ic.size = Vector2(96, 96)
		b.add_child(ic)
		if lock != "":
			ic.modulate = Color(0.4, 0.4, 0.4)
	else:
		var dash := UiTheme.title_label("-", UiTheme.T_TITLE, UiTheme.TEXT_DIM)
		dash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dash)
	if lock != "":
		var lk := IconSet.rect("camp_stash", 48)
		lk.position = Vector2(80, 80)
		b.add_child(lk)
		var lt := UiTheme.pixel_label(lock, UiTheme.PX_M, UiTheme.AMBER)
		lt.position = Vector2(12, 12)
		b.add_child(lt)
	if on:
		var tick := IconSet.rect("tab_daily", 48)
		tick.position = Vector2(84, 4)
		b.add_child(tick)
	return b


## One selectable text row (Dust Pacts): name / desc. Tap to pick.
func _option(icon: Texture2D, title: String, desc: String, lock: String, on: bool, cb: Callable, mirror: bool = false, on_text: String = "EQUIPPED") -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_force_pass_scroll_events = true
	b.custom_minimum_size = Vector2(0, 80)
	var kind := "panel_hi" if on else "panel"
	b.add_theme_stylebox_override("normal", UiTheme.plate(kind, 10.0, Color(1, 1, 1, 0.95) if lock == "" else Color(0.7, 0.7, 0.7, 0.8)))
	b.add_theme_stylebox_override("hover", UiTheme.plate(kind, 10.0))
	b.add_theme_stylebox_override("pressed", UiTheme.plate("panel_hi", 10.0))
	b.add_theme_stylebox_override("disabled", UiTheme.plate("panel", 10.0, Color(0.6, 0.6, 0.6, 0.7)))
	b.disabled = lock != ""
	b.pressed.connect(cb)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 16 if s in ["left", "right"] else 8)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(UiTheme.head_label(title, UiTheme.T_H3, UiTheme.AMBER if on else UiTheme.TEXT))
	var d := UiTheme.body_label(desc, UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	if on:
		h.add_child(UiTheme.head_label(on_text, UiTheme.T_SMALL, UiTheme.TEAL))
	return b


func pick_style(sid: String) -> bool:
	var ok := GameState.set_style(_hero, sid)
	Juice.sfx("ui_tap")
	_rebuild()
	return ok


func pick_ability(v: String) -> bool:
	var ok := GameState.set_ability_version(_hero, v)
	Juice.sfx("ui_tap")
	_rebuild()
	return ok


func pick_quirk(q: String) -> bool:
	var ok := GameState.set_quirk(_hero, q)
	Juice.sfx("ui_tap")
	_rebuild()
	return ok


func pick_tonic(tid: String) -> bool:
	var ok := GameState.toggle_tonic(tid)
	Juice.sfx("ui_tap")
	_rebuild()
	return ok


func pick_pact(pid: String) -> bool:
	var ok := GameState.toggle_pact(pid)
	Juice.sfx("ui_tap")
	_rebuild()
	return ok
