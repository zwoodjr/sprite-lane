extends Control

## Shared scaffold for menu screens: animated backdrop + safe-area frame.
## Subclasses override build(content: VBoxContainer).

const MenuBg = preload("res://scripts/ui/menu_bg.gd")
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
	## Entrance: fade in. (No position tween: moving an anchored container
	## freezes its size, and autowrap labels report a huge height on the first
	## layout pass, which pushed bottom buttons off-screen.)
	content.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(content, "modulate:a", 1.0, 0.22)
	frame.resized.connect(_fit_frame)
	_fit_frame.call_deferred()

## Keep the frame exactly the screen size (it may never grow past it).
func _fit_frame() -> void:
	if not is_instance_valid(frame):
		return
	var vp := get_viewport_rect().size
	if absf(frame.size.y - vp.y) > 0.5 or absf(frame.size.x - vp.x) > 0.5 or frame.position != Vector2.ZERO:
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _apply_margins() -> void:
	var m := MobileLayout.control_safe_margin()
	var vp := get_viewport_rect().size
	frame.add_theme_constant_override("margin_left", int(m.position.x + 4))
	frame.add_theme_constant_override("margin_right", int(vp.x - m.position.x - m.size.x + 4))
	frame.add_theme_constant_override("margin_top", int(m.position.y + 6))
	frame.add_theme_constant_override("margin_bottom", int(vp.y - m.position.y - m.size.y + 6))

func build(_c: VBoxContainer) -> void:
	pass

func header(title: String, back_cb: Callable = Callable()) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	if back_cb.is_valid():
		var b := UiTheme.cap_button("back", 64)
		b.pressed.connect(back_cb)
		h.add_child(b)
	var t := UiTheme.title_label(title, 38)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(t)
	return h

func spacer(expand: bool = true, h: float = 0.0) -> Control:
	var s := Control.new()
	if expand:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, h)
	return s

## Riveted plate card. A non-default border picks the brighter brass plate,
## a near-black bg the recessed inset.
func card(border: Color = UiTheme.LINE, bg: Color = UiTheme.PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	var kind := "panel"
	if border == UiTheme.AMBER:
		kind = "panel_hi"
	elif border != UiTheme.LINE:
		kind = "panel_steel"
	var tint := Color.WHITE
	if bg.a < 0.9:
		tint = Color(1, 1, 1, clampf(bg.a + 0.08, 0.6, 1.0))
	p.add_theme_stylebox_override("panel", UiTheme.plate(kind, 20.0, tint))
	return p


## Worn modal dialog over the whole screen (dim backdrop + brass plate, the
## pause menu's look): a title, body lines ([text, color] or plain text) and
## buttons from `buttons` ([[label, accent, callable], ...]). Returns the
## overlay; callers close it with queue_free.
func modal(title: String, lines: Array, buttons: Array, title_color: Color = UiTheme.AMBER) -> Control:
	var overlay := Control.new()
	overlay.name = "Modal"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.plate("panel_hi", 28.0))
	center.add_child(plate)
	var v := VBoxContainer.new()
	v.name = "Body"
	v.add_theme_constant_override("separation", 14)
	var w := minf(560.0, get_viewport_rect().size.x - 72.0)
	v.custom_minimum_size = Vector2(w, 0)
	plate.add_child(v)
	v.add_child(UiTheme.title_label(title, UiTheme.T_TITLE, title_color))
	for ln in lines:
		var txt := str(ln[0]) if ln is Array else str(ln)
		var col: Color = ln[1] if ln is Array and (ln as Array).size() > 1 else UiTheme.TEXT
		var l := UiTheme.body_label(txt, UiTheme.T_BODY, col)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(w, 0)
		v.add_child(l)
	for b in buttons:
		var btn := UiTheme.big_button(str(b[0]), b[1], 80 if b[1] == UiTheme.AMBER else 64, 32 if b[1] == UiTheme.AMBER else 22)
		btn.name = "Btn_" + str(b[0]).split(" ")[0]
		btn.pressed.connect(b[2])
		v.add_child(btn)
	plate.pivot_offset = Vector2(w * 0.5, 200)
	plate.scale = Vector2(0.92, 0.92) if not SettingsDefs.reduce_motion() else Vector2.ONE
	plate.modulate.a = 0.0
	var tw := plate.create_tween().set_parallel(true)
	tw.tween_property(plate, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(plate, "modulate:a", 1.0, 0.12)
	return overlay
