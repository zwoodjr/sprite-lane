extends Node

## Capture of the RUN INTERRUPTED prompt (main menu after a force quit).
##   xvfb-run godot --path game --rendering-method gl_compatibility \
##     --resolution 720x1560 res://tools/resume_shot.tscn -- OUT.png
## Leaves the player's save as it found it.

var _out: String = "/tmp/resume_prompt.png"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_run.call_deferred()


func _read(p: String) -> String:
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


func _put(p: String, text: String) -> void:
	if text == "":
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
		return
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _run() -> void:
	var keep_main := _read(GameState.SAVE_PATH)
	var keep_bak := _read(GameState.SAVE_BAK_PATH)
	var hero := "ash_rook"
	GameState.selected_character_id = hero
	GameState.selected_mode_id = "drift"
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for pair in [[GearDefs.make_weapon(hero, "epic", rng), "weapon"], [GearDefs.make_gear("head", "rare", rng), "head"]]:
		GameState.add_to_stash(pair[0])
		GameState.equip(hero, str(pair[1]), int(GameState.stash[GameState.stash.size() - 1]["uid"]))
	GameState.begin_run(false)
	GameState.run_level = 7
	GameState.live_run = {"id": 1, "mode": "wander", "level": "", "tier_mode": "drift", "hero": hero, "pet": GameState.selected_pet_id, "started": 0, "resumes": 0}
	GameState.live_run_snapshot()
	var snap := GameState.read_live_snapshot()
	snap["match"] = {"match_time": 412.0, "phase_index": 3, "hp": 64.0, "max_hp": 120.0}
	_put(GameState.RUN_PATH, JSON.stringify(snap))
	var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	for i in range(60):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out)
	print("SHOT ", _out)
	GameState.live_run = {}
	_put(GameState.RUN_PATH, "")
	_put(GameState.SAVE_PATH, keep_main)
	_put(GameState.SAVE_BAK_PATH, keep_bak)
	get_tree().quit(0)
