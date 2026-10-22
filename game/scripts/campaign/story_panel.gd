extends CanvasLayer

## Talking-portrait story scenes and Helm's radio.
##
## play(lines) pauses the run and shows a bottom plate with the speaker's
## painted portrait above it (left / right slots; the one talking is lit, the
## other dims). Text types out; tap = finish the line, tap again = next. SKIP
## runs to the next choice (or the end). Line forms:
##   ["rook", "Text."]                 a line ({hero} = the hero's name)
##   ["helm", "Text.", "radio"]        over the radio: CRT-framed portrait
##   ["", "Text."]                     narration (no portrait)
##   {"choice": [{"text": "...", "flag": "k", "value": v, "then": [lines]}], "speaker": "rook", "prompt": "..."}
##   {"if": ["k", v], "then": [lines], "else": [lines]}
## radio(speaker, text) is the non-blocking in-run version: a small plate under
## the HUD that types, holds and goes.

signal finished
signal choice_made(flag: String, value: Variant)

const INK := Color("140c0e")
const BONE := Color("e9dfc9")
const DIM := Color("8f877e")
const DUST := Color("ffc040")
const TEAL := Color("5cd2c0")
const CPS := 48.0

var auto: bool = false
## Choice index taken in auto mode (tests / bots).
var auto_choice: int = 0
var active: bool = false
var _root: Control
var _dim: ColorRect
var _plate: PanelContainer
var _name: Label
var _name_plate: PanelContainer
var _text: Label
var _next: Label
var _skip: Button
var _slots: Array = [] ## [{"rect": TextureRect, "frame": Control, "speaker": ""}]
var _choices: VBoxContainer
var _typing: bool = false
var _tap: bool = false
var _skipping: bool = false
var _t: float = 0.0
var _choice_pick: int = -1
var _radio_box: PanelContainer
var _radio_text: Label
var _radio_name: Label
var _radio_port: TextureRect
var _radio_scan: Control
var _radio_q: Array = []
var _radio_left: float = 0.0
var _radio_typing: float = 0.0
var hero_name: String = ""


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_scene_ui()
	_build_radio_ui()
	_layout()
	get_viewport().size_changed.connect(_layout)
	_set_scene_visible(false)


func _build_scene_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(INK, 0.5)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_input)
	_root.add_child(_dim)
	for side in [0, 1]:
		var frame := Control.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.custom_minimum_size = Vector2(208, 208)
		frame.size = Vector2(208, 208)
		frame.draw.connect(_draw_frame.bind(frame, side))
		_root.add_child(frame)
		var tr := TextureRect.new()
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(8, 8)
		tr.size = Vector2(192, 192)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if side == 1:
			tr.flip_h = true
		frame.add_child(tr)
		var scan := Control.new()
		scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scan.position = Vector2.ZERO
		scan.size = Vector2(208, 208)
		var sdi: int = side
		scan.draw.connect(func() -> void:
			if bool(_slots[sdi].get("radio", false)):
				_draw_scan(scan, Rect2(Vector2(6, 6), Vector2(196, 196))))
		frame.add_child(scan)
		_slots.append({"rect": tr, "frame": frame, "scan": scan, "speaker": "", "radio": false})
	_plate = PanelContainer.new()
	_plate.add_theme_stylebox_override("panel", UiTheme.plate("panel", 24.0))
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(v)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_override("font", UiTheme.font_body)
	_text.add_theme_font_size_override("font_size", 24)
	_text.add_theme_color_override("font_color", BONE)
	_text.add_theme_constant_override("line_spacing", 2)
	_text.custom_minimum_size = Vector2(0, 112)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	_next = UiTheme.pixel_label("NEXT", UiTheme.PX_S, DUST)
	_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_next)
	_name_plate = PanelContainer.new()
	_name_plate.add_theme_stylebox_override("panel", UiTheme.plate("panel_hi", 10.0))
	_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_name_plate)
	_name = Label.new()
	_name.add_theme_font_override("font", UiTheme.font_button)
	_name.add_theme_font_size_override("font_size", 28)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_plate.add_child(_name)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 12)
	_root.add_child(_choices)
	_skip = UiTheme.big_button("SKIP", UiTheme.LINE, 56, 20)
	_skip.custom_minimum_size = Vector2(128, 56)
	_skip.pressed.connect(func() -> void:
		_skipping = true
		_tap = true)
	_root.add_child(_skip)


