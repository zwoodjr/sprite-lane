extends Control

const ModeDefs = preload("res://scripts/data/mode_defs.gd")
const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")

@onready var easy_btn: Button = %EasyButton
@onready var medium_btn: Button = %MediumButton
@onready var details: Label = %Details
@onready var fast_check: CheckBox = %FastTimers
@onready var next_btn: Button = $Center/Row/NextButton
@onready var back_btn: Button = $Center/Row/BackButton
@onready var title: Label = $Center/Title


func _ready() -> void:
	MobileLayout.polish_menu(self, [easy_btn, medium_btn, next_btn, back_btn], title)
	MobileLayout.bump_label(details, 15)
	fast_check.add_theme_font_size_override("font_size", 16)
	fast_check.custom_minimum_size = Vector2(0, 44)
	fast_check.button_pressed = GameState.fast_timers
	_refresh()


func _refresh() -> void:
	var mode := GameState.get_mode()
	var phases: Array = mode["phases"]
	var total := 0.0
	for p in phases:
		total += float(p["duration"])
	if GameState.fast_timers:
		total *= GameState.FAST_TIMER_SCALE
	details.text = "%s — ~%d min design · phases %d · payout ×%.2f · enemy HP %.0f%%\nInsurance slots: %d · TL step ×%.2f%s" % [
		mode["display_name"],
		int(mode["target_minutes"]),
		phases.size(),
		float(mode["payout_mult"]),
		float(mode["enemy_hp"]) * 100.0,
		int(mode["insurance_slots"]),
		float(mode["tl_step_size"]),
		"\n(Fast timers ON — ~%.0fs total)" % total if GameState.fast_timers else "",
	]
	easy_btn.text = "Easy (5 min)" + (" ✓" if GameState.selected_mode_id == ModeDefs.EASY_ID else "")
	medium_btn.text = "Medium (10 min)" + (" ✓" if GameState.selected_mode_id == ModeDefs.MEDIUM_ID else "")


func _on_easy_pressed() -> void:
	GameState.selected_mode_id = ModeDefs.EASY_ID
	_refresh()


func _on_medium_pressed() -> void:
	GameState.selected_mode_id = ModeDefs.MEDIUM_ID
	_refresh()


func _on_fast_toggled(pressed: bool) -> void:
	GameState.fast_timers = pressed
	_refresh()


func _on_next_pressed() -> void:
	GameState.go_character_select()


func _on_back_pressed() -> void:
	GameState.go_main_menu()
