extends "res://scripts/ui/menu_base.gd"

## The Hangar (home base). Top: the hangar itself, built from stacked painted
## layers that appear as ranks are bought (assets/sprites/hangar, see
## tools/gen_hangar_art.py). Below: tabs for the three upgrade layers + stash,
## then Logbook / Trophy wall / Deploy. One thumb: big rows, big buttons.

const HANGAR_DIR := "res://assets/sprites/hangar/"
const TABS := ["camp", "survivors", "kennel", "brew", "stash"]
const TAB_LABEL := {"camp": "CAMP", "survivors": "CREW", "kennel": "KENNEL", "brew": "BREW", "stash": "STASH"}
const TAB_ICON := {"camp": "tab_camp", "survivors": "tab_crew", "kennel": "tab_kennel", "brew": "tab_brew", "stash": "tab_stash"}
const RARITY_FRAME := "res://assets/sprites/icons/frames/frame_%s.png"
const PET_ON_BED := {"noel": Vector2(110, 141.5), "bentley": Vector2(125, 141.5), "lillie": Vector2(140, 141.5)}
## Painted layers are cropped PNGs; this gives each one's rect on the painted canvas.
const ART_LAYOUT := preload("res://scripts/data/hangar_art_layout.gd")

var _scrap_label: Label
var _view: Control
var _layers: Dictionary = {} ## layer name -> TextureRect
var _pets: Dictionary = {} ## pet id -> TextureRect (dog on its bed)
var _tab_btns: Dictionary = {}
var _tab: String = "camp"
var _scroll: ScrollContainer
var _list: VBoxContainer
var _scroll_y_keep: int = 0
var _popup: Control


func build(c: VBoxContainer) -> void:
	c.add_theme_constant_override("separation", 16)
	var top := header("HANGAR", GameState.go_main_menu)
	top.add_child(IconSet.rect("cur_scrap", 48))
	_scrap_label = UiTheme.pixel_label("", UiTheme.PX_M, UiTheme.AMBER)
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_scrap_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_scrap_label)
	c.add_child(top)

	_view = _build_view()
	c.add_child(_view)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	c.add_child(tabs)
	for t in TABS:
		var b := UiTheme.big_button(TAB_LABEL[t], UiTheme.LINE, 64, 16)
		b.icon = IconSet.tex(str(TAB_ICON[t]), false)
		b.add_theme_constant_override("h_separation", 4)
		b.custom_minimum_size.x = 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_tab.bind(t))
		tabs.add_child(b)
		_tab_btns[t] = b

	_scroll = ScrollContainer.new()
	_scroll.name = "HangarScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 18
	c.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)
	_scroll.resized.connect(_sync_list_width)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	c.add_child(bottom)
	var log_b := UiTheme.big_button("LOGBOOK", UiTheme.TEAL, 64, 16)
	log_b.custom_minimum_size.x = 0
	log_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_b.pressed.connect(open_logbook)
	bottom.add_child(log_b)
	var gear_b := UiTheme.big_button("GEAR", UiTheme.TEAL, 64, 16)
	gear_b.custom_minimum_size.x = 0
	gear_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_b.pressed.connect(func() -> void: GameState.go_loadout("hangar"))
	bottom.add_child(gear_b)
	var tro_b := UiTheme.big_button("TROPHIES", UiTheme.TEAL, 64, 16)
	tro_b.custom_minimum_size.x = 0
	tro_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tro_b.pressed.connect(open_trophies)
	bottom.add_child(tro_b)
	var play := UiTheme.big_button("DEPLOY", UiTheme.AMBER, 64, 24)
	play.custom_minimum_size.x = 0
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.size_flags_stretch_ratio = 1.4
	play.pressed.connect(GameState.go_mode_select)
	bottom.add_child(play)

	show_tab("camp")
	if not GameState.check_milestones().is_empty():
		GameState.save_profile()
		_refresh_view(false)
	if GameState.claim_pending_rewards() > 0:
		_toast("A story reward was waiting — it's in the stash now")
	if GameState.hangar_notice != "":
		_toast(GameState.hangar_notice)
		GameState.hangar_notice = ""


