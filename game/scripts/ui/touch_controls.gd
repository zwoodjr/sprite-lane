extends CanvasLayer

## Phone layout: left MOVE stick · right AIM stick · big FIRE · action row.
## Root ignores mouse so empty space never steals world/camera touches.

const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")

@onready var root: Control = $Root
@onready var left_stick: Control = $Root/LeftStick
@onready var right_stick: Control = $Root/RightStick
@onready var btn_fire: Button = $Root/FireBtn
@onready var btn_extract: Button = $Root/Actions/ExtractBtn
@onready var btn_ability: Button = $Root/Actions/AbilityBtn
@onready var btn_mount: Button = $Root/Actions/MountBtn
@onready var btn_pause: Button = $Root/PauseBtn
@onready var btn_auto: Button = $Root/AutoAimBtn
@onready var btn_fill: Button = $Root/FillBtn


func _ready() -> void:
	layer = 20
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_buttons()
	_apply_safe()
	visible = true
	left_stick.stick_changed.connect(_on_left_stick)
	right_stick.stick_changed.connect(_on_right_stick)
	## Hold-to-fire (button_down / button_up) — more reliable than pressed for thumbs
	btn_fire.button_down.connect(func() -> void: TouchInput.set_fire_held(true))
	btn_fire.button_up.connect(func() -> void: TouchInput.set_fire_held(false))
	btn_extract.pressed.connect(func() -> void: TouchInput.pulse_extract())
	btn_ability.pressed.connect(func() -> void: TouchInput.pulse_ability())
	btn_mount.pressed.connect(func() -> void: TouchInput.pulse_mount())
	btn_pause.pressed.connect(func() -> void: TouchInput.pulse_pause())
	btn_auto.pressed.connect(_toggle_auto_aim)
	btn_fill.pressed.connect(_toggle_fill)
	_refresh_auto_label()
	get_viewport().size_changed.connect(_apply_safe)


func _exit_tree() -> void:
	TouchInput.clear_sticks()
	TouchInput.set_fire_held(false)


func _style_buttons() -> void:
	for b: Button in [btn_fire, btn_extract, btn_ability, btn_mount, btn_pause, btn_auto, btn_fill]:
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_fire.add_theme_font_size_override("font_size", 28)
	btn_fire.modulate = Color(1.0, 0.55, 0.28, 1.0)


func _apply_safe() -> void:
	var m := MobileLayout.control_safe_margin()
	var win := DisplayServer.window_get_size()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	## Pad controls only — do not shrink the game world
	root.offset_left = m.position.x
	root.offset_top = m.position.y
	root.offset_right = -(win.x - (m.position.x + m.size.x))
	root.offset_bottom = -(win.y - (m.position.y + m.size.y))


func _on_left_stick(v: Vector2, _active: bool) -> void:
	TouchInput.set_move(v)


func _on_right_stick(v: Vector2, _active: bool) -> void:
	## Aim only — fire is the FIRE button (or stick+fire legacy off)
	TouchInput.set_aim(v, false)


func _toggle_auto_aim() -> void:
	TouchInput.auto_aim = not TouchInput.auto_aim
	_refresh_auto_label()


func _refresh_auto_label() -> void:
	btn_auto.text = "AUTO-AIM: ON" if TouchInput.auto_aim else "AUTO-AIM: OFF"


func _toggle_fill() -> void:
	DisplayFit.toggle_fill_screen()
	btn_fill.text = "FILL ✓" if DisplayFit.is_filled() else "FILL"
