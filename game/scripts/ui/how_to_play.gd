extends "res://scripts/ui/menu_base.gd"

const HelpViewer = preload("res://scripts/ui/help_viewer.gd")


func build(c: VBoxContainer) -> void:
	c.add_child(header("HOW TO PLAY", GameState.go_main_menu))
	var viewer: VBoxContainer = VBoxContainer.new()
	viewer.set_script(HelpViewer)
	viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewer.finished.connect(GameState.go_main_menu)
	c.add_child(viewer)
