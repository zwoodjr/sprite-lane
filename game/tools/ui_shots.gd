extends Node

## UI review captures (Track D): every menu screen, the level-up picker, the
## in-match HUD, pause and both result treatments.
##   xvfb-run godot --path game --rendering-method gl_compatibility \
##     --resolution 720x1560 res://tools/ui_shots.tscn -- OUTDIR [only]

var _out: String = "/tmp/ui_shots"
var _only: String = ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_only = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _snap(name: String) -> void:
	if _only != "" and not name.begins_with(_only):
		return
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
	if _only != "" and not name.begins_with(_only):
		return
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
	await _show("res://scenes/ui/main_menu.tscn", "01_main_menu", 60)
	await _show("res://scenes/ui/mode_select.tscn", "02_mode_select")
	await _show("res://scenes/ui/character_select.tscn", "03_character_select")
	await _show("res://scenes/ui/prep.tscn", "04_prep")
	await _show("res://scenes/ui/loadout.tscn", "05_loadout")
	if _only == "" or "06".begins_with(_only.substr(0, 2)):
		var lo := _scene("res://scenes/ui/loadout.tscn")
		await _wait(20)
		lo.call("select_slot", "head")
		await _wait(10)
		await _snap("06_loadout_pick")
		lo.queue_free()
	if _only == "" or _only.begins_with("07"):
		var h := _scene("res://scenes/ui/hangar.tscn")
		for t in ["camp", "survivors", "kennel", "stash", "brew", "workshop"]:
			h.call("show_tab", t)
			await _wait(20)
			await _snap("07_hangar_%s" % t)
		h.queue_free()
		await get_tree().process_frame
	await _show("res://scenes/ui/logbook.tscn", "08_logbook")
	await _show("res://scenes/ui/settings_menu.tscn", "09_settings")
	await _show("res://scenes/ui/how_to_play.tscn", "10_how_to_play")
	## Match HUD + level-up picker + pause.
	if _only == "" or _only.begins_with("1"):
		TouchInput.touch_primary = true
		GameState.begin_run()
		var m := _scene("res://scenes/match/match.tscn")
		await _wait(90)
		await _snap("11_match_hud")
		var pk: Node = null
		for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if n.has_method("pick_index"):
				pk = n
		if pk:
			GameState.fast_timers = false
			pk.call("open", 3, Progression.roll_run_choices())
			await _wait(30)
			await _snap("12_levelup")
			pk.call("pick_index", 0)
			await _wait(5)
			pk.call("open", 4, Progression.roll_run_choices())
			await _wait(30)
			await _snap("12b_levelup")
			pk.call("pick_index", 1)
			await _wait(5)
		m.get_node("HUD").call("_open_pause")
		await _wait(15)
		await _snap("13_pause")
		get_tree().paused = false
		m.queue_free()
		await _wait(3)
	## Results: extract and wipe.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	GameState.extracted = true
	GameState.wiped = false
	GameState.kills = 214
	GameState.loot_mult = 1.8
	GameState.result_run_level_reached = 9
	GameState.result_scrap_before = 1240
	GameState.result_scrap_banked = 486
	GameState.account_scrap = 1726
	GameState.payout_this_run = 486
	GameState.result_found = []
	for r in ["common", "rare", "epic", "legendary"]:
		GameState.result_found.append(GearDefs.roll_drop(5, "ash_rook", 0.5, rng, "", r))
	GameState.result_unlocks = ["Hero unlocked: Pebble", "Tier unlocked: The Drift"]
	await _show("res://scenes/ui/result_screen.tscn", "14_result_extract", 30)
	await _show("res://scenes/ui/result_screen.tscn", "14b_result_extract_late", 200)
	GameState.extracted = false
	GameState.wiped = true
	GameState.result_scrap_banked = 48
	GameState.result_scrap_lost = 432
	GameState.result_lost_items = GameState.result_found.duplicate()
	GameState.result_unlocks = []
	GameState.account_scrap = 1288
	await _show("res://scenes/ui/result_screen.tscn", "15_result_wipe", 200)
	get_tree().quit()
