extends CanvasLayer

## Hidden admin panel (owner only). Unlock/lock: tap the top-left corner of
## the screen 5 times quickly (do it on the main menu). Once unlocked, a small
## ADMIN chip sits top-left on every screen; it opens a panel of rescue and
## test controls. The unlock is stored in user://admin.cfg, not the save.

const CFG := "user://admin.cfg"
const CORNER := 110.0
const TAPS := 5
## One finger tap arrives twice (ScreenTouch + emulated mouse, or the reverse
## on desktop); a second press inside this window is the same tap.
const TAP_DEDUPE_MS := 80

## RELEASE GATE. The panel is available when this is a debug build, or the
## export has the "admin" feature tag, or ADMIN_IN_RELEASE is true.
## ADMIN_IN_RELEASE is ON for now because the web tester build is a release
## export (and Xogot builds may be too). TURN OFF FOR APP STORE: set it to
## false (and drop any "admin" custom feature from export presets).
const ADMIN_IN_RELEASE := true

## False when gated off: no taps are counted and the chip never shows.
var allowed: bool = true

var enabled: bool = false

## --- Test switches (all reset to off when the app starts) ----------------
## God mode: the player takes no damage at all (hits, hazards, sickness).
var god: bool = false
## Player damage +% (0..500) and defense +% (0..90 = damage taken x0.1).
var dmg_pct: int = 0
var def_pct: int = 0
## Freezes the window countdown, schedule clock and Dust storm; enemies keep
## spawning and fighting.
var freeze_timer: bool = false
## Game speed in a match (0.5 / 1 / 2 / 3).
var time_scale: float = 1.0
## Ignore the live-enemy soft cap (stress tests).
var no_cap: bool = false
var hitboxes: bool = false
## Anything that changes the outcome was used this run: the result is
## flagged and kept out of bests, tier clears and Ascension records.
var run_tainted: bool = false
var _tab: String = "RUN"
var _confirm_reset_until: int = 0
var _hitbox_node: Node2D
const TABS: Array = ["RUN", "PLAYER", "SPAWN", "ACCOUNT", "DEBUG"]
const SPEEDS: Array = [0.5, 1.0, 2.0, 3.0]
var _taps: Array = []
var _chip: Button
var _panel: Control
var _was_paused: bool = false
var _fps: Label


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	allowed = admin_allowed()
	var cf := ConfigFile.new()
	if allowed and cf.load(CFG) == OK:
		enabled = bool(cf.get_value("admin", "enabled", false))
	_chip = Button.new()
	_chip.text = "ADMIN"
	_chip.focus_mode = Control.FOCUS_NONE
	_chip.add_theme_font_size_override("font_size", 13)
	_chip.custom_minimum_size = Vector2(64, 24)
	## Slim flat chip (theme buttons have tall content margins).
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.06, 0.05, 0.85) if st != "pressed" else Color(0.3, 0.2, 0.1, 0.9)
		sb.border_color = Color(1.0, 0.75, 0.25, 0.8)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		_chip.add_theme_stylebox_override(st, sb)
	_chip.modulate = Color(1, 1, 1, 0.75)
	_chip.pressed.connect(open_panel)
	add_child(_chip)
	_fps = Label.new()
	_fps.add_theme_font_size_override("font_size", 12)
	_fps.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
	_fps.visible = false
	add_child(_fps)
	_place_chip()
	get_viewport().size_changed.connect(_place_chip)
	_chip.visible = enabled
	if not allowed:
		set_process(false)
		set_process_input(false)


## Settings > Video > Show FPS (works in release builds too; the admin
## panel's FPS button flips the same setting).
func set_fps_visible(on: bool) -> void:
	_fps.visible = on
	if on:
		set_process(true)
	elif not allowed:
		set_process(false)


static func admin_allowed() -> bool:
	return OS.is_debug_build() or OS.has_feature("admin") or ADMIN_IN_RELEASE


