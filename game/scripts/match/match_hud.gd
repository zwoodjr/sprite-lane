extends CanvasLayer

## In-match HUD, built in code. Everything on screen explains itself:
##   top-left   – who you are, HP, ammo/reload, active buffs
##   top-center – current phase, timer, and one line telling you what to do
##   top-right  – Threat Level (+ what it costs/pays), minimap, run counters
##   center     – phase banners, toasts, extract progress
## Keeps the public API match_controller.gd expects.

const TouchControlsScene := preload("res://scenes/ui/touch_controls.tscn")
const MinimapScript = preload("res://scripts/ui/minimap.gd")
const ExtractArrowsScript = preload("res://scripts/ui/extract_arrows.gd")
const PauseMenuScript = preload("res://scripts/ui/pause_menu.gd")
const TutorialScript = preload("res://scripts/ui/tutorial_overlay.gd")
const EnemyArrowsScript = preload("res://scripts/ui/enemy_arrows.gd")
const ExtractBarScript = preload("res://scripts/ui/extract_bar.gd")
const BossBarScript = preload("res://scripts/ui/boss_bar.gd")
## Top-left bar art (HD pack): frame 360×36, fills 348×24 inset 6 px.
const BAR_FRAME := "res://assets/sprites/ui/hud_bar_frame.png"
const BAR_HP := "res://assets/sprites/ui/hud_bar_fill_health.png"
const BAR_XP := "res://assets/sprites/ui/hud_bar_fill_xp.png"
const BAR_W := 200.0 ## on-screen width of the slim bars
## Compact HUD (playtest feedback): slim bars, big minimap top-right with the loot
## panel under it, a slim phase strip at the top centre, hints that fade.
const HP_BAR_H := 15.0
const XP_BAR_H := 7.0
const MAP_SIZE := 135.0 ## +30% (icons, rim markers)
## Visual tier slim HUD: PressStart2P pixel text, no plates behind the readouts.
const PIXEL_FONT := "res://assets/fonts/PressStart2P.ttf"
const XpLineScript := preload("res://scripts/ui/xp_line.gd")
const PANEL_ALPHA := 0.5
const HINT_SHOW := 4.0
const SHOW_COMBAT_TIPS := false
## Locked "smashed readout" bars (scripts/ui/readout_bar.gd).
const ReadoutScript := preload("res://scripts/ui/readout_bar.gd")
const HP_READOUT := Vector2(300, 48)
const XP_READOUT := Vector2(232, 24)
var root: Control
var _match: Node = null
var _player: Node = null
var _touch_controls: CanvasLayer = null
var _minimap: Control = null
var _arrows: Control = null
var _pause: CanvasLayer = null
var tutorial: Control = null

## top-left
var _hp_bar: TextureProgressBar
var _hp_text: Label
var _ammo_label: Label
var _reload_bar: ProgressBar
var _buff_row: HBoxContainer
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
var _run_level_label: Label
var _run_xp_bar: TextureProgressBar
var _enemy_arrows: Control = null
var _extract_bar: Control = null
var _hit_flash: TextureRect
var _boss_bar: Control
var _white_flash: ColorRect
## center
var _banner: Label
var _banner_sub: Label
var _toast_box: VBoxContainer
var _extract_prompt: Label
var _vignette: TextureRect
var _hint_label: Label
## Depth Update E1: backpack, medicine, plague exposure, tonics drunk.
var _pack_row: HBoxContainer
var _pack_label: Label
var _med_icon: TextureRect
var _med_label: Label
var _tonic_row: HBoxContainer
var _pouch_row: HBoxContainer
var _pouch_labels: Dictionary = {}
var _expo_box: VBoxContainer
## Depth E7 zone row: bunker keys · power cell · air filter · flare.
var _zone_row: HBoxContainer
var _zone_bits: Dictionary = {}
var _expo_label: Label
var _expo_bar: ProgressBar
var _expo_col: Color = Color(0.55, 0.85, 0.35)
## E4: radio jobs / stay stakes under the phase card.
var _jobs_label: Label

var _hp_ratio: float = 1.0
var _last_tl: int = 0
var _extract_open: bool = false
var _t: float = 0.0
var _hint_cycle_t: float = 0.0
var _pack_panel: PanelContainer
var _hp_readout: Control
var _xp_readout: Control
var _hint_index: int = 0
var _pixel: Font = null
var _xp_line: Control = null
var _run_lv: int = 1
var _phase_id: String = ""
var _phase_shown_t: float = 0.0

