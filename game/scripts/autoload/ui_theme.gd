extends Node

## Global "Dust Apothecary" UI theme, built in code and applied to the root
## window so every Control (menus, HUD, pause) shares one look.
## Painted scrap-metal kit: riveted 9-slice plates and brass/tonic/rust
## buttons (assets/sprites/ui/kit, made by tools/gen_ui_kit.py), Barlow
## Condensed for headings/buttons and Barlow Semi Condensed for body text.

const BG := Color(0.11, 0.08, 0.06)
const PANEL := Color(0.17, 0.125, 0.09, 0.94)
const PANEL_LIGHT := Color(0.24, 0.18, 0.13, 0.96)
const LINE := Color(0.45, 0.33, 0.2)
const AMBER := Color(0.95, 0.72, 0.30)
const RUST := Color(0.82, 0.36, 0.20)
const TEAL := Color(0.38, 0.78, 0.62)
const TEXT := Color(0.96, 0.91, 0.82)
const TEXT_DIM := Color(0.74, 0.66, 0.55)
const DANGER := Color(0.92, 0.32, 0.25)

const KIT := "res://assets/sprites/ui/kit/"
const FONT_DISPLAY_PATH := "res://assets/fonts/BarlowCondensed-ExtraBold.ttf"
const FONT_BUTTON_PATH := "res://assets/fonts/BarlowCondensed-Bold.ttf"
const FONT_BODY_PATH := "res://assets/fonts/BarlowSemiCondensed-Medium.ttf"
const FONT_BODY_BOLD_PATH := "res://assets/fonts/BarlowSemiCondensed-SemiBold.ttf"

var theme: Theme
var font_display: Font
var font_button: Font
var font_body: Font
var font_body_bold: Font
var _tex_cache: Dictionary = {}
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_fonts()
	theme = _build()
	get_tree().root.theme = theme
	## Every button anywhere gets press feedback (scale + haptic tick).
	get_tree().node_added.connect(_on_node_added)
	_build_fade()


func _load_fonts() -> void:
	var fb: Font = ThemeDB.fallback_font
	font_display = _font(FONT_DISPLAY_PATH, fb)
	font_button = _font(FONT_BUTTON_PATH, fb)
	font_body = _font(FONT_BODY_PATH, fb)
	font_body_bold = _font(FONT_BODY_BOLD_PATH, fb)
	## World-space labels (pet names, pickup names, landmarks) have no theme:
	## make the engine fallback the UI body font too.
	if font_body != fb:
		ThemeDB.fallback_font = font_body


func _font(path: String, fb: Font) -> Font:
	if not ResourceLoader.exists(path):
		return fb
	var f := load(path) as FontFile
	if f == null:
		return fb
	## Arrows, check marks etc. aren't in Barlow's latin set: fall back to the
	## engine font for those glyphs.
	if fb and f.fallbacks.is_empty():
		f.fallbacks = [fb]
	return f


func tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path := KIT + name + ".png"
	var t: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_tex_cache[name] = t
	return t


