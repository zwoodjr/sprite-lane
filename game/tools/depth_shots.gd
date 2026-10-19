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


func _mob(m: Node, kind: String, at: Vector2) -> Node2D:
	var e: CharacterBody2D = (load("res://scenes/entities/enemy.tscn") as PackedScene).instantiate()
	e.setup(at, 1.0, 0.2, 1.0, kind)
	m.get_node("World").add_child(e)
	return e


## E2: trait elites (both sides), a raider crew, plague vs machine brawl.
func _shots_e2() -> void:
	GameState.best_tier_extracted = 9
	GameState.camp = {}
	var m := await _match("choke", "helm_wisp")
	var player: Node2D = m.get_node("World/Player")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(2)
	var p := player.global_position
	var e1 := _mob(m, "cyber_juggernaut", p + Vector2(150, -170))
	e1.call("set_role", "elite")
	e1.call("set_traits", ["shielded", "overclocked"])
	var e2 := _mob(m, "scorpion_king", p + Vector2(-150, 170))
	e2.call("set_role", "elite")
	e2.call("set_traits", ["bloated", "sporing"])
	e2.call("_spore_cloud", p + Vector2(-90, 230), 56.0, 30.0, 1.0)
	await _frames(50)
	await _snap("e2_elites")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(2)
	m.call("spawn_crew", p + Vector2(60, -260))
	_mob(m, "rad_gator", p + Vector2(-60, 260))
	_mob(m, "scrap_hound", p + Vector2(10, 270))
	await _frames(45)
	await _snap("e2_raider_crew")
	m.queue_free()
	await _frames(3)


## E3: an evolution card on the level-up picker, the storm it makes, Field Notes.
func _shots_e3() -> void:
	GameState.best_tier_extracted = 9
	GameState.camp = {}
	var m := await _match("drift", "vesper_thorn")
	var player: Node2D = m.get_node("World/Player")
	for id in ["dust_rounds", "spore_mines", "split_shot", "quick_mag", "orbit_blades", "piercing"]:
		var u := UpgradeDefs.get_def(id)
		for i in range(int(u.get("max_rank", 1))):
			GameState.apply_run_upgrade(u)
	var picker: Node = null
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.has_method("pick_index"):
			picker = n
	var choices := [RecipeDefs.get_recipe("lead_rain"), UpgradeDefs.get_def("ricochet"), UpgradeDefs.get_def("firewalk")]
	picker.call("open", 7, choices)
	await _frames(20)
	await _snap("e3_evolution_card")
	picker.call("pick_index", 0)
	GameState.apply_run_upgrade(RecipeDefs.get_recipe("blade_storm"))
	GameState.apply_run_upgrade(RecipeDefs.get_recipe("plague_bloom"))
	for k in range(14):
		_mob(m, ["rad_gator", "scrap_hound", "toxic_scorp"][k % 3], player.global_position + Vector2.RIGHT.rotated(k * 0.45) * (160.0 + 12.0 * k))
	await _frames(70)
	await _snap("e3_storm")
	m.queue_free()
	await _frames(3)
	GameState.bestiary = {"rad_gator": 140, "scrap_hound": 52, "toxic_scorp": 12, "raider_grunt": 3}
	GameState.lore_pages = {"p_first": true, "p_cathedral": true}
	var lb := await _open("res://scenes/ui/logbook.tscn")
	lb.call("show_tab", "notes")
	await _frames(10)
	await _snap("e3_field_notes")
	lb.queue_free()
	await _frames(3)


## E4: camp cameos out in the Dust, Nyx's market, the Dust Warden, stakes.
func _shots_e4() -> void:
	GameState.best_tier_extracted = 9
	GameState.camp = {}
	var m := await _match("blight", "pebble")
	var player: Node2D = m.get_node("World/Player")
	player.set("max_hp", 9999.0)
	player.set("hp", 9999.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var jobs: Node = m.get_node("RadioJobs")
	var p := player.global_position
	jobs.call("start", "field_tent", p + Vector2(-170, -230))
	jobs.call("start", "overwatch", p + Vector2(170, -250))
	jobs.call("start", "defend_relay", p + Vector2(-160, 230))
	jobs.call("start", "vault", p + Vector2(170, 250))
	jobs.set("_stake", "raider_crew")
	await _frames(40)
	await _snap("e4_cameos")
	for id in ["field_tent", "overwatch", "defend_relay", "vault"]:
		var s: Dictionary = (jobs.get("active") as Dictionary).get(id, {})
		if s.get("npc") is Node:
			(s["npc"] as Node).queue_free()
		if s.get("node") is Node:
			(s["node"] as Node).queue_free()
	(jobs.get("active") as Dictionary).clear()
	jobs.call("start", "black_market", p + Vector2(110, -40))
	jobs.call("start", "black_box", p + Vector2(-180, 200))
	await _frames(20)
	GameState.scrap_found = 120
	jobs.call("_open_market")
	await _frames(12)
	await _snap("e4_black_market")
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.has_method("buy"):
			n.call("close")
	await _frames(4)
	var w: Node = jobs.call("spawn_warden", [])
	w.global_position = p + Vector2(0, -220)
	await _frames(60)
	await _snap("e4_dust_warden")
	m.queue_free()
	await _frames(3)


## E5: pre-run Loadout (styles, ability versions, quirks, tonics), Hot Barrel HUD.
func _shots_e5() -> void:
	GameState.camp = {HangarDefs.station_id("vesper_thorn"): 4}
	GameState.selected_character_id = "vesper_thorn"
	GameState.kit = {"vesper_thorn": {"style": "semi", "ability": "b", "quirk": "no_reload"}}
	GameState.tonics = {"menders": 2, "spark": 1}
	GameState.tonic_loadout = ["menders"]
	GameState.reset_loadout_to_defaults()
	var prep := await _open("res://scenes/ui/prep.tscn")
	await _snap("e5_prep_top")
	var sc: ScrollContainer = prep.find_child("PrepScroll", true, false)
	sc.scroll_vertical = 100000
	await _frames(6)
	await _snap("e5_prep_bottom")
	prep.queue_free()
	GameState.camp = {}
	GameState.selected_character_id = "pebble"
	GameState.kit = {}
	GameState.reset_loadout_to_defaults()
	prep = await _open("res://scenes/ui/prep.tscn")
	await _snap("e5_prep_locked")
	prep.queue_free()
	await _frames(3)
	GameState.camp = {HangarDefs.station_id("vesper_thorn"): 4}
	GameState.selected_character_id = "vesper_thorn"
	GameState.kit = {"vesper_thorn": {"style": "semi", "ability": "b", "quirk": "no_reload"}}
	GameState.reset_loadout_to_defaults()
	var m := await _match("smog", "vesper_thorn")
	var player: Node2D = m.get_node("World/Player")
	player.set("max_hp", 9999.0)
	player.set("hp", 9999.0)
	player.set("_overheat_left", 1.5)
	await _frames(10)
	await _snap("e5_hot_barrel_hud")
	m.queue_free()
	await _frames(3)
