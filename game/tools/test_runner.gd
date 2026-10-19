extends Node

## Headless test harness (autoloads active).
##   godot --headless --path game res://tools/test_runner.tscn
## 1) loads + instantiates every script/scene
## 2) opens each menu for a few frames
## 3) plays a fast-timer match with a bot driving the touch inputs
## Prints TEST_PASS / TEST_FAIL. Watch stderr for SCRIPT ERRORs.

const MENUS := [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/mode_select.tscn",
	"res://scenes/ui/character_select.tscn",
	"res://scenes/ui/how_to_play.tscn",
	"res://scenes/ui/settings_menu.tscn",
	"res://scenes/ui/result_screen.tscn",
	"res://scenes/ui/hangar.tscn",
]

var _bad: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	## 1. Load everything
	for path in _walk("res://scripts") + _walk("res://scenes"):
		if not (path.ends_with(".gd") or path.ends_with(".tscn")):
			continue
		var r := ResourceLoader.load(path)
		if r == null:
			print("FAIL load ", path)
			_bad += 1
	print("LOAD_OK")
	## 2. Menus
	for m in MENUS:
		var inst: Node = (load(m) as PackedScene).instantiate()
		get_tree().root.add_child(inst)
		for i in range(10):
			await get_tree().process_frame
		inst.queue_free()
		await get_tree().process_frame
	print("MENUS_OK")
	## 3. Match with a bot, per character and mode
	var chars: Array = ["ash_rook", "sister_cinder"]
	var modes: Array = ["haze", "drift"]
	for i in range(2):
		GameState.selected_character_id = chars[i]
		GameState.selected_mode_id = modes[i]
		GameState.fast_timers = true
		GameState.tutorial_done = (i == 1)  ## first pass exercises the tutorial
		GameState.begin_run()
		var match_scene: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(match_scene)
		get_tree().current_scene = match_scene
		var t := 0.0
		var frames := 0
		var player: Node2D = match_scene.get_node("World/Player")
		var hud: Node = match_scene.get_node("HUD")
		var paused_once := false
		while frames < 5000 and is_instance_valid(match_scene) and not bool(match_scene.get("_ended")):
			var dt := get_process_delta_time()
			t += dt
			frames += 1
			## Bot: circle-strafe; single-stick run-aim toward nearest enemy.
			var target := Vector2(cos(t * 0.7), sin(t * 0.9)).normalized()
			var en := get_tree().get_nodes_in_group("enemies")
			if en.size() > 0 and is_instance_valid(player):
				target = ((en[0] as Node2D).global_position - player.global_position).normalized()
			TouchInput.set_move(target)
			if frames % 120 == 0:
				TouchInput.pulse_dash()
			if frames % 400 == 0:
				TouchInput.pulse_ability()
			if frames == 300 and not paused_once:
				paused_once = true
				hud.call("_open_pause")
				await get_tree().process_frame
				get_tree().paused = false
				var pm := get_tree().root.find_children("*", "CanvasLayer", true, false)
				for n in pm:
					if n.has_method("close"):
						n.call("close")
			## Walk to an open pad late in the match
			if bool(match_scene.call("is_extract_open")) and frames > 1500 and is_instance_valid(player):
				var pads: Array = match_scene.call("get_pads")
				if pads.size() > 0:
					player.global_position = player.global_position.lerp((pads[0] as Node2D).global_position, 0.2)
			await get_tree().physics_frame
		print("MATCH_%d frames=%d kills=%d scrap=%d tl=%d extracted=%s wiped=%s" % [
			i, frames, GameState.kills, GameState.scrap_found, GameState.threat_level,
			GameState.extracted, GameState.wiped])
		TouchInput.clear_sticks()
		## The match changes scene to results on its own; give it time, then clean up.
		for k in range(150):
			await get_tree().process_frame
		for n in get_tree().root.get_children():
			if n != self and not (n.name in ["GameState", "TouchInput", "DisplayFit", "Juice", "UiTheme"]):
				n.queue_free()
		await get_tree().process_frame
	await _test_picker()
	var keep_scrap := GameState.account_scrap
	var keep_camp: Dictionary = GameState.camp.duplicate()
	var keep_stash: Array = GameState.stash.duplicate(true)
	await _test_hangar()
	await _test_upgrades()
	GameState.camp = keep_camp
	GameState.stash = keep_stash
	GameState.account_scrap = keep_scrap
	GameState.save_profile()
	Engine.time_scale = 1.0
	print("TEST_PASS" if _bad == 0 else "TEST_FAIL bad=%d" % _bad)
	get_tree().quit(0 if _bad == 0 else 1)