## =========================================================================
## The hangar picture

func _build_view() -> Control:
	var v := Control.new()
	_view = v
	v.name = "HangarView"
	v.custom_minimum_size = Vector2(0, 400)
	v.clip_contents = true
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var names: Array = ["backdrop", "trophy_wall"]
	for s in [0, 1, 2, 3]:
		names.append("stash_%d" % s)
	## Ranks 2 and 4 are repair layers (welds, lamps back on) over the rank-1 prop.
	for id in HangarDefs.SHARED_IDS:
		for s in [1, 2, 3, 4, 5]:
			names.append("%s_%d" % [id, s])
	for h in CharacterDefs.PLAYABLE_IDS:
		for s in [1, 2, 3, 4, 5]:
			names.append("station_%s_%d" % [h, s])
	for p in ["noel", "bentley", "lillie"]:
		for s in [1, 2, 3]:
			names.append("kennel_%s_%d" % [p, s])
	for b in ["dread_naught", "mutant_overlord"]:
		names.append("trophy_%s" % b)
	for cz in ["banner", "flag", "campfire", "toys", "case"]:
		names.append("cosmetic_%s" % cz)
	for n in names:
		var path := HANGAR_DIR + str(n) + ".png"
		if not ResourceLoader.exists(path):
			continue
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tr)
		_layers[n] = tr
	## Depth E7: Helm's plane, rebuilt outside the door one tier-part at a time.
	for i in range(1, ZoneDefs.PLANE_PARTS.size() + 1):
		var pp := ZoneDefs.PLANE_LAYER % i
		if not ResourceLoader.exists(pp):
			continue
		var pl := TextureRect.new()
		pl.texture = load(pp)
		pl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pl.stretch_mode = TextureRect.STRETCH_SCALE
		pl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## Keep it behind the hangar's own props (just above the backdrop).
		v.add_child(pl)
		v.move_child(pl, mini(1, v.get_child_count() - 1))
		_layers["plane_%d" % i] = pl
	## The dogs nap on their beds once the kennel has one.
	for p in PET_ON_BED.keys():
		var tex := _pet_frame(str(p))
		if tex == null:
			continue
		var pr := TextureRect.new()
		pr.texture = tex
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		pr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(pr)
		_pets[p] = pr
	v.resized.connect(_place_art)
	_refresh_view(false)
	return v


func _pet_frame(pet_id: String, tight: bool = false) -> Texture2D:
	## Row icons use the painted pet portrait (tools/gen_portraits.py).
	var portrait := "res://assets/sprites/portraits/pet_%s.png" % pet_id
	if tight and ResourceLoader.exists(portrait):
		return load(portrait)
	var def := PetDefs.get_pet(pet_id)
	var path := str(def.get("anim", "")) + "_idle.png"
	if not ResourceLoader.exists(path):
		return null
	var strip: Texture2D = load(path)
	var at := AtlasTexture.new()
	at.atlas = strip
	var h := float(strip.get_height())
	at.region = Rect2(h * 0.2, h * 0.28, h * 0.6, h * 0.6) if tight else Rect2(0, 0, h, h)
	return at


## Art-space (240x150) → view-space transform for the stacked layers.
func _art_rect() -> Rect2:
	var sz := _view.size
	var s := minf(sz.x / 240.0, sz.y / 150.0)
	var w := 240.0 * s
	var h := 150.0 * s
	return Rect2((sz.x - w) * 0.5, (sz.y - h) * 0.5, w, h)


