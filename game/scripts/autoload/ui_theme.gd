extends Node

## Global "Dust Apothecary" UI theme, built in code and applied to the root
## window so every Control (menus, HUD, pause) shares one look.

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

var theme: Theme


func _ready() -> void:
	theme = _build()
	get_tree().root.theme = theme


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


func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20

	## Buttons
	var normal := box(PANEL_LIGHT, LINE)
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 3)
	var hover := box(Color(0.30, 0.22, 0.15, 0.98), AMBER)
	var pressed := box(Color(0.38, 0.26, 0.14, 1.0), AMBER, 14, 3)
	var disabled := box(Color(0.15, 0.12, 0.10, 0.7), Color(0.3, 0.25, 0.2))
	var focus := box(Color(0, 0, 0, 0), AMBER, 14, 2)
	focus.draw_center = false
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color(1, 0.95, 0.85))
		t.set_color("font_pressed_color", type, AMBER)
		t.set_color("font_hover_pressed_color", type, AMBER)
		t.set_color("font_disabled_color", type, Color(0.5, 0.45, 0.4))
		t.set_color("font_outline_color", type, Color(0.05, 0.03, 0.02))
		t.set_constant("outline_size", type, 3)

	## Panels
	t.set_stylebox("panel", "Panel", box(PANEL, LINE, 18))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 18, 2, 18))

	## Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0.06, 0.04, 0.03))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_outline_color", "RichTextLabel", Color(0.06, 0.04, 0.03))
	t.set_constant("outline_size", "RichTextLabel", 3)

	## Progress bars (HP etc.)
	var pb_bg := box(Color(0.08, 0.06, 0.05, 0.85), Color(0.3, 0.22, 0.15), 8, 2, 0)
	var pb_fill := box(TEAL, Color(0, 0, 0, 0), 6, 0, 0)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_color("font_color", "ProgressBar", TEXT)

	## Sliders
	t.set_stylebox("slider", "HSlider", box(Color(0.1, 0.08, 0.06), LINE, 6, 1, 4))
	t.set_stylebox("grabber_area", "HSlider", box(AMBER.darkened(0.3), Color(0, 0, 0, 0), 6, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(AMBER, Color(0, 0, 0, 0), 6, 0, 4))

	## Scroll
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.2), Color(0, 0, 0, 0), 6, 0, 2))
	t.set_stylebox("grabber", "VScrollBar", box(LINE, Color(0, 0, 0, 0), 6, 0, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(AMBER, Color(0, 0, 0, 0), 6, 0, 2))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(AMBER, Color(0, 0, 0, 0), 6, 0, 2))
	return t


## Small helpers used by menus -----------------------------------------------

func title_label(text: String, size: int = 52, color: Color = AMBER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 4)
	return l


func body_label(text: String, size: int = 18, color: Color = TEXT, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func big_button(text: String, accent: Color = AMBER, min_h: float = 64.0, font_size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	var n := box(accent.darkened(0.55), accent, 16, 3)
	n.shadow_color = Color(0, 0, 0, 0.4)
	n.shadow_size = 6
	n.shadow_offset = Vector2(0, 4)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", box(accent.darkened(0.4), accent.lightened(0.2), 16, 3))
	var p := box(accent.darkened(0.25), accent.lightened(0.3), 16, 4)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.pressed.connect(func() -> void: Juice.sfx("ui_tap"))
	return b


func press_anim(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(0.92, 0.92), 0.05)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