func _place_chip() -> void:
	var m := MobileLayout.control_safe_margin()
	var vp := get_viewport().get_visible_rect().size
	## Top bar, right side, inside the safe band ABOVE every screen's header row
	## (it used to sit 196 px down and covered the hero strip on Choose Your
	## Wanderer). Right-aligned so it clears a centred notch / Dynamic Island.
	var h := clampf(m.position.y - 4.0, 18.0, 28.0)
	_chip.custom_minimum_size = Vector2(64, h)
	_chip.size = _chip.custom_minimum_size
	_chip.add_theme_font_size_override("font_size", 11 if h < 24.0 else 13)
	var right := m.position.x + m.size.x
	_chip.position = Vector2(right - _chip.size.x, maxf(0.0, m.position.y - h - 2.0))
	_fps.position = Vector2(_chip.position.x - 72.0, _chip.position.y + 2.0)


func _process(_delta: float) -> void:
	if run_tainted == false and _match() != null and cheats_on():
		run_tainted = true
	if _fps.visible:
		_fps.text = "%d fps %.1f ms" % [Engine.get_frames_per_second(), 1000.0 / maxf(1.0, Engine.get_frames_per_second())]
	## Game speed: only in a match, never over hitstop / slow-mo (Juice owns those).
	if not get_tree().paused and not Juice.slowmo_active() and not Juice.hitstop_active():
		var want := game_speed()
		if not is_equal_approx(Engine.time_scale, want):
			Engine.time_scale = want
	_sync_hitboxes()


## --- Hooks read by gameplay code -------------------------------------------

## Outcome-changing switches currently on.
func cheats_on() -> bool:
	return god or dmg_pct != 0 or def_pct != 0 or freeze_timer or not is_equal_approx(time_scale, 1.0)

func dmg_mult() -> float:
	return 1.0 + float(dmg_pct) / 100.0

## Damage taken multiplier (god mode is handled before this).
func def_mult() -> float:
	return clampf(1.0 - float(def_pct) / 100.0, 0.1, 1.0)

func game_speed() -> float:
	return time_scale if _match() != null else 1.0

## GameState.begin_run: a fresh run starts clean unless switches are still on.
func on_run_begin() -> void:
	run_tainted = cheats_on()

func taint() -> void:
	if _match() != null:
		run_tainted = true


func _sync_hitboxes() -> void:
	var mc := _match()
	var want := hitboxes and mc != null
	if want and (_hitbox_node == null or not is_instance_valid(_hitbox_node)):
		var w: Node = mc.get("world") if mc.get("world") != null else mc
		_hitbox_node = Node2D.new()
		_hitbox_node.set_script(load("res://scripts/ui/admin_hitboxes.gd"))
		w.add_child(_hitbox_node)
	elif not want and _hitbox_node != null and is_instance_valid(_hitbox_node):
		_hitbox_node.queue_free()
		_hitbox_node = null


func _input(event: InputEvent) -> void:
	if not allowed:
		return
	var pos := Vector2.INF
	## Emulated events (touch->mouse or mouse->touch) are copies of a real one.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos == Vector2.INF:
		return
	## Event positions are in window pixels; convert to the stretched UI space.
	var vp := get_viewport()
	var ui_pos: Vector2 = vp.get_screen_transform().affine_inverse() * pos if vp else pos
	register_tap(ui_pos, Time.get_ticks_msec())


## One corner press at `now` ms. True when it toggled the panel unlock.
func register_tap(ui_pos: Vector2, now: int) -> bool:
	if not allowed:
		return false
	if ui_pos.x > CORNER or ui_pos.y > CORNER:
		_taps.clear()
		return false
	if _taps.size() > 0 and now - int(_taps[_taps.size() - 1]) < TAP_DEDUPE_MS:
		return false
	_taps.append(now)
	while _taps.size() > 0 and now - int(_taps[0]) > 2500:
		_taps.pop_front()
	if _taps.size() >= TAPS:
		_taps.clear()
		set_enabled(not enabled)
		return true
	return false