func _place_art() -> void:
	var r := _art_rect()
	var k := r.size.x / ART_LAYOUT.CANVAS.x
	for n in _layers.keys():
		var lr: Rect2 = ART_LAYOUT.RECTS.get(n, Rect2(Vector2.ZERO, ART_LAYOUT.CANVAS))
		if str(n).begins_with("plane_"):
			lr = ZoneDefs.PLANE_RECT
		var tr: TextureRect = _layers[n]
		tr.position = r.position + lr.position * k
		tr.size = lr.size * k
	var s := r.size.x / 240.0
	for p in _pets.keys():
		var pr: TextureRect = _pets[p]
		var feet: Vector2 = PET_ON_BED[p]
		var size := 30.0 * s
		pr.size = Vector2(size, size)
		pr.position = r.position + feet * s - Vector2(size * 0.5, size * 0.82)


func _layer_visible(n: String) -> bool:
	if n == "backdrop" or n == "trophy_wall" or n == "stash_0":
		return true
	if n.begins_with("trophy_"):
		return GameState.has_trophy(n.substr(7))
	if n.begins_with("plane_"):
		## Layer i = the part from tier i + 2 (Smog = 1 ... Dustfall = 8).
		return GameState.plane_parts.has(str(int(n.substr(6)) + 2))
	if n.begins_with("cosmetic_"):
		return GameState.has_cosmetic(n.substr(9))
	var cut := n.rfind("_")
	var id := n.substr(0, cut)
	var stage := int(n.substr(cut + 1))
	return GameState.camp_rank(id) >= stage


func _refresh_view(animate: bool) -> void:
	for n in _layers.keys():
		var tr: TextureRect = _layers[n]
		var want := _layer_visible(str(n))
		if want and not tr.visible and animate:
			tr.visible = true
			tr.modulate.a = 0.0
			tr.create_tween().tween_property(tr, "modulate:a", 1.0, 0.45)
		else:
			tr.visible = want
	## The Generator lights the whole hangar.
	var g := GameState.camp_rank("generator")
	var lit := 0.62 + 0.076 * float(g)
	var tint := Color(lit, lit * 0.97, lit * 0.92)
	for n in _layers.keys():
		(_layers[n] as TextureRect).self_modulate = tint
	for p in _pets.keys():
		var pr: TextureRect = _pets[p]
		pr.visible = GameState.kennel_rank(str(p)) >= 1
		pr.self_modulate = tint
	_place_art()


## =========================================================================
## Tabs + rows

func show_tab(t: String) -> void:
	if not t in TABS:
		return
	if t != _tab:
		_scroll_y_keep = 0
	_tab = t
	for k in _tab_btns.keys():
		var b: Button = _tab_btns[k]
		var on := str(k) == t
		UiTheme.skin_button(b, UiTheme.AMBER if on else UiTheme.LINE, 12.0)
	_rebuild()


func get_tab() -> String:
	return _tab


func _rebuild() -> void:
	if _scroll != null:
		_scroll_y_keep = _scroll.scroll_vertical
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_scrap_label.text = "%d" % GameState.account_scrap
	match _tab:
		"camp":
			_list.add_child(_note("Shared upgrades help every survivor."))
			for id in HangarDefs.ids_for("shared"):
				_list.add_child(_row(str(id), IconSet.tex("camp_" + str(id))))
			_list.add_child(_row("backpack", IconSet.tex("camp_backpack")))
		"survivors":
			_list.add_child(_note("Each survivor's weapon and signature trick."))
			var ids: Array = HangarDefs.ids_for("station")
			## Selected survivor first.
			var mine := HangarDefs.station_id(GameState.selected_character_id)
			ids.erase(mine)
			ids.push_front(mine)
			for id in ids:
				var hero := str(id).substr(8)
				_list.add_child(_row(str(id), IconSet.tex(IconSet.ability(hero, "a"))))
		"kennel":
			_list.add_child(_note("Noel guards, Bentley scouts, Lillie rams."))
			for id in HangarDefs.ids_for("kennel"):
				if not PetDefs.is_mech(str(id).substr(7)):
					_list.add_child(_row(str(id), _pet_frame(str(id).substr(7), true)))
			_build_workshop()
		"brew":
			_build_brew()
		"stash":
			_build_stash()
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 24)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(pad)
	_sync_list_width()
	call_deferred("_clamp_scroll")


