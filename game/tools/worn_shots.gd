extends Node

## Art-direction review shots: every menu screen, the hangar at rank 0 and max,
## pause, results and the level-up picker (needs a display, e.g. xvfb-run).
##   godot --path game --rendering-method gl_compatibility res://tools/worn_shots.tscn -- OUTDIR

var _out: String = "/tmp/worn"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name)


func _wait(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _show(path: String, name: String, frames: int = 40) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	await _wait(frames)
	if name != "":
		await _snap(name)
	return inst


func _free(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()
	await get_tree().process_frame


func _run() -> void:
	var keep_tut := GameState.tutorial_done
	var keep_camp: Dictionary = GameState.camp.duplicate()
	GameState.tutorial_done = true
	GameState.selected_character_id = "sister_cinder"
	await _free(await _show("res://scenes/ui/main_menu.tscn", "01_main_menu"))
	await _free(await _show("res://scenes/ui/character_select.tscn", "02_character_select"))
	await _free(await _show("res://scenes/ui/mode_select.tscn", "03_tier_select"))
	GameState.camp = {}
	await _free(await _show("res://scenes/ui/hangar.tscn", "04_hangar_rank0"))
	for id in HangarDefs.all_ids():
		GameState.camp[id] = 1
	await _free(await _show("res://scenes/ui/hangar.tscn", "04b_hangar_rank1"))
	for id in HangarDefs.all_ids():
		GameState.camp[id] = mini(3, HangarDefs.max_rank(str(id)))
	await _free(await _show("res://scenes/ui/hangar.tscn", "04c_hangar_rank3"))
	GameState.camp = {}
	for id in HangarDefs.all_ids():
		GameState.camp[id] = HangarDefs.max_rank(str(id))
	var h: Node = await _show("res://scenes/ui/hangar.tscn", "05_hangar_max")
	h.call("show_tab", "stash")
	await _wait(20)
	await _snap("05b_hangar_stash")
	await _free(h)
	await _wait(10)
	GameState.camp = keep_camp
	await _free(await _show("res://scenes/ui/loadout.tscn", "06_gear"))
	await _free(await _show("res://scenes/ui/logbook.tscn", "07_logbook"))
	GameState.extracted = true
	GameState.wiped = false
	GameState.payout_this_run = 342
	await _free(await _show("res://scenes/ui/result_screen.tscn", "08_results"))
	GameState.selected_character_id = "pebble"
	TouchInput.touch_primary = true
	GameState.begin_run()
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	await _wait(60)
	m.get_node("HUD").call("_open_pause")
	await _wait(12)
	await _snap("09_pause")
	get_tree().paused = false
	await _wait(2)
	var picker := CanvasLayer.new()
	picker.set_script(load("res://scripts/ui/run_upgrade_picker.gd"))
	get_tree().root.add_child(picker)
	picker.call("open", 2, Progression.roll_run_choices())
	await _wait(30)
	await _snap("10_levelup_picker")
	picker.queue_free()
	get_tree().paused = false
	await _free(m)
	GameState.tutorial_done = keep_tut
	get_tree().quit()