func set_enabled(on: bool) -> void:
	on = on and allowed
	enabled = on
	_chip.visible = on
	if not on:
		close_panel()
		god = false
		if not bool(GameState.settings.get("show_fps", false)):
			_fps.visible = false
	var cf := ConfigFile.new()
	cf.set_value("admin", "enabled", on)
	cf.save(CFG)
	Juice.haptic(60)


func _player() -> Node:
	return get_tree().get_first_node_in_group("player") if get_tree() else null


func _match() -> Node:
	var s := get_tree().current_scene
	return s if s and s.has_method("spawn_special") else null


## --- Panel ------------------------------------------------------------------

func open_panel() -> void:
	if _panel and is_instance_valid(_panel):
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build_panel()


func _build_panel() -> void:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.01, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)
	var m := MobileLayout.control_safe_margin()
	var root := VBoxContainer.new()
	root.position = m.position + Vector2(8, 4)
	root.size = m.size - Vector2(16, 8)
	root.add_theme_constant_override("separation", 6)
	_panel.add_child(root)

	## Header: title + run flag + close (top-right, where the chip was).
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	root.add_child(hdr)
	var title := Label.new()
	title.text = "ADMIN"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	hdr.add_child(title)
	var flag := Label.new()
	flag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flag.add_theme_font_size_override("font_size", 13)
	if run_tainted:
		flag.text = "ADMIN RUN: no bests / clears"
		flag.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	else:
		flag.text = "clean run" if _match() != null else ""
		flag.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	hdr.add_child(flag)
	var close := _btn("CLOSE", Color(1.0, 0.75, 0.3))
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size = Vector2(110, 52)
	close.pressed.connect(close_panel)
	hdr.add_child(close)

	## Tabs.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	root.add_child(tabs)
	for t in TABS:
		var tb := _btn(str(t), Color(1.0, 0.8, 0.4) if t == _tab else Color(0.7, 0.65, 0.55))
		tb.custom_minimum_size = Vector2(0, 52)
		tb.add_theme_font_size_override("font_size", 15)
		if t == _tab:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.32, 0.2, 0.08, 0.95)
			sb.border_color = Color(1.0, 0.75, 0.3)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(6)
			tb.add_theme_stylebox_override("normal", sb)
		var tid := str(t)
		tb.pressed.connect(func() -> void:
			_tab = tid
			_refresh())
		tabs.add_child(tb)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	match _tab:
		"RUN": _tab_run(v)
		"PLAYER": _tab_player(v)
		"SPAWN": _tab_spawn(v)
		"ACCOUNT": _tab_account(v)
		_: _tab_debug(v)


