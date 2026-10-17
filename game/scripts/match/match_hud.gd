extends CanvasLayer

## In-match HUD, built in code. Everything on screen explains itself:
##   top-left   – who you are, HP, ammo/reload, active buffs
##   top-center – current phase, timer, and one line telling you what to do
##   top-right  – Threat Level (+ what it costs/pays), minimap, run counters
##   center     – phase banners, toasts, extract progress
## Keeps the public API match_controller.gd expects.

const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")
const TouchControlsScene := preload("res://scenes/ui/touch_controls.tscn")
const MinimapScript = preload("res://scripts/ui/minimap.gd")
const ExtractArrowsScript = preload("res://scripts/ui/extract_arrows.gd")
const PauseMenuScript = preload("res://scripts/ui/pause_menu.gd")
const TutorialScript = preload("res://scripts/ui/tutorial_overlay.gd")
const ModeDefs = preload("res://scripts/data/mode_defs.gd")

var root: Control
var _match: Node = null
var _player: Node = null
var _touch_controls: CanvasLayer = null
var _minimap: Control = null
var _arrows: Control = null
var _pause: CanvasLayer = null
var tutorial: Control = null

## top-left
var _name_label: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _ammo_label: Label
var _reload_bar: ProgressBar
var _buff_row: HBoxContainer
var _ability_label: Label
## top-center
var _phase_card: PanelContainer
var _phase_label: Label
var _timer_label: Label
var _phase_hint: Label
var _phase_bar: ProgressBar
## top-right
var _threat_panel: PanelContainer
var _threat_label: Label
var _threat_sub: Label
var _counter_label: Label
## center
var _banner: Label
var _banner_sub: Label
var _toast_box: VBoxContainer
var _extract_prompt: Label
var _vignette: TextureRect
var _hint_label: Label

var _hp_ratio: float = 1.0
var _last_tl: int = 0
var _extract_open: bool = false
var _t: float = 0.0
var _hint_cycle_t: float = 0.0
var _hint_index: int = 0

const ROTATING_HINTS := [
	"Gold arrows on the screen edge point to extract pads.",
	"DASH makes you briefly invincible — dash through red bullets.",
	"Red wedge on an enemy = it's about to attack. Move or dash!",
	"Standing still tightens your aim. Moving widens it.",
	"Crates sometimes drop timed buffs. Shoot them open.",
	"Skipping an extract window raises Threat: tougher enemies, bigger payout.",
	"Standing on an open pad extracts you automatically.",
]


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build()
	get_viewport().size_changed.connect(_layout)


func setup(match_node: Node) -> void:
	_match = match_node
	_touch_controls = TouchControlsScene.instantiate()
	get_parent().add_child(_touch_controls)
	_pause = CanvasLayer.new()
	_pause.set_script(PauseMenuScript)
	get_parent().add_child(_pause)
	TouchInput.pause_pressed.connect(_open_pause)
	if not GameState.tutorial_done:
		tutorial = Control.new()
		tutorial.set_script(TutorialScript)
		root.add_child(tutorial)
		tutorial.call("setup", self)
	_layout()


func setup_nav(player: Node2D, pads: Array, landmarks: Array) -> void:
	_player = player
	var c: Dictionary = GameState.get_character()
	_name_label.text = str(c.get("display_name", "Wanderer")).to_upper()
	_name_label.add_theme_color_override("font_color", c.get("accent", UiTheme.AMBER))
	var ab: Dictionary = c.get("ability", {})
	_ability_label.text = ("%s — %s" % [ab.get("name", ""), ab.get("desc", "")]) if not ab.is_empty() else ""
	if player.has_signal("ammo_changed"):
		player.ammo_changed.connect(func(_a: int, _m: int, _r: bool) -> void: _refresh_ammo())
	if player.has_signal("ability_used"):
		player.ability_used.connect(func(n: String) -> void: show_toast(n + "!", UiTheme.AMBER))
	_minimap = Control.new()
	_minimap.set_script(MinimapScript)
	_minimap.custom_minimum_size = Vector2(150, 150)
	root.add_child(_minimap)
	_minimap.call("setup", player, pads, landmarks)
	_arrows = Control.new()
	_arrows.set_script(ExtractArrowsScript)
	root.add_child(_arrows)
	root.move_child(_arrows, 0)
	_arrows.call("setup", player, pads)
	for pad in pads:
		if pad.has_signal("channel_changed"):
			pad.channel_changed.connect(_on_channel)
	_refresh_ammo()
	on_health_changed(float(player.get("hp")), float(player.get("max_hp")))
	_layout()


## ---------------------------------------------------------------------------
## Build

func _panel(alpha: float = 0.78) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiTheme.box(Color(0.1, 0.075, 0.055, alpha), Color(0.42, 0.31, 0.19, 0.9), 14, 2, 12)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(text: String, size: int, color: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _build() -> void:
	## Low-HP vignette (behind everything)
	_vignette = TextureRect.new()
	_vignette.texture = _make_vignette()
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate = Color(1, 1, 1, 0)
	root.add_child(_vignette)

	## Top-left: vitals
	var vit := _panel()
	vit.name = "Vitals"
	root.add_child(vit)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vit.add_child(vb)
	_name_label = _label("WANDERER", 15, UiTheme.AMBER)
	vb.add_child(_name_label)
	var hp_row := Control.new()
	hp_row.custom_minimum_size = Vector2(230, 24)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hp_row)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_row.add_child(_hp_bar)
	_hp_text = _label("100 / 100", 14)
	_hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_row.add_child(_hp_text)
	_ammo_label = _label("24 / 24", 16)
	vb.add_child(_ammo_label)
	_reload_bar = ProgressBar.new()
	_reload_bar.custom_minimum_size = Vector2(230, 6)
	_reload_bar.show_percentage = false
	_reload_bar.max_value = 1.0
	_reload_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload_bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.AMBER, Color(0, 0, 0, 0), 3, 0, 0))
	_reload_bar.visible = false
	vb.add_child(_reload_bar)
	_ability_label = _label("", 11, UiTheme.TEXT_DIM)
	_ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ability_label.custom_minimum_size = Vector2(230, 0)
	vb.add_child(_ability_label)
	_buff_row = HBoxContainer.new()
	_buff_row.add_theme_constant_override("separation", 6)
	_buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_buff_row)

	## Top-center: phase card
	_phase_card = _panel(0.82)
	root.add_child(_phase_card)
	var pc := VBoxContainer.new()
	pc.add_theme_constant_override("separation", 0)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_card.add_child(pc)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(row)
	_phase_label = _label("LOCKOUT", 18, UiTheme.AMBER)
	row.add_child(_phase_label)
	_timer_label = _label("1:30", 32)
	row.add_child(_timer_label)
	_phase_bar = ProgressBar.new()
	_phase_bar.custom_minimum_size = Vector2(300, 5)
	_phase_bar.show_percentage = false
	_phase_bar.max_value = 1.0
	_phase_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(_phase_bar)
	_phase_hint = _label("", 13, UiTheme.TEXT_DIM)
	_phase_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(_phase_hint)

	## Top-right: threat + counters
	_threat_panel = _panel()
	root.add_child(_threat_panel)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_threat_panel.add_child(tv)
	_threat_label = _label("THREAT 0", 18, UiTheme.TEXT)
	_threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(_threat_label)
	_threat_sub = _label("payout ×1.00", 11, UiTheme.TEXT_DIM)
	_threat_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(_threat_sub)
	_counter_label = _label("", 13, UiTheme.AMBER)
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(_counter_label)

	## Center: banner + toasts + extract prompt
	_banner = _label("", 46, UiTheme.AMBER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_banner_sub = _label("", 18, UiTheme.TEXT)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.modulate.a = 0.0
	root.add_child(_banner_sub)
	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.add_theme_constant_override("separation", 4)
	root.add_child(_toast_box)
	_extract_prompt = _label("", 22, Color(0.5, 1.0, 0.65))
	_extract_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_extract_prompt)
	_hint_label = _label("", 13, Color(0.85, 0.78, 0.65, 0.8))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hint_label)


func _layout() -> void:
	if root == null:
		return
	var m := MobileLayout.control_safe_margin()
	var vp := get_viewport().get_visible_rect().size
	root.position = Vector2.ZERO
	root.size = vp
	_vignette.position = Vector2.ZERO
	_vignette.size = vp
	var vit := root.get_node("Vitals") as Control
	vit.position = m.position
	_phase_card.size = Vector2.ZERO
	_phase_card.reset_size()
	var pcs := _phase_card.get_combined_minimum_size()
	_phase_card.position = Vector2(vp.x * 0.5 - maxf(pcs.x, 340.0) * 0.5, m.position.y)
	_phase_card.custom_minimum_size = Vector2(340, 0)
	## Right column: pause button sits at the very corner (touch layer), so
	## the threat panel goes to its left and the minimap below.
	var right := m.position.x + m.size.x
	_threat_panel.reset_size()
	var tps := _threat_panel.get_combined_minimum_size()
	_threat_panel.custom_minimum_size = Vector2(170, 0)
	_threat_panel.position = Vector2(right - maxf(tps.x, 170.0) - 74.0, m.position.y)
	if _minimap:
		_minimap.size = Vector2(150, 150)
		_minimap.position = Vector2(right - 150.0, m.position.y + 84.0)
	_banner.position = Vector2(0, vp.y * 0.26)
	_banner.size = Vector2(vp.x, 60)
	_banner_sub.position = Vector2(0, vp.y * 0.26 + 58)
	_banner_sub.size = Vector2(vp.x, 30)
	_toast_box.position = Vector2(vp.x * 0.5 - 260, m.position.y + 104)
	_toast_box.size = Vector2(520, 120)
	_extract_prompt.position = Vector2(0, vp.y * 0.62)
	_extract_prompt.size = Vector2(vp.x, 34)
	_hint_label.position = Vector2(vp.x * 0.25, m.position.y + m.size.y - 22)
	_hint_label.size = Vector2(vp.x * 0.5, 20)


func _open_pause() -> void:
	if _pause and not get_tree().paused:
		_pause.call("open")


## ---------------------------------------------------------------------------
## Per-frame

func _process(delta: float) -> void:
	_t += delta
	if Input.is_action_just_pressed("pause_menu"):
		_open_pause()
	## Vignette pulses harder the lower you are.
	var low := clampf((0.45 - _hp_ratio) / 0.45, 0.0, 1.0)
	_vignette.modulate.a = low * (0.55 + 0.25 * sin(_t * (4.0 + low * 4.0)))
	if _player and is_instance_valid(_player) and _player.has_method("is_reloading"):
		var rel: bool = _player.call("is_reloading")
		_reload_bar.visible = rel
		if rel:
			_reload_bar.value = float(_player.call("get_reload_ratio"))
			_ammo_label.text = "RELOADING…"
	## Rotating tips (when the tutorial isn't talking)
	if GameState.settings.get("show_hints", true) and (tutorial == null or not is_instance_valid(tutorial)):
		_hint_cycle_t += delta
		if _hint_cycle_t > 9.0 or _hint_label.text == "":
			_hint_cycle_t = 0.0
			_hint_label.text = ROTATING_HINTS[_hint_index % ROTATING_HINTS.size()]
			_hint_index += 1
	else:
		_hint_label.text = ""
	## Buff timers tick visibly
	if _player and is_instance_valid(_player) and _player.has_method("get_active_buffs"):
		_refresh_buffs(_player.call("get_active_buffs"))


func update_match(phase: Dictionary, time_left: float, tl: int, stay: float, player: Node) -> void:
	_phase_label.text = str(phase.get("label", "")).to_upper()
	_timer_label.text = _fmt_time(time_left)
	var dur := float(phase.get("duration", 1.0))
	_phase_bar.value = 1.0 - time_left / maxf(dur, 0.01)
	var is_open := bool(phase.get("extract_open", false))
	var is_last := bool(phase.get("is_last", false))
	var urgent := time_left <= 10.0
	if is_open:
		_phase_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
		_phase_bar.add_theme_stylebox_override("fill", UiTheme.box(Color(0.45, 0.95, 0.55), Color(0, 0, 0, 0), 3, 0, 0))
		if is_last:
			_phase_hint.text = "LAST CHANCE — reach a gold pad or you're wiped"
		elif urgent:
			_phase_hint.text = "Closing! Leave now, or stay for Threat +1 & bigger payout"
		else:
			_phase_hint.text = "Extract OPEN — stand on a gold pad to leave"
	else:
		_phase_label.add_theme_color_override("font_color", UiTheme.AMBER)
		_phase_bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.AMBER, Color(0, 0, 0, 0), 3, 0, 0))
		var pid := str(phase.get("id", ""))
		if pid == "lockout":
			_phase_hint.text = "Survive & loot — extracts open when the timer hits 0"
		elif pid == "final_seal":
			_phase_hint.text = "Final seal — head toward a pad for the Last Extract"
		else:
			_phase_hint.text = "Sealed — next window opens when the timer hits 0"
	_timer_label.add_theme_color_override("font_color", UiTheme.DANGER if urgent and (is_open or is_last) else UiTheme.TEXT)
	if urgent:
		var p := 1.0 + 0.06 * absf(sin(_t * 6.0))
		_timer_label.pivot_offset = _timer_label.size * 0.5
		_timer_label.scale = Vector2(p, p)
	else:
		_timer_label.scale = Vector2.ONE
	## Threat
	var tlt := ModeDefs.tl_table(tl)
	_threat_label.text = "THREAT %d" % tl
	var tl_col: Color = [UiTheme.TEXT, UiTheme.AMBER, UiTheme.RUST, UiTheme.DANGER][clampi(tl, 0, 3)]
	_threat_label.add_theme_color_override("font_color", tl_col)
	_threat_sub.text = "enemies +%d%% · payout ×%.2f" % [int((float(tlt["hp"]) - 1.0) * 100.0), float(tlt["payout"])]
	if tl != _last_tl:
		_last_tl = tl
		_pulse(_threat_panel)
	_counter_label.text = "Scrap %d · Kills %d · Stay ×%.2f" % [GameState.scrap_found, GameState.kills, stay]
	if player and is_instance_valid(player) and not bool(player.call("is_reloading")):
		_refresh_ammo()


func _refresh_ammo() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if bool(_player.call("is_reloading")):
		return
	var a: int = _player.call("get_ammo")
	var m: int = _player.call("get_mag_size")
	_ammo_label.text = "AMMO  %d / %d" % [a, m]
	_ammo_label.add_theme_color_override("font_color", UiTheme.DANGER if a <= m / 5 else UiTheme.TEXT)


func set_extract_open(is_open: bool) -> void:
	if is_open != _extract_open:
		_extract_open = is_open
	if _minimap and _minimap.has_method("set_extract_open"):
		_minimap.set_extract_open(is_open)
	if _arrows and _arrows.has_method("set_extract_open"):
		_arrows.set_extract_open(is_open)


func _on_channel(ratio: float) -> void:
	if ratio > 0.01:
		_extract_prompt.text = "EXTRACTING… %d%%  — stay on the pad" % int(ratio * 100.0)
	else:
		_extract_prompt.text = ""


func on_health_changed(current: float, maximum: float) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_ratio = current / maxf(maximum, 1.0)
	_hp_text.text = "%d / %d" % [int(ceil(maxf(current, 0.0))), int(maximum)]
	var col := UiTheme.TEAL
	if _hp_ratio < 0.3:
		col = UiTheme.DANGER
	elif _hp_ratio < 0.6:
		col = UiTheme.AMBER
	_hp_bar.add_theme_stylebox_override("fill", UiTheme.box(col, Color(0, 0, 0, 0), 6, 0, 0))


func on_buffs_changed(buffs: Dictionary) -> void:
	_refresh_buffs(buffs)


func _refresh_buffs(buffs: Dictionary) -> void:
	var want := buffs.size()
	while _buff_row.get_child_count() > want:
		var c := _buff_row.get_child(_buff_row.get_child_count() - 1)
		_buff_row.remove_child(c)
		c.queue_free()
	while _buff_row.get_child_count() < want:
		var chip := _label("", 12)
		var sb := UiTheme.box(Color(0.1, 0.08, 0.06, 0.9), UiTheme.AMBER, 8, 2, 6)
		chip.add_theme_stylebox_override("normal", sb)
		_buff_row.add_child(chip)
	var i := 0
	for id in buffs.keys():
		var entry: Dictionary = buffs[id]
		var def: Dictionary = entry.get("def", {})
		var chip := _buff_row.get_child(i) as Label
		chip.text = "%s %ds" % [str(def.get("name", id)), int(ceil(float(entry.get("time_left", 0))))]
		chip.add_theme_color_override("font_color", def.get("color", UiTheme.AMBER))
		i += 1


## ---------------------------------------------------------------------------
## Messages

func show_banner(title: String, sub: String = "", color: Color = UiTheme.AMBER) -> void:
	_banner.text = title
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = sub
	_banner.pivot_offset = Vector2(_banner.size.x * 0.5, 30)
	_banner.scale = Vector2(1.4, 1.4)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.15)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_banner_sub, "modulate:a", 1.0, 0.25).set_delay(0.1)
	tw.chain().tween_interval(1.8)
	tw.chain().set_parallel(true)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)
	tw.tween_property(_banner_sub, "modulate:a", 0.0, 0.4)


func show_toast(msg: String, color: Color = UiTheme.TEXT) -> void:
	var l := _label(msg, 17, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	l.modulate.a = 0.0
	_toast_box.add_child(l)
	while _toast_box.get_child_count() > 3:
		_toast_box.get_child(0).queue_free()
		_toast_box.remove_child(_toast_box.get_child(0))
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	tw.tween_interval(3.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _pulse(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.15, 1.15), 0.1)
	tw.tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _fmt_time(seconds: float) -> String:
	var s := maxi(0, int(ceil(seconds)))
	return "%d:%02d" % [s / 60, s % 60]


func _make_vignette() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.7, 0.05, 0.03, 0.0))
	g.set_color(1, Color(0.7, 0.05, 0.03, 0.85))
	g.add_point(0.55, Color(0.7, 0.05, 0.03, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	return tex