const ROTATING_HINTS := [
	"Gold arrows on the screen edge point to extract pads.",
	"DASH makes you briefly invincible — dash through red bullets.",
	"Red ring on the ground = an attack is coming. Move or dash!",
	"Your hero attacks the closest enemy in range — just steer.",
	"Crates sometimes drop timed buffs. Shoot them open.",
	"Loot climbs ×0.1 every 30s you stay — and so does Threat.",
	"Hold an open pad for 3s to extract. Getting hit resets it.",
]

func _ready() -> void:
	layer = 10
	add_to_group("hud")
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
	_ammo_label.visible = not bool(player.call("is_melee"))
	if player.has_signal("hurt"):
		player.hurt.connect(func(_a: float) -> void: _flash_hit())
	if player.has_signal("ammo_changed"):
		player.ammo_changed.connect(func(_a: int, _m: int, _r: bool) -> void: _refresh_ammo())
	if player.has_signal("ability_used"):
		player.ability_used.connect(func(n: String) -> void: show_toast(n + "!", UiTheme.AMBER))
	_minimap = Control.new()
	_minimap.set_script(MinimapScript)
	root.add_child(_minimap)
	_minimap.call("setup", player, pads, landmarks)
	_enemy_arrows = Control.new()
	_enemy_arrows.set_script(EnemyArrowsScript)
	root.add_child(_enemy_arrows)
	root.move_child(_enemy_arrows, 1)
	_enemy_arrows.call("setup", player)
	_extract_bar = Control.new()
	_extract_bar.set_script(ExtractBarScript)
	root.add_child(_extract_bar)
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
	## Slim riveted brass HUD plate (smoky see-through face).
	var sb := UiTheme.plate("hud", 12.0, Color(1, 1, 1, clampf(alpha + 0.14, 0.0, 1.0)))
	p.add_theme_stylebox_override("panel", sb)
	return p

## Small caps caption over a bar ("HEALTH", "XP · LV 3").
func _caption(text: String) -> Label:
	var l := _label(text, 13, UiTheme.TEXT_DIM)
	l.add_theme_font_override("font", UiTheme.font_button)
	return l

## Pixel-font HUD text (PressStart2P) with a dark outline so it reads on any ground.
## Only for numbers / short caps, and only at multiples of 8 px (the face's grid)
## so its pixels stay square: 8 for small tags, 16 for the readouts.
func _px(text: String, size: int, color: Color = UiTheme.TEXT) -> Label:
	size = maxi(8, int(round(float(size) / 8.0)) * 8)
	var l := _label(text, size, color)
	if _pixel == null and ResourceLoader.exists(PIXEL_FONT):
		_pixel = load(PIXEL_FONT)
	if _pixel:
		l.add_theme_font_override("font", _pixel)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.9))
	return l

