extends Control

const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")

@onready var title: Label = %Title
@onready var body: Label = %Body
@onready var meta: Label = %Meta
@onready var again_btn: Button = $Center/Row/AgainButton
@onready var menu_btn: Button = $Center/Row/MenuButton


func _ready() -> void:
	MobileLayout.polish_menu(self, [again_btn, menu_btn], title)
	MobileLayout.bump_label(body, 17)
	MobileLayout.bump_label(meta, 14)
	if GameState.extracted:
		title.text = "EXTRACT SUCCESS"
		title.add_theme_color_override("font_color", Color(0.85, 0.9, 0.45))
	else:
		title.text = "WIPE"
		title.add_theme_color_override("font_color", Color(0.9, 0.35, 0.28))
	body.text = GameState.result_summary
	meta.text = "Mode: %s · Character: %s · TL %d · Skips %d · Kills %d · Stay ×%.2f\nAccount XP %d · Garage Tokens %d" % [
		GameState.get_mode().get("display_name", "?"),
		GameState.get_character().get("display_name", "?"),
		GameState.threat_level,
		GameState.windows_skipped,
		GameState.kills,
		GameState.stay_bonus,
		GameState.account_xp,
		GameState.garage_tokens,
	]


func _on_again_pressed() -> void:
	GameState.go_mode_select()


func _on_menu_pressed() -> void:
	GameState.go_main_menu()
