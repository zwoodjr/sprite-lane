extends Node

const CraftSets = preload("res://scripts/data/craft_defs.gd")
const PetGear = preload("res://scripts/data/pet_gear_defs.gd")

## Layout check: no action button may sit on top of a label, and no row may
## overflow its card. Builds the Gear screen (every slot picker with the
## longest item open, sets popups) and the Hangar (every tab, crates open,
## Workbench item card, Kennel + pet gear picker) with the longest item and
## set names in the data, at phone sizes and every text size. Also the main
## menu, every Settings tab, the level-up cards and a live match HUD with the
## thumb controls, at the iPhone Duo's inner (1878x2670), cover (1398x2034)
## and landscape (2670x1878) sizes as well, plus a live fold / unfold pass
## (Hangar, level-up, a match with the stick held through the resize).
##   godot --headless --path game res://tools/layout_check.tscn
## Prints LAYOUT_PASS / LAYOUT_FAIL n.

const SIZES := [Vector2i(390, 844), Vector2i(375, 812), Vector2i(375, 667),
	Vector2i(1878, 2670), Vector2i(1398, 2034), Vector2i(2670, 1878)]
## Fold / unfold / rotate order for the live-resize pass.
const FOLD := [Vector2i(1398, 2034), Vector2i(1878, 2670), Vector2i(2670, 1878), Vector2i(1398, 2034), Vector2i(390, 844)]

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
		## Mid-animation (a pulsing / popping logo or card): not a layout fault.
		if (c as Control).scale != Vector2.ONE:
			continue
		var pr := (p as Control).get_global_rect()
		var cr := (c as Control).get_global_rect()
		_checked += 1
		if cr.position.x < pr.position.x - 2.0 or cr.end.x > pr.end.x + 2.0:
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


## Main menu + every Settings tab (as the overlay from the main menu).
func _menu_pass() -> void:
	## No "resume your run?" dialog from the match passes.
	GameState.live_run = {}
	DirAccess.remove_absolute(GameState.RUN_PATH)
	GameState.save_profile()
	var mm := _scene("res://scenes/ui/main_menu.tscn")
	await _settle()
	_where = "main menu"
	await _check(mm)
	_check_inside(mm, "main menu")
	mm.call("open_settings")
	await _settle()
	var scr: Node = get_tree().root.find_child("SettingsMenu", true, false)
	if scr != null:
		for t in SettingsDefs.TABS:
			scr.call("show_tab", str(t["id"]))
			await _settle()
			_where = "settings %s" % t["id"]
			await _check(scr)
			_check_inside(scr.find_child("Tabs", true, false), "settings tab bar")
		scr.call("close")
	await _wait(2)
	if is_instance_valid(mm):
		mm.queue_free()
	await _wait(2)


## Level-up cards (3 choices) and the BUILD PATHS overlay.
func _levelup_pass() -> void:
	var pk := CanvasLayer.new()
	pk.set_script(load("res://scripts/ui/run_upgrade_picker.gd"))
	get_tree().root.add_child(pk)
	await _wait(1)
	var keep_fast := GameState.fast_timers
	GameState.fast_timers = false
	pk.call("open", 7, Progression.roll_run_choices())
	await _settle()
	_where = "level-up cards"
	await _check(pk)
	_check_inside(pk.get("_root").get_child(1), "level-up cards")
	GameState.fast_timers = keep_fast
	get_tree().paused = false
	pk.queue_free()
	await _wait(2)


## Every visible control of `root` lies inside the screen.
func _check_inside(root: Node, what: String) -> void:
	if root == null:
		return
	var vp := get_viewport().get_visible_rect()
	var all: Array = []
	if root is Control:
		all.append(root)
	_collect(root, all)
	for c in all:
		## Buttons and text only: painted backdrops may bleed past the edge.
		if not (c is Button or c is Label):
			continue
		var r := _shown(c as Control)
		if r.size.x <= 2.0 or r.size.y <= 2.0:
			continue
		_checked += 1
		if not vp.grow(1.0).encloses(r):
			_fail("%s: off screen %s (screen %s)" % [what, _desc(c), vp.size])
			return


