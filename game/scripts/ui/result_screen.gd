extends "res://scripts/ui/menu_base.gd"

## Post-run results, the payoff moment (style bible §6, audit cause #9).
## Two distinct treatments:
##   EXTRACTED: warm stage, teal extract beam + slow amber rays, hero idling.
##   WIPED:     dark red stage, falling ash, hero down in the dust, lost gear
##              stamped out.
## Sequence: title slam -> scrap count-up (ticks) -> account XP bar fills
## (level-up flash) -> gear revealed card by card with a rarity flash ->
## unlock cards -> actions. Tap anywhere skips the wait.

const Feedback = preload("res://scripts/ui/feedback.gd")
const REVEAL_GAP := 0.28

var _scrap_label: Label
var _bank_label: Label
var _xp_bar: ProgressBar
var _xp_lv: Label
var _xp_gain: Label
var _loot_wells: Array[Control] = []
var _unlock_cards: Array[Control] = []
var _continue_row: HBoxContainer
var _actions: VBoxContainer
var _skip: bool = false
var _won: bool = true
## Buttons stay deaf until the ceremony is over, so a skip tap never lands on
## RUN AGAIN / MENU while they are still invisible.
var actions_live: bool = false


func build(c: VBoxContainer) -> void:
	_won = GameState.extracted
	c.add_theme_constant_override("separation", 16)
	if not _won:
		## Wipe: the whole backdrop sinks into the dark.
		var dark := ColorRect.new()
		dark.color = Color(0.078, 0.047, 0.055, 0.55)
		dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dark)
		move_child(dark, 1)
		dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	## Title + one short line.
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	c.add_child(head)
	var title := UiTheme.title_label("EXTRACTED" if _won else "WIPED", UiTheme.T_TITLE_XL, UiTheme.TEAL if _won else UiTheme.DANGER)
	head.add_child(title)
	var mode_name := str(GameState.get_mode().get("display_name", ""))
	var sub := UiTheme.head_label(("%s  ·  SCRAP BANKED" % mode_name.to_upper()) if _won else "THE DUST TOOK YOUR BAG", UiTheme.T_H3, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(sub)
	title.resized.connect(func() -> void: title.pivot_offset = title.size * 0.5)
	title.scale = Vector2(1.6, 1.6)
	title.modulate.a = 0.0
	var tt := title.create_tween().set_parallel(true)
	tt.tween_property(title, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tt.tween_property(title, "modulate:a", 1.0, 0.12)

	## Daily Run: the score breakdown (and SHARE) leads the screen.
	var daily := GameState.last_daily
	if not daily.is_empty():
		c.add_child(_daily_card(daily))

	## Stage: the hero, lit by the outcome.
	var stage := _Stage.new()
	stage.won = _won
	stage.custom_minimum_size = Vector2(0, 232 if get_viewport_rect().size.y < 1400 else 280)
	if not daily.is_empty():
		stage.custom_minimum_size.y = 144
	c.add_child(stage)
	var hid := GameState.selected_character_id
	var hero := StripAnim.make("res://assets/sprites/characters/%s/%s_%s.png" % [hid, hid, "idle" if _won else "death"], 256, 8.0 if _won else 10.0)
	hero.loop = _won
	if not _won:
		hero.end_frame = 6
	stage.hero = hero
	stage.add_child(hero)

	## Scrap readout: icon, big pixel count-up, banked total.
	var sc := card(UiTheme.AMBER if _won else UiTheme.LINE)
	c.add_child(sc)
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 16)
	sc.add_child(sr)
	sr.add_child(IconSet.rect("cur_scrap", 96))
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sr.add_child(sv)
	sv.add_child(UiTheme.head_label("SCRAP BANKED" if _won else "SCRAP KEPT", UiTheme.T_H3, UiTheme.TEXT_DIM))
	_scrap_label = UiTheme.pixel_label("+0", UiTheme.PX_L, UiTheme.AMBER)
	sv.add_child(_scrap_label)
	var extra := _scrap_after() - GameState.result_scrap_before - GameState.result_scrap_banked
	if extra > 0:
		var xl := UiTheme.body_label("+%d from salvage & rewards" % extra, UiTheme.T_SMALL, UiTheme.TEXT_DIM)
		xl.name = "ScrapExtraLine"
		sv.add_child(xl)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 8)
	sr.add_child(right)
	if not _won and GameState.result_scrap_lost > 0:
		var lost := UiTheme.pixel_label("-%d" % GameState.result_scrap_lost, UiTheme.PX_M, UiTheme.DANGER)
		lost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(lost)
	_bank_label = UiTheme.pixel_label("%d" % GameState.result_scrap_before, UiTheme.PX_M, UiTheme.TEXT)
	_bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bank_label.name = "ScrapTotal"
	right.add_child(_bank_label)
	var bl := UiTheme.head_label("TOTAL", UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(bl)

	## Account XP: level badge + bar that fills from the old value.
	var xr := HBoxContainer.new()
	xr.add_theme_constant_override("separation", 16)
	c.add_child(xr)
	xr.add_child(IconSet.rect("cur_level", 48))
	var before: Dictionary = Progression.account_progress(GameState.account_xp - GameState.account_xp_this_run)
	_xp_lv = UiTheme.pixel_label("LV %d" % int(before["level"]), UiTheme.PX_M, UiTheme.AMBER)
	_xp_lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xr.add_child(_xp_lv)
	_xp_bar = ProgressBar.new()
	_xp_bar.max_value = 1.0
	_xp_bar.step = 0.0
	_xp_bar.value = float(before["ratio"])
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 24)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiTheme.skin_bar(_xp_bar, UiTheme.TEAL)
	xr.add_child(_xp_bar)
	_xp_gain = UiTheme.pixel_label("+%d XP" % GameState.account_xp_this_run, UiTheme.PX_M, UiTheme.TEAL)
	_xp_gain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_gain.modulate.a = 0.0
	xr.add_child(_xp_gain)

	## Run stats: three icon + number chips.
	var st := HBoxContainer.new()
	st.add_theme_constant_override("separation", 16)
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(st)
	_stat(st, "cur_xp", "LV %d" % GameState.result_run_level_reached, UiTheme.TEAL)
	_stat(st, "hud_kills", str(GameState.kills), UiTheme.TEXT)
	_stat(st, "hud_loot", "x%.1f" % GameState.loot_mult, UiTheme.AMBER)
	if GameState.run_best_chain >= 10:
		var ch := UiTheme.pixel_label("BEST KILL CHAIN  x%d" % GameState.run_best_chain, UiTheme.PX_M, UiTheme.RUST)
		ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ch.add_theme_constant_override("outline_size", 6)
		ch.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.95))
		c.add_child(ch)

	## Loot + unlocks scroll so a long list never pushes the buttons off.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 18
	scroll.custom_minimum_size = Vector2(0, 128)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(scroll)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	scroll.add_child(mid)
	var gear_list: Array = GameState.result_found.duplicate() if _won else GameState.result_lost_items
	var held: Array = []
	if _won and GameState.result_held_n > 0:
		held = GameState.pending_rewards.slice(maxi(0, GameState.pending_rewards.size() - GameState.result_held_n))
		gear_list.append_array(held)
	if not gear_list.is_empty():
		var gh := UiTheme.head_label("GEAR TO STASH" if _won else "GEAR LOST", UiTheme.T_H3, UiTheme.AMBER if _won else UiTheme.DANGER)
		mid.add_child(gh)
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		mid.add_child(grid)
		## Best first: legendary lands last for the biggest flash.
		var sorted := gear_list.duplicate()
		var order := {"common": 0, "rare": 1, "epic": 2, "legendary": 3}
		sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(order.get(str(a.get("rarity", "")), 0)) < int(order.get(str(b.get("rarity", "")), 0)))
		for i in range(mini(sorted.size(), 5)):
			var w := _loot_well(sorted[i])
			grid.add_child(w)
			_loot_wells.append(w)
		if gear_list.size() > 5:
			var more := UiTheme.pixel_label("+%d" % (gear_list.size() - 5), UiTheme.PX_M, UiTheme.TEXT_DIM)
			more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			grid.add_child(more)
	if not _won and not GameState.result_death_kept.is_empty():
		mid.add_child(UiTheme.body_label("Dragged home %d found piece%s (best first) — extract to keep the rest." % [GameState.result_death_kept.size(),
			"" if GameState.result_death_kept.size() == 1 else "s"], UiTheme.T_SMALL, UiTheme.AMBER))
	if _won and GameState.result_auto_salvaged_n > 0:
		var al := UiTheme.body_label("Auto-salvaged %d common%s (+%d scrap)" % [GameState.result_auto_salvaged_n,
			"" if GameState.result_auto_salvaged_n == 1 else "s", GameState.result_auto_salvaged_scrap], UiTheme.T_SMALL, UiTheme.AMBER)
		al.name = "AutoSalvageLine"
		mid.add_child(al)
	if _won and GameState.result_held_n > 0:
		var hl := UiTheme.body_label("Stash full: %d item%s held, nothing lost. Salvage something in Stash to make room." % [GameState.result_held_n,
			"" if GameState.result_held_n == 1 else "s"], UiTheme.T_SMALL, UiTheme.AMBER)
		hl.name = "HeldLine"
		mid.add_child(hl)
	if _won and GameState.result_salvaged > 0:
		mid.add_child(UiTheme.body_label("Stash full: %d extra common%s salvaged for %d scrap" % [GameState.result_overflow_n,
			"" if GameState.result_overflow_n == 1 else "s", GameState.result_salvaged], UiTheme.T_SMALL, UiTheme.TEXT_DIM))
	if _won and (GameState.result_auto_salvaged_n > 0 or GameState.result_salvaged > 0):
		mid.add_child(UiTheme.body_label("Changed your mind? Stash > BUY BACK.", UiTheme.T_SMALL, UiTheme.TEXT_DIM))
	for u in GameState.result_unlocks:
		var uc := _unlock_card(str(u))
		mid.add_child(uc)
		_unlock_cards.append(uc)

	## Actions sit at the bottom, under the thumb; they arrive last.
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 16)
	c.add_child(_actions)
	var primary := UiTheme.big_button("UPGRADE IN HANGAR" if _won else "HANGAR", UiTheme.AMBER, 80, 32)
	primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary.pressed.connect(GameState.go_hangar)
	_actions.add_child(primary)
	_continue_row = HBoxContainer.new()
	_continue_row.add_theme_constant_override("separation", 16)
	_actions.add_child(_continue_row)
	if _won and not GameState.result_found.is_empty():
		var eqg := UiTheme.big_button("EQUIP GEAR", UiTheme.TEAL, 64, 24)
		eqg.custom_minimum_size.x = 0
		eqg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eqg.pressed.connect(func() -> void: GameState.go_loadout("hangar"))
		_continue_row.add_child(eqg)
	var again := UiTheme.big_button("PRACTICE" if not daily.is_empty() else "RUN AGAIN", UiTheme.TEAL, 64, 24)
	again.custom_minimum_size.x = 0
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(GameState.go_match)
	_continue_row.add_child(again)
	var menu := UiTheme.big_button("MENU", UiTheme.LINE, 64, 24)
	menu.custom_minimum_size.x = 0
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.size_flags_stretch_ratio = 0.6
	menu.pressed.connect(GameState.go_main_menu)
	_continue_row.add_child(menu)
	## Tester report: screenshot of this result + the run's context.
	var fb := UiTheme.big_button("FEEDBACK", UiTheme.LINE, 64, 20)
	fb.name = "FeedbackButton"
	fb.custom_minimum_size.x = 0
	fb.icon = IconSet.tex("tab_notes", false)
	fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fb.pressed.connect(func() -> void: Feedback.open(self))
	_actions.add_child(fb)
	_actions.modulate.a = 0.0
	_set_actions_live(false)

	_sequence()


