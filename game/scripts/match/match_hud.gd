extends CanvasLayer

const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")
const TouchControlsScene := preload("res://scenes/ui/touch_controls.tscn")
const MinimapScript = preload("res://scripts/ui/minimap.gd")
const ExtractArrowsScript = preload("res://scripts/ui/extract_arrows.gd")

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
@onready var minimap_host: Control = $Root/MinimapHost
@onready var arrows_host: Control = $Root/ExtractArrows

var _toast_time: float = 0.0
var _match: Node = null
var _touch_controls: CanvasLayer = null
var _minimap: Control = null
var _arrows: Control = null
var _buff_label: Label = null


func setup(match_node: Node) -> void:
	_match = match_node
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_mobile_hud()
	_touch_controls = TouchControlsScene.instantiate()
	get_parent().add_child(_touch_controls)
	hint_label.text = "Touch L/R halves = move/aim · FIRE · rare crate buffs · extract arrows"
	if not TouchInput.touch_primary:
		hint_label.text += "  |  WASD · Mouse · E/Q/F · Esc"
	toast_label.text = ""
	_buff_label = Label.new()
	_buff_label.name = "BuffLabel"
	_buff_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_label.position = Vector2(8, 70)
	_buff_label.add_theme_font_size_override("font_size", 14)
	_buff_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	root.add_child(_buff_label)


func setup_nav(player: Node2D, pads: Array, landmarks: Array) -> void:
	_minimap = Control.new()
	_minimap.set_script(MinimapScript)
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minimap_host.add_child(_minimap)
	_minimap.call("setup", player, pads, landmarks)

	_arrows = Control.new()
	_arrows.set_script(ExtractArrowsScript)
	arrows_host.add_child(_arrows)
	_arrows.call("setup", player, pads)
	_arrows.call("set_anchors_and_offsets_preset", Control.PRESET_FULL_RECT)


func set_extract_open(is_open: bool) -> void:
	if _minimap and _minimap.has_method("set_extract_open"):
		_minimap.set_extract_open(is_open)
	if _arrows and _arrows.has_method("set_extract_open"):
		_arrows.set_extract_open(is_open)


func _apply_mobile_hud() -> void:
	var win := DisplayServer.window_get_size()
	var m := MobileLayout.control_safe_margin()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = m.position.x
	root.offset_top = m.position.y
	root.offset_right = -(win.x - (m.position.x + m.size.x))
	root.offset_bottom = -(win.y - (m.position.y + m.size.y))
	MobileLayout.bump_label(phase_label, 24)
	MobileLayout.bump_label(timer_label, 40)
	MobileLayout.bump_label(tl_label, 24)
	MobileLayout.bump_label(ammo_label, 18)
	MobileLayout.bump_label(mount_label, 16)
	MobileLayout.bump_label(stay_label, 15)
	MobileLayout.bump_label(toast_label, 24)
	hp_bar.custom_minimum_size = Vector2(0, 28)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.offset_top = -250.0
	bottom_bar.offset_bottom = -140.0
	hint_label.offset_top = -280.0
	hint_label.offset_bottom = -256.0
	top_bar.offset_top = 4.0
	top_bar.offset_bottom = 56.0
	## Minimap under pause / fill row
	minimap_host.offset_left = -168.0
	minimap_host.offset_top = 78.0
	minimap_host.offset_right = -8.0
	minimap_host.offset_bottom = 234.0


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
	stay_label.text = "Stay ×%.2f · Scrap %d · XP %d · Kills %d · seed %d" % [
		stay, GameState.scrap_found, GameState.xp_this_run, GameState.kills, GameState.run_seed % 100000
	]
	if player and is_instance_valid(player):
		if player.has_method("get_ammo_text"):
			ammo_label.text = player.get_ammo_text()
		if player.has_method("get_mount_text"):
			mount_label.text = player.get_mount_text()


func on_health_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current


func on_buffs_changed(buffs: Dictionary) -> void:
	if _buff_label == null:
		return
	if buffs.is_empty():
		_buff_label.text = ""
		return
	var parts: PackedStringArray = []
	for id in buffs.keys():
		var entry: Dictionary = buffs[id]
		var def: Dictionary = entry.get("def", {})
		var name := str(def.get("name", id))
		var t := int(ceil(float(entry.get("time_left", 0))))
		parts.append("%s %ds" % [name, t])
	_buff_label.text = " · ".join(parts)


func show_toast(msg: String) -> void:
	toast_label.text = msg
	_toast_time = 3.0


func _fmt_time(seconds: float) -> String:
	var s := maxi(0, int(ceil(seconds)))
	return "%d:%02d" % [s / 60, s % 60]
