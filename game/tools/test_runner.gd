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
	"res://scenes/ui/loadout.tscn",
	"res://scenes/ui/logbook.tscn",
	"res://scenes/ui/mode_choice.tscn",
	"res://scenes/ui/campaign_map.tscn",
]

var _bad: int = 0
var _campaign_levels_run: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	## Tests buy, equip and bank freely — put the player's save back afterwards.
	var save_backup := FileAccess.get_file_as_string(GameState.SAVE_PATH) if FileAccess.file_exists(GameState.SAVE_PATH) else ""
	## `-- only=depth_e1`: run just one section (fast iteration), then finish.
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("only="):
			await call("_test_" + str(a).substr(5))
			_finish(save_backup)
			return
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
	var keep_lo: Dictionary = GameState.loadouts.duplicate(true)
	var keep_ins: Dictionary = GameState.insured.duplicate(true)
	var keep_mats: Dictionary = GameState.materials.duplicate(true)
	var keep_trophies: Dictionary = GameState.trophies.duplicate(true)
	await _test_hangar()
	_test_gear()
	await _test_upgrades()
	await _test_gear_screens()
	await _test_gear_ux()
	await _test_loot2()
	await _test_p0_ui()
	await _test_gear_deploy_sync()
	await _test_full_sets()
	var keep_q := [GameState.daily.duplicate(true), GameState.stories.duplicate(true), GameState.milestones.duplicate(true), GameState.kennel_bond.duplicate(true)]
	await _test_quests_events()
	var keep_best := GameState.best_tier_extracted
	await _test_tiers()
	var keep_depth := [GameState.ingredients.duplicate(), GameState.tonics.duplicate(), GameState.tonic_loadout.duplicate()]
	await _test_depth_e1()
	await _test_depth_e2()
	var keep_notes := [GameState.bestiary.duplicate(), GameState.lore_pages.duplicate()]
	await _test_depth_e3()
	GameState.bestiary = keep_notes[0]
	GameState.lore_pages = keep_notes[1]
	var keep_st := GameState.stories.duplicate(true)
	await _test_depth_e4()
	GameState.stories = keep_st
	var keep_kit := GameState.kit.duplicate(true)
	await _test_depth_e5()
	await _test_ash_breaks()
	GameState.kit = keep_kit
	await _test_minimap()
	await _test_campaign()
	await _test_story_canon()
	await _test_plane_unified()
	var keep_mech := [GameState.mechs_built.duplicate(), GameState.selected_pet_id, GameState.account_scrap]
	await _test_depth_e6()
	await _test_quickwins()
	var keep_e7 := [GameState.tier_clears.duplicate(true), GameState.plane_parts.duplicate(), GameState.pacts.duplicate(), GameState.best_tier_extracted]
	await _test_depth_e7()
	await _test_p2_ui()
	GameState.tier_clears = keep_e7[0]
	GameState.plane_parts = keep_e7[1]
	GameState.pacts = keep_e7[2]
	GameState.best_tier_extracted = keep_e7[3]
	GameState.mechs_built = keep_mech[0]
	GameState.selected_pet_id = keep_mech[1]
	GameState.account_scrap = keep_mech[2]
	GameState.ingredients = keep_depth[0]
	GameState.tonics = keep_depth[1]
	GameState.tonic_loadout = keep_depth[2]
	GameState.best_tier_extracted = keep_best
	GameState.selected_mode_id = "drift"
	GameState.daily = keep_q[0]
	GameState.stories = keep_q[1]
	GameState.milestones = keep_q[2]
	GameState.kennel_bond = keep_q[3]
	GameState.loadouts = keep_lo
	GameState.insured = keep_ins
	GameState.materials = keep_mats
	GameState.trophies = keep_trophies
	GameState.camp = keep_camp
	GameState.stash = keep_stash
	GameState.account_scrap = keep_scrap
	GameState.save_profile()
	Engine.time_scale = 1.0
	for n in get_tree().root.get_children():
		if n != self and not (n.name in ["GameState", "TouchInput", "DisplayFit", "Juice", "UiTheme"]):
			n.queue_free()
	await get_tree().process_frame
	_finish(save_backup)