func _start_match() -> Node:
	TouchInput.touch_primary = true
	GameState.selected_character_id = "ash_rook"
	GameState.selected_mode_id = "haze"
	GameState.fast_timers = true
	GameState.begin_run()
	var m := _scene("res://scenes/match/match.tscn")
	await _wait(24)
	get_tree().paused = false
	return m


func _end_match(m: Node) -> void:
	get_tree().paused = false
	if is_instance_valid(m):
		m.queue_free()
	await _wait(3)
	GameState.fast_timers = false
	GameState.live_run = {}
	DirAccess.remove_absolute(GameState.RUN_PATH)


func _tc() -> Node:
	return get_tree().get_first_node_in_group("touch_controls")


## HUD + thumb controls: DASH / ABILITY inside the safe area, in the bottom
## corner within thumb reach, apart, and clear of the HUD panels; spawns land
## off-screen (the camera's view cap).
func _hud_checks(m: Node, what: String) -> void:
	var hud: Node = m.get_node_or_null("HUD")
	_where = what
	await _check(hud)
	_check_inside(hud.get("root") if hud else null, what + " HUD")
	var tc := _tc()
	if tc == null:
		_fail("%s: no touch controls" % what)
		return
	var vp := get_viewport().get_visible_rect().size
	var safe := MobileLayout.control_safe_margin()
	var corner := safe.end
	var dash: Control = tc.get("btn_dash")
	var abil: Control = tc.get("btn_ability")
	for b in [dash, abil]:
		var r := (b as Control).get_global_rect()
		_checked += 3
		if not safe.grow(2.0).encloses(r):
			_fail("%s: %s outside the safe area %s / %s" % [what, b.get("label_text"), r, safe])
		var c := r.get_center()
		if c.x < vp.x * 0.5 or c.y < vp.y * 0.5:
			_fail("%s: %s not in the bottom-right corner (%s)" % [what, b.get("label_text"), c])
		## Thumb reach: within ~1.6 in of the corner on an iPhone (380 UI px).
		if c.distance_to(corner) > 380.0:
			_fail("%s: %s out of thumb reach (%d px from the corner)" % [what, b.get("label_text"), int(c.distance_to(corner))])
	_checked += 1
	if dash.get_global_rect().intersects(abil.get_global_rect()):
		_fail("%s: DASH and ABILITY overlap" % what)
	if hud:
		for nm in ["Vitals"]:
			var n: Control = hud.get("root").get_node_or_null(nm)
			if n and n.visible:
				for b in [dash, abil]:
					_checked += 1
					if n.get_global_rect().intersects((b as Control).get_global_rect()):
						_fail("%s: %s covers the %s" % [what, b.get("label_text"), nm])
	await _corner_checks(m, what)
	## Fairness: a spawn never lands inside the visible world.
	var cam: Camera2D = m.get_node("World/Player").get_node_or_null("Camera2D")
	if cam:
		var pl := m.get_node("World/Player") as Node2D
		var view := Rect2(pl.global_position + cam.offset - vp / cam.zoom * 0.5, vp / cam.zoom)
		var hd := (vp / cam.zoom).length() * 0.5
		_checked += 1
		if hd > 640.5:
			_fail("%s: visible world radius %d > cap" % [what, int(hd)])
		for i in range(16):
			var a := TAU * float(i) / 16.0
			var sp: Vector2 = m.call("_spawn_point_outside_view", Vector2(cos(a), sin(a)))
			_checked += 1
			if view.grow(-8.0).has_point(sp):
				_fail("%s: spawn on screen at %s (view %s)" % [what, sp, view])
				break


## Max gap (UI px) between a control's outer edges and its screen corner.
const CORNER_N := 240.0


