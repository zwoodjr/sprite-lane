extends "res://scripts/ui/menu_base.gd"

var _tabs: Dictionary = {}
var _pet_tabs: Dictionary = {}
var _portrait: TextureRect
var _name: Label
var _fantasy: Label
var _ability: Label
var _perks: VBoxContainer
var _stats: VBoxContainer
var _loadout: Label
var _pet_blurb: Label

func build(c: VBoxContainer) -> void:
	var portrait := MobileLayout.is_portrait()
	c.add_child(header("CHOOSE YOUR WANDERER", GameState.go_mode_select))

	## Roster strip: 8 sheet heroes — scrollable on narrow portrait phones.
	var strip_scroll := ScrollContainer.new()
	strip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	strip_scroll.custom_minimum_size = Vector2(0, 78)
	c.add_child(strip_scroll)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	strip_scroll.add_child(strip)
	for id in CharacterDefs.all_known_ids():
		strip.add_child(_roster_tile(id))

	var row: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14 if portrait else 18)
	c.add_child(row)

	## Portrait card
	var pc := card(UiTheme.LINE)
	pc.custom_minimum_size = Vector2(0 if portrait else 250, 0)
	row.add_child(pc)
	var pv := VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(pv)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(140 if portrait else 200, 140 if portrait else 200)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pv.add_child(_portrait)
	_name = UiTheme.title_label("", 26 if portrait else 28)
	pv.add_child(_name)
	_fantasy = UiTheme.body_label("", 13 if portrait else 14, UiTheme.TEXT_DIM)
	_fantasy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_fantasy)

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
	dv.add_child(UiTheme.body_label("ABILITY  (the gold button)", 13, UiTheme.AMBER))
	_ability = UiTheme.body_label("", 17)
	dv.add_child(_ability)
	dv.add_child(UiTheme.body_label("PERKS  (always on)", 13, UiTheme.AMBER))
	_perks = VBoxContainer.new()
	dv.add_child(_perks)
	dv.add_child(UiTheme.body_label("STATS", 13, UiTheme.AMBER))
	_stats = VBoxContainer.new()
	dv.add_child(_stats)
	_loadout = UiTheme.body_label("", 13, UiTheme.TEXT_DIM)
	dv.add_child(_loadout)
	dv.add_child(UiTheme.body_label("PET  (equip one)", 13, UiTheme.AMBER))
	var pet_row := HBoxContainer.new()
	pet_row.add_theme_constant_override("separation", 8)
	dv.add_child(pet_row)
	for pdef in PetDefs.all_pets():
		pet_row.add_child(_pet_tile(pdef))
	_pet_blurb = UiTheme.body_label("", 14)
	dv.add_child(_pet_blurb)

	var bottom := HBoxContainer.new()
	c.add_child(bottom)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	var deploy := UiTheme.big_button("DEPLOY ›", UiTheme.AMBER, 70, 28)
	deploy.custom_minimum_size.x = 240 if MobileLayout.is_portrait() else 300
	deploy.pressed.connect(GameState.go_match)
	bottom.add_child(deploy)
	_refresh()

func _pet_tile(def: Dictionary) -> Control:
	var id := str(def["id"])
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(72, 72)
	b.expand_icon = true
	b.icon = load(str(def.get("sprite", ""))) as Texture2D
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

func _roster_tile(id: String) -> Control:
	var def := CharacterDefs.get_character(id)
	var playable := CharacterDefs.is_playable(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	## Compact tiles so 8 heroes fit a portrait strip without crushing.
	b.custom_minimum_size = Vector2(56, 56)
	b.icon = load(str(def["sprite"])) if playable else null
	b.expand_icon = true
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
	for id in _tabs.keys():
		var b: Button = _tabs[id]
		var on: bool = id == GameState.selected_character_id
		if CharacterDefs.is_playable(id):
			var col: Color = (c["accent"] as Color) if on else UiTheme.LINE
			for s in ["normal", "hover", "pressed", "hover_pressed"]:
				b.add_theme_stylebox_override(s, UiTheme.box(Color(0.2, 0.15, 0.1), col, 12, 4 if on else 2, 6))
	_portrait.texture = load(str(c["sprite"]))
	_name.text = str(c["display_name"])
	_name.add_theme_color_override("font_color", c.get("accent", UiTheme.AMBER))
	_fantasy.text = str(c["fantasy"])
	var ab: Dictionary = c.get("ability", {})
	_ability.text = "%s — %s  (%ds cooldown)" % [ab.get("name", "—"), ab.get("desc", ""), int(float(ab.get("cooldown", 0)))] if not ab.is_empty() else "None"
	for ch in _perks.get_children():
		ch.queue_free()
	for p in c["perks"]:
		_perks.add_child(UiTheme.body_label("• %s — %s" % [p["name"], p["desc"]], 15))
	for ch in _stats.get_children():
		ch.queue_free()
	var w: Dictionary = LoadoutStubs.weapon_for_character(str(c["id"]))
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
		var col: Color = UiTheme.AMBER if on else UiTheme.LINE
		for s in ["normal", "hover", "pressed", "hover_pressed"]:
			pb.add_theme_stylebox_override(s, UiTheme.box(Color(0.2, 0.15, 0.1), col, 12, 4 if on else 2, 6))
	_pet_blurb.text = "%s — %s" % [pet.get("ability_name", ""), pet.get("ability_desc", "")]

func _stat_bar(label: String, v: float, lo: float, hi: float) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := UiTheme.body_label(label, 15, UiTheme.TEXT_DIM)
	l.custom_minimum_size = Vector2(80, 0)
	h.add_child(l)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf((v - lo) / (hi - lo), 0.05, 1.0)
	bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.AMBER, Color(0, 0, 0, 0), 4, 0, 0))
	h.add_child(bar)
	_stats.add_child(h)
