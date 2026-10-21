extends Node

## Global "Dust Apothecary" UI theme, built in code and applied to the root
## window so every Control (menus, HUD, pause) shares one look.
## Painted scrap-metal kit: riveted 9-slice plates and brass/tonic/rust
## buttons (assets/sprites/ui/kit, made by tools/gen_ui_kit.py), Barlow
## Condensed for headings/buttons and Barlow Semi Condensed for body text.

## Colour roles (style bible §6.3), all from the master palette.
const BG := Color("1f1a1d")
const PANEL := Color(0.122, 0.102, 0.114, 0.94)
const PANEL_LIGHT := Color(0.106, 0.133, 0.173, 0.96)
const LINE := Color("7c6550")
const AMBER := Color("ffc040")
const RUST := Color("ad5a2a")
const TEAL := Color("5cd2c0")
const TEXT := Color("e9dfc9")
const TEXT_DIM := Color("8f877e")
const DANGER := Color("ff4836")
const POISON := Color("9ccf3e")
const INK := Color("140c0e")
const BRASS := Color("b88a33")

## Type scale (§6.2): the only sizes the UI uses, in design px.
const T_TITLE_XL := 56
const T_TITLE := 40
const T_H1 := 32
const T_H2 := 24
const T_H3 := 20
const T_BODY := 20
const T_SMALL := 16
## Pixel font (numbers / short readouts): 8 / 16 / 24 only.
const PX_S := 8
const PX_M := 16
const PX_L := 24
## 8-px grid, 24-px screen margins, 16-px gutters.
const GRID := 8
const MARGIN := 24
const GUTTER := 16

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
## Bundled symbol fallback (DejaVu Sans Bold subset: arrows, ×, ✓, ★, ◆ …).
## The web build and iOS have no system font fallback, so these were tofu.
var font_symbols: Font
## The one pixel face (HUD numbers / damage numbers), with the symbol fallback.
var font_pixel: Font
const FONT_SYMBOLS_PATH := "res://assets/fonts/Symbols-DejaVuSansBold.ttf"
const FONT_PIXEL_PATH := "res://assets/fonts/PressStart2P.ttf"
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
	if ResourceLoader.exists(FONT_SYMBOLS_PATH):
		font_symbols = load(FONT_SYMBOLS_PATH) as Font
	font_display = _font(FONT_DISPLAY_PATH, fb)
	font_button = _font(FONT_BUTTON_PATH, fb)
	font_body = _font(FONT_BODY_PATH, fb)
	font_body_bold = _font(FONT_BODY_BOLD_PATH, fb)
	## World-space labels (pet names, pickup names, landmarks) have no theme:
	## make the engine fallback the UI body font too.
	if font_body != fb:
		ThemeDB.fallback_font = font_body
	font_pixel = _font(FONT_PIXEL_PATH, fb)
	## Pixel face: hard pixels, no AA / hinting / subpixel drift.
	if font_pixel is FontFile:
		var pf := font_pixel as FontFile
		pf.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		pf.hinting = TextServer.HINTING_NONE
		pf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


func _font(path: String, fb: Font) -> Font:
	if not ResourceLoader.exists(path):
		return fb
	var f := load(path) as FontFile
	if f == null:
		return fb
	## Arrows, check marks etc. aren't in Barlow's latin set: fall back to the
	## engine font for those glyphs.
	if f.fallbacks.is_empty():
		var fbs: Array[Font] = []
		if font_symbols:
			fbs.append(font_symbols)
		if fb:
			fbs.append(fb)
		f.fallbacks = fbs
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
	t.default_font_size = T_BODY

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
		t.set_color("font_hover_color", type, TEXT)
		t.set_color("font_pressed_color", type, AMBER)
		t.set_color("font_hover_pressed_color", type, AMBER)
		t.set_color("font_disabled_color", type, TEXT_DIM)
		t.set_color("font_outline_color", type, INK)
		t.set_constant("outline_size", type, 4)
		t.set_font_size("font_size", type, T_H3)
		t.set_constant("h_separation", type, 8)

	## Panels
	t.set_stylebox("panel", "Panel", plate("panel", 18.0))
	t.set_stylebox("panel", "PanelContainer", plate("panel", 20.0))

	## Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 4)
	t.set_font_size("font_size", "Label", T_BODY)
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

