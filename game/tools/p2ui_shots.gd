extends Node

## P2 readability captures: HUD, main menu, hangar, gear screen, settings.
##   xvfb-run godot --path game --rendering-method gl_compatibility \
##     --resolution 720x1560 res://tools/p2ui_shots.tscn -- OUTDIR [text_size]

var _out: String = "/tmp/p2ui_shots"


func _ready() -> void:
	GameState.onboard_skip = true ## dev tool: every system on
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1 and UiTheme.has_method("set_text_size"):
		UiTheme.call("set_text_size", int(args[1]))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name)


func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _scene(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	return inst


func _show(path: String, name: String, frames: int = 40) -> void:
	var inst := _scene(path)
	await _wait(frames)
	await _snap(name)
	inst.queue_free()
	await get_tree().process_frame


func _run() -> void:
	GameState.tutorial_done = true
	GameState.selected_character_id = "ash_rook"
	GameState.account_scrap = 1240
	GameState.account_xp = 900
	GameState.successful_extracts = 7
	GameState.best_payout = 512
	GameState.total_runs = 9
	await _show("res://scenes/ui/main_menu.tscn", "2_menu", 60)
	var h := _scene("res://scenes/ui/hangar.tscn")
	h.call("show_tab", "camp")
	await _wait(30)
	await _snap("3_hangar")
	h.queue_free()
	await _wait(2)
	var lo := _scene("res://scenes/ui/loadout.tscn")
	await _wait(20)
	lo.call("select_slot", "head")
	await _wait(10)
	await _snap("4_gear")
	lo.queue_free()
	await _wait(2)
	await _show("res://scenes/ui/settings_menu.tscn", "5_settings")
	TouchInput.touch_primary = true
	GameState.begin_run()
	var m := _scene("res://scenes/match/match.tscn")
	await _wait(90)
	await _snap("1_hud")
	get_tree().quit()
