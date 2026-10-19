extends "res://scripts/ui/menu_base.gd"

## The Hangar (home base). Top: the hangar itself, built from stacked painted
## layers that appear as ranks are bought (assets/sprites/hangar, see
## tools/gen_hangar_art.py). Below: tabs for the three upgrade layers + stash,
## then Logbook / Trophy wall / Deploy. One thumb: big rows, big buttons.

const HANGAR_DIR := "res://assets/sprites/hangar/"
const TABS := ["camp", "survivors", "kennel", "stash"]
const TAB_LABEL := {"camp": "CAMP", "survivors": "SURVIVORS", "kennel": "KENNEL", "stash": "STASH"}
const RARITY_FRAME := "res://assets/sprites/icons/frames/frame_%s.png"
const PET_ON_BED := {"noel": Vector2(106, 135), "bentley": Vector2(120, 135), "lillie": Vector2(134, 135)}

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
	c.add_theme_constant_override("separation", 10)
	var top := header("HANGAR", GameState.go_main_menu)
	_scrap_label = UiTheme.title_label("", 30, UiTheme.AMBER)
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_scrap_label)
	c.add_child(top)

	_view = _build_view()
	c.add_child(_view)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	c.add_child(tabs)
	for t in TABS:
		var b := UiTheme.big_button(TAB_LABEL[t], UiTheme.LINE, 54, 17)
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
	var log_b := UiTheme.big_button("LOGBOOK", UiTheme.TEAL, 64, 17)
	log_b.custom_minimum_size.x = 0
	log_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_b.pressed.connect(open_logbook)
	bottom.add_child(log_b)
	var tro_b := UiTheme.big_button("TROPHIES", UiTheme.TEAL, 64, 17)
	tro_b.custom_minimum_size.x = 0
	tro_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tro_b.pressed.connect(open_trophies)
	bottom.add_child(tro_b)
	var play := UiTheme.big_button("DEPLOY", UiTheme.AMBER, 64, 22)
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
	for id in HangarDefs.SHARED_IDS:
		for s in [1, 3, 5]:
			names.append("%s_%d" % [id, s])
	for h in CharacterDefs.PLAYABLE_IDS:
		for s in [1, 3, 5]:
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
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tr)
		_layers[n] = tr
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
	v.resized.connect(_place_pets)
	_refresh_view(false)
	return v


func _pet_frame(pet_id: String, tight: bool = false) -> Texture2D:
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


func _place_pets() -> void:
	var r := _art_rect()
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
	_place_pets()


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
		b.add_theme_stylebox_override("normal", UiTheme.box(
			UiTheme.AMBER.darkened(0.45) if on else UiTheme.PANEL_LIGHT, UiTheme.AMBER if on else UiTheme.LINE, 14, 3 if on else 2))
	_rebuild()


func get_tab() -> String:
	return _tab


func _rebuild() -> void:
	if _scroll != null:
		_scroll_y_keep = _scroll.scroll_vertical
	for c in _list.get_children():
		_list.remove_child(c)
		c.free()
	_scrap_label.text = "%d SCRAP" % GameState.account_scrap
	match _tab:
		"camp":
			_list.add_child(_note("Shared camp upgrades help every survivor."))
			for id in HangarDefs.ids_for("shared"):
				_list.add_child(_row(str(id), null))
		"survivors":
			_list.add_child(_note("Each survivor's corner: their weapon and signature trick."))
			var ids: Array = HangarDefs.ids_for("station")
			## Selected survivor first.
			var mine := HangarDefs.station_id(GameState.selected_character_id)
			ids.erase(mine)
			ids.push_front(mine)
			for id in ids:
				var hero := str(id).substr(8)
				_list.add_child(_row(str(id), load(CharacterDefs.ability_icon_path(hero))))
		"kennel":
			_list.add_child(_note("Three ranks per dog. Noel guards, Bentley scouts, Lillie rams."))
			for id in HangarDefs.ids_for("kennel"):
				_list.add_child(_row(str(id), _pet_frame(str(id).substr(7), true)))
		"stash":
			_build_stash()
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 24)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(pad)
	_sync_list_width()
	call_deferred("_clamp_scroll")


