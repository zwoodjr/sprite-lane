extends "res://scripts/ui/menu_base.gd"

const SettingsMenu = preload("res://scripts/ui/settings_menu.gd")

const LOGO := "res://assets/sprites/ui/logo_wanderer.png"
const MenuFlow = preload("res://scripts/ui/menu_flow.gd")
const Feedback = preload("res://scripts/ui/feedback.gd")
const BuildInfo = preload("res://scripts/build_info.gd")


func _ready() -> void:
	## First launch on a new profile: straight into the Mayday prologue.
	if MenuFlow.route_boot(self):
		return
	super()

func build(c: VBoxContainer) -> void:
	c.add_theme_constant_override("separation", 10)

	## Top bar: logo (slams in), account level, scrap.
	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.add_theme_constant_override("separation", 10)
	c.add_child(top)
	var logo := TextureRect.new()
	if ResourceLoader.exists(LOGO):
		logo.texture = load(LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.custom_minimum_size = Vector2(0, 72)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## Owner-only: 5 quick taps on the logo open the admin PIN pad.
	logo.mouse_filter = Control.MOUSE_FILTER_STOP
	logo.gui_input.connect(_on_logo_input)
	top.add_child(logo)
	_sting(logo)
	var ab: Dictionary = GameState.account_bar_state()
	var lvbox := VBoxContainer.new()
	lvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	lvbox.add_theme_constant_override("separation", 4)
	top.add_child(lvbox)
	var lv := UiTheme.pixel_label("LV %d" % int(ab["level"]), UiTheme.PX_M, UiTheme.AMBER)
	lv.name = "AccountLevel"
	lvbox.add_child(lv)
	var xp_bar := ProgressBar.new()
	xp_bar.min_value = 0.0
	xp_bar.max_value = 1.0
	xp_bar.value = float(ab["ratio"])
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(72, 10)
	UiTheme.skin_bar(xp_bar, UiTheme.TEAL)
	lvbox.add_child(xp_bar)
	top.add_child(IconSet.rect("cur_scrap", 48))
	var scrap := UiTheme.pixel_label(str(GameState.account_scrap), UiTheme.PX_M, UiTheme.AMBER)
	scrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(scrap)

	## Headline goal: the next Hangar upgrade and how close the bank is.
	if not MenuFlow.is_first_wander():
		var goal := MenuFlow.goal_card()
		if goal:
			c.add_child(goal)

	## Hero showcase: the selected wanderer idling, pet at heel. Integer
	## scales of the 128-px frame.
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 256)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(stage)
	var hid := GameState.selected_character_id
	var hero := StripAnim.make("res://assets/sprites/characters/%s/%s_idle.png" % [hid, hid], 256, 8.0)
	var pid := GameState.selected_pet_id if GameState.pet_available(GameState.selected_pet_id) else PetDefs.default_id()
	var pet := PetDefs.get_pet(pid)
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
	var bob := hero.create_tween().set_loops()
	bob.tween_property(hero, "position:y", -2.0, 0.5).as_relative().set_trans(Tween.TRANS_SINE)
	bob.tween_property(hero, "position:y", 2.0, 0.5).as_relative().set_trans(Tween.TRANS_SINE)

	## Who deploys: tap to change survivor / pet.
	var who := UiTheme.big_button("%s  ·  %s" % [str(GameState.get_character().get("display_name", "")).to_upper(), str(pet.get("name", "")).to_upper()], UiTheme.LINE, UiTheme.MIN_TOUCH, 24)
	who.name = "WhoButton"
	who.custom_minimum_size.x = 0
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.clip_text = true
	who.pressed.connect(GameState.go_character_select)
	c.add_child(who)

	## Zone card: where PLAY goes, and CHANGE (campaign / Wander tiers / ascension).
	c.add_child(_zone_card())

	## DAILY · CAMPAIGN · SETTINGS
	var chips := HBoxContainer.new()
	chips.name = "Chips"
	chips.add_theme_constant_override("separation", 8)
	c.add_child(chips)
	for it in [["DAILY", GameState.go_daily, "tab_daily"], ["CAMPAIGN", GameState.go_campaign_map, "tab_stories"], ["SETTINGS", open_settings, "tab_workshop"]]:
		var b := UiTheme.big_button(str(it[0]), UiTheme.LINE, UiTheme.MIN_TOUCH, 18)
		b.name = "Chip_" + str(it[0])
		b.custom_minimum_size.x = 0
		b.icon = IconSet.tex(str(it[2]), false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(it[1])
		chips.add_child(b)
	## HELP · FEEDBACK (· QUIT on desktop), smaller.
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 8)
	c.add_child(sub)
	var items: Array = [["HELP", GameState.go_how_to_play, "set_hints", "HelpButton"], ["FEEDBACK", func() -> void: Feedback.open(self), "tab_notes", "FeedbackButton"]]
	if MobileLayout.is_desktop():
		items.append(["QUIT", func() -> void: get_tree().quit(), "set_reset", "QuitButton"])
	for it in items:
		var b := UiTheme.big_button(str(it[0]), UiTheme.LINE, UiTheme.MIN_TOUCH, 16)
		b.name = str(it[3])
		b.custom_minimum_size.x = 0
		b.icon = IconSet.tex(str(it[2]), false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(it[1])
		sub.add_child(b)
	## Build stamp: testers quote it in reports.
	var ver := UiTheme.body_label(BuildInfo.stamp(), 14, UiTheme.TEXT_DIM, false)
	ver.name = "BuildStamp"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(ver)
	## The bottom tab bar; PLAY is one tap into a run.
	var nav := NavBar.make("play")
	c.add_child(nav)
	_pulse(nav.get_node("Nav_play"))
	## The app closed mid-run (force quit / crash): resume or abandon first.
	if GameState.has_live_run():
		_live_prompt.call_deferred()
	elif GameState.load_notice != "":
		_notice_prompt.call_deferred()
	elif OS.has_feature("web") and not bool(GameState.settings.get("web_notice_seen", false)):
		_web_save_prompt.call_deferred()


## RUN INTERRUPTED — RESUME rebuilds the match; ABANDON counts as a death.
var _abandon_armed: bool = false
var _dialog: Control

func _close_dialog() -> void:
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null

func _live_prompt() -> void:
	var info: Dictionary = GameState.live_run_info()
	var hero := str(CharacterDefs.get_character(str(info.get("hero", ""))).get("display_name", "Your survivor"))
	var where := ""
	if str(info.get("mode", "")) == "campaign":
		where = str(CampaignDefs.level(str(info.get("level", ""))).get("title", "Campaign"))
	else:
		where = str(ModeDefs.get_mode(str(info.get("tier_mode", ""))).get("display_name", "Wander"))
	var t := int(float(info.get("time", 0.0)))
	var lines: Array = [
		["%s was out in %s when the app closed." % [hero, where], UiTheme.TEXT],
		["Run Lv %d · %d:%02d in" % [int(info.get("run_level", 1)), t / 60, t % 60], UiTheme.AMBER],
	]
	if not bool(info.get("ok", false)):
		lines.append(["The run's snapshot is damaged — resuming will count as abandoning.", UiTheme.DANGER])
	var at_risk: Array = info.get("at_risk", [])
	var lose := "your equipped gear (%s)" % ", ".join(PackedStringArray(at_risk)) if not at_risk.is_empty() else "your equipped gear"
	var kept := str(info.get("kept", ""))
	if str(info.get("mode", "")) == "campaign":
		lines.append(["ABANDON counts as a failed level: the run is lost, your gear is kept.", UiTheme.DANGER])
	else:
		lines.append(["ABANDON counts as a death: %s is lost, no scrap is recovered and the pack is lost.%s" % [
			lose, (" Insured: %s stays." % kept) if kept != "" else ""], UiTheme.DANGER])
	_abandon_armed = false
	_dialog = modal("RUN INTERRUPTED", lines, [
		["RESUME", UiTheme.AMBER, func() -> void:
			if not GameState.resume_live_run():
				_close_dialog()
				_after_abandon({}, "The run couldn't be rebuilt, so it counts as a loss.")],
		["ABANDON", UiTheme.RUST, func() -> void:
			var b: Button = null
			if is_instance_valid(_dialog):
				b = _dialog.find_child("Btn_ABANDON", true, false) as Button
			if not _abandon_armed:
				_abandon_armed = true
				if b:
					b.text = "TAP AGAIN: LOSE THE RUN" if str(info.get("mode", "")) == "campaign" else "TAP AGAIN: LOSE THE GEAR"
				return
			var r := GameState.abandon_live_run()
			_close_dialog()
			_after_abandon(r, "Run abandoned.")],
	], UiTheme.RUST)


func _after_abandon(r: Dictionary, head: String) -> void:
	var lost: Array = r.get("lost", [])
	var lines: Array = [[head, UiTheme.TEXT]]
	lines.append(["Lost: %s" % (", ".join(PackedStringArray(lost)) if not lost.is_empty() else "nothing equipped"), UiTheme.DANGER])
	if str(r.get("kept", "")) != "":
		lines.append(["Insured %s came home." % str(r["kept"]), UiTheme.TEAL])
	_dialog = modal("RUN LOST", lines, [["OK", UiTheme.LINE, func() -> void:
		_close_dialog()
		get_tree().reload_current_scene()]], UiTheme.RUST)


func _notice_prompt() -> void:
	_dialog = modal("SAVE CHECK", [[GameState.load_notice, UiTheme.TEXT]], [["OK", UiTheme.AMBER, func() -> void:
		GameState.load_notice = ""
		_close_dialog()]])


## Web build, once: progress lives in this browser only.
func _web_save_prompt() -> void:
	_dialog = modal("PLAYING IN THE BROWSER", [["Your progress is saved in this browser on this device. Clearing Safari's history or website data wipes it. Add Wanderer to your Home Screen for the best fit.", UiTheme.TEXT]],
		[["GOT IT", UiTheme.AMBER, func() -> void:
			GameState.set_setting("web_notice_seen", true)
			_close_dialog()]])


func _on_logo_input(ev: InputEvent) -> void:
	var down: bool = (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT)
	if down:
		Admin.logo_tap(Time.get_ticks_msec(), "touch" if ev is InputEventScreenTouch else "mouse")


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
	if not is_instance_valid(b) or SettingsDefs.reduce_motion():
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


## Where PLAY goes: tier (or first run) + payout; CHANGE opens campaign /
## Wander tier / ascension choice.
func _zone_card() -> Control:
	var p := card(UiTheme.LINE)
	p.name = "ZoneCard"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var m: Dictionary = ModeDefs.get_mode(MenuFlow.quick_mode_id() if not MenuFlow.is_first_wander() else ModeDefs.HAZE_ID)
	var title := "%s  ·  TIER %d" % [str(m.get("display_name", "")).to_upper(), int(m.get("tier", 1))]
	if GameState.ascension > 0 and not MenuFlow.is_first_wander():
		title += "  ·  A%d" % GameState.ascension
	var t := UiTheme.head_label(title, UiTheme.T_H3, UiTheme.AMBER)
	t.name = "ZoneTitle"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var sub := "First run: the tutorial drop" if MenuFlow.is_first_wander() else "Payout x%.1f  ·  %s" % [float(m.get("payout_mult", 1.0)), str(m.get("blurb", ""))]
	var d := UiTheme.body_label(sub, UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	d.max_lines_visible = 2
	v.add_child(d)
	var ch := UiTheme.big_button("CHANGE", UiTheme.LINE, UiTheme.MIN_TOUCH, 18)
	ch.name = "ZoneChange"
	ch.custom_minimum_size.x = 132
	ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.pressed.connect(GameState.go_mode_choice)
	h.add_child(ch)
	return p


## Settings as an overlay: closing it comes straight back here.
func open_settings() -> void:
	if not SettingsMenu.is_open(get_tree()):
		SettingsMenu.open_overlay(self)
