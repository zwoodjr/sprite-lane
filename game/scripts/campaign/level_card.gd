extends CanvasLayer

## Campaign level cards: the intro (chapter, number, title, who you play as,
## first objective, BEGIN), the outro (EXTRACTED: time, scrap, rewards, who
## joined, NEXT / MAP) and the fail card (DOWN IN THE DUST: RETRY / MAP).
## Pauses the run while up. Emits `chosen` with "begin" | "next" | "map" | "retry".

signal chosen(action: String)

const INK := Color("140c0e")
var _root: Control
var _box: VBoxContainer
var auto: String = ""


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _open(bg_alpha: float) -> VBoxContainer:
	for c in get_children():
		c.queue_free()
	visible = true
	get_tree().paused = true
	TouchInput.clear_sticks()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(INK, bg_alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var m := MobileLayout.control_safe_margin()
	var frame := MarginContainer.new()
	frame.position = m.position + Vector2(24, 24)
	frame.size = m.size - Vector2(48, 48)
	_root.add_child(frame)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 16)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	frame.add_child(_box)
	_root.modulate.a = 0.0
	var tw := _root.create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.2)
	return _box


func close() -> void:
	visible = false
	for c in get_children():
		c.queue_free()
	get_tree().paused = false


func _center(c: Control) -> Control:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc


func _spacer(h: float, expand: bool = false) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	if expand:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


func _head(lv: Dictionary) -> void:
	var ch: Dictionary = lv.get("chapter", {})
	var tag := UiTheme.head_label("%s  ·  %s" % [str(ch.get("tag", "")), str(ch.get("name", "")).to_upper()], UiTheme.T_H3, UiTheme.AMBER)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(tag)
	var num := UiTheme.pixel_label(CampaignDefs.number_tag(str(lv.get("id", ""))), UiTheme.PX_L, UiTheme.AMBER)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(num)
	var t := UiTheme.title_label(str(lv.get("title", "")).to_upper(), UiTheme.T_TITLE_XL, UiTheme.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)


func _portrait(id: String, px: float = 192.0, dim: bool = false) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px + 12.0, px + 12.0)
	holder.draw.connect(func() -> void:
		holder.draw_rect(Rect2(Vector2.ZERO, holder.custom_minimum_size), INK)
		holder.draw_rect(Rect2(Vector2(2, 2), holder.custom_minimum_size - Vector2(4, 4)), Color("b88a33") if not dim else Color("5e6d7a"), false, 2.0))
	var tr := TextureRect.new()
	var pp := CampaignDefs.portrait_path(id)
	if pp != "":
		tr.texture = load(pp)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.position = Vector2(6, 6)
	tr.size = Vector2(px, px)
	holder.add_child(tr)
	return holder


