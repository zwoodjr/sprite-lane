extends "res://scripts/ui/menu_base.gd"

## Tier select as a map: the ten zones lie along one winding brass trail,
## Haze at the bottom, Dustfall at the top. Each stop is a zone badge in that
## zone's ground colours (style bible §2.2) with its number in the pixel font;
## locked stops are dark and padlocked, cleared ones carry a tick. The chosen
## zone's card sits above the map.

## Zone ground (crack, base, mid, speck) per tier, from the bible.
const ZONE_GROUND := [
	["433428", "5b4a3b", "685645", "7e6953"], ["433424", "5d4a36", "6a5640", "7e6a50"],
	["3a3633", "524d46", "5f5951", "746c60"], ["34363f", "494e5a", "54596a", "676d7b"],
	["36382f", "4d4f43", "585b4d", "6b6f5f"], ["4a3028", "67453a", "755244", "896555"],
	["37372d", "4e4e3c", "5a5a46", "6d6e56"], ["323834", "474f4b", "535b56", "676f69"],
	["3a3634", "534c49", "5f5854", "726c67"], ["502f1b", "6b452e", "775038", "8a6549"],
]
const STOP := 96.0 ## badge size
const ROW := 128.0 ## vertical spacing between stops (8-px grid)

var _cards: Dictionary = {}
var _fast: Button

var _detail: VBoxContainer
var _extras: VBoxContainer
var _opt_btn: Button
var _list: Control
var _scroll: ScrollContainer
var _map: _Map

func build(c: VBoxContainer) -> void:
	var portrait := MobileLayout.is_portrait()
	c.add_theme_constant_override("separation", 16)
	c.add_child(header("CHOOSE THE DUST", GameState.go_main_menu))
	if not GameState.is_tier_unlocked(int(GameState.get_mode()["tier"])):
		GameState.selected_mode_id = ModeDefs.HAZE_ID
	## Wander extras: today's Daily Run + this week's Dust modifiers.
	_extras = VBoxContainer.new()
	_extras.name = "WanderExtras"
	_extras.add_theme_constant_override("separation", 8)
	c.add_child(_extras)
	_build_extras()
	_detail = VBoxContainer.new()
	c.add_child(_detail)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 18
	c.add_child(_scroll)
	_map = _Map.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list = _map
	_scroll.add_child(_map)
	var modes := ModeDefs.all_modes()
	_map.custom_minimum_size = Vector2(0, ROW * modes.size() + 32.0)
	for mode in modes:
		_map.add_child(_tier_stop(mode))
	_map.resized.connect(_place_stops)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	c.add_child(bottom)
	_fast = Button.new()
	_fast.toggle_mode = true
	_fast.focus_mode = Control.FOCUS_NONE
	_fast.button_pressed = GameState.fast_timers
	_fast.custom_minimum_size = Vector2(0, 64)
	_fast.add_theme_font_size_override("font_size", UiTheme.T_SMALL)
	_fast.toggled.connect(func(on: bool) -> void:
		GameState.fast_timers = on
		_refresh()
	)
	_fast.visible = GameState.dev_tools
	if not GameState.dev_tools:
		GameState.fast_timers = false
	bottom.add_child(_fast)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	var next := UiTheme.big_button("CHOOSE HERO", UiTheme.AMBER, 80, 32)
	next.custom_minimum_size.x = 320 if portrait else 400
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(GameState.go_character_select)
	bottom.add_child(next)
	_refresh()
	## Bring the selected tier into view.
	await get_tree().process_frame
	await get_tree().process_frame
	_place_stops()
	var b: Variant = _cards.get(GameState.selected_mode_id, {}).get("button", null)
	if b is Control and is_instance_valid(b):
		_scroll.ensure_control_visible(b)


