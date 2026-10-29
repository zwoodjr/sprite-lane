extends "res://scripts/ui/menu_base.gd"

const PORTRAIT := "res://assets/sprites/portraits/%s.png"
const PET_PORTRAIT := "res://assets/sprites/portraits/pet_%s.png"
const IDLE := "res://assets/sprites/characters/%s/%s_idle.png"

var _tabs: Dictionary = {}
var _pet_tabs: Dictionary = {}
var _hero: StripAnim
var _name: Label
var _fantasy: Label
var _weapon_icon: TextureRect
var _weapon_name: Label
var _ability_icon: TextureRect
var _ability_name: Label
var _ability: Label
var _perks: VBoxContainer
var _stats: VBoxContainer
var _loadout: Label
var _pet_name: Label
var _pet_blurb: Label

func build(c: VBoxContainer) -> void:
	var portrait := MobileLayout.is_portrait()
	c.add_child(header("CHOOSE YOUR WANDERER", GameState.go_mode_select))

	## Roster strip: painted bust portraits in brass tiles.
	var strip_scroll := ScrollContainer.new()
	strip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	strip_scroll.custom_minimum_size = Vector2(0, 86)
	c.add_child(strip_scroll)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", STRIP_SEP)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_scroll.add_child(strip)
	for id in CharacterDefs.all_known_ids():
		strip.add_child(_roster_tile(id))
	## Narrow portrait (iPhone SE / notched safe area): shrink the tiles so the
	## whole roster fits; past the minimum the strip scrolls instead.
	strip_scroll.resized.connect(func() -> void: _fit_strip(strip_scroll, strip))
	_fit_strip.call_deferred(strip_scroll, strip)

	## Big hero stage: the idle at an integer x2/x3 on a lit pad, name over it.
	var stage := _HeroStage.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 256)
	c.add_child(stage)
	_hero = StripAnim.make("", 256, 8.0)
	stage.add_child(_hero)
	stage.hero = _hero
	var namebox := VBoxContainer.new()
	namebox.add_theme_constant_override("separation", 0)
	namebox.position = Vector2(8, 8)
	stage.add_child(namebox)
	_name = UiTheme.title_label("", UiTheme.T_TITLE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	namebox.add_child(_name)
	_fantasy = UiTheme.body_label("", UiTheme.T_SMALL, UiTheme.TEXT_DIM, false)
	namebox.add_child(_fantasy)
	stage.namebox = namebox

	## Kit card: weapon + ability (icon-led), stats, perks, pet.
	var dc := card(UiTheme.LINE)
	c.add_child(dc)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_theme_constant_override("separation", 8)
	dc.add_child(dv)
	var kit := HBoxContainer.new()
	kit.add_theme_constant_override("separation", 16)
	dv.add_child(kit)
	var wr := _icon_row(kit)
	_weapon_icon = wr[0]
	_weapon_name = wr[1]
	var ar := _icon_row(kit)
	_ability_icon = ar[0]
	_ability_name = ar[1]
	_ability = UiTheme.body_label("", UiTheme.T_SMALL, UiTheme.TEXT)
	_ability.max_lines_visible = 2
	dv.add_child(_ability)
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 4)
	dv.add_child(_stats)
	_perks = VBoxContainer.new()
	_perks.add_theme_constant_override("separation", 0)
	dv.add_child(_perks)
	_loadout = UiTheme.body_label("", UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	_loadout.visible = false
	dv.add_child(_loadout)
	var pet_row := HBoxContainer.new()
	pet_row.add_theme_constant_override("separation", 8)
	dv.add_child(pet_row)
	## Dogs + any mech pets built in the Workshop (tiles shrink to fit the row).
	var pets: Array = []
	for pdef in PetDefs.all_pets():
		if GameState.pet_available(str(pdef["id"])):
			pets.append(pdef)
	var tile := 80.0 if pets.size() <= 3 else (72.0 if pets.size() <= 5 else 64.0)
	for pdef in pets:
		var t := _pet_tile(pdef)
		t.custom_minimum_size = Vector2(tile, tile)
		pet_row.add_child(t)
	var pet_txt := VBoxContainer.new()
	pet_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet_txt.alignment = BoxContainer.ALIGNMENT_CENTER
	pet_txt.add_theme_constant_override("separation", 0)
	pet_row.add_child(pet_txt)
	_pet_name = UiTheme.head_label("", UiTheme.T_H2, UiTheme.AMBER)
	pet_txt.add_child(_pet_name)
	_pet_blurb = UiTheme.body_label("", UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	_pet_blurb.max_lines_visible = 2
	pet_txt.add_child(_pet_blurb)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	c.add_child(bottom)
	var gear := UiTheme.big_button("GEAR", UiTheme.TEAL, 80, 24)
	gear.icon = IconSet.tex("slot_chest", false)
	gear.custom_minimum_size.x = 0
	gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear.size_flags_stretch_ratio = 0.7
	gear.pressed.connect(func() -> void: GameState.go_loadout("character_select"))
	bottom.add_child(gear)
	var deploy := UiTheme.big_button("LOADOUT", UiTheme.AMBER, 80, 32)
	deploy.custom_minimum_size.x = 0
	deploy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deploy.pressed.connect(GameState.go_prep)
	bottom.add_child(deploy)
	_refresh()

func _icon_row(parent: Control) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(h)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UiTheme.plate("inset", 4.0))
	h.add_child(well)
	var ic := IconSet.rect("slot_weapon", 48)
	well.add_child(ic)
	var l := UiTheme.body_label("", 20, UiTheme.TEXT, true)
	l.add_theme_font_override("font", UiTheme.font_button)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return [ic, l]

func _pet_tile(def: Dictionary) -> Control:
	var id := str(def["id"])
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(84, 84)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.icon = _pet_icon(id, str(def.get("sprite", "")))
	b.tooltip_text = str(def.get("name", "Pet"))
	b.pressed.connect(func() -> void:
		GameState.selected_pet_id = id
		GameState.reset_loadout_to_defaults()
		GameState.save_profile()
		Juice.sfx("ui_tap")
		_refresh()
	)
	_pet_tabs[id] = b
	return b

## Painted pet portrait; falls back to frame 0 of the idle strip.
func _pet_icon(id: String, strip: String) -> Texture2D:
	var p := PET_PORTRAIT % id
	if ResourceLoader.exists(p):
		return load(p)
	return _first_frame(strip)

## Pet art is an animation strip (square frames side by side): show frame 0.
func _first_frame(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var h := float(tex.get_height())
	if float(tex.get_width()) <= h * 1.5:
		return tex
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, h, h)
	return at

const STRIP_SEP := 6
const TILE_MAX := 76.0
const TILE_MIN := 56.0

func _fit_strip(sc: ScrollContainer, strip: HBoxContainer) -> void:
	if not is_instance_valid(sc) or not is_instance_valid(strip):
		return
	var n := strip.get_child_count()
	if n <= 0 or sc.size.x <= 0.0:
		return
	var t := floorf((sc.size.x - float(STRIP_SEP * (n - 1))) / float(n))
	t = clampf(t, TILE_MIN, TILE_MAX)
	for ch in strip.get_children():
		(ch as Control).custom_minimum_size = Vector2(t, t)
	sc.custom_minimum_size.y = t + 10.0

func _roster_tile(id: String) -> Control:
	var def := CharacterDefs.get_character(id)
	var playable := CharacterDefs.is_playable(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(76, 76)
	var pp := PORTRAIT % id
	if playable:
		b.icon = load(pp) if ResourceLoader.exists(pp) else load(str(def["sprite"]))
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.text = "" if playable else "?"
	b.tooltip_text = str(def["display_name"])
	b.disabled = not playable
	if playable:
		b.pressed.connect(func() -> void:
			GameState.selected_character_id = id
			GameState.reset_loadout_to_defaults()
			GameState.save_profile()
			Juice.sfx("ui_tap")
			_refresh()
		)
	_tabs[id] = b
	return b

func _refresh() -> void:
	var c := GameState.get_character()
	var cid := str(c["id"])
	for id in _tabs.keys():
		var b: Button = _tabs[id]
		var on: bool = id == GameState.selected_character_id
		UiTheme.skin_tile(b, on, 4.0)
		b.self_modulate = Color.WHITE if on else Color(0.82, 0.8, 0.78)
	_hero.set_strip(IDLE % [cid, cid])
	if _hero.texture == null:
		_hero.texture = load(str(c["sprite"]))
	## Little hop when the hero changes.
	_hero.pivot_offset = Vector2(_hero.size.x * 0.5, _hero.size.y)
	_hero.scale = Vector2(0.9, 1.08)
	_hero.create_tween().tween_property(_hero, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_name.text = str(c["display_name"])
	_name.add_theme_color_override("font_color", c.get("accent", UiTheme.AMBER))
	_fantasy.text = str(c["fantasy"])
	var w: Dictionary = LoadoutStubs.weapon_for_character(cid)
	var sts: Array = KitDefs.styles(cid)
	_weapon_icon.texture = IconSet.tex(IconSet.style(cid, str(sts[0]["id"])) if not sts.is_empty() else "slot_weapon", false)
	_weapon_name.text = str(w.get("name", "Weapon"))
	var ab: Dictionary = c.get("ability", {})
	_ability_icon.texture = IconSet.tex(IconSet.ability(cid, "a"), false)
	_ability_name.text = "%s  %ds" % [ab.get("name", "-"), int(float(ab.get("cooldown", 0)))] if not ab.is_empty() else "No ability"
	_ability.text = str(ab.get("desc", "")) if not ab.is_empty() else ""
	for ch in _perks.get_children():
		ch.queue_free()
	var pf := HFlowContainer.new()
	pf.add_theme_constant_override("h_separation", 8)
	pf.add_theme_constant_override("v_separation", 8)
	_perks.add_child(pf)
	for p in c["perks"]:
		var chp := UiTheme.chip(str(p["name"]), UiTheme.AMBER)
		chp.tooltip_text = str(p["desc"])
		chp.mouse_filter = Control.MOUSE_FILTER_PASS
		pf.add_child(chp)
	for ch in _stats.get_children():
		ch.queue_free()
	_stat_bar("Speed", float(c["move_speed_mult"]), 0.85, 1.15)
	_stat_bar("Damage", float(w.get("damage", 12)), 6.0, 50.0)
	_stat_bar("Attack rate", float(w.get("fire_rate", 8.0)), 1.0, 14.0)
	_stat_bar("Range", float(w.get("trigger_range", 300.0)), 50.0, 480.0)
	_stat_bar("Health", 100.0 + float(c["max_hp_bonus"]), 90.0, 130.0)
	var pet := PetDefs.get_pet(GameState.selected_pet_id)
	_loadout.text = "Loadout: %s (%s · %s · %.1f/s) · %s · Pet: %s" % [
		w["name"],
		w.get("category", "Gun"),
		"melee" if w.has("melee") else "%d rnd" % int(w.get("mag_size", 0)),
		float(w.get("fire_rate", 0.0)),
		LoadoutStubs.default_armor()["set_name"],
		pet["name"],
	]
	var tn: PackedStringArray = []
	for t in GameState.tonic_loadout:
		tn.append("%s (%d)" % [MedicineDefs.item_name(str(t)), GameState.tonic_count(str(t))])
	_loadout.text += "\nTonics: %s" % (", ".join(tn) if not tn.is_empty() else "none — brew at the Hangar's BREW tab")
	for pid in _pet_tabs.keys():
		var pb: Button = _pet_tabs[pid]
		var on: bool = pid == GameState.selected_pet_id
		UiTheme.skin_tile(pb, on, 4.0)
		pb.self_modulate = Color.WHITE if on else Color(0.82, 0.8, 0.78)
	_pet_name.text = str(pet.get("name", ""))
	_pet_blurb.text = "%s — %s" % [pet.get("ability_name", ""), pet.get("ability_desc", "")]

func _stat_bar(label: String, v: float, lo: float, hi: float) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := UiTheme.head_label(label.to_upper(), UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.step = 0.0
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf((v - lo) / (hi - lo), 0.05, 1.0)
	UiTheme.skin_bar(bar, UiTheme.AMBER)
	h.add_child(bar)
	_stats.add_child(h)



## Lit pad under the hero; places the strip at an integer scale.
class _HeroStage extends Control:
	var hero: Control
	var namebox: Control
	var _t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(_place)

	func _place() -> void:
		if hero == null:
			return
		var k := clampi(int((size.y + 24.0) / 128.0), 2, 3)
		var hs := 128.0 * k
		hero.size = Vector2(hs, hs)
		hero.position = Vector2(floorf(size.x * 0.58 - hs * 0.5), size.y - hs + 8.0 * k)
		if namebox:
			namebox.size.x = size.x * 0.5

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.58, size.y - 12.0)
		## Warm spotlight wedge + pixel pad ellipses.
		var w := 140.0 + sin(_t * 1.5) * 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - 40, 0), Vector2(c.x + 40, 0), Vector2(c.x + w, c.y), Vector2(c.x - w, c.y)]), Color(1.0, 0.75, 0.25, 0.08))
		for st in [[170.0, 26.0, Color(0.078, 0.047, 0.055, 0.5)], [120.0, 16.0, Color(0.72, 0.54, 0.2, 0.35)], [90.0, 10.0, Color(0.078, 0.047, 0.055, 0.45)]]:
			var pts := PackedVector2Array()
			for i in range(28):
				var a := TAU * i / 28.0
				pts.append((c + Vector2(cos(a) * float(st[0]), sin(a) * float(st[1]))).floor())
			draw_colored_polygon(pts, st[2])