func _build_radio_ui() -> void:
	_radio_box = PanelContainer.new()
	_radio_box.add_theme_stylebox_override("panel", UiTheme.plate("hud", 10.0))
	_radio_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radio_box.visible = false
	_root.add_child(_radio_box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radio_box.add_child(h)
	var pf := Control.new()
	pf.custom_minimum_size = Vector2(72, 72)
	pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pf.draw.connect(func() -> void: _draw_crt(pf, Rect2(Vector2.ZERO, pf.size)))
	h.add_child(pf)
	_radio_port = TextureRect.new()
	_radio_port.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_radio_port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_radio_port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_radio_port.position = Vector2(4, 4)
	_radio_port.size = Vector2(64, 64)
	_radio_port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pf.add_child(_radio_port)
	var scan := Control.new()
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scan.size = Vector2(72, 72)
	scan.draw.connect(func() -> void: _draw_scan(scan, Rect2(Vector2(4, 4), Vector2(64, 64))))
	pf.add_child(scan)
	_radio_scan = scan
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_radio_name = Label.new()
	_radio_name.add_theme_font_override("font", UiTheme.font_button)
	_radio_name.add_theme_font_size_override("font_size", 20)
	v.add_child(_radio_name)
	_radio_text = Label.new()
	_radio_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_radio_text.add_theme_font_override("font", UiTheme.font_body)
	_radio_text.add_theme_font_size_override("font_size", 20)
	_radio_text.add_theme_color_override("font_color", BONE)
	_radio_text.custom_minimum_size = Vector2(0, 0)
	v.add_child(_radio_text)


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var m := MobileLayout.control_safe_margin()
	_root.position = Vector2.ZERO
	_root.size = vp
	_dim.position = Vector2.ZERO
	_dim.size = vp
	var w := m.size.x - 16.0
	var x := m.position.x + 8.0
	_plate.custom_minimum_size = Vector2(w, 0)
	_plate.size = Vector2(w, 0)
	_plate.reset_size()
	var bottom := m.position.y + m.size.y - 24.0
	_plate.position = Vector2(x, bottom - maxf(_plate.size.y, 200.0))
	var py := _plate.position.y - 200.0
	(_slots[0]["frame"] as Control).position = Vector2(x + 8.0, py)
	(_slots[1]["frame"] as Control).position = Vector2(x + w - 216.0, py)
	_choices.position = Vector2(x + 24.0, _plate.position.y - 24.0)
	_choices.size = Vector2(w - 48.0, 0)
	_skip.position = Vector2(m.position.x + m.size.x - 136.0, m.position.y + 8.0)
	var rw := minf(560.0, vp.x - 32.0)
	_radio_box.custom_minimum_size = Vector2(rw, 0)
	_radio_box.size = Vector2(rw, 0)
	_radio_box.position = Vector2((vp.x - rw) * 0.5, m.position.y + 232.0)


func _set_scene_visible(on: bool) -> void:
	for n in [_dim, _plate, _name_plate, _choices, _skip]:
		(n as Control).visible = on
	for s in _slots:
		(s["frame"] as Control).visible = on and str(s["speaker"]) != ""


## ---------------------------------------------------------------------------
## Scenes

func play(lines: Array) -> void:
	if lines.is_empty():
		return
	active = true
	_skipping = false
	for s in _slots:
		s["speaker"] = ""
	_radio_box.visible = false
	get_tree().paused = true
	TouchInput.clear_sticks()
	_set_scene_visible(true)
	_dim.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_dim, "modulate:a", 1.0, 0.18)
	await _play_lines(lines)
	_set_scene_visible(false)
	active = false
	get_tree().paused = false
	TouchInput.clear_sticks()
	finished.emit()


func _play_lines(lines: Array) -> void:
	for ln in lines:
		if not is_inside_tree():
			return
		if ln is Dictionary:
			var d: Dictionary = ln
			if d.has("choice"):
				var picked: Dictionary = await _ask(d)
				if picked.has("then"):
					await _play_lines(picked["then"])
			elif d.has("if"):
				var cond: Array = d["if"]
				var ok := GameState.campaign_flag_is(str(cond[0]), cond[1] if cond.size() > 1 else null)
				var branch: Array = d.get("then", []) if ok else d.get("else", [])
				await _play_lines(branch)
			continue
		var arr: Array = ln
		if _skipping:
			continue
		await _show_line(str(arr[0]), str(arr[1]), arr.size() > 2 and str(arr[2]) == "radio")


