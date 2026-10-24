extends "res://scripts/ui/menu_base.gd"

const LOGO := "res://assets/sprites/ui/logo_wanderer.png"
const MenuFlow = preload("res://scripts/ui/menu_flow.gd")


func _ready() -> void:
	## First launch on a new profile: straight into the Mayday prologue.
	if MenuFlow.route_boot(self):
		return
	super()

func build(c: VBoxContainer) -> void:
	var portrait := MobileLayout.is_portrait()
	c.add_theme_constant_override("separation", 12)

	## Logo + one-line tagline; the logo slams in (title sting).
	var logo := TextureRect.new()
	if ResourceLoader.exists(LOGO):
		logo.texture = load(LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 144 if portrait else 112)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(logo)
	_sting(logo)
	var tag := UiTheme.head_label("DROP IN.  GRAB IT.  GET OUT.", UiTheme.T_H3, UiTheme.TEXT_DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(tag)

	## Hero showcase: the selected wanderer idling on the dunes, pet at heel.
	## Integer scales of the 128-px frame (x3 on tall phones, x2 otherwise).
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 256)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(stage)
	var hid := GameState.selected_character_id
	var hero := StripAnim.make("res://assets/sprites/characters/%s/%s_idle.png" % [hid, hid], 256, 8.0)
	var pet := PetDefs.get_pet(GameState.selected_pet_id)
	var dog := StripAnim.make(str(pet.get("sprite", "")), 192, 7.0)
	var shadow := _Shadow.new()
	stage.add_child(shadow)
	stage.add_child(hero)
	stage.add_child(dog)
	stage.resized.connect(func() -> void:
		var k := 4 if stage.size.y >= 520 else (3 if stage.size.y >= 384 else 2)
		var hs := 128.0 * k
		hero.size = Vector2(hs, hs)
		hero.position = Vector2(floorf((stage.size.x - hs) * 0.5) - 24.0, stage.size.y - hs + 8.0 * k)
		var ds := 64.0 * k
		dog.size = Vector2(ds, ds)
		dog.position = Vector2(hero.position.x + hs * 0.62, stage.size.y - ds + 4.0 * k)
		shadow.size = Vector2(hs * 1.2, 24)
		shadow.position = Vector2(hero.position.x - hs * 0.1, stage.size.y - 20.0)
	)
	## Idle breathing bob on top of the strip (keyed, 2 px steps).
	var bob := hero.create_tween().set_loops()
	bob.tween_property(hero, "position:y", -2.0, 0.5).as_relative().set_trans(Tween.TRANS_SINE)
	bob.tween_property(hero, "position:y", 2.0, 0.5).as_relative().set_trans(Tween.TRANS_SINE)

	## Account strip: level badge + XP bar, scrap total. Numbers in pixels.
	var pc := card(UiTheme.LINE)
	c.add_child(pc)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	pc.add_child(top)
	var ab: Dictionary = GameState.account_bar_state()
	top.add_child(IconSet.rect("cur_level", 48))
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(mid)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 8)
	mid.add_child(who)
	var nm := UiTheme.head_label(str(GameState.get_character().get("display_name", "")).to_upper(), UiTheme.T_H3, UiTheme.TEXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(nm)
	var lv := UiTheme.pixel_label("LV %d" % int(ab["level"]), UiTheme.PX_M, UiTheme.AMBER)
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(lv)
	var xp_bar := ProgressBar.new()
	xp_bar.min_value = 0.0
	xp_bar.max_value = 1.0
	xp_bar.value = float(ab["ratio"])
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 16)
	UiTheme.skin_bar(xp_bar, UiTheme.TEAL)
	mid.add_child(xp_bar)
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(8, 0)
	top.add_child(sep)
	top.add_child(IconSet.rect("cur_scrap", 48))
	var scrap := UiTheme.pixel_label(str(GameState.account_scrap), UiTheme.PX_M, UiTheme.AMBER)
	scrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(scrap)

	## Actions — bottom of the screen, under the thumb.
	## QUICK DEPLOY (after the first run): last hero / gear / pet / tier, one tap.
	if MenuFlow.can_quick_deploy():
		c.add_child(MenuFlow.quick_button())
	## PLAY -> CAMPAIGN (the story) or WANDER (the endless runs).
	var play := UiTheme.big_button("PLAY", UiTheme.AMBER, 96, 40)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(GameState.go_mode_choice)
	c.add_child(play)
	_pulse(play)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 16)
	c.add_child(sub)
	var items: Array = [["HANGAR", UiTheme.TEAL, GameState.go_hangar, "tab_camp"], ["HELP", UiTheme.LINE, GameState.go_how_to_play, "set_hints"],
		["SETTINGS", UiTheme.LINE, GameState.go_settings, "tab_workshop"]]
	if MobileLayout.is_desktop():
		items.append(["QUIT", UiTheme.RUST, func() -> void: get_tree().quit(), "set_reset"])
	for it in items:
		var b := UiTheme.big_button(str(it[0]), it[1], 64, 20)
		b.custom_minimum_size.x = 0
		b.icon = IconSet.tex(str(it[3]), false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 0.7 if str(it[0]) == "QUIT" else 1.0
		b.pressed.connect(it[2])
		sub.add_child(b)


## Title sting: the logo drops in big, lands with a shake and a dust puff.
func _sting(logo: Control) -> void:
	logo.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(logo):
		return
	logo.pivot_offset = logo.size * 0.5
	logo.scale = Vector2(1.5, 1.5)
	var tw := logo.create_tween()
	tw.set_parallel(true)
	tw.tween_property(logo, "modulate:a", 1.0, 0.12)
	tw.tween_property(logo, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		Juice.haptic(20)
		Juice.sfx("ui_tap", -4.0)
	)
	var x0 := logo.position.x
	for k in [6.0, -5.0, 3.0, -2.0, 0.0]:
		tw.chain().tween_property(logo, "position:x", x0 + k, 0.035)


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
	## Hard 2-step pixel ellipse (bible §1.4): INK 45% core, 27% rim.
	func _draw() -> void:
		var c := size * 0.5
		for st in [[1.0, 0.27], [0.7, 0.45]]:
			var pts := PackedVector2Array()
			for i in range(28):
				var a := TAU * i / 28.0
				pts.append((c + Vector2(cos(a) * size.x * 0.5 * st[0], sin(a) * size.y * 0.5 * st[0])).floor())
			draw_colored_polygon(pts, Color(0.078, 0.047, 0.055, st[1]))