## Controls hug the real screen corners (not a centred column): ABILITY over
## DASH bottom-right (bottom-left when left-handed), the MOVE hint
## bottom-left (mirrored), vitals top-left, pause + minimap top-right; none
## of them reaches into the central 50% of the screen around the hero.
func _corner_checks(m: Node, what: String) -> void:
	var tc := _tc()
	var hud: Node = m.get_node_or_null("HUD")
	if tc == null or hud == null:
		return
	for lh in [false, true]:
		GameState.set_setting("left_handed", lh, false)
		await _wait(2)
		var vp := get_viewport().get_visible_rect().size
		var mid := Rect2(vp * 0.25, vp * 0.5)
		var dash: Control = tc.get("btn_dash")
		var abil: Control = tc.get("btn_ability")
		var pause: Control = tc.get("btn_pause")
		var sr: float = float(tc.get("stick_radius"))
		var gp: Vector2 = tc.call("_ghost_pos")
		var stick := Rect2(gp - Vector2.ONE * sr, Vector2.ONE * sr * 2.0)
		var hroot: Control = hud.get("root")
		var items := {
			"DASH": [dash.get_global_rect(), "br"],
			"ABILITY": [abil.get_global_rect(), "br"],
			"MOVE": [stick, "bl"],
			"PAUSE": [pause.get_global_rect(), "tr"],
			"Vitals": [(hroot.get_node("Vitals") as Control).get_global_rect(), "tl"],
		}
		var mm: Control = hud.get("_minimap")
		if mm:
			items["Minimap"] = [mm.get_global_rect(), "tr"]
		var tp: Control = hud.get("_threat_panel")
		if tp and tp.visible:
			## Under the minimap: hugs the right edge, stays in the top band.
			items["LOOT"] = [tp.get_global_rect(), "tr", vp.y * 0.3]
		for nm in items:
			var r: Rect2 = items[nm][0]
			var cn: String = items[nm][1]
			var ny: float = float(items[nm][2]) if items[nm].size() > 2 else CORNER_N
			if lh and nm in ["DASH", "ABILITY", "MOVE"]:
				cn = ("bl" if cn == "br" else "br")
			var gx := r.position.x if cn.ends_with("l") else vp.x - r.end.x
			var gy := r.position.y if cn.begins_with("t") else vp.y - r.end.y
			_checked += 2
			if gx < -1.0 or gy < -1.0 or gx > CORNER_N or gy > ny:
				_fail("%s%s: %s %d,%d px from the %s corner (max %d)" % [what, " LH" if lh else "", nm, int(gx), int(gy), cn, int(CORNER_N)])
			## LOOT is a label (allowed up top, checked to the top 30% above);
			## the controls themselves never reach the central half.
			if nm != "LOOT" and r.intersects(mid):
				_fail("%s%s: %s %s covers the central 50%% %s" % [what, " LH" if lh else "", nm, r, mid])
		if not lh and what.begins_with("hud") and UiTheme.text_size_index() == 0:
			print("   corners %s: dash %s abil %s move %s pause %s" % [vp, dash.get_global_rect(), abil.get_global_rect(), stick, pause.get_global_rect()])
		_checked += 1
		if dash.get_global_rect().get_center().y <= abil.get_global_rect().get_center().y:
			_fail("%s: ABILITY not stacked over DASH" % what)
	GameState.set_setting("left_handed", false, false)
	await _wait(2)


func _hud_pass(sz: Vector2i) -> void:
	var m: Node = await _start_match()
	await _hud_checks(m, "hud %dx%d" % [sz.x, sz.y])
	if sz.x > 1000:
		## Xogot on the Duo inner screen reported a safe area ~69% as wide as
		## the window: the bogus side must not drag the controls inward.
		MobileLayout.sim_display_safe = Rect2i(0, int(sz.y * 0.03), int(sz.x * 0.69), int(sz.y * 0.95))
		get_viewport().size_changed.emit()
		await _wait(3)
		var sm := MobileLayout.control_safe_margin()
		var vp := get_viewport().get_visible_rect().size
		_checked += 1
		if vp.x - sm.end.x > 40.0:
			_fail("hud %dx%d bogus safe area: right margin %d" % [sz.x, sz.y, int(vp.x - sm.end.x)])
		await _hud_checks(m, "hud %dx%d xogot-safe" % [sz.x, sz.y])
		MobileLayout.sim_display_safe = Rect2i()
		get_viewport().size_changed.emit()
		await _wait(3)
	await _end_match(m)