func _tab_run(v: VBoxContainer) -> void:
	var mc := _match()
	_section(v, "Go to")
	_row(v, [
		["Restart run", func() -> void: _go(GameState.go_match)],
		["Main menu", func() -> void: _go(GameState.go_main_menu)],
	])
	_row(v, [
		["Tier select", func() -> void: _go(GameState.go_mode_select)],
		["Hangar", func() -> void: _go(GameState.go_hangar)],
	])
	if mc == null:
		_note(v, "Start a run for the in-run controls.")
	else:
		_section(v, "Timer")
		_row(v, [
			["Pause timer: %s" % _on(freeze_timer), func() -> void:
				freeze_timer = not freeze_timer
				_refresh()],
			["Next window", _skip_phase],
		])
		_row(v, [
			["Jump to extract", _jump_extract],
			["Extract now", func() -> void:
				taint()
				_call_match("_on_extract_requested")],
		])
		_row(v, [
			["Teleport to pad", _teleport_pad],
			["Die now", func() -> void: _call_match("_finish_wipe", ["admin"])],
		])
		_section(v, "Greed")
		_stepper(v, "Greed (windows stayed)", str(GameState.windows_skipped), func(d: int) -> void:
			GameState.windows_skipped = clampi(GameState.windows_skipped + d, 0, ModeDefs.GREED_MAX)
			taint())
		_row(v, [
			["Kill all enemies", func() -> void:
				taint()
				_kill_all()],
			["Empty backpack", _empty_bag],
		])
	_section(v, "Campaign")
	if mc != null and mc.has_method("debug_complete_objective"):
		_row(v, [
			["Complete objective", func() -> void:
				close_panel()
				get_tree().paused = false
				mc.call("debug_complete_objective")],
			["Win level", func() -> void: _call_match("_on_extract_requested")],
		])
	_row(v, [
		["Campaign map", func() -> void: _go(GameState.go_campaign_map)],
		["Unlock all levels", func() -> void:
			GameState.campaign_debug_unlock_to(str(CampaignDefs.ORDER[CampaignDefs.ORDER.size() - 1]))
			_refresh()],
	])
	var jumps: Array = []
	for id in CampaignDefs.ORDER:
		if CampaignDefs.is_playable(str(id)):
			var lid := str(id)
			jumps.append(["%s %s" % [CampaignDefs.number_tag(lid), str(CampaignDefs.level(lid).get("title", ""))], func() -> void:
				GameState.campaign_debug_unlock_to(lid)
				_go(func() -> void: GameState.go_campaign_level(lid))])
	for i in range(0, jumps.size(), 2):
		_row(v, jumps.slice(i, i + 2))


func _tab_player(v: VBoxContainer) -> void:
	_section(v, "Survival")
	_row(v, [
		["God mode: %s" % _on(god), func() -> void:
			god = not god
			_refresh()],
		["Full heal", _heal],
	])
	_stepper(v, "Damage dealt", "+%d%%" % dmg_pct, func(d: int) -> void:
		dmg_pct = clampi(dmg_pct + d * 25, 0, 500))
	_stepper(v, "Defense (less damage taken)", "+%d%%" % def_pct, func(d: int) -> void:
		def_pct = clampi(def_pct + d * 10, 0, 90))
	_section(v, "Power")
	_row(v, [
		["+1 run level", _level_up],
		["+5 run levels", func() -> void:
			for i in range(5):
				GameState.add_run_xp(maxi(1, Progression.run_xp_to_next(GameState.run_level) - GameState.run_xp))
			close_panel()
			get_tree().paused = false],
	])
	_row(v, [
		["Refill ability + dash", _refill],
		["Ammo full", func() -> void:
			var p := _player()
			if p and p.has_method("_mag_size"):
				p.set("_ammo", p.call("_mag_size"))
				p.set("_reload_left", 0.0)],
	])
	_note(v, "God, damage, defense, timer pause and speed flag the run: payout still banks, but bests, tier clears and Ascension records are skipped.")


func _tab_spawn(v: VBoxContainer) -> void:
	var mc := _match()
	if mc == null:
		_note(v, "Start a run to spawn enemies.")
		return
	_section(v, "Specials")
	_row(v, [
		["Elite", func() -> void: _spawn("elite")],
		["Zone boss", func() -> void: _spawn("boss")],
	])
	var bosses: Array = []
	var seen := {}
	for t in range(5, 11):
		for b in ZoneDefs.wander_bosses(t):
			var k := str(b["kind"])
			if seen.has(k):
				continue
			seen[k] = true
			var bd: Dictionary = b
			bosses.append([str(bd.get("name", k)), func() -> void: _spawn_named(bd)])
	bosses.append(["Dust Warden", func() -> void:
		var p := _player() as Node2D
		var e: Node = mc.call("spawn_at", "boss", RadioDefs.WARDEN_KIND, p.global_position + Vector2(0, -320)) if p else null
		if e:
			mc.call("attach_brain", e, "warden")
		close_panel()])
	for i in range(0, bosses.size(), 2):
		_row(v, bosses.slice(i, i + 2))
	_section(v, "Any enemy (spawns near you)")
	var all: Array = []
	for k in EnemyDefs.all_kinds():
		var kid := str(k.get("id", ""))
		if kid == "":
			continue
		all.append([kid.replace("_", " "), func() -> void:
			var p := _player() as Node2D
			if p:
				mc.call("spawn_mob", kid, p.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 220.0, "", 1.0)])
	for i in range(0, all.size(), 2):
		_row(v, all.slice(i, i + 2), 15)


