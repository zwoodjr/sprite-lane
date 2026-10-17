extends Node

## Shared touch / virtual-control state. Keyboard/mouse still work via InputMap;
## player merges both. Always available — sticks show when touch is primary.

signal extract_pressed
signal ability_pressed
signal mount_pressed
signal pause_pressed

var move_vector: Vector2 = Vector2.ZERO
var aim_vector: Vector2 = Vector2.ZERO
var wants_fire: bool = false

var _extract_just: bool = false
var _ability_just: bool = false
var _mount_just: bool = false
var _pause_just: bool = false

## True when we should prefer on-screen controls (iPhone / touch displays).
var touch_primary: bool = true


func _ready() -> void:
	touch_primary = _detect_touch_primary()


func _detect_touch_primary() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android"):
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	## Godot-on-iPhone editor often reports touchscreen; also treat small windows as mobile.
	var size := DisplayServer.window_get_size()
	return mini(size.x, size.y) > 0 and maxi(size.x, size.y) <= 1400 and DisplayServer.is_touchscreen_available()


func set_move(v: Vector2) -> void:
	move_vector = v.limit_length(1.0)


func set_aim(v: Vector2, firing: bool) -> void:
	if v.length() > 0.15:
		aim_vector = v.normalized()
		wants_fire = firing
	else:
		aim_vector = Vector2.ZERO
		wants_fire = false


func clear_sticks() -> void:
	move_vector = Vector2.ZERO
	aim_vector = Vector2.ZERO
	wants_fire = false


func pulse_extract() -> void:
	_extract_just = true
	extract_pressed.emit()


func pulse_ability() -> void:
	_ability_just = true
	ability_pressed.emit()


func pulse_mount() -> void:
	_mount_just = true
	mount_pressed.emit()


func pulse_pause() -> void:
	_pause_just = true
	pause_pressed.emit()


func consume_extract() -> bool:
	var v := _extract_just
	_extract_just = false
	return v


func consume_ability() -> bool:
	var v := _ability_just
	_ability_just = false
	return v


func consume_mount() -> bool:
	var v := _mount_just
	_mount_just = false
	return v


func consume_pause() -> bool:
	var v := _pause_just
	_pause_just = false
	return v


func get_move() -> Vector2:
	var k := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if k.length() > 0.01:
		return k
	return move_vector


func is_firing() -> bool:
	return wants_fire or Input.is_action_pressed("shoot")
