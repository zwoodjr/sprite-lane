extends "res://scripts/ui/menu_base.gd"

const LOGO := "res://assets/sprites/ui/logo_wanderer.png"

func build(c: VBoxContainer) -> void:
	var portrait := MobileLayout.is_portrait()
	c.add_theme_constant_override("separation", 12)

	## Logo + tagline
	var logo := TextureRect.new()
	if ResourceLoader.exists(LOGO):
		logo.texture = load(LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 150 if portrait else 120)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(logo)
	var tag := UiTheme.body_label("Drop in. Grab what you can. Get out before the dust takes you.", 18, UiTheme.TEXT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(tag)

	## Hero showcase: the selected wanderer idling on the dunes, pet at heel.
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 220)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(stage)
	var hid := GameState.selected_character_id
	var hero := StripAnim.make("res://assets/sprites/characters/%s/%s_idle.png" % [hid, hid], 300, 8.0)
	hero.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hero.size = Vector2(300, 300)
	hero.position = Vector2(-150, -300)
	var pet := PetDefs.get_pet(GameState.selected_pet_id)
	var dog := StripAnim.make(str(pet.get("sprite", "")), 150, 7.0)
	dog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dog.size = Vector2(150, 150)
	dog.position = Vector2(60, -148)
	var shadow := _Shadow.new()
	shadow.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	shadow.position = Vector2(-150, -40)
	shadow.size = Vector2(320, 40)
	stage.add_child(shadow)
	stage.add_child(hero)
	stage.add_child(dog)
	stage.resized.connect(func() -> void:
		var k := clampf(stage.size.y / 300.0, 0.55, 1.0)
		hero.scale = Vector2.ONE * k
		hero.pivot_offset = Vector2(150, 300)
		dog.scale = Vector2.ONE * k
		dog.pivot_offset = Vector2(75, 150)
	)

	## Account strip
	var pc := card(UiTheme.LINE, Color(0.1, 0.075, 0.055, 0.9))
	c.add_child(pc)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	pc.add_child(pv)
	var ab: Dictionary = GameState.account_bar_state()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	pv.add_child(top)
	var who := UiTheme.body_label("%s  ·  Lv %d" % [str(GameState.get_character().get("display_name", "")), int(ab["level"])], 15, UiTheme.AMBER, false)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(who)
	top.add_child(UiTheme.body_label("%d scrap banked" % GameState.account_scrap, 15, UiTheme.TEXT, false))
	var xp_bar := ProgressBar.new()
	xp_bar.min_value = 0.0
	xp_bar.max_value = 1.0
	xp_bar.value = float(ab["ratio"])
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 18)
	UiTheme.skin_bar(xp_bar, UiTheme.TEAL)
	pv.add_child(xp_bar)
	var sub_l := "%d / %d XP  ·  %d extracts  ·  best %d" % [int(ab["into"]), int(ab["need"]), GameState.successful_extracts, GameState.best_payout]
	pv.add_child(UiTheme.body_label(sub_l, 13, UiTheme.TEXT_DIM, false))

	## Actions — bottom of the screen, under the thumb.
	var first := not GameState.tutorial_done
	var play := UiTheme.big_button("PLAY" if not first else "PLAY  ·  TUTORIAL", UiTheme.AMBER, 92, 38)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(GameState.go_mode_select)
	c.add_child(play)
	_pulse(play)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 10)
	c.add_child(sub)
	var items: Array = [["HANGAR", UiTheme.TEAL, GameState.go_hangar], ["HOW TO PLAY", UiTheme.LINE, GameState.go_how_to_play],
		["SETTINGS", UiTheme.LINE, GameState.go_settings]]
	if MobileLayout.is_desktop():
		items.append(["QUIT", UiTheme.RUST, func() -> void: get_tree().quit()])
	for it in items:
		var b := UiTheme.big_button(str(it[0]), it[1], 62, 18)
		b.custom_minimum_size.x = 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 0.7 if str(it[0]) == "QUIT" else 1.0
		b.pressed.connect(it[2])
		sub.add_child(b)


func _pulse(b: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(b):
		return
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween().set_loops()
	tw.tween_property(b, "self_modulate", Color(1.12, 1.08, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "self_modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)


class _Shadow extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		for i in range(4):
			var k := 1.0 - i * 0.2
			draw_set_transform(c, 0.0, Vector2(1.0, 0.22))
			draw_circle(Vector2.ZERO, size.x * 0.4 * k, Color(0.05, 0.03, 0.02, 0.16))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
