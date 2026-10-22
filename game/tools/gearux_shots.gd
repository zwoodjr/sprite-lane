extends Node

## Gear / stash UX captures: a mixed stash (commons to a named Legendary, set
## pieces), the Gear screen, the slot picker + compare, the Hangar stash,
## the salvage confirm, the set overview and the prep screen's gear row.
##   xvfb-run godot --path game --rendering-method gl_compatibility \
##     --resolution 720x1560 res://tools/gearux_shots.tscn -- OUTDIR [prefix]

var _out: String = "/tmp/gearux"
var _pre: String = ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_pre = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s%s.png" % [_out, _pre, name])
	print("SHOT ", name)


func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _scene(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	return inst


func _add(it: Dictionary, hero: String = "", slot: String = "") -> int:
	GameState.add_to_stash(it)
	var uid := int(GameState.stash[GameState.stash.size() - 1]["uid"])
	if hero != "":
		GameState.equip(hero, slot, uid)
	return uid


func _stock() -> Dictionary:
	GameState.stash.clear()
	GameState.loadouts.clear()
	GameState.insured.clear()
	GameState.salvage_bin.clear()
	GameState.camp["stash"] = 3
	GameState.materials = {"dust_heart": 1, "salvage_core": 2}
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var hero := "ash_rook"
	GameState.selected_character_id = hero
	_add(GearDefs.make_weapon(hero, "rare", rng), hero, "weapon")
	var nr := ["head", "chest", "legs"]
	for sl in nr:
		var it := GearDefs.make_gear(sl, "epic", rng, "general", hero)
		it["set"] = "night_runner"
		it["name"] = "Night Runner's %s" % GearDefs.SLOT_NAME[sl]
		_add(it, hero, sl)
	_add(GearDefs.make_gear("boots", "common", rng), hero, "boots")
	_add(GearDefs.make_gear("charm", "rare", rng), hero, "charm")
	_add(GearDefs.make_mod("scope", "rare"), hero, "mod1")
	var leg := _add(GearDefs.make_weapon(hero, "legendary", rng))
	var nr4 := GearDefs.make_gear("boots", "epic", rng, "general", hero)
	nr4["set"] = "night_runner"
	nr4["name"] = "Night Runner's Striders"
	var nr4u := _add(nr4)
	_add(GearDefs.make_gear("hands", "epic", rng, "survivor", hero))
	_add(GearDefs.make_gear("head", "legendary", rng, "survivor", hero))
	for sl in ["head", "chest", "shoulders", "legs", "hands", "boots", "charm", "vial", "patch"]:
		_add(GearDefs.make_gear(sl, "common", rng))
	_add(GearDefs.make_gear("head", "rare", rng))
	_add(GearDefs.make_gear("boots", "rare", rng))
	var pd := GearDefs.make_gear("shoulders", "epic", rng, "general", hero)
	pd["set"] = "plague_doctor"
	pd["name"] = "Plague Doctor's Mantle"
	_add(pd)
	var dc := GearDefs.make_gear("hands", "legendary", rng, "general", hero)
	dc["set"] = "demolition_crew"
	dc["name"] = "Demolition Grips"
	_add(dc)
	_add(GearDefs.make_weapon(hero, "epic", rng))
	_add(GearDefs.make_mod("coat_fire", "epic"))
	_add(GearDefs.make_weapon("pebble", "legendary", rng))
	_add(GearDefs.make_gear("vial", "legendary", rng))
	## Fresh loot from the last run is NEW.
	for it0 in GameState.stash:
		it0.erase("new")
	for i in range(4):
		var it2: Dictionary = GameState.stash[GameState.stash.size() - 1 - i]
		it2["new"] = true
	GameState.stash[GameState.stash.size() - 1]["new"] = true
	GameState.reset_loadout_to_defaults()
	return {"legendary": leg, "nr4": nr4u}


func _run() -> void:
	var save_backup := FileAccess.get_file_as_string(GameState.SAVE_PATH) if FileAccess.file_exists(GameState.SAVE_PATH) else ""
	GameState.tutorial_done = true
	GameState.account_scrap = 1240
	var ids := _stock()
	## Gear screen (summary), then the boots picker with a compare.
	var lo := _scene("res://scenes/ui/loadout.tscn")
	await _wait(30)
	await _snap("01_gear")
	lo.call("select_slot", "boots")
	await _wait(10)
	if lo.has_method("preview_item"):
		lo.call("preview_item", int(ids["nr4"]))
		await _wait(10)
	await _snap("02_gear_pick_compare")
	lo.call("select_slot", "weapon")
	await _wait(10)
	if lo.has_method("preview_item"):
		lo.call("preview_item", int(ids["legendary"]))
		await _wait(10)
	await _snap("03_gear_pick_weapon")
	if lo.has_method("open_set"):
		lo.call("open_set", "night_runner")
		await _wait(10)
		await _snap("04_set_overview")
	lo.queue_free()
	await _wait(2)
	## Hangar stash.
	var h := _scene("res://scenes/ui/hangar.tscn")
	await _wait(10)
	h.call("show_tab", "stash")
	await _wait(20)
	var sc: ScrollContainer = h.find_child("HangarScroll", true, false)
	await _snap("05_stash")
	if sc != null:
		sc.scroll_vertical = 330
		await _wait(10)
	await _snap("05b_stash_grid")
	h.call("inspect_item", int(ids["legendary"]))
	await _wait(15)
	await _snap("06_inspect_legendary")
	if h.has_method("ask_salvage"):
		h.call("ask_salvage", int(ids["legendary"]))
		await _wait(15)
		await _snap("07_salvage_confirm")
	if h.has_method("close_popup"):
		h.call("close_popup")
	if h.has_method("open_buyback"):
		var c := GameState.stash.size()
		for it in GameState.stash.duplicate():
			if str(it.get("rarity", "")) == "common" and GameState.equipped_by(int(it["uid"])).is_empty():
				GameState.call("salvage", int(it["uid"]))
				break
		print("stash ", c)
		h.call("open_buyback")
		await _wait(15)
		await _snap("08_buyback")
		h.call("close_popup")
	h.queue_free()
	await _wait(2)
	## Prep (pre-run loadout) shows the deploy hero's gear.
	var p := _scene("res://scenes/ui/prep.tscn")
	await _wait(30)
	await _snap("09_prep")
	p.queue_free()
	await _wait(2)
	## Owner bug flow: switch survivor on Gear, equip, go to prep — same kit.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lo2 := _scene("res://scenes/ui/loadout.tscn")
	await _wait(10)
	if lo2.has_method("set_hero"):
		lo2.call("set_hero", "pebble")
	for it in [GearDefs.make_weapon("pebble", "legendary", rng), GearDefs.make_gear("chest", "epic", rng, "survivor", "pebble"), GearDefs.make_gear("legs", "rare", rng)]:
		var u := _add(it)
		GameState.quick_equip(u, "pebble")
	lo2.call("refresh")
	await _wait(20)
	await _snap("10_flow_gear_pebble")
	lo2.queue_free()
	await _wait(2)
	var p2 := _scene("res://scenes/ui/prep.tscn")
	await _wait(30)
	await _snap("11_flow_prep_pebble")
	p2.queue_free()
	await _wait(2)
	if save_backup != "":
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(save_backup)
			f.close()
	print("GEARUX_SHOTS_DONE")
	get_tree().quit(0)
