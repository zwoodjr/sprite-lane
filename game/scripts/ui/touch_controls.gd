extends CanvasLayer

## Dual-stick + action buttons. Left = move, Right = aim + fire while held.

const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")

@onready var root: Control = $Root
@onready var left_stick: Control = $Root/LeftStick
@onready var right_stick: Control = $Root/RightStick
@onready var btn_extract: Button = $Root/Actions/ExtractBtn
@onready var btn_ability: Button = $Root/Actions/AbilityBtn
@onready var btn_mount: Button = $Root/Actions/MountBtn
@onready var btn_pause: Button = $Root/Actions/PauseBtn


func _ready() -> void:
	layer = 20
	_apply_safe()
	## Always show on touch-primary; also show on desktop so scheme can be tested.
	## Hide only if explicitly desktop-without-touch and user prefers mouse — still keep
	## visible by default for iPhone-first; PC can ignore and use WASD/mouse.
	visible = true
	if not TouchInput.touch_primary:
		## Slightly more transparent on PC so mouse play stays clear
		root.modulate = Color(1, 1, 1, 0.7)
	left_stick.stick_changed.connect(_on_left_stick)
	right_stick.stick_changed.connect(_on_right_stick)
	btn_extract.pressed.connect(func() -> void: TouchInput.pulse_extract())
	btn_ability.pressed.connect(func() -> void: TouchInput.pulse_ability())
	btn_mount.pressed.connect(func() -> void: TouchInput.pulse_mount())
	btn_pause.pressed.connect(func() -> void: TouchInput.pulse_pause())
	get_viewport().size_changed.connect(_apply_safe)


func _exit_tree() -> void:
	TouchInput.clear_sticks()


func _apply_safe() -> void:
	var m := MobileLayout.safe_margin()
	var win := DisplayServer.window_get_size()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = m.position.x
	root.offset_top = m.position.y
	root.offset_right = -(win.x - (m.position.x + m.size.x))
	root.offset_bottom = -(win.y - (m.position.y + m.size.y))


func _on_left_stick(v: Vector2, _active: bool) -> void:
	TouchInput.set_move(v)


func _on_right_stick(v: Vector2, active: bool) -> void:
	## Fire while stick is past deadzone (active drag).
	TouchInput.set_aim(v, active and v.length() > 0.12)
