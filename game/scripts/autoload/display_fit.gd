extends Node

## Maximize the game viewport on phone / Xogot Play.
## Limitation: Xogot editor chrome around the Play viewport cannot be removed
## from game code — FILL / fullscreen only affects the OS window when allowed.

var _filled: bool = true


func _ready() -> void:
	get_tree().root.size_changed.connect(_on_size_changed)
	call_deferred("apply_startup_fill")


func apply_startup_fill() -> void:
	_try_fullscreen(true)
	_sync_stretch()
	_filled = true


func toggle_fill_screen() -> void:
	_filled = not _filled
	_try_fullscreen(_filled)
	_sync_stretch()


func is_filled() -> bool:
	return _filled


func _try_fullscreen(enable: bool) -> void:
	if enable:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _sync_stretch() -> void:
	var root := get_tree().root as Window
	if root == null:
		return
	## Match project.godot: canvas_items + expand so the scene fills the host viewport.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_factor = 1.0


func _on_size_changed() -> void:
	_sync_stretch()
