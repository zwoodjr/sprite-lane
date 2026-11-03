extends Node

## Maximize the game viewport on phone / Xogot Play, and keep it fitted while
## the window changes size (iPhone Duo fold / unfold, rotation).
## Limitation: Xogot editor chrome around the Play viewport cannot be removed
## from game code — FILL / fullscreen only affects the OS window when allowed.
##
## Stretch: canvas_items + expand on the 720x1280 design size. A squarer
## screen (iPhone Duo inner 1878x2670 ~ 1:1.42) widens the UI space to about
## 900x1280; a tall iPhone (390x844) stays 720 wide and gets taller, exactly
## as before. Settings → Render scale 50% switches to viewport stretch at
## the same UI size (base resolution, scaled up).

## Emitted (deferred, once per burst of resizes) after the window settled on
## a new size: screens that build their layout once rebuild on it.
signal layout_changed(size: Vector2)

## Screens squarer than this (short / long side) may rotate: the iPhone Duo
## (0.70 / 0.69) and iPads. Regular iPhones (0.46) stay portrait.
const ROTATE_ASPECT := 0.6

var _filled: bool = true
var _last_size: Vector2 = Vector2.ZERO
var _pending: bool = false
var _orientation: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size_changed.connect(_on_size_changed)
	call_deferred("apply_startup_fill")


func apply_startup_fill() -> void:
	_try_fullscreen(true)
	sync_stretch()
	_filled = true
	_last_size = get_tree().root.get_visible_rect().size


func toggle_fill_screen() -> void:
	_filled = not _filled
	_try_fullscreen(_filled)
	sync_stretch()


func is_filled() -> bool:
	return _filled


func _try_fullscreen(enable: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if enable:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Stretch mode for the current Render scale; the UI size is the same either way.
func sync_stretch() -> void:
	var root := get_tree().root as Window
	if root == null:
		return
	var low := SettingsDefs.render_low()
	var mode := Window.CONTENT_SCALE_MODE_VIEWPORT if low else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if root.content_scale_mode != mode:
		root.content_scale_mode = mode
	if root.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND:
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if root.content_scale_size != Vector2i(720, 1280):
		root.content_scale_size = Vector2i(720, 1280)
	if not is_equal_approx(root.content_scale_factor, 1.0):
		root.content_scale_factor = 1.0
	_sync_orientation()


func render_low() -> bool:
	var root := get_tree().root as Window
	return root != null and root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT


## Squarer screens (the Duo, iPads) follow the device rotation; tall phones
## stay locked to portrait (the single-stick layout).
func _sync_orientation() -> void:
	if not OS.has_feature("mobile"):
		return
	var scr := Vector2(DisplayServer.screen_get_size())
	if scr.x <= 0.0 or scr.y <= 0.0:
		return
	var want := DisplayServer.SCREEN_SENSOR if is_squarish(scr) else DisplayServer.SCREEN_PORTRAIT
	if want != _orientation:
		_orientation = want
		DisplayServer.screen_set_orientation(want)


static func is_squarish(sz: Vector2) -> bool:
	return minf(sz.x, sz.y) / maxf(maxf(sz.x, sz.y), 1.0) >= ROTATE_ASPECT


func _on_size_changed() -> void:
	sync_stretch()
	if _pending:
		return
	_pending = true
	_settle.call_deferred()


func _settle() -> void:
	## Two frames: iOS reports the fold in a couple of steps.
	await get_tree().process_frame
	await get_tree().process_frame
	_pending = false
	var sz := get_tree().root.get_visible_rect().size
	if sz.distance_to(_last_size) < 0.5:
		return
	_last_size = sz
	## A finger that was down during the fold may never get its lift event:
	## clear the stick / buttons only if the touch went away (TouchInput keeps
	## live touches), so a held stick keeps working across the resize.
	layout_changed.emit(sz)