## DAILY SCORE: scrap hauled + kills + time (0 if down), counted or practice.
func _daily_card(d: Dictionary) -> Control:
	var parts: Dictionary = d.get("parts", {})
	var practice := bool(d.get("practice", false))
	var p := card(UiTheme.AMBER)
	p.name = "DailyScore"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var hl := UiTheme.head_label("DAILY · %s%s" % [str(d.get("date", "")), "  ·  PRACTICE" if practice else ""], UiTheme.T_H3,
		UiTheme.TEXT_DIM if practice else UiTheme.AMBER)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.clip_text = true
	top.add_child(hl)
	var total := UiTheme.pixel_label(str(int(parts.get("total", 0))), UiTheme.PX_L, UiTheme.AMBER if _won else UiTheme.DANGER)
	total.name = "DailyTotal"
	top.add_child(total)
	var ext := bool(parts.get("extracted", false))
	_score_line(v, "Scrap hauled", "+%d" % int(parts.get("scrap", 0)), ext)
	_score_line(v, "Kills  %d × %d" % [int(parts.get("kill_n", 0)), DailyDefs.KILL_POINTS], "+%d" % int(parts.get("kills", 0)), ext)
	_score_line(v, "Time  %s × %d/s" % [DailyDefs.fmt_time(float(parts.get("seconds", 0))), DailyDefs.TIME_POINTS], "+%d" % int(parts.get("time", 0)), ext)
	if not ext:
		v.add_child(UiTheme.body_label("Went down: a daily only scores if you extract.", UiTheme.T_SMALL, UiTheme.DANGER))
	var note := ("Practice: today's counted score stays %d." % int(d.get("counted", 0))) if practice else "Counted for today. More runs today are practice."
	v.add_child(UiTheme.body_label(note, UiTheme.T_SMALL, UiTheme.TEXT_DIM))
	var share := UiTheme.big_button("SHARE RESULT", UiTheme.TEAL, 56, 20)
	share.name = "DailyShare"
	share.pressed.connect(func() -> void:
		var how := share_result(str(d.get("share", "")))
		share.text = "SHARED" if how == "share" else "COPIED TO CLIPBOARD")
	v.add_child(share)
	return p


