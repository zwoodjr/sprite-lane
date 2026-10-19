extends Node

## Shared touch / virtual-control state. Keyboard still works via InputMap.
##
## Phone scheme: one floating MOVE stick (left 60% of the screen). Attacks are
## automatic — the hero fires / swings at the closest enemy in weapon range —
## so the right thumb only has DASH and ABILITY.

signal ability_pressed
signal pause_pressed
signal dash_pressed
## Emitted by clear_sticks() so TouchControls drops its tracked fingers too.
signal sticks_cleared

var move_vector: Vector2 = Vector2.ZERO

var _ability_just: bool = false
var _pause_just: bool = false
var _dash_just: bool = false

var touch_primary: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	touch_primary = _detect_touch_primary()
	if touch_primary:
		_strip_mouse_bindings()


func _detect_touch_primary() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android"):
		return true
	return DisplayServer.is_touchscreen_available()


## iOS emulates mouse clicks from touches, so a mouse-bound action fired on ANY
## tap. On touch-first devices, actions are keyboard + on-screen controls only.
func _strip_mouse_bindings() -> void:
	for action in InputMap.get_actions():
		for ev in InputMap.action_get_events(action):
			if ev is InputEventMouseButton:
				InputMap.action_erase_event(action, ev)


## Auto-pause when the app goes to the background (iOS home swipe / call).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		clear_sticks()
		var tree := get_tree()
		if tree == null or tree.paused:
			return
		var scene := tree.current_scene
		if scene != null and scene.has_method("request_auto_pause"):
			scene.call("request_auto_pause")


func set_move(v: Vector2) -> void:
	move_vector = v.limit_length(1.0)


func clear_sticks() -> void:
	move_vector = Vector2.ZERO
	sticks_cleared.emit()


func pulse_ability() -> void:
	_ability_just = true
	ability_pressed.emit()


func pulse_pause() -> void:
	_pause_just = true
	pause_pressed.emit()


func pulse_dash() -> void:
	_dash_just = true
	dash_pressed.emit()


func consume_ability() -> bool:
	var v := _ability_just
	_ability_just = false
	return v


func consume_pause() -> bool:
	var v := _pause_just
	_pause_just = false
	return v


func consume_dash() -> bool:
	var v := _dash_just
	_dash_just = false
	return v or Input.is_action_just_pressed("dash")


func get_move() -> Vector2:
	var k := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if k.length() > 0.01:
		return k
	return move_vector