func _tab_account(v: VBoxContainer) -> void:
	_section(v, "Scrap + XP (saved)")
	_row(v, [
		["+1,000 scrap", func() -> void: _scrap(1000)],
		["+10,000 scrap", func() -> void: _scrap(10000)],
	])
	_row(v, [
		["+1 account level", func() -> void:
			var pr := Progression.account_progress(GameState.account_xp)
			GameState.account_xp += int(pr["need"]) - int(pr["into"])
			GameState.call("_sync_account_level")
			GameState.save_profile()
			_refresh()],
		["Scrap to 0", func() -> void:
			GameState.account_scrap = 0
			GameState.save_profile()
			_refresh()],
	])
	_section(v, "Tier + Ascension")
	var cur_tier := int(GameState.get_mode().get("tier", 1))
	_stepper(v, "Tier", "%d %s" % [cur_tier, str(GameState.get_mode().get("display_name", ""))], func(d: int) -> void:
		var t := clampi(cur_tier + d, 1, ModeDefs.EXPOSED_TIERS)
		GameState.play_mode = "wander"
		GameState.selected_mode_id = str(ModeDefs.tier_mode(t).get("id", GameState.selected_mode_id)))
	_stepper(v, "Ascension (Dustfall)", "A%d" % GameState.ascension, func(d: int) -> void:
		var a := clampi(GameState.ascension + d, 0, ModeDefs.ASCENSION_MAX)
		GameState.ascension_cleared = maxi(GameState.ascension_cleared, a - 1)
		if GameState.tier_extracts_at(ModeDefs.EXPOSED_TIERS) <= 0:
			GameState.tier_extracts[str(ModeDefs.EXPOSED_TIERS)] = 1
		GameState.set_ascension(a))
	_section(v, "Unlock")
	_row(v, [
		["All tiers", _unlock_tiers],
		["All Ascension", func() -> void:
			GameState.ascension_cleared = ModeDefs.ASCENSION_MAX - 1
			GameState.tier_extracts[str(ModeDefs.EXPOSED_TIERS)] = maxi(1, GameState.tier_extracts_at(ModeDefs.EXPOSED_TIERS))
			GameState.save_profile()
			_refresh()],
	])
	_row(v, [
		["Max all stations", _max_hangar],
		["Build all mechs", func() -> void:
			for id in PetDefs.MECH_IDS:
				GameState.mechs_built[str(id)] = true
			GameState.save_profile()
			_refresh()],
	])
	_section(v, "Gear (to stash, for %s)" % GameState.selected_character_id)
	_row(v, [
		["Common", func() -> void: _grant("common")],
		["Rare", func() -> void: _grant("rare")],
	])
	_row(v, [
		["Epic", func() -> void: _grant("epic")],
		["Legendary", func() -> void: _grant("legendary")],
	])
	_row(v, [
		["Set piece", func() -> void: _grant("set")],
		["Legendary weapon", func() -> void: _grant("weapon")],
	])
	_section(v, "Onboarding")
	_row(v, [
		["Skip phase-in: %s" % _on(GameState.onboard_skip), func() -> void:
			GameState.onboard_skip = not GameState.onboard_skip
			_refresh()],
		["Fast timers: %s" % _on(GameState.fast_timers), func() -> void:
			GameState.fast_timers = not GameState.fast_timers
			_refresh()],
	])
	_section(v, "Danger")
	var armed := Time.get_ticks_msec() < _confirm_reset_until
	var reset := _btn("TAP AGAIN TO WIPE THE SAVE" if armed else "Reset save…", Color(1.0, 0.3, 0.25))
	reset.pressed.connect(func() -> void:
		if Time.get_ticks_msec() < _confirm_reset_until:
			_confirm_reset_until = 0
			GameState.reset_profile()
			GameState.save_profile()
			_go(GameState.go_main_menu)
		else:
			_confirm_reset_until = Time.get_ticks_msec() + 4000
			_refresh())
	v.add_child(reset)