func _note(text: String) -> Label:
	return UiTheme.body_label(text, 15, UiTheme.TEXT_DIM)


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
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	if icon != null:
		var ir := TextureRect.new()
		ir.texture = icon
		ir.custom_minimum_size = Vector2(56, 56)
		ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ir.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ir)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	h.add_child(info)
	var title := HBoxContainer.new()
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(title)
	var nm := UiTheme.body_label(HangarDefs.display_name(id), 19, UiTheme.AMBER, false)
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(nm)
	title.add_child(_pips(rank, max_r))
	if rank > 0:
		info.add_child(UiTheme.body_label("Now: " + HangarDefs.rank_text(id, rank), 13, UiTheme.TEXT))
	if not maxed:
		info.add_child(UiTheme.body_label("Next: " + HangarDefs.rank_text(id, rank + 1), 13, UiTheme.TEXT_DIM))
	else:
		info.add_child(UiTheme.body_label(HangarDefs.blurb(id), 13, UiTheme.TEXT_DIM))
	var btn: Button
	if maxed:
		btn = UiTheme.big_button("MAX", UiTheme.LINE, 60, 17)
		btn.disabled = true
	else:
		var afford := GameState.account_scrap >= cost
		btn = UiTheme.big_button("%d" % cost, UiTheme.TEAL if afford else UiTheme.RUST, 60, 19)
		btn.disabled = not afford
		btn.pressed.connect(buy.bind(id))
	btn.custom_minimum_size.x = 104
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
		r.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.TEAL if i < rank else Color(0.1, 0.08, 0.06), UiTheme.TEAL, 3, 2, 0))
		hb.add_child(r)
	return hb


func buy(id: String) -> bool:
	if not GameState.try_buy_camp(id):
		Juice.sfx("ui_tap")
		return false
	Juice.sfx("pickup")
	for m in GameState.check_milestones():
		_toast("Milestone: %s — the hangar changes" % str(m["name"]))
		GameState.save_profile()
	_refresh_view(true)
	_rebuild()
	return true


## =========================================================================
## Stash (Phase B fills it with gear)

func _build_stash() -> void:
	var cap := GameState.stash_capacity()
	_list.add_child(_note("Shared lockbox: %d / %d slots. Gear you extract with lands here. Tap an item to inspect or salvage it." % [GameState.stash.size(), cap]))
	var eqb := UiTheme.big_button("EQUIP SURVIVORS", UiTheme.TEAL, 58, 18)
	eqb.pressed.connect(func() -> void: GameState.go_loadout("hangar"))
	_list.add_child(eqb)
	_list.add_child(UiTheme.body_label("Dust Hearts %d  ·  Salvage Cores %d" % [GameState.material_count("dust_heart"), GameState.material_count("salvage_core")], 14, UiTheme.TEXT_DIM))
	_list.add_child(_row("stash", null))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_list.add_child(grid)
	for i in range(cap):
		grid.add_child(_slot(GameState.stash[i] if i < GameState.stash.size() else {}))


func _slot(item: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 104)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_force_pass_scroll_events = true
	var clear := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, clear)
	var ic := LoadoutScreen.item_icon(item if not item.is_empty() else {"rarity": "common"}, 96.0)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.modulate = Color(1, 1, 1, 1.0 if not item.is_empty() else 0.35)
	b.add_child(ic)
	if item.is_empty():
		b.disabled = true
	else:
		if not GameState.equipped_by(int(item.get("uid", -1))).is_empty():
			var e := Label.new()
			e.text = "E"
			e.add_theme_font_size_override("font_size", 14)
			e.add_theme_color_override("font_color", UiTheme.TEAL)
			e.position = Vector2(10, 4)
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
		Juice.sfx("pickup")
		close_popup()
		_rebuild())
	v.add_child(sal)
	v.move_child(sal, v.get_child_count() - 2)


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
	var bar_w := 0.0
	var vbar := _scroll.get_v_scroll_bar()
	if vbar != null and vbar.visible:
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
