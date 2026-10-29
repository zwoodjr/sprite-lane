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
var god: bool = false
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
	if god:
		var p := _player()
		if p:
			p.set("_iframes", maxf(float(p.get("_iframes")), 0.5))
			if float(p.get("hp")) < float(p.get("max_hp")) * 0.5:
				p.set("hp", float(p.get("max_hp")))
	if _fps.visible:
		_fps.text = "%d fps" % Engine.get_frames_per_second()


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
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)
	var m := MobileLayout.control_safe_margin()
	var scroll := ScrollContainer.new()
	scroll.position = m.position + Vector2(0, 40)
	scroll.size = m.size - Vector2(0, 40)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = m.size.x
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)

	var title := Label.new()
	title.text = "ADMIN"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	v.add_child(title)

	var in_match := _match() != null
	_section(v, "Go to")
	_row(v, [
		["Main menu", func() -> void: _go(GameState.go_main_menu)],
		["Hangar", func() -> void: _go(GameState.go_hangar)],
	])
	_row(v, [
		["Tier select", func() -> void: _go(GameState.go_mode_select)],
		["Restart run", func() -> void: _go(GameState.go_match)],
	])
	if in_match:
		_section(v, "This run")
		_row(v, [
			["Extract now", func() -> void: _call_match("_on_extract_requested")],
			["Die now", func() -> void: _call_match("_finish_wipe", ["admin"])],
		])
		_row(v, [
			["Kill all enemies", _kill_all],
			["Skip to next window", _skip_phase],
		])
		_row(v, [
			["Spawn elite", func() -> void: _spawn("elite")],
			["Spawn boss", func() -> void: _spawn("boss")],
		])
		_row(v, [
			["Full heal", _heal],
			["+1 run level", _level_up],
		])
		_row(v, [
			["God mode: %s" % ("ON" if god else "OFF"), func() -> void:
				god = not god
				_refresh()],
			["Empty backpack", _empty_bag],
		])
	_section(v, "Campaign")
	if in_match and _match().has_method("debug_complete_objective"):
		_row(v, [
			["Complete objective", func() -> void:
				var mc := _match()
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
	_section(v, "Account")
	_row(v, [
		["+1,000 scrap", func() -> void: _scrap(1000)],
		["+10,000 scrap", func() -> void: _scrap(10000)],
	])
	_row(v, [
		["Unlock all tiers", _unlock_tiers],
		["Fast timers: %s" % ("ON" if GameState.fast_timers else "OFF"), func() -> void:
			GameState.fast_timers = not GameState.fast_timers
			_refresh()],
	])
	_row(v, [
		["FPS: %s" % ("ON" if _fps.visible else "OFF"), func() -> void:
			GameState.set_setting("show_fps", not _fps.visible)
			_refresh()],
		["Hide admin", func() -> void: set_enabled(false)],
	])
	_section(v, "Danger")
	var reset := _btn("Reset save (hold 2 s)", Color(0.8, 0.25, 0.2))
	var hold := {"t": 0.0}
	reset.button_down.connect(func() -> void: hold["t"] = Time.get_ticks_msec())
	reset.button_up.connect(func() -> void:
		if Time.get_ticks_msec() - float(hold["t"]) >= 2000.0:
			GameState.reset_profile()
			GameState.save_profile()
			_go(GameState.go_main_menu))
	v.add_child(reset)
	var close := _btn("CLOSE", Color(1.0, 0.75, 0.3))
	close.pressed.connect(close_panel)
	v.add_child(close)


func close_panel() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
		get_tree().paused = _was_paused


func _refresh() -> void:
	close_panel()
	open_panel()


func _section(v: VBoxContainer, t: String) -> void:
	var l := Label.new()
	l.text = t.to_upper()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55))
	v.add_child(l)


func _btn(t: String, col: Color = Color(0.9, 0.85, 0.75)) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", col)
	return b


func _row(v: VBoxContainer, items: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	for it in items:
		var b := _btn(str(it[0]))
		b.pressed.connect(it[1])
		h.add_child(b)


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


func _spawn(role: String) -> void:
	var mc := _match()
	if mc:
		mc.call("spawn_special", role)
	close_panel()


func _heal() -> void:
	var p := _player()
	if p:
		p.set("hp", float(p.get("max_hp")))


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
