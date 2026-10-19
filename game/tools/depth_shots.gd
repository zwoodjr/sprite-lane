extends Node

## Depth Update review shots (needs a display, e.g. xvfb-run):
##   xvfb-run godot --path game --rendering-method gl_compatibility --resolution 720x1560 \
##     res://tools/depth_shots.tscn -- OUTDIR e1
## One function per phase; the player's save is restored afterwards.

var _out: String = "/tmp/shots"
var _phase: String = "e1"
var _save: String = ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_phase = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_save = FileAccess.get_file_as_string(GameState.SAVE_PATH) if FileAccess.file_exists(GameState.SAVE_PATH) else ""
	_run.call_deferred()


func _run() -> void:
	TouchInput.touch_primary = true
	GameState.tutorial_done = true
	await call("_shots_" + _phase.to_lower())
	get_tree().paused = false
	if _save != "":
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(_save)
			f.close()
	get_tree().quit()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name, " ", img.get_size())


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _open(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	await _frames(20)
	return inst


func _match(mode: String, hero: String) -> Node:
	GameState.selected_mode_id = mode
	GameState.selected_character_id = hero
	GameState.fast_timers = false
	GameState.begin_run()
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	await _frames(30)
	return m


func _pause_menu() -> Node:
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.has_method("show_pack"):
			return n
	return null


## E1: Apothecary tab, a Blight run with fog / crates / pack / exposure, backpack view.
func _shots_e1() -> void:
	GameState.best_tier_extracted = 9
	GameState.camp = {HangarDefs.station_id("sister_cinder"): 2, "backpack": 1}
	GameState.ingredients = {"herb": 7, "plague_gland": 3, "dust_shard": 2, "machine_oil": 1, "medicine": 1}
	GameState.tonics = {"menders": 2, "ward": 1}
	GameState.tonic_loadout = ["menders", "ward"]
	GameState.account_scrap = 860
	var h := await _open("res://scenes/ui/hangar.tscn")
	h.call("show_tab", "brew")
	await _frames(15)
	await _snap("e1_brew")
	var sc := h.find_child("HangarScroll", true, false) as ScrollContainer
	if sc:
		sc.scroll_vertical = 100000
		await _frames(6)
		await _snap("e1_brew_scrolled")
	h.call("show_tab", "camp")
	await _frames(10)
	if sc:
		sc.scroll_vertical = 100000
		await _frames(6)
	await _snap("e1_camp_backpack")
	h.queue_free()
	var cs := await _open("res://scenes/ui/character_select.tscn")
	await _snap("e1_character_select")
	cs.queue_free()
	var m := await _match("blight", "sister_cinder")
	var player: Node2D = m.get_node("World/Player")
	var world: Node = m.get_node("World")
	m.get_node("PlagueSystem").call("spawn_zone", player.global_position + Vector2(-90, 140), 150.0)
	HaulPickup.spawn(world, player.global_position + Vector2(120, -60), "medicine", 1, false)
	for id in ["herb", "plague_gland", "dust_shard", "machine_oil"]:
		HaulPickup.spawn(world, player.global_position + Vector2(randf_range(-160, 160), randf_range(60, 200)), id)
	GameState.add_to_pack("medicine")
	GameState.add_to_pack("herb", 2)
	GameState.exposure = 55.0
	await _frames(40)
	await _snap("e1_match")
	m.get_node("HUD").call("_open_pause")
	await _frames(6)
	await _snap("e1_pause")
	var pm := _pause_menu()
	if pm:
		pm.call("show_pack")
		await _frames(8)
		await _snap("e1_backpack")
		pm.call("close")
	m.queue_free()
	await _frames(3)