func _tab_debug(v: VBoxContainer) -> void:
	_section(v, "Speed")
	var sp := HBoxContainer.new()
	sp.add_theme_constant_override("separation", 6)
	v.add_child(sp)
	for s in SPEEDS:
		var sv := float(s)
		var b := _btn(("%.1fx" % sv).replace(".0x", "x"), Color(1.0, 0.8, 0.4) if is_equal_approx(sv, time_scale) else Color(0.8, 0.75, 0.65))
		b.pressed.connect(func() -> void:
			time_scale = sv
			_refresh())
		sp.add_child(b)
	_section(v, "Overlays")
	_row(v, [
		["FPS / ms: %s" % _on(_fps.visible), func() -> void:
			GameState.set_setting("show_fps", not _fps.visible)
			_refresh()],
		["Hitboxes: %s" % _on(hitboxes), func() -> void:
			hitboxes = not hitboxes
			_refresh()],
	])
	_section(v, "Spawning")
	_row(v, [
		["Enemy cap: %s" % ("OFF" if no_cap else "ON"), func() -> void:
			no_cap = not no_cap
			_refresh()],
		["Hide admin", func() -> void: set_enabled(false)],
	])
	var n := get_tree().get_nodes_in_group("enemies").size()
	_note(v, "Live enemies: %d · nodes: %d · speed %.1fx" % [n, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), time_scale])


func close_panel() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
		get_tree().paused = _was_paused


func _refresh() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
	_build_panel()


func _on(b: bool) -> String:
	return "ON" if b else "OFF"


func _section(v: VBoxContainer, t: String) -> void:
	var l := Label.new()
	l.text = t.to_upper()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55))
	v.add_child(l)


func _note(v: VBoxContainer, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.65, 0.6, 0.52))
	v.add_child(l)


func _btn(t: String, col: Color = Color(0.9, 0.85, 0.75)) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", col)
	return b


func _row(v: VBoxContainer, items: Array, font: int = 17) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	for it in items:
		var b := _btn(str(it[0]))
		b.add_theme_font_size_override("font_size", font)
		b.pressed.connect(it[1])
		h.add_child(b)
	## Odd count: keep the half-width look.
	if items.size() == 1:
		var pad := Control.new()
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(pad)


## [label ........ (-) value (+)] — thumb-sized steppers.
func _stepper(v: VBoxContainer, label: String, value: String, change: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 16)
	h.add_child(l)
	var minus := _btn("–")
	minus.custom_minimum_size = Vector2(64, 56)
	minus.size_flags_horizontal = Control.SIZE_SHRINK_END
	minus.pressed.connect(func() -> void:
		change.call(-1)
		_refresh())
	h.add_child(minus)
	var val := Label.new()
	val.text = value
	val.custom_minimum_size = Vector2(110, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 17)
	val.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	h.add_child(val)
	var plus := _btn("+")
	plus.custom_minimum_size = Vector2(64, 56)
	plus.size_flags_horizontal = Control.SIZE_SHRINK_END
	plus.pressed.connect(func() -> void:
		change.call(1)
		_refresh())
	h.add_child(plus)


## --- Actions ----------------------------------------------------------------

func _go(f: Callable) -> void:
	close_panel()
	get_tree().paused = false
	Engine.time_scale = 1.0
	f.call()


func _call_match(method: String, args: Array = []) -> void:
	var mc := _match()
	if mc and mc.has_method(method):
		close_panel()
		get_tree().paused = false
		mc.callv(method, args)


func _kill_all() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.call("take_damage", 99999.0, Vector2.ZERO, 0.0, false)