func _note(text: String) -> Label:
	return UiTheme.body_label(text, UiTheme.T_SMALL, UiTheme.TEXT_DIM)


func _row(id: String, icon: Texture2D) -> PanelContainer:
	var rank := GameState.camp_rank(id)
	var max_r := HangarDefs.max_rank(id)
	var cost := GameState.camp_cost(id)
	var maxed := cost < 0
	var mine := HangarDefs.layer_of(id) == "station" and id.substr(8) == GameState.selected_character_id
	var p := card(UiTheme.AMBER if mine else UiTheme.LINE, Color(0.11, 0.08, 0.055, 0.92))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	if icon != null:
		var well := PanelContainer.new()
		well.add_theme_stylebox_override("panel", UiTheme.plate("inset", 4.0))
		well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(well)
		var ir := TextureRect.new()
		ir.texture = icon
		ir.custom_minimum_size = Vector2(96, 96)
		ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ir.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(ir)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	h.add_child(info)
	var title := HBoxContainer.new()
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(title)
	var nm := UiTheme.head_label(HangarDefs.display_name(id), UiTheme.T_H2, UiTheme.AMBER if mine else UiTheme.TEXT)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(nm)
	var pr := UiTheme.rank_pips(rank, max_r, not maxed)
	info.add_child(pr)
	var nx := UiTheme.body_label(HangarDefs.rank_text(id, rank + 1) if not maxed else HangarDefs.rank_text(id, rank), UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	nx.max_lines_visible = 2
	info.add_child(nx)
	var btn: Button
	if maxed:
		btn = UiTheme.big_button("MAX", UiTheme.LINE, 64, 20)
		btn.disabled = true
	else:
		var afford := GameState.account_scrap >= cost
		btn = UiTheme.big_button("%d" % cost, UiTheme.TEAL if afford else UiTheme.RUST, 64, 16)
		btn.add_theme_font_override("font", UiTheme.font_pixel)
		btn.add_theme_font_size_override("font_size", UiTheme.PX_M)
		btn.icon = IconSet.tex("cur_scrap", false)
		btn.disabled = not afford
		btn.pressed.connect(buy.bind(id))
	btn.custom_minimum_size.x = 136
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.mouse_force_pass_scroll_events = true
	h.add_child(btn)
	return p


## Rank pips: filled teal squares for owned ranks.
func _pips(rank: int, max_r: int) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in range(max_r):
		var r := Panel.new()
		r.custom_minimum_size = Vector2(12, 12)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_theme_stylebox_override("panel", UiTheme.plate("bar_fill", 0.0, UiTheme.TEAL) if i < rank else UiTheme.plate("bar_bg", 0.0))
		hb.add_child(r)
	return hb


func buy(id: String) -> bool:
	if not GameState.try_buy_camp(id):
		Juice.sfx("ui_denied")
		return false
	Juice.sfx("ui_purchase")
	for m in GameState.check_milestones():
		_toast("Milestone: %s — the hangar changes" % str(m["name"]))
		GameState.save_profile()
	_refresh_view(true)
	_rebuild()
	return true


## =========================================================================
## Workshop (Depth Update E6): Helm rebuilds war machines into mech pets.

func _build_workshop() -> void:
	var core_row := HBoxContainer.new()
	core_row.add_theme_constant_override("separation", 8)
	var hd := UiTheme.head_label("WORKSHOP", UiTheme.T_H2, UiTheme.AMBER)
	hd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	core_row.add_child(hd)
	core_row.add_child(IconSet.rect("mat_salvage_core", 48))
	var cl := UiTheme.pixel_label("%d" % GameState.salvage_cores(), UiTheme.PX_M, UiTheme.TEAL)
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	core_row.add_child(cl)
	_list.add_child(core_row)
	_list.add_child(_note("Helm rebuilds war-machine cores into mech pets."))
	for mid in PetDefs.MECH_IDS:
		if GameState.pet_available(str(mid)):
			_list.add_child(_row(HangarDefs.kennel_id(str(mid)), _pet_frame(str(mid), true)))
		else:
			_list.add_child(_mech_build_row(str(mid)))


func _mech_build_row(mid: String) -> PanelContainer:
	var d := PetDefs.get_pet(mid)
	var p := card(UiTheme.TEAL, Color(0.07, 0.09, 0.09, 0.92))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var ir := TextureRect.new()
	ir.texture = _pet_frame(mid, true)
	ir.custom_minimum_size = Vector2(96, 96)
	ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ir.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ir.modulate = Color(0.55, 0.6, 0.62)
	ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ir)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	h.add_child(info)
	info.add_child(UiTheme.head_label(str(d["name"]), UiTheme.T_H2, UiTheme.TEAL))
	var ad := UiTheme.body_label(str(d["ability_desc"]), UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	ad.max_lines_visible = 2
	info.add_child(ad)
	var need := HBoxContainer.new()
	need.add_theme_constant_override("separation", 8)
	info.add_child(need)
	var okc := GameState.can_build_mech(mid)
	need.add_child(IconSet.rect("mat_salvage_core", 48))
	var n1 := UiTheme.pixel_label("%d" % int(d["build_cores"]), UiTheme.PX_M, UiTheme.TEXT if okc else UiTheme.DANGER)
	n1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	need.add_child(n1)
	need.add_child(IconSet.rect("cur_scrap", 48))
	var n2 := UiTheme.pixel_label("%d" % int(d["build_scrap"]), UiTheme.PX_M, UiTheme.TEXT if okc else UiTheme.DANGER)
	n2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	need.add_child(n2)
	var ok := GameState.can_build_mech(mid)
	var btn := UiTheme.big_button("BUILD", UiTheme.TEAL if ok else UiTheme.RUST, 64, 20)
	btn.disabled = not ok
	btn.custom_minimum_size.x = 136
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.mouse_force_pass_scroll_events = true
	btn.pressed.connect(build_mech.bind(mid))
	h.add_child(btn)
	return p


func build_mech(mid: String) -> bool:
	if not GameState.build_mech(mid):
		Juice.sfx("ui_denied")
		return false
	Juice.sfx("ui_purchase")
	_toast("%s rebuilt — equip it on the survivor screen" % str(PetDefs.get_pet(mid)["name"]))
	_rebuild()
	return true


## =========================================================================
## Apothecary (Depth Update E1): Cinder brews tonics from run ingredients.

func _build_brew() -> void:
	_list.add_child(_note("Brew from what you carry home. Slotted tonics last the whole run."))
	var inv := HFlowContainer.new()
	inv.add_theme_constant_override("h_separation", 16)
	inv.add_theme_constant_override("v_separation", 8)
	inv.mouse_filter = Control.MOUSE_FILTER_PASS
	_list.add_child(inv)
	for id in MedicineDefs.INGREDIENT_IDS + ["medicine"]:
		inv.add_child(_chip(str(id), GameState.ingredient_count(str(id)), 48, UiTheme.TEXT))
	var slots := GameState.tonic_slot_count()
	var sl := UiTheme.head_label("TONIC SLOTS %d/%d" % [GameState.tonic_loadout.size(), slots], UiTheme.T_H3, UiTheme.AMBER)
	_list.add_child(sl)
	for tid in MedicineDefs.TONIC_IDS:
		_list.add_child(_tonic_row(str(tid)))


## Icon + count chip (ingredients, recipe parts).
func _chip(id: String, n: int, px: float, col: Color, need: int = -1) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(IconSet.rect(IconSet.stuff(id), 48))
	var txt := "%d" % n if need < 0 else "%d/%d" % [n, need]
	var l := UiTheme.pixel_label(txt, UiTheme.PX_M, col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


func _tonic_row(tid: String) -> PanelContainer:
	var td: Dictionary = MedicineDefs.TONICS[tid]
	var slotted := tid in GameState.tonic_loadout
	var p := card(UiTheme.AMBER if slotted else UiTheme.LINE, Color(0.11, 0.08, 0.055, 0.92))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(h)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UiTheme.plate("inset", 4.0))
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(IconSet.rect("tonic_" + tid, 96))
	h.add_child(well)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(info)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 8)
	info.add_child(nh)
	var nm := UiTheme.head_label(str(td["name"]), UiTheme.T_H2, UiTheme.AMBER if slotted else UiTheme.TEXT)
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nh.add_child(nm)
	var stock := UiTheme.pixel_label("x%d" % GameState.tonic_count(tid), UiTheme.PX_M, UiTheme.TEXT)
	stock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nh.add_child(stock)
	var dl := UiTheme.body_label(str(td["desc"]), UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	dl.max_lines_visible = 2
	info.add_child(dl)
	var rec := HBoxContainer.new()
	rec.add_theme_constant_override("separation", 8)
	rec.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(rec)
	var r: Dictionary = td["recipe"]
	for k in r.keys():
		var have := GameState.ingredient_count(str(k))
		rec.add_child(_chip(str(k), have, 48, UiTheme.TEAL if have >= int(r[k]) else UiTheme.DANGER, int(r[k])))
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(btns)
	var can := GameState.can_brew(tid)
	var b := UiTheme.big_button("BREW", UiTheme.TEAL if can else UiTheme.RUST, 64, 20)
	b.custom_minimum_size.x = 120
	b.disabled = not can
	b.mouse_force_pass_scroll_events = true
	b.pressed.connect(brew.bind(tid))
	btns.add_child(b)
	var s := UiTheme.big_button("IN SLOT" if slotted else "BRING", UiTheme.AMBER if slotted else UiTheme.LINE, 64, 20)
	s.custom_minimum_size.x = 120
	s.disabled = not slotted and GameState.tonic_count(tid) <= 0
	s.mouse_force_pass_scroll_events = true
	s.pressed.connect(toggle_tonic.bind(tid))
	btns.add_child(s)
	return p


func brew(tid: String) -> bool:
	if not GameState.brew(tid):
		Juice.sfx("ui_denied")
		return false
	Juice.sfx("ui_purchase")
	_toast("Brewed %s" % MedicineDefs.item_name(tid))
	_rebuild()
	return true


func toggle_tonic(tid: String) -> bool:
	var ok := GameState.toggle_tonic(tid)
	Juice.sfx("ui_toggle")
	_rebuild()
	return ok


## =========================================================================
## Stash (Phase B fills it with gear)

func _build_stash() -> void:
	var cap := GameState.stash_capacity()
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 8)
	_list.add_child(sh)
	for pair in [["camp_stash", "%d/%d" % [GameState.stash.size(), cap]], ["mat_dust_heart", str(GameState.material_count("dust_heart"))],
			["mat_salvage_core", str(GameState.material_count("salvage_core"))]]:
		sh.add_child(IconSet.rect(str(pair[0]), 48))
		var pl := UiTheme.pixel_label(str(pair[1]), UiTheme.PX_M, UiTheme.TEXT)
		pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sh.add_child(pl)
		var g := Control.new()
		g.custom_minimum_size = Vector2(8, 0)
		sh.add_child(g)
	var eqb := UiTheme.big_button("EQUIP SURVIVORS", UiTheme.TEAL, 64, 20)
	eqb.icon = IconSet.tex("slot_chest", false)
	eqb.pressed.connect(func() -> void: GameState.go_loadout("hangar"))
	_list.add_child(eqb)
	_list.add_child(_row("stash", null))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_list.add_child(grid)
	for i in range(cap):
		grid.add_child(_slot(GameState.stash[i] if i < GameState.stash.size() else {}))


