extends Node

const CraftSets = preload("res://scripts/data/craft_defs.gd")
const PetGear = preload("res://scripts/data/pet_gear_defs.gd")

## Layout check: no action button may sit on top of a label, and no row may
## overflow its card. Builds the Gear screen (every slot picker with the
## longest item open, sets popups) and the Hangar (every tab, crates open,
## Workbench item card, Kennel + pet gear picker) with the longest item and
## set names in the data, at phone sizes and every text size.
##   godot --headless --path game res://tools/layout_check.tscn
## Prints LAYOUT_PASS / LAYOUT_FAIL n.

const SIZES := [Vector2i(390, 844), Vector2i(375, 812), Vector2i(375, 667)]

var _bad: int = 0
var _checked: int = 0
var _where: String = ""
var _ids: Dictionary = {}


func _ready() -> void:
	_run.call_deferred()


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


## Longest set title, and the longest item name the generators can make.
func _longest() -> Dictionary:
	var best_set := ""
	var best_len := 0
	var sids: Array = GearDefs.GENERAL_SETS.keys() + GearDefs.SURVIVOR_SETS.keys() + CraftSets.SETS.keys()
	for sid in sids:
		var t := GearDefs.set_title(str(sid))
		if t.length() > best_len:
			best_len = t.length()
			best_set = str(sid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var names: Array = []
	for sid in GearDefs.SURVIVOR_SETS.keys():
		for sl in GearDefs.SURVIVOR_SETS[sid]["slots"]:
			names.append("%s %s" % [GearDefs.SURVIVOR_SETS[sid]["name"], GearDefs.SLOT_NAME[sl]])
	for gid in GearDefs.GENERAL_SETS.keys():
		for sl in GearDefs.ARMOR_SLOTS:
			for nn in GearDefs.SLOT_NOUN.get(sl, []):
				names.append("%s %s" % [GearDefs.GENERAL_SETS[gid]["noun"], nn])
	for rk in GearDefs.RARITY_ADJ.keys():
		for adj in GearDefs.RARITY_ADJ[rk]:
			for sl in GearDefs.SLOT_NOUN.keys():
				for nn in GearDefs.SLOT_NOUN[sl]:
					names.append("%s %s" % [adj, nn])
	for sid in CraftSets.SETS.keys():
		for sl in GearDefs.ARMOR_SLOTS:
			names.append(str(GearDefs.make_craft_piece(str(sid), str(sl), rng)["name"]))
	var best_name := ""
	for nm in names:
		if str(nm).length() > best_name.length():
			best_name = str(nm)
	for h in CharacterDefs.PLAYABLE_IDS:
		var w := GearDefs.make_weapon(str(h), "legendary", rng)
		if str(w["name"]).length() > best_name.length():
			best_name = str(w["name"])
	print("longest set: ", GearDefs.set_title(best_set), " | longest name: ", best_name)
	return {"set": best_set, "name": best_name}


func _stock() -> void:
	GameState.stash.clear()
	GameState.loadouts.clear()
	GameState.insured.clear()
	GameState.salvage_bin.clear()
	GameState.camp["stash"] = 3
	GameState.account_scrap = 99999
	var lg := _longest()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var hero := "ash_rook"
	GameState.selected_character_id = hero
	_add(GearDefs.make_weapon(hero, "legendary", rng), hero, "weapon")
	var first := -1
	for sl in GearDefs.ARMOR_SLOTS:
		## Worn piece of the longest set + a stash piece with the longest name
		## in that same set (so the compare shows set lines and tier tags).
		var w := GearDefs.make_gear(str(sl), "epic", rng, "general", hero)
		w["set"] = lg["set"]
		w["name"] = str(lg["name"])
		_add(w, hero, str(sl))
		var it := GearDefs.make_gear(str(sl), "legendary", rng, "general", hero)
		it["set"] = lg["set"]
		it["name"] = str(lg["name"])
		it["new"] = true
		var u := _add(it)
		if first < 0:
			first = u
		var it2 := GearDefs.make_gear(str(sl), "rare", rng)
		it2["name"] = str(lg["name"])
		_add(it2)
	var wpn := GearDefs.make_weapon(hero, "legendary", rng)
	wpn["name"] = str(lg["name"])
	_add(wpn)
	for t in PetGear.TYPES.keys():
		var pg: Dictionary = PetGear.make(str(t), "legendary", rng)
		pg["name"] = str(lg["name"])
		_add(pg)
	GameState.reset_loadout_to_defaults()
	_ids = {"first": first}


## ---------------------------------------------------------------- checks

func _fail(msg: String) -> void:
	_bad += 1
	if _bad <= 60:
		print("FAIL [%s] %s" % [_where, msg])


func _path(n: Node) -> String:
	var s := str(n.name)
	var p := n.get_parent()
	for i in range(3):
		if p == null:
			break
		s = str(p.name) + "/" + s
		p = p.get_parent()
	return s


func _desc(c: Control) -> String:
	var t := ""
	if c is Label:
		t = (c as Label).text
	elif c is Button:
		t = (c as Button).text
	return "%s '%s' %s" % [_path(c), t.replace("\n", " ").left(40), c.get_global_rect()]


func _collect(n: Node, out: Array) -> void:
	for ch in n.get_children():
		if ch is CanvasItem and not (ch as CanvasItem).visible:
			continue
		if ch is Control:
			out.append(ch)
		_collect(ch, out)


func _is_action(c: Control) -> bool:
	if not (c is Button):
		return false
	var b := c as Button
	return b.text.strip_edges() != "" and not b.flat


func _check(root: Node) -> void:
	var shots := OS.get_environment("LAYOUT_SHOTS")
	if shots != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(shots)
		get_viewport().get_texture().get_image().save_png("%s/%d_%d_%s.png" % [shots, get_window().size.x, UiTheme.text_size_index(), _where.replace(" ", "_")])
	var all: Array = []
	_collect(root, all)
	var buttons: Array = []
	var labels: Array = []
	for c in all:
		if _is_action(c):
			buttons.append(c)
		elif c is Label and (c as Label).text.strip_edges() != "":
			labels.append(c)
	## 1) A button never covers a label (only what is on screen: the part of
	## a scrolled row inside its list's window).
	for b in buttons:
		var br := _shown(b as Control)
		if br.size.x <= 2.0 or br.size.y <= 2.0:
			continue
		br = br.grow(-1.0)
		for l in labels:
			if (b as Node).is_ancestor_of(l):
				continue
			var lr := _shown(l as Control)
			if lr.size.x <= 2.0 or lr.size.y <= 2.0:
				continue
			_checked += 1
			if br.intersects(lr.grow(-1.0)):
				_fail("button %s covers label %s" % [_desc(b), _desc(l)])
	## 2) Nothing spills out of its container (min size wider than the room).
	for c in all:
		var p := (c as Control).get_parent()
		if not (p is Container) or p is ScrollContainer and (p as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			continue
		var pr := (p as Control).get_global_rect()
		var cr := (c as Control).get_global_rect()
		_checked += 1
		if cr.position.x < pr.position.x - 1.0 or cr.end.x > pr.end.x + 1.0:
			_fail("%s spills out of %s" % [_desc(c), _desc(p)])
	## 3) Unclipped one-line labels: the text fits the label.
	for l in labels:
		var lb := l as Label
		if lb.clip_text or lb.autowrap_mode != TextServer.AUTOWRAP_OFF or lb.text.contains("\n"):
			continue
		var f := lb.get_theme_font("font")
		var w := f.get_string_size(lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lb.get_theme_font_size("font_size")).x
		_checked += 1
		if w > lb.size.x + 2.0:
			_fail("label text wider than its box (%d > %d) %s" % [int(w), int(lb.size.x), _desc(lb)])


## Global rect clipped to every ScrollContainer above it (empty = scrolled away).
func _shown(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			r = r.intersection((p as Control).get_global_rect())
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				return Rect2()
		p = p.get_parent()
	return r


func _settle() -> void:
	await _wait(6)


## ---------------------------------------------------------------- screens

func _gear_pass() -> void:
	GameState.loadout_from = "prep"
	var lo := _scene("res://scenes/ui/loadout.tscn")
	await _settle()
	_where = "gear summary"
	await _check(lo)
	for sl in GearDefs.LOADOUT_SLOTS:
		lo.call("select_slot", str(sl))
		await _settle()
		_where = "gear pick %s" % sl
		await _check(lo)
		var row := _first_row(lo)
		if row > 0:
			lo.call("preview_item", row)
			await get_tree().create_timer(0.4).timeout
			await _settle()
			_where = "gear pick %s open" % sl
			await _check(lo)
			var sc: ScrollContainer = lo.find_child("GearScroll", true, false)
			var r: Control = lo.find_child("Row_%d" % row, true, false)
			if sc != null and r != null:
				## The opened card starts at the top of the list (no half card above).
				_checked += 1
				var top := r.get_global_rect().position.y - sc.get_global_rect().position.y
				var vb := sc.get_v_scroll_bar()
				var at_end := sc.scroll_vertical >= int(vb.max_value - vb.page) - 1
				if top < -1.0 or (top > 1.0 and not at_end):
					_fail("opened row not at the list top (offset %d, scroll %d)" % [int(top), sc.scroll_vertical])
		lo.call("select_slot", str(sl))
	lo.call("open_sets")
	await _settle()
	_where = "gear sets popup"
	await _check(lo.find_child("ActiveSetsPopup", true, false))
	lo.call("close_popup")
	lo.queue_free()
	await _wait(2)


func _first_row(lo: Node) -> int:
	var list: Node = (lo.find_child("GearScroll", true, false) as Node).get_child(0)
	for ch in list.get_children():
		var n := str(ch.name)
		if n.begins_with("Row_") and ch.get_child_count() > 0 and ch.get_child(0) is Button:
			return int(n.substr(4))
	return -1


func _hangar_pass() -> void:
	var h := _scene("res://scenes/ui/hangar.tscn")
	await _settle()
	for t in ["camp", "survivors", "kennel", "brew", "stash"]:
		h.call("show_tab", t)
		await _settle()
		_where = "hangar %s" % t
		await _check(h)
	if h.get("_crates_open") == false:
		h.call("toggle_crates")
		await _settle()
		_where = "hangar crates"
		await _check(h)
	h.call("inspect_item", int(_ids["first"]))
	await _settle()
	_where = "hangar workbench"
	await _check(h.get("_popup"))
	h.call("close_popup")
	h.call("show_tab", "kennel")
	await _settle()
	var pc: Node = null
	for c in h.find_children("PetCard_*", "", true, false):
		pc = c
		break
	if pc != null:
		h.call("open_pet_gear", str(pc.name).substr(8))
		await _settle()
		_where = "kennel pet gear"
		await _check(h.get("_popup"))
		h.call("close_popup")
	h.queue_free()
	await _wait(2)


func _run() -> void:
	var save_backup := FileAccess.get_file_as_string(GameState.SAVE_PATH) if FileAccess.file_exists(GameState.SAVE_PATH) else ""
	var ts0 := UiTheme.text_size_index()
	GameState.tutorial_done = true
	_stock()
	for sz in SIZES:
		get_window().size = sz
		await _wait(3)
		for ti in range(UiTheme.TEXT_SCALES.size()):
			UiTheme.set_text_size(ti)
			print("-- %dx%d text %s (view %s)" % [sz.x, sz.y, UiTheme.TEXT_SIZE_NAMES[ti], get_viewport().get_visible_rect().size])
			var b0 := _bad
			await _gear_pass()
			await _hangar_pass()
			print("   failures: %d" % (_bad - b0))
	UiTheme.set_text_size(ts0)
	if save_backup != "":
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(save_backup)
			f.close()
	print("checks: %d" % _checked)
	print("LAYOUT_PASS" if _bad == 0 else "LAYOUT_FAIL %d" % _bad)
	get_tree().quit(0 if _bad == 0 else 1)
