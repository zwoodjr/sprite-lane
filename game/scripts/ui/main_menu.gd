extends Control

const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")

@onready var subtitle: Label = %Subtitle
@onready var account_label: Label = %AccountLabel
@onready var deploy_btn: Button = $Center/DeployButton
@onready var quit_btn: Button = $Center/QuitButton
@onready var title: Label = $Center/Title


func _ready() -> void:
	MobileLayout.polish_menu(self, [deploy_btn, quit_btn], title)
	MobileLayout.bump_label(subtitle, 16)
	MobileLayout.bump_label(account_label, 13)
	subtitle.text = "Stay longer. Risk more. Extract richer."
	account_label.text = "Account XP %d · Garage Tokens %d · Extracts %d · Mount tier %d" % [
		GameState.account_xp,
		GameState.garage_tokens,
		GameState.successful_extracts,
		GameState.mount_unlock_tier,
	]
	var platform := "iPhone" if TouchInput.touch_primary else "PC"
	subtitle.text += "\n(%s · landscape · dual-stick ready)" % platform


func _on_deploy_pressed() -> void:
	GameState.go_mode_select()


func _on_quit_pressed() -> void:
	get_tree().quit()