func _walk(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_walk(dir + "/" + sub))
	return out


## 4) Level-up picker: 3 cards, reroll, pick → unpaused, rank applied.
func _test_picker() -> void:
	GameState.selected_character_id = "helm_wisp"
	GameState.fast_timers = false
	GameState.begin_run()
	var picker := CanvasLayer.new()
	picker.set_script(load("res://scripts/ui/run_upgrade_picker.gd"))
	get_tree().root.add_child(picker)
	await get_tree().process_frame
	picker.call("open", 2, Progression.roll_run_choices())
	await get_tree().process_frame
	var ch: Array = picker.call("get_choices")
	if ch.size() != 3 or not get_tree().paused:
		print("FAIL picker open choices=%d" % ch.size())
		_bad += 1
	if not bool(picker.call("reroll")) or GameState.run_rerolls_left != 1:
		print("FAIL picker reroll")
		_bad += 1
	var id := str((picker.call("get_choices") as Array)[0]["id"])
	picker.call("pick_index", 0)
	await get_tree().process_frame
	if get_tree().paused or GameState.run_rank(id) != 1:
		print("FAIL picker pick")
		_bad += 1
	picker.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	print("PICKER_OK")


## 5) Every hero with every card it can take at max rank + each special ammo,
## a small horde and the ability spammed (catches runtime script errors).
func _test_upgrades() -> void:
	var ammo_ids: Array = UpgradeDefs.AMMO.keys()
	var hi := 0
	for hero in CharacterDefs.PLAYABLE_IDS:
		GameState.selected_character_id = hero
		GameState.selected_pet_id = ["noel", "bentley", "lillie"][hi % 3]
		GameState.selected_mode_id = "drift"
		GameState.fast_timers = true
		GameState.tutorial_done = true
		GameState.begin_run()
		for u in UpgradeDefs.all():
			while Progression.can_offer(u):
				GameState.apply_run_upgrade(u)
		var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(m)
		get_tree().current_scene = m
		var player: Node2D = m.get_node("World/Player")
		await get_tree().process_frame
		player.call("apply_powerup", RunFx.ammo_def(str(ammo_ids[hi % ammo_ids.size()])))
		var es: PackedScene = load("res://scenes/entities/enemy.tscn")
		var frames := 0
		while frames < 700 and is_instance_valid(m) and not bool(m.get("_ended")):
			frames += 1
			if frames % 40 == 1 and get_tree().get_nodes_in_group("enemies").size() < 10:
				var e: CharacterBody2D = es.instantiate()
				var kinds := ["rad_gator", "iron_horse", "muck_golem", "scrap_hound"]
				e.call("setup", player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 140.0, 1.0, 0.3, 1.0, kinds[frames % 4])
				player.get_parent().add_child(e)
			TouchInput.set_move(Vector2(cos(frames * 0.03), sin(frames * 0.04)))
			if frames % 70 == 0:
				TouchInput.pulse_dash()
			if frames % 90 == 5:
				TouchInput.pulse_ability()
			if frames % 200 == 0 and is_instance_valid(player) and player.has_method("heal"):
				player.call("take_damage", 5.0, null)
				player.call("heal", 3.0)
			await get_tree().physics_frame
		print("UPG_%s frames=%d kills=%d ranks=%d drones=%d" % [hero, frames, GameState.kills, GameState.run_ranks.size(),
			(player.call("get_drones") as Array).size() if is_instance_valid(player) else -1])
		TouchInput.clear_sticks()
		m.queue_free()
		for n in get_tree().root.get_children():
			if n != self and not (n.name in ["GameState", "TouchInput", "DisplayFit", "Juice", "UiTheme"]):
				n.queue_free()
		for k in range(5):
			await get_tree().process_frame
		hi += 1
	print("UPGRADES_OK")


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL ", what)
		_bad += 1