func _score_line(parent: Control, label: String, value: String, live: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	var l := UiTheme.body_label(label, UiTheme.T_SMALL, UiTheme.TEXT if live else UiTheme.TEXT_DIM, false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var r := UiTheme.pixel_label(value if live else "0", UiTheme.PX_S, UiTheme.TEXT if live else UiTheme.TEXT_DIM)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(r)


## Web: the system share sheet (navigator.share) when the browser has one,
## otherwise the clipboard; native builds: the clipboard. Returns "share" |
## "clipboard". (Game Center boards come later.)
static func share_result(text: String) -> String:
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var js := "(function(t){if(navigator.share){navigator.share({text:t}).catch(function(){});return 'share';}" \
			+ "if(navigator.clipboard){navigator.clipboard.writeText(t);}return 'clipboard';})(%s)" % JSON.stringify(text)
		var r: Variant = JavaScriptBridge.eval(js, true)
		return "share" if str(r) == "share" else "clipboard"
	DisplayServer.clipboard_set(text)
	return "clipboard"


func _scrap_after() -> int:
	return GameState.result_scrap_after if GameState.result_scrap_after >= 0 else GameState.account_scrap


## Every button under the actions block ignores input until the reveal ends.
func _set_actions_live(on: bool) -> void:
	actions_live = on
	if not is_instance_valid(_actions):
		return
	for b in _actions.find_children("*", "BaseButton", true, false):
		(b as Control).mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed) or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed):
		_skip = true