func box(bg: Color, border: Color = LINE, radius: int = 14, border_w: int = 2, pad: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	sb.anti_aliasing = true
	return sb


## Painted 9-slice plate. kind: panel · panel_hi · panel_steel · inset · tile · tile_on
## · btn_<amber|teal|rust|steel|neutral>[_hover|_pressed] · btn_disabled.
## Falls back to a flat box if the kit art is missing.
func plate(kind: String = "panel", pad: float = 18.0, tint: Color = Color.WHITE) -> StyleBox:
	var t := tex(kind)
	if t == null:
		return box(PANEL, LINE, 14, 2, int(pad))
	var sb := StyleBoxTexture.new()
	sb.texture = t
	var m := _slice_margin(kind)
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	if kind.begins_with("panel") or kind == "inset":
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.75
	sb.content_margin_bottom = pad * 0.75
	sb.modulate_color = tint
	return sb


func _slice_margin(kind: String) -> float:
	if kind.begins_with("panel"):
		return 28.0
	if kind.begins_with("btn"):
		return 22.0
	if kind == "tile":
		return 20.0
	if kind == "tile_on":
		return 26.0
	if kind == "inset":
		return 18.0
	if kind == "hud":
		return 14.0
	if kind == "bar_bg":
		return 10.0
	if kind == "bar_fill":
		return 8.0
	return 16.0


## Which painted button family suits an accent colour.
func kit_for(accent: Color) -> String:
	var best := "steel"
	var best_d := 0.06
	for pair in [["amber", AMBER], ["teal", TEAL], ["rust", RUST], ["rust", DANGER], ["steel", LINE]]:
		var c: Color = pair[1]
		var d := absf(c.r - accent.r) + absf(c.g - accent.g) + absf(c.b - accent.b)
		if d < best_d:
			best_d = d
			best = str(pair[0])
	if best_d >= 0.06:
		return "neutral"
	return best


## Apply the painted button skin to any Button (keeps its text/icon).
func skin_button(b: Button, accent: Color = LINE, pad: float = 16.0) -> void:
	var fam := kit_for(accent)
	var tint := Color.WHITE
	if fam == "neutral":
		tint = accent.lightened(0.1)
	var n := plate("btn_" + fam, pad, tint)
	var h := plate("btn_%s_hover" % fam, pad, tint)
	var p := plate("btn_%s_pressed" % fam, pad, tint)
	## Pressed content sinks 2px into the plate.
	p.content_margin_top += 2.0
	p.content_margin_bottom = maxf(0.0, p.content_margin_bottom - 2.0)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", plate("btn_disabled", pad))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Square selectable tile (roster heroes, pets, slots). on = selected glow.
func skin_tile(b: Button, on: bool, pad: float = 6.0) -> void:
	var sb := plate("tile_on" if on else "tile", pad)
	var hv := plate("tile_on", pad) if on else plate("tile", pad, Color(1.15, 1.1, 1.0))
	for s in ["normal", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("disabled", plate("tile", pad, Color(0.6, 0.6, 0.6)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Painted progress bar (groove + tinted fill).
func skin_bar(bar: ProgressBar, fill: Color = TEAL) -> void:
	var h := maxf(bar.custom_minimum_size.y, 10.0)
	bar.custom_minimum_size.y = h
	var bg := plate("bar_bg", 0.0)
	var f := plate("bar_fill", 0.0, fill)
	## Thin bars: keep the 9-slice caps inside the bar height.
	for sb in [bg, f]:
		if sb is StyleBoxTexture:
			var st := sb as StyleBoxTexture
			st.texture_margin_top = minf(st.texture_margin_top, floorf(h * 0.45))
			st.texture_margin_bottom = st.texture_margin_top
			st.texture_margin_left = minf(st.texture_margin_left, floorf(h * 0.6))
			st.texture_margin_right = st.texture_margin_left
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", f)


func _build() -> Theme:
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 21

	## Buttons — painted steel by default
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox", "MenuButton"]:
		t.set_stylebox("normal", type, plate("btn_steel", 16.0))
		t.set_stylebox("hover", type, plate("btn_steel_hover", 16.0))
		var p := plate("btn_steel_pressed", 16.0)
		p.content_margin_top += 2.0
		t.set_stylebox("pressed", type, p)
		t.set_stylebox("hover_pressed", type, p)
		t.set_stylebox("disabled", type, plate("btn_disabled", 16.0))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_font("font", type, font_button)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color(1, 0.96, 0.86))
		t.set_color("font_pressed_color", type, Color(1, 0.86, 0.55))
		t.set_color("font_hover_pressed_color", type, Color(1, 0.86, 0.55))
		t.set_color("font_disabled_color", type, Color(0.55, 0.5, 0.45))
		t.set_color("font_outline_color", type, Color(0.07, 0.045, 0.03))
		t.set_constant("outline_size", type, 5)
		t.set_constant("h_separation", type, 8)

	## Panels
	t.set_stylebox("panel", "Panel", plate("panel", 18.0))
	t.set_stylebox("panel", "PanelContainer", plate("panel", 20.0))

	## Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0.06, 0.04, 0.03))
	t.set_constant("outline_size", "Label", 4)
	t.set_constant("line_spacing", "Label", 1)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_outline_color", "RichTextLabel", Color(0.06, 0.04, 0.03))
	t.set_constant("outline_size", "RichTextLabel", 3)
	t.set_font("normal_font", "RichTextLabel", font_body)
	t.set_font("bold_font", "RichTextLabel", font_body_bold)
	t.set_font("font", "TooltipLabel", font_body)

	## Progress bars (HP etc.)
	var pbg := plate("bar_bg", 0.0)
	var pfill := plate("bar_fill", 0.0, TEAL)
	for sb in [pbg, pfill]:
		if sb is StyleBoxTexture:
			(sb as StyleBoxTexture).texture_margin_top = 3.0
			(sb as StyleBoxTexture).texture_margin_bottom = 3.0
			(sb as StyleBoxTexture).texture_margin_left = 5.0
			(sb as StyleBoxTexture).texture_margin_right = 5.0
	t.set_stylebox("background", "ProgressBar", pbg)
	t.set_stylebox("fill", "ProgressBar", pfill)
	t.set_color("font_color", "ProgressBar", TEXT)

	## Sliders
	t.set_stylebox("slider", "HSlider", plate("bar_bg", 4.0))
	t.set_stylebox("grabber_area", "HSlider", plate("bar_fill", 0.0, AMBER.darkened(0.15)))
	t.set_stylebox("grabber_area_highlight", "HSlider", plate("bar_fill", 0.0, AMBER))
	var cap := tex("cap_grab")
	if cap:
		t.set_icon("grabber", "HSlider", cap)
		t.set_icon("grabber_highlight", "HSlider", cap)

	## Scroll
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 6, 0, 2))
	t.set_stylebox("grabber", "VScrollBar", box(LINE, Color(0, 0, 0, 0), 6, 0, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(AMBER, Color(0, 0, 0, 0), 6, 0, 2))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(AMBER, Color(0, 0, 0, 0), 6, 0, 2))
	t.set_stylebox("scroll", "HScrollBar", box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 6, 0, 2))
	t.set_stylebox("grabber", "HScrollBar", box(LINE, Color(0, 0, 0, 0), 6, 0, 2))
	t.set_stylebox("grabber_highlight", "HScrollBar", box(AMBER, Color(0, 0, 0, 0), 6, 0, 2))
	t.set_stylebox("grabber_pressed", "HScrollBar", box(AMBER, Color(0, 0, 0, 0), 6, 0, 2))
	t.set_stylebox("panel", "TooltipPanel", plate("panel_steel", 10.0))
	return t


