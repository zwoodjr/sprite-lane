extends Node

## Wander extras captures: mode select (daily + weekly), the daily result
## breakdown, and Run History (runs + daily board). The profile on disk is
## put back afterwards.
##   xvfb-run godot --path game --rendering-method gl_compatibility \
##     --resolution 720x1560 res://tools/wanderx_shots.tscn -- OUTDIR

var _out: String = "/tmp/wanderx_shots"


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


func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _scene(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	return inst


func _run() -> void:
	var keep_save := FileAccess.get_file_as_string(GameState.SAVE_PATH) if FileAccess.file_exists(GameState.SAVE_PATH) else ""
	GameState.tutorial_done = true
	GameState.selected_character_id = "ash_rook"
	GameState.selected_mode_id = "drift"
	GameState.weekly_opt_in = true
	var today := GameState.today()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	GameState.daily_runs = {}
	for i in range(1, 30):
		if i % 3 == 2:
			continue
		var d := DailyDefs.date_add(today, -i)
		var ext := rng.randf() < 0.7
		GameState.daily_runs[d] = GameState._clean_daily({"date": d, "score": rng.randi_range(380, 1450) if ext else 0,
			"hero": DailyDefs.hero_for(d), "pet": DailyDefs.pet_for(d), "extracted": ext, "kills": rng.randi_range(20, 90),
			"seconds": rng.randi_range(150, 420), "attempts": rng.randi_range(1, 3), "mods": DustModDefs.for_date(d)})
	GameState.run_history = []
	var heroes: Array = CharacterDefs.PLAYABLE_IDS
	var causes := ["Rad Gator", "Coil Spider", "Dust storm", "Raider Brute", "Abandoned"]
	var items := [["Patched Scrap Vest", "common"], ["Sturdy Bolt Gloves", "rare"], ["Fine Bell Rifle", "epic"], ["Lamplighter's Coat", "legendary"]]
	for i in range(18):
		var ext := rng.randf() < 0.6
		var it: Array = items[rng.randi_range(0, 3)]
		GameState.push_history({"date": DailyDefs.date_add(today, -(18 - i) / 2), "kind": "daily" if i % 5 == 0 else "wander",
			"tier": 1 + i % 5, "mode": ModeDefs.tier_mode(1 + i % 5)["id"], "hero": heroes[i % heroes.size()], "pet": "noel",
			"extracted": ext, "seconds": rng.randi_range(120, 480), "kills": rng.randi_range(12, 120),
			"scrap": rng.randi_range(80, 900) if ext else 0, "best_item": it[0] if rng.randf() < 0.7 else "", "best_rarity": it[1],
			"cause": "" if ext else causes[i % causes.size()], "score": 0, "mods": DustModDefs.for_date(today) if i % 4 == 0 else []})
	GameState.daily_runs.erase(today)

	## 1. Mode select: daily + weekly cards on top of the tier map.
	var ms := _scene("res://scenes/ui/mode_select.tscn")
	await _wait(40)
	await _snap("1_mode_select")
	ms.queue_free()
	await _wait(2)

	## 2. A daily run that extracts → the result breakdown.
	GameState.arm_daily()
	GameState.begin_run()
	GameState.kills = 64
	GameState.scrap_found = 420
	GameState.run_time = 333.0
	GameState.loot_mult = 1.9
	GameState.on_extract_success()
	var rs := _scene("res://scenes/ui/result_screen.tscn")
	await _wait(220)
	await _snap("2_daily_result")
	rs.queue_free()
	await _wait(2)

	## 3 + 4. Run History: runs + the 30-day daily board.
	GameState.history_from = "logbook"
	GameState.history_tab = "runs"
	var hs := _scene("res://scenes/ui/run_history.tscn")
	await _wait(30)
	await _snap("3_history_runs")
	hs.call("show_tab", "daily")
	await _wait(20)
	await _snap("4_history_daily")
	if keep_save != "":
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		f.store_string(keep_save)
		f.close()
	get_tree().quit()
