class_name MobileLayout
extends RefCounted

## Safe-area + touch-friendly sizing helpers for iPhone-first UI.
## Design size is portrait 720x1280 (survivor FOV + single stick).


static func is_touch_ui() -> bool:
	return TouchInput.touch_primary


static func is_portrait() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var s := tree.root.get_visible_rect().size
		return s.y >= s.x
	return true


static func safe_margin() -> Rect2:
	return control_safe_margin()


static func control_safe_margin() -> Rect2:
	## Extra padding for thumbs / notch / home indicator - used by controls & HUD text only.
	## Game world should still render edge-to-edge behind the HUD.
	## Safe area comes back in real window pixels; the UI lives in stretched
	## viewport space, so convert before using it.
	var vp_size := Vector2(720, 1280)
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		vp_size = tree.root.get_visible_rect().size
	var win_size := Vector2(DisplayServer.window_get_size())
	var k := Vector2.ONE
	if win_size.x > 0 and win_size.y > 0:
		k = vp_size / win_size
	var wa := DisplayServer.get_display_safe_area()
	## Baseline padding for portrait thumbs + Dynamic Island / home bar.
	var left := 22.0
	var top := 18.0
	var right := 22.0
	var bottom := 22.0
	if wa.size.x > 0 and wa.size.y > 0 and OS.has_feature("mobile"):
		left = maxf(left, float(wa.position.x) * k.x + 8.0)
		top = maxf(top, float(wa.position.y) * k.y + 6.0)
		right = maxf(right, (win_size.x - float(wa.position.x + wa.size.x)) * k.x + 8.0)
		bottom = maxf(bottom, (win_size.y - float(wa.position.y + wa.size.y)) * k.y + 10.0)
	return Rect2(left, top, vp_size.x - left - right, vp_size.y - top - bottom)


static func apply_menu_root(root: Control) -> void:
	var m := safe_margin()
	var win := root.get_viewport_rect().size
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