## 6) Hangar v4: old-save refund, prices, every rank's effect, ammo gating,
## the screen (tabs, buy, stash grid, popups). Leaves the camp maxed so the
## upgrade pass below runs with stations + kennel at full rank.
func _test_hangar() -> void:
	## Old v3 save: flat list refunded once, then never again.
	GameState.migrated_hangar_v4 = false
	GameState.camp.clear()
	GameState.apply_save({"version": 3, "migrated_v3": true, "account_scrap": 10,
		"meta_upgrades": {"starting_hp": 2, "crit_chance": 1, "bogus": 4}})
	var refund := 90 + int(round((90.0 + 55.0) * 1.35)) + 100
	_check(GameState.account_scrap == 10 + refund, "hangar refund %d" % GameState.account_scrap)
	_check(GameState.meta_upgrades.is_empty() and GameState.migrated_hangar_v4, "hangar migrated flag")
	GameState.apply_save({"version": 4, "migrated_hangar_v4": true, "account_scrap": 5,
		"meta_upgrades": {"starting_hp": 3}, "camp": {"generator": 9, "nonsense": 2}, "stash": [{"id": "x"}, 4]})
	_check(GameState.account_scrap == 5, "hangar no double refund")
	_check(GameState.camp_rank("generator") == 5 and not GameState.camp.has("nonsense"), "camp load clamps")
	_check(GameState.stash.size() == 1, "stash load filters")
	GameState.stash.clear()
	## Prices per the brief.
	_check(HangarDefs.cost("generator", 0) == 100 and HangarDefs.cost("generator", 4) == 1500, "shared prices")
	_check(HangarDefs.cost("station_pebble", 4) == 1100 and HangarDefs.cost("kennel_noel", 2) == 900, "station/kennel prices")
	_check(HangarDefs.cost("stash", 0) == 300 and HangarDefs.cost("stash", 3) == -1, "stash prices")
	## Ammo Bench gating.
	GameState.camp.clear()
	_check(not GameState.ammo_pickups_enabled() and RunFx.random_bench_ammo_id() == "", "ammo gated at bench 0")
	GameState.camp["ammo_bench"] = 1
	_check(RunFx.random_bench_ammo_id() in ["incendiary", "frost"], "bench 1 types")
	GameState.camp.clear()
	## The screen: tabs, buying, stash, popups.
	GameState.account_scrap = HangarDefs.full_max_cost()
	GameState.selected_character_id = "ash_rook"
	GameState.selected_pet_id = "noel"
	var base_cd := float(GameState.hero_ability().get("cooldown", 0.0))
	var h: Node = (load("res://scenes/ui/hangar.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(h)
	for i in range(3):
		await get_tree().process_frame
	for t in ["camp", "survivors", "kennel", "stash"]:
		h.call("show_tab", t)
		await get_tree().process_frame
	for id in HangarDefs.all_ids():
		while GameState.camp_cost(str(id)) >= 0:
			if not bool(h.call("buy", str(id))):
				_check(false, "buy %s" % id)
				break
	_check(GameState.account_scrap == 0, "full max costs exactly %d" % HangarDefs.full_max_cost())
	_check(GameState.stash_capacity() == 50, "stash 50 slots")
	_check(GameState.starting_hp_bonus() == 50.0 and is_equal_approx(GameState.scrap_find_mult(), 1.4), "generator/press")
	_check(GameState.pad_ping_lead() == ModeDefs.PING_LEAD + 15.0, "radio tower")
	_check(float(GameState.hero_ability().get("cooldown", 0.0)) < base_cd, "station cooldown")
	_check(is_equal_approx(GameState.starting_damage_bonus(), 0.32), "station damage")
	GameState.reset_loadout_to_defaults()
	_check(int(GameState.pet.get("rampage_chain", 0)) == 2 and int(GameState.pet.get("kennel_rank", 0)) == 3, "kennel noel r3")
	GameState.selected_character_id = "helm_wisp"
	_check(int(GameState.hero_ability().get("temp_drones", 0)) == 2, "helm station drones")
	h.call("open_logbook")
	await get_tree().process_frame
	h.call("open_trophies")
	await get_tree().process_frame
	h.call("close_popup")
	h.call("show_tab", "stash")
	await get_tree().process_frame
	h.queue_free()
	await get_tree().process_frame
	print("HANGAR_OK")