## Snap any requested size onto the bible's fixed type scale.
static func title_size(size: int) -> int:
	if size >= 50:
		return T_TITLE_XL
	if size >= 36:
		return T_TITLE
	if size >= 28:
		return T_H1
	return T_H2


static func ui_size(size: int) -> int:
	if size >= 50:
		return T_TITLE_XL
	if size >= 36:
		return T_TITLE
	if size >= 28:
		return T_H1
	if size >= 22:
		return T_H2
	if size >= 18:
		return T_H3
	return T_SMALL


static func px_size(size: int) -> int:
	if size >= 20:
		return PX_L
	if size >= 12:
		return PX_M
	return PX_S


func title_label(text: String, size: int = 52, color: Color = AMBER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fs := title_size(size)
	if font_display:
		l.add_theme_font_override("font", font_display)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 8 if fs >= T_TITLE else 6)
	l.add_theme_color_override("font_shadow_color", Color(INK, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 4 if fs >= T_TITLE else 2)
	return l


## Body text (Barlow Semi Condensed Medium 20, or 16 minimum). Section
## captions in a value/positive colour use the SemiBold emphasis cut.
func body_label(text: String, size: int = 18, color: Color = TEXT, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var fs := ui_size(size)
	if fs > T_BODY:
		l.add_theme_font_override("font", font_button)
	elif (color == AMBER or color == TEAL) and font_body_bold:
		l.add_theme_font_override("font", font_body_bold)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	return l


## Header / label in Barlow Condensed Bold (32 / 24 / 20).
func head_label(text: String, size: int = T_H2, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_button)
	l.add_theme_font_size_override("font_size", ui_size(maxi(size, T_H3)))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Number / short readout in the pixel font (8 / 16 / 24, AA off).
func pixel_label(text: String, size: int = PX_M, color: Color = AMBER) -> Label:
	var l := Label.new()
	l.text = text
	if font_pixel:
		l.add_theme_font_override("font", font_pixel)
	l.add_theme_font_size_override("font_size", px_size(size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 4 if size >= PX_M else 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## --- Icon-led building blocks ----------------------------------------------

## Recessed icon well with the rarity rim; the icon sits at an integer x2.
func icon_well(icon_id: String, rarity: String = "common", px: int = 128) -> Control:
	var well := PanelContainer.new()
	var sb := StyleBoxTexture.new()
	sb.texture = IconSet.frame(rarity)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 12.0)
		sb.set_content_margin(side, 0.0)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	well.add_theme_stylebox_override("panel", sb)
	well.custom_minimum_size = Vector2(px, px)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Integer scales only: 48-px art x2 in wells >= 112, x1 in wells >= 56.
	var ic_px := 96 if px >= 112 else (48 if px >= 56 else 32)
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(c)
	var r := IconSet.rect(icon_id, ic_px)
	if ic_px == 32:
		r.texture = IconSet.tex(icon_id, false)
	c.add_child(r)
	return well


## Small tag chip: INK-edged steel plate with Barlow Condensed Bold 16 text.
func chip(text: String, color: Color = TEXT_DIM, fill: Color = Color("1b222c")) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.border_width_top = 2
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", font_button)
	l.add_theme_font_size_override("font_size", T_SMALL)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


## Rarity tab: painted plate in the rarity colour with INK text (§6.3).
func rarity_tab(text: String, rarity: String) -> PanelContainer:
	var col := IconSet.rarity_color(rarity)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", font_button)
	l.add_theme_font_size_override("font_size", T_H3)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


## Rank pips: filled = owned, the next rank glows amber, the rest are empty.
func rank_pips(rank: int, max_rank: int, next_glow: bool = true) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(max_rank):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(16, 16)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.border_color = INK
		sb.set_border_width_all(2)
		if i < rank:
			sb.bg_color = Color("e88a1c")
		elif i == rank and next_glow:
			sb.bg_color = AMBER
			sb.border_color = Color("fff2c0")
		else:
			sb.bg_color = Color("1f1a1d")
			sb.border_color = Color("36424f")
		pip.add_theme_stylebox_override("panel", sb)
		h.add_child(pip)
	return h


func big_button(text: String, accent: Color = AMBER, min_h: float = 64.0, font_size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = false
	var fs := ui_size(font_size)
	if fs >= T_TITLE:
		fs = T_H1
	if font_button:
		b.add_theme_font_override("font", font_display if fs >= T_H1 else font_button)
	b.add_theme_font_size_override("font_size", fs)
	## Bible: primary 80 tall, secondary 64; touch targets >= 64 everywhere.
	b.custom_minimum_size.y = maxf(64.0, roundf(min_h / 8.0) * 8.0)
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


## Scene transition (polish pass 2): an interlaced CRT scanline wipe in the
## worn amber-readout look instead of a plain fade. 8-px INK bands with a dim
## scanline drop away top-to-bottom (even rows, then odd), each led by a 2-px
## DUST-amber line; time is stepped (12 steps) so it reads pixel, not tweened.
## 0.24 s, never blocks input (mouse_filter IGNORE), hidden when done.
const WIPE_TIME := 0.24
const WIPE_SHADER := """
shader_type canvas_item;
uniform float t = 1.0;
uniform float rows = 195.0;
void fragment() {
	float ts = floor(t * 12.0) / 12.0;
	float r = floor(UV.y * rows);
	float odd = mod(r, 2.0);
	float d = (r / rows) * 0.5 + odd * 0.3;
	float open_at = d + 0.18;
	float inrow = fract(UV.y * rows);
	vec4 ink = vec4(0.078, 0.047, 0.055, 1.0);
	vec4 scan = vec4(0.122, 0.102, 0.114, 1.0);
	vec4 amber = vec4(1.0, 0.753, 0.251, 1.0);
	vec4 ember = vec4(0.659, 0.322, 0.059, 1.0);
	if (ts >= open_at) {
		COLOR = vec4(0.0);
	} else if (ts >= open_at - 0.1) {
		// the band is collapsing: amber line on top, ember under it
		float k = (ts - (open_at - 0.1)) / 0.1;
		float lim = 1.0 - k;
		if (inrow > lim) { COLOR = vec4(0.0); }
		else if (inrow > lim - 0.25) { COLOR = amber; }
		else if (inrow > lim - 0.5) { COLOR = ember; }
		else { COLOR = ink; }
	} else {
		COLOR = inrow < 0.25 ? scan : ink;
	}
}
"""
var _wipe_mat: ShaderMaterial


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.WHITE
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = WIPE_SHADER
	_wipe_mat = ShaderMaterial.new()
	_wipe_mat.shader = sh
	_fade.material = _wipe_mat
	_fade.visible = false
	layer.add_child(_fade)


var _wipe_tw: Tween


## New scene: scanline wipe up from INK so screen changes never hard-cut.
func _fade_in() -> void:
	if _fade == null:
		return
	if _wipe_tw and _wipe_tw.is_valid():
		_wipe_tw.kill()
	var h := maxf(get_viewport().get_visible_rect().size.y, 8.0)
	_wipe_mat.set_shader_parameter("rows", floorf(h / 8.0))
	_wipe_mat.set_shader_parameter("t", 0.0)
	_fade.visible = true
	_wipe_tw = _fade.create_tween()
	_wipe_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_wipe_tw.tween_method(func(v: float) -> void: _wipe_mat.set_shader_parameter("t", v), 0.0, 1.0, WIPE_TIME)
	_wipe_tw.tween_callback(func() -> void: _fade.visible = false)


## Progress of the current wipe (0..1; 1 = done). For tests / capture tools.
func wipe_t() -> float:
	if _fade == null or not _fade.visible:
		return 1.0
	return float(_wipe_mat.get_shader_parameter("t"))
