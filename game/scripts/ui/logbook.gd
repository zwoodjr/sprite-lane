extends "res://scripts/ui/menu_base.gd"

## Logbook (brief Part 8): DAILY quests (claim scrap), survivor STORIES
## (5 chapters each, ending in their named Legendary), camp MILESTONES.

const TABS := ["daily", "stories", "milestones", "notes"]
const TAB_LABEL := {"daily": "DAILY", "stories": "STORIES", "milestones": "GOALS", "notes": "NOTES"}
const TAB_ICON := {"daily": "tab_daily", "stories": "tab_stories", "milestones": "tab_goals", "notes": "tab_notes"}

var _tab: String = "daily"
var _tab_btns: Dictionary = {}
var _scroll: ScrollContainer
var _list: VBoxContainer
var _scrap: Label


func build(c: VBoxContainer) -> void:
	c.add_theme_constant_override("separation", 16)
	var top := header("LOGBOOK", GameState.go_hangar)
	top.add_child(IconSet.rect("cur_scrap", 48))
	_scrap = UiTheme.pixel_label("", UiTheme.PX_M, UiTheme.AMBER)
	_scrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_scrap)
	c.add_child(top)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	c.add_child(tabs)
	for t in TABS:
		var b := UiTheme.big_button(TAB_LABEL[t], UiTheme.LINE, 64, 20)
		b.icon = IconSet.tex(str(TAB_ICON[t]), false)
		b.custom_minimum_size.x = 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_tab.bind(t))
		tabs.add_child(b)
		_tab_btns[t] = b
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 18
	c.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)
	var back := UiTheme.big_button("BACK TO HANGAR", UiTheme.AMBER, 64, 20)
	back.pressed.connect(GameState.go_hangar)
	c.add_child(back)
	show_tab("daily")


func show_tab(t: String) -> void:
	if not t in TABS:
		return
	_tab = t
	for k in _tab_btns.keys():
		var on := str(k) == t
		UiTheme.skin_button(_tab_btns[k] as Button, UiTheme.AMBER if on else UiTheme.LINE, 12.0)
	_rebuild()


func _rebuild() -> void:
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	_scrap.text = "%d" % GameState.account_scrap
	match _tab:
		"daily":
			_list.add_child(_note("Three jobs a day. New ones tomorrow."))
			var qs := GameState.daily_quests()
			for i in range(qs.size()):
				_list.add_child(_daily_row(qs[i], i))
		"stories":
			_list.add_child(_note("Play a survivor to move their story on. Chapter 5 earns their named Legendary."))
			## Only survivors the player can actually field.
			var ids: Array = (QuestDefs.unlocked_context()["heroes"] as Array).duplicate()
			ids.erase(GameState.selected_character_id)
			ids.push_front(GameState.selected_character_id)
			for h in ids:
				_list.add_child(_story_card(str(h)))
		"milestones":
			_list.add_child(_note("Long goals. Each one changes the hangar."))
			for m in QuestDefs.MILESTONES:
				_list.add_child(_milestone_row(m))
		"notes":
			_build_notes()
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	_list.add_child(pad)
	_scroll.scroll_vertical = 0


func _note(t: String) -> Label:
	return UiTheme.body_label(t, UiTheme.T_SMALL, UiTheme.TEXT_DIM)


func _bar(have: int, need: int) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.max_value = maxi(1, need)
	pb.value = mini(have, need)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 12)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb


func _daily_row(q: Dictionary, i: int) -> PanelContainer:
	var done := int(q.get("have", 0)) >= int(q.get("need", 1))
	var claimed := bool(q.get("claimed", false))
	var p := card(UiTheme.TEAL if done and not claimed else UiTheme.LINE, Color(0.11, 0.08, 0.055, 0.92))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(v)
	v.add_child(UiTheme.body_label(str(q.get("label", "")), 18, UiTheme.AMBER))
	v.add_child(UiTheme.body_label("%d / %d  ·  %d scrap" % [int(q.get("have", 0)), int(q.get("need", 1)), int(q.get("reward", 0))], 14, UiTheme.TEXT_DIM, false))
	v.add_child(_bar(int(q.get("have", 0)), int(q.get("need", 1))))
	var b := UiTheme.big_button("DONE" if claimed else "CLAIM", UiTheme.TEAL if done and not claimed else UiTheme.LINE, 56, 17)
	b.custom_minimum_size.x = 110
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = claimed or not done
	b.pressed.connect(func() -> void:
		if claim(i) > 0:
			Juice.sfx("ui_purchase"))
	h.add_child(b)
	return p


func claim(i: int) -> int:
	var r := GameState.claim_daily(i)
	_rebuild()
	return r


func _story_card(hero: String) -> PanelContainer:
	var story := QuestDefs.story(hero)
	var st := GameState.story_state(hero)
	var step := int(st["step"])
	var total := QuestDefs.STORY_STEPS.size()
	var mine := hero == GameState.selected_character_id
	var p := card(UiTheme.AMBER if mine else UiTheme.LINE, Color(0.11, 0.08, 0.055, 0.92))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(v)
	var hname := str(CharacterDefs.get_character(hero).get("display_name", hero))
	v.add_child(UiTheme.body_label("%s — %s" % [hname, str(story.get("title", ""))], 19, UiTheme.AMBER))
	v.add_child(UiTheme.body_label("Chapter %d / %d" % [mini(step + 1, total), total] if step < total else "Story complete", 14, UiTheme.TEAL, false))
	var lore: Array = story.get("lore", [])
	for i in range(mini(step, lore.size())):
		v.add_child(UiTheme.body_label("\"%s\"" % str(lore[i]), 14, UiTheme.TEXT))
	if step < total:
		var sd: Dictionary = QuestDefs.STORY_STEPS[step]
		var reward := "%d scrap" % int(sd.get("reward", 0)) if step < total - 1 else "Legendary: %s" % str(GearDefs.LEGENDARIES[str(story["legendary"])]["name"])
		v.add_child(UiTheme.body_label("Next: %s as %s  ·  %s" % [str(sd["label"]), hname, reward], 14, UiTheme.TEXT_DIM))
		v.add_child(_bar(int(st["have"]), int(sd["need"])))
	return p


