extends "res://scripts/ui/menu_base.gd"

## Run History: the last 50 Wander / Daily runs with simple totals (RUNS), and
## the Daily Run board — the counted score per day for the last 30 days (DAILY).
## Reached from the logbook, the hangar and the mode select's daily card.

const TABS := ["runs", "daily"]
const TAB_LABEL := {"runs": "RUNS", "daily": "DAILY BOARD"}

var _tab: String = "runs"
var _tab_btns: Dictionary = {}
var _scroll: ScrollContainer
var _list: VBoxContainer


func build(c: VBoxContainer) -> void:
	c.add_theme_constant_override("separation", 16)
	c.add_child(header("RUN HISTORY", _back))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	c.add_child(tabs)
	for t in TABS:
		var b := UiTheme.big_button(TAB_LABEL[t], UiTheme.LINE, 64, 20)
		b.name = "Tab_" + str(t)
		b.custom_minimum_size.x = 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_tab.bind(t))
		tabs.add_child(b)
		_tab_btns[t] = b
	_scroll = ScrollContainer.new()
	_scroll.name = "HistoryScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 18
	c.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)
	var back := UiTheme.big_button("BACK", UiTheme.AMBER, 64, 20)
	back.pressed.connect(_back)
	c.add_child(back)
	show_tab(GameState.history_tab if GameState.history_tab in TABS else "runs")


func _back() -> void:
	match GameState.history_from:
		"mode_select":
			GameState.go_mode_select()
		"hangar":
			GameState.go_hangar()
		_:
			GameState.go_logbook()


func show_tab(t: String) -> void:
	if not t in TABS:
		return
	_tab = t
	GameState.history_tab = t
	for k in _tab_btns.keys():
		UiTheme.skin_button(_tab_btns[k] as Button, UiTheme.AMBER if str(k) == t else UiTheme.LINE, 12.0)
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	if t == "runs":
		_build_runs()
	else:
		_build_daily()
	_scroll.scroll_vertical = 0


## --- RUNS ------------------------------------------------------------------

func _build_runs() -> void:
	var tot := GameState.history_totals()
	var p := card(UiTheme.AMBER)
	p.name = "Totals"
	_list.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	v.add_child(chips)
	_stat_chip(chips, "RUNS", str(int(tot["runs"])), UiTheme.TEXT)
	_stat_chip(chips, "EXTRACTED", str(int(tot["extracts"])), UiTheme.TEAL)
	_stat_chip(chips, "RATE", "%d%%" % int(round(float(tot["rate"]) * 100.0)), UiTheme.AMBER)
	var best: Dictionary = tot["best_by_hero"]
	if not best.is_empty():
		v.add_child(UiTheme.head_label("BEST RUN PER SURVIVOR", UiTheme.T_H3, UiTheme.TEXT_DIM))
		for hid in CharacterDefs.PLAYABLE_IDS:
			if not best.has(hid):
				continue
			var e: Dictionary = best[hid]
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			v.add_child(h)
			var nm := UiTheme.body_label(_hero_name(str(hid)), UiTheme.T_SMALL, UiTheme.TEXT, false)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.clip_text = true
			h.add_child(nm)
			var what := ("%d scrap · %s" % [int(e.get("scrap", 0)), _mode_name(e)]) if bool(e.get("extracted", false)) else "no extract yet"
			h.add_child(UiTheme.body_label(what, UiTheme.T_SMALL, UiTheme.AMBER if bool(e.get("extracted", false)) else UiTheme.TEXT_DIM, false))
	if GameState.run_history.is_empty():
		_list.add_child(_note("No runs logged yet. Every Wander and Daily run lands here (the last %d)." % GameState.RUN_HISTORY_MAX))
		return
	_list.add_child(_note("Last %d runs, newest first." % GameState.RUN_HISTORY_MAX))
	for e in GameState.run_history:
		_list.add_child(_run_row(e))


func _run_row(e: Dictionary) -> Control:
	var ok := bool(e.get("extracted", false))
	var p := card(UiTheme.LINE)
	p.name = "RunRow"
	p.set_meta("history_row", "run")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var head := "%s · %s" % [str(e.get("date", "")).substr(5), _mode_name(e).to_upper()]
	var hl := UiTheme.head_label(head, UiTheme.T_H3, UiTheme.AMBER if str(e.get("kind", "")) == "daily" else UiTheme.TEXT)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.clip_text = true
	top.add_child(hl)
	top.add_child(UiTheme.chip("EXTRACTED" if ok else "DOWN", UiTheme.TEAL if ok else UiTheme.DANGER))
	var pet := str(PetDefs.get_pet(str(e.get("pet", ""))).get("name", "")) if str(e.get("pet", "")) != "" else ""
	var who := _hero_name(str(e.get("hero", ""))) + ((" + " + pet) if pet != "" else "")
	var stats := "%s · %s · %d kills · %d scrap" % [who, DailyDefs.fmt_time(float(e.get("seconds", 0))), int(e.get("kills", 0)), int(e.get("scrap", 0))]
	if str(e.get("kind", "")) == "daily":
		stats += " · score %d" % int(e.get("score", 0))
	var sl := UiTheme.body_label(stats, UiTheme.T_SMALL, UiTheme.TEXT)
	v.add_child(sl)
	var bi := str(e.get("best_item", ""))
	if bi != "":
		var rar := str(e.get("best_rarity", "common"))
		v.add_child(UiTheme.body_label("Best find: %s (%s)" % [bi, str(GearDefs.RARITY_NAME.get(rar, rar))], UiTheme.T_SMALL, GearDefs.RARITY_COLOR.get(rar, UiTheme.TEXT)))
	if not ok:
		v.add_child(UiTheme.body_label("Cause: " + str(e.get("cause", "Went down in the dust")), UiTheme.T_SMALL, UiTheme.DANGER))
	var mods: Array = e.get("mods", [])
	if not mods.is_empty():
		v.add_child(UiTheme.body_label("Dust: " + ", ".join(PackedStringArray(mods.map(func(m: Variant) -> String: return DustModDefs.mod_name(str(m))))),
			UiTheme.T_SMALL, UiTheme.TEXT_DIM))
	return p