func _label(text: String, size: int, color: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## Framed texture bar scaled to BAR_W (art is 360×36 with a 6 px inset fill).
func _tex_bar(fill_path: String) -> TextureProgressBar:
	var t := TextureProgressBar.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture_under = load(BAR_FRAME)
	t.texture_progress = load(fill_path)
	t.texture_progress_offset = Vector2(6, 6)
	t.step = 0.0
	t.scale = Vector2.ONE * (BAR_W / 360.0)
	return t

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
	var vit := _panel(PANEL_ALPHA)
	vit.name = "Vitals"
	## The readouts carry their own housings — no plate behind them.
	vit.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(vit)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vit.add_child(vb)
	vb.add_theme_constant_override("separation", 2)
	_hp_readout = _readout("hp", "HP", HP_READOUT)
	vb.add_child(_hp_readout)
	_xp_readout = _readout("xp", "LV", XP_READOUT)
	_xp_readout.visible = false
	vb.add_child(_xp_readout)
	_xp_line = Control.new()
	_xp_line.set_script(XpLineScript)
	_xp_line.custom_minimum_size = Vector2(HP_READOUT.x - 20.0, 10)
	vb.add_child(_xp_line)
	var hp_row := Control.new()
	hp_row.visible = false
	hp_row.custom_minimum_size = Vector2(BAR_W, HP_BAR_H)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hp_row)
	_hp_bar = _tex_bar(BAR_HP)
	_hp_bar.scale = Vector2(BAR_W / 360.0, HP_BAR_H / 36.0)
	hp_row.add_child(_hp_bar)
	_hp_text = _label("100 / 100", 11)
	_hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text.add_theme_constant_override("outline_size", 4)
	_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hp_row.add_child(_hp_text)
	var xp_line := HBoxContainer.new()
	xp_line.visible = false
	xp_line.add_theme_constant_override("separation", 5)
	xp_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(xp_line)
	_run_level_label = _caption("LV 1")
	_run_level_label.add_theme_font_size_override("font_size", 11)
	_run_level_label.custom_minimum_size = Vector2(34, 0)
	xp_line.add_child(_run_level_label)
	var xp_row := Control.new()
	xp_row.custom_minimum_size = Vector2(BAR_W - 39.0, XP_BAR_H)
	xp_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_line.add_child(xp_row)
	_run_xp_bar = _tex_bar(BAR_XP)
	_run_xp_bar.scale = Vector2((BAR_W - 39.0) / 360.0, XP_BAR_H / 36.0)
	_run_xp_bar.max_value = 1.0
	_run_xp_bar.step = 0.0
	xp_row.add_child(_run_xp_bar)
	## Ammo / reload now live on the arc beside the hero (player.gd AmmoArc);
	## this line only appears for the Hot Barrel heat gauge.
	_ammo_label = _px("", 8, UiTheme.TEXT_DIM)
	_ammo_label.visible = false
	vb.add_child(_ammo_label)
	_reload_bar = ProgressBar.new()
	_reload_bar.custom_minimum_size = Vector2(BAR_W, 5)
	_reload_bar.show_percentage = false
	_reload_bar.max_value = 1.0
	_reload_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload_bar.custom_minimum_size = Vector2(BAR_W, 8)
	UiTheme.skin_bar(_reload_bar, UiTheme.AMBER)
	## Reload progress is folded into the ammo line (no separate bar).
	_reload_bar.visible = false
	_buff_row = HBoxContainer.new()
	_buff_row.add_theme_constant_override("separation", 6)
	_buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_buff_row)
	## Pack / pouch / plague: a compact chip right under the vitals block.
	_pack_panel = _panel(PANEL_ALPHA)
	_pack_panel.name = "PackChip"
	_pack_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(_pack_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pack_panel.add_child(pv)
	_build_depth(pv)

	## Top-center: phase card
	_phase_card = _panel(0.35)
	_phase_card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
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
	row.add_theme_constant_override("separation", 10)
	_phase_label = _label("EXTRACT IN", 24, UiTheme.AMBER)
	_phase_label.add_theme_font_override("font", UiTheme.font_display)
	_phase_label.add_theme_constant_override("outline_size", 6)
	_phase_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.9))
	row.add_child(_phase_label)
	_timer_label = _px("1:30", 16, Color(0.94, 0.8, 0.5))
	row.add_child(_timer_label)
	_phase_bar = ProgressBar.new()
	_phase_bar.visible = false
	_phase_bar.custom_minimum_size = Vector2(120, 4)
	UiTheme.skin_bar(_phase_bar, UiTheme.AMBER)
	_phase_bar.show_percentage = false
	_phase_bar.max_value = 1.0
	_phase_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(_phase_bar)
	var tick_gap := Control.new()
	tick_gap.custom_minimum_size = Vector2(0, 16)
	tick_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(tick_gap)
	_phase_hint = _label("", 16, Color(0.86, 0.8, 0.68))
	_phase_hint.visible = false
	_phase_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_phase_hint.clip_text = true
	_phase_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(_phase_hint)
	_jobs_label = _label("", 16, RadioDefs.MAP_COLOR)
	_jobs_label.add_theme_constant_override("outline_size", 5)
	_jobs_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.9))
	_jobs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_jobs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_jobs_label.visible = false
	pc.add_child(_jobs_label)

	## Top-right: threat + counters
	_threat_panel = _panel(PANEL_ALPHA)
	_threat_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(_threat_panel)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_threat_panel.add_child(tv)
	_threat_label = _label("LOOT ×1.0", 28, UiTheme.AMBER)
	_threat_label.add_theme_font_override("font", UiTheme.font_display)
	_threat_label.add_theme_constant_override("outline_size", 6)
	_threat_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.9))
	_threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(_threat_label)
	## Threat / bag / kills moved off the combat HUD (pause menu + results);
	## the LOOT colour already warms with Threat.
	_threat_sub = _px("", 8, UiTheme.TEXT_DIM)
	_threat_sub.visible = false
	_threat_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(_threat_sub)
	_counter_label = _px("", 8, Color(0.86, 0.75, 0.52, 0.85))
	_counter_label.visible = false
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(_counter_label)

	## Center: banner + toasts + extract prompt
	_banner = _label("", 52, UiTheme.AMBER)
	_banner.add_theme_font_override("font", UiTheme.font_display)
	_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_banner.add_theme_constant_override("shadow_offset_y", 4)
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
	_extract_prompt = _label("", 26, Color(0.5, 1.0, 0.65))
	_extract_prompt.add_theme_font_override("font", UiTheme.font_display)
	_extract_prompt.add_theme_constant_override("outline_size", 6)
	_extract_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_extract_prompt)
	_hint_label = _label("", 11, Color(0.85, 0.78, 0.65, 0.75))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hint_label)
	## Red screen-edge flash when the hero takes a hit.
	_hit_flash = TextureRect.new()
	_hit_flash.texture = _make_vignette()
	_hit_flash.stretch_mode = TextureRect.STRETCH_SCALE
	_hit_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_flash.modulate = Color(1.3, 1, 1, 0)
	root.add_child(_hit_flash)
	_boss_bar = Control.new()
	_boss_bar.name = "BossBar"
	_boss_bar.set_script(BossBarScript)
	root.add_child(_boss_bar)
	_white_flash = ColorRect.new()
	_white_flash.color = Color(1.0, 0.95, 0.88, 0.0)
	_white_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_white_flash)