func show_intro(lv: Dictionary, hero: String, pet: String, objective: String) -> void:
	_open(0.92)
	_box.add_child(_spacer(0, true))
	_head(lv)
	var sub := UiTheme.body_label(str(lv.get("subtitle", "")), UiTheme.T_BODY, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(sub)
	_box.add_child(_spacer(8))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(_portrait(CampaignDefs.hero_speaker(hero)))
	if pet != "":
		var pv := VBoxContainer.new()
		pv.alignment = BoxContainer.ALIGNMENT_END
		pv.add_child(_portrait(pet, 96.0))
		row.add_child(pv)
	_box.add_child(row)
	var who := UiTheme.head_label("AS %s" % str(CharacterDefs.get_character(hero).get("display_name", hero)).to_upper(), UiTheme.T_H2, UiTheme.TEXT)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(who)
	if objective != "":
		var op := PanelContainer.new()
		op.add_theme_stylebox_override("panel", UiTheme.plate("inset", 14.0))
		var oh := HBoxContainer.new()
		oh.add_theme_constant_override("separation", 12)
		op.add_child(oh)
		var ol := UiTheme.pixel_label("GOAL", UiTheme.PX_S, UiTheme.TEAL)
		ol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		oh.add_child(ol)
		var ot := UiTheme.head_label(objective, UiTheme.T_H3, UiTheme.TEXT)
		ot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		oh.add_child(ot)
		_box.add_child(op)
	_box.add_child(_spacer(0, true))
	var go := UiTheme.big_button("BEGIN", UiTheme.AMBER, 80, 32)
	go.pressed.connect(func() -> void: _choose("begin"))
	_box.add_child(go)
	_maybe_auto("begin")


func show_outro(lv: Dictionary, res: Dictionary) -> void:
	_open(0.92)
	_box.add_child(_spacer(0, true))
	_head(lv)
	var ex := UiTheme.title_label("EXTRACTED", UiTheme.T_TITLE, UiTheme.TEAL)
	ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(ex)
	var nums := HBoxContainer.new()
	nums.alignment = BoxContainer.ALIGNMENT_CENTER
	nums.add_theme_constant_override("separation", 24)
	for pair in [["hud_timer", _fmt(float(res.get("time", 0.0))), UiTheme.TEXT], ["cur_scrap", "+%d" % int(res.get("scrap", 0)), UiTheme.AMBER]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(IconSet.rect(str(pair[0]), 48))
		var l := UiTheme.pixel_label(str(pair[1]), UiTheme.PX_M, pair[2])
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		nums.add_child(h)
	_box.add_child(nums)
	var joined: Array = res.get("joined", [])
	var dogs: Array = res.get("pets", [])
	if not joined.is_empty() or not dogs.is_empty():
		var jr := HBoxContainer.new()
		jr.alignment = BoxContainer.ALIGNMENT_CENTER
		jr.add_theme_constant_override("separation", 12)
		for h2 in joined:
			jr.add_child(_portrait(CampaignDefs.hero_speaker(str(h2)), 128.0))
		for p in dogs:
			jr.add_child(_portrait(str(p), 96.0))
		_box.add_child(jr)
	for line in res.get("lines", PackedStringArray()):
		if str(line).begins_with("+") and str(line).ends_with("scrap"):
			continue
		var l2 := UiTheme.head_label(str(line), UiTheme.T_H3, UiTheme.TEXT)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(l2)
	_box.add_child(_spacer(0, true))
	var nxt := str(res.get("next", ""))
	if nxt != "" and CampaignDefs.is_playable(nxt):
		var nb := UiTheme.big_button("NEXT: %s" % str(CampaignDefs.level(nxt).get("title", "")).to_upper(), UiTheme.AMBER, 80, 28)
		nb.pressed.connect(func() -> void: _choose("next"))
		_box.add_child(nb)
	var mb := UiTheme.big_button("CAMPAIGN MAP", UiTheme.LINE, 64, 20)
	mb.pressed.connect(func() -> void: _choose("map"))
	_box.add_child(mb)
	_maybe_auto("map")


func show_fail(lv: Dictionary, reason: String) -> void:
	_open(0.88)
	_box.add_child(_spacer(0, true))
	_head(lv)
	var t := UiTheme.title_label("DOWN IN THE DUST", UiTheme.T_TITLE, UiTheme.DANGER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	var r := UiTheme.body_label(reason, UiTheme.T_BODY, UiTheme.TEXT)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(r)
	var keep := UiTheme.body_label("Nothing lost. Your gear and pack are safe at the hangar.", UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	keep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(keep)
	_box.add_child(_spacer(0, true))
	var rb := UiTheme.big_button("RETRY", UiTheme.AMBER, 80, 32)
	rb.pressed.connect(func() -> void: _choose("retry"))
	_box.add_child(rb)
	var mb := UiTheme.big_button("CAMPAIGN MAP", UiTheme.LINE, 64, 20)
	mb.pressed.connect(func() -> void: _choose("map"))
	_box.add_child(mb)
	_maybe_auto("map")


func _choose(a: String) -> void:
	Juice.sfx("ui_tap")
	close()
	chosen.emit(a)


## Tests / bots: take the given action after a moment.
func _maybe_auto(a: String) -> void:
	if auto == "" or (a != "begin" and not GameState.campaign_autoplay_exit):
		return
	var act := a if auto == "default" else auto
	await get_tree().create_timer(0.3, true, false, true).timeout
	if visible:
		_choose(act)


func _fmt(s: float) -> String:
	var n := int(s)
	return "%d:%02d" % [n / 60, n % 60]
