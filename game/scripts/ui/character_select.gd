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
	strip.add_theme_constant_override("separation", 6)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_scroll.add_child(strip)
	for id in CharacterDefs.all_known_ids():
		strip.add_child(_roster_tile(id))

	var row: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12 if portrait else 18)
	c.add_child(row)

	## Hero card: idle animation on the left, name / weapon / ability on the right.
	var pc := card(UiTheme.AMBER)
	pc.custom_minimum_size = Vector2(0 if portrait else 250, 0)
	row.add_child(pc)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	pc.add_child(ph)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UiTheme.plate("inset", 0.0))
	stage.custom_minimum_size = Vector2(196, 196)
	ph.add_child(stage)
	_hero = StripAnim.make("", 196, 8.0)
	stage.add_child(_hero)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	ph.add_child(info)
	_name = UiTheme.title_label("", 34)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(_name)
	_fantasy = UiTheme.body_label("", 15, UiTheme.TEXT_DIM)
	info.add_child(_fantasy)
	var wr := _icon_row(info)
	_weapon_icon = wr[0]
	_weapon_name = wr[1]
	var ar := _icon_row(info)
	_ability_icon = ar[0]
	_ability_name = ar[1]

	## Details
	var dc := card(UiTheme.LINE)
	dc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(dc)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dc.add_child(scroll)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_theme_constant_override("separation", 8)
	scroll.add_child(dv)
	dv.add_child(UiTheme.body_label("ABILITY  ·  the gold button", 13, UiTheme.AMBER))
	_ability = UiTheme.body_label("", 17)
	dv.add_child(_ability)
	dv.add_child(UiTheme.body_label("PERKS  ·  always on", 13, UiTheme.AMBER))
	_perks = VBoxContainer.new()
	_perks.add_theme_constant_override("separation", 2)
	dv.add_child(_perks)
	dv.add_child(UiTheme.body_label("STATS", 13, UiTheme.AMBER))
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 4)
	dv.add_child(_stats)
	_loadout = UiTheme.body_label("", 13, UiTheme.TEXT_DIM)
	dv.add_child(_loadout)
	dv.add_child(UiTheme.body_label("PET  ·  equip one", 13, UiTheme.AMBER))
	var pet_row := HBoxContainer.new()
	pet_row.add_theme_constant_override("separation", 10)
	dv.add_child(pet_row)
	for pdef in PetDefs.all_pets():
		pet_row.add_child(_pet_tile(pdef))
	var pet_txt := VBoxContainer.new()
	pet_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet_txt.alignment = BoxContainer.ALIGNMENT_CENTER
	pet_row.add_child(pet_txt)
	_pet_name = UiTheme.title_label("", 24)
	_pet_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pet_txt.add_child(_pet_name)
	_pet_blurb = UiTheme.body_label("", 14)
	dv.add_child(_pet_blurb)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	c.add_child(bottom)
	var gear := UiTheme.big_button("GEAR", UiTheme.TEAL, 76, 24)
	gear.custom_minimum_size.x = 0
	gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear.size_flags_stretch_ratio = 0.7
	gear.pressed.connect(func() -> void: GameState.go_loadout("character_select"))
	bottom.add_child(gear)
	var deploy := UiTheme.big_button("DEPLOY ›", UiTheme.AMBER, 76, 32)
	deploy.custom_minimum_size.x = 0
	deploy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deploy.pressed.connect(GameState.go_match)
	bottom.add_child(deploy)
	_refresh()

func _icon_row(parent: Control) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(40, 40)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(ic)
	var l := UiTheme.body_label("", 16, UiTheme.TEXT, true)
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
	_hero.pivot_offset = Vector2(98, 196)
	_hero.scale = Vector2(0.9, 1.08)
	_hero.create_tween().tween_property(_hero, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_name.text = str(c["display_name"])
	_name.add_theme_color_override("font_color", c.get("accent", UiTheme.AMBER))
	_fantasy.text = str(c["fantasy"])
	var w: Dictionary = LoadoutStubs.weapon_for_character(cid)
	var wpath := "res://assets/sprites/icons/weapons/weapon_%s.png" % cid
	_weapon_icon.texture = load(wpath) if ResourceLoader.exists(wpath) else null
	_weapon_name.text = "%s  ·  %s" % [w.get("name", "Weapon"), "melee" if w.has("melee") else str(w.get("category", "Gun"))]
	var ab: Dictionary = c.get("ability", {})
	var apath := CharacterDefs.ability_icon_path(cid)
	_ability_icon.texture = load(apath) if ResourceLoader.exists(apath) else null
	_ability_name.text = "%s  ·  %ds" % [ab.get("name", "—"), int(float(ab.get("cooldown", 0)))] if not ab.is_empty() else "No ability"
	_ability.text = "%s — %s" % [ab.get("name", "—"), ab.get("desc", "")] if not ab.is_empty() else "None"
	for ch in _perks.get_children():
		ch.queue_free()
	for p in c["perks"]:
		_perks.add_child(UiTheme.body_label("•  %s — %s" % [p["name"], p["desc"]], 15))
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
	var l := UiTheme.body_label(label, 15, UiTheme.TEXT_DIM)
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf((v - lo) / (hi - lo), 0.05, 1.0)
	UiTheme.skin_bar(bar, UiTheme.AMBER)
	h.add_child(bar)
	_stats.add_child(h)