func _layout() -> void:
	if root == null:
		return
	var m := MobileLayout.control_safe_margin()
	var vp := get_viewport().get_visible_rect().size
	root.position = Vector2.ZERO
	root.size = vp
	_vignette.position = Vector2.ZERO
	_vignette.size = vp
	_hit_flash.position = Vector2.ZERO
	_hit_flash.size = vp
	_white_flash.position = Vector2.ZERO
	_white_flash.size = vp
	## Top-left: slim vitals, the pack chip right under it.
	var vit := root.get_node("Vitals") as Control
	vit.position = m.position
	vit.reset_size()
	if _pack_panel:
		_pack_panel.position = Vector2(m.position.x, m.position.y + vit.size.y + 4.0)
		_pack_panel.reset_size()
	## Top-right: a big minimap, the loot / threat panel under it.
	var right := m.position.x + m.size.x
	var map_s := minf(MAP_SIZE, vp.x * 0.3)
	if _minimap:
		_minimap.custom_minimum_size = Vector2(map_s, map_s)
		_minimap.size = Vector2(map_s, map_s)
		_minimap.position = Vector2(right - map_s, m.position.y)
	_threat_panel.custom_minimum_size = Vector2(map_s, 0)
	_threat_panel.reset_size()
	## Clear of the minimap's SEALED / OPEN plate on its lower rim (they touched at 720x1560).
	_threat_panel.position = Vector2(right - _threat_panel.size.x, m.position.y + map_s + 12.0)
	## Top-centre: a slim phase strip between the two corners.
	var left_w := vit.size.x + 8.0
	## Slim HUD: the extract readout sits centred in the gap between the vitals
	## and the minimap (not the screen centre), so long hints fit on one line.
	var gap_l := m.position.x + left_w
	var gap_r := right - map_s - 8.0
	var phase_w := clampf(gap_r - gap_l, 150.0, 340.0)
	_phase_card.custom_minimum_size = Vector2(phase_w, 0)
	_phase_hint.custom_minimum_size = Vector2(phase_w - 20.0, 0)
	if _jobs_label:
		_jobs_label.custom_minimum_size = Vector2(phase_w - 20.0, 0)
	_phase_bar.custom_minimum_size = Vector2(phase_w - 24.0, 4)
	_phase_card.reset_size()
	var phase_cx := (gap_l + gap_r) * 0.5
	_phase_card.position = Vector2(phase_cx - _phase_card.size.x * 0.5, m.position.y + 2.0)
	if _extract_bar:
		var tw := minf(220.0, phase_w - 20.0)
		_extract_bar.size = Vector2(tw, 8)
		## Under the "EXTRACT IN 0:53" row (it used to cut through the words).
		_extract_bar.position = Vector2(phase_cx - tw * 0.5, m.position.y + 36.0)
	if _boss_bar:
		## Under the extract strip, between the vitals and the minimap columns.
		var bw := clampf(vp.x - 2.0 * (map_s + m.position.x + 12.0), 220.0, 420.0)
		_boss_bar.size = Vector2(bw, 44)
		_boss_bar.position = Vector2(vp.x * 0.5 - bw * 0.5, m.position.y + 74.0)
	var below := maxf(_threat_panel.position.y + _threat_panel.size.y, m.position.y + vit.size.y + 60.0) + 10.0
	below = maxf(below, _phase_card.position.y + _phase_card.size.y + 54.0)
	_banner.position = Vector2(0, vp.y * 0.26)
	_banner.size = Vector2(vp.x, 60)
	_banner_sub.position = Vector2(0, vp.y * 0.26 + 58)
	_banner_sub.size = Vector2(vp.x, 30)
	var toast_w := minf(520.0, vp.x - 40.0)
	_toast_box.position = Vector2(vp.x * 0.5 - toast_w * 0.5, below)
	_toast_box.size = Vector2(toast_w, 120)
	_extract_prompt.position = Vector2(0, vp.y * 0.58)
	_extract_prompt.size = Vector2(vp.x, 34)
	_hint_label.position = Vector2(vp.x * 0.1, m.position.y + m.size.y - 22)
	_hint_label.size = Vector2(vp.x * 0.8, 20)

