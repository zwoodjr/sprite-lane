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


## Review tools only: a simulated DisplayServer safe area (window px) run
## through the same mobile path, e.g. the bogus one Xogot reported on the Duo.
static var sim_display_safe := Rect2i()

## A real notch / home-bar / Dynamic Island inset is at most ~7% of the
## screen side (59 pt of 852). Anything bigger is not a hardware inset: Xogot
## on the iPhone Duo inner screen reported a safe area ~69% as wide as the
## window, which pinned DASH / ABILITY, the pause cap and the minimap to a
## centred column. Such a side falls back to the baseline padding.
const MAX_INSET_FRAC := 0.09


## Window-px insets (l, t, r, b) from a safe-area rect, implausible sides
## dropped to 0. Pure (tests).
static func sane_insets(win_size: Vector2, wa: Rect2) -> Vector4:
	if win_size.x <= 0.0 or win_size.y <= 0.0 or wa.size.x <= 0.0 or wa.size.y <= 0.0:
		return Vector4.ZERO
	var ins := Vector4(wa.position.x, wa.position.y,
		win_size.x - (wa.position.x + wa.size.x), win_size.y - (wa.position.y + wa.size.y))
	var lim := Vector4(win_size.x, win_size.y, win_size.x, win_size.y) * MAX_INSET_FRAC
	for i in range(4):
		if ins[i] < 0.0 or ins[i] > lim[i]:
			ins[i] = 0.0
	return ins


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
	var wa := DisplayServer.get_display_safe_area()
	var mobile := OS.has_feature("mobile")
	if sim_display_safe.size != Vector2i.ZERO:
		wa = sim_display_safe
		mobile = true
		if DisplayServer.get_name() == "headless" and tree and tree.root:
			win_size = Vector2(tree.root.size)
	var k := Vector2.ONE
	if win_size.x > 0 and win_size.y > 0:
		k = vp_size / win_size
	## Baseline padding for portrait thumbs + Dynamic Island / home bar.
	var left := 22.0
	var top := 18.0
	var right := 22.0
	var bottom := 22.0
	if mobile:
		var ins := sane_insets(win_size, Rect2(wa))
		if ins.x > 0.0:
			left = maxf(left, ins.x * k.x + 8.0)
		if ins.y > 0.0:
			top = maxf(top, ins.y * k.y + 6.0)
		if ins.z > 0.0:
			right = maxf(right, ins.z * k.x + 8.0)
		if ins.w > 0.0:
			bottom = maxf(bottom, ins.w * k.y + 10.0)
	if sim_safe != Vector4.ZERO:
		left = maxf(left, sim_safe.x)
		top = maxf(top, sim_safe.y)
		right = maxf(right, sim_safe.z)
		bottom = maxf(bottom, sim_safe.w)
	return Rect2(left, top, vp_size.x - left - right, vp_size.y - top - bottom)


## Squarer screens (iPhone Duo, iPads) under Xogot Play get its run toolbar
## floating over the top-right corner (it ends ~100 UI px down on the Duo).
## There the minimap starts below it and the pause cap moves beside the
## minimap; tall iPhones keep the exact old layout (0 = no overlay).
const OVERLAY_TR_BOTTOM := 108.0


static func overlay_bottom(vp: Vector2) -> float:
	if vp.x <= 0.0 or vp.y <= 0.0:
		return 0.0
	if minf(vp.x, vp.y) / maxf(vp.x, vp.y) < 0.6:
		return 0.0
	return OVERLAY_TR_BOTTOM


## In-run minimap side (UI px); the pause cap lines up with it.
const MINIMAP_SIZE := 135.0


static func minimap_side(vp_w: float) -> float:
	return minf(MINIMAP_SIZE, vp_w * 0.3)


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