func _input(e: InputEvent) -> void:
	_gui_input(e)


func _wait(t: float) -> void:
	if _skip or not is_inside_tree():
		return
	await get_tree().create_timer(t).timeout


## The ceremony, step by step.
func _sequence() -> void:
	await _wait(0.35)
	await _count_scrap()
	await _fill_xp()
	for w in _loot_wells:
		if not is_instance_valid(w):
			return
		_reveal(w)
		await _wait(REVEAL_GAP + (0.25 if str(w.get_meta("rarity", "")) == "legendary" else 0.0))
	for uc in _unlock_cards:
		if not is_instance_valid(uc):
			return
		uc.modulate.a = 1.0
		uc.pivot_offset = uc.size * 0.5
		uc.scale = Vector2(0.9, 0.9)
		uc.create_tween().tween_property(uc, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Juice.sfx("radio_blip", -6.0)
		await _wait(0.2)
	if is_instance_valid(_actions):
		var ft := _actions.create_tween()
		ft.tween_property(_actions, "modulate:a", 1.0, 0.2)
		ft.tween_callback(_set_actions_live.bind(true))
		var p := _actions.get_child(0) as Control
		var tw := p.create_tween().set_loops()
		tw.tween_property(p, "self_modulate", Color(1.12, 1.08, 1.0), 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(p, "self_modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)


## Scrap ticks up with a sound, the total climbs with it.
func _count_scrap() -> void:
	var gain := GameState.result_scrap_banked
	var base := GameState.result_scrap_before
	var total := _scrap_after()
	var steps := clampi(gain, 0, 30)
	for i in range(steps + 1):
		if _skip or not is_instance_valid(_scrap_label):
			break
		var v := int(round(float(gain) * float(i) / float(maxi(steps, 1))))
		_scrap_label.text = "+%d" % v
		_bank_label.text = str(base + int(round(float(total - base) * float(i) / float(maxi(steps, 1)))))
		if i % 3 == 0:
			Juice.sfx("pick_scrap", -10.0)
		await get_tree().create_timer(0.035).timeout
	if is_instance_valid(_scrap_label):
		_scrap_label.text = "+%d" % gain
		_bank_label.text = str(total)
		_punch(_scrap_label)


func _fill_xp() -> void:
	if not is_instance_valid(_xp_bar):
		return
	_xp_gain.create_tween().tween_property(_xp_gain, "modulate:a", 1.0, 0.15)
	var before: Dictionary = Progression.account_progress(GameState.account_xp - GameState.account_xp_this_run)
	var after: Dictionary = GameState.account_bar_state()
	var lv0 := int(before["level"])
	var lv1 := int(after["level"])
	if lv1 > lv0:
		if not _skip:
			var tw := _xp_bar.create_tween()
			tw.tween_property(_xp_bar, "value", 1.0, 0.35)
			await tw.finished
		_xp_bar.value = 0.0
		_xp_lv.text = "LV %d" % lv1
		_punch(_xp_lv)
		Juice.sfx("level_up", -4.0)
	if _skip:
		_xp_bar.value = float(after["ratio"])
		return
	Juice.sfx("pick_xp", -6.0)
	var t2 := _xp_bar.create_tween()
	t2.tween_property(_xp_bar, "value", float(after["ratio"]), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t2.finished


func _punch(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(1.35, 1.35)
	c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stat(parent: Control, icon_id: String, value: String, col: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.plate("inset", 8.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(IconSet.rect(icon_id, 48))
	var l := UiTheme.pixel_label(value, UiTheme.PX_M, col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	parent.add_child(p)


## A gear well, hidden until its reveal.
func _loot_well(it: Dictionary) -> Control:
	var r := str(it.get("rarity", "common"))
	var w := GearUi.tile(it, 112, {"worn": false, "new": false})
	w.set_meta("rarity", r)
	w.tooltip_text = str(it.get("name", ""))
	w.modulate.a = 0.0
	if not _won:
		## Lost: greyed and stamped with a red cross.
		(w.get_child(0) as Control).self_modulate = Color(0.75, 0.6, 0.6)
		var x := _Cross.new()
		x.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		w.add_child(x)
	return w


func _reveal(w: Control) -> void:
	var r := str(w.get_meta("rarity", "common"))
	w.modulate = Color(2.2, 2.2, 2.2, 1.0) if _won else Color(1, 1, 1, 1)
	w.pivot_offset = w.size * 0.5
	w.scale = Vector2(1.3, 1.3)
	var tw := w.create_tween().set_parallel(true)
	tw.tween_property(w, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "modulate", Color.WHITE, 0.3)
	if _won:
		var fl := _Flash.new()
		fl.col = IconSet.rarity_color(r)
		fl.big = r in ["epic", "legendary"]
		fl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		w.add_child(fl)
		Juice.sfx("pick_legendary" if r == "legendary" else ("pick_epic" if r == "epic" else "pick_scrap"), -4.0)
		if r == "legendary":
			Juice.haptic(30)
	else:
		Juice.sfx("hit_metal", -10.0)


## "New tier unlocked: The Drift" -> icon card. Dev phrasing is cleaned up.
func _unlock_card(s: String) -> Control:
	var icon := "tab_goals"
	var kind := "UNLOCKED"
	var text := s
	if s.begins_with("Account prestige"):
		icon = "cur_level"
		kind = "LEVEL UP"
		text = "Account level %s" % s.get_slice("Lv ", 1).get_slice(" ", 0)
	elif s.begins_with("New tier unlocked:") or s.begins_with("Tier unlocked:"):
		icon = "cur_extract"
		kind = "NEW TIER"
		text = s.get_slice(":", 1).strip_edges()
	elif s.begins_with("Milestone:"):
		icon = "tab_goals"
		kind = "MILESTONE"
		text = s.get_slice(":", 1).strip_edges()
	elif s.begins_with("Hero unlocked:"):
		icon = "tab_crew"
		kind = "NEW HERO"
		text = s.get_slice(":", 1).strip_edges()
	elif s.begins_with("+"):
		kind = "FOUND"
		var low := s.to_lower()
		for k in ["dust_heart", "salvage_core", "herb", "plague_gland", "dust_shard", "machine_oil", "medicine"]:
			var nm := (MedicineDefs.item_name(k) if k != "dust_heart" else "Dust Heart").to_lower()
			if low.contains(nm):
				icon = IconSet.stuff(k)
				break
		if icon == "tab_goals":
			icon = "cur_scrap"
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.plate("panel_steel", 12.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	h.add_child(IconSet.rect(icon, 48))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UiTheme.head_label(kind, UiTheme.T_SMALL, UiTheme.TEAL))
	var tl := UiTheme.body_label(text, UiTheme.T_BODY, UiTheme.TEXT, false)
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(tl)
	p.modulate.a = 0.0
	return p


## Outcome stage behind the hero: light, rays, falling ash, ground line.
class _Stage extends Control:
	var won: bool = true
	var hero: Control
	var _t: float = 0.0
	var _ash: Array[Vector3] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in range(40):
			_ash.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.04, 0.12)))
		resized.connect(_place)

	func _place() -> void:
		if hero == null:
			return
		## Integer scale: 256 px frame at x1, or x2 when there is room... keep 1:1
		## (the strip is already authored at 1 texel = 1 px x the world zoom).
		var s := minf(256.0, size.y)
		hero.size = Vector2(s, s)
		hero.position = Vector2((size.x - s) * 0.5, size.y - s)

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y - 16.0)
		if won:
			## Teal extract beam + slow amber rays, all hard-edged bands.
			for i in range(8):
				var a := _t * 0.15 + i * TAU / 8.0
				var p1 := c + Vector2(cos(a - 0.08), sin(a - 0.08)) * 520.0
				var p2 := c + Vector2(cos(a + 0.08), sin(a + 0.08)) * 520.0
				draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(1.0, 0.75, 0.25, 0.07))
			var bw := 72.0 + sin(_t * 2.0) * 4.0
			draw_rect(Rect2(c.x - bw * 0.5, 0, bw, c.y), Color(0.36, 0.82, 0.75, 0.10))
			draw_rect(Rect2(c.x - bw * 0.25, 0, bw * 0.5, c.y), Color(0.36, 0.82, 0.75, 0.10))
			## Pad ellipse under the hero.
			_ellipse(c, Vector2(120, 22), Color(0.12, 0.35, 0.34, 0.9))
			_ellipse(c, Vector2(100, 16), Color(0.36, 0.82, 0.75, 0.35))
			## Rising sparks.
			for v in _ash:
				var y := fposmod(v.y - _t * v.z, 1.0)
				var x := c.x + (v.x - 0.5) * 220.0
				draw_rect(Rect2(Vector2(x, y * size.y).floor(), Vector2(2, 2)), Color(1.0, 0.75, 0.25, 0.7 * y))
		else:
			## Dark red pool, falling ash, a crack line in the ground.
			_ellipse(c, Vector2(150, 26), Color(0.3, 0.06, 0.07, 0.6))
			_ellipse(c, Vector2(96, 14), Color(0.08, 0.05, 0.05, 0.8))
			for v in _ash:
				var y := fposmod(v.y + _t * v.z * 0.6, 1.0)
				var x := v.x * size.x + sin(_t + v.x * 9.0) * 6.0
				draw_rect(Rect2(Vector2(x, y * size.y).floor(), Vector2(2, 2)), Color(0.56, 0.53, 0.49, 0.55))

	func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(32):
			var a := TAU * i / 32.0
			pts.append((c + Vector2(cos(a) * r.x, sin(a) * r.y)).floor())
		draw_colored_polygon(pts, col)


class _Flash extends Control:
	var col: Color = Color.WHITE
	var big: bool = false
	var _t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		_t += d
		queue_redraw()
		if _t > 0.5:
			queue_free()

	func _draw() -> void:
		var k := 1.0 - _t / 0.5
		var c := size * 0.5
		var r := size.x * (0.5 + _t * (2.4 if big else 1.4))
		for i in range(8 if big else 4):
			var a := i * TAU / (8.0 if big else 4.0) + PI / 8.0
			var p := c + Vector2(cos(a), sin(a)) * r
			draw_line(c + Vector2(cos(a), sin(a)) * size.x * 0.4, p, Color(col, k), 4.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(col, 0.5 * k), false, 4.0)


class _Cross extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var m := 20.0
		var col := Color("ff4836")
		draw_line(Vector2(m, m), size - Vector2(m, m), Color("140c0e"), 10.0)
		draw_line(Vector2(size.x - m, m), Vector2(m, size.y - m), Color("140c0e"), 10.0)
		draw_line(Vector2(m, m), size - Vector2(m, m), col, 6.0)
		draw_line(Vector2(size.x - m, m), Vector2(m, size.y - m), col, 6.0)
