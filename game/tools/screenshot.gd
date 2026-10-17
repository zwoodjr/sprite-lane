extends Node

## Renders screens to PNG for visual review (needs a display, e.g. xvfb-run).
##   xvfb-run godot --path game --rendering-method gl_compatibility res://tools/screenshot.tscn -- OUTDIR
## Captures each menu plus a few moments of a live match.

var _out: String = "/tmp/shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name)


func _show(path: String, name: String, frames: int = 30) -> void:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	for i in range(frames):
		await get_tree().process_frame
	await _snap(name)
	inst.queue_free()
	await get_tree().process_frame


func _run() -> void:
	GameState.tutorial_done = false
	await _show("res://scenes/ui/main_menu.tscn", "01_main_menu")
	await _show("res://scenes/ui/mode_select.tscn", "02_mode_select")
	await _show("res://scenes/ui/character_select.tscn", "03_character_select")
	await _show("res://scenes/ui/how_to_play.tscn", "04_how_to_play")
	await _show("res://scenes/ui/settings_menu.tscn", "05_settings")
	## Match
	TouchInput.touch_primary = true
	GameState.selected_character_id = "sister_cinder"
	GameState.fast_timers = true
	GameState.begin_run()
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	var player: Node2D = m.get_node("World/Player")
	var tc: Node = null
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.has_method("paint_sticks"):
			tc = n
	for f in range(60):
		await get_tree().process_frame
	await _snap("06_match_start_tutorial")
	## Simulate single move stick (run = aim); twin optional
	var vp := get_viewport().get_visible_rect().size
	if tc:
		tc.call("_begin_touch", 0, Vector2(vp.x * 0.5, vp.y * 0.78))
		tc.call("_drag_touch", 0, Vector2(vp.x * 0.5 + 60, vp.y * 0.78 - 40))
		if bool(GameState.settings.get("twin_stick", false)):
			tc.call("_begin_touch", 1, Vector2(vp.x * 0.72, vp.y * 0.72))
			tc.call("_drag_touch", 1, Vector2(vp.x * 0.72 + 70, vp.y * 0.72 - 10))
	for f in range(240):
		var en := get_tree().get_nodes_in_group("enemies")
		if en.size() > 0 and tc:
			var d := ((en[0] as Node2D).global_position - player.global_position).normalized()
			tc.call("_drag_touch", 0, Vector2(vp.x * 0.5, vp.y * 0.78) + d * 70.0)
		await get_tree().process_frame
	await _snap("07_match_combat")
	## Hurt the player to show low-HP vignette and jump to an open window
	player.call("take_damage", 80.0)
	while not bool(m.call("is_extract_open")):
		await get_tree().process_frame
	for f in range(20):
		await get_tree().process_frame
	await _snap("08_extract_open")
	var pads: Array = m.call("get_pads")
	player.global_position = (pads[0] as Node2D).global_position
	for f in range(50):
		await get_tree().process_frame
	await _snap("09_extracting")
	## Pause menu
	m.get_node("HUD").call("_open_pause")
	for f in range(10):
		await get_tree().process_frame
	await _snap("10_pause")
	get_tree().paused = false
	m.queue_free()
	GameState.extracted = true
	GameState.payout_this_run = 342
	GameState.result_summary = "Extracted. Payout 342 Scrap · XP 120 · TL 1"
	await _show("res://scenes/ui/result_screen.tscn", "11_result")
	get_tree().quit()