func _touch(idx: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = down
	_tc().call("_input", e)


func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	_tc().call("_input", e)


## Live fold / unfold / rotate: the Hangar and the level-up cards refit, and
## in a match the stick held through the resize keeps steering; a touch
## whose lift was lost in the fold doesn't block the next one.
func _fold_pass() -> void:
	UiTheme.set_text_size(0)
	get_window().size = FOLD[0]
	await _wait(4)
	var h := _scene("res://scenes/ui/hangar.tscn")
	await _settle()
	for i in range(1, FOLD.size()):
		get_window().size = FOLD[i]
		await _settle()
		h.call("show_tab", "camp")
		await _settle()
		_where = "fold hangar %dx%d" % [FOLD[i].x, FOLD[i].y]
		await _check(h)
		_check_inside(h, _where)
	h.queue_free()
	await _wait(2)
	get_window().size = FOLD[0]
	await _wait(4)
	var m: Node = await _start_match()
	for i in range(1, FOLD.size()):
		var vp := get_viewport().get_visible_rect().size
		var p0 := vp * Vector2(0.3, 0.75)
		_touch(0, p0, true)
		_drag(0, p0 + Vector2(70, 0))
		await _wait(1)
		var before := TouchInput.get_move()
		get_window().size = FOLD[i]
		await _settle()
		var vp2 := get_viewport().get_visible_rect().size
		var p1 := vp2 * Vector2(0.3, 0.75)
		## The held thumb moves on in the new layout (same spot on the glass).
		_drag(0, p1 + Vector2(70, 0))
		await _wait(1)
		var after := TouchInput.get_move()
		_checked += 2
		if before.x <= 0.1:
			_fail("fold %d: stick did not steer before the fold" % i)
		if after.x <= 0.1:
			_fail("fold %d: stick lost across the fold (%s -> %s)" % [i, before, after])
		## Lift lost in a fold (finger 0 never lifts or moves again): after
		## the next fold a new finger still gets the stick.
		_tc().call("_on_fold", vp2)
		_touch(3, p1 + Vector2(0, -40), true)
		_drag(3, p1 + Vector2(-80, -40))
		await _wait(1)
		_checked += 1
		if TouchInput.get_move().x >= -0.1:
			_fail("fold %d: new touch after a lost lift got no stick (%s)" % [i, TouchInput.get_move()])
		_touch(3, p1, false)
		_touch(0, p1, false)
		await _wait(1)
		_checked += 1
		if TouchInput.get_move().length() > 0.01:
			_fail("fold %d: stick stuck after release" % i)
		await _hud_checks(m, "fold hud %dx%d" % [FOLD[i].x, FOLD[i].y])
	await _end_match(m)
	## Level-up cards open while folding.
	var pk := CanvasLayer.new()
	pk.set_script(load("res://scripts/ui/run_upgrade_picker.gd"))
	get_tree().root.add_child(pk)
	await _wait(1)
	pk.call("open", 7, Progression.roll_run_choices())
	for i in range(1, FOLD.size()):
		get_window().size = FOLD[i]
		await _settle()
		_where = "fold level-up %dx%d" % [FOLD[i].x, FOLD[i].y]
		await _check(pk)
		_check_inside(pk.get("_root").get_child(pk.get("_root").get_child_count() - 1), _where)
	get_tree().paused = false
	pk.queue_free()
	await _wait(2)


func _run() -> void:
	var save_backup := FileAccess.get_file_as_string(GameState.SAVE_PATH) if FileAccess.file_exists(GameState.SAVE_PATH) else ""
	var run_backup := FileAccess.get_file_as_string(GameState.RUN_PATH) if FileAccess.file_exists(GameState.RUN_PATH) else ""
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
			await _menu_pass()
			await _levelup_pass()
			await _hud_pass(sz)
			print("   failures: %d" % (_bad - b0))
	print("-- fold / unfold")
	var bf := _bad
	await _fold_pass()
	print("   failures: %d" % (_bad - bf))
	UiTheme.set_text_size(ts0)
	if save_backup != "":
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(save_backup)
			f.close()
	DirAccess.remove_absolute(GameState.RUN_PATH)
	if run_backup != "":
		var rf := FileAccess.open(GameState.RUN_PATH, FileAccess.WRITE)
		if rf:
			rf.store_string(run_backup)
			rf.close()
	print("checks: %d" % _checked)
	print("LAYOUT_PASS" if _bad == 0 else "LAYOUT_FAIL %d" % _bad)
	get_tree().quit(0 if _bad == 0 else 1)
