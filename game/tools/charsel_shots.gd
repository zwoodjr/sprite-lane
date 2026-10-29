extends Node

## Choose Your Wanderer at a given device size / text size / notch insets, with
## the ADMIN chip on (iPhone portrait review). Run with a throwaway XDG_DATA_HOME:
##   xvfb-run godot --path game --rendering-method gl_compatibility --resolution 780x1688 \
##     res://tools/charsel_shots.tscn -- OUT.png TEXT_SIZE(0-2) "l,t,r,b"
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "/tmp/charsel.png"
	var ts := int(a[1]) if a.size() > 1 else 0
	if a.size() > 2 and a[2] != "":
		var p: PackedStringArray = a[2].split(",")
		MobileLayout.sim_safe = Vector4(float(p[0]), float(p[1]), float(p[2]), float(p[3]))
	GameState.onboard_skip = true
	UiTheme.set_text_size(ts)
	Admin.allowed = true
	Admin.call("set_enabled", true)
	Admin.call("_place_chip")
	var inst: Node = (load("res://scenes/ui/character_select.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	for i in range(40):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out)
	get_tree().quit()
