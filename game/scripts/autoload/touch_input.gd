extends Node

## Shared touch / virtual-control state. Keyboard/mouse still work via InputMap.
##
## Default phone scheme (single stick / survivor):
##   - One MOVE stick. While moving, aim + auto-fire along the move vector.
##   - Idle: keep last facing; nearest-enemy auto-aim only as idle fallback / FIRE hold.
## Optional twin_stick setting restores classic left-move / right-aim sticks.

signal extract_pressed
signal ability_pressed
signal mount_pressed
signal pause_pressed
signal dash_pressed

const AIM_FIRE_THRESHOLD := 0.32
## Move stick must push past this to count as run-aim (pairs with larger hero sprites).
const MOVE_FIRE_THRESHOLD := 0.22

var move_vector: Vector2 = Vector2.ZERO
var aim_vector: Vector2 = Vector2.ZERO
var aim_strength: float = 0.0
var fire_held: bool = false
var aim_stick_firing: bool = false

var _extract_just: bool = false
var _ability_just: bool = false
var _mount_just: bool = false
var _pause_just: bool = false
var _dash_just: bool = false

var touch_primary: bool = true

## Legacy accessor used by older code — now backed by settings.
var auto_aim: bool:
	get:
		return bool(GameState.settings.get("auto_aim", true))
	set(v):
		GameState.set_setting("auto_aim", v)


func _ready() -> void:
	touch_primary = _detect_touch_primary()


func _detect_touch_primary() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android"):
		return true
	return DisplayServer.is_touchscreen_available()


func is_single_stick() -> bool:
	return not bool(GameState.settings.get("twin_stick", false))


func is_auto_fire() -> bool:
	return bool(GameState.settings.get("auto_fire", true))


func set_move(v: Vector2) -> void:
	move_vector = v.limit_length(1.0)


func set_aim(v: Vector2, _legacy: bool = false) -> void:
	aim_strength = v.length()
	if aim_strength > 0.05:
		aim_vector = v.normalized()
	else:
		aim_vector = Vector2.ZERO
	aim_stick_firing = (
		bool(GameState.settings.get("aim_autofire", true))
		and aim_strength >= AIM_FIRE_THRESHOLD
	)


func set_fire_held(held: bool) -> void:
	fire_held = held


func clear_sticks() -> void:
	move_vector = Vector2.ZERO
	aim_vector = Vector2.ZERO
	aim_strength = 0.0
	aim_stick_firing = false
	fire_held = false


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


func pulse_dash() -> void:
	_dash_just = true
	dash_pressed.emit()


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


func consume_dash() -> bool:
	var v := _dash_just
	_dash_just = false
	return v or Input.is_action_just_pressed("dash")


func get_move() -> Vector2:
	var k := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if k.length() > 0.01:
		return k
	return move_vector


## True when the move stick/keys are pushed hard enough to drive run-aim.
func is_move_aiming() -> bool:
	return get_move().length() >= MOVE_FIRE_THRESHOLD


func is_firing() -> bool:
	if fire_held or aim_stick_firing or Input.is_action_pressed("shoot"):
		return true
	## Single-stick: auto-fire while running (aim = move direction).
	if is_single_stick() and is_auto_fire() and is_move_aiming():
		return true
	return false


## True when the player is shooting via the FIRE button only (no stick aim),
## which is when idle auto-aim should pick a target.
func is_button_firing() -> bool:
	return fire_held and not aim_stick_firing and not is_move_aiming()
