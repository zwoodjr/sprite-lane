extends Node

## Polish-pass screenshots: every menu, the level-up picker, HUD, pause and
## results at 720x1280 (needs a display, e.g. xvfb-run + gl_compatibility).
##   godot --path game --rendering-method gl_compatibility res://tools/polish_shots.tscn -- OUTDIR [menus|match|all]

var _out: String = "/tmp/polish"
var _what: String = "all"


func _ready() -> void:
	GameState.onboard_skip = true ## dev tool: every system on
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_what = args[1]
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
	await _snap(name)
	return inst


func _free(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()
	await get_tree().process_frame


func _run() -> void:
	var keep_tut := GameState.tutorial_done
	GameState.tutorial_done = true
	if _what in ["all", "menus"]:
		await _free(await _show("res://scenes/ui/main_menu.tscn", "01_main_menu"))
		await _free(await _show("res://scenes/ui/mode_select.tscn", "02_mode_select"))
		for hid in ["sister_cinder", "helm_wisp"]:
			GameState.selected_character_id = hid
			await _free(await _show("res://scenes/ui/character_select.tscn", "03_character_select_%s" % hid))
		await _free(await _show("res://scenes/ui/how_to_play.tscn", "04_how_to_play"))
		await _free(await _show("res://scenes/ui/settings_menu.tscn", "05_settings"))
		await _free(await _show("res://scenes/ui/hangar.tscn", "06_hangar"))
		GameState.extracted = true
		GameState.wiped = false
		GameState.payout_this_run = 342
		await _free(await _show("res://scenes/ui/result_screen.tscn", "12_result_extracted"))
		GameState.extracted = false
		GameState.wiped = true
		GameState.payout_this_run = 18
		await _free(await _show("res://scenes/ui/result_screen.tscn", "13_result_wiped"))
	if _what in ["all", "match"]:
		GameState.selected_character_id = "pebble"
		TouchInput.touch_primary = true
		GameState.fast_timers = true
		GameState.begin_run()
		var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(m)
		get_tree().current_scene = m
		var player: Node2D = m.get_node("World/Player")
		await _wait(90)
		## Scatter some loot + pickups near the hero for the loot shot.
		var w: Node = m.get_node("World")
		var pu := load("res://scenes/entities/powerup_pickup.tscn") as PackedScene
		var k := 0
		for d in PowerupDefs.POOL:
			var p: Node2D = pu.instantiate()
			p.position = player.global_position + Vector2(-150 + k * 100, -150)
			w.add_child(p)
			p.call("setup", (d as Dictionary).duplicate(true))
			k += 1
		var ld := load("res://scripts/entities/loot_drop.gd") as GDScript
		ld.call("spawn_burst", w, player.global_position + Vector2(-60, 140), "scrap", 5, 5.0)
		ld.call("spawn_burst", w, player.global_position + Vector2(60, 140), "xp", 5, 5.0)
		await _wait(30)
		await _snap("07_match_hud")
		await _wait(200)
		await _snap("08_match_combat")
		var hud: Node = m.get_node("HUD")
		hud.call("_open_pause")
		await _wait(12)
		await _snap("10_pause")
		get_tree().paused = false
		await _wait(2)
		GameState.fast_timers = false
		var picker := CanvasLayer.new()
		picker.set_script(load("res://scripts/ui/run_upgrade_picker.gd"))
		get_tree().root.add_child(picker)
		picker.call("open", 2, Progression.roll_run_choices())
		await _wait(30)
		await _snap("09_levelup_picker")
		picker.queue_free()
		get_tree().paused = false
		await _free(m)
	GameState.tutorial_done = keep_tut
	get_tree().quit()
