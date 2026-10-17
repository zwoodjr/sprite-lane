extends Control

@onready var subtitle: Label = %Subtitle
@onready var account_label: Label = %AccountLabel


func _ready() -> void:
	subtitle.text = "Stay longer. Risk more. Extract richer."
	account_label.text = "Account XP %d · Garage Tokens %d · Extracts %d · Mount tier %d" % [
		GameState.account_xp,
		GameState.garage_tokens,
		GameState.successful_extracts,
		GameState.mount_unlock_tier,
	]


func _on_deploy_pressed() -> void:
	GameState.go_mode_select()


func _on_quit_pressed() -> void:
	get_tree().quit()