func _show_line(spk: String, text: String, radio: bool) -> void:
	## "{hero}" speaks as whoever is playing this level.
	if spk == "{hero}":
		spk = CampaignDefs.hero_speaker(GameState.selected_character_id)
	var sd: Dictionary = CampaignDefs.speaker(spk) if spk != "" else {}
	radio = radio or bool(sd.get("radio", false))
	var col := Color(str(sd.get("color", "e9dfc9"))) if spk != "" else DIM
	## Pick a slot: keep the speaker where they already stand, else the slot
	## not used by the last speaker.
	var side := -1
	if spk != "":
		for i in range(2):
			if str(_slots[i]["speaker"]) == spk:
				side = i
		if side < 0:
			side = 0 if str(_slots[0]["speaker"]) == "" else (1 if str(_slots[1]["speaker"]) == "" else _least_recent())
			_slots[side]["speaker"] = spk
			var pp := CampaignDefs.portrait_path(spk)
			(_slots[side]["rect"] as TextureRect).texture = load(pp) if pp != "" else null
		_slots[side]["radio"] = radio
		_slots[side]["t"] = Time.get_ticks_msec()
	for i in range(2):
		var fr := _slots[i]["frame"] as Control
		fr.visible = str(_slots[i]["speaker"]) != ""
		var lit := i == side
		fr.modulate = Color.WHITE if lit else Color(0.45, 0.42, 0.4, 1.0)
		fr.position.y = (_plate.position.y - 200.0) - (8.0 if lit else 0.0)
		fr.queue_redraw()
		(_slots[i]["scan"] as Control).queue_redraw()
	_name_plate.visible = spk != ""
	_name.text = (str(sd.get("name", spk)).to_upper() + ("  ·  RADIO" if radio else "")) if spk != "" else ""
	_name.add_theme_color_override("font_color", col)
	_name_plate.reset_size()
	if side == 1:
		_name_plate.position = Vector2(_plate.position.x + _plate.size.x - _name_plate.size.x - 24.0, _plate.position.y - _name_plate.size.y * 0.5)
	else:
		_name_plate.position = Vector2(_plate.position.x + 24.0, _plate.position.y - _name_plate.size.y * 0.5)
	_text.text = text.replace("{hero}", hero_name)
	_text.add_theme_color_override("font_color", BONE if spk != "" else DIM)
	_text.visible_characters = 0
	_typing = true
	_tap = false
	if radio:
		Juice.sfx("radio_chatter", -8.0)
	var total := _text.get_total_character_count()
	var shown := 0.0
	while shown < total and not _tap and not auto:
		await get_tree().process_frame
		shown += CPS * get_process_delta_time()
		_text.visible_characters = int(shown)
	_text.visible_characters = -1
	_typing = false
	_tap = false
	if auto:
		await get_tree().process_frame
		return
	while not _tap:
		await get_tree().process_frame
	_tap = false


func _least_recent() -> int:
	return 0 if int(_slots[0].get("t", 0)) <= int(_slots[1].get("t", 0)) else 1


func _ask(d: Dictionary) -> Dictionary:
	var opts: Array = d["choice"]
	_skipping = false
	if d.has("prompt"):
		_tap = false
		await _show_line(str(d.get("speaker", "")), str(d["prompt"]), false)
	for c in _choices.get_children():
		c.queue_free()
	_choice_pick = -1
	for i in range(opts.size()):
		var b := UiTheme.big_button(str(opts[i]["text"]).to_upper(), UiTheme.AMBER if i == 0 else UiTheme.TEAL, 72, 24)
		b.custom_minimum_size = Vector2(0, 72)
		var k := i
		b.pressed.connect(func() -> void: _choice_pick = k)
		_choices.add_child(b)
	_choices.visible = true
	_next.visible = false
	_skip.visible = false
	_choices.reset_size()
	_choices.position.y = _plate.position.y - _choices.size.y - 24.0
	## Portraits step aside for the buttons.
	for s in _slots:
		(s["frame"] as Control).visible = false
	if auto:
		_choice_pick = clampi(auto_choice, 0, opts.size() - 1)
	while _choice_pick < 0:
		await get_tree().process_frame
	var picked: Dictionary = opts[_choice_pick]
	for c in _choices.get_children():
		c.queue_free()
	_choices.visible = false
	_next.visible = true
	_skip.visible = true
	if picked.has("flag"):
		GameState.set_campaign_flag(str(picked["flag"]), picked.get("value", true))
		choice_made.emit(str(picked["flag"]), picked.get("value", true))
	Juice.sfx("ui_tap")
	return picked


