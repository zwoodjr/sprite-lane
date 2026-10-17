class_name MobileLayout
extends RefCounted

## Safe-area + touch-friendly sizing helpers for iPhone-first UI.


static func is_touch_ui() -> bool:
	return TouchInput.touch_primary


static func safe_margin() -> Rect2:
	return control_safe_margin()


static func control_safe_margin() -> Rect2:
	## Extra padding for thumbs / notch / home indicator — used by controls & HUD text only.
	## Game world should still render edge-to-edge behind the HUD.
	var wa := DisplayServer.get_display_safe_area()
	var win_size := DisplayServer.window_get_size()
	var left := 20.0
	var top := 16.0
	var right := 20.0
	var bottom := 36.0
	if wa.size.x > 0 and wa.size.y > 0:
		left = maxf(left, float(wa.position.x) + 8.0)
		top = maxf(top, float(wa.position.y) + 6.0)
		right = maxf(right, float(win_size.x - (wa.position.x + wa.size.x)) + 8.0)
		bottom = maxf(bottom, float(win_size.y - (wa.position.y + wa.size.y)) + 12.0)
	bottom = maxf(bottom, 40.0)
	return Rect2(left, top, win_size.x - left - right, win_size.y - top - bottom)


static func apply_menu_root(root: Control) -> void:
	var m := safe_margin()
	var win := DisplayServer.window_get_size()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = m.position.x
	root.offset_top = m.position.y
	root.offset_right = -(win.x - (m.position.x + m.size.x))
	root.offset_bottom = -(win.y - (m.position.y + m.size.y))


static func bump_button(btn: BaseButton, min_h: float = 56.0, font_size: int = 22) -> void:
	btn.custom_minimum_size = Vector2(
		maxi(int(btn.custom_minimum_size.x), 160),
		maxi(int(btn.custom_minimum_size.y), int(min_h))
	)
	btn.add_theme_font_size_override("font_size", font_size)


static func bump_label(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)


static func polish_menu(root: Control, buttons: Array, title: Label = null) -> void:
	apply_menu_root(root)
	if title:
		bump_label(title, 36)
	for b in buttons:
		if b is BaseButton:
			bump_button(b as BaseButton, 58.0, 22)