func _milestone_row(m: Dictionary) -> PanelContainer:
	var done := bool(GameState.milestones.get(str(m["id"]), false))
	var p := card(UiTheme.TEAL if done else UiTheme.LINE, Color(0.11, 0.08, 0.055, 0.92))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(v)
	v.add_child(UiTheme.body_label(("[x] " if done else "") + str(m["name"]), 18, UiTheme.TEAL if done else UiTheme.AMBER))
	var cz := str(m.get("cosmetic", ""))
	v.add_child(UiTheme.body_label("%s  ·  %s" % [str(m["desc"]), ("Hangar: " + cz) if cz != "" else "Trophy over the door"], 14, UiTheme.TEXT_DIM))
	var prog := GameState.milestone_progress(str(m["id"]))
	v.add_child(_bar(prog, int(m["need"])))
	return p


## =========================================================================
## Quill's Field Notes (Depth E3): bestiary + hidden lore pages.

func _build_notes() -> void:
	_list.add_child(_note("Quill's notebook. Kills of each creature fill its page: %d to study it, %d to find its weak spot (+10%% damage), %d to master it (+20%%)." % [
		int(BestiaryDefs.THRESHOLDS[0]), int(BestiaryDefs.THRESHOLDS[1]), int(BestiaryDefs.THRESHOLDS[2])]))
	var kinds: Array = []
	for k in EnemyDefs.all_kinds():
		kinds.append(str(k["id"]))
	## Known creatures first, most-killed first.
	kinds.sort_custom(func(a: String, b: String) -> bool: return GameState.bestiary_kills(a) > GameState.bestiary_kills(b))
	for k in kinds:
		_list.add_child(_beast_row(str(k)))
	_list.add_child(UiTheme.body_label("LORE PAGES  %d / %d" % [GameState.lore_pages.size(), BestiaryDefs.PAGES.size()], 18, UiTheme.AMBER))
	for p in BestiaryDefs.PAGES:
		_list.add_child(_page_row(p))


func beast_count() -> int:
	return EnemyDefs.all_kinds().size()


func _beast_icon(kind: String) -> Texture2D:
	var def := EnemyDefs.get_kind(kind)
	var path := str(def.get("anim", "")) + "_idle.png"
	if not ResourceLoader.exists(path):
		return null
	var strip: Texture2D = load(path)
	var at := AtlasTexture.new()
	at.atlas = strip
	var h := float(strip.get_height())
	at.region = Rect2(h * 0.1, h * 0.1, h * 0.8, h * 0.8)
	return at


func _beast_row(kind: String) -> PanelContainer:
	var n := GameState.bestiary_kills(kind)
	var st := BestiaryDefs.stage_for(n)
	var p := card(UiTheme.AMBER if st >= 3 else UiTheme.LINE, Color(0.11, 0.08, 0.055, 0.92))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(h)
	var ic := TextureRect.new()
	ic.texture = _beast_icon(kind)
	ic.custom_minimum_size = Vector2(72, 72)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if n <= 0:
		ic.modulate = Color(0.05, 0.04, 0.04, 0.85)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(v)
	var nm := str(EnemyDefs.get_kind(kind).get("display_name", kind)) if n > 0 else "???"
	v.add_child(UiTheme.body_label("%s  ·  %d kills  ·  %s" % [nm, n, str(BestiaryDefs.STAGE_NAME[st])], 17, UiTheme.AMBER if n > 0 else UiTheme.TEXT_DIM, false))
	var nx := BestiaryDefs.next_threshold(n)
	if nx > 0:
		v.add_child(_bar(n, nx))
	var notes: Array = BestiaryDefs.NOTES.get(kind, ["", ""])
	if st >= 1:
		v.add_child(UiTheme.body_label(str(notes[0]), 14, UiTheme.TEXT))
	else:
		v.add_child(UiTheme.body_label("Kill %d to study it." % int(BestiaryDefs.THRESHOLDS[0]), 13, UiTheme.TEXT_DIM))
	if st >= 2:
		v.add_child(UiTheme.body_label("Weak spot: %s  (+%d%% damage)" % [str(notes[1]), int(round(BestiaryDefs.damage_bonus(n) * 100.0))], 14, UiTheme.TEAL))
	return p


func _page_row(pg: Dictionary) -> PanelContainer:
	var found := GameState.lore_pages.has(str(pg["id"]))
	var p := card(UiTheme.LINE, Color(0.11, 0.08, 0.055, 0.92))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(h)
	var ic := TextureRect.new()
	if ResourceLoader.exists(BestiaryDefs.PAGE_ICON):
		ic.texture = load(BestiaryDefs.PAGE_ICON)
	ic.custom_minimum_size = Vector2(48, 48)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.modulate = Color.WHITE if found else Color(0.3, 0.28, 0.26, 0.8)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(v)
	v.add_child(UiTheme.body_label(str(pg["title"]) if found else "Torn page", 17, UiTheme.AMBER if found else UiTheme.TEXT_DIM, false))
	v.add_child(UiTheme.body_label(str(pg["text"]) if found else "Somewhere out in the Dust. Look for a page fluttering on the ground.", 14, UiTheme.TEXT if found else UiTheme.TEXT_DIM))
	return p
