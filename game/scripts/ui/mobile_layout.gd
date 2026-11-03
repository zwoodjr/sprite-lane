class_name MobileLayout
extends RefCounted

## Safe-area + touch-friendly sizing helpers for iPhone-first UI.
## Design size is portrait 720x1280 (survivor FOV + single stick).


static func is_touch_ui() -> bool:
	return TouchInput.touch_primary


## A real desktop build (mouse, OS window). QUIT / FULLSCREEN only exist here:
## iOS, Xogot Play and the web build never show them.
static func is_desktop() -> bool:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return false
	if not (OS.get_name() in ["Windows", "Linux", "macOS", "FreeBSD"]):
		return false
	return not TouchInput.touch_primary


static func is_portrait() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var s := tree.root.get_visible_rect().size
		return s.y >= s.x
	return true


static func safe_margin() -> Rect2:
	return control_safe_margin()


## Review tools only: simulated notch / home-bar insets in UI px (l, t, r, b).
static var sim_safe := Vector4.ZERO
## Review tools / tests only: forced device px per UI px (0 = measure).
static var sim_stretch := 0.0

## Device px per UI px above which the thumb controls shrink toward their
## iPhone physical size: 1.8 = a Pro Max (1290 px / 720), so every regular
## iPhone keeps exactly the old layout; the iPhone Duo inner screen (1878 px
## over a 900-wide UI, 2.09) gets 0.86.
const THUMB_REF_STRETCH := 1.8
const THUMB_MIN := 0.8


## Device px per UI px (1 in headless runs).
static func stretch() -> float:
	if sim_stretch > 0.0:
		return sim_stretch
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null or DisplayServer.get_name() == "headless":
		return 1.0
	var vis := tree.root.get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if vis.x <= 0.0 or win.x <= 0.0:
		return 1.0
	return win.x / vis.x


## Scale for DASH / ABILITY / the stick so they keep a thumb-sized physical
## size (and reach) on big screens: 1.0 on every regular iPhone.
static func thumb_scale() -> float:
	return clampf(THUMB_REF_STRETCH / maxf(stretch(), 0.01), THUMB_MIN, 1.0)


## Widest a menu column gets (UI px): a landscape fold (1820 wide) keeps a
## readable phone-width column instead of stretching every card edge to edge.
const MENU_MAX_W := 900.0


## Extra side margin (each side) that keeps a menu column at MENU_MAX_W.
static func column_pad(vp_w: float, used_w: float) -> float:
	return maxf(0.0, (used_w - MENU_MAX_W) * 0.5) if vp_w > 0.0 else 0.0


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
	if sim_safe != Vector4.ZERO:
		left = maxf(left, sim_safe.x)
		top = maxf(top, sim_safe.y)
		right = maxf(right, sim_safe.z)
		bottom = maxf(bottom, sim_safe.w)
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
