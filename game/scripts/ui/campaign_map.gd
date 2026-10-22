extends "res://scripts/ui/menu_base.gd"

## Act One on one map: the hangar at the bottom, Dustfall at the top. Each
## chapter is a band of its own ground (style bible zone colours); levels are
## badges along one dashed brass trail (locked dark + padlock, done = tick,
## boss levels = skull). The selected level's card sits above the map: title,
## who goes (pick from the survivors the story has met), PLAY / REPLAY.
## Top strip: the camp so far (survivor portraits, dogs) and Helm's plane parts.

const STOP := 88.0
const ROW := 120.0
const BAND_HEAD := 72.0
const BOSS_LEVELS := ["l04_cathedral", "l07_mother_vane", "l08_dead_signal", "l09_quarantine", "l11_wardens_gate", "l12_dustfall"]

var _sel: String = ""
var _detail: VBoxContainer
var _scroll: ScrollContainer
var _map: _Map
var _badges: Dictionary = {}


func build(c: VBoxContainer) -> void:
	c.add_theme_constant_override("separation", 16)
	c.add_child(header("CAMPAIGN", GameState.go_mode_choice))
	c.add_child(_camp_strip())
	_sel = GameState.campaign_next_level()
	_detail = VBoxContainer.new()
	c.add_child(_detail)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 18
	c.add_child(_scroll)
	_map = _Map.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_map)
	var h := 32.0
	for ch in CampaignDefs.CHAPTERS:
		h += BAND_HEAD + ROW * float((ch["levels"] as Array).size())
	_map.custom_minimum_size = Vector2(0, h + 96.0)
	for id in CampaignDefs.ORDER:
		_add_badge(str(id))
	_map.resized.connect(_place)
	_refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	_place()
	## Centre the selected level in the view.
	var b: Control = _badges.get(_sel, null)
	if b and is_instance_valid(b):
		_scroll.scroll_vertical = int(maxf(0.0, b.position.y + STOP * 0.5 - _scroll.size.y * 0.5))


## Survivors met (portrait row, 48 px) and plane parts (icons, lit when found).
func _camp_strip() -> Control:
	var p := card(UiTheme.LINE)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	for hid in CharacterDefs.PLAYABLE_IDS:
		var met := GameState.campaign_has_survivor(str(hid))
		var fallen := GameState.campaign_fallen(str(hid))
		var tr := TextureRect.new()
		var pp := CampaignDefs.portrait_path(CampaignDefs.hero_speaker(str(hid)))
		if pp != "":
			tr.texture = load(pp)
		tr.custom_minimum_size = Vector2(40, 40)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.modulate = Color.WHITE if met else (Color(0.6, 0.25, 0.22) if fallen else Color(0.12, 0.1, 0.1))
		h.add_child(tr)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	## Helm's plane: parts found / needed.
	var have := (GameState.campaign["parts"] as Array).size()
	var ic := IconSet.rect("tab_camp", 48)
	ic.modulate = Color.WHITE if have > 0 else Color(0.35, 0.3, 0.3)
	h.add_child(ic)
	var pl := UiTheme.pixel_label("%d/%d" % [have, CampaignDefs.PLANE_ORDER.size()], UiTheme.PX_M, UiTheme.AMBER)
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pl)
	return p


func _add_badge(id: String) -> void:
	var b := _Badge.new()
	b.num = CampaignDefs.number_tag(id)
	b.unlocked = GameState.campaign_level_unlocked(id)
	b.done = GameState.campaign_level_done(id)
	b.soon = not CampaignDefs.is_playable(id)
	b.boss = id in BOSS_LEVELS
	b.ground = CampaignDefs.chapter_of(id)["ground"]
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.custom_minimum_size = Vector2(STOP, STOP)
	b.size = Vector2(STOP, STOP)
	b.mouse_force_pass_scroll_events = true
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: select(id))
	_map.add_child(b)
	var nm := UiTheme.head_label(str(CampaignDefs.level(id).get("title", "")).to_upper(), UiTheme.T_H3,
		UiTheme.TEXT if b.unlocked else UiTheme.TEXT_DIM)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.clip_text = true
	_map.add_child(nm)
	_badges[id] = b
	b.set_meta("label", nm)


func select(id: String) -> bool:
	Juice.sfx("ui_tap")
	_sel = id
	_refresh()
	return GameState.campaign_level_unlocked(id)


