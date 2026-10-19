extends Node

## Renders screens to PNG for visual review (needs a display, e.g. xvfb-run).
##   xvfb-run godot --path game --rendering-method gl_compatibility res://tools/screenshot.tscn -- OUTDIR
## Captures each menu plus a few moments of a live match.

var _out: String = "/tmp/shots"
var _char: String = "sister_cinder"
var _match_only: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_char = args[1]
		_match_only = true
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


## `-- OUTDIR hangar`: the Hangar at a few build-outs, every tab.
func _hangar_shots() -> void:
	var keep_camp: Dictionary = GameState.camp.duplicate()
	var keep_scrap := GameState.account_scrap
	GameState.account_scrap = 1240
	GameState.camp = {"generator": 2, "scrap_press": 1, "station_ash_rook": 3, "station_pebble": 1, "kennel_noel": 1}
	for step in [["early", ["camp", "survivors"]], ["max", ["kennel", "stash", "camp"]]]:
		if str(step[0]) == "max":
			GameState.camp = {}
			for id in HangarDefs.all_ids():
				GameState.camp[id] = HangarDefs.max_rank(str(id))
		var h: Node = (load("res://scenes/ui/hangar.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(h)
		get_tree().current_scene = h
		for t in step[1]:
			h.call("show_tab", t)
			for i in range(30):
				await get_tree().process_frame
			await _snap("hangar_%s_%s" % [step[0], t])
		if str(step[0]) == "max":
			h.call("open_trophies")
			for i in range(10):
				await get_tree().process_frame
			await _snap("hangar_trophies")
		h.queue_free()
		await get_tree().process_frame
	GameState.camp = keep_camp
	GameState.account_scrap = keep_scrap
	get_tree().quit()


## `-- OUTDIR gear`: gear screen, stash with items, a drop in a match, results.
func _gear_shots() -> void:
	var keep := [GameState.stash.duplicate(true), GameState.loadouts.duplicate(true), GameState.camp.duplicate(), GameState.materials.duplicate()]
	var hero := "pebble"
	GameState.selected_character_id = hero
	GameState.camp["stash"] = 1
	GameState.stash.clear()
	GameState.loadouts.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var kit: Array = [[GearDefs.make_weapon(hero, "legendary", rng), "weapon"], [GearDefs.make_mod("edge", "epic"), "mod1"],
		[GearDefs.make_mod("coat_shock", "rare"), "mod2"], [GearDefs.make_gear("charm", "rare", rng), "charm"]]
	for sl in GearDefs.SURVIVOR_SETS["quarry_plate"]["slots"]:
		kit.append([GearDefs.make_gear(str(sl), "epic", rng, "survivor", hero), str(sl)])
	for sl in ["head", "hands"]:
		var it := GearDefs.make_gear(sl, "legendary", rng, "general", hero)
		it["set"] = "demolition_crew"
		kit.append([it, sl])
	for pair in kit:
		GameState.add_to_stash(pair[0])
		GameState.equip(hero, str(pair[1]), int(GameState.stash[GameState.stash.size() - 1]["uid"]))
	for i in range(9):
		GameState.add_to_stash(GearDefs.roll_drop(6, hero, 0.6, rng))
	GameState.materials = {"dust_heart": 2, "salvage_core": 3}
	var lo: Node = (load("res://scenes/ui/loadout.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(lo)
	get_tree().current_scene = lo
	for i in range(30):
		await get_tree().process_frame
	await _snap("gear_summary")
	lo.call("select_slot", "chest")
	for i in range(10):
		await get_tree().process_frame
	await _snap("gear_pick_chest")
	lo.queue_free()
	var h: Node = (load("res://scenes/ui/hangar.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(h)
	get_tree().current_scene = h
	h.call("show_tab", "stash")
	for i in range(20):
		await get_tree().process_frame
	await _snap("gear_stash")
	h.call("inspect_item", int(GameState.stash[0]["uid"]))
	for i in range(10):
		await get_tree().process_frame
	await _snap("gear_inspect")
	h.queue_free()
	## A match with drops on the ground.
	TouchInput.touch_primary = true
	GameState.tutorial_done = true
	GameState.selected_mode_id = "drift"
	GameState.begin_run()
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	var player: Node2D = m.get_node("World/Player")
	for i in range(40):
		await get_tree().process_frame
	var k := 0
	for r in ["common", "rare", "epic", "legendary"]:
		GearPickup.spawn(m.get_node("World"), player.global_position + Vector2(-150 + k * 100, -140), GearDefs.roll_drop(5, hero, 0.0, rng, "armor", r))
		k += 1
	GearPickup.spawn_material(m.get_node("World"), player.global_position + Vector2(0, 130), "dust_heart", 1)
	m.call("spawn_special", "boss", "mutant_overlord")
	for i in range(50):
		await get_tree().process_frame
	await _snap("gear_drops_match")
	m.queue_free()
	await get_tree().process_frame
	GameState.extracted = true
	GameState.wiped = false
	GameState.result_found = []
	for i in range(4):
		GameState.result_found.append(GearDefs.roll_drop(5, hero, 0.5, rng))
	GameState.payout_this_run = 512
	await _show("res://scenes/ui/result_screen.tscn", "gear_result")
	GameState.stash = keep[0]
	GameState.loadouts = keep[1]
	GameState.camp = keep[2]
	GameState.materials = keep[3]
	GameState.save_profile()
	get_tree().quit()


func _run() -> void:
	if _char == "gear":
		await _gear_shots()
		return
	if _char == "hangar":
		await _hangar_shots()
		return
	GameState.tutorial_done = _match_only
	GameState.selected_character_id = _char
	if not _match_only:
		await _show("res://scenes/ui/main_menu.tscn", "01_main_menu")
		await _show("res://scenes/ui/mode_select.tscn", "02_mode_select")
		await _show("res://scenes/ui/character_select.tscn", "03_character_select")
		await _show("res://scenes/ui/how_to_play.tscn", "04_how_to_play")
		await _show("res://scenes/ui/settings_menu.tscn", "05_settings")
	## Match
	TouchInput.touch_primary = true
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
		tc.call("_begin_touch", 0, Vector2(vp.x * 0.3, vp.y * 0.78))
		tc.call("_drag_touch", 0, Vector2(vp.x * 0.3 + 40, vp.y * 0.78 - 30))
	for f in range(420):
		var en := get_tree().get_nodes_in_group("enemies")
		if en.size() > 0 and tc and is_instance_valid(player):
			var to := (en[0] as Node2D).global_position - player.global_position
			var d := to.normalized()
			## Close in to ~70% of weapon range, then circle.
			if to.length() < float(player.call("get_trigger_range")) * 0.7:
				d = d.rotated(PI * 0.5)
			tc.call("_drag_touch", 0, Vector2(vp.x * 0.3, vp.y * 0.78) + d * 60.0)
		if f == 300:
			await _snap("07a_match_combat")
		await get_tree().process_frame
	await _snap("07_match_combat")
	## Close-quarters check: drop a small pack right next to the hero.
	var es: PackedScene = load("res://scenes/entities/enemy.tscn")
	for k in range(5):
		var e: Node = es.instantiate()
		var ang := TAU * k / 5.0
		e.call("setup", player.global_position + Vector2(cos(ang), sin(ang)) * (80.0 + 40.0 * k), 3.0, 0.2, 1.0, ["rad_gator", "scrap_hound", "muck_golem", "toxic_scorp", "scav_bear"][k])
		m.get_node("World").add_child(e)
	tc.call("_end_touch", 0)
	for f in range(36):
		await get_tree().process_frame
		if f == 12 or f == 24:
			await _snap("07b_close_%d" % f)
	await _snap("07c_close")
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
	if is_instance_valid(m):
		m.queue_free()
	GameState.extracted = true
	GameState.payout_this_run = 342
	GameState.result_summary = "Extracted. Payout 342 Scrap · XP 120 · TL 1"
	await _show("res://scenes/ui/result_screen.tscn", "11_result")
	get_tree().quit()