func _slot(item: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(112, 112)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_force_pass_scroll_events = true
	var clear := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, clear)
	var ic := LoadoutScreen.item_icon(item, 112.0) if not item.is_empty() else UiTheme.icon_well("", "common", 112)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.modulate = Color(1, 1, 1, 1.0 if not item.is_empty() else 0.4)
	b.add_child(ic)
	if item.is_empty():
		b.disabled = true
	else:
		if not GameState.equipped_by(int(item.get("uid", -1))).is_empty():
			var e := UiTheme.pixel_label("E", UiTheme.PX_M, UiTheme.TEAL)
			e.position = Vector2(12, 12)
			e.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(e)
		b.pressed.connect(inspect_item.bind(int(item.get("uid", -1))))
	return b


## Item detail popup: stats, who wears it, salvage for scrap.
func inspect_item(uid: int) -> void:
	var it := GameState.stash_item(uid)
	if it.is_empty():
		return
	var lines: Array = []
	var rar := str(it.get("rarity", "common"))
	lines.append(GearDefs.RARITY_NAME.get(rar, rar))
	for l in GearDefs.stat_lines(it):
		lines.append(str(l))
	var by := GameState.equipped_by(uid)
	if not by.is_empty():
		lines.append("Worn by %s" % str(CharacterDefs.get_character(str(by[0])).get("display_name", by[0])))
	_open_popup(str(it.get("name", "Item")), lines)
	var v: VBoxContainer = _popup.find_children("*", "VBoxContainer", true, false)[0]
	var sal := UiTheme.big_button("SALVAGE  +%d SCRAP" % GearDefs.salvage_value(it), UiTheme.RUST, 60, 18)
	sal.pressed.connect(func() -> void:
		GameState.salvage(uid)
		Juice.sfx("ui_purchase")
		close_popup()
		_rebuild())
	v.add_child(sal)
	v.move_child(sal, v.get_child_count() - 2)
	## One-tap equip onto the selected survivor when it fits them.
	var hero := GameState.selected_character_id
	if GameState.slot_for(uid, hero) != "" and (by.is_empty() or str(by[0]) != hero):
		var hname := str(CharacterDefs.get_character(hero).get("display_name", hero))
		var eq := UiTheme.big_button("EQUIP ON %s" % hname.to_upper(), UiTheme.TEAL, 60, 18)
		eq.pressed.connect(func() -> void:
			if GameState.quick_equip(uid, hero):
				Juice.sfx("ui_equip")
			close_popup()
			_rebuild())
		v.add_child(eq)
		v.move_child(eq, v.get_child_count() - 3)


