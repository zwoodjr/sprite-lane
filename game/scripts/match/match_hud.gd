extends CanvasLayer

const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")
const TouchControlsScene := preload("res://scenes/ui/touch_controls.tscn")

@onready var root: Control = $Root
@onready var top_bar: HBoxContainer = $Root/Top
@onready var bottom_bar: VBoxContainer = $Root/Bottom
@onready var phase_label: Label = $Root/Top/PhaseLabel
@onready var timer_label: Label = $Root/Top/TimerLabel
@onready var tl_label: Label = $Root/Top/TLLabel
@onready var hp_bar: ProgressBar = $Root/Bottom/HpBar
@onready var ammo_label: Label = $Root/Bottom/AmmoLabel
@onready var mount_label: Label = $Root/Bottom/MountLabel
@onready var stay_label: Label = $Root/Bottom/StayLabel
@onready var toast_label: Label = $Root/Toast
@onready var hint_label: Label = $Root/Hint

var _toast_time: float = 0.0
var _match: Node = null
var _touch_controls: CanvasLayer = null


func setup(match_node: Node) -> void:
	_match = match_node
	_apply_mobile_hud()
	_touch_controls = TouchControlsScene.instantiate()
	add_child(_touch_controls)
	hint_label.text = "Left stick move · Right stick aim+fire · EXTRACT / ABILITY / MOUNT · PAUSE"
	if not TouchInput.touch_primary:
		hint_label.text += "  |  WASD · Mouse · E/Q/F · Esc"
	toast_label.text = ""


func _apply_mobile_hud() -> void:
	var win := DisplayServer.window_get_size()
	var m := MobileLayout.safe_margin()
	root.offset_left = m.position.x
	root.offset_top = m.position.y
	root.offset_right = -(win.x - (m.position.x + m.size.x))
	root.offset_bottom = -(win.y - (m.position.y + m.size.y))
	## Bigger type for phone readability
	MobileLayout.bump_label(phase_label, 22)
	MobileLayout.bump_label(timer_label, 36)
	MobileLayout.bump_label(tl_label, 22)
	MobileLayout.bump_label(ammo_label, 18)
	MobileLayout.bump_label(mount_label, 16)
	MobileLayout.bump_label(stay_label, 15)
	MobileLayout.bump_label(toast_label, 24)
	hp_bar.custom_minimum_size = Vector2(0, 26)
	## Keep bottom stats above virtual sticks / action row
	bottom_bar.offset_top = -200.0
	bottom_bar.offset_bottom = -110.0
	hint_label.offset_top = -250.0
	hint_label.offset_bottom = -226.0
	top_bar.offset_top = 4.0
	top_bar.offset_bottom = 52.0


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			toast_label.text = ""
	if Input.is_action_just_pressed("pause_menu") or TouchInput.consume_pause():
		GameState.go_main_menu()


func update_match(phase: Dictionary, time_left: float, tl: int, stay: float, player: Node) -> void:
	phase_label.text = str(phase.get("label", ""))
	timer_label.text = _fmt_time(time_left)
	tl_label.text = "TL %d" % tl
	stay_label.text = "Stay ×%.2f · Scrap %d · XP %d · Kills %d" % [
		stay, GameState.scrap_found, GameState.xp_this_run, GameState.kills
	]
	if player and is_instance_valid(player):
		if player.has_method("get_ammo_text"):
			ammo_label.text = player.get_ammo_text()
		if player.has_method("get_mount_text"):
			mount_label.text = player.get_mount_text()


func on_health_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current


func show_toast(msg: String) -> void:
	toast_label.text = msg
	_toast_time = 3.0


func _fmt_time(seconds: float) -> String:
	var s := maxi(0, int(ceil(seconds)))
	return "%d:%02d" % [s / 60, s % 60]
