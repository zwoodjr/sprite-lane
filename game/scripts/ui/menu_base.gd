extends Control

## Shared scaffold for menu screens: animated backdrop + safe-area frame.
## Subclasses override build(content: VBoxContainer).

const MenuBg = preload("res://scripts/ui/menu_bg.gd")
const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")

var frame: MarginContainer
var content: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Control.new()
	bg.set_script(MenuBg)
	add_child(bg)
	frame = MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	frame.add_child(content)
	_apply_margins()
	get_viewport().size_changed.connect(_apply_margins)
	build(content)
	## Gentle entrance
	content.modulate.a = 0.0
	create_tween().tween_property(content, "modulate:a", 1.0, 0.25)


func _apply_margins() -> void:
	var m := MobileLayout.control_safe_margin()
	var vp := get_viewport_rect().size
	frame.add_theme_constant_override("margin_left", int(m.position.x + 12))
	frame.add_theme_constant_override("margin_right", int(vp.x - m.position.x - m.size.x + 12))
	frame.add_theme_constant_override("margin_top", int(m.position.y + 6))
	frame.add_theme_constant_override("margin_bottom", int(vp.y - m.position.y - m.size.y + 6))


func build(_c: VBoxContainer) -> void:
	pass


func header(title: String, back_cb: Callable = Callable()) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	if back_cb.is_valid():
		var b := UiTheme.big_button("‹", UiTheme.LINE, 56, 28)
		b.custom_minimum_size = Vector2(64, 56)
		b.pressed.connect(back_cb)
		h.add_child(b)
	var t := UiTheme.title_label(title, 38)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	return h


func spacer(expand: bool = true, h: float = 0.0) -> Control:
	var s := Control.new()
	if expand:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, h)
	return s


func card(border: Color = UiTheme.LINE, bg: Color = UiTheme.PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(bg, border, 18, 2, 18))
	return p
