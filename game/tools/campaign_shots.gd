extends Node

## Campaign review captures: mode select, campaign map, and per level the
## intro card, a dialogue line, the objective tracker in play, the boss intro.
##   xvfb-run godot --path game --rendering-method gl_compatibility \
##     --resolution 720x1560 res://tools/campaign_shots.tscn -- OUTDIR [level,level,...] [map_progress_level]
## Run with a throwaway XDG_DATA_HOME: it writes campaign progress.

var _out: String = "/tmp/campaign_shots"
var _levels: Array = []
var _map_at: String = "l03_lights_out"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1 and str(args[1]) != "":
		_levels = str(args[1]).split(",")
	if args.size() > 2:
		_map_at = str(args[2])
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


func _clear() -> void:
	get_tree().paused = false
	for n in get_tree().root.get_children():
		if n != self and not (n.name in ["GameState", "TouchInput", "DisplayFit", "Juice", "UiTheme", "Admin", "Sound"]):
			n.queue_free()
	await _wait(3)


func _run() -> void:
	GameState.tutorial_done = true
	GameState.campaign = GameState._fresh_campaign()
	GameState.campaign_debug_unlock_to(_map_at)
	var mc := _scene("res://scenes/ui/mode_choice.tscn")
	await _wait(40)
	await _snap("00_mode_choice")
	mc.queue_free()
	await _wait(2)
	var cm := _scene("res://scenes/ui/campaign_map.tscn")
	await _wait(50)
	await _snap("00_campaign_map")
	cm.queue_free()
	await _wait(2)
	for id in _levels:
		await _level(str(id))
	get_tree().quit()


func _level(id: String) -> void:
	await _clear()
	Admin.god = true
	GameState.campaign = GameState._fresh_campaign()
	GameState.campaign_debug_unlock_to(id)
	GameState.campaign_autoplay = false
	GameState.campaign_autoplay_exit = false
	if not GameState.prepare_campaign_level(id):
		print("SKIP ", id)
		return
	var m := _scene(CampaignDefs.MATCH_SCENE)
	await _wait(45)
	await _snap("%s_1_intro" % id)
	var card: Node = m.get("card")
	card.call("_choose", "begin")
	var story: Node = m.get("story")
	## Step through the intro to a line with a speaker, let it type, snap.
	var shot := false
	for k in range(40):
		await _wait(6)
		if not bool(story.get("active")):
			break
		var np: Control = story.get("_name_plate")
		if np.visible and k >= 1:
			## Let the line type out fully, then snap.
			await _wait(90)
			await _snap("%s_2_dialogue" % id)
			shot = true
			break
		story.set("_tap", true)
		await _wait(2)
		story.set("_tap", true)
	if bool(story.get("active")):
		story.set("auto", true)
		story.set("_tap", true)
	for k in range(200):
		if not bool(story.get("active")):
			break
		await _wait(1)
	story.set("auto", true)
	await _wait(120)
	await _snap("%s_3_objective" % id)
	if not shot:
		print("NO_DIALOGUE_SHOT ", id)
	## Boss intro: skip ahead to the boss objective.
	var runner: Node = m.get("runner")
	var has_boss := false
	for o in GameState.campaign_level().get("objectives", []):
		if str(o.get("type", "")) == "boss":
			has_boss = true
	if has_boss:
		var pl: Node2D = m.get_node("World/Player")
		for k in range(40):
			var o: Dictionary = runner.get("obj")
			if str(o.get("type", "")) == "boss":
				## Stand where the fight happens, a little south of the boss.
				var bat: Vector2 = (o.get("boss", {}) as Dictionary).get("at", pl.global_position)
				pl.global_position = bat + Vector2(0, 330)
				break
			if not bool(runner.get("busy")):
				runner.call("debug_complete")
				var tg: Vector2 = runner.call("current_target")
				if tg != Vector2.INF:
					pl.global_position = tg + Vector2(0, 60)
			await _wait(10)
		for k in range(60):
			if runner.get("_boss") != null:
				break
			await _wait(2)
		await _wait(40)
		## A level-up card can pop from the teleport kills: take a card first.
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("pick_index") and bool(n.call("is_open")):
				n.call("pick_index", 0)
		await _wait(30)
		await _snap("%s_4_boss" % id)
	await _clear()