## Bottom-up: chapter bands, each with its levels zig-zagging up the trail.
func _place() -> void:
	if _map == null:
		return
	var w := _map.size.x
	var y := _map.size.y - 64.0
	var pts := PackedVector2Array()
	var bands: Array = []
	var xs := [0.5, 0.26, 0.5, 0.74]
	var k := 0
	for ch in CampaignDefs.CHAPTERS:
		var y0 := y
		for id in ch["levels"]:
			y -= ROW
			var x := w * float(xs[k % 4])
			k += 1
			var p := Vector2(x, y + ROW * 0.5)
			pts.append(p)
			var b: Control = _badges[str(id)]
			b.position = (p - Vector2(STOP, STOP) * 0.5).floor()
			var lab: Label = b.get_meta("label")
			lab.size = Vector2(w * 0.42, 40)
			if x <= w * 0.5:
				lab.position = Vector2(x + STOP * 0.5 + 12.0, p.y - 20.0)
				lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			else:
				lab.position = Vector2(x - STOP * 0.5 - 12.0 - lab.size.x, p.y - 20.0)
				lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		y -= BAND_HEAD
		bands.append({"y0": y, "y1": y0, "ch": ch})
	_map.points = pts
	_map.bands = bands
	var lit := 0
	for i in range(CampaignDefs.ORDER.size()):
		if GameState.campaign_level_unlocked(str(CampaignDefs.ORDER[i])):
			lit = i
	_map.lit = lit
	_map.queue_redraw()


func _refresh() -> void:
	for id in _badges.keys():
		var b: _Badge = _badges[id]
		b.selected = id == _sel
		b.queue_redraw()
		var lab: Label = b.get_meta("label")
		lab.add_theme_color_override("font_color", UiTheme.AMBER if b.selected else (UiTheme.TEXT if b.unlocked else UiTheme.TEXT_DIM))
	_build_detail()