## Pack (weight / room), medicine count, tonics drunk, plague exposure meter.
func _build_depth(vb: VBoxContainer) -> void:
	_pack_row = HBoxContainer.new()
	_pack_row.add_theme_constant_override("separation", 4)
	_pack_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_pack_row)
	## PACK only shows once the pack is nearly full (it's the only time it matters).
	_pack_label = _label("PACK 0/8", 18, Color(0.86, 0.75, 0.52))
	_pack_label.add_theme_font_override("font", UiTheme.font_button)
	_pack_label.add_theme_constant_override("outline_size", 5)
	_pack_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.9))
	_pack_label.visible = false
	_pack_row.add_child(_pack_label)
	_med_icon = _icon(MedicineDefs.icon_path("medicine"), 18)
	_med_icon.visible = false
	_pack_row.add_child(_med_icon)
	_med_label = _px("", 8, Color(1.0, 0.55, 0.5))
	_pack_row.add_child(_med_label)
	_tonic_row = HBoxContainer.new()
	_tonic_row.add_theme_constant_override("separation", 2)
	_tonic_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pack_row.add_child(_tonic_row)
	## Weightless ingredient pouch: icon + count per ingredient (hidden until found).
	_pouch_row = HBoxContainer.new()
	_pouch_row.add_theme_constant_override("separation", 3)
	_pouch_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pouch_row.visible = false
	vb.add_child(_pouch_row)
	for id in MedicineDefs.INGREDIENT_IDS:
		var ic := _icon(MedicineDefs.icon_path(str(id)), 18)
		ic.visible = false
		_pouch_row.add_child(ic)
		var l := _label("", 13, UiTheme.TEXT)
		l.add_theme_font_override("font", UiTheme.font_button)
		l.visible = false
		_pouch_row.add_child(l)
		_pouch_labels[id] = [ic, l]
	_zone_row = HBoxContainer.new()
	_zone_row.add_theme_constant_override("separation", 4)
	_zone_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_row.visible = false
	vb.add_child(_zone_row)
	for zk in ["key", "power_cell", "filter", "flare"]:
		var zi := _icon("res://assets/sprites/depth/icons/zone_%s.png" % zk, 18)
		zi.visible = false
		_zone_row.add_child(zi)
		var zl := _label("", 13, UiTheme.TEXT)
		zl.add_theme_font_override("font", UiTheme.font_button)
		zl.visible = false
		_zone_row.add_child(zl)
		_zone_bits[zk] = [zi, zl]
	_expo_box = VBoxContainer.new()
	_expo_box.add_theme_constant_override("separation", 2)
	_expo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expo_box.visible = false
	vb.add_child(_expo_box)
	var er := HBoxContainer.new()
	er.add_theme_constant_override("separation", 4)
	er.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expo_box.add_child(er)
	er.add_child(_icon(MedicineDefs.icon_path("exposure"), 18))
	_expo_label = _caption("PLAGUE 0%")
	_expo_label.add_theme_color_override("font_color", _expo_col)
	er.add_child(_expo_label)
	_expo_bar = ProgressBar.new()
	_expo_bar.custom_minimum_size = Vector2(BAR_W, 8)
	_expo_bar.show_percentage = false
	_expo_bar.max_value = MedicineDefs.EXPOSURE_MAX
	_expo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.skin_bar(_expo_bar, _expo_col)
	_expo_box.add_child(_expo_bar)

