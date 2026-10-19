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
]

var _bad: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	## Tests buy, equip and bank freely — put the player's save back afterwards.
	var save_backup := FileAccess.get_file_as_string(GameState.SAVE_PATH) if FileAccess.file_exists(GameState.SAVE_PATH) else ""
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
	await _test_full_sets()
	var keep_q := [GameState.daily.duplicate(true), GameState.stories.duplicate(true), GameState.milestones.duplicate(true), GameState.kennel_bond.duplicate(true)]
	await _test_quests_events()
	var keep_best := GameState.best_tier_extracted
	await _test_tiers()
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
		_check(GameState.run_loot.size() >= 3, "%s role loot %d" % [hero, GameState.run_loot.size()])
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
	_check(HangarDefs.cost("stash", 0) == 300 and HangarDefs.cost("stash", 3) == -1, "stash prices")
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
	_check(GameState.result_salvaged == GearDefs.SALVAGE["epic"], "overflow salvaged")
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
	_check(eitems.size() == 2 and str(eitems[1]["kind"]) == "mod" and GearDefs.RARITIES.find(str(eitems[0]["rarity"])) >= 1, "elite reward")
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
				if not seen.has(iid):
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