func _finish(save_backup: String) -> void:
	if save_backup != "":
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(save_backup)
			f.close()
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
		_equip_test_kit(hero, hi)
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
		## Elite + boss: rewards, boss loot bonus, trophy.
		var el: Node = m.call("spawn_special", "elite")
		var bs: Node = m.call("spawn_special", "boss", ["dread_naught", "mutant_overlord"][hi % 2])
		await get_tree().physics_frame
		await get_tree().physics_frame
		for sp in [el, bs]:
			if is_instance_valid(sp):
				(sp as Node2D).global_position = player.global_position + Vector2(60, 0)
				sp.call("take_damage", 99999.0, Vector2.RIGHT)
		for k in range(30):
			await get_tree().physics_frame
		for g in get_tree().get_nodes_in_group("gear_drops"):
			g.call("_collect")
		_check(GameState.run_loot.size() >= 2, "%s role loot %d" % [hero, GameState.run_loot.size()])
		_check(not GameState.run_materials.is_empty(), "%s boss materials" % hero)
		_check(GameState.boss_loot_bonus >= 0.5, "%s boss loot bonus" % hero)
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
	_check(HangarDefs.cost("stash", 0) == 300 and HangarDefs.cost("stash", HangarDefs.STASH_PRICES.size()) == -1 and HangarDefs.stash_slots(0) == 80 and HangarDefs.stash_slots(5) == 280, "stash prices")
	## Ammo Bench gating.
	GameState.camp.clear()
	_check(not GameState.ammo_pickups_enabled() and RunFx.random_bench_ammo_id() == "", "ammo gated at bench 0")
	GameState.camp["ammo_bench"] = 1
	_check(RunFx.random_bench_ammo_id() in ["incendiary", "frost"], "bench 1 types")
	GameState.camp.clear()
	## The screen: tabs, buying, stash, popups (no gear, so only camp bonuses count).
	GameState.loadouts.clear()
	GameState.stash.clear()
	GameState._compute_gear()
	GameState.account_scrap = HangarDefs.full_max_cost()
	GameState.selected_character_id = "ash_rook"
	GameState.selected_pet_id = "noel"
	var base_cd := float(GameState.hero_ability().get("cooldown", 0.0))
	var h: Node = (load("res://scenes/ui/hangar.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(h)
	for i in range(3):
		await get_tree().process_frame
	for t in ["camp", "survivors", "kennel", "brew", "stash"]:
		h.call("show_tab", t)
		await get_tree().process_frame
	## Mech bays (Depth E6) open once the mech is built.
	var keep_mechs := GameState.mechs_built.duplicate()
	for mid in PetDefs.MECH_IDS:
		GameState.mechs_built[mid] = true
	for id in HangarDefs.all_ids():
		while GameState.camp_cost(str(id)) >= 0:
			if not bool(h.call("buy", str(id))):
				_check(false, "buy %s" % id)
				break
	_check(GameState.account_scrap == 0, "full max costs exactly %d" % HangarDefs.full_max_cost())
	GameState.mechs_built = keep_mechs
	_check(GameState.stash_capacity() == HangarDefs.stash_slots(GameState.camp_rank("stash")), "stash slots")
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


## A full kit for the upgrade pass: Legendary weapon, 2 fitting mods,
## survivor set (3) + 3 pieces of a general set, charged Vial, Charm, Patch.
func _equip_test_kit(hero: String, hi: int) -> void:
	GameState.stash.clear()
	GameState.loadouts.clear()
	GameState.insured.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + hi
	var add := func(it: Dictionary, slot: String) -> void:
		GameState.add_to_stash(it)
		var uid := int(GameState.stash[GameState.stash.size() - 1]["uid"])
		if not GameState.equip(hero, slot, uid):
			_check(false, "equip %s %s" % [hero, slot])
	add.call(GearDefs.make_weapon(hero, "legendary", rng), "weapon")
	var melee := GearDefs.is_melee_hero(hero)
	add.call(GearDefs.make_mod("edge" if melee else "scope", "epic"), "mod1")
	add.call(GearDefs.make_mod(["coat_poison", "coat_fire", "coat_shock", "coat_frost"][hi % 4], "rare"), "mod2")
	var sid := GearDefs.survivor_set_for(hero)
	var ss_slots: Array = GearDefs.SURVIVOR_SETS[sid]["slots"]
	for sl in ss_slots:
		add.call(GearDefs.make_gear(str(sl), "epic", rng, "survivor", hero), str(sl))
	var gid: String = GearDefs.GENERAL_SETS.keys()[hi % 4]
	for sl in GearDefs.ARMOR_SLOTS:
		if sl in ss_slots:
			continue
		var it := GearDefs.make_gear(str(sl), "legendary", rng, "general", hero)
		it["set"] = gid
		add.call(it, str(sl))
	for sl in GearDefs.ACCESSORY_SLOTS:
		var it2 := GearDefs.make_gear(str(sl), "legendary", rng)
		if bool(it2.get("needs_heart", false)):
			it2["charged"] = true
		add.call(it2, str(sl))
	GameState.reset_loadout_to_defaults()
	_check(GameState.has_set(sid, 3), "%s survivor set" % hero)
	_check(GameState.set_count(gid) == 3, "%s general 3" % hero)
	_check(GameState.gear_legendary() != "", "%s legendary" % hero)


## 7) Gear data, equip rules, weapons, extract / death banking, role rewards.
func _test_gear() -> void:
	GameState.stash.clear()
	GameState.loadouts.clear()
	GameState.insured.clear()
	GameState.camp["stash"] = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	## Drops: valid, fitting, JSON-safe; set pieces only at Epic+.
	var bad := 0
	for hero in CharacterDefs.PLAYABLE_IDS:
		for i in range(120):
			var it := GearDefs.roll_drop(1 + i % 10, hero, 0.2, rng)
			var back: Variant = JSON.parse_string(JSON.stringify(it))
			if typeof(back) != TYPE_DICTIONARY or str(it.get("name", "")) == "" or not str(it.get("rarity", "")) in GearDefs.RARITIES:
				bad += 1
			if str(it.get("set", "")) != "" and not str(it["rarity"]) in ["epic", "legendary"]:
				bad += 1
			var fits_any := false
			for sl in GearDefs.LOADOUT_SLOTS:
				if GearDefs.fits(back, str(sl), hero):
					fits_any = true
			if not fits_any:
				bad += 1
			if GearDefs.stat_lines(it).is_empty():
				bad += 1
	_check(bad == 0, "gear rolls bad=%d" % bad)
	## Melee survivors never take ranged mods (Quill counts as melee).
	for hero in ["pebble", "bolt_juno", "nyx_caldera", "quill_marrow"]:
		_check(not GearDefs.fits(GearDefs.make_mod("scope", "rare"), "mod1", hero), "%s no scope" % hero)
		_check(GearDefs.fits(GearDefs.make_mod("coat_fire", "rare"), "mod1", hero), "%s coating ok" % hero)
	_check(not GearDefs.fits(GearDefs.make_mod("grip", "rare"), "mod1", "vesper_thorn"), "vesper no grip")
	## Quick equip (stash popup / results): every rolled drop lands in a slot.
	var qe_bad := 0
	var qrng := RandomNumberGenerator.new()
	qrng.seed = 77
	for hero in CharacterDefs.PLAYABLE_IDS:
		for i in range(12):
			GameState.stash.clear()
			GameState.loadouts.clear()
			GameState.add_to_stash(GearDefs.roll_drop(1 + i % 10, hero, 0.2, qrng))
			var quid := int(GameState.stash[0]["uid"])
			if not GameState.quick_equip(quid, hero) or GameState.equipped_by(quid).is_empty():
				qe_bad += 1
	_check(qe_bad == 0, "quick equip bad=%d" % qe_bad)
	GameState.stash.clear()
	GameState.loadouts.clear()
	_check(not GearDefs.fits(GearDefs.make_weapon("pebble", "rare", rng), "weapon", "ash_rook"), "weapon locked to hero")
	## Weapon variants + mods.
	var base := LoadoutStubs.weapon_for_character("vesper_thorn")
	var w := GearDefs.apply_weapon(base, GearDefs.make_weapon("vesper_thorn", "legendary", rng), [GearDefs.make_mod("scope", "legendary")])
	_check(float(w["damage"]) > float(base["damage"]) and float(w["trigger_range"]) > float(base["trigger_range"]), "weapon + scope")
	_check(int(w.get("pierce", 0)) == 1 and str(w["legendary"]) == "bellwether", "bellwether pierce")
	## Equip, move between survivors, insure, salvage.
	GameState.selected_character_id = "ash_rook"
	GameState.add_to_stash(GearDefs.make_gear("head", "rare", rng))
	var uid := int(GameState.stash[0]["uid"])
	_check(GameState.equip("ash_rook", "head", uid), "equip head")
	_check(not GameState.equip("ash_rook", "chest", uid), "head not in chest")
	_check(GameState.set_insured("ash_rook", uid) and GameState.is_insured(uid), "insure")
	_check(GameState.equip("pebble", "head", uid) and GameState.equipped_items("ash_rook").is_empty(), "moves to pebble")
	_check(not GameState.is_insured(uid), "insure cleared on move")
	var scrap0 := GameState.account_scrap
	_check(GameState.salvage(uid) == GearDefs.SALVAGE["rare"] and GameState.account_scrap == scrap0 + GearDefs.SALVAGE["rare"], "salvage")
	## Vial needs a Dust Heart.
	GameState.add_to_stash(GearDefs.make_gear("vial", "epic", rng))
	var vu := int(GameState.stash[GameState.stash.size() - 1]["uid"])
	GameState.materials["dust_heart"] = 0
	_check(not GameState.charge_vial(vu), "vial needs heart")
	GameState.materials["dust_heart"] = 1
	_check(GameState.charge_vial(vu) and GameState.material_count("dust_heart") == 0, "vial charged")
	## Extract banks found gear; overflow is salvaged.
	GameState.stash.clear()
	GameState.selected_mode_id = "drift"
	GameState.begin_run()
	for i in range(3):
		GameState.add_run_loot(GearDefs.roll_drop(2, "ash_rook", 0.0, rng))
	GameState.add_run_material("salvage_core", 2)
	GameState.on_extract_success()
	_check(GameState.stash.size() == 3 and GameState.result_found.size() == 3, "extract banks gear")
	_check(GameState.material_count("salvage_core") >= 2, "extract banks materials")
	while GameState.stash.size() < GameState.stash_capacity():
		GameState.add_to_stash(GearDefs.make_gear("boots", "common", rng))
	GameState.begin_run()
	GameState.add_run_loot(GearDefs.make_gear("legs", "epic", rng))
	GameState.on_extract_success()
	_check(GameState.result_salvaged == 0 and GameState.result_held_n == 1 and str(GameState.pending_rewards.back()["rarity"]) == "epic", "overflow holds epic")
	GameState.pending_rewards.pop_back()
	## Death: brought-in gear lost except the insured piece; found gear lost.
	GameState.stash.clear()
	GameState.loadouts.clear()
	GameState.add_to_stash(GearDefs.make_gear("head", "rare", rng))
	GameState.add_to_stash(GearDefs.make_gear("boots", "rare", rng))
	var u1 := int(GameState.stash[0]["uid"])
	var u2 := int(GameState.stash[1]["uid"])
	GameState.equip("ash_rook", "head", u1)
	GameState.equip("ash_rook", "boots", u2)
	GameState.set_insured("ash_rook", u1)
	GameState.begin_run()
	GameState.add_run_loot(GearDefs.make_gear("legs", "epic", rng))
	GameState.on_wipe()
	_check(not GameState.stash_item(u1).is_empty() and GameState.stash_item(u2).is_empty(), "wipe keeps insured only")
	_check(GameState.result_lost_items.size() == 2, "wipe lost list %d" % GameState.result_lost_items.size())
	## Elite / boss rewards (Part 3).
	var er := GearDefs.roll_role_reward("elite", "cyber_juggernaut", 3, "ash_rook", 0.0, rng)
	var eitems: Array = er["items"]
	_check(eitems.size() >= 1 and (eitems.size() == 1 or str(eitems[1]["kind"]) == "mod") and GearDefs.RARITIES.find(str(eitems[0]["rarity"])) >= 1, "elite reward")
	var br := GearDefs.roll_role_reward("boss", "mutant_overlord", 5, "ash_rook", 0.0, rng)
	var bitems: Array = br["items"]
	_check(str(bitems[0]["rarity"]) == "epic" and str(bitems[0]["set"]) != "" and int((br["materials"] as Dictionary).get("dust_heart", 0)) >= 1, "boss reward")
	## Old saves (no gear keys) load with safe defaults.
	GameState.apply_save({"version": 4, "migrated_hangar_v4": true, "stash": [{"name": "old", "rarity": "rare", "kind": "armor", "slot": "head"}]})
	_check(GameState.stash.size() == 1 and int(GameState.stash[0]["uid"]) > 0 and GameState.loadouts.is_empty(), "old save gear defaults")
	GameState.stash.clear()
	print("GEAR_OK")


## 8) Gear screen + hangar stash with items (popups, equip through the UI).
func _test_gear_screens() -> void:
	_equip_test_kit("helm_wisp", 1)
	var rng := RandomNumberGenerator.new()
	for i in range(6):
		GameState.add_to_stash(GearDefs.roll_drop(5, "helm_wisp", 0.5, rng))
	var lo: Node = (load("res://scenes/ui/loadout.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(lo)
	await get_tree().process_frame
	for sl in GearDefs.LOADOUT_SLOTS:
		lo.call("select_slot", str(sl))
		await get_tree().process_frame
	lo.call("select_slot", "")
	lo.call("cycle_hero", 1)
	await get_tree().process_frame
	lo.queue_free()
	var h: Node = (load("res://scenes/ui/hangar.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(h)
	await get_tree().process_frame
	h.call("show_tab", "stash")
	await get_tree().process_frame
	var n0 := GameState.stash.size()
	h.call("inspect_item", int(GameState.stash[n0 - 1]["uid"]))
	await get_tree().process_frame
	h.call("close_popup")
	h.queue_free()
	await get_tree().process_frame
	GameState.stash.clear()
	GameState.loadouts.clear()
	print("GEAR_SCREENS_OK")

## 8b) Gear UX: item identity, salvage confirm / lock / undo, bulk safety,
## sort / filter, set progress, old-save safety.
func _test_gear_ux() -> void:
	GameState.stash.clear()
	GameState.loadouts.clear()
	GameState.insured.clear()
	GameState.salvage_bin.clear()
	GameState.camp["stash"] = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	## Identity: one icon per variant / look; every set has an emblem.
	var miss: Array = []
	for hero in CharacterDefs.PLAYABLE_IDS:
		var seen := {}
		for v in GearDefs.variants(hero):
			var it := {"kind": "weapon", "hero": hero, "variant": str(v["id"]), "legendary": str(v.get("legendary", ""))}
			var id := IconSet.item(it)
			if not IconSet.has(id) or seen.has(id):
				miss.append(id)
			seen[id] = true
	for sl in GearDefs.ARMOR_SLOTS + GearDefs.ACCESSORY_SLOTS:
		var ids := {}
		for i in range(3):
			var id2 := IconSet.item({"kind": "armor", "slot": sl, "noun": i})
			if not IconSet.has(id2):
				miss.append(id2)
			ids[id2] = true
		if ids.size() != 3:
			miss.append("%s looks" % sl)
	for sid in GearDefs.GENERAL_SETS.keys() + GearDefs.SURVIVOR_SETS.keys():
		if not IconSet.has(IconSet.emblem(str(sid))):
			miss.append(str(sid))
	_check(miss.is_empty() and IconSet.has("ui_lock"), "gear icons %s" % [miss])
	_check(GearDefs.noun_index({"slot": "boots", "name": "Worn Striders"}) == 2 and GearDefs.noun_index({"slot": "charm", "name": "Fine Lucky Bottle Cap"}) == 1, "old-save look from name")
	## Old saves: no lock / new / bin keys -> safe defaults.
	GameState.apply_save({"version": 4, "migrated_hangar_v4": true, "stash": [{"uid": 3, "name": "Plain Hood", "rarity": "common", "kind": "armor", "slot": "head"}]})
	_check(GameState.stash.size() == 1 and not bool(GameState.stash[0].get("new", false)) and GameState.salvage_bin.is_empty() and GameState.next_uid >= 4, "old save gear ux defaults")
	GameState.camp["stash"] = 3
	GameState.stash.clear()
	## Confirm rules.
	var leg := GearDefs.make_weapon("ash_rook", "legendary", rng)
	var setp := GearDefs.make_gear("chest", "epic", rng, "general", "ash_rook")
	_check(GearDefs.needs_salvage_confirm(leg) and GearDefs.needs_salvage_confirm(setp) and not GearDefs.needs_salvage_confirm(GearDefs.make_gear("head", "rare", rng)), "salvage confirm rules")
	## Lock blocks salvage; unlock allows.
	GameState.add_to_stash(leg)
	var lu := int(GameState.stash[0]["uid"])
	_check(bool(GameState.stash[0].get("new", false)), "new item badge")
	GameState.mark_seen(lu)
	_check(not bool(GameState.stash_item(lu).get("new", false)), "mark seen")
	_check(GameState.toggle_lock(lu) and GameState.salvage(lu) == 0 and not GameState.stash_item(lu).is_empty(), "lock blocks salvage")
	GameState.toggle_lock(lu)
	## Undo: salvage the Legendary, buy it back with the same uid.
	var s0 := GameState.account_scrap
	var got := GameState.salvage(lu)
	_check(got == GearDefs.SALVAGE["legendary"] and GameState.stash_item(lu).is_empty() and GameState.salvage_bin.size() == 1, "salvage to bin")
	_check(GameState.buy_back(lu) and GameState.account_scrap == s0 and str(GameState.stash_item(lu).get("legendary", "")) == "last_shift", "buy back restores")
	_check(not GameState.buy_back(lu), "buy back once")
	## Bin keeps valuables over a flood of commons; buy back needs scrap.
	GameState.salvage(lu)
	for i in range(GameState.SALVAGE_BIN_MAX + 4):
		GameState.add_to_stash(GearDefs.make_gear("boots", "common", rng))
		GameState.salvage(int(GameState.stash[GameState.stash.size() - 1]["uid"]))
	var kept := false
	for e in GameState.salvage_bin:
		kept = kept or int(e["item"]["uid"]) == lu
	_check(GameState.salvage_bin.size() == GameState.SALVAGE_BIN_MAX and kept, "bin keeps the legendary")
	var keep_scrap := GameState.account_scrap
	GameState.account_scrap = 5
	_check(not GameState.buy_back(lu), "buy back needs scrap")
	GameState.account_scrap = keep_scrap
	## Bin survives save/load.
	var back: Variant = JSON.parse_string(JSON.stringify({"version": 9, "migrated_hangar_v4": true, "stash": GameState.stash, "salvage_bin": GameState.salvage_bin, "camp": {"stash": 3}, "account_scrap": 5000}))
	GameState.apply_save(back)
	_check(GameState.salvage_bin.size() == GameState.SALVAGE_BIN_MAX and GameState.buy_back(lu), "bin save round trip")
	## Bulk salvage: only loose, unlocked, unworn, uninsured Commons.
	GameState.stash.clear()
	GameState.loadouts.clear()
	GameState.salvage_bin.clear()
	var keep_uids: Array = []
	var c_uids: Array = []
	for i in range(4):
		GameState.add_to_stash(GearDefs.make_gear(["head", "legs", "charm", "vial"][i], "common", rng))
		c_uids.append(int(GameState.stash[GameState.stash.size() - 1]["uid"]))
	GameState.add_to_stash(GearDefs.make_gear("head", "common", rng))
	var locked_c := int(GameState.stash[GameState.stash.size() - 1]["uid"])
	GameState.toggle_lock(locked_c)
	GameState.add_to_stash(GearDefs.make_gear("boots", "common", rng))
	var worn_c := int(GameState.stash[GameState.stash.size() - 1]["uid"])
	GameState.equip("pebble", "boots", worn_c)
	var odd := GearDefs.make_gear("chest", "common", rng)
	odd["set"] = "night_runner"
	GameState.add_to_stash(odd)
	var set_c := int(GameState.stash[GameState.stash.size() - 1]["uid"])
	GameState.add_to_stash(GearDefs.make_gear("hands", "epic", rng))
	var ep := int(GameState.stash[GameState.stash.size() - 1]["uid"])
	GameState.add_to_stash(GearDefs.make_weapon("pebble", "legendary", rng))
	var lg := int(GameState.stash[GameState.stash.size() - 1]["uid"])
	keep_uids = [locked_c, worn_c, set_c, ep, lg]
	var r := GameState.salvage_commons()
	var all_kept := true
	for u in keep_uids:
		all_kept = all_kept and not GameState.stash_item(int(u)).is_empty()
	var none_left := true
	for u in c_uids:
		none_left = none_left and GameState.stash_item(int(u)).is_empty()
	_check(int(r["count"]) == 4 and all_kept and none_left, "bulk salvage safety %s" % [r])
	## Sort / filter.
	for i in range(12):
		GameState.add_to_stash(GearDefs.roll_drop(6, "ash_rook", 0.8, rng))
	var ok_sort := true
	var v := GameState.stash_view("rarity")
	for i in range(1, v.size()):
		ok_sort = ok_sort and GearDefs.RARITIES.find(str(v[i - 1]["rarity"])) >= GearDefs.RARITIES.find(str(v[i]["rarity"]))
	var vn := GameState.stash_view("newest")
	for i in range(1, vn.size()):
		ok_sort = ok_sort and int(vn[i - 1]["uid"]) > int(vn[i]["uid"])
	var vs := GameState.stash_view("set")
	var seen_loose := false
	for it in vs:
		if str(it.get("set", "")) == "":
			seen_loose = true
		elif seen_loose:
			ok_sort = false
	_check(ok_sort and v.size() == GameState.stash.size(), "stash sorts")
	var ok_f := true
	for it in GameState.stash_view("rarity", {"group": "weapon"}):
		ok_f = ok_f and str(it["kind"]) == "weapon"
	for it in GameState.stash_view("rarity", {"rarity": "epic"}):
		ok_f = ok_f and str(it["rarity"]) == "epic"
	for it in GameState.stash_view("rarity", {"set": "any"}):
		ok_f = ok_f and str(it.get("set", "")) != ""
	for it in GameState.stash_view("rarity", {"fits": "pebble"}):
		ok_f = ok_f and GameState.slot_for(int(it["uid"]), "pebble") != ""
	var n_fit := 0
	for it in GameState.stash:
		if GameState.slot_for(int(it["uid"]), "pebble") != "":
			n_fit += 1
	_check(ok_f and GameState.stash_view("rarity", {"fits": "pebble"}).size() == n_fit, "stash filters")
	## Set progress: 2 Night Runner pieces on, a third reads 2/6 -> 3/6.
	GameState.stash.clear()
	GameState.loadouts.clear()
	var nr: Array = []
	for sl in ["head", "chest", "legs", "boots"]:
		var g := GearDefs.make_gear(sl, "epic", rng, "general", "ash_rook")
		g["set"] = "night_runner"
		GameState.add_to_stash(g)
		nr.append(int(GameState.stash[GameState.stash.size() - 1]["uid"]))
	GameState.equip("ash_rook", "head", nr[0])
	GameState.equip("ash_rook", "chest", nr[1])
	var sp := GameState.set_progress("ash_rook", GameState.stash_item(nr[2]))
	_check(sp.size() == 1 and int(sp[0]["now"]) == 2 and int(sp[0]["after"]) == 3 and int(sp[0]["total"]) == 6, "set progress up %s" % [sp])
	var pd := GearDefs.make_gear("head", "epic", rng, "general", "ash_rook")
	pd["set"] = "plague_doctor"
	GameState.add_to_stash(pd)
	var sp2 := GameState.set_progress("ash_rook", GameState.stash[GameState.stash.size() - 1])
	_check(sp2.size() == 2 and str(sp2[1]["set"]) == "night_runner" and int(sp2[1]["after"]) == 1, "set progress down %s" % [sp2])
	_check(GearUi.compare_lines(GearDefs.make_gear("head", "legendary", rng), {}).size() >= 1, "compare lines")
	## Screens: Hangar stash (sort, filter, confirm, lock, bulk, buy back) + Gear.
	GameState.selected_character_id = "ash_rook"
	for i in range(6):
		GameState.add_to_stash(GearDefs.make_gear(["hands", "vial", "patch", "charm", "legs", "boots"][i], "common", rng))
	GameState.add_to_stash(GearDefs.make_weapon("ash_rook", "legendary", rng))
	var hl := int(GameState.stash[GameState.stash.size() - 1]["uid"])
	var h: Node = (load("res://scenes/ui/hangar.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(h)
	await get_tree().process_frame
	h.call("show_tab", "stash")
	await get_tree().process_frame
	for s2 in ["slot", "set", "newest", "rarity"]:
		h.call("set_stash_sort", s2)
	for f in ["group", "group", "rarity", "set", "fits"]:
		h.call("cycle_stash_filter", f)
	await get_tree().process_frame
	h.call("set_stash_filters", {"group": "", "rarity": "", "set": "", "fits": ""})
	_check((h.call("stash_shown") as Array).size() == GameState.stash.size(), "stash grid shows all")
	h.call("inspect_item", hl)
	await get_tree().process_frame
	h.call("ask_salvage", hl)
	await get_tree().process_frame
	_check(not GameState.stash_item(hl).is_empty() and h.find_child("SalvageConfirm", true, false) != null, "legendary asks to confirm")
	_check(int(h.call("confirm_salvage", hl)) == GearDefs.SALVAGE["legendary"] and GameState.stash_item(hl).is_empty(), "confirmed salvage")
	h.call("open_buyback")
	await get_tree().process_frame
	_check(h.find_child("BuyBack", true, false) != null and GameState.buy_back(hl), "buy back from the screen")
	GameState.toggle_lock(hl)
	h.call("ask_salvage", hl)
	await get_tree().process_frame
	_check(not GameState.stash_item(hl).is_empty(), "locked stays")
	GameState.toggle_lock(hl)
	var com := -1
	for it in GameState.stash:
		if GameState.bulk_salvageable(it):
			com = int(it["uid"])
	h.call("ask_salvage", com)
	_check(GameState.stash_item(com).is_empty(), "common salvages at once")
	h.call("ask_bulk_salvage")
	await get_tree().process_frame
	h.call("open_set", "night_runner")
	await get_tree().process_frame
	h.call("close_popup")
	h.queue_free()
	await get_tree().process_frame
	var lo: Node = (load("res://scenes/ui/loadout.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(lo)
	await get_tree().process_frame
	lo.call("select_slot", "legs")
	lo.call("preview_item", nr[2])
	for s3 in ["newest", "set", "rarity"]:
		lo.call("set_sort", s3)
	await get_tree().process_frame
	_check(bool(lo.call("equip_item", nr[2])) and int(GameState.worn_set_counts("ash_rook").get("night_runner", 0)) == 3, "equip from picker")
	lo.call("select_slot", "")
	lo.call("open_set", "night_runner")
	await get_tree().process_frame
	lo.call("close_popup")
	lo.queue_free()
	await get_tree().process_frame
	GameState.stash.clear()
	GameState.loadouts.clear()
	GameState.salvage_bin.clear()
	print("GEAR_UX_OK")


## 8b2) Loot v2: fewer Common drops (Rare+ odds kept), auto-salvage toggle,
## overflow salvages Commons first, SET sort groups + set filter chip.
func _test_loot2() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var keep_auto: Variant = GameState.settings.get("auto_salvage_commons", false)
	var keep_bin := GameState.salvage_bin.duplicate(true)
	var keep_stash := GameState.stash.duplicate(true)
	var keep_lo := GameState.loadouts.duplicate(true)
	## Drop counts: per random drop roll, Commons thinned to COMMON_KEEP, Rare+ unchanged.
	for tier in [1, 5, 8]:
		var old := {}
		var now := {}
		var n := 20000
		for i in range(n):
			var a := GearDefs.roll_drop(tier, "ash_rook", 0.0, rng)
			old[a["rarity"]] = int(old.get(a["rarity"], 0)) + 1
			var b := GearDefs.random_drop(tier, "ash_rook", 0.0, rng)
			if not b.is_empty():
				now[b["rarity"]] = int(now.get(b["rarity"], 0)) + 1
		var rare_old := n - int(old.get("common", 0))
		var rare_now := 0
		for r in ["rare", "epic", "legendary"]:
			rare_now += int(now.get(r, 0))
		var c_ratio := float(now.get("common", 0)) / maxf(1.0, float(old.get("common", 0)))
		print("LOOT_DROPS tier=%d old=%s new=%s" % [tier, old, now])
		_check(absf(c_ratio - GearDefs.COMMON_KEEP) < 0.05, "commons thinned t%d %.2f" % [tier, c_ratio])
		_check(absf(float(rare_now) / float(rare_old) - 1.0) < 0.08, "rare+ odds kept t%d %d/%d" % [tier, rare_now, rare_old])
	## Elite / boss rewards stay guaranteed.
	var er := GearDefs.roll_role_reward("elite", "", 3, "ash_rook", 0.0, rng)
	var br := GearDefs.roll_role_reward("boss", "dread_naught", 5, "ash_rook", 0.0, rng)
	_check((er["items"] as Array).size() >= 1 and (br["items"] as Array).size() >= 1 and not (br["materials"] as Dictionary).is_empty(), "elite/boss rewards guaranteed")
	var mods := 0
	for i in range(2000):
		var e2 := GearDefs.roll_role_reward("elite", "", 3, "ash_rook", 0.0, rng)
		_check((e2["items"] as Array).size() >= 1 and GearDefs.RARITIES.find(str(e2["items"][0]["rarity"])) >= 1, "elite gear guaranteed")
		mods += (e2["items"] as Array).size() - 1
	_check(absf(float(mods) / 2000.0 - GearDefs.ELITE_MOD_CHANCE) < 0.05, "elite bonus mod rate %d" % mods)
	_check((GearDefs.roll_role_reward("elite", "", 3, "ash_rook", 0.0, rng, false)["items"] as Array).size() == 1, "soft cap: no bonus mod")
	## Toggle: default OFF, and an old save without the key loads OFF.
	_check(((load("res://scripts/ui/settings_panel.gd") as GDScript).get_script_constant_map()["ROWS"] as Array).any(func(r: Dictionary) -> bool: return str(r["key"]) == "auto_salvage_commons"), "settings row")
	GameState.settings.erase("auto_salvage_commons")
	GameState.save_profile()
	var old_save: Variant = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	(old_save["settings"] as Dictionary).erase("auto_salvage_commons")
	old_save["version"] = 3
	GameState.apply_save(old_save)
	_check(not GameState.auto_salvage_on() and not GameState.settings.has("auto_salvage_commons") or GameState.settings["auto_salvage_commons"] == false, "auto-salvage default off (old save)")
	## OFF: every Common goes to the stash.
	GameState.stash.clear()
	GameState.loadouts.clear()
	GameState.salvage_bin.clear()
	GameState.selected_mode_id = "drift"
	GameState.begin_run()
	for i in range(3):
		GameState.add_run_loot(GearDefs.make_gear("boots", "common", rng))
	GameState.on_extract_success()
	_check(GameState.stash.size() == 3 and GameState.result_auto_salvaged_n == 0, "auto off keeps commons")
	## ON: plain Commons salvaged; set / Rare+ / upgrades kept; all in buy-back.
	GameState.stash.clear()
	GameState.salvage_bin.clear()
	var worn := GearDefs.make_gear("head", "common", rng)
	worn["stats"] = {"max_hp": 6.0}
	GameState.add_to_stash(worn)
	GameState.equip("ash_rook", "head", int(GameState.stash[0]["uid"]))
	GameState.set_setting("auto_salvage_commons", true)
	GameState.begin_run()
	var up := GearDefs.make_gear("head", "common", rng)
	up["stats"] = {"max_hp": 7.0, "crit": 0.02}
	var worse := GearDefs.make_gear("head", "common", rng)
	worse["stats"] = {"max_hp": 5.0}
	var setp := GearDefs.make_gear("chest", "epic", rng, "general", "ash_rook")
	for it in [GearDefs.make_gear("boots", "common", rng), up, worse, GearDefs.make_gear("hands", "rare", rng), setp]:
		GameState.add_run_loot(it)
	var scrap0 := GameState.account_scrap
	GameState.on_extract_success()
	var auto_scrap := 2 * int(GearDefs.SALVAGE["common"])
	_check(GameState.result_auto_salvaged_n == 2 and GameState.result_auto_salvaged_scrap == auto_scrap, "auto-salvaged 2 %d" % GameState.result_auto_salvaged_n)
	_check(GameState.stash.size() == 4 and GameState.salvage_bin.size() == 2, "kept upgrade + rare + set; bin has the commons")
	_check(GameState.account_scrap - scrap0 >= auto_scrap, "auto scrap paid")
	var rs: Node = (load("res://scenes/ui/result_screen.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(rs)
	for i in range(3):
		await get_tree().process_frame
	var al: Label = rs.find_child("AutoSalvageLine", true, false) as Label
	_check(al != null and al.text == "Auto-salvaged 2 commons (+%d scrap)" % auto_scrap, "result line %s" % (al.text if al else "none"))
	rs.queue_free()
	await get_tree().process_frame
	var bu := int((GameState.salvage_bin[0]["item"] as Dictionary)["uid"])
	_check(GameState.buy_back(bu) and not GameState.stash_item(bu).is_empty(), "auto-salvaged buy back")
	## Stash full: overflow salvages Commons before anything rarer.
	GameState.set_setting("auto_salvage_commons", false)
	GameState.stash.clear()
	GameState.loadouts.clear()
	while GameState.stash.size() < GameState.stash_capacity() - 2:
		GameState.add_to_stash(GearDefs.make_gear("boots", "common", rng))
	GameState.begin_run()
	GameState.add_run_loot(GearDefs.make_gear("legs", "common", rng))
	GameState.add_run_loot(GearDefs.make_gear("legs", "epic", rng))
	GameState.add_run_loot(GearDefs.make_gear("charm", "common", rng))
	GameState.add_run_loot(GearDefs.make_gear("head", "rare", rng))
	GameState.on_extract_success()
	var kept_r: Array = GameState.result_found.map(func(x: Dictionary) -> String: return str(x["rarity"]))
	_check(GameState.result_overflow_n == 2 and kept_r.has("epic") and kept_r.has("rare") and not kept_r.has("common"), "overflow commons first %s" % [kept_r])
	_check(GameState.result_salvaged == 2 * int(GearDefs.SALVAGE["common"]), "overflow scrap")
	## SET sort + set filter + stash quick toggle.
	GameState.stash.clear()
	GameState.selected_character_id = "ash_rook"
	var a1 := GearDefs.make_gear("head", "epic", rng, "general", "ash_rook")
	a1["set"] = "night_runner"
	var a2 := GearDefs.make_gear("chest", "epic", rng, "survivor", "pebble")
	a2["set"] = "quarry_plate"
	a2["hero"] = "pebble"
	var a3 := GearDefs.make_gear("head", "epic", rng, "survivor", "ash_rook")
	a3["set"] = "foremans_kit"
	a3["hero"] = "ash_rook"
	for it in [GearDefs.make_gear("boots", "common", rng), a2, a1, a3, GearDefs.make_gear("legs", "rare", rng)]:
		GameState.add_to_stash(it)
	var order: Array = GameState.stash_view("set").map(func(x: Dictionary) -> String: return str(x.get("set", "")))
	_check(order == ["night_runner", "foremans_kit", "quarry_plate", "", ""], "set sort order %s" % [order])
	_check(GameState.set_owned("night_runner") == 1 and GameState.set_groups(GameState.stash_view("set")).size() == 4, "set groups")
	var h: Node = (load("res://scenes/ui/hangar.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(h)
	await get_tree().process_frame
	h.call("show_tab", "stash")
	h.call("set_stash_sort", "set")
	await get_tree().process_frame
	_check(h.find_child("SetHeader_night_runner", true, false) != null and h.find_child("SetHeader_none", true, false) != null, "stash set headers")
	h.call("cycle_stash_filter", "set")
	h.call("cycle_stash_filter", "set")
	_check((h.call("stash_shown") as Array).size() == 1, "set filter chip picks one set")
	h.call("set_stash_filters", {"group": "", "rarity": "", "set": "", "fits": ""})
	var tb := h.find_child("AutoSalvageToggle", true, false)
	_check(tb != null and bool(h.call("toggle_auto_salvage")) and GameState.auto_salvage_on(), "stash quick toggle")
	h.call("toggle_auto_salvage")
	_check(not GameState.auto_salvage_on(), "stash quick toggle off")
	h.queue_free()
	await get_tree().process_frame
	var lo: Node = (load("res://scenes/ui/loadout.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(lo)
	await get_tree().process_frame
	lo.call("set_hero", "ash_rook")
	lo.call("select_slot", "head")
	lo.call("set_sort", "set")
	await get_tree().process_frame
	_check(lo.find_child("SetHeader_foremans_kit", true, false) != null, "picker set headers")
	lo.queue_free()
	await get_tree().process_frame
	GameState.settings["auto_salvage_commons"] = keep_auto
	GameState.salvage_bin = keep_bin
	GameState.stash = keep_stash
	GameState.loadouts = keep_lo
	print("LOOT2_OK")


## P0 UI: full-stash overflow never salvages Rare+ (held instead), result
## TOTAL matches the bank, result buttons deaf during the reveal, admin taps.
func _test_p0_ui() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var keep_auto: Variant = GameState.settings.get("auto_salvage_commons", false)
	var keep_bin := GameState.salvage_bin.duplicate(true)
	var keep_stash := GameState.stash.duplicate(true)
	var keep_lo := GameState.loadouts.duplicate(true)
	var keep_pend := GameState.pending_rewards.duplicate(true)
	var keep_scrap := GameState.account_scrap
	for auto in [false, true]:
		GameState.set_setting("auto_salvage_commons", auto)
		GameState.stash.clear()
		GameState.loadouts.clear()
		GameState.pending_rewards.clear()
		GameState.salvage_bin.clear()
		while GameState.stash.size() < GameState.stash_capacity():
			GameState.add_to_stash(GearDefs.make_gear("boots", "common", rng))
		GameState.selected_mode_id = "drift"
		GameState.begin_run()
		var leg := GearDefs.make_weapon("ash_rook", "legendary", rng)
		var setc := GearDefs.make_gear("chest", "common", rng, "general", "ash_rook")
		setc["set"] = "night_runner"
		for it in [GearDefs.make_gear("legs", "common", rng), leg, GearDefs.make_gear("legs", "epic", rng), GearDefs.make_gear("head", "rare", rng), setc]:
			GameState.add_run_loot(it)
		GameState.on_extract_success()
		var held_r: Array = GameState.pending_rewards.map(func(x: Dictionary) -> String: return str(x["rarity"]))
		_check(GameState.result_held_n == 4 and GameState.pending_rewards.size() == 4 and held_r.has("legendary") and held_r.has("epic") and held_r.has("rare"), "overflow holds rare+/set auto=%s %s" % [auto, held_r])
		_check(GameState.result_overflow_n + GameState.result_auto_salvaged_n == 1, "only the plain common salvaged auto=%s" % auto)
		for e in GameState.salvage_bin:
			_check(str((e["item"] as Dictionary).get("rarity", "")) == "common", "bin has commons only")
		_check(GameState.stash.size() == GameState.stash_capacity(), "stash untouched")
		## Result TOTAL equals the bank after every payout; buttons deaf until shown.
		var rs: Node = (load("res://scenes/ui/result_screen.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(rs)
		await get_tree().process_frame
		var again: Button = null
		for b in rs.find_children("*", "Button", true, false):
			if (b as Button).text == "RUN AGAIN":
				again = b
		_check(again != null and again.mouse_filter == Control.MOUSE_FILTER_IGNORE and not bool(rs.get("actions_live")), "result buttons deaf during reveal")
		_check(rs.find_child("HeldLine", true, false) != null, "held line shown")
		rs.set("_skip", true)
		for i in range(90):
			await get_tree().process_frame
			if bool(rs.get("actions_live")):
				break
		await get_tree().create_timer(0.4).timeout
		var tot: Label = rs.find_child("ScrapTotal", true, false) as Label
		_check(tot != null and tot.text == str(GameState.account_scrap) and GameState.result_scrap_after == GameState.account_scrap, "result TOTAL %s vs %d" % [tot.text if tot else "none", GameState.account_scrap])
		_check(bool(rs.get("actions_live")) and is_instance_valid(again) and again.mouse_filter == Control.MOUSE_FILTER_STOP, "result buttons live after reveal")
		rs.queue_free()
		await get_tree().process_frame
		## Making room pulls held gear in.
		GameState.salvage(int(GameState.stash[0]["uid"]))
		_check(GameState.pending_rewards.size() == 3 and GameState.stash.size() == GameState.stash_capacity(), "salvage claims a held item")
	## Admin: a touch + its emulated mouse copy count once; 5 real taps toggle.
	var adm: Node = (load("res://scripts/autoload/admin.gd") as GDScript).new()
	add_child(adm)
	await get_tree().process_frame
	_check(bool(adm.get("allowed")), "admin allowed in this build")
	if adm:
		var was := bool(adm.get("enabled"))
		var t0 := 1000000
		var toggled := false
		for i in range(3):
			toggled = bool(adm.call("register_tap", Vector2(20, 20), t0 + i * 300)) or toggled
			toggled = bool(adm.call("register_tap", Vector2(20, 20), t0 + i * 300 + 5)) or toggled
		_check(not toggled and bool(adm.get("enabled")) == was, "3 doubled taps do not unlock")
		adm.set("_taps", [])
		for i in range(5):
			toggled = bool(adm.call("register_tap", Vector2(20, 20), t0 + 5000 + i * 300))
		_check(toggled and bool(adm.get("enabled")) != was, "5 taps toggle admin")
		adm.call("set_enabled", was)
		adm.set("_taps", [])
		adm.queue_free()
	GameState.settings["auto_salvage_commons"] = keep_auto
	GameState.salvage_bin = keep_bin
	GameState.stash = keep_stash
	GameState.loadouts = keep_lo
	GameState.pending_rewards = keep_pend
	GameState.account_scrap = keep_scrap
	print("P0_UI_OK")


## 8c) What Gear shows is what prep shows and what the match applies — also
## after cycling survivors on the Gear screen (owner bug: "equipped a bunch,
## the loadout wasn't the same").
func _test_gear_deploy_sync() -> void:
	GameState.stash.clear()
	GameState.loadouts.clear()
	GameState.insured.clear()
	GameState.camp["stash"] = 3
	var keep := [GameState.selected_mode_id, GameState.fast_timers, GameState.tutorial_done]
	GameState.selected_character_id = "ash_rook"
	GameState.fast_timers = true
	GameState.tutorial_done = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	GameState.loadout_from = "prep"
	var lo: Node = (load("res://scenes/ui/loadout.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(lo)
	await get_tree().process_frame
	## Cycle to another survivor and equip there.
	lo.call("cycle_hero", 1)
	lo.call("cycle_hero", 1)
	var x := str(lo.call("get_hero"))
	_check(x != "ash_rook" and GameState.selected_character_id == x, "gear hero = deploy hero")
	for it in [GearDefs.make_weapon(x, "epic", rng), GearDefs.make_gear("head", "rare", rng), GearDefs.make_gear("boots", "legendary", rng), GearDefs.make_gear("charm", "common", rng)]:
		GameState.add_to_stash(it)
		var u := int(GameState.stash[GameState.stash.size() - 1]["uid"])
		var sl := GameState.slot_for(u, x)
		lo.call("select_slot", sl)
		lo.call("equip_item", u)
	## Look at other survivors, come back.
	lo.call("cycle_hero", 1)
	lo.call("cycle_hero", -1)
	var shown: Dictionary = lo.call("shown_uids")
	_check(shown.size() == 4 and GameState.selected_character_id == x, "gear shows 4 on %s" % x)
	lo.queue_free()
	await get_tree().process_frame
	var p: Node = (load("res://scenes/ui/prep.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(p)
	await get_tree().process_frame
	_check(str(p.get("_hero")) == x and (p.call("gear_uids") as Dictionary) == shown, "prep shows the gear screen's kit")
	p.queue_free()
	await get_tree().process_frame
	## Deploy: the match applies exactly this kit.
	GameState.begin_run()
	var wi: Dictionary = GameState.gear.get("weapon_item", {})
	_check(int(wi.get("uid", -1)) == int(shown["weapon"]), "deploy weapon item")
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	for i in range(10):
		await get_tree().physics_frame
	var pl: Node = m.get_node("World/Player")
	var pw: Dictionary = pl.get("_weapon")
	var eq := GameState.equipped_items(x)
	var applied := {}
	for sl2 in eq.keys():
		applied[str(sl2)] = int((eq[sl2] as Dictionary)["uid"])
	_check(applied == shown and str(pw.get("name", "")) == str(GameState.stash_item(int(shown["weapon"])).get("name", "?")), "match applies gear %s" % [pw.get("name", "")])
	_check(GameState.gear_stat("max_hp") >= 0.0 and GameState.selected_character_id == x, "match hero")
	TouchInput.clear_sticks()
	m.queue_free()
	for k in range(5):
		await get_tree().process_frame
	GameState.loadout_from = "hangar"
	GameState.stash.clear()
	GameState.loadouts.clear()
	GameState.selected_character_id = "ash_rook"
	GameState.selected_mode_id = keep[0]
	GameState.fast_timers = keep[1]
	GameState.tutorial_done = keep[2]
	GameState.reset_loadout_to_defaults()
	print("GEAR_SYNC_OK")


## 9) Each general set at 6 pieces in a short live match (2 / 4 / 6 bonuses).
func _test_full_sets() -> void:
	var i := 0
	for gid in GearDefs.GENERAL_SETS.keys():
		GameState.stash.clear()
		GameState.loadouts.clear()
		GameState.selected_character_id = ["ash_rook", "nyx_caldera", "sister_cinder", "pebble"][i]
		var rng := RandomNumberGenerator.new()
		for sl in GearDefs.ARMOR_SLOTS:
			var it := GearDefs.make_gear(str(sl), "epic", rng, "general")
			it["set"] = gid
			GameState.add_to_stash(it)
			GameState.equip(GameState.selected_character_id, str(sl), int(GameState.stash[GameState.stash.size() - 1]["uid"]))
		GameState.begin_run()
		_check(GameState.has_set(str(gid), 6), "%s 6pc" % gid)
		var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(m)
		get_tree().current_scene = m
		var player: Node2D = m.get_node("World/Player")
		var es: PackedScene = load("res://scenes/entities/enemy.tscn")
		for f in range(300):
			if f % 25 == 1 and get_tree().get_nodes_in_group("enemies").size() < 8:
				var e: CharacterBody2D = es.instantiate()
				e.call("setup", player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 120.0, 0.4, 0.3, 1.0, "scrap_hound")
				player.get_parent().add_child(e)
			TouchInput.set_move(Vector2(cos(f * 0.05), sin(f * 0.04)))
			if f % 50 == 0:
				TouchInput.pulse_dash()
			if f % 90 == 10 and is_instance_valid(player):
				player.call("take_damage", 4.0, null)
			await get_tree().physics_frame
		print("SET_%s kills=%d" % [gid, GameState.kills])
		TouchInput.clear_sticks()
		m.queue_free()
		for k in range(5):
			await get_tree().process_frame
		i += 1
	GameState.stash.clear()
	GameState.loadouts.clear()
	print("SETS_OK")


## 10) Logbook (daily, stories, milestones, bond) and every in-run event live.
func _test_quests_events() -> void:
	GameState.stash.clear()
	GameState.loadouts.clear()
	GameState.camp = {}
	GameState.daily = {}
	var qs := GameState.daily_quests()
	var types := {}
	for q in qs:
		types[str(q["type"])] = true
	_check(qs.size() == 3 and types.size() == 3, "daily 3 distinct")
	_check(str(QuestDefs.roll_daily("2026-01-01", 2)[0]["label"]) == str(QuestDefs.roll_daily("2026-01-01", 2)[0]["label"]), "daily deterministic")
	GameState.daily = {"date": GameState.today(), "quests": [
		{"type": "kills", "need": 2, "have": 0, "reward": 50, "claimed": false, "label": "k"},
		{"type": "kills_kind", "kind": "rad_gator", "need": 1, "have": 0, "reward": 10, "claimed": false, "label": "kk"},
		{"type": "extract_mult", "mult": 2.0, "need": 1, "have": 0, "reward": 10, "claimed": false, "label": "em"}]}
	GameState.quest_event("kills", 1, {"kind": "rad_gator"})
	GameState.quest_event("kills", 1, {"kind": "scrap_hound"})
	GameState.quest_event("extract", 1, {"tier": 2, "mult": 1.4})
	var dq := GameState.daily_quests()
	_check(int(dq[0]["have"]) == 2 and int(dq[1]["have"]) == 1 and int(dq[2]["have"]) == 0, "daily progress")
	var s0 := GameState.account_scrap
	_check(GameState.claim_daily(0) == 50 and GameState.account_scrap == s0 + 50 and GameState.claim_daily(0) == 0, "daily claim once")
	## Story: five chapters, the last pays the named Legendary.
	GameState.selected_character_id = "ash_rook"
	GameState.stories = {}
	GameState.quest_event("extract", 1, {"tier": 1, "mult": 1.0})
	GameState.quest_event("kills", 80, {"kind": "x"})
	GameState.quest_event("ability", 25)
	GameState.quest_event("event", 2)
	_check(int(GameState.story_state("ash_rook")["step"]) == 4, "story step 4 (%d)" % int(GameState.story_state("ash_rook")["step"]))
	GameState.quest_event("extract", 1, {"tier": 1, "mult": 2.5})
	var leg := false
	for it in GameState.stash:
		if str(it.get("legendary", "")) == "last_shift":
			leg = true
	_check(leg and int(GameState.story_state("ash_rook")["step"]) == 5, "story legendary")
	_check(int(GameState.story_state("pebble")["step"]) == 0, "story per survivor")
	## Milestones + cosmetics; Pet Bond.
	GameState.milestones = {}
	GameState.camp["generator"] = 5
	var ms := GameState.check_milestones()
	_check(GameState.has_cosmetic("banner") and GameState.has_cosmetic("case") and ms.size() >= 2, "milestones")
	GameState.kennel_bond = {}
	GameState.selected_pet_id = "noel"
	GameState.add_bond("noel", EventDefs.BOND_XP_PER_LEVEL * 2)
	_check(GameState.bond_level("noel") == 2 and is_equal_approx(GameState.pet_power_mult(), 1.0 + 2.0 * EventDefs.BOND_DAMAGE_PER_LEVEL), "pet bond")
	## Every event in a live match.
	GameState.selected_mode_id = "drift"
	GameState.fast_timers = false
	GameState.tutorial_done = true
	GameState.begin_run()
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	var player: Node2D = m.get_node("World/Player")
	var ev: Node = m.get_node("RunEvents")
	await get_tree().process_frame
	for id in EventDefs.IN_RUN.keys():
		ev.call("start_event", str(id))
		_check(str(ev.call("active_event")) == str(id), "event %s starts" % id)
		for f in range(40):
			await get_tree().physics_frame
		match str(id):
			"scrap_spike":
				player.global_position = ev.get("_target_pos")
				await get_tree().physics_frame
				await get_tree().physics_frame
				_check(GameState.event_scrap_mult == 2.0, "spike doubles")
			"dust_surge":
				_check(GameState.event_enemy_damage > 1.0, "surge hits harder")
			"pad_heat":
				_check(float(m.get("_phase_time_left")) <= float(EventDefs.IN_RUN["pad_heat"]["open_in"]) + 0.01, "pad heat early")
			"supply_crash":
				player.global_position = ev.get("_target_pos")
			"elite_hunt":
				var tgt: Node = ev.get("_target_node")
				if tgt != null and is_instance_valid(tgt):
					tgt.call("take_damage", 999999.0, Vector2.RIGHT)
		for f in range(30):
			await get_tree().physics_frame
		print("EVENT_%s active=%s done=%d" % [id, ev.call("active_event"), GameState.events_done_run])
	_check(GameState.events_done_run >= 2, "events completed %d" % GameState.events_done_run)
	## At-extract bonuses.
	var es: PackedScene = load("res://scenes/entities/enemy.tscn")
	for k in range(3):
		var e: CharacterBody2D = es.instantiate()
		e.call("setup", player.global_position + Vector2(60 + k * 20, 0), 50.0, 0.0, 0.0, "muck_golem")
		player.get_parent().add_child(e)
	await get_tree().physics_frame
	GameState.extract_bonus_scrap = 0
	m.call("_extract_bonuses")
	_check(GameState.extract_bonus_scrap > 0, "ambush bounty")
	m.queue_free()
	for k in range(5):
		await get_tree().process_frame
	## Logbook screen.
	var lb: Node = (load("res://scenes/ui/logbook.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(lb)
	for t in ["daily", "stories", "milestones"]:
		lb.call("show_tab", t)
		await get_tree().process_frame
	lb.queue_free()
	await get_tree().process_frame
	GameState.stash.clear()
	GameState.camp = {}
	print("QUESTS_EVENTS_OK")


## 11) Tiers 1–10 (Part 5): table values, window rule, unlocks, tier select,
## elites / bosses on schedule in a live (fast-timer) match.
func _test_tiers() -> void:
	var tiers := ModeDefs.all_tiers()
	_check(tiers.size() == 10 and ModeDefs.all_modes().size() == 10, "10 tiers exposed")
	var expect := [[0.85, 0.75, 0.10], [1.0, 1.0, 0.15], [1.15, 1.25, 0.20], [1.30, 1.5, 0.25], [1.50, 1.8, 0.30],
		[1.70, 2.1, 0.35], [1.95, 2.5, 0.40], [2.20, 3.0, 0.45], [2.50, 3.5, 0.50], [3.00, 4.5, 0.55]]
	for i in range(10):
		var t: Dictionary = tiers[i]
		var e: Array = expect[i]
		_check(is_equal_approx(float(t["enemy_hp"]), float(e[0])) and is_equal_approx(float(t["payout_mult"]), float(e[1]))
			and is_equal_approx(float(t["death_keep"]), float(e[2])), "tier %d table" % (i + 1))
		if i >= 2:
			var prev: Dictionary = tiers[i - 1]
			_check(float(t["window_open"]) == float(prev["window_open"]) - 1.0 and float(t["window_every"]) > float(prev["window_every"]), "tier %d window rule" % (i + 1))
	_check(float(tiers[0]["first_window"]) == 90.0 and float(tiers[1]["window_open"]) == 15.0, "haze/drift unchanged")
	_check(ModeDefs.canonical_id("squall") == "smog" and ModeDefs.canonical_id("medium") == "drift", "old tier ids")
	## Unlocks: extract on a tier opens the next one.
	GameState.best_tier_extracted = 0
	_check(GameState.highest_unlocked_tier() == 2 and not GameState.is_tier_unlocked(3), "start unlocks")
	GameState.selected_mode_id = "drift"
	GameState.begin_run()
	GameState.on_extract_success()
	_check(GameState.is_tier_unlocked(3) and not GameState.is_tier_unlocked(4), "drift extract opens smog")
	GameState.apply_save({"version": 4, "migrated_hangar_v4": true, "selected_mode_id": "blight"})
	_check(GameState.selected_mode_id != "blight" and GameState.best_tier_extracted == 0, "locked tier not selected from save")
	## Tier select screen.
	var ms: Node = (load("res://scenes/ui/mode_select.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(ms)
	for k in range(3):
		await get_tree().process_frame
	_check(not bool(ms.call("select_tier", "dustfall")), "can't pick locked tier")
	GameState.best_tier_extracted = 9
	_check(bool(ms.call("select_tier", "dustfall")) and GameState.selected_mode_id == "dustfall", "pick unlocked tier")
	ms.queue_free()
	await get_tree().process_frame
	## Elites from 3, bosses from 5, two elites from 8 (fast timers).
	for tid in ["drift", "smog", "blackout"]:
		GameState.selected_mode_id = tid
		GameState.selected_character_id = "pebble"
		GameState.fast_timers = true
		GameState.tutorial_done = true
		GameState.begin_run()
		var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(m)
		get_tree().current_scene = m
		var player: Node2D = m.get_node("World/Player")
		Engine.time_scale = 4.0
		var elites := 0
		var bosses := 0
		var seen := {}
		var f := 0
		while f < 2400 and is_instance_valid(m) and not bool(m.get("_ended")):
			f += 1
			if is_instance_valid(player):
				player.set("hp", player.get("max_hp"))
			for e in get_tree().get_nodes_in_group("elites") + get_tree().get_nodes_in_group("bosses"):
				var iid := e.get_instance_id()
				## Only the tier schedule counts (radio bounties, Elite Hunt, the Dust
				## Warden etc. can add elites on any tier — that made this flaky).
				if not seen.has(iid) and e.has_meta("scheduled"):
					seen[iid] = true
					if e.is_in_group("bosses"):
						bosses += 1
					else:
						elites += 1
			if float(m.get("_match_time")) > (ModeDefs.BOSS_FIRST + 5.0) * GameState.timer_scale():
				break
			await get_tree().physics_frame
		var tier := int(GameState.get_mode()["tier"])
		Engine.time_scale = 1.0
		print("TIER_%s elites=%d bosses=%d t=%.1f" % [tid, elites, bosses, float(m.get("_match_time"))])
		if tier < ModeDefs.ELITE_FROM_TIER:
			_check(elites == 0 and bosses == 0, "%s no specials" % tid)
		else:
			_check(elites >= (2 if tier >= ModeDefs.DOUBLE_ELITE_FROM_TIER else 1), "%s elites %d" % [tid, elites])
			_check((bosses >= 1) == (tier >= ModeDefs.BOSS_FROM_TIER), "%s bosses %d" % [tid, bosses])
		m.queue_free()
		for k in range(5):
			await get_tree().process_frame
	GameState.fast_timers = false
	print("TIERS_OK")


## Depth E1: old saves, brewing, tonic slots + effects, backpack + medicine,
## banking / losing the pack, plague exposure, and a short Blight match.
func _test_depth_e1() -> void:
	GameState.apply_save({"version": 4, "migrated_hangar_v4": true})
	_check(GameState.ingredients.is_empty() and GameState.tonics.is_empty() and GameState.tonic_loadout.is_empty(), "e1 old save defaults")
	GameState.apply_save({"version": 4, "migrated_hangar_v4": true, "ingredients": {"herb": 3, "bogus": 2, "dust_shard": -4},
		"tonics": {"menders": 2, "x": 1}, "tonic_loadout": ["menders", "menders", "nope"]})
	_check(GameState.ingredients == {"herb": 3} and GameState.tonics == {"menders": 2} and GameState.tonic_loadout == ["menders"], "e1 save sanitised")
	GameState.camp.clear()
	GameState.loadouts.clear()
	GameState.selected_character_id = "ash_rook"
	GameState._compute_gear()
	## Brewing + slots.
	GameState.ingredients = {"herb": 5, "plague_gland": 2}
	GameState.tonics = {}
	GameState.tonic_loadout = []
	_check(GameState.can_brew("menders") and not GameState.can_brew("spark"), "e1 can_brew")
	_check(GameState.brew("menders") and GameState.tonic_count("menders") == 1 and GameState.ingredient_count("herb") == 2, "e1 brew")
	_check(not GameState.brew("menders"), "e1 brew needs ingredients")
	GameState.camp[HangarDefs.station_id("sister_cinder")] = 4
	GameState.ingredients["herb"] = 2
	_check(GameState.brew("ward") and GameState.tonic_count("ward") == 2, "e1 double brew at rank 4")
	GameState.camp.clear()
	_check(GameState.tonic_slot_count() == 1, "e1 one slot")
	GameState.toggle_tonic("menders")
	GameState.toggle_tonic("ward")
	_check(GameState.tonic_loadout == ["ward"], "e1 slot swaps")
	GameState.camp[HangarDefs.station_id("sister_cinder")] = 2
	GameState.toggle_tonic("menders")
	_check(GameState.tonic_slot_count() == 2 and GameState.tonic_loadout.size() == 2, "e1 two slots")
	## Deploy drinks them.
	GameState.selected_mode_id = "blight"
	GameState.best_tier_extracted = 9
	GameState.begin_run()
	_check(GameState.run_tonics.size() == 2 and GameState.tonic_count("menders") == 0 and GameState.tonic_count("ward") == 1, "e1 drink on deploy")
	_check(GameState.tonic_loadout == ["ward"], "e1 empty slot cleared")
	_check(is_equal_approx(GameState.tonic_fx("regen"), 1.2) and is_equal_approx(GameState.tonic_fx_mult("exposure_mult"), 0.5), "e1 tonic fx")
	## Exposure: Plague Ward halves it; Cinder resists; stages.
	GameState.add_exposure(40.0)
	_check(is_equal_approx(GameState.exposure, 20.0), "e1 exposure ward %.1f" % GameState.exposure)
	GameState.run_tonics = []
	GameState.exposure = 0.0
	GameState.selected_character_id = "sister_cinder"
	GameState.add_exposure(40.0)
	_check(is_equal_approx(GameState.exposure, 30.0), "e1 exposure cinder %.1f" % GameState.exposure)
	_check(MedicineDefs.stage_of(39.0) == -1 and MedicineDefs.stage_of(45.0) == 0 and MedicineDefs.stage_of(100.0) == 2, "e1 stages")
	GameState.selected_character_id = "ash_rook"
	GameState.selected_mode_id = "drift"
	GameState.exposure = 0.0
	GameState.add_exposure(50.0)
	_check(GameState.exposure == 0.0, "e1 no exposure below tier 5")
	## Backpack + medicine.
	GameState.camp.clear()
	GameState.begin_run()
	_check(GameState.pack_capacity() == 9, "e1 pack 9")
	_check(GameState.add_to_pack("medicine") and GameState.add_to_pack("medicine") and GameState.add_to_pack("medicine"), "e1 pack fill")
	_check(not GameState.add_to_pack("medicine") and GameState.pack_weight() == 9, "e1 pack full")
	_check(GameState.add_to_pack("herb", 2) and GameState.pack_weight() == 9 and GameState.pouch() == {"herb": 2}, "e1 pouch is weightless")
	_check(is_equal_approx(GameState.carry_speed_mult(), 1.0 - 0.18) and GameState.smells_medicine(), "e1 carry slow")
	var bag := GameState.bag_value()
	_check(bag == 3 * MedicineDefs.MEDICINE_SCRAP, "e1 medicine in bag")
	GameState.run_tonics = ["saints"]
	_check(GameState.carry_speed_mult() == 1.0 and not GameState.smells_medicine(), "e1 saints carry free")
	GameState.run_tonics = []
	GameState.camp["backpack"] = 3
	_check(GameState.pack_capacity() == 18 and GameState.add_to_pack("medicine"), "e1 pack upgrade")
	GameState.ingredients = {}
	GameState.on_extract_success()
	_check(GameState.ingredient_count("medicine") == 4 and GameState.ingredient_count("herb") == 2 and GameState.run_pack.is_empty(), "e1 pack banked")
	_check(GameState.payout_this_run >= int((ModeDefs.BAG_STIPEND + bag) * float(GameState.get_mode()["payout_mult"])), "e1 medicine pays")
	## Backlog 1 economy: diminishing bag above the knee, boss bonus paid once.
	_check(is_equal_approx(ModeDefs.bag_curve(80.0), 80.0) and ModeDefs.bag_curve(400.0) < 300.0 and ModeDefs.bag_curve(400.0) > ModeDefs.bag_curve(200.0), "econ bag curve")
	GameState.begin_run()
	GameState.on_boss_killed("dread_naught")
	GameState.on_boss_killed("mutant_overlord")
	_check(is_equal_approx(GameState.boss_loot_bonus, GearDefs.BOSS_LOOT_BONUS_CAP), "econ boss bonus capped")
	GameState.boss_loot_bonus = 0.0
	GameState.begin_run()
	GameState.add_to_pack("medicine")
	GameState.on_wipe()
	_check(GameState.ingredient_count("medicine") == 4 and GameState.run_pack.is_empty(), "e1 pack lost on death")
	## A short Blight match: crates placed, fog builds exposure, stages bite.
	GameState.camp.clear()
	GameState.selected_mode_id = "blight"
	GameState.selected_character_id = "vesper_thorn"
	GameState.fast_timers = true
	GameState.tutorial_done = true
	GameState.tonic_loadout = []
	GameState.begin_run()
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	for k in range(4):
		await get_tree().physics_frame
	var player: Node2D = m.get_node("World/Player")
	var ps0: Node = m.get_node("PlagueSystem")
	_check(get_tree().get_nodes_in_group("medicine_crates").size() == MedicineDefs.crates_at_start(5), "e1 crates placed")
	ps0.call("on_window_open", 1)
	await get_tree().physics_frame
	_check(get_tree().get_nodes_in_group("medicine_crates").size() == MedicineDefs.crates_at_start(5) + 1, "e1 window adds a crate")
	var ps: Node = ps0
	ps.call("spawn_zone", player.global_position, 150.0)
	for k in range(40):
		player.set("hp", player.get("max_hp"))
		await get_tree().physics_frame
	_check(GameState.exposure > 1.0, "e1 fog builds exposure %.1f" % GameState.exposure)
	GameState.exposure = 75.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(is_equal_approx(float(player.get("exposure_move")), -0.14), "e1 sick slows")
	var hp0 := float(player.get("hp"))
	for k in range(30):
		await get_tree().physics_frame
	_check(float(player.get("hp")) < hp0, "e1 sick drains")
	## Medicine crate pickup + kill drops + drop from the pack.
	var crate: Node2D = get_tree().get_nodes_in_group("medicine_crates")[0]
	crate.global_position = player.global_position
	for k in range(30):
		await get_tree().physics_frame
	_check(GameState.medicine_carried() == 1, "e1 crate picked up")
	HaulPickup.drop_kill(m.get_node("World"), player.global_position + Vector2(70, 0), EnemyDefs.MACHINE, "boss")
	for k in range(60):
		await get_tree().physics_frame
	_check(GameState.pack_count("dust_shard") >= 1, "e1 kill drops picked up")
	var hud: Node = m.get_node("HUD")
	hud.call("_open_pause")
	await get_tree().process_frame
	var pm: Node = null
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.has_method("show_pack"):
			pm = n
	if pm:
		pm.call("show_pack")
		var before := GameState.pack_weight()
		pm.call("drop_item", "medicine")
		_check(GameState.pack_weight() == before - MedicineDefs.MEDICINE_WEIGHT, "e1 drop from pack")
		pm.call("close")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var dropped := 0
	for h in get_tree().get_nodes_in_group("haul"):
		if bool(h.get("dropped")):
			dropped += 1
	_check(dropped == 1 and GameState.medicine_carried() == 0, "e1 dropped stays on the ground")
	m.queue_free()
	GameState.fast_timers = false
	get_tree().paused = false
	for k in range(3):
		await get_tree().process_frame
	## The Apothecary tab.
	GameState.ingredients = {"herb": 3}
	var hg: Node = (load("res://scenes/ui/hangar.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(hg)
	await get_tree().process_frame
	hg.call("show_tab", "brew")
	await get_tree().process_frame
	_check(bool(hg.call("brew", "menders")) and bool(hg.call("toggle_tonic", "menders")) and GameState.tonic_loadout.has("menders"), "e1 brew tab")
	hg.queue_free()
	await get_tree().process_frame
	GameState.camp.clear()
	GameState.selected_mode_id = "drift"
	print("DEPTH_E1_OK")


## Depth E5: loadouts — weapon styles, ability versions, quirks, prep screen.
func _test_depth_e5() -> void:
	for h in CharacterDefs.PLAYABLE_IDS:
		var st: Array = KitDefs.styles(str(h))
		_check(st.size() == 3 and KitDefs.ABILITIES.has(h) and KitDefs.quirks(str(h)).size() == 3, "e5 kit defs %s" % h)
		for q in KitDefs.quirks(str(h)):
			_check(not KitDefs.quirk(str(q)).is_empty(), "e5 quirk exists %s" % q)
		for s in st:
			_check(ResourceLoader.exists(KitDefs.icon_path(str(h), str(s["id"]))), "e5 style icon %s %s" % [h, s["id"]])
	## Unlock gating by station rank.
	GameState.camp.clear()
	GameState.kit = {}
	var sid := HangarDefs.station_id("ash_rook")
	_check(not GameState.set_style("ash_rook", "cluster") and GameState.kit_style("ash_rook") == "boom", "e5 style locked at rank 0")
	_check(not GameState.set_ability_version("ash_rook", "b") and GameState.kit_ability("ash_rook") == "a", "e5 ability B locked")
	GameState.camp[sid] = 2
	_check(GameState.set_style("ash_rook", "cluster") and not GameState.set_style("ash_rook", "mortar"), "e5 rank 2 unlocks style 2 only")
	GameState.camp[sid] = 4
	_check(GameState.set_style("ash_rook", "mortar") and GameState.set_ability_version("ash_rook", "b"), "e5 rank 4 unlocks all")
	_check(not GameState.set_quirk("ash_rook", "bloodthirst") and GameState.set_quirk("ash_rook", "glass_cannon"), "e5 quirk list per hero")
	GameState.camp[sid] = 0
	_check(GameState.kit_style("ash_rook") == "boom" and GameState.kit_ability("ash_rook") == "a", "e5 kit falls back when station drops")
	## Style edits.
	var base := LoadoutStubs.weapon_for_character("ash_rook")
	var cl := KitDefs.apply_style(base, "ash_rook", "cluster")
	_check(int(cl.get("pellets", 0)) == 2 and absf(float(cl["damage"]) - float(base["damage"]) * 0.55) <= 0.51, "e5 cluster style")
	var mo := KitDefs.apply_style(base, "ash_rook", "mortar")
	_check(int(mo["mag_size"]) == 3 and str((mo["coats"] as Array)[-1]["coat"]) == "fire" and str(mo["style"]) == "mortar", "e5 mortar style")
	var sw := KitDefs.apply_style(LoadoutStubs.weapon_for_character("pebble"), "pebble", "sweep")
	_check(is_equal_approx(float(sw["melee"]["arc_deg"]), 210.0), "e5 sweep widens the arc")
	_check(KitDefs.apply_style(base, "ash_rook", "boom").get("pellets", 1) == base.get("pellets", 1), "e5 base style unchanged")
	## Save sanitize.
	GameState._load_depth({"kit": {"ash_rook": {"style": "laser", "ability": "b", "quirk": "bloodthirst"},
		"pebble": {"style": "sweep", "ability": "x", "quirk": "berserker"}, "nobody": {"style": "boom"}, "vesper_thorn": 5}})
	_check(GameState.kit_of("ash_rook")["style"] == "boom" and GameState.kit_of("ash_rook")["quirk"] == "", "e5 save drops bad style / quirk")
	_check(GameState.kit_of("pebble")["style"] == "sweep" and GameState.kit_of("pebble")["ability"] == "a" and GameState.kit_of("pebble")["quirk"] == "berserker", "e5 save keeps good entries")
	_check(not GameState.kit.has("nobody"), "e5 save drops unknown heroes")
	GameState._load_depth({})
	_check(GameState.kit.is_empty() and GameState.kit_style("vesper_thorn") == "bolt", "e5 old saves default kit")
	## Melee survivors ignore ranged-only quirks.
	GameState.selected_character_id = "pebble"
	GameState.reset_loadout_to_defaults()
	GameState.kit_of("pebble")["quirk"] = "no_reload"
	_check(GameState.quirk_fx("no_reload") == 0.0, "e5 melee ignores Hot Barrel")
	GameState.kit_of("pebble")["quirk"] = ""
	## In match: Rook with Slag Mortar, Short Charge and Glass Cannon.
	GameState.kit = {"ash_rook": {"style": "mortar", "ability": "b", "quirk": "glass_cannon"}}
	var m: Node = await _depth_match("smog", "ash_rook", {sid: 4})
	var player: Node2D = m.get_node("World/Player")
	var w: Dictionary = player.get("_weapon")
	_check(str(w.get("style", "")) == "mortar", "e5 style reaches the player")
	var ab: Dictionary = player.get("_ability")
	_check(ab.has("end_slam_radius") and str(ab.get("version", "")) == "b", "e5 ability B reaches the player")
	var mhp := float(CharacterDefs.get_character("ash_rook").get("max_hp", 100.0))
	_check(float(player.get("max_hp")) < mhp * 0.95, "e5 glass cannon lowers max HP (%.0f vs %.0f)" % [float(player.get("max_hp")), mhp])
	_check(GameState.quirk_fx("damage") > 0.25, "e5 glass cannon damage")
	var tgt := _mob(m, "scav_bear", player.global_position + Vector2(40, 0))
	tgt.set("max_hp", 5000.0)
	tgt.set("hp", 5000.0)
	await get_tree().physics_frame
	player.call("_on_rush_end")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(float(tgt.get("hp")) < 5000.0, "e5 short charge slams")
	await _end_depth_match(m)
	## Vesper: Hot Barrel never reloads, overheats; Steady Hands vs moving.
	GameState.kit = {"vesper_thorn": {"style": "semi", "ability": "a", "quirk": "no_reload"}}
	m = await _depth_match("smog", "vesper_thorn", {HangarDefs.station_id("vesper_thorn"): 2})
	player = m.get_node("World/Player")
	player.set("max_hp", 99999.0)
	player.set("hp", 99999.0)
	_check(int((player.get("_weapon") as Dictionary).get("mag_size", 0)) == 8, "e5 semi style mag")
	player.set("_ammo", 0)
	player.call("_try_shoot")
	_check(float(player.get("_reload_left")) <= 0.0, "e5 hot barrel no reload")
	player.set("_heat", GameState.quirk_fx("heat_max") - 0.001)
	var foe := _mob(m, "scav_bear", player.global_position + Vector2(120, 0))
	foe.set("max_hp", 99999.0)
	foe.set("hp", 99999.0)
	player.set("_fire_cd", 0.5)
	player.set("_target", foe)
	player.call("_tick_heat", 0.05)
	_check(float(player.get("_overheat_left")) > 0.0 and float(player.call("heat_ratio")) == 1.0, "e5 hot barrel overheats")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(str(m.get_tree().get_first_node_in_group("hud").get("_ammo_label").text).begins_with("OVERHEAT"), "e5 HUD shows heat")
	await _end_depth_match(m)
	## Berserker below half HP; Dust Eater stage damage.
	GameState.kit = {"quill_marrow": {"style": "bayonet", "ability": "a", "quirk": "berserker"}}
	m = await _depth_match("smog", "quill_marrow")
	player = m.get_node("World/Player")
	var q0 := float(player.call("_quirk_damage"))
	player.set("hp", float(player.get("max_hp")) * 0.3)
	_check(is_equal_approx(q0, 1.0) and float(player.call("_quirk_damage")) > 1.3, "e5 berserker")
	await _end_depth_match(m)
	## Prep screen builds, respects locks, and routes the gear button.
	GameState.camp.clear()
	GameState.kit = {}
	GameState.selected_character_id = "nyx_caldera"
	var prep: Node = (load("res://scenes/ui/prep.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(prep)
	await get_tree().process_frame
	_check(not bool(prep.call("pick_style", "viper")) and bool(prep.call("pick_quirk", "scavenger")), "e5 prep locks / picks")
	_check(GameState.kit_quirk("nyx_caldera") == "scavenger" and GameState.run_scrap_mult() > 1.3, "e5 scavenger scrap")
	var btns := 0
	for b in prep.find_children("*", "Button", true, false):
		btns += 1
	_check(btns >= 10, "e5 prep rows (%d)" % btns)
	prep.queue_free()
	GameState.camp.clear()
	GameState.selected_character_id = "ash_rook"
	GameState.reset_loadout_to_defaults()
	await get_tree().process_frame
	print("DEPTH_E5_OK")


## Depth E6: Salvage Cores, the Workshop, mech pets and their tricks.
func _test_depth_e6() -> void:
	for mid in PetDefs.MECH_IDS:
		var d := PetDefs.get_pet(str(mid))
		_check(str(d["id"]) == str(mid) and HangarDefs.KENNEL.has(mid), "e6 mech def %s" % mid)
		var st := UnitAnim.load_states(str(d["anim"]))
		_check(st.has("idle") and st.has("walk") and st.has("attack") and st.has("death"), "e6 mech art %s" % mid)
	_check(ResourceLoader.exists(MedicineDefs.icon_path("salvage_core")) and MedicineDefs.weight("salvage_core") == 0, "e6 salvage core is a pouch item")
	## Machine elites always drop cores.
	var holder := Node2D.new()
	get_tree().root.add_child(holder)
	HaulPickup.drop_kill(holder, Vector2.ZERO, "machine", "elite")
	await get_tree().process_frame
	var cores := 0
	for n in holder.get_children():
		if str(n.get("id")) == "salvage_core":
			cores += 1
	_check(cores >= 1, "e6 machine elite drops a core")
	holder.queue_free()
	## Workshop gating.
	GameState.mechs_built = {}
	GameState.ingredients["salvage_core"] = 0
	var keep_mat := GameState.material_count("salvage_core")
	GameState.materials["salvage_core"] = 0
	GameState.account_scrap = 5000
	_check(not GameState.can_build_mech("mech_hound") and not GameState.try_buy_camp("kennel_mech_hound"), "e6 needs cores; bay closed")
	GameState.ingredients["salvage_core"] = 10
	_check(GameState.build_mech("mech_hound") and GameState.salvage_cores() == 6 and GameState.account_scrap == 4700, "e6 build spends cores + scrap")
	_check(not GameState.build_mech("mech_hound") and GameState.pet_available("mech_hound") and not GameState.pet_available("drone_bat"), "e6 built once")
	GameState.ingredients["salvage_core"] = 1
	GameState.materials["salvage_core"] = 4
	_check(GameState.salvage_cores() == 5 and GameState.build_mech("drone_bat") and GameState.salvage_cores() == 0, "e6 boss-material cores count too")
	GameState.mechs_built.erase("drone_bat")
	GameState.materials["salvage_core"] = keep_mat
	_check(GameState.try_buy_camp("kennel_mech_hound") and GameState.kennel_rank("mech_hound") == 1, "e6 mech bay ranks")
	var hk := HangarDefs.apply_kennel(PetDefs.get_pet("mech_hound"), 3)
	_check(int(hk["shock_chain"]) == 6, "e6 kennel ranks reach the mech")
	## Save sanitize.
	GameState.selected_pet_id = "rust_mule"
	GameState._load_depth({"mechs_built": {"mech_hound": true, "noel": true, "bogus": true}})
	_check(GameState.mechs_built.size() == 1 and GameState.mechs_built.has("mech_hound"), "e6 save keeps only real mechs")
	_check(GameState.selected_pet_id == PetDefs.default_id(), "e6 unbuilt mech falls back to Noel")
	GameState._load_depth({})
	_check(GameState.mechs_built.is_empty(), "e6 old saves: no mechs")
	## Rust Mule carries extra pack room.
	GameState.mechs_built = {"mech_hound": true, "drone_bat": true, "rust_mule": true}
	GameState.selected_pet_id = "noel"
	GameState.reset_loadout_to_defaults()
	var cap0 := GameState.pack_capacity()
	GameState.selected_pet_id = "rust_mule"
	GameState.reset_loadout_to_defaults()
	_check(GameState.pack_capacity() == cap0 + 2, "e6 mule pack room")
	## In match: each trick.
	for mid in ["mech_hound", "drone_bat", "rust_mule"]:
		GameState.selected_pet_id = mid
		var m: Node = await _depth_match("smog", "ash_rook", {"generator": 0})
		var player: Node2D = m.get_node("World/Player")
		player.set("max_hp", 99999.0)
		player.set("hp", 99999.0)
		var pet: Node2D = get_tree().get_first_node_in_group("pets")
		_check(pet != null and str(pet.call("get_pet_name")) == str(PetDefs.get_pet(mid)["name"]), "e6 %s deployed" % mid)
		if pet == null:
			await _end_depth_match(m)
			continue
		var mobs: Array = []
		for i in range(3):
			var e := _mob(m, "scrap_hound", pet.global_position + Vector2(90 + i * 40, 10 * i))
			e.set("max_hp", 5000.0)
			e.set("hp", 5000.0)
			mobs.append(e)
		await get_tree().physics_frame
		match mid:
			"mech_hound":
				_check(int(pet.call("_shock_chain", mobs[0])) >= 2 and float(mobs[1].get("hp")) < 5000.0, "e6 hound shock chain")
			"drone_bat":
				_check(pet.collision_mask == 0, "e6 drone bat flies")
				_check(int(pet.call("_do_strafe")) >= 3 and float(mobs[0].get("hp")) < 5000.0, "e6 drone strafe")
			"rust_mule":
				var at: Vector2 = pet.call("_do_mortar")
				_check(at != Vector2.INF, "e6 mule fires")
				var t_end := Time.get_ticks_msec() + 1500
				var hit := false
				while Time.get_ticks_msec() < t_end and not hit:
					await get_tree().process_frame
					for e in mobs:
						if is_instance_valid(e) and float(e.get("hp")) < 5000.0:
							hit = true
				_check(hit, "e6 mule mortar lands")
		await _end_depth_match(m)
	## Hangar workshop builds from the kennel tab.
	GameState.mechs_built = {}
	GameState.ingredients["salvage_core"] = 20
	GameState.account_scrap = 5000
	var hg: Node = (load("res://scenes/ui/hangar.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(hg)
	await get_tree().process_frame
	hg.set("_tab", "kennel")
	hg.call("_rebuild")
	await get_tree().process_frame
	_check(bool(hg.call("build_mech", "drone_bat")) and GameState.pet_available("drone_bat"), "e6 hangar workshop build")
	hg.queue_free()
	GameState.selected_pet_id = "noel"
	GameState.reset_loadout_to_defaults()
	await get_tree().process_frame
	print("DEPTH_E6_OK")


## Depth E7: zones + twists for tiers 3-10, exclusive loot, trophies, pacts, plane.
func _test_depth_e7() -> void:
	_check(ZoneDefs.ZONES.size() == 10 and ZoneDefs.zone(1)["twists"].is_empty(), "e7 ten zones")
	for t in range(3, 11):
		var z := ZoneDefs.zone(t)
		_check(not (z["twists"] as Array).is_empty(), "e7 tier %d has a twist" % t)
		_check(ResourceLoader.exists("res://assets/sprites/tiles/zones/ground_earth_%s.png" % z["grade"]), "e7 tier %d ground" % t)
		for pr in z["props"]:
			_check(ResourceLoader.exists(ZoneDefs.PROP_DIR % pr) and ZoneDefs.PROP_INFO.has(pr), "e7 prop %s" % pr)
		_check(not ZoneDefs.exclusive(t).is_empty() and not ZoneDefs.plane_part(t).is_empty(), "e7 tier %d loot + plane part" % t)
	for zk in ["key", "flare", "filter", "power_cell"]:
		_check(ResourceLoader.exists("res://assets/sprites/depth/icons/zone_%s.png" % zk), "e7 icon %s" % zk)
	for i in range(1, 9):
		_check(ResourceLoader.exists(ZoneDefs.PLANE_LAYER % i), "e7 plane layer %d" % i)
	for tw in ["smog", "night", "shroud", "toxic_air", "power_cells", "revive"]:
		_check(ZoneDefs.has_twist(10, tw), "e7 dustfall has %s" % tw)
	## Exclusive loot.
	var ex := GameState.make_exclusive(7)
	_check(str(ex["exclusive"]) == "chem_filter_vial" and str(ex["rarity"]) == "legendary" and not ex.has("needs_heart") and float(ex["stats"].get("regen", 0.0)) >= 1.0, "e7 exclusive item")
	_check(GameState.make_exclusive(2).is_empty(), "e7 no exclusive below smog")
	## Trophies + plane parts.
	GameState.tier_clears = {}
	GameState.plane_parts = {}
	GameState.selected_character_id = "pebble"
	GameState._record_tier_clear(2)
	_check(GameState.tier_clears.is_empty(), "e7 no trophy below smog")
	GameState._record_tier_clear(5)
	_check(GameState.has_tier_clear("pebble", 5) and GameState.has_plane_part("tail") and not GameState.has_tier_clear("ash_rook", 5), "e7 trophy + plane part")
	for t in range(3, 11):
		GameState._record_tier_clear(t)
	_check(not GameState.plane_complete() and GameState.plane_part_count() == 8, "e7 all tier parts, battery still missing")
	GameState.add_plane_part("battery")
	_check(GameState.plane_complete() and GameState.plane_part_count() == GameState.plane_part_total(), "e7 plane complete")
	## Pacts.
	GameState.pacts = []
	GameState.best_tier_extracted = 2
	_check(not GameState.toggle_pact("thick_dust"), "e7 pacts locked before smog")
	GameState.best_tier_extracted = 3
	_check(GameState.toggle_pact("thick_dust") and GameState.toggle_pact("hungry_dark") and is_equal_approx(GameState.pact_fx("enemy_hp"), 1.25), "e7 pacts stack")
	_check(is_equal_approx(GameState.pact_loot_bonus(), 0.3), "e7 pact loot bonus")
	GameState.toggle_pact("hungry_dark")
	_check(GameState.pacts == ["thick_dust"], "e7 pact toggles off")
	## Save sanitize.
	GameState._load_depth({"tier_clears": {"pebble": {"5": true, "1": true, "x": true}, "nobody": {"5": true}}, "plane_parts": {"4": true, "2": true}, "pacts": ["thick_dust", "bogus", "thick_dust"]})
	_check(GameState.tier_clears.size() == 1 and (GameState.tier_clears["pebble"] as Dictionary).size() == 1, "e7 save tier clears sanitized")
	_check(GameState.plane_parts.keys() == ["wings"] and GameState.pacts == ["thick_dust"], "e7 save plane / pacts sanitized")
	GameState._load_depth({})
	_check(GameState.tier_clears.is_empty() and GameState.plane_parts.is_empty() and GameState.pacts.is_empty(), "e7 old saves")
	## Pact in a match: enemies tougher, narrower windows.
	GameState.pacts = ["thick_dust", "narrow_windows"]
	var m: Node = await _depth_match("smog", "pebble")
	var md: Dictionary = m.get("_mode")
	_check(float(md["enemy_hp"]) > float(ModeDefs.get_mode("smog")["enemy_hp"]) and float(md["window_open"]) < float(ModeDefs.get_mode("smog")["window_open"]), "e7 pacts reach the match")
	GameState.pacts = []
	## Smog: patches, bunkers, keys.
	var tw: Node = m.get_node("ZoneTwists")
	var player: Node2D = m.get_node("World/Player")
	player.set("max_hp", 99999.0)
	player.set("hp", 99999.0)
	_check((tw.get("smog") as Array).size() == int(ZoneDefs.SMOG["patches"]) and get_tree().get_nodes_in_group("bunkers").size() == 2, "e7 smog + bunkers")
	var pk: Node = tw.call("spawn_pickup", "key", player.global_position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(GameState.run_keys == 1, "e7 key picked up")
	var bk: Node = get_tree().get_nodes_in_group("bunkers")[0]
	_check(bool(bk.call("open_bunker")) and GameState.run_keys == 0 and bool(bk.get("opened")), "e7 bunker opens with a key")
	var sm: Node2D = (tw.get("smog") as Array)[0]["node"]
	var hid := _mob(m, "rad_gator", sm.global_position)
	hid.set("_spawn_in", 9.0)
	player.global_position = sm.global_position + Vector2(900, 0)
	for k in range(3):
		await get_tree().process_frame
	_check(bool(hid.get_meta("smog_hidden", false)), "e7 smog hides enemies")
	await _end_depth_match(m)
	## Pall: night + flares + wraith phasing.
	m = await _depth_match("pall", "pebble")
	tw = m.get_node("ZoneTwists")
	player = m.get_node("World/Player")
	var r0 := float(tw.call("light_radius"))
	tw.call("on_pickup", "flare", Vector2.ZERO)
	_check(tw.get("_night") != null and float(tw.call("light_radius")) > r0, "e7 night + flare")
	var wr := _mob(m, "ash_wraiths", player.global_position + Vector2(300, 0))
	wr.set("_spawn_in", 9.0)
	tw.set("_phase_t", float(ZoneDefs.WRAITH_PHASE["every"]) - float(ZoneDefs.WRAITH_PHASE["on"]) * 0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	var whp := float(wr.get("hp"))
	wr.call("take_damage", 50.0, Vector2.ZERO)
	_check(bool(wr.get("phased")) and is_equal_approx(float(wr.get("hp")), whp), "e7 wraith phases")
	await _end_depth_match(m)
	## Shroud: unseen until close; marked = seen; the rival crew hunts.
	m = await _depth_match("shroud", "pebble")
	tw = m.get_node("ZoneTwists")
	player = m.get_node("World/Player")
	player.set("max_hp", 99999.0)
	player.set("hp", 99999.0)
	var far := _mob(m, "rad_gator", player.global_position + Vector2(600, 0))
	far.set("_spawn_in", 9.0)
	var t_sh := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < t_sh:
		await get_tree().process_frame
	_check(far.modulate.a < 0.05, "e7 shroud hides far enemies")
	far.call("apply_status", "mark", 3.0, 1.1)
	await get_tree().process_frame
	_check(far.modulate.a > 0.9, "e7 marked enemies show")
	tw.set("_t", 999.0)
	await get_tree().process_frame
	var crews := get_tree().get_nodes_in_group("raider_crews")
	_check(crews.size() >= 1 and bool(crews[0].get("hunting")), "e7 raider crew hunts")
	await _end_depth_match(m)
	## Choke: the air filter drains, empty hurts, filters refill.
	m = await _depth_match("choke", "pebble")
	tw = m.get_node("ZoneTwists")
	player = m.get_node("World/Player")
	GameState.run_filter = 0.0
	var hp0 := float(player.get("hp"))
	for k in range(10):
		await get_tree().process_frame
	_check(float(player.get("hp")) < hp0, "e7 no air hurts")
	tw.call("on_pickup", "filter", Vector2.ZERO)
	_check(GameState.run_filter >= float(ZoneDefs.TOXIC_AIR["refill"]) - 1.0, "e7 filter refills")
	await _end_depth_match(m)
	## Blackout: dead pads + power cell; enraged machines.
	m = await _depth_match("blackout", "pebble")
	tw = m.get_node("ZoneTwists")
	player = m.get_node("World/Player")
	var hound := _mob(m, "scrap_hound", player.global_position + Vector2(400, 0))
	_check(float(hound.get("damage")) > float(EnemyDefs.get_kind("scrap_hound")["damage"]) * 1.1, "e7 machines enraged")
	var pad: Area2D = (load("res://scenes/entities/extract_pad.tscn") as PackedScene).instantiate()
	m.add_child(pad)
	pad.call("set_open", true)
	tw.call("on_window_open", 1, [pad])
	_check(not bool(pad.get("powered")) and get_tree().get_nodes_in_group("zone_pickups").size() >= 1, "e7 pads dead + cell spawned")
	pad.set("player_inside", true)
	await get_tree().process_frame
	_check(not bool(pad.get("powered")) and float(pad.call("get_channel_ratio")) == 0.0, "e7 dead pad won't channel")
	tw.call("on_pickup", "power_cell", Vector2.ZERO)
	await get_tree().process_frame
	_check(bool(pad.get("powered")) and not GameState.run_has_cell, "e7 cell powers the pad")
	pad.queue_free()
	await _end_depth_match(m)
	## Deadfall: one pad, sinkholes, rubble, serpent, revive.
	m = await _depth_match("deadfall", "pebble")
	tw = m.get_node("ZoneTwists")
	player = m.get_node("World/Player")
	player.set("max_hp", 99999.0)
	player.set("hp", 99999.0)
	m.call("_place_window_pads", 1)
	_check((m.get("_pads") as Array).size() == 1, "e7 one pad on deadfall")
	_check((tw.get("sinkholes") as Array).size() == int(ZoneDefs.SINKHOLES["count"]), "e7 sinkholes")
	var sh: Dictionary = (tw.get("sinkholes") as Array)[0]
	var hpb := float(player.get("hp"))
	player.global_position = sh["pos"]
	player.set("_iframes", 0.0)
	tw.set("_sink_cd", 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(float(player.get("hp")) < hpb and player.global_position.distance_to(sh["pos"]) > float(sh["r"]) * 0.8, "e7 sinkhole hurts + flings")
	var sp: Node = tw.call("serpent_ambush")
	_check(sp != null and str(sp.get("kind")) == "dune_serpent", "e7 serpent ambush")
	var zomb := _mob(m, "rad_gator", player.global_position + Vector2(500, 0))
	zomb.set("_spawn_in", 9.0)
	await get_tree().process_frame
	var downs := 0
	for k in range(12):
		var z2 := _mob(m, "rad_gator", player.global_position + Vector2(500, 60 + k * 10))
		z2.set("_spawn_in", 9.0)
		await get_tree().physics_frame
		z2.call("take_damage", 99999.0, Vector2.ZERO)
		if bool(z2.call("is_downed")):
			downs += 1
			z2.call("take_damage", 1.0, Vector2.ZERO)
			_check(bool(z2.get("_dead")), "e7 downed mob finished by a hit")
	_check(downs >= 2, "e7 some mobs go down instead of dying (%d/12)" % downs)
	await _end_depth_match(m)
	## Dustfall: the storm wall closes; outside hurts; bosses in pairs.
	m = await _depth_match("dustfall", "pebble")
	tw = m.get_node("ZoneTwists")
	player = m.get_node("World/Player")
	var r_start := float(tw.get("storm_radius"))
	m.set("_elapsed_in_phases", float(tw.get("_storm_total")) * 0.9)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(float(tw.get("storm_radius")) < r_start * 0.5, "e7 storm closes in")
	var hpd := float(player.get("hp"))
	player.global_position = Vector2(float(tw.get("storm_radius")) + 400.0, 0) + tw.get("_origin")
	for k in range(6):
		await get_tree().process_frame
	_check(float(player.get("hp")) < hpd, "e7 storm hurts outside")
	player.global_position = tw.get("_origin") + Vector2(float(tw.get("storm_radius")) * 3.0, 0)
	m.call("_place_window_pads", 1)
	var inside := true
	for pd in m.get("_pads"):
		if (pd as Node2D).global_position.distance_to(tw.get("_origin")) > float(tw.get("storm_radius")):
			inside = false
	_check(inside, "e7 pads stay inside the storm")
	var b0 := get_tree().get_nodes_in_group("bosses").size()
	m.set("_next_boss_at", 0.0)
	m.call("_tick_specials")
	_check(get_tree().get_nodes_in_group("bosses").size() - b0 == 2, "e7 double boss")
	await _end_depth_match(m)
	GameState.selected_mode_id = "drift"
	print("DEPTH_E7_OK")


func _depth_match(mode: String, hero: String, camp_set: Dictionary = {}) -> Node:
	GameState.camp.clear()
	GameState.selected_mode_id = mode
	GameState.selected_character_id = hero
	if not camp_set.is_empty():
		for k in camp_set.keys():
			GameState.camp[k] = camp_set[k]
		GameState.reset_loadout_to_defaults()
	GameState.fast_timers = true
	GameState.tutorial_done = true
	GameState.tonic_loadout = []
	GameState.begin_run()
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	for k in range(4):
		await get_tree().physics_frame
	## Clear the field so tests control who is around.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await get_tree().physics_frame
	return m


## Audit quick wins: cold open, opening waves, reload tuning, damage-number
## aggregation, boss bar, pet scale, HUD text purge.
func _test_quickwins() -> void:
	var keep_tut := GameState.tutorial_done
	## Cold open: first run is quiet (no mobs, frozen clock) until released.
	GameState.selected_mode_id = "haze"
	GameState.selected_character_id = "ash_rook"
	GameState.fast_timers = false
	GameState.tutorial_done = false
	GameState.begin_run()
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	for k in range(30):
		await get_tree().physics_frame
	_check(bool(m.get("quiet")) and get_tree().get_nodes_in_group("enemies").is_empty(), "qw cold open is quiet")
	_check(float(m.get("_match_time")) == 0.0, "qw cold open clock frozen")
	m.call("release_cold_open")
	await get_tree().physics_frame
	_check(not bool(m.get("quiet")) and get_tree().get_nodes_in_group("enemies").size() == int(m.get_script().get_script_constant_map()["COLD_OPEN_MOBS"]), "qw cold open mobs walk in")
	m.queue_free()
	GameState.tutorial_done = true
	for k in range(3):
		await get_tree().process_frame
	## Opening wave lands at its time on a normal run.
	GameState.begin_run()
	m = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	await get_tree().physics_frame
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await get_tree().physics_frame
	var waves: Array = m.get_script().get_script_constant_map()["OPENING_WAVES"]
	m.set("_match_time", float(waves[0][0]) + 0.01)
	m.call("_tick_opening_waves")
	await get_tree().physics_frame
	_check(get_tree().get_nodes_in_group("enemies").size() >= int(waves[0][1]), "qw opening wave spawns")
	## Reload is shorter than the weapon's listed time.
	var player: Node2D = m.get_node("World/Player")
	player.set("_ammo", 0)
	player.call("_start_reload")
	_check(float(player.get("_reload_left")) < float((player.get("_weapon") as Dictionary).get("reload_time", 1.4)) * 0.7, "qw reload tuned")
	## Damage numbers: rapid hits on one target merge into one number.
	var foe := _mob(m, "rad_gator", player.global_position + Vector2(900, 0))
	foe.set("speed", 0.0)
	foe.set("max_hp", 9999.0)
	foe.set("hp", 9999.0)
	var live0: int = (Juice.get("_dn_live") as Array).size()
	for i in range(4):
		foe.call("take_damage", 15.0)
	var live: Array = Juice.get("_dn_live")
	_check(live.size() == live0 + 1 and int(round(float(live[live.size() - 1]["total"]))) == 60, "qw damage numbers aggregate")
	## Mob HP bars: hidden on normal mobs once the hit is old.
	for k in range(140):
		await get_tree().physics_frame
	_check(not (foe.get("hp_bar") as Control).visible, "qw mob bar hides after a while")
	## Boss bar appears for a boss.
	var boss: Node = m.call("spawn_special", "boss")
	for k in range(30):
		await get_tree().process_frame
	var bb: Control = m.get_node("HUD").get("_boss_bar")
	_check(bb != null and bb.visible and is_instance_valid(boss), "qw boss bar shows")
	## Pets are drawn smaller than the hero.
	var pet := get_tree().get_first_node_in_group("pets")
	if pet:
		## Cleanup P2: pets y-sort with the hero, mobs and standing props (a pet
		## in front of a wreck must not vanish behind it), never above units.
		_check(int((pet as Node2D).z_index) <= 0, "qw pet sorted behind hero")
	m.queue_free()
	GameState.tutorial_done = keep_tut
	for k in range(3):
		await get_tree().process_frame
	print("QUICKWINS_OK")


func _end_depth_match(m: Node) -> void:
	if is_instance_valid(m):
		m.queue_free()
	GameState.fast_timers = false
	get_tree().paused = false
	for k in range(3):
		await get_tree().process_frame


func _mob(m: Node, kind: String, at: Vector2) -> Node2D:
	var e: CharacterBody2D = (load("res://scenes/entities/enemy.tscn") as PackedScene).instantiate()
	e.setup(at, 1.0, 1.0, 1.0, kind)
	m.get_node("World").add_child(e)
	e.set("_spawn_in", 0.0)
	return e


## Depth E2: weaknesses, elite traits, infighting, raider crews.
func _test_depth_e2() -> void:
	_check(is_equal_approx(FactionDefs.weakness("plague", "fire"), 1.35) and FactionDefs.weakness("plague", "shock") == 1.0, "e2 weakness table")
	_check(EnemyDefs.faction("scrap_hound") == "machine" and EnemyDefs.faction("rad_gator") == "plague" and EnemyDefs.faction("raider_grunt") == "raider", "e2 factions")
	_check(FactionDefs.roll_traits("plague", 2).is_empty() and FactionDefs.roll_traits("plague", 4).size() == 1 and FactionDefs.roll_traits("machine", 8).size() == 2, "e2 trait counts")
	_check(not ("raider_grunt" in EnemyDefs.ids_for_tier(2)), "e2 raiders crew-only")
	var m: Node = await _depth_match("smog", "ash_rook")
	var player: Node2D = m.get_node("World/Player")
	var fac := {}
	for i in range(2):
		var el: Node = m.call("spawn_special", "elite")
		fac[str(el.get("faction"))] = true
		_check((el.get("traits") as Array).size() == 1, "e2 elite one trait")
	_check(fac.has("plague") and fac.has("machine"), "e2 elites alternate sides")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await get_tree().physics_frame
	## Weakness through the hit pipeline (incendiary vs plague).
	player.call("apply_powerup", RunFx.ammo_def("incendiary"))
	_check(str(player.call("hit_element", "main")) == "fire", "e2 incendiary is fire")
	var far := player.global_position + Vector2(300, 0)
	var pm := _mob(m, "rad_gator", far)
	var mm := _mob(m, "scrap_hound", far + Vector2(0, 200))
	pm.set("max_hp", 1000.0); pm.set("hp", 1000.0)
	mm.set("max_hp", 1000.0); mm.set("hp", 1000.0)
	await get_tree().physics_frame
	player.call("hit_enemy", pm, 100.0, Vector2.RIGHT, 0.0, false, "blast")
	player.call("hit_enemy", mm, 100.0, Vector2.RIGHT, 0.0, false, "blast")
	var lost_p := 1000.0 - float(pm.get("hp"))
	var lost_m := 1000.0 - float(mm.get("hp"))
	_check(lost_p > lost_m * 1.2, "e2 plague burns harder %.0f vs %.0f" % [lost_p, lost_m])
	pm.queue_free()
	mm.queue_free()
	## Shielded: front hits blocked, back hits land.
	var sh := _mob(m, "cyber_juggernaut", player.global_position + Vector2(500, 0))
	sh.call("set_traits", ["shielded"])
	sh.set("_facing_left", false)
	sh.set("max_hp", 1000.0); sh.set("hp", 1000.0)
	sh.call("take_damage", 100.0, Vector2.LEFT, 0.0)
	var front := 1000.0 - float(sh.get("hp"))
	sh.call("take_damage", 100.0, Vector2.RIGHT, 0.0)
	var back := 1000.0 - float(sh.get("hp")) - front
	_check(front < 40.0 and back > 90.0, "e2 shield front %.0f back %.0f" % [front, back])
	## Overclocked: overheats and takes more.
	sh.call("set_traits", ["overclocked"])
	sh.set("_overheat_t", 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(float(sh.get("_overheat_left")) > 0.0, "e2 overheat")
	var h0 := float(sh.get("hp"))
	sh.call("take_damage", 100.0, Vector2.ZERO, 0.0)
	_check(h0 - float(sh.get("hp")) > 140.0, "e2 overheat takes more")
	sh.queue_free()
	## Self-repair heals when hurt; regrowing regenerates unless burning.
	var sr := _mob(m, "fusion_golem", player.global_position + Vector2(-500, 0))
	sr.call("set_traits", ["self_repair"])
	sr.set("hp", float(sr.get("max_hp")) * 0.3)
	for k in range(40):
		await get_tree().physics_frame
	_check(float(sr.get("hp")) > float(sr.get("max_hp")) * 0.35, "e2 self repair")
	sr.queue_free()
	var rg := _mob(m, "scav_bear", player.global_position + Vector2(0, 500))
	rg.call("set_traits", ["regrowing"])
	rg.set("hp", float(rg.get("max_hp")) * 0.5)
	for k in range(30):
		await get_tree().physics_frame
	_check(float(rg.get("hp")) > float(rg.get("max_hp")) * 0.51, "e2 regrowing")
	rg.call("apply_status", "burn", 5.0, 0.01)
	var hb := float(rg.get("hp"))
	for k in range(20):
		await get_tree().physics_frame
	_check(float(rg.get("hp")) <= hb, "e2 burning stops regrowth")
	rg.queue_free()
	## Bloated burst hurts the hero.
	var bl := _mob(m, "toxic_scorp", player.global_position + Vector2(40, 0))
	bl.call("set_traits", ["bloated"])
	await get_tree().physics_frame
	player.set("_iframes", 0.0)
	var php := float(player.get("hp"))
	bl.call("take_damage", 9999.0, Vector2.ZERO, 0.0)
	_check(float(player.get("hp")) < php, "e2 bloated burst")
	for k in range(5):
		await get_tree().physics_frame
	## Infighting: plague vs machine brawl when the hero is far away.
	var a := _mob(m, "rad_gator", player.global_position + Vector2(700, 300))
	var b := _mob(m, "scrap_hound", player.global_position + Vector2(760, 300))
	for e in [a, b]:
		e.set("max_hp", 500.0)
		e.set("hp", 500.0)
	for k in range(150):
		player.set("hp", player.get("max_hp"))
		await get_tree().physics_frame
	_check((is_instance_valid(a) and float(a.get("hp")) < 500.0) or (is_instance_valid(b) and float(b.get("hp")) < 500.0), "e2 infighting")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _end_depth_match(m)
	## Raider crew: loots a crate, hunts, drops its bag.
	m = await _depth_match("blight", "pebble")
	player = m.get_node("World/Player")
	for c in get_tree().get_nodes_in_group("medicine_crates"):
		c.queue_free()
	await get_tree().physics_frame
	var at := player.global_position + Vector2(900, 0)
	var crew: Node = m.call("spawn_crew", at)
	await get_tree().physics_frame
	var members: Array = crew.get("members")
	_check(members.size() == 1 + FactionDefs.crew_brutes(5) + FactionDefs.crew_grunts(5), "e2 crew size %d" % members.size())
	_check(str(crew.get("carrier").get("kind")) == "raider_captain" and str(crew.get("carrier").get("role")) == "boss", "e2 captain carries")
	var crate := HaulPickup.spawn(m.get_node("World"), at + Vector2(60, 0), "medicine", 1, false)
	for k in range(240):
		player.set("hp", player.get("max_hp"))
		if int(crew.get("bag_medicine")) > 0:
			break
		await get_tree().physics_frame
	_check(int(crew.get("bag_medicine")) == 1 and not is_instance_valid(crate), "e2 crew loots medicine")
	_check(not bool(crew.call("is_hunting")), "e2 crew not hunting yet")
	var cap: Node2D = crew.get("carrier")
	cap.call("take_damage", 1.0, Vector2.ZERO, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(bool(crew.call("is_hunting")), "e2 crew hunts when hurt")
	var cap_pos := cap.global_position
	cap.call("take_damage", 999999.0, Vector2.ZERO, 0.0)
	for k in range(4):
		await get_tree().physics_frame
	var bag_found := false
	for h in get_tree().get_nodes_in_group("medicine_crates"):
		if (h as Node2D).global_position.distance_to(cap_pos) < 80.0:
			bag_found = true
	_check(bag_found, "e2 bag drops with the medicine")
	_check(crew.get("carrier") != null and crew.get("carrier") != cap, "e2 new carrier")
	await _end_depth_match(m)
	print("DEPTH_E2_OK")


func _grant(id: String, n: int = 99) -> void:
	var u := UpgradeDefs.get_def(id)
	for i in range(n):
		if GameState.run_rank(id) >= int(u.get("max_rank", 1)):
			break
		GameState.apply_run_upgrade(u)


## Depth E3: recipes / evolutions, Field Notes bestiary, lore pages.
func _test_depth_e3() -> void:
	## Every shared upgrade is in a recipe; every survivor has a class recipe.
	var in_recipe := {}
	for c in RecipeDefs.all():
		for nd in c["needs"]:
			in_recipe[str(nd)] = true
	for u in UpgradeDefs.all():
		if not u.has("hero"):
			_check(in_recipe.has(str(u["id"])), "e3 recipe covers %s" % u["id"])
	for h in CharacterDefs.PLAYABLE_IDS:
		var n := 0
		for c in RecipeDefs.all():
			if str(c.get("hero", "")) == h:
				n += 1
		_check(n == 1, "e3 class recipe %s" % h)
	## Readiness + guaranteed offer.
	GameState.camp.clear()
	GameState.loadouts.clear()
	GameState.selected_character_id = "vesper_thorn"
	GameState.selected_mode_id = "drift"
	GameState.begin_run()
	_grant("dust_rounds", 2)
	_grant("spore_mines", 1)
	_check(not Progression.recipe_ready(RecipeDefs.get_recipe("plague_bloom")), "e3 not ready below max")
	_grant("dust_rounds")
	_check(Progression.recipe_ready(RecipeDefs.get_recipe("plague_bloom")), "e3 ready at max + partner")
	var ch := Progression.roll_run_choices()
	var offered := false
	for c in ch:
		offered = offered or str(c["id"]) == "plague_bloom"
	_check(offered and ch.size() == 3, "e3 evolution offered")
	GameState.apply_run_upgrade(RecipeDefs.get_recipe("plague_bloom"))
	_check(GameState.has_evo("plague_bloom") and not Progression.recipe_ready(RecipeDefs.get_recipe("plague_bloom")), "e3 evolution owned once")
	_grant("ricochet")
	_check(not Progression.recipe_ready(RecipeDefs.get_recipe("arc_storm")), "e3 arc storm needs shock")
	GameState.run_ammo_seen["shock"] = true
	_check(Progression.recipe_ready(RecipeDefs.get_recipe("arc_storm")), "e3 arc storm with shock")
	_check(not Progression.recipe_ready(RecipeDefs.get_recipe("earthquake")), "e3 class recipe other hero")
	var pk := CanvasLayer.new()
	pk.set_script(load("res://scripts/ui/run_upgrade_picker.gd"))
	add_child(pk)
	_check(str(pk.call("_recipe_hint", "spore_mines", "vesper_thorn")).contains("Plague Bloom"), "e3 card shows recipe")
	pk.queue_free()
	## Deadeye / Fortune numbers.
	var c0 := GameState.crit_chance()
	GameState.run_ranks["deadeye"] = 1
	GameState.run_ranks["fortune"] = 1
	_check(is_equal_approx(GameState.crit_chance(), c0 + 0.2) and GameState.run_scrap_mult() >= 1.5, "e3 deadeye/fortune")
	## In a match: Plague Bloom cloud, Death Knell blast, Blade Storm shards, Lead Rain fan.
	var m: Node = await _depth_match("drift", "vesper_thorn")
	var player: Node2D = m.get_node("World/Player")
	GameState.run_ranks["plague_bloom"] = 1
	GameState.run_ranks["death_knell"] = 1
	var a := _mob(m, "rad_gator", player.global_position + Vector2(400, 0))
	var b := _mob(m, "rad_gator", player.global_position + Vector2(440, 0))
	await get_tree().physics_frame
	var g0 := get_tree().get_nodes_in_group("ground_fx").size()
	a.call("apply_status", "poison", 3.0, 1.0)
	a.call("apply_status", "mark", 3.0, 1.0)
	b.set("max_hp", 500.0)
	b.set("hp", 500.0)
	a.call("take_damage", 9999.0, Vector2.ZERO, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(get_tree().get_nodes_in_group("ground_fx").size() > g0, "e3 plague bloom cloud")
	_check(float(b.get("hp")) < 500.0, "e3 death knell blast")
	b.queue_free()
	GameState.run_ranks["orbit_blades"] = 1
	GameState.run_ranks["blade_storm"] = 1
	## Count the NEW bullets (not the scene's child count: other nodes — the
	## dying gator, freed mobs — leave in the same frames, which made this flaky).
	var seen := {}
	for c in m.get_children():
		seen[c.get_instance_id()] = true
	var bullet_script: Script = load("res://scripts/entities/bullet.gd")
	var shards := 0
	player.set("_shard_t", 0.0)
	for f in range(2):
		await get_tree().physics_frame
		for c in m.get_children():
			if not seen.has(c.get_instance_id()) and c.get_script() == bullet_script:
				seen[c.get_instance_id()] = true
				shards += 1
	_check(shards >= 8, "e3 blade storm shards %d" % shards)
	GameState.run_ranks.erase("blade_storm")
	GameState.run_ranks["lead_rain"] = 1
	await get_tree().physics_frame
	var b2 := m.get_child_count()
	player.call("_fire_one_shot")
	await get_tree().process_frame
	_check(m.get_child_count() >= b2 + 3, "e3 lead rain fan")
	await _end_depth_match(m)
	## Field Notes: kills fill entries (kept), weak spot bonus, save round trip, logbook tab.
	GameState.bestiary = {}
	GameState.lore_pages = {}
	for i in range(BestiaryDefs.THRESHOLDS[1]):
		GameState.note_kill("scrap_hound")
	_check(BestiaryDefs.stage_for(GameState.bestiary_kills("scrap_hound")) == 2 and is_equal_approx(GameState.bestiary_bonus("scrap_hound"), 0.1), "e3 weak spot")
	_check(GameState.find_page("p_war") and not GameState.find_page("p_war") and not GameState.find_page("nope"), "e3 lore page once")
	GameState.save_profile()
	GameState.apply_save(JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH)))
	_check(GameState.bestiary_kills("scrap_hound") == 40 and GameState.lore_pages.has("p_war"), "e3 notes saved")
	GameState.apply_save({"version": 4, "migrated_hangar_v4": true, "bestiary": {"rad_gator": "x", "toxic_scorp": 5}, "lore_pages": {"bogus": true}})
	_check(GameState.bestiary == {"toxic_scorp": 5} and GameState.lore_pages.is_empty(), "e3 notes sanitised")
	var lb: Node = (load("res://scenes/ui/logbook.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(lb)
	await get_tree().process_frame
	lb.call("show_tab", "notes")
	await get_tree().process_frame
	_check(int(lb.call("beast_count")) >= 30, "e3 notes tab")
	lb.queue_free()
	## A page in a run gets picked up.
	m = await _depth_match("drift", "pebble")
	player = m.get_node("World/Player")
	m.get_node("PlagueSystem").call("spawn_page", "p_dust", player.global_position + Vector2(10, 0))
	for k in range(6):
		await get_tree().physics_frame
	_check(GameState.lore_pages.has("p_dust"), "e3 page picked up in a run")
	await _end_depth_match(m)
	print("DEPTH_E3_OK")


## Depth E4: radio contracts, camp cameos, black market, stakes, Dust Warden.
func _test_depth_e4() -> void:
	for h in CharacterDefs.PLAYABLE_IDS:
		for id in RadioDefs.jobs_for("contract", h) + RadioDefs.jobs_for("service", h):
			_check(str(RadioDefs.job(str(id))["giver"]) != h, "e4 no self-cameo %s" % h)
	var m: Node = await _depth_match("blight", "ash_rook")
	var player: Node2D = m.get_node("World/Player")
	var jobs: Node = m.get_node("RadioJobs")
	## Keep the hero up through the whole section (elites, bursts, waves).
	player.set("max_hp", 99999.0)
	player.set("hp", 99999.0)
	var q: Array = jobs.call("queued_ids")
	_check(q.size() >= 2 and not ("vault" in q), "e4 jobs scheduled %s" % str(q))
	_check(not ("elite_pair" in RadioDefs.stakes_for(2)) and "elite_pair" in RadioDefs.stakes_for(3), "e4 no elite stakes before tier 3")
	GameState.stories = {}
	var s0 := GameState.extract_bonus_scrap
	## Bounty: kill the marked elite.
	var st: Dictionary = jobs.call("start", "bounty")
	var el: Node = st["node"]
	el.call("take_damage", 9e9, Vector2.ZERO, 0.0)
	await get_tree().process_frame
	_check(bool(jobs.call("is_done", "bounty")) and GameState.extract_bonus_scrap > s0, "e4 bounty")
	_check(int(GameState.story_state("quill_marrow")["have"]) > 0 or int(GameState.story_state("quill_marrow")["step"]) > 0, "e4 cameo moves quill's story")
	## Medicine cache: walk up to it.
	jobs.call("start", "medicine_cache", player.global_position + Vector2(30, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(bool(jobs.call("is_done", "medicine_cache")), "e4 cache")
	## Relay: hold near Juno.
	st = jobs.call("start", "defend_relay", player.global_position)
	st["hold"] = float(RadioDefs.job("defend_relay")["hold"]) - 0.05
	var t_end := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < t_end and not bool(jobs.call("is_done", "defend_relay")):
		player.global_position = st["pos"]
		await get_tree().process_frame
	_check(bool(jobs.call("is_done", "defend_relay")), "e4 relay")
	## Rescue: Pebble follows, delivered at extract.
	st = jobs.call("start", "rescue", player.global_position + Vector2(40, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(str(st["phase"]) == "escort", "e4 pebble follows")
	## Black box: hold still by the wreck (clear the field so nothing interrupts).
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	player.set("_iframes", 99.0)
	await get_tree().process_frame
	st = jobs.call("start", "black_box", player.global_position)
	var t_bb := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < t_bb and str(st["phase"]) != "carry":
		st["channel"] = maxf(float(st["channel"]), float(RadioDefs.job("black_box")["channel"]) - 0.05)
		player.global_position = st["pos"]
		await get_tree().process_frame
	_check(str(st["phase"]) == "carry", "e4 black box carried")
	jobs.call("on_extract")
	_check(bool(jobs.call("is_done", "rescue")) and bool(jobs.call("is_done", "black_box")), "e4 delivered at extract")
	## Field tent: heal + cleanse.
	player.set("hp", 10.0)
	GameState.exposure = 60.0
	jobs.call("start", "field_tent", player.global_position)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(float(player.get("hp")) > 50.0 and GameState.exposure < 1.0, "e4 field tent")
	player.set("hp", 99999.0)
	## Overwatch snipes; vault opens.
	var tgt := _mob(m, "scav_bear", player.global_position + Vector2(200, 0))
	tgt.set("max_hp", 5000.0)
	tgt.set("hp", 5000.0)
	st = jobs.call("start", "overwatch", player.global_position + Vector2(-120, 0))
	st["fire_t"] = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	_check(float(tgt.get("hp")) < 5000.0, "e4 overwatch snipe")
	tgt.queue_free()
	var g0 := get_tree().get_nodes_in_group("gear_drops").size()
	st = jobs.call("start", "vault", player.global_position)
	await get_tree().process_frame
	await get_tree().process_frame
	st["fuse"] = 0.01
	for k in range(4):
		await get_tree().process_frame
	_check(bool(jobs.call("is_done", "vault")) and get_tree().get_nodes_in_group("gear_drops").size() > g0, "e4 vault loot")
	## Black market: buy, Pack Lock keeps the pack on a death.
	GameState.scrap_found = 200
	var mk := CanvasLayer.new()
	mk.set_script(load("res://scripts/ui/black_market.gd"))
	add_child(mk)
	mk.call("open", jobs)
	_check(bool(mk.call("buy", "lock")) and GameState.run_pack_locked and GameState.scrap_found == 155, "e4 market buy")
	_check(not bool(mk.call("buy", "lock")), "e4 lock once")
	var rr := GameState.run_rerolls_left
	mk.call("buy", "reroll")
	_check(GameState.run_rerolls_left == rr + 1, "e4 market reroll")
	mk.call("close")
	await get_tree().process_frame
	## Stakes from window 2.
	_check(str(jobs.call("roll_stake", 1)) == "", "e4 no stake on window 1")
	var sk := str(jobs.call("roll_stake", 2))
	_check(RadioDefs.STAKES.has(sk), "e4 stake rolled")
	jobs.set("_stake", "elite_pair")
	var e0 := get_tree().get_nodes_in_group("elites").size()
	jobs.call("apply_stake")
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("elites").size() >= e0 + 2, "e4 elite pair stake")
	## Dust Warden: boss at tier 5+, pulses.
	var w: Node = jobs.call("spawn_warden", [])
	_check(w != null and str(w.get("kind")) == "dust_warden" and str(w.get("role")) == "boss", "e4 warden boss")
	w.global_position = player.global_position + Vector2(60, 0)
	w.set("_spawn_in", 0.0)
	w.set("_pulse_t", 0.0)
	player.set("_iframes", 0.0)
	var hp1 := 5000.0
	player.set("hp", hp1)
	var until := Time.get_ticks_msec() + int((RadioDefs.WARDEN_PULSE_WINDUP + 0.6) * 1000.0)
	while Time.get_ticks_msec() < until:
		player.set("_iframes", 0.0)
		await get_tree().process_frame
	_check(float(player.get("hp")) < hp1, "e4 warden pulse")
	## Contract rewards ride home on extract; Pack Lock on a wipe.
	GameState.add_to_pack("medicine")
	GameState.on_wipe()
	_check(GameState.ingredient_count("medicine") >= 1, "e4 pack lock on wipe")
	await _end_depth_match(m)
	GameState.begin_run()
	GameState.add_job_reward(50, {"herb": 2})
	var h0 := GameState.ingredient_count("herb")
	GameState.on_extract_success()
	_check(GameState.ingredient_count("herb") == h0 + 2, "e4 rewards banked on extract")
	## Tier 3: the Warden is an elite.
	m = await _depth_match("smog", "pebble")
	var w2: Node = m.get_node("RadioJobs").call("spawn_warden", [])
	_check(w2 != null and str(w2.get("role")) == "elite", "e4 warden elite below tier 5")
	await _end_depth_match(m)
	print("DEPTH_E4_OK")


## Ash Rook breaks crates: rockets (incl. point blank), the Rush ram and the slam.
func _ash_crate(m: Node, pos: Vector2) -> Node2D:
	var br: StaticBody2D = (load("res://scenes/entities/breakable.tscn") as PackedScene).instantiate()
	m.get_node("World").add_child(br)
	br.setup("herb_crate", null, 20.0)
	br.global_position = pos
	return br


func _test_ash_breaks() -> void:
	GameState.kit = {"ash_rook": {"style": "boom", "ability": "a", "quirk": ""}}
	var m: Node = await _depth_match("smog", "ash_rook", {})
	var player: Node2D = m.get_node("World/Player")
	player.set("max_hp", 99999.0)
	player.set("hp", 99999.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	for c in get_tree().get_nodes_in_group("breakables"):
		c.queue_free()
	await get_tree().physics_frame
	## Rocket at range: auto-targets the crate and breaks it.
	var far := _ash_crate(m, player.global_position + Vector2(160, 0))
	for i in range(120):
		await get_tree().physics_frame
		if not is_instance_valid(far):
			break
	_check(not is_instance_valid(far), "ash rocket breaks a crate")
	## Point blank: crate overlapping the muzzle.
	player.set("_reload_left", 0.0)
	player.set("_fire_cd", 0.0)
	var near := _ash_crate(m, player.global_position + Vector2(30, -6))
	for i in range(120):
		await get_tree().physics_frame
		if not is_instance_valid(near):
			break
	_check(not is_instance_valid(near), "ash point-blank rocket breaks a crate")
	## Rattle Rush ram smashes a crate he runs into.
	var ram := _ash_crate(m, player.global_position + Vector2(20, 0))
	player.call("_ability_cast", "rattle_rush")
	player.call("_update_rush_ram")
	await get_tree().physics_frame
	_check(not is_instance_valid(ram) or ram.is_queued_for_deletion(), "ash rush ram breaks a crate")
	player.set("_rush_active", false)
	## Short Charge slam / blasts break crates in the radius.
	var ab: Dictionary = player.get("_ability")
	ab["end_slam_radius"] = 120.0
	var slam := _ash_crate(m, player.global_position + Vector2(-80, 0))
	player.call("_on_rush_end")
	await get_tree().physics_frame
	_check(not is_instance_valid(slam) or slam.is_queued_for_deletion(), "ash slam breaks a crate")
	ab.erase("end_slam_radius")
	await _end_depth_match(m)


## Minimap upgrade: 30% bigger, pixel icons, capped mobs, rim markers, legend.
func _test_minimap() -> void:
	for id in range(MapIcons.COUNT):
		_check(MapIcons.tex(id) != null, "minimap glyph %d baked" % id)
	_check(MapIcons.rarity_color("legendary") != MapIcons.rarity_color("common") and MapIcons.rarity_color("uncommon").g > 0.8, "minimap rarity colours")
	var m := await _depth_match("drift", "ash_rook")
	var hud: Node = m.get_node("HUD")
	var mm: Control = hud.get("_minimap")
	var tp: Control = hud.get("_threat_panel")
	_check(mm != null and mm.size.x >= 134.0, "minimap 30%% bigger (%.0f)" % (mm.size.x if mm else 0.0))
	if mm == null:
		await _end_depth_match(m)
		return
	_check(not mm.get_global_rect().intersects(tp.get_global_rect()), "minimap clear of loot readout")
	var vp := mm.get_viewport_rect().size
	_check(mm.get_global_rect().end.x <= vp.x and mm.position.y >= 0.0, "minimap inside the screen")
	var player: Node2D = m.get_node("World/Player")
	var o := player.global_position
	for i in range(40):
		_mob(m, "scrap_hound", o + Vector2.from_angle(TAU * i / 40.0) * (150.0 + i * 8.0))
	var el := _mob(m, "scrap_hound", o + Vector2(200, 0))
	el.call("set_role", "elite")
	var boss: Node = m.call("spawn_special", "boss")
	(boss as Node2D).global_position = o + Vector2(-5000, 0)
	var it := {"rarity": "legendary"}
	GearPickup.spawn(m.get_node("World"), o + Vector2(0, 120), it)
	HaulPickup.spawn(m.get_node("World"), o + Vector2(0, -150), "medicine", 1, false)
	m.get_node("RunEvents").call("start_event", "scrap_spike")
	await get_tree().physics_frame
	await get_tree().physics_frame
	mm.call("_gather")
	var ids: Array = mm.call("icon_ids")
	_check(ids.count(MapIcons.SKULL) <= 24 and ids.count(MapIcons.SKULL) >= 20, "minimap caps mobs (%d)" % ids.count(MapIcons.SKULL))
	_check(ids.has(MapIcons.SKULL_BIG), "minimap shows the elite")
	_check(ids.has(MapIcons.GEM) and ids.has(MapIcons.CROSS), "minimap shows gear + medicine")
	_check(ids.has(MapIcons.BANG) or (mm.call("rim_ids") as Array).has(MapIcons.BANG), "minimap shows the event")
	_check((mm.call("rim_ids") as Array).has(MapIcons.SKULL_BIG), "far boss pinned to the rim")
	_check(int(mm.call("rim_count")) <= 7, "rim markers capped")
	var ev: Dictionary = m.get_node("RunEvents").call("map_target")
	_check(not ev.is_empty() and str(ev["id"]) == "scrap_spike", "event exposes its map target")
	m.get_node("RadioJobs").call("start", "field_tent", o + Vector2(300, 300))
	var jt: Array = m.get_node("RadioJobs").call("map_targets")
	_check(jt.size() >= 1 and str(jt[0]["id"]) == "field_tent", "radio jobs expose map targets")
	mm.call("toggle_legend")
	_check(bool(mm.call("legend_visible")) and not get_tree().paused, "legend toggles, nothing pauses")
	mm.call("toggle_legend")
	_check(not bool(mm.call("legend_visible")), "legend toggles off")
	for k in range(12):
		await get_tree().process_frame
	await _end_depth_match(m)
	print("MINIMAP_OK")


## =============================================================================
## CAMPAIGN (Act One): save migration + sanitising, flags (committed on a win,
## dropped on a loss), unlock order, and every level loads and runs to the end
## by debug-completing its objectives (god mode). Wander state is untouched.
func _test_campaign() -> void:
	var keep := [GameState.campaign.duplicate(true), GameState.selected_character_id, GameState.selected_pet_id,
		GameState.account_scrap, GameState.camp.duplicate(), GameState.stash.duplicate(true), GameState.selected_mode_id, GameState.plane_parts.duplicate()]
	## --- save: old saves (no key), junk, round trip
	GameState._load_campaign(null)
	_check(GameState.campaign_done_count() == 0 and (GameState.campaign["roster"] as Array).is_empty(), "campaign: missing key = fresh")
	GameState.plane_parts = {}
	GameState._load_campaign({"done": {"p0_mayday": {"best": 91.0, "runs": 2}, "bogus": {"best": 1}}, "flags": {"a": 1.0, "b": [1], "c": "x"},
		"roster": ["ash_rook", "nobody"], "pets": ["noel", "cat"], "parts": ["frame", "wing"], "last": "zzz", "picks": {"l07_mother_vane": "pebble", "l01_rubble_run": "ghost"}})
	_check(GameState.campaign_level_done("p0_mayday") and GameState.campaign_done_count() == 1, "campaign: known levels kept, junk dropped")
	_check(typeof(GameState.campaign["flags"]["a"]) == TYPE_INT and not (GameState.campaign["flags"] as Dictionary).has("b") and str(GameState.campaign["flags"]["c"]) == "x", "campaign: flags sanitised")
	_check(GameState.campaign["roster"] == ["ash_rook"] and GameState.campaign["pets"] == ["noel"] and GameState.plane_parts.keys() == ["fuselage"] and not GameState.campaign.has("parts"), "campaign: roster / pets / parts sanitised (parts merged into the one tracker)")
	_check(str(GameState.campaign["last"]) == "" and (GameState.campaign["picks"] as Dictionary).size() == 1, "campaign: last + picks sanitised")
	var snap: Dictionary = GameState.campaign.duplicate(true)
	GameState._load_campaign(JSON.parse_string(JSON.stringify(GameState.campaign)))
	_check(JSON.stringify(GameState.campaign) == JSON.stringify(snap), "campaign: JSON round trip")
	GameState.save_profile()
	var raw := FileAccess.get_file_as_string(GameState.SAVE_PATH)
	var old: Dictionary = JSON.parse_string(raw)
	old.erase("campaign")
	var scrap_before := GameState.account_scrap
	GameState.apply_save(old)
	_check(GameState.campaign_done_count() == 0 and GameState.account_scrap == scrap_before, "campaign: pre-campaign save loads, Wander untouched")
	GameState.apply_save(JSON.parse_string(raw))
	_check(GameState.campaign_level_done("p0_mayday"), "campaign: saved progress loads back")
	## --- unlocks + flags
	GameState.campaign = GameState._fresh_campaign()
	_check(GameState.campaign_level_unlocked("p0_mayday") and not GameState.campaign_level_unlocked("l01_rubble_run"), "campaign: prologue first, the rest locked")
	_check(GameState.prepare_campaign_level("p0_mayday"), "campaign: prologue prepares")
	_check(GameState.in_campaign_run() and GameState.selected_character_id == "helm_wisp" and not bool(GameState.pet.get("active", true)), "campaign: forced hero, no dog yet")
	_check(not GameState.twist_on("one_pad") and not GameState.exposure_active() and GameState.get_mode()["id"] == "campaign", "campaign: no twists / exposure, own mode")
	GameState.set_campaign_flag("test_flag", 2)
	_check(GameState.campaign_flag_is("test_flag", 2) and not GameState.campaign_flag_is("test_flag", 3), "campaign: run flag readable")
	GameState.fail_campaign_level("test")
	_check(GameState.campaign_flag("test_flag", null) == null and not GameState.campaign_level_done("p0_mayday"), "campaign: a loss forgets this attempt's choices")
	GameState.leave_campaign_run()
	_check(GameState.selected_character_id == str(keep[1]) and not GameState.in_campaign_run(), "campaign: leaving restores the Wander hero")
	GameState.prepare_campaign_level("p0_mayday")
	GameState.set_campaign_flag("test_flag", true)
	GameState.complete_campaign_level(100.0)
	_check(GameState.campaign_flag_is("test_flag") and GameState.campaign_level_done("p0_mayday"), "campaign: a win commits the choices")
	_check(GameState.campaign_has_survivor("ash_rook") and "noel" in GameState.campaign["pets"], "campaign: prologue rewards (Rook, Noel)")
	_check(GameState.campaign_level_unlocked("l01_rubble_run") == CampaignDefs.is_playable("l01_rubble_run"), "campaign: next level unlocks")
	GameState.leave_campaign_run()
	## --- every playable level runs to the end
	for id in CampaignDefs.ORDER:
		if CampaignDefs.is_playable(str(id)):
			await _campaign_run_level(str(id))
	GameState.campaign_autoplay = false
	GameState.leave_campaign_run()
	GameState.campaign = keep[0]
	GameState.selected_character_id = keep[1]
	GameState.selected_pet_id = keep[2]
	GameState.account_scrap = keep[3]
	GameState.camp = keep[4]
	GameState.stash = keep[5]
	GameState.selected_mode_id = keep[6]
	GameState.plane_parts = keep[7]
	GameState.reset_loadout_to_defaults()
	_check(_campaign_levels_run >= 1, "campaign: levels ran (%d)" % _campaign_levels_run)
	print("CAMPAIGN_OK")


func _campaign_run_level(id: String) -> void:
	GameState.campaign = GameState._fresh_campaign()
	GameState.campaign_debug_unlock_to(id)
	GameState.campaign_autoplay = true
	GameState.campaign_autoplay_exit = false
	_check(GameState.campaign_level_unlocked(id), "campaign %s unlocked after the ones before" % id)
	if id == "l12_dustfall":
		GameState.plane_parts.erase("heart")
	if not GameState.prepare_campaign_level(id):
		_check(false, "campaign %s prepares" % id)
		return
	var lv := GameState.campaign_level()
	await _campaign_play(id, lv)
	if id == "l12_dustfall":
		## The story bot picks the first option: Destroy the heart.
		_check(GameState.campaign_flag_is("ending", "destroy") and not GameState.has_plane_part("heart"), "campaign: destroying the heart gives no Dust Heart part")


## Plays a prepared level to the end (debug-complete), outro included.
func _campaign_play(id: String, lv: Dictionary) -> void:
	var m: Node = (load(CampaignDefs.MATCH_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	var runner: Node = m.get("runner")
	var objs := 0
	var last_idx := -1
	var frames := 0
	## Ends on the win itself (a replay is already "done" before it starts).
	while frames < 4000 and not (is_instance_valid(m) and bool(m.get("won"))):
		frames += 1
		await get_tree().physics_frame
		if not is_instance_valid(m) or bool(m.get("_ended")) and not bool(m.get("won")):
			break
		if int(runner.get("idx")) != last_idx:
			last_idx = int(runner.get("idx"))
			objs += 1
		## God mode without the Admin autoload (earlier sections free it).
		var pl := m.get_node_or_null("World/Player")
		if pl:
			pl.set("hp", float(pl.get("max_hp")))
			pl.set("_iframes", 0.5)
		if frames % 12 == 0 and bool(m.get("started")) and not bool(runner.get("busy")) and not get_tree().paused:
			runner.call("debug_complete")
	var ok := GameState.campaign_level_done(id) and is_instance_valid(m) and bool(m.get("won"))
	_campaign_levels_run += 1
	_check(ok, "campaign %s completes by debug-complete (frames %d, objectives %d)" % [id, frames, objs])
	var rw: Dictionary = lv.get("rewards", {})
	for h in rw.get("survivors", []):
		_check(GameState.campaign_has_survivor(str(h)) or GameState.campaign_fallen(str(h)), "campaign %s: %s joined" % [id, h])
	## Let the outro scene / card play out (errors surface in the log).
	for k in range(150):
		await get_tree().process_frame
	print("CAMPAIGN_LEVEL %s done=%s frames=%d objectives=%d time=%.1f" % [id, ok, frames, objs, float(m.get("level_time")) if is_instance_valid(m) else -1.0])
	get_tree().paused = false
	if is_instance_valid(m):
		m.queue_free()
	GameState.leave_campaign_run()
	for k in range(3):
		await get_tree().process_frame


## Story lines a scene would show with the current flags (mirrors
## story_panel._play_lines; a choice shows its locked / first option).
func _scene_text(lines: Array) -> String:
	var out := PackedStringArray()
	for ln in lines:
		if ln is Dictionary:
			var d: Dictionary = ln
			if d.has("choice"):
				var opts: Array = d["choice"]
				var pick: Dictionary = opts[0]
				for o in opts:
					var lk: Variant = GameState.campaign_locked_choice(str((o as Dictionary).get("flag", "")))
					if lk != null and str(lk) == str((o as Dictionary).get("value", true)):
						pick = o
				out.append(_scene_text(pick.get("then", [])))
			elif d.has("if"):
				var cond: Array = d["if"]
				var ok := GameState.campaign_flag_is(str(cond[0]), cond[1] if cond.size() > 1 else null)
				out.append(_scene_text(d.get("then", []) if ok else d.get("else", [])))
			continue
		out.append(str((ln as Array)[1]))
	return "\n".join(out)


## Choke outro + epilogue agree with who the saved story says fell.
func _check_story_text(what: String) -> void:
	var fall := str(GameState.campaign_canon_flag("choke_fall", ""))
	var choke := _scene_text(CampaignDefs.level("l10_choke")["scenes"]["outro"])
	var epi := _scene_text(CampaignDefs.level("e0_wheels_up")["scenes"]["hangar"])
	var v_fell := GameState.campaign_fallen("vesper_thorn")
	var n_fell := GameState.campaign_fallen("nyx_caldera")
	_check(v_fell == (fall == "vesper_thorn") and n_fell == (fall == "nyx_caldera"), "story %s: fallen state = the Choke outcome (%s)" % [what, fall])
	_check(("Where's Vesper" in choke) == v_fell and ("Where is Nyx" in choke) == n_fell and ("EVERYONE" in choke) == (not v_fell and not n_fell), "story %s: Choke outro matches the fallen state" % what)
	_check(("window seat" in epi) == v_fell and ("shortcut through the sky" in epi) == n_fell and ("back way out of a sky" in epi) == (not n_fell), "story %s: epilogue matches the fallen state" % what)


func _first_clear(id: String, flags: Dictionary) -> void:
	GameState.prepare_campaign_level(id)
	_check(not GameState.campaign_memory_run(), "story: %s first clear is not a memory" % id)
	for k in flags.keys():
		GameState.set_campaign_flag(str(k), flags[k])
	GameState.complete_campaign_level(100.0)
	GameState.leave_campaign_run()


func _test_story_canon() -> void:
	var keep := [GameState.campaign.duplicate(true), GameState.plane_parts.duplicate(), GameState.selected_character_id, GameState.selected_pet_id,
		GameState.account_scrap, GameState.stash.duplicate(true), GameState.camp.duplicate(), GameState.selected_mode_id]
	GameState.campaign = GameState._fresh_campaign()
	GameState.campaign_debug_unlock_to("l02_bell_tower")
	## First playthrough: Vesper kept at arm's length, Nyx loyal -> Vesper falls at Choke.
	_first_clear("l02_bell_tower", {"vesper_open": false})
	GameState.campaign_debug_unlock_to("l06_smugglers_road")
	_first_clear("l06_smugglers_road", {"nyx_sold_road": false})
	GameState.campaign_debug_unlock_to("l10_choke")
	_first_clear("l10_choke", {"choke_fall": "vesper_thorn", "fallen_vesper_thorn": true})
	_check(GameState.campaign_fallen("vesper_thorn") and GameState.campaign_has_survivor("nyx_caldera"), "story: first Choke clear is canonical (Vesper fell)")
	_check_story_text("first clear")
	var canon: Dictionary = GameState.campaign["flags"].duplicate()
	## Memory replays try to rewrite earlier choices.
	for pair in [["l02_bell_tower", "vesper_open", true], ["l06_smugglers_road", "nyx_sold_road", true]]:
		GameState.prepare_campaign_level(str(pair[0]))
		_check(GameState.campaign_memory_run(), "story: %s replay is a memory" % pair[0])
		_check(str(GameState.campaign_locked_choice(str(pair[1]))) == str(canon[pair[1]]), "story: %s choice is locked to the first pick" % pair[0])
		GameState.set_campaign_flag(str(pair[1]), pair[2])
		_check(str(GameState.campaign_flag(str(pair[1]))) == str(canon[pair[1]]), "story: %s replay can't flip %s" % [pair[0], pair[1]])
		var sc := GameState.account_scrap
		var res := GameState.complete_campaign_level(90.0)
		_check(GameState.account_scrap > sc and "A memory: the story stays as it was" in res["lines"], "story: %s memory still pays" % pair[0])
		GameState.leave_campaign_run()
	## Replaying Choke trying to kill a second survivor (Nyx).
	GameState.prepare_campaign_level("l10_choke")
	GameState.set_campaign_flag("choke_fall", "nyx_caldera")
	GameState.set_campaign_flag("fallen_nyx_caldera", true)
	GameState.complete_campaign_level(80.0)
	GameState.leave_campaign_run()
	_check(JSON.stringify(GameState.campaign["flags"]) == JSON.stringify(canon), "story: replays leave every story flag as it was")
	_check(GameState.campaign_fallen("vesper_thorn") and not GameState.campaign_fallen("nyx_caldera") and "nyx_caldera" in GameState.campaign_roster(), "story: replay can't kill a second survivor")
	_check_story_text("after replays")
	## A real replay of Choke through the level scene (outro included).
	GameState.campaign_autoplay = true
	GameState.campaign_autoplay_exit = false
	GameState.prepare_campaign_level("l10_choke")
	await _campaign_play("l10_choke", GameState.campaign_level())
	GameState.campaign_autoplay = false
	_check(JSON.stringify(GameState.campaign["flags"]) == JSON.stringify(canon) and not GameState.campaign_fallen("nyx_caldera"), "story: played Choke replay changes nothing")
	_check_story_text("after a played replay")
	## Broken old saves are repaired from the saved outcome.
	GameState._load_campaign({"done": {"p0_mayday": {"best": 1.0, "runs": 1}}, "flags": {"choke_fall": "none", "fallen_nyx_caldera": true}, "roster": ["nyx_caldera", "vesper_thorn"]})
	_check(not GameState.campaign_fallen("nyx_caldera") and not GameState.campaign_fallen("vesper_thorn"), "story: save repair (everyone lived = nobody fallen)")
	_check_story_text("repaired save A")
	GameState._load_campaign({"flags": {"choke_fall": "vesper_thorn", "fallen_vesper_thorn": true, "fallen_nyx_caldera": true}, "roster": ["nyx_caldera", "vesper_thorn"]})
	_check(GameState.campaign_fallen("vesper_thorn") and not GameState.campaign_fallen("nyx_caldera"), "story: save repair (one outcome, one fallen)")
	_check_story_text("repaired save B")
	## RESTART CAMPAIGN is the only way to change the story.
	GameState.restart_campaign()
	_check(GameState.campaign_done_count() == 0 and (GameState.campaign["flags"] as Dictionary).is_empty(), "story: restart wipes the story")
	GameState.campaign_debug_unlock_to("l10_choke")
	_first_clear("l10_choke", {"choke_fall": "nyx_caldera", "fallen_nyx_caldera": true})
	_check(GameState.campaign_fallen("nyx_caldera") and not GameState.campaign_fallen("vesper_thorn"), "story: after a restart the first clear decides again")
	_check_story_text("after restart")
	var cm: Node = (load("res://scenes/ui/campaign_map.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(cm)
	for k in range(3):
		await get_tree().process_frame
	_check(cm.find_child("RestartCampaign", true, false) != null, "story: campaign map has RESTART CAMPAIGN")
	cm.queue_free()
	await get_tree().process_frame
	GameState.campaign = keep[0]
	GameState.plane_parts = keep[1]
	GameState.selected_character_id = keep[2]
	GameState.selected_pet_id = keep[3]
	GameState.account_scrap = keep[4]
	GameState.stash = keep[5]
	GameState.camp = keep[6]
	GameState.selected_mode_id = keep[7]
	GameState.reset_loadout_to_defaults()


func _labels_text(n: Node) -> String:
	var out := PackedStringArray()
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	for b in n.find_children("*", "Button", true, false):
		out.append((b as Button).text)
	return "\n".join(out)


func _test_plane_unified() -> void:
	var keep := [GameState.campaign.duplicate(true), GameState.plane_parts.duplicate(), GameState.selected_character_id, GameState.selected_pet_id,
		GameState.account_scrap, GameState.stash.duplicate(true), GameState.camp.duplicate(), GameState.tier_clears.duplicate(true), GameState.selected_mode_id]
	## One tracker: a campaign part and the same part from Wander count once.
	GameState.plane_parts = {}
	GameState.campaign = GameState._fresh_campaign()
	_first_clear("p0_mayday", {})
	_check(GameState.has_plane_part("fuselage") and GameState.plane_part_count() == 1, "plane: campaign part lands in the one tracker")
	GameState.selected_character_id = "pebble"
	GameState._record_tier_clear(3)
	GameState._record_tier_clear(4)
	_check(GameState.plane_part_count() == 2 and GameState.has_plane_part("wings"), "plane: Wander tier part, no double count")
	## Same count in the Campaign map, the mode choice and the Hangar.
	var want := GameState.plane_progress_text()
	for sp in ["res://scenes/ui/campaign_map.tscn", "res://scenes/ui/mode_choice.tscn"]:
		var s: Node = (load(sp) as PackedScene).instantiate()
		get_tree().root.add_child(s)
		for k in range(3):
			await get_tree().process_frame
		_check(want in _labels_text(s), "plane: %s shows %s" % [sp.get_file(), want])
		s.queue_free()
		await get_tree().process_frame
	var hg: Node = (load("res://scenes/ui/hangar.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(hg)
	await get_tree().process_frame
	hg.call("open_trophies")
	await get_tree().process_frame
	_check(("HELM'S PLANE  " + want) in _labels_text(hg), "plane: hangar shows %s" % want)
	_check(bool(hg.call("_layer_visible", "plane_1")) and bool(hg.call("_layer_visible", "plane_2")) and not bool(hg.call("_layer_visible", "plane_3")), "plane: hangar art follows the tracker")
	hg.call("close_popup")
	hg.queue_free()
	await get_tree().process_frame
	## Save migration: old Wander tier keys + old campaign parts merge, nothing lost.
	GameState._load_depth({"plane_parts": {"3": true, "6": true, "4": true}})
	GameState._load_campaign({"flags": {"ending": "power"}, "parts": ["frame", "battery", "engine", "heart", "bogus"]})
	var ks: Array = GameState.plane_parts.keys()
	ks.sort()
	_check(ks == ["battery", "engine", "fuselage", "heart", "wings"] and GameState.plane_part_count() == 4, "plane: old saves merge both trackers (%s)" % str(ks))
	GameState._load_depth({"plane_parts": {"5": true}})
	GameState._load_campaign({"flags": {"ending": "destroy"}, "parts": ["fuel", "heart"]})
	ks = GameState.plane_parts.keys()
	ks.sort()
	_check(ks == ["fuel", "tail"], "plane: old destroy-ending save drops the wrongly given Dust Heart (%s)" % str(ks))
	GameState.save_profile()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	GameState.plane_parts = {}
	GameState.apply_save(raw)
	_check(GameState.has_plane_part("fuel") and GameState.has_plane_part("tail") and GameState.plane_part_count() == 2, "plane: unified tracker survives a save round trip")
	## Dustfall: destroy -> no heart; power -> heart.
	for pair in [["destroy", false], ["power", true]]:
		GameState.plane_parts = {}
		GameState.campaign = GameState._fresh_campaign()
		GameState.campaign_debug_unlock_to("l12_dustfall")
		_first_clear("l12_dustfall", {"ending": pair[0]})
		_check(GameState.has_plane_part("heart") == bool(pair[1]), "plane: %s the heart -> Dust Heart part %s" % [pair[0], pair[1]])
		_check(GameState.plane_part_count() == 0, "plane: the heart never counts towards the whole plane")
	## A memory replay of Dustfall can't change the ending (or hand out the heart).
	GameState.plane_parts = {}
	GameState.campaign = GameState._fresh_campaign()
	GameState.campaign_debug_unlock_to("l12_dustfall")
	_first_clear("l12_dustfall", {"ending": "destroy"})
	GameState.prepare_campaign_level("l12_dustfall")
	GameState.set_campaign_flag("ending", "power")
	GameState.complete_campaign_level(99.0)
	GameState.leave_campaign_run()
	_check(GameState.campaign_flag_is("ending", "destroy") and not GameState.has_plane_part("heart"), "plane: Dustfall replay keeps destroy, no heart")
	GameState.campaign = keep[0]
	GameState.plane_parts = keep[1]
	GameState.selected_character_id = keep[2]
	GameState.selected_pet_id = keep[3]
	GameState.account_scrap = keep[4]
	GameState.stash = keep[5]
	GameState.camp = keep[6]
	GameState.tier_clears = keep[7]
	GameState.selected_mode_id = keep[8]
	GameState.reset_loadout_to_defaults()


## P2 readability / front door: text floor + Text size, dailies only for
## unlocked content, first launch -> Mayday, Quick Deploy, pause top-right.
func _test_p2_ui() -> void:
	var MenuFlowS: Script = load("res://scripts/ui/menu_flow.gd")
	var keep_settings: Dictionary = GameState.settings.duplicate(true)
	var keep := [GameState.total_runs, GameState.successful_extracts, GameState.account_xp, GameState.tutorial_done,
		GameState.campaign.duplicate(true), GameState.best_tier_extracted, GameState.daily.duplicate(true),
		GameState.selected_mode_id, GameState.selected_character_id, GameState.selected_pet_id]
	## --- dailies never reference locked content
	var bad_daily := 0
	for t in range(1, 4):
		var ctx: Dictionary = QuestDefs.unlocked_context(t)
		for d in range(90):
			var date := "2026-%02d-%02d" % [1 + d / 28, 1 + d % 28]
			for q in QuestDefs.roll_daily(date, t, ctx):
				var qd: Dictionary = q
				if not QuestDefs.daily_is_unlocked(qd, ctx) or int(qd.get("tier", 1)) > t \
						or (str(qd["type"]) == "elite" and t < ModeDefs.ELITE_FROM_TIER) \
						or (qd.has("kind") and not (str(qd["kind"]) in (ctx["kinds"] as Array))):
					bad_daily += 1
	_check(bad_daily == 0, "p2: dailies only ask for unlocked tiers / mobs (%d bad)" % bad_daily)
	_check(not QuestDefs.daily_is_unlocked({"type": "kills", "hero": "nobody"}, QuestDefs.unlocked_context(1))
		and not QuestDefs.daily_is_unlocked({"type": "kills", "pet": "no_pet"}, QuestDefs.unlocked_context(1))
		and not QuestDefs.daily_is_unlocked({"type": "extract", "zone": 9}, QuestDefs.unlocked_context(2)), "p2: hero / pet / zone requirements gate dailies")
	## A stale save holding a locked daily is re-rolled.
	GameState.best_tier_extracted = 0
	GameState.daily = {"date": GameState.today(), "quests": [{"type": "extract_tier", "tier": 9, "need": 1, "have": 0, "reward": 1, "claimed": false, "label": "x"},
		{"type": "elite", "need": 1, "have": 0, "reward": 1, "claimed": false, "label": "y"}]}
	var ok_stale := true
	for q in GameState.daily_quests():
		ok_stale = ok_stale and QuestDefs.daily_is_unlocked(q, QuestDefs.unlocked_context(GameState.highest_unlocked_tier()))
	_check(ok_stale, "p2: a saved daily for locked content is replaced")
	## --- Text size setting persists and scales
	UiTheme.set_text_size(2)
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	_check(typeof(raw) == TYPE_DICTIONARY and int((raw as Dictionary).get("settings", {}).get("text_size", -1)) == 2, "p2: text size saved")
	GameState.settings["text_size"] = 0
	GameState.apply_save(raw)
	_check(UiTheme.text_size_index() == 2, "p2: text size loads back")
	var big := UiTheme.body_label("Readable", UiTheme.T_SMALL)
	add_child(big)
	await get_tree().process_frame
	_check(big.get_theme_font_size("font_size") == UiTheme.font_px(UiTheme.MIN_FONT) and UiTheme.font_px(UiTheme.MIN_FONT) > UiTheme.MIN_FONT, "p2: Extra large scales labels (%d)" % big.get_theme_font_size("font_size"))
	UiTheme.set_text_size(0)
	await get_tree().process_frame
	_check(big.get_theme_font_size("font_size") == UiTheme.MIN_FONT, "p2: back to Normal refits live labels")
	big.queue_free()
	## --- no text under the floor, every button a 44-pt target (main screens)
	GameState.total_runs = maxi(1, GameState.total_runs)
	for path in ["res://scenes/ui/main_menu.tscn", "res://scenes/ui/hangar.tscn", "res://scenes/ui/loadout.tscn",
			"res://scenes/ui/settings_menu.tscn", "res://scenes/ui/logbook.tscn", "res://scenes/ui/mode_select.tscn"]:
		var inst: Node = (load(path) as PackedScene).instantiate()
		get_tree().root.add_child(inst)
		for i in range(6):
			await get_tree().process_frame
		var small := PackedStringArray()
		for n in inst.find_children("*", "Control", true, false):
			var c := n as Control
			if not c.is_visible_in_tree():
				continue
			if c is Label or c is Button:
				var px := UiTheme.font_pixel != null and c.get_theme_font("font") == UiTheme.font_pixel
				var floor_fs := UiTheme.MIN_PIXEL_FONT if px else UiTheme.MIN_FONT
				if c.get_theme_font_size("font_size") < floor_fs:
					small.append("%s(%d)" % [c.name, c.get_theme_font_size("font_size")])
			if c is BaseButton and (c.size.x < UiTheme.MIN_TOUCH - 0.5 or c.size.y < UiTheme.MIN_TOUCH - 0.5):
				small.append("btn %s %dx%d" % [c.name, int(c.size.x), int(c.size.y)])
		_check(small.is_empty(), "p2: %s readable + tappable %s" % [path.get_file(), ", ".join(small.slice(0, 6))])
		if path.ends_with("main_menu.tscn"):
			_check(inst.find_child("QuickDeploy", true, false) != null, "p2: main menu offers Quick Deploy")
		if path.ends_with("hangar.tscn"):
			_check(inst.find_child("QuickDeploy", true, false) != null, "p2: hangar offers Quick Deploy")
		inst.queue_free()
		await get_tree().process_frame
	## --- pause cap: top-right, 44-pt target
	var tc: Node = (load("res://scenes/ui/touch_controls.tscn") as PackedScene).instantiate()
	add_child(tc)
	await get_tree().process_frame
	var pb: Control = tc.get("btn_pause")
	var vp := get_viewport().get_visible_rect().size
	var pc: Vector2 = pb.call("center_global")
	_check(pc.x > vp.x * 0.8 and pc.y < vp.y * 0.12, "p2: pause sits top-right (%s)" % str(pc))
	_check(bool(pb.call("hit", pc + Vector2(UiTheme.MIN_TOUCH * 0.5 - 1.0, 0))), "p2: pause hit area is a 44-pt target")
	tc.queue_free()
	## --- Quick Deploy: last hero / pet / tier, locked tier falls back
	GameState.selected_character_id = "pebble"
	GameState.selected_mode_id = ModeDefs.DRIFT_ID
	MenuFlowS.call("prepare_quick_deploy")
	_check(GameState.selected_character_id == "pebble" and GameState.selected_mode_id == ModeDefs.DRIFT_ID and GameState.play_mode == "wander"
		and str(GameState.weapon.get("id", "")) != "", "p2: quick deploy keeps the last setup")
	GameState.selected_mode_id = str(ModeDefs.tier_mode(ModeDefs.EXPOSED_TIERS).get("id", "haze"))
	MenuFlowS.call("prepare_quick_deploy")
	_check(GameState.selected_mode_id == ModeDefs.HAZE_ID, "p2: quick deploy never drops into a locked tier")
	## --- first launch: new profile -> Mayday once; old saves -> menu
	GameState.total_runs = 0
	GameState.successful_extracts = 0
	GameState.account_xp = 0
	GameState.tutorial_done = false
	GameState.campaign = GameState._fresh_campaign()
	GameState.settings.erase("opening_seen")
	_check(str(MenuFlowS.call("first_launch_target")) == "p0_mayday", "p2: first launch on a new profile -> Mayday")
	_check(str(MenuFlowS.call("first_launch_target")) == "", "p2: only the first launch is routed")
	GameState.settings.erase("opening_seen")
	GameState.total_runs = 4
	_check(str(MenuFlowS.call("first_launch_target")) == "" and bool(GameState.settings.get("opening_seen", false)), "p2: an existing save opens the menu")
	## The boot menu really hands over to the prologue.
	GameState.total_runs = 0
	GameState.settings.erase("opening_seen")
	MenuFlowS.set("_boot_checked", false)
	## Boot path: the menu arrives as the current scene (a stand-in is swapped out).
	var stand_in := Node.new()
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	get_tree().change_scene_to_packed(load("res://scenes/ui/main_menu.tscn") as PackedScene)
	for i in range(12):
		await get_tree().process_frame
	var cur := get_tree().current_scene
	_check(cur != null and cur.scene_file_path == CampaignDefs.MATCH_SCENE and GameState.campaign_level_id == "p0_mayday", "p2: boot menu routes into Mayday")
	get_tree().paused = false
	if is_instance_valid(cur) and cur != self:
		cur.queue_free()
	GameState.leave_campaign_run()
	get_tree().current_scene = self
	await get_tree().process_frame
	## restore
	GameState.settings = keep_settings
	GameState.total_runs = keep[0]
	GameState.successful_extracts = keep[1]
	GameState.account_xp = keep[2]
	GameState.tutorial_done = keep[3]
	GameState.campaign = keep[4]
	GameState.best_tier_extracted = keep[5]
	GameState.daily = keep[6]
	GameState.selected_mode_id = keep[7]
	GameState.selected_character_id = keep[8]
	GameState.selected_pet_id = keep[9]
	UiTheme.text_scale = UiTheme.TEXT_SCALES[UiTheme.text_size_index()]
	GameState.reset_loadout_to_defaults()
	print("P2_UI_OK")