## =========================================================================
## Logbook + trophy wall (placeholders until Phase C)

func open_logbook() -> void:
	GameState.go_logbook()


func open_trophies() -> void:
	var lines: Array = []
	for b in [["dread_naught", "Dread Naught"], ["mutant_overlord", "Mutant Overlord"]]:
		lines.append("%s — %s" % [b[1], "TROPHY MOUNTED" if GameState.has_trophy(str(b[0])) else "not yet slain"])
	lines.append("")
	for m in QuestDefs.MILESTONES:
		if str(m.get("cosmetic", "")) != "":
			lines.append("%s %s — %s" % ["[x]" if bool(GameState.milestones.get(str(m["id"]), false)) else "[ ]", str(m["name"]), str(m["desc"])])
	lines.append("")
	lines.append("First kill of each boss puts a trophy over the hangar door; milestones dress up the hangar.")
	_open_popup("TROPHY WALL", lines)
	_add_tier_trophies()


## Depth E7: per-survivor tier clears (Smog → Dustfall) and Helm's plane parts.
func _add_tier_trophies() -> void:
	if _popup == null:
		return
	var v: VBoxContainer = _popup.find_child("*", true, false) as VBoxContainer
	for n in _popup.find_children("*", "VBoxContainer", true, false):
		v = n
		break
	if v == null:
		return
	var close := v.get_child(v.get_child_count() - 1)
	var head := UiTheme.body_label("TIER CLEARS  ·  Smog → Dustfall", 15, UiTheme.AMBER, false)
	v.add_child(head)
	v.move_child(head, close.get_index())
	var grid := GridContainer.new()
	grid.columns = 1 + (ModeDefs.EXPOSED_TIERS - ZoneDefs.TROPHY_FROM_TIER + 1)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	v.add_child(grid)
	v.move_child(grid, close.get_index())
	for h in CharacterDefs.PLAYABLE_IDS:
		var nm := UiTheme.body_label(str(CharacterDefs.get_character(str(h)).get("display_name", h)), 13, UiTheme.TEXT, false)
		nm.custom_minimum_size.x = 120
		nm.clip_text = true
		grid.add_child(nm)
		for t in range(ZoneDefs.TROPHY_FROM_TIER, ModeDefs.EXPOSED_TIERS + 1):
			var on := GameState.has_tier_clear(str(h), t)
			var c := ColorRect.new()
			c.custom_minimum_size = Vector2(22, 16)
			c.color = UiTheme.AMBER if on else Color(0.2, 0.17, 0.14)
			c.tooltip_text = str(ZoneDefs.zone(t)["name"])
			grid.add_child(c)
	var parts: Array = []
	for t in ZoneDefs.PLANE_PARTS.keys():
		parts.append(("[x] " if GameState.plane_parts.has(str(t)) else "[ ] ") + str(ZoneDefs.PLANE_PARTS[t]["name"]))
	var pl := UiTheme.body_label("HELM'S PLANE  %d/%d — %s" % [GameState.plane_part_count(), ZoneDefs.PLANE_PARTS.size(), "  ".join(PackedStringArray(parts))], 13, UiTheme.TEXT_DIM)
	v.add_child(pl)
	v.move_child(pl, close.get_index())