func _skip_phase() -> void:
	var mc := _match()
	if mc and "_phase_time_left" in mc:
		mc.set("_phase_time_left", 0.05)
	close_panel()


## Straight to the next open extract window (skips sealed phases).
func _jump_extract() -> void:
	var mc := _match()
	if mc == null:
		return
	var phases: Array = mc.get("_phases")
	var i := int(mc.get("_phase_index")) + 1
	while i < phases.size() and not bool((phases[i] as Dictionary).get("extract_open", false)):
		i += 1
	if i < phases.size():
		taint()
		mc.call("_start_phase", i)
	close_panel()


func _teleport_pad() -> void:
	var mc := _match()
	var p := _player() as Node2D
	if mc == null or p == null:
		return
	var best: Node2D = null
	for pad in mc.call("get_pads"):
		if is_instance_valid(pad) and (best == null or p.global_position.distance_to(pad.global_position) < p.global_position.distance_to(best.global_position)):
			best = pad
	if best:
		p.global_position = best.global_position + Vector2(0, 6)
	close_panel()


func _spawn(role: String) -> void:
	var mc := _match()
	if mc:
		mc.call("spawn_special", role)
	close_panel()


func _spawn_named(b: Dictionary) -> void:
	var mc := _match()
	if mc:
		var e: Node = mc.call("spawn_special", "boss", str(b["kind"]))
		if e:
			e.set("display_name", str(b.get("name", "")))
			mc.call("attach_brain", e, str(b.get("brain", "")))
	close_panel()


func _heal() -> void:
	var p := _player()
	if p:
		p.set("hp", float(p.get("max_hp")))
		if p.has_signal("health_changed"):
			p.emit_signal("health_changed", p.get("hp"), p.get("max_hp"))


func _refill() -> void:
	var p := _player()
	if p:
		p.set("_ability_cd", 0.0)
		p.set("_dash_cd", 0.0)


func _level_up() -> void:
	close_panel()
	get_tree().paused = false
	GameState.add_run_xp(maxi(1, Progression.run_xp_to_next(GameState.run_level) - GameState.run_xp))


func _empty_bag() -> void:
	GameState.run_pack.clear()
	for sig in ["pack_changed", "run_pack_changed"]:
		if GameState.has_signal(sig):
			GameState.emit_signal(sig)
	_refresh()


func _scrap(n: int) -> void:
	GameState.account_scrap += n
	GameState.save_profile()
	if GameState.has_signal("meta_changed"):
		GameState.meta_changed.emit()
	_refresh()


func _unlock_tiers() -> void:
	GameState.best_tier_extracted = maxi(int(GameState.best_tier_extracted), ModeDefs.EXPOSED_TIERS - 1)
	GameState.save_profile()
	_refresh()


func _max_hangar() -> void:
	for id in HangarDefs.all_ids():
		GameState.camp[str(id)] = HangarDefs.max_rank(str(id))
	GameState.save_profile()
	if GameState.has_signal("meta_changed"):
		GameState.meta_changed.emit()
	_refresh()


func _grant(what: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var hero := GameState.selected_character_id
	var it: Dictionary
	match what:
		"weapon":
			it = GearDefs.make_weapon(hero, "legendary", rng)
		"set":
			it = GearDefs.roll_set_piece("epic", hero, rng)
		_:
			var slots: Array = GearDefs.ARMOR_SLOTS + GearDefs.ACCESSORY_SLOTS
			it = GearDefs.make_gear(str(slots[rng.randi() % slots.size()]), what, rng)
	if not it.is_empty() and GameState.add_to_stash(it):
		GameState.save_profile()
		Juice.haptic(30)
		_toast("+ %s" % str(it.get("name", "item")))
	else:
		_toast("Stash full")


func _toast(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	l.position = Vector2(24, get_viewport().get_visible_rect().size.y * 0.5)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.6)
	tw.tween_callback(l.queue_free)
