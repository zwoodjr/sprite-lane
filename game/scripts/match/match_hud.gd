extends CanvasLayer

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


func setup(match_node: Node) -> void:
	_match = match_node
	hint_label.text = "WASD move · Mouse aim · LMB shoot · E extract · Q ability · F mount · Esc menu"
	toast_label.text = ""


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			toast_label.text = ""
	if Input.is_action_just_pressed("pause_menu"):
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