## DAILY RUN card (seed of the day, fixed survivor, today's standing) and the
## WEEKLY DUST card (this week's modifiers, opt-in for normal runs).
func _build_extras() -> void:
	for ch in _extras.get_children():
		_extras.remove_child(ch)
		ch.queue_free()
	## Onboarding: Daily / Weekly appear after the fourth finished run.
	_extras.visible = GameState.feature_on("modes")
	if not _extras.visible:
		return
	var today := GameState.today()
	var hero := DailyDefs.hero_for(today)
	var hc := CharacterDefs.get_character(hero)
	var dp := card(UiTheme.AMBER)
	dp.name = "DailyCard"
	_extras.add_child(dp)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 4)
	dp.add_child(dv)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	dv.add_child(top)
	var pr := TextureRect.new()
	pr.custom_minimum_size = Vector2(64, 64)
	pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var pp := "res://assets/sprites/portraits/%s.png" % hero
	if ResourceLoader.exists(pp):
		pr.texture = load(pp)
	top.add_child(pr)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(tv)
	var tl := HBoxContainer.new()
	tl.add_theme_constant_override("separation", 8)
	tv.add_child(tl)
	var dn := UiTheme.head_label("DAILY RUN", UiTheme.T_H2, UiTheme.AMBER)
	dn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.add_child(dn)
	tl.add_child(UiTheme.pixel_label(today, UiTheme.PX_S, UiTheme.TEXT_DIM))
	var who := UiTheme.body_label("%s · %s · %s — same map for everyone today" % [str(hc.get("display_name", hero)),
		str(PetDefs.get_pet(DailyDefs.pet_for(today)).get("name", "")), str(ModeDefs.get_mode(DailyDefs.TIER_ID)["display_name"])],
		UiTheme.T_SMALL, UiTheme.TEXT, false)
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(who)
	var e := GameState.daily_entry(today)
	var st := ""
	var st_col := UiTheme.TEXT_DIM
	if e.is_empty():
		st = "Not played yet: your first finish counts."
		st_col = UiTheme.TEAL
	else:
		st = "Today: %d (%s)%s" % [int(e["score"]), "extracted" if bool(e["extracted"]) else "went down",
			"  ·  practice best %d" % int(e["practice_best"]) if int(e.get("attempts", 1)) > 1 else "  ·  more runs = practice"]
		st_col = UiTheme.AMBER
	var sl := UiTheme.body_label(st, UiTheme.T_SMALL, st_col, false)
	sl.name = "DailyStatus"
	sl.clip_text = true
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dv.add_child(sl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	dv.add_child(row)
	var board := UiTheme.big_button("BOARD", UiTheme.TEAL, 64, 20)
	board.name = "DailyBoard"
	board.custom_minimum_size.x = 0
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_stretch_ratio = 0.6
	board.pressed.connect(func() -> void: GameState.go_run_history("mode_select", "daily"))
	row.add_child(board)
	var play := UiTheme.big_button("PLAY DAILY" if e.is_empty() else "PRACTICE", UiTheme.AMBER, 64, 24)
	play.name = "DailyPlay"
	play.custom_minimum_size.x = 0
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(GameState.go_daily)
	row.add_child(play)

	var mods := GameState.week_mods()
	var wp := card(UiTheme.RUST)
	wp.name = "WeeklyCard"
	_extras.add_child(wp)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 4)
	wp.add_child(wv)
	var wt := HBoxContainer.new()
	wt.add_theme_constant_override("separation", 8)
	wv.add_child(wt)
	var wn := UiTheme.head_label("WEEKLY DUST", UiTheme.T_H2, UiTheme.RUST.lightened(0.25))
	wn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wt.add_child(wn)
	wt.add_child(UiTheme.pixel_label(DailyDefs.iso_week(today), UiTheme.PX_S, UiTheme.TEXT_DIM))
	for id in mods:
		var m := DustModDefs.mod(str(id))
		var mr := HBoxContainer.new()
		mr.add_theme_constant_override("separation", 8)
		wv.add_child(mr)
		mr.add_child(IconSet.rect(str(m.get("icon", "hud_threat")), 48))
		var mv := VBoxContainer.new()
		mv.add_theme_constant_override("separation", 0)
		mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mr.add_child(mv)
		mv.add_child(UiTheme.head_label(str(m.get("name", id)).to_upper(), UiTheme.T_H3, UiTheme.AMBER))
		var md := UiTheme.body_label(str(m.get("desc", "")), UiTheme.T_SMALL, UiTheme.TEXT)
		md.custom_minimum_size.x = 120
		mv.add_child(md)
	_opt_btn = UiTheme.big_button("", UiTheme.LINE, 56, 20)
	_opt_btn.name = "WeeklyOptIn"
	_opt_btn.toggle_mode = true
	_opt_btn.button_pressed = GameState.weekly_opt_in
	_opt_btn.toggled.connect(func(on: bool) -> void:
		GameState.set_weekly_opt_in(on)
		Juice.sfx("ui_tap")
		_sync_opt())
	wv.add_child(_opt_btn)
	_sync_opt()


