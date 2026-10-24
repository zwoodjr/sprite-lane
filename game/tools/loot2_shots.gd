extends Node

## Loot v2 captures: Settings auto-salvage toggle, result screen with the
## auto-salvage line, Hangar stash in SET sort, Gear slot picker in SET sort.
##   xvfb-run godot --path game --rendering-method gl_compatibility \
##     --resolution 720x1560 res://tools/loot2_shots.tscn -- OUTDIR
## Run with a throwaway XDG_DATA_HOME (it saves settings).

var _out: String = "/tmp/loot2"


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
	for ch in get_tree().root.get_children():
		if ch != self and ch.get_parent() == get_tree().root and ch == get_tree().current_scene:
			ch.queue_free()
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	return inst


func _scroll_to(root: Node, target: Control) -> void:
	for sc in root.find_children("*", "ScrollContainer", true, false):
		var s := sc as ScrollContainer
		if target != null and s.is_ancestor_of(target):
			s.scroll_vertical = int(target.global_position.y - s.global_position.y + s.scroll_vertical - 40)
		elif target == null:
			s.scroll_vertical = 100000


func _stock(rng: RandomNumberGenerator) -> void:
	GameState.stash.clear()
	GameState.loadouts.clear()
	GameState.salvage_bin.clear()
	GameState.camp["stash"] = 1
	var hero := "ash_rook"
	GameState.selected_character_id = hero
	for sl in ["head", "chest", "legs", "boots"]:
		var it := GearDefs.make_gear(sl, "epic", rng, "general", hero)
		it["set"] = "night_runner"
		it["name"] = "Night Runner's %s" % GearDefs.SLOT_NAME[sl]
		GameState.add_to_stash(it)
	for sl in ["head", "hands"]:
		var it := GearDefs.make_gear(sl, "legendary" if sl == "head" else "epic", rng, "survivor", hero)
		GameState.add_to_stash(it)
	var pd := GearDefs.make_gear("head", "epic", rng, "general", hero)
	pd["set"] = "plague_doctor"
	pd["name"] = "Plague Doctor's Mask"
	GameState.add_to_stash(pd)
	var qp := GearDefs.make_gear("chest", "epic", rng, "survivor", "pebble")
	qp["set"] = "quarry_plate"
	qp["hero"] = "pebble"
	qp["name"] = "Quarry Plate Chest"
	GameState.add_to_stash(qp)
	for sl in ["head", "boots", "charm", "legs"]:
		GameState.add_to_stash(GearDefs.make_gear(sl, "common" if sl != "legs" else "rare", rng))
	GameState.add_to_stash(GearDefs.make_weapon(hero, "rare", rng))


func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	GameState.tutorial_done = true
	## 1. Settings: the toggle (ON), scrolled into view.
	GameState.settings["auto_salvage_commons"] = true
	var st := _scene("res://scenes/ui/settings_menu.tscn")
	await _wait(12)
	_scroll_to(st, null)
	await _wait(4)
	await _snap("loot2_settings_toggle")
	## 2. Result screen: a run with Commons auto-salvaged.
	_stock(rng)
	GameState.selected_mode_id = "drift"
	GameState.begin_run()
	for sl in ["boots", "charm", "legs", "hands", "vial"]:
		GameState.add_run_loot(GearDefs.make_gear(sl, "common", rng))
	GameState.add_run_loot(GearDefs.make_gear("shoulders", "rare", rng))
	GameState.add_run_loot(GearDefs.make_gear("chest", "epic", rng, "general", "ash_rook"))
	GameState.add_run_loot(GearDefs.make_weapon("ash_rook", "legendary", rng))
	GameState.kills = 214
	GameState.on_extract_success()
	_scene("res://scenes/ui/result_screen.tscn")
	await _wait(240)
	await _snap("loot2_result_auto_salvage")
	## 3. Hangar stash, SET sort.
	_stock(rng)
	var h := _scene("res://scenes/ui/hangar.tscn")
	await _wait(6)
	h.call("show_tab", "stash")
	h.call("set_stash_sort", "set")
	await _wait(8)
	_scroll_to(h, h.find_child("AutoSalvageToggle", true, false) as Control)
	await _wait(4)
	await _snap("loot2_stash_set_sort")
	h.call("cycle_stash_filter", "set")
	h.call("cycle_stash_filter", "set")
	await _wait(6)
	_scroll_to(h, h.find_child("AutoSalvageToggle", true, false) as Control)
	await _wait(4)
	await _snap("loot2_stash_set_filter")
	## 4. Gear slot picker (head), SET sort.
	var lo := _scene("res://scenes/ui/loadout.tscn")
	await _wait(6)
	lo.call("set_hero", "ash_rook")
	lo.call("select_slot", "head")
	lo.call("set_sort", "set")
	await _wait(8)
	await _snap("loot2_picker_set_sort")
	GameState.settings["auto_salvage_commons"] = false
	get_tree().quit()
