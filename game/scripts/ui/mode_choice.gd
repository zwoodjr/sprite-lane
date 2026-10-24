extends "res://scripts/ui/menu_base.gd"

## PLAY -> two ways in: CAMPAIGN (Act One, the story) or WANDER (the endless
## extraction runs, exactly as before). Two big riveted cards; tap one.

func build(c: VBoxContainer) -> void:
	c.add_theme_constant_override("separation", 24)
	c.add_child(header("PLAY", GameState.go_main_menu))
	c.add_child(_campaign_card())
	c.add_child(_wander_card())


func _card(kind: String, cb: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UiTheme.plate(kind, 24.0))
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(func() -> void:
		Juice.sfx("ui_tap")
		UiTheme.press_anim(p)
		cb.call())
	p.set_meta("tap", b)
	return p


func _portrait(path: String, px: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px + 12.0, px + 12.0)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.draw.connect(func() -> void:
		holder.draw_rect(Rect2(Vector2.ZERO, holder.custom_minimum_size), UiTheme.INK)
		holder.draw_rect(Rect2(Vector2(2, 2), holder.custom_minimum_size - Vector2(4, 4)), UiTheme.BRASS, false, 2.0))
	var tr := TextureRect.new()
	if ResourceLoader.exists(path):
		tr.texture = load(path)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.position = Vector2(6, 6)
	tr.size = Vector2(px, px)
	holder.add_child(tr)
	return holder


func _campaign_card() -> Control:
	var p := _card("panel_hi", GameState.go_campaign_map)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	var nxt := GameState.campaign_next_level()
	var lv := CampaignDefs.level(nxt)
	var hero := GameState.campaign_pick_for(nxt) if CampaignDefs.is_playable(nxt) else CharacterDefs.HELM_WISP_ID
	top.add_child(_portrait(CampaignDefs.portrait_path(CampaignDefs.hero_speaker(hero)), 192.0))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(tv)
	var chip := UiTheme.pixel_label("STORY", UiTheme.PX_S, UiTheme.TEAL)
	tv.add_child(chip)
	var t1 := UiTheme.title_label("CAMPAIGN", UiTheme.T_TITLE_XL, UiTheme.AMBER)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(t1)
	tv.add_child(UiTheme.head_label("ACT ONE  ·  THE LONG DUST", UiTheme.T_H3, UiTheme.TEXT))
	var done := GameState.campaign_done_count()
	var line := "Start the story" if done == 0 else ("Act One complete" if done >= CampaignDefs.ORDER.size() else "Next: %s %s" % [CampaignDefs.number_tag(nxt), str(lv.get("title", ""))])
	var nl := UiTheme.body_label(line, UiTheme.T_BODY, UiTheme.TEXT_DIM, false)
	nl.clip_text = true
	tv.add_child(nl)
	## Progress: one pip per level, and Helm's plane.
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	v.add_child(pr)
	pr.add_child(IconSet.rect("tab_camp", 48))
	var pl := UiTheme.pixel_label("PLANE " + GameState.plane_progress_text(), UiTheme.PX_M, UiTheme.AMBER)
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(pl)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pr.add_child(sp)
	var dl := UiTheme.pixel_label("%d/%d" % [done, CampaignDefs.ORDER.size()], UiTheme.PX_M, UiTheme.TEXT)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(dl)
	var pips := _Pips.new()
	pips.total = CampaignDefs.ORDER.size()
	pips.done = done
	pips.custom_minimum_size = Vector2(0, 16)
	v.add_child(pips)
	var tap: Button = p.get_meta("tap")
	p.add_child(tap)
	return p


func _wander_card() -> Control:
	var p := _card("panel_steel", GameState.go_mode_select)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	top.add_child(_portrait(CampaignDefs.portrait_path(CampaignDefs.hero_speaker(GameState.selected_character_id)), 192.0))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(tv)
	tv.add_child(UiTheme.pixel_label("ENDLESS", UiTheme.PX_S, UiTheme.TEAL))
	var t2 := UiTheme.title_label("WANDER", UiTheme.T_TITLE_XL, UiTheme.TEXT)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(t2)
	tv.add_child(UiTheme.head_label("DROP IN.  GRAB IT.  GET OUT.", UiTheme.T_H3, UiTheme.TEXT))
	var tier := ModeDefs.tier_mode(GameState.highest_unlocked_tier())
	var tl := UiTheme.body_label("Deepest Dust open: %s" % str(tier.get("display_name", "")), UiTheme.T_BODY, UiTheme.TEXT_DIM, false)
	tl.clip_text = true
	tv.add_child(tl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	for pair in [["cur_scrap", str(GameState.account_scrap), UiTheme.AMBER], ["cur_extract", str(GameState.successful_extracts), UiTheme.TEXT]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(IconSet.rect(str(pair[0]), 48))
		var l := UiTheme.pixel_label(str(pair[1]), UiTheme.PX_M, pair[2])
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		row.add_child(h)
	var tap: Button = p.get_meta("tap")
	p.add_child(tap)
	return p


## One pip per level: DUST 3 done, STEEL 1 to go (INK edge).
class _Pips extends Control:
	var total: int = 14
	var done: int = 0

	func _draw() -> void:
		var gap := 6.0
		var w := (size.x - gap * (total - 1)) / float(total)
		for i in range(total):
			var r := Rect2(floorf(i * (w + gap)), 0, floorf(w), size.y)
			draw_rect(r, Color("140c0e"))
			draw_rect(r.grow(-2.0), Color("ffc040") if i < done else Color("36424f"))