func _sync_opt() -> void:
	if not is_instance_valid(_opt_btn):
		return
	var pct := int(round(DustModDefs.loot_bonus(GameState.week_mods()) * 100.0))
	var on := GameState.weekly_opt_in
	_opt_btn.text = ("WANDER RUNS: ON  (+%d%% PAYOUT)" if on else "USE IN WANDER RUNS  (+%d%% PAYOUT)") % pct
	UiTheme.skin_button(_opt_btn, UiTheme.AMBER if on else UiTheme.LINE, 12.0)


## Stops zig-zag up the map: tier 1 bottom-left, alternating sides.
func _place_stops() -> void:
	if _map == null:
		return
	var w := _map.size.x
	var pts := PackedVector2Array()
	var n := _cards.size()
	for id in _cards.keys():
		var tier: int = _cards[id]["tier"]
		var i := tier - 1
		var xs := [0.22, 0.5, 0.78, 0.5]
		var x := w * float(xs[i % 4])
		var y := _map.size.y - 16.0 - ROW * 0.5 - i * ROW
		var b: Control = _cards[id]["button"]
		b.position = (Vector2(x, y) - Vector2(STOP, STOP) * 0.5).floor()
		var lab: Control = _cards[id]["label"]
		lab.size = Vector2(w * 0.4, 56)
		if x < w * 0.4:
			lab.position = Vector2(x + STOP * 0.5 + 16.0, y - 28.0)
			(lab as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		elif x > w * 0.6:
			lab.position = Vector2(x - STOP * 0.5 - 16.0 - lab.size.x, y - 28.0)
			(lab as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		else:
			lab.position = Vector2(x + STOP * 0.5 + 16.0, y - 28.0)
			(lab as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		while pts.size() <= i:
			pts.append(Vector2.ZERO)
		pts[i] = Vector2(x, y)
	_map.points = pts
	_map.unlocked = 0
	for id in _cards.keys():
		if _cards[id]["unlocked"]:
			_map.unlocked = maxi(_map.unlocked, int(_cards[id]["tier"]))
	_map.queue_redraw()
	if n == 0:
		return


func select_tier(id: String) -> bool:
	var m := ModeDefs.get_mode(id)
	if not GameState.is_tier_unlocked(int(m["tier"])):
		Juice.sfx("ui_denied", -4.0)
		return false
	GameState.selected_mode_id = str(m["id"])
	GameState.save_profile()
	Juice.sfx("ui_tap")
	_refresh()
	return true


## One map stop per tier: a zone badge button + its name beside it.
func _tier_stop(mode: Dictionary) -> Control:
	var id := str(mode["id"])
	var tier := int(mode["tier"])
	var unlocked := GameState.is_tier_unlocked(tier)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := _Badge.new()
	b.tier = tier
	b.unlocked = unlocked
	b.cleared = tier <= GameState.best_tier_extracted
	b.boss = tier >= ModeDefs.BOSS_FROM_TIER
	b.ground = ZONE_GROUND[clampi(tier - 1, 0, 9)]
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.custom_minimum_size = Vector2(STOP, STOP)
	b.size = Vector2(STOP, STOP)
	b.mouse_force_pass_scroll_events = true
	b.pressed.connect(func() -> void: select_tier(id))
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_map.add_child(b)
	var nm := UiTheme.head_label(str(mode["display_name"]).to_upper(), UiTheme.T_H2, UiTheme.TEXT if unlocked else UiTheme.TEXT_DIM)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.clip_text = true
	_map.add_child(nm)
	_cards[id] = {"button": b, "label": nm, "unlocked": unlocked, "tier": tier}
	return holder


## Detail card for the selected tier: name, time, one line, the window
## timeline and three number chips.
func _build_detail(mode: Dictionary) -> void:
	for ch in _detail.get_children():
		_detail.remove_child(ch)
		ch.queue_free()
	var p := card(UiTheme.AMBER)
	_detail.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	var tn := UiTheme.pixel_label("T%d" % int(mode["tier"]), UiTheme.PX_L, UiTheme.AMBER)
	tn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(tn)
	var name_l := UiTheme.title_label(str(mode["display_name"]).to_upper(), UiTheme.T_TITLE)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	top.add_child(IconSet.rect("hud_timer", 48))
	var mins := UiTheme.pixel_label("%dm" % int(mode["target_minutes"]), UiTheme.PX_M, UiTheme.TEXT)
	mins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(mins)
	var zn := ZoneDefs.zone(int(mode.get("tier", 1)))
	var zt := str(zn.get("name", "")) if not (zn["twists"] as Array).is_empty() else str(mode.get("blurb", ""))
	var zl := UiTheme.body_label(zt, UiTheme.T_SMALL, UiTheme.TEXT_DIM, false)
	zl.clip_text = true
	zl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(zl)
	## Unlock pacing: how many more extracts open the next tier.
	var top_t := GameState.highest_unlocked_tier()
	var left := GameState.extracts_to_next_tier()
	if int(mode["tier"]) == top_t and left > 0:
		var ul := UiTheme.body_label("Extract %d more time%s here to open %s" % [left, "" if left == 1 else "s",
			str(ModeDefs.tier_mode(top_t + 1).get("display_name", ""))], UiTheme.T_SMALL, UiTheme.AMBER, false)
		ul.clip_text = true
		ul.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(ul)
	var tl := Control.new()
	tl.custom_minimum_size = Vector2(0, 24)
	tl.draw.connect(_draw_timeline.bind(tl, mode))
	v.add_child(tl)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	v.add_child(chips)
	_num_chip(chips, "hud_threat", "%d%%" % int(round(float(mode["enemy_hp"]) * 100.0)), UiTheme.DANGER)
	_num_chip(chips, "cur_scrap", "x%.2f" % float(mode["payout_mult"]), UiTheme.AMBER)
	_num_chip(chips, "hud_loot", "%d%%" % int(round(float(mode["death_keep"]) * 100.0)), UiTheme.TEXT)
	## Dustfall: the Ascension ladder (post-game chase).
	if int(mode["tier"]) >= ModeDefs.EXPOSED_TIERS and GameState.ascension_open() > 0:
		_ascension_row(v, mode)


func _ascension_row(v: VBoxContainer, mode: Dictionary) -> void:
	var lv := clampi(GameState.ascension, 0, GameState.ascension_open())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var t := UiTheme.head_label("ASCENSION", UiTheme.T_H3, UiTheme.AMBER)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	var minus := UiTheme.big_button("-", UiTheme.LINE, 56, 24)
	minus.custom_minimum_size.x = 64
	minus.disabled = lv <= 0
	row.add_child(minus)
	var val := UiTheme.pixel_label("OFF" if lv == 0 else "A%d" % lv, UiTheme.PX_L, UiTheme.DANGER if lv > 0 else UiTheme.TEXT_DIM)
	val.custom_minimum_size.x = 96
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(val)
	var plus := UiTheme.big_button("+", UiTheme.AMBER, 56, 24)
	plus.custom_minimum_size.x = 64
	plus.disabled = lv >= GameState.ascension_open()
	row.add_child(plus)
	minus.pressed.connect(func() -> void:
		GameState.set_ascension(lv - 1)
		Juice.sfx("ui_tab")
		_build_detail(mode))
	plus.pressed.connect(func() -> void:
		GameState.set_ascension(lv + 1)
		Juice.sfx("ui_tab")
		_build_detail(mode))
	var rules: PackedStringArray = []
	for i in range(lv):
		rules.append(str(ModeDefs.ASCENSION[i][3]))
	var pay := ModeDefs.ascension_loot(lv)
	for p in ModeDefs.ascension_pacts(lv):
		pay += float(ZoneDefs.pact(str(p)).get("loot", 0.0))
	var txt := ("Payout +%d%% · " % int(round(pay * 100.0)) + " · ".join(rules)) if lv > 0 else "Extract at A%d to open the next. Best: A%d" % [GameState.ascension_open(), GameState.ascension_cleared]
	var rl := UiTheme.body_label(txt, UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rl)


func _num_chip(parent: Control, icon_id: String, value: String, col: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.plate("inset", 8.0))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	h.add_child(IconSet.rect(icon_id, 48))
	var l := UiTheme.pixel_label(value, UiTheme.PX_M, col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	parent.add_child(p)


func _draw_timeline(c: Control, mode: Dictionary) -> void:
	var total := 0.0
	for p in mode["phases"]:
		total += float(p["duration"])
	var x := 0.0
	var w := c.size.x
	for p in mode["phases"]:
		var pw := float(p["duration"]) / total * w
		var col := Color(0.45, 0.95, 0.55) if bool(p["extract_open"]) else Color(0.55, 0.4, 0.25)
		if bool(p.get("is_last", false)):
			col = Color(0.95, 0.4, 0.3)
		c.draw_rect(Rect2(x + 1, 4, pw - 2, c.size.y - 8), col)
		x += pw

func _refresh() -> void:
	for id in _cards.keys():
		var b: _Badge = _cards[id]["button"]
		b.selected = id == GameState.selected_mode_id
		b.queue_redraw()
		var lab: Label = _cards[id]["label"]
		lab.add_theme_color_override("font_color", UiTheme.AMBER if b.selected else (UiTheme.TEXT if _cards[id]["unlocked"] else UiTheme.TEXT_DIM))
	_build_detail(GameState.get_mode())
	_fast.text = "Dev: quick-test timers %s" % ("ON (12%)" if GameState.fast_timers else "OFF")


## The trail: dashed brass between stops, dim past the last unlocked one.
class _Map extends Control:
	var points := PackedVector2Array()
	var unlocked: int = 1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		for i in range(points.size() - 1):
			var a := points[i]
			var b := points[i + 1]
			var lit := i + 2 <= unlocked
			var col := Color("b88a33") if lit else Color("3a3436")
			var d := b - a
			var n := int(d.length() / 16.0)
			for k in range(n):
				if k % 2 == 1:
					continue
				var p0 := a + d * (float(k) / n)
				var p1 := a + d * (float(k + 1) / n)
				draw_line(p0, p1, Color("140c0e"), 10.0)
				draw_line(p0, p1, col, 6.0)


## Zone badge: worn steel ring, the zone's ground inside, tier number in
## the pixel font; padlock / tick / boss skull pips.
class _Badge extends Button:
	var tier: int = 1
	var unlocked: bool = true
	var cleared: bool = false
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
			draw_circle(c, r, Color(1.0, 0.75, 0.25, 0.25 + 0.2 * k))
		draw_circle(c, r - 4.0, Color("140c0e"))
		draw_circle(c, r - 6.0, Color("ffc040") if selected else (Color("5e6d7a") if unlocked else Color("36424f")))
		draw_circle(c, r - 12.0, Color("140c0e"))
		var g0 := Color(str(ground[1])) if unlocked else Color("1f1a1d")
		var g1 := Color(str(ground[3])) if unlocked else Color("3a3436")
		draw_circle(c, r - 14.0, g0)
		## a few speck clusters lit top-left
		for p in [Vector2(-14, -10), Vector2(10, 12), Vector2(16, -16), Vector2(-8, 16)]:
			draw_rect(Rect2((c + p).floor(), Vector2(4, 4)), g1)
		var f: Font = UiTheme.font_pixel
		if f:
			var txt := str(tier)
			var fs := 24
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := (c + Vector2(-tw * 0.5, fs * 0.5)).floor()
			draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color("140c0e"))
			draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffc040") if unlocked else Color("5d5654"))
		var badge := ""
		if not unlocked:
			badge = "camp_stash"
		elif cleared:
			badge = "tab_daily"
		elif boss:
			badge = "hud_kills"
		if badge != "":
			var t := IconSet.tex(badge, false)
			if t:
				draw_texture_rect(t, Rect2(Vector2(size.x - 40, size.y - 40), Vector2(48, 48)), false)