func _open_popup(title: String, lines: Array) -> void:
	close_popup()
	_popup = Control.new()
	_popup.name = "Popup"
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_popup)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(center)
	var p := card(UiTheme.AMBER, UiTheme.PANEL)
	p.custom_minimum_size = Vector2(minf(640.0, get_viewport_rect().size.x - 40.0), 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UiTheme.title_label(title, 34))
	for l in lines:
		v.add_child(UiTheme.body_label(str(l), 17, UiTheme.TEXT))
	var close := UiTheme.big_button("CLOSE", UiTheme.LINE, 60, 20)
	close.pressed.connect(close_popup)
	v.add_child(close)


func close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


func _toast(text: String) -> void:
	var l := UiTheme.body_label(text, 17, UiTheme.AMBER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = 90
	l.offset_left = 30
	l.offset_right = -30
	add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


## =========================================================================
## Scroll helpers (touch: rows pass drags through to the scroller)

func _sync_list_width() -> void:
	if _scroll == null or _list == null:
		return
	## Always reserve the bar's width: sizing to its visibility can loop forever
	## (bar shows -> text wraps taller/shorter -> bar hides -> ...).
	var bar_w := 0.0
	var vbar := _scroll.get_v_scroll_bar()
	if vbar != null:
		bar_w = vbar.get_combined_minimum_size().x
	var w := _scroll.size.x - bar_w
	if w > 1.0:
		_list.custom_minimum_size.x = w


func _clamp_scroll() -> void:
	if _scroll == null:
		return
	_sync_list_width()
	var vbar := _scroll.get_v_scroll_bar()
	if vbar == null:
		return
	var max_y := maxi(0, int(vbar.max_value - vbar.page))
	_scroll.scroll_vertical = clampi(_scroll_y_keep, 0, max_y)