func _build_detail() -> void:
	for ch in _detail.get_children():
		_detail.remove_child(ch)
		ch.queue_free()
	var lv := CampaignDefs.level(_sel)
	var unlocked := GameState.campaign_level_unlocked(_sel)
	var done := GameState.campaign_level_done(_sel)
	var p := card(UiTheme.AMBER if unlocked else UiTheme.LINE)
	_detail.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var ch: Dictionary = lv.get("chapter", {})
	var tag := UiTheme.head_label("%s  ·  %s" % [str(ch.get("tag", "")), str(ch.get("name", "")).to_upper()], UiTheme.T_H3, UiTheme.AMBER)
	v.add_child(tag)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	var num := UiTheme.pixel_label(CampaignDefs.number_tag(_sel), UiTheme.PX_L, UiTheme.AMBER)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(num)
	var t := UiTheme.title_label(str(lv.get("title", "")).to_upper(), UiTheme.T_TITLE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(t)
	if done:
		var best := float((GameState.campaign["done"] as Dictionary).get(_sel, {}).get("best", 0.0))
		top.add_child(IconSet.rect("hud_timer", 48))
		var bl := UiTheme.pixel_label("%d:%02d" % [int(best) / 60, int(best) % 60], UiTheme.PX_M, UiTheme.TEXT)
		bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(bl)
	var sub := UiTheme.body_label(str(lv.get("subtitle", "")), UiTheme.T_SMALL, UiTheme.TEXT_DIM, true)
	v.add_child(sub)
	if not CampaignDefs.is_playable(_sel):
		v.add_child(UiTheme.head_label("COMING SOON", UiTheme.T_H3, UiTheme.TEXT_DIM))
		return
	if not unlocked:
		v.add_child(UiTheme.head_label("LOCKED  ·  FINISH THE LEVEL BEFORE IT", UiTheme.T_H3, UiTheme.TEXT_DIM))
		return
	## Who goes.
	var heroes := GameState.campaign_heroes_for(_sel)
	var pick := GameState.campaign_pick_for(_sel)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	v.add_child(hr)
	var forced := heroes.size() == 1
	for hid in heroes:
		var hb := _HeroTile.new()
		hb.hero = str(hid)
		hb.on = str(hid) == pick
		hb.custom_minimum_size = Vector2(64, 64)
		hb.focus_mode = Control.FOCUS_NONE
		hb.flat = true
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			hb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var hh := str(hid)
		hb.pressed.connect(func() -> void:
			GameState.campaign_set_pick(_sel, hh)
			Juice.sfx("ui_tap")
			_build_detail())
		hr.add_child(hb)
	var hname := str(CharacterDefs.get_character(pick).get("display_name", pick)).to_upper()
	if forced:
		var who := UiTheme.head_label("AS " + hname, UiTheme.T_H3, UiTheme.TEXT)
		who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hr.add_child(who)
	var go := UiTheme.big_button(("REPLAY" if done else "PLAY") + ("" if forced else "  ·  " + hname), UiTheme.AMBER, 80, 32)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lid := _sel
	go.pressed.connect(func() -> void: GameState.go_campaign_level(lid, GameState.campaign_pick_for(lid)))
	v.add_child(go)


## Chapter bands (zone ground, speck clusters, the chapter name) + the trail.
class _Map extends Control:
	var points := PackedVector2Array()
	var bands: Array = []
	var lit: int = 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var f: Font = UiTheme.font_button
		for b in bands:
			var ch: Dictionary = b["ch"]
			var g: Array = ch["ground"]
			var r := Rect2(0, float(b["y0"]), size.x, float(b["y1"]) - float(b["y0"]))
			draw_rect(r, Color(str(g[1])))
			## speck clusters, lit top-left (deterministic)
			var n := int(r.size.y / 24.0)
			for i in range(n):
				var px := fposmod(float(i) * 197.0 + float(ch["num"]) * 61.0, maxf(1.0, size.x - 12.0))
				var py := r.position.y + fposmod(float(i) * 53.0, maxf(1.0, r.size.y - 8.0))
				draw_rect(Rect2(floorf(px), floorf(py), 6, 4), Color(str(g[3])))
				draw_rect(Rect2(floorf(px) + 2, floorf(py) + 4, 6, 2), Color(str(g[0])))
			## band edge: INK line, chapter name at the band's top
			draw_rect(Rect2(0, r.position.y, size.x, 4), Color("140c0e"))
			if f:
				var txt := "%s  ·  %s" % [str(ch["tag"]), str(ch["name"]).to_upper()]
				draw_string_outline(f, Vector2(16, r.position.y + 40), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color("140c0e"))
				draw_string(f, Vector2(16, r.position.y + 40), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ffc040"))
		## The hangar at the bottom of the trail.
		if points.size() > 0:
			var hb := Vector2(points[0].x, size.y - 32.0)
			var t := IconSet.tex("tab_camp", true)
			if t:
				draw_texture_rect(t, Rect2(hb - Vector2(24, 24), Vector2(48, 48)), false)
			_dash(hb, points[0], true)
		for i in range(points.size() - 1):
			_dash(points[i], points[i + 1], i + 1 <= lit)

	func _dash(a: Vector2, b: Vector2, on: bool) -> void:
		var d := b - a
		var n := int(d.length() / 16.0)
		for k in range(n):
			if k % 2 == 1:
				continue
			var p0 := a + d * (float(k) / n)
			var p1 := a + d * (float(k + 1) / n)
			draw_line(p0, p1, Color("140c0e"), 10.0)
			draw_line(p0, p1, Color("b88a33") if on else Color("3a3436"), 6.0)


## Level badge: steel ring, the chapter's ground inside, number in pixels.
class _Badge extends Button:
	var num: String = "1"
	var unlocked: bool = false
	var done: bool = false
	var soon: bool = false
	var boss: bool = false
	var selected: bool = false
	var ground: Array = []
	var _t: float = 0.0

	func _process(d: float) -> void:
		if selected:
			_t += d
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		if selected:
			var k := 0.5 + 0.5 * sin(_t * 4.0)
			draw_circle(c, r, Color(1.0, 0.75, 0.25, 0.25 + 0.25 * k))
		draw_circle(c, r - 4.0, Color("140c0e"))
		draw_circle(c, r - 6.0, Color("ffc040") if selected else (Color("5e6d7a") if unlocked else Color("36424f")))
		draw_circle(c, r - 12.0, Color("140c0e"))
		draw_circle(c, r - 14.0, Color(str(ground[1])) if unlocked else Color("1f1a1d"))
		var f: Font = UiTheme.font_pixel
		if f:
			var fs := 24 if num.length() <= 1 else 16
			var tw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := (c + Vector2(-tw * 0.5, fs * 0.5)).floor()
			draw_string_outline(f, pos, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color("140c0e"))
			draw_string(f, pos, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffc040") if unlocked else Color("5d5654"))
		var badge := ""
		if not unlocked:
			badge = "camp_stash"
		elif done:
			badge = "tab_daily"
		elif boss:
			badge = "hud_kills"
		if badge != "":
			var t := IconSet.tex(badge, false)
			if t:
				draw_texture_rect(t, Rect2(Vector2(size.x - 36, size.y - 36), Vector2(48, 48)), false)


## Hero pick tile: portrait in a brass (picked) or steel frame.
class _HeroTile extends Button:
	var hero: String = ""
	var on: bool = false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("140c0e"))
		var pp := CampaignDefs.portrait_path(CampaignDefs.hero_speaker(hero))
		if pp != "":
			draw_texture_rect(load(pp), r.grow(-4.0), false)
		draw_rect(r.grow(-1.0), Color("ffc040") if on else Color("5e6d7a"), false, 3.0 if on else 2.0)