func _on_input(ev: InputEvent) -> void:
	var press: bool = (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT)
	if press and active:
		_tap = true


func _unhandled_input(ev: InputEvent) -> void:
	if active and (ev.is_action_pressed("ui_accept") or ev.is_action_pressed("dash")):
		_tap = true


## ---------------------------------------------------------------------------
## Radio (non-blocking)

func radio(spk: String, text: String) -> void:
	if spk == "{hero}":
		spk = CampaignDefs.hero_speaker(GameState.selected_character_id)
	_radio_q.append([spk, text])


func radio_busy() -> bool:
	return _radio_box.visible or not _radio_q.is_empty()


func _process(delta: float) -> void:
	_t += delta
	if active:
		_next.modulate.a = 1.0 if fmod(_t, 1.0) < 0.6 else 0.25
		for s in _slots:
			if bool(s.get("radio", false)):
				(s["scan"] as Control).queue_redraw()
		return
	if get_tree().paused:
		return
	if _radio_box.visible:
		_radio_scan.queue_redraw()
		if _radio_typing < float(_radio_text.get_total_character_count()):
			_radio_typing += CPS * delta
			_radio_text.visible_characters = int(_radio_typing)
		else:
			_radio_text.visible_characters = -1
			_radio_left -= delta
			if _radio_left <= 0.0:
				_radio_box.visible = false
	elif not _radio_q.is_empty():
		var it: Array = _radio_q.pop_front()
		var sd := CampaignDefs.speaker(str(it[0]))
		_radio_name.text = str(sd.get("name", it[0])).to_upper() + "  ·  RADIO"
		_radio_name.add_theme_color_override("font_color", Color(str(sd.get("color", "e9dfc9"))))
		var pp := CampaignDefs.portrait_path(str(it[0]))
		_radio_port.texture = load(pp) if pp != "" else null
		_radio_text.text = str(it[1]).replace("{hero}", hero_name)
		_radio_text.visible_characters = 0
		_radio_typing = 0.0
		_radio_left = 1.6 + float(str(it[1]).length()) / 22.0
		_radio_box.visible = true
		_radio_box.reset_size()
		Juice.sfx("radio_chatter", -10.0)


## ---------------------------------------------------------------------------
## Drawing: worn steel portrait frame; radio = CRT (scanlines, static, amber edge).

func _draw_frame(fr: Control, side: int) -> void:
	var r := Rect2(Vector2.ZERO, fr.size)
	var radio := bool(_slots[side].get("radio", false))
	if radio:
		_draw_crt(fr, r)
		return
	fr.draw_rect(r, INK)
	fr.draw_rect(r.grow(-2.0), Color("5e6d7a"), false, 2.0)
	fr.draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), Color("1f1a1d"))


func _draw_crt(c: Control, r: Rect2) -> void:
	c.draw_rect(r, INK)
	c.draw_rect(r.grow(-2.0), Color("b88a33"), false, 2.0)
	c.draw_rect(r.grow(-6.0), Color("1b222c"))


## Over the portrait: scanlines (25 % INK every other 2-px row) + static ticks.
func _draw_scan(c: Control, inner: Rect2) -> void:
	var y := inner.position.y
	var k := 0
	var seed_t := int(Time.get_ticks_msec() / 90)
	while y < inner.end.y:
		if k % 2 == 0:
			c.draw_rect(Rect2(inner.position.x, y, inner.size.x, 2.0), Color(INK, 0.25))
		## A few static ticks that jump around.
		if (k * 7 + seed_t) % 23 == 0:
			c.draw_rect(Rect2(inner.position.x + float((k * 37 + seed_t * 13) % int(maxf(1.0, inner.size.x - 12.0))), y, 12.0, 2.0), Color(BONE, 0.5))
		y += 2.0
		k += 1
