extends "res://scripts/ui/menu_base.gd"

## Pre-run LOADOUT (Depth E5): pick the weapon style, ability version and
## quirk for this survivor, slot tonics, check gear — then deploy.

const PORTRAIT := "res://assets/sprites/portraits/%s.png"

var _scroll: ScrollContainer
var _list: VBoxContainer
var _hero: String = ""


func build(c: VBoxContainer) -> void:
	c.add_theme_constant_override("separation", 10)
	_hero = GameState.selected_character_id
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
	var gear := UiTheme.big_button("GEAR", UiTheme.TEAL, 72, 22)
	gear.custom_minimum_size.x = 0
	gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear.size_flags_stretch_ratio = 0.6
	gear.pressed.connect(func() -> void: GameState.go_loadout("prep"))
	bottom.add_child(gear)
	var deploy := UiTheme.big_button("DEPLOY ›", UiTheme.AMBER, 72, 30)
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
	## Who + station rank.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_list.add_child(top)
	var pr := TextureRect.new()
	pr.custom_minimum_size = Vector2(72, 72)
	pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(PORTRAIT % _hero):
		pr.texture = load(PORTRAIT % _hero)
	top.add_child(pr)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(tv)
	var nm := UiTheme.title_label(str(c.get("display_name", _hero)), 30, c.get("accent", UiTheme.AMBER))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(nm)
	tv.add_child(UiTheme.body_label("%s · station rank %d/5 · %s" % [str(HangarDefs.display_name(HangarDefs.station_id(_hero))), rank,
		str(GameState.get_mode().get("display_name", ""))], 14, UiTheme.TEXT_DIM))
	## Weapon style.
	_list.add_child(_section("WEAPON STYLE"))
	var cur_style := GameState.kit_style(_hero)
	var styles := KitDefs.styles(_hero)
	for i in range(styles.size()):
		var st: Dictionary = styles[i]
		var sid := str(st["id"])
		var unlocked := KitDefs.style_unlocked(_hero, sid, rank)
		var lock := "" if unlocked else "Unlocks at station rank %d" % int(KitDefs.STYLE_UNLOCK[i])
		_list.add_child(_option(load(KitDefs.icon_path(_hero, sid)) if ResourceLoader.exists(KitDefs.icon_path(_hero, sid)) else null,
			str(st["name"]), str(st["desc"]), lock, sid == cur_style, pick_style.bind(sid)))
	## Ability version.
	_list.add_child(_section("ABILITY"))
	var base: Dictionary = c.get("ability", {})
	var cur_ab := GameState.kit_ability(_hero)
	var aicon: Texture2D = load(CharacterDefs.ability_icon_path(_hero)) if ResourceLoader.exists(CharacterDefs.ability_icon_path(_hero)) else null
	_list.add_child(_option(aicon, str(base.get("name", "")), str(base.get("desc", "")), "", cur_ab == "a", pick_ability.bind("a")))
	var b: Dictionary = KitDefs.ABILITIES.get(_hero, {})
	if not b.is_empty():
		var lk := "" if rank >= KitDefs.ABILITY_B_RANK else "Unlocks at station rank %d" % KitDefs.ABILITY_B_RANK
		_list.add_child(_option(aicon, str(b["name"]), str(b["desc"]), lk, cur_ab == "b", pick_ability.bind("b"), true))
	## Quirk.
	_list.add_child(_section("QUIRK  ·  pick one rule to bend"))
	var cur_q := GameState.kit_quirk(_hero)
	_list.add_child(_option(null, "No quirk", "Play it straight.", "", cur_q == "", pick_quirk.bind("")))
	for qid in KitDefs.quirks(_hero):
		var q := KitDefs.quirk(str(qid))
		_list.add_child(_option(null, str(q["name"]), str(q["desc"]), "", cur_q == str(qid), pick_quirk.bind(str(qid))))
	## Tonics.
	_list.add_child(_section("TONICS  ·  %d/%d slots" % [GameState.tonic_loadout.size(), GameState.tonic_slot_count()]))
	var any := false
	for tid in MedicineDefs.TONIC_IDS:
		if GameState.tonic_count(str(tid)) <= 0:
			continue
		any = true
		var td: Dictionary = MedicineDefs.TONICS[str(tid)]
		_list.add_child(_option(load(MedicineDefs.icon_path(str(tid))), "%s ×%d" % [str(td["name"]), GameState.tonic_count(str(tid))],
			str(td["desc"]), "", str(tid) in GameState.tonic_loadout, pick_tonic.bind(str(tid))))
	if not any:
		_list.add_child(UiTheme.body_label("No tonics brewed. Cinder brews them at the Hangar's BREW tab.", 14, UiTheme.TEXT_DIM))
	## Dust Pacts (Depth E7): stack rules against yourself for a bigger payout.
	if GameState.pacts_unlocked():
		_list.add_child(_section("DUST PACTS  ·  payout +%d%%" % int(round(GameState.pact_loot_bonus() * 100.0))))
		for pid in ZoneDefs.PACTS.keys():
			var pd: Dictionary = ZoneDefs.PACTS[pid]
			_list.add_child(_option(null, "%s  (+%d%%)" % [str(pd["name"]), int(round(float(pd["loot"]) * 100.0))], str(pd["desc"]), "",
				str(pid) in GameState.pacts, pick_pact.bind(str(pid)), false, "SWORN"))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	_list.add_child(pad)
	_scroll.set_deferred("scroll_vertical", keep)


func _section(t: String) -> Label:
	var l := UiTheme.body_label(t, 15, UiTheme.AMBER)
	return l


## One selectable row: icon · name / desc · lock line. Tap to pick.
func _option(icon: Texture2D, title: String, desc: String, lock: String, on: bool, cb: Callable, mirror: bool = false, on_text: String = "EQUIPPED") -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_force_pass_scroll_events = true
	b.custom_minimum_size = Vector2(0, 76)
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
		m.add_theme_constant_override("margin_" + s, 12 if s in ["left", "right"] else 6)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	if icon != null:
		var ic := TextureRect.new()
		ic.texture = icon
		ic.custom_minimum_size = Vector2(56, 56)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.flip_h = mirror
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var t := UiTheme.body_label(title + ("   ✔" if false else ""), 18, UiTheme.AMBER if on else UiTheme.TEXT, false)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var d := UiTheme.body_label(desc, 13, UiTheme.TEXT_DIM)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	if lock != "":
		var l := UiTheme.body_label(lock, 13, UiTheme.RUST, false)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	if on:
		var tag := UiTheme.body_label(on_text, 13, UiTheme.TEAL, false)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tag)
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