## --- DAILY BOARD -----------------------------------------------------------

func _build_daily() -> void:
	var today := GameState.today()
	var e := GameState.daily_entry(today)
	var p := card(UiTheme.AMBER)
	p.name = "DailyToday"
	_list.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := UiTheme.head_label("TODAY · " + today, UiTheme.T_H2, UiTheme.AMBER)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UiTheme.pixel_label(str(int(e.get("score", 0))) if not e.is_empty() else "--", UiTheme.PX_L, UiTheme.AMBER))
	v.add_child(UiTheme.body_label("%s · %s · first finish counts" % [_hero_name(DailyDefs.hero_for(today)),
		str(ModeDefs.get_mode(DailyDefs.TIER_ID)["display_name"])], UiTheme.T_SMALL, UiTheme.TEXT))
	v.add_child(UiTheme.body_label("Score = scrap hauled + %d per kill + %d per second survived. 0 if you go down." % [
		DailyDefs.KILL_POINTS, DailyDefs.TIME_POINTS], UiTheme.T_SMALL, UiTheme.TEXT_DIM))
	## Best of the last 30 days.
	var best_d := ""
	var best_s := -1
	var played := 0
	for k in GameState.daily_runs.keys():
		played += 1
		if int(GameState.daily_runs[k].get("score", 0)) > best_s:
			best_s = int(GameState.daily_runs[k].get("score", 0))
			best_d = str(k)
	var sum := HBoxContainer.new()
	sum.add_theme_constant_override("separation", 8)
	_list.add_child(sum)
	_stat_chip(sum, "DAYS PLAYED", str(played), UiTheme.TEXT)
	_stat_chip(sum, "BEST DAY", str(maxi(best_s, 0)), UiTheme.AMBER)
	_list.add_child(_note("Last %d days. Online boards come later (Game Center)." % DailyDefs.BOARD_DAYS))
	## The days sit on a dark plate so dim "not played" rows stay readable.
	var board := card(UiTheme.LINE, Color(0.06, 0.05, 0.05, 0.96))
	board.name = "DailyBoardList"
	_list.add_child(board)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	board.add_child(bv)
	for i in range(DailyDefs.BOARD_DAYS):
		var d := DailyDefs.date_add(today, -i)
		bv.add_child(_day_row(d, GameState.daily_entry(d), d == best_d and best_s > 0))


func _day_row(date: String, e: Dictionary, best: bool) -> Control:
	var h := HBoxContainer.new()
	h.name = "DayRow"
	h.set_meta("history_row", "day")
	h.add_theme_constant_override("separation", 8)
	var dl := UiTheme.pixel_label(date.substr(5), UiTheme.PX_S, UiTheme.AMBER if best else UiTheme.TEXT_DIM)
	dl.custom_minimum_size.x = 96
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dl)
	if e.is_empty():
		var nl := UiTheme.body_label("not played", UiTheme.T_SMALL, UiTheme.TEXT_DIM, false)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		return h
	var info := "%s · %s" % [_hero_name(str(e.get("hero", ""))), "extracted" if bool(e.get("extracted", false)) else "went down"]
	if int(e.get("attempts", 1)) > 1:
		info += " · %d tries" % int(e.get("attempts", 1))
	var il := UiTheme.body_label(info, UiTheme.T_SMALL, UiTheme.TEXT, false)
	il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	il.clip_text = true
	il.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(il)
	var sc := UiTheme.pixel_label(str(int(e.get("score", 0))), UiTheme.PX_M, UiTheme.AMBER if best else UiTheme.TEXT)
	sc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sc)
	return h


## --- bits ------------------------------------------------------------------

func _stat_chip(parent: Control, label: String, value: String, col: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.plate("inset", 8.0))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var n := UiTheme.pixel_label(value, UiTheme.PX_L, col)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var l := UiTheme.head_label(label, UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	parent.add_child(p)


func _note(text: String) -> Label:
	return UiTheme.body_label(text, UiTheme.T_SMALL, UiTheme.TEXT_DIM)


func _hero_name(id: String) -> String:
	if not CharacterDefs.is_playable(id):
		return id.capitalize()
	return str(CharacterDefs.get_character(id).get("display_name", id))


func _mode_name(e: Dictionary) -> String:
	if str(e.get("kind", "")) == "daily":
		return "Daily"
	return str(ModeDefs.get_mode(str(e.get("mode", "haze"))).get("display_name", ""))