## Small helpers used by menus -----------------------------------------------

func title_label(text: String, size: int = 52, color: Color = AMBER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_display:
		l.add_theme_font_override("font", font_display)
	l.add_theme_font_size_override("font_size", int(size * 1.08))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.09, 0.055, 0.035))
	l.add_theme_constant_override("outline_size", maxi(6, int(size * 0.2)))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", maxi(3, int(size * 0.08)))
	return l


func body_label(text: String, size: int = 18, color: Color = TEXT, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	## Small amber/teal captions read as section headers: use the bolder cut.
	if size <= 15 and (color == AMBER or color == TEAL) and font_body_bold:
		l.add_theme_font_override("font", font_body_bold)
	l.add_theme_font_size_override("font_size", size + 1)
	l.add_theme_color_override("font_color", color)
	return l


func big_button(text: String, accent: Color = AMBER, min_h: float = 64.0, font_size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = false
	if font_button:
		b.add_theme_font_override("font", font_display if font_size >= 26 else font_button)
	b.add_theme_font_size_override("font_size", font_size + 2)
	skin_button(b, accent, 18.0)
	b.pressed.connect(func() -> void: Juice.sfx("ui_tap"))
	return b


## Round bottle-cap icon button (back / close).
func cap_button(kind: String = "back", px: float = 64.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.flat = true
	b.icon = tex("cap_" + kind)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var e := StyleBoxEmpty.new()
		b.add_theme_stylebox_override(s, e)
	b.add_theme_color_override("icon_hover_color", Color(1.12, 1.08, 1.0))
	b.add_theme_color_override("icon_pressed_color", Color(0.8, 0.75, 0.7))
	b.pressed.connect(func() -> void: Juice.sfx("ui_back"))
	return b


func press_anim(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(0.92, 0.92), 0.05)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## --- Feel: global button feedback + scene fade ------------------------------

func _on_node_added(n: Node) -> void:
	## Theme lookup stops at CanvasLayers (HUD, pause, picker...): hand those
	## UI roots the theme directly so they match the menus.
	if n is Control and (n as Control).theme == null:
		var par := n.get_parent()
		if par is CanvasLayer:
			(n as Control).theme = theme
	if n is BaseButton:
		var b := n as BaseButton
		if not b.button_down.is_connected(_on_btn_down.bind(b)):
			b.button_down.connect(_on_btn_down.bind(b))
			b.button_up.connect(_on_btn_up.bind(b))
	elif n.get_parent() == get_tree().root and n is CanvasItem and n != _fade:
		_fade_in.call_deferred()


func _on_btn_down(b: BaseButton) -> void:
	if not is_instance_valid(b) or b.disabled:
		return
	Juice.haptic(8)
	var c := b as Control
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(0.95, 0.95), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_btn_up(b: BaseButton) -> void:
	if not is_instance_valid(b):
		return
	var c := b as Control
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.035, 0.025, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


## New scene: fade up from dust-dark so screen changes never hard-cut.
func _fade_in() -> void:
	if _fade == null:
		return
	_fade.color.a = 1.0
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