func _icon(path: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(path):
		t.texture = load(path)
	return t

func set_jobs(lines: PackedStringArray) -> void:
	if _jobs_label == null:
		return
	## One objective line at a time (the most urgent comes first); the rest
	## live on the minimap and in the pause menu.
	var txt := lines[0] if lines.size() > 0 else ""
	if _jobs_label.text != txt:
		_jobs_label.text = txt
		_jobs_label.visible = txt != ""
		_phase_card.reset_size()

func set_pack(weight: int, cap: int, medicine: int) -> void:
	if _pack_label == null:
		return
	var txt := ("PACK FULL" if weight >= cap else "PACK %d/%d") % ([] if weight >= cap else [weight, cap])
	_pack_label.visible = cap > 0 and float(weight) >= float(cap) * 0.75
	if _pack_label.text != txt:
		_pack_label.text = txt
		_pack_label.add_theme_color_override("font_color", UiTheme.RUST if weight >= cap else Color(0.86, 0.75, 0.52))
		_pack_label.set_meta("pack", Vector2i(weight, cap))
	_med_icon.visible = medicine > 0
	_med_label.text = "×%d" % medicine if medicine > 0 else ""
	var pouch := GameState.pouch()
	_pouch_row.visible = not pouch.is_empty()
	for id in _pouch_labels.keys():
		var n := int(pouch.get(id, 0))
		var pair: Array = _pouch_labels[id]
		(pair[0] as Control).visible = n > 0
		(pair[1] as Label).visible = n > 0
		(pair[1] as Label).text = "%d" % n

## Zone run state (Depth E7). filter < 0 / flare <= 0 hide those bits.
func set_zone(keys: int, cell: bool, filter: float, flare: float) -> void:
	if _zone_row == null:
		return
	var vals := {"key": "%d" % keys if keys > 0 else "", "power_cell": "CELL" if cell else "",
		"filter": "AIR %d%%" % int(ceil(filter)) if filter >= 0.0 else "", "flare": "%ds" % int(ceil(flare)) if flare > 0.0 else ""}
	var any := false
	for zk in _zone_bits.keys():
		var pair: Array = _zone_bits[zk]
		var on := str(vals[zk]) != ""
		any = any or on
		(pair[0] as Control).visible = on
		(pair[1] as Label).visible = on
		(pair[1] as Label).text = str(vals[zk])
		if zk == "filter" and on:
			(pair[1] as Label).add_theme_color_override("font_color", UiTheme.DANGER if filter < 20.0 else UiTheme.TEXT)
	_zone_row.visible = any

func set_tonics(ids: Array) -> void:
	if _tonic_row == null:
		return
	for c in _tonic_row.get_children():
		c.queue_free()
	for t in ids:
		_tonic_row.add_child(_icon(MedicineDefs.icon_path(str(t)), 20))

func set_exposure(v: float, stage: int) -> void:
	if _expo_box == null:
		return
	_expo_box.visible = true
	_expo_bar.value = v
	var nm := "" if stage < 0 else " · " + str(MedicineDefs.STAGES[stage]["name"]).to_upper()
	_expo_label.text = "PLAGUE %d%%%s" % [int(round(v)), nm]
	var col := _expo_col if stage < 1 else (Color(0.9, 0.85, 0.3) if stage == 1 else UiTheme.DANGER)
	if _expo_bar.get_meta("c", Color.BLACK) != col:
		_expo_bar.set_meta("c", col)
		UiTheme.skin_bar(_expo_bar, col)
		_expo_label.add_theme_color_override("font_color", col)

func _readout(kind: String, label: String, sz: Vector2) -> Control:
	var c := Control.new()
	c.set_script(ReadoutScript)
	c.set("kind", kind)
	c.set("label_text", label)
	c.custom_minimum_size = sz
	return c

func _flash_hit() -> void:
	if _hit_flash == null:
		return
	_hit_flash.modulate.a = 0.85
	var tw := _hit_flash.create_tween()
	tw.tween_property(_hit_flash, "modulate:a", 0.0, 0.35)

func _open_pause() -> void:
	if _pause == null or get_tree().paused:
		return
	if _match and is_instance_valid(_match) and _match.has_method("is_run_over") and bool(_match.call("is_run_over")):
		return
	_pause.call("open")

func open_pause() -> void:
	_open_pause()

## ---------------------------------------------------------------------------
## Per-frame

func _process(delta: float) -> void:
	_t += delta
	## Keep the pack chip glued under the vitals (buff chips can grow them).
	if _pack_panel and root:
		var vit := root.get_node("Vitals") as Control
		_pack_panel.position.y = vit.position.y + vit.size.y + 4.0
	if Input.is_action_just_pressed("pause_menu"):
		_open_pause()
	## Vignette pulses harder the lower you are.
	## Low HP is an edge pulse only (audit: the full-screen red flood hid the fight).
	var low := clampf((0.4 - _hp_ratio) / 0.4, 0.0, 1.0)
	_vignette.modulate.a = low * (0.5 + 0.5 * sin(_t * (4.0 + low * 4.0))) * 0.6
	if _player and is_instance_valid(_player) and _player.has_method("is_reloading"):
		var rel: bool = _player.call("is_reloading")
		if rel:
			_ammo_label.text = ""
		## Hot Barrel quirk: no magazine — the ammo line becomes a heat gauge.
		if GameState.quirk_fx("no_reload") > 0.0 and _player.has_method("heat_ratio") and not bool(_player.call("is_melee")):
			var hr := float(_player.call("heat_ratio"))
			var over: bool = _player.get("_overheat_left") > 0.0
			var cells := int(round(hr * 10.0))
			_ammo_label.text = ("OVERHEAT " if over else "HEAT ") + "|".repeat(cells) + ".".repeat(10 - cells)
			_ammo_label.visible = true
			_ammo_label.add_theme_color_override("font_color", UiTheme.DANGER if over or hr > 0.8 else (UiTheme.AMBER if hr > 0.5 else UiTheme.TEXT))
	_phase_shown_t += delta
	if _phase_hint:
		_phase_hint.modulate.a = clampf((6.0 - _phase_shown_t) / 0.8, 0.0, 1.0)
	## Rotating tips (when the tutorial isn't talking)
	## Rotating tip bar removed from combat (audit: text wall); tips live in
	## the tutorial and How to Play.
	if SHOW_COMBAT_TIPS:
		_hint_cycle_t += delta
		if _hint_cycle_t > 14.0 or _hint_label.text == "":
			_hint_cycle_t = 0.0
			_hint_label.text = ROTATING_HINTS[_hint_index % ROTATING_HINTS.size()]
			_hint_index += 1
		## Each hint shows briefly, then fades away until the next one.
		_hint_label.modulate.a = clampf((HINT_SHOW - _hint_cycle_t) / 0.8, 0.0, 1.0)
	else:
		_hint_label.text = ""
	## Buff timers tick visibly
	if _player and is_instance_valid(_player) and _player.has_method("get_active_buffs"):
		_refresh_buffs(_player.call("get_active_buffs"))

func set_schedule(phases: Array) -> void:
	if _extract_bar:
		_extract_bar.call("set_schedule", phases)

func set_schedule_clock(elapsed: float) -> void:
	if _extract_bar:
		_extract_bar.call("set_clock", elapsed)

## New pads were placed (10 s before a window): pulse the minimap.
func ping_pads() -> void:
	if _minimap and _minimap.has_method("ping"):
		_minimap.call("ping")

func update_match(phase: Dictionary, time_left: float, tl: int, loot: float, player: Node) -> void:
	var is_open0 := bool(phase.get("extract_open", false))
	var is_last0 := bool(phase.get("is_last", false))
	_phase_label.text = "LAST CHANCE" if is_last0 else ("EXTRACT OPEN" if is_open0 else "EXTRACT IN")
	_timer_label.text = _fmt_time(time_left)
	var pid0 := str(phase.get("id", ""))
	if pid0 != _phase_id:
		_phase_id = pid0
		_phase_shown_t = 0.0
	var dur := float(phase.get("duration", 1.0))
	_phase_bar.value = 1.0 - time_left / maxf(dur, 0.01)
	var is_open := bool(phase.get("extract_open", false))
	var is_last := bool(phase.get("is_last", false))
	var urgent := time_left <= 10.0
	if is_open:
		var oc := UiTheme.DANGER if is_last else Color(0.55, 1.0, 0.6)
		_phase_label.add_theme_color_override("font_color", oc)
		if _phase_bar.get_meta("fill_col", Color.BLACK) != oc:
			_phase_bar.set_meta("fill_col", oc)
			UiTheme.skin_bar(_phase_bar, oc)
		if is_last:
			_phase_hint.text = "Reach a red pad before the storm"
		elif urgent:
			_phase_hint.text = "Closing! Leave at ×%.1f or stay" % loot
		else:
			_phase_hint.text = "Hold a pad 3s to leave at ×%.1f" % loot
	else:
		_phase_label.add_theme_color_override("font_color", UiTheme.AMBER)
		if _phase_bar.get_meta("fill_col", Color.BLACK) != UiTheme.AMBER:
			_phase_bar.set_meta("fill_col", UiTheme.AMBER)
			UiTheme.skin_bar(_phase_bar, UiTheme.AMBER)
		var pid := str(phase.get("id", ""))
		if pid == "lockout":
			_phase_hint.text = "Survive & loot until the first window"
		else:
			_phase_hint.text = "Sealed — loot climbs while you stay"
	_timer_label.add_theme_color_override("font_color", UiTheme.DANGER if urgent and (is_open or is_last) else UiTheme.TEXT)
	if urgent:
		var p := 1.0 + 0.06 * absf(sin(_t * 6.0))
		_timer_label.pivot_offset = _timer_label.size * 0.5
		_timer_label.scale = Vector2(p, p)
	else:
		_timer_label.scale = Vector2.ONE
	## Loot multiplier (big) + Threat (rises with it)
	_threat_label.text = "LOOT ×%.1f" % loot
	var tl_col: Color = [UiTheme.AMBER, UiTheme.AMBER, UiTheme.RUST, UiTheme.DANGER][clampi(tl, 0, 3)]
	_threat_label.add_theme_color_override("font_color", tl_col)
	_threat_sub.text = "THREAT %d +%d%%" % [tl, int((float(ModeDefs.tl_table(tl)["hp"]) - 1.0) * 100.0)]
	if tl != _last_tl:
		_last_tl = tl
		_pulse(_threat_panel)
	_counter_label.text = "BAG %d  KILLS %d" % [GameState.bag_value(), GameState.kills]
	var rp: Dictionary = GameState.run_bar_state()
	_run_level_label.text = "LV %d%s" % [
		int(rp["level"]),
		"  MAX" if bool(rp.get("capped", false)) else "",
	]
	_run_xp_bar.value = float(rp["ratio"])
	if _xp_line:
		_xp_line.call("set_ratio", float(rp["ratio"]))
	if int(rp["level"]) != _run_lv and _pack_label:
		_run_lv = int(rp["level"])
		if _xp_line:
			_xp_line.call("set_level", _run_lv)
	if _xp_readout:
		_xp_readout.call("set_value", float(rp["ratio"]), 1.0, "%d" % int(rp["level"]))
	if player and is_instance_valid(player) and not bool(player.call("is_reloading")):
		_refresh_ammo()

func _refresh_ammo() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if bool(_player.call("is_reloading")) or bool(_player.call("is_melee")):
		return
	var a: int = _player.call("get_ammo")
	var m: int = _player.call("get_mag_size")
	_ammo_label.text = ""
	_ammo_label.add_theme_color_override("font_color", UiTheme.DANGER if a <= m / 5 else UiTheme.TEXT)

func set_extract_open(is_open: bool) -> void:
	if is_open != _extract_open:
		_extract_open = is_open
	if _extract_bar:
		_extract_bar.call("set_open", is_open)
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
	if _hp_readout:
		## Low health: the phosphor runs hot red.
		_hp_readout.set("on_color", Color(0.95, 0.3, 0.18) if _hp_ratio < 0.3 else Color(0.87, 0.54, 0.14))
		_hp_readout.call("set_value", current, maximum, "%d" % int(ceil(maxf(current, 0.0))))
	_hp_bar.tint_progress = Color(1, 1, 1) if _hp_ratio >= 0.3 else Color(1.0, 0.6, 0.55)

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
		chip.add_theme_stylebox_override("normal", UiTheme.plate("hud", 8.0))
		chip.add_theme_font_override("font", UiTheme.font_button)
		_buff_row.add_child(chip)
	var i := 0
	for id in buffs.keys():
		var raw = buffs[id]
		var entry: Dictionary = raw if raw is Dictionary else {"time_left": float(raw) if (raw is float or raw is int) else 0.0, "def": {}}
		var def_raw = entry.get("def", {})
		var def: Dictionary = def_raw if def_raw is Dictionary else {}
		var chip := _buff_row.get_child(i) as Label
		chip.text = "%s %ds" % [str(def.get("name", id)), int(ceil(float(entry.get("time_left", 0))))]
		var col_raw = def.get("color", UiTheme.AMBER)
		var col: Color = col_raw if col_raw is Color else UiTheme.AMBER
		chip.add_theme_color_override("font_color", col)
		## Special ammo (Phase 4): bigger chip outlined in the ammo colour.
		var is_ammo := str(id) == "ammo"
		chip.text = chip.text.to_upper() if is_ammo else chip.text
		chip.add_theme_font_size_override("font_size", 14 if is_ammo else 12)
		if chip.get_meta("chip_col", Color.BLACK) != col:
			chip.set_meta("chip_col", col)
			chip.add_theme_stylebox_override("normal", UiTheme.plate("hud", 8.0, Color.WHITE.lerp(col, 0.45) if is_ammo else Color.WHITE))
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

## Boss arrival: white pop, camera punch-in, name title. The top bar appears
## by itself (BossBar polls the "bosses" group).
func boss_intro(boss_name: String) -> void:
	if _white_flash:
		_white_flash.color.a = 0.55
		var tw := _white_flash.create_tween()
		tw.tween_property(_white_flash, "color:a", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	show_banner(boss_name.to_upper(), "BOSS INBOUND", UiTheme.DANGER)
	var cam := get_viewport().get_camera_2d()
	if cam and "punch" in cam:
		cam.set("punch", 1.14)


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
	## Thin red rim hugging the screen edges; the play area stays clear.
	var g := Gradient.new()
	g.set_color(0, Color(0.8, 0.06, 0.03, 0.0))
	g.set_color(1, Color(0.8, 0.06, 0.03, 0.75))
	g.add_point(0.78, Color(0.8, 0.06, 0.03, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex
