extends "res://scripts/ui/menu_base.gd"

## Settings: one tabbed screen (AUDIO / VIDEO / CONTROLS / ACCESS / ABOUT)
## used everywhere. As a scene (main menu) BACK goes to the main menu; as an
## overlay (SettingsMenu.open_overlay from the main menu, hangar or the pause
## menu) BACK frees the overlay and runs the caller's callback, leaving the
## pause state as it was. Rows come from SettingsDefs.TABS; every change is
## applied live through GameState.set_setting and saved.

const Feedback = preload("res://scripts/ui/feedback.gd")
const BuildInfo = preload("res://scripts/build_info.gd")
const SCRIPT_PATH := "res://scripts/ui/settings_menu.gd"
const RESET_HOLD_MS := 2000
const CREDIT_FILES := ["res://assets/ATTRIBUTION.md"]
const LICENCE_DIRS := ["res://assets/fonts", "res://assets"]

## Remembered between openings (per session).
static var last_tab: String = "audio"

## Overlay mode: called (once) when the screen closes.
var on_close: Callable = Callable()
## Opened from the in-run pause menu (Reset save is unavailable mid-run).
var in_run: bool = false
var _tab: String = "audio"
var _tab_btns: Dictionary = {}
var _scroll: ScrollContainer
var _list: VBoxContainer
var _reset_tab: Button
var _closing: bool = false
var _hold_start: int = -1
var _hold_btn: Button
var _swatch: Control


## Open Settings on top of `host` (a scene or the pause layer). Works while
## the tree is paused. Returns the screen.
static func open_overlay(host: Node, closed: Callable = Callable(), run: bool = false) -> Control:
	var layer := CanvasLayer.new()
	layer.name = "SettingsLayer"
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var scr: Control = Control.new()
	scr.set_script(load(SCRIPT_PATH))
	scr.name = "SettingsMenu"
	scr.set("in_run", run)
	scr.set("on_close", func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
		if closed.is_valid():
			closed.call())
	layer.add_child(scr)
	host.add_child(layer)
	Juice.sfx("ui_open")
	return scr


static func is_open(tree: SceneTree) -> bool:
	return tree != null and tree.root.find_child("SettingsLayer", true, false) != null


func build(c: VBoxContainer) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tab = last_tab
	c.add_theme_constant_override("separation", 12)
	c.add_child(header("SETTINGS", close))
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 6)
	c.add_child(tabs)
	for t in SettingsDefs.TABS:
		var id := str(t["id"])
		var b := Button.new()
		b.name = "Tab_" + id
		b.text = str(t["label"])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
		b.add_theme_font_override("font", UiTheme.font_button)
		b.add_theme_font_size_override("font_size", UiTheme.T_H3)
		b.pressed.connect(show_tab.bind(id))
		tabs.add_child(b)
		_tab_btns[id] = b
	_scroll = ScrollContainer.new()
	_scroll.name = "SettingsScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 18
	c.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "Rows"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)
	_reset_tab = UiTheme.big_button("RESET TAB TO DEFAULTS", UiTheme.LINE, 64, 20)
	_reset_tab.name = "ResetTab"
	_reset_tab.icon = IconSet.tex("set_reset", false)
	_reset_tab.pressed.connect(reset_tab)
	c.add_child(_reset_tab)
	show_tab(_tab)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _process(_delta: float) -> void:
	if _hold_start >= 0 and is_instance_valid(_hold_btn):
		var held := Time.get_ticks_msec() - _hold_start
		if held >= RESET_HOLD_MS:
			_hold_start = -1
			_hold_btn.text = "RESET SAVE"
			_confirm_reset()
		else:
			_hold_btn.text = "HOLD... %.1f" % (float(RESET_HOLD_MS - held) / 1000.0)


## BACK: save, then leave (overlay: free + callback; scene: main menu).
func close() -> void:
	if _closing:
		return
	_closing = true
	GameState.save_profile()
	if on_close.is_valid():
		on_close.call()
	else:
		GameState.go_main_menu()


func current_tab() -> String:
	return _tab


func show_tab(id: String) -> void:
	_tab = id
	last_tab = id
	_hold_start = -1
	_swatch = null
	for k in _tab_btns:
		var b: Button = _tab_btns[k]
		var on := str(k) == id
		b.set_pressed_no_signal(on)
		_style_choice(b, on)
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	var t := SettingsDefs.tab(id)
	for r in t["rows"]:
		if bool(r.get("desktop", false)) and not MobileLayout.is_desktop():
			continue
		_list.add_child(_make_row(r))
	_reset_tab.visible = id != "about"
	_scroll.scroll_vertical = 0


## Every stored key on the current tab back to its default (applied + saved).
func reset_tab() -> void:
	var d := SettingsDefs.tab_defaults(_tab)
	for k in d:
		if str(k) == "text_size":
			UiTheme.set_text_size(int(d[k]))
		else:
			GameState.set_setting(str(k), d[k], false)
	GameState.save_profile()
	Juice.sfx("ui_toggle")
	show_tab(_tab)


## --- rows -----------------------------------------------------------------

func _make_row(r: Dictionary) -> Control:
	var key := str(r["key"])
	var typ := str(r["type"])
	var panel := PanelContainer.new()
	panel.name = "Row_" + key
	panel.add_theme_stylebox_override("panel", UiTheme.plate("inset", 10.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	panel.add_child(h)
	var ic := IconSet.rect(str(r.get("icon", "set_ui")), 48)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	h.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	var lab := UiTheme.head_label(str(r["label"]), UiTheme.T_H3, UiTheme.TEXT)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(lab)
	match typ:
		"toggle":
			var b := Button.new()
			b.name = "Toggle"
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(120, UiTheme.MIN_TOUCH)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.button_pressed = bool(SettingsDefs.get_value(key))
			_style_toggle(b)
			b.toggled.connect(func(on: bool) -> void:
				GameState.set_setting(key, on)
				_style_toggle(b)
				Juice.sfx("ui_toggle")
				if key == "haptics" and on:
					Juice.haptic(Juice.HAPTIC_HIT))
			h.add_child(b)
		"slider":
			var val := UiTheme.pixel_label("", UiTheme.PX_M, UiTheme.AMBER)
			val.name = "Value"
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			val.custom_minimum_size = Vector2(80, 0)
			top.add_child(val)
			var s := HSlider.new()
			s.name = "Slider"
			s.min_value = float(r.get("min", 0.0))
			s.max_value = float(r.get("max", 1.0))
			s.step = float(r.get("step", 0.01))
			s.value = float(SettingsDefs.get_value(key))
			s.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
			s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s.focus_mode = Control.FOCUS_NONE
			val.text = fmt(r, s.value)
			s.value_changed.connect(func(v: float) -> void:
				val.text = fmt(r, v)
				GameState.set_setting(key, v, false)
				if key == "brightness" and is_instance_valid(_swatch):
					_swatch.queue_redraw())
			s.drag_ended.connect(func(_c: bool) -> void:
				GameState.save_profile()
				if r.has("preview"):
					Juice.sfx(str(r["preview"]))
				if bool(r.get("preview_haptic", false)):
					Juice.haptic(Juice.HAPTIC_BIG))
			col.add_child(s)
			if bool(r.get("swatch", false)):
				_swatch = _gamma_swatch()
				col.add_child(_swatch)
		"choice":
			col.add_child(_choice_row(key, r["options"]))
		"info":
			var v := UiTheme.body_label(_info(key), UiTheme.T_BODY, UiTheme.AMBER)
			v.name = "Info"
			col.add_child(v)
		"action":
			col.remove_child(top)
			top.queue_free()
			var b := UiTheme.big_button(str(r["label"]).to_upper(), UiTheme.RUST if key == "reset_save" else UiTheme.LINE, 64, 20)
			b.name = "Action"
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(b)
			_wire_action(key, b)
	var desc := str(r.get("desc", ""))
	if desc != "":
		var d := UiTheme.body_label(desc, UiTheme.T_SMALL, UiTheme.TEXT_DIM)
		col.add_child(d)
	return panel


## Slider readout: 0-100 by default, "pct" for multipliers, "signed" around 50.
static func fmt(r: Dictionary, v: float) -> String:
	match str(r.get("fmt", "")):
		"pct":
			return "%d%%" % int(round(v * 100.0))
		"signed":
			var n := int(round((v - 0.5) * 100.0))
			return ("+%d" % n) if n > 0 else str(n)
	return str(int(round(v * 100.0)))


## Segmented picker, active option lit teal. Text size goes through UiTheme
## (refits the whole screen); the rest through set_setting.
func _choice_row(key: String, options: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Choice"
	row.add_theme_constant_override("separation", 8)
	var cur := UiTheme.text_size_index() if key == "text_size" else int(SettingsDefs.get_value(key))
	var btns: Array[Button] = []
	for i in range(options.size()):
		var b := Button.new()
		b.name = "Opt%d" % i
		b.text = str(options[i])
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
		b.clip_text = true
		row.add_child(b)
		btns.append(b)
	var paint := func(sel: int) -> void:
		for j in range(btns.size()):
			btns[j].set_pressed_no_signal(j == sel)
			_style_choice(btns[j], j == sel)
	paint.call(cur)
	for i in range(btns.size()):
		btns[i].pressed.connect(func() -> void:
			paint.call(i)
			if key == "text_size":
				UiTheme.set_text_size(i)
			else:
				GameState.set_setting(key, i)
			Juice.sfx("ui_toggle")
			if key == "shake_level" and i > 0:
				Juice.shake(0.5))
	return row


## Six dark-to-mid grey steps through the current gamma: set Brightness so
## the darkest step is just visible.
func _gamma_swatch() -> Control:
	var sw := Control.new()
	sw.name = "Swatch"
	sw.custom_minimum_size = Vector2(0, 40)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw.draw.connect(func() -> void:
		var g := SettingsDefs.gamma()
		var n := 6
		var w := sw.size.x / float(n)
		for i in range(n):
			var base := 0.05 + 0.07 * float(i)
			var v := pow(base, g)
			sw.draw_rect(Rect2(Vector2(w * i, 0), Vector2(w - 4.0, sw.size.y)), Color(v, v * 0.97, v * 0.93))
		sw.draw_rect(Rect2(Vector2.ZERO, sw.size), UiTheme.INK, false, 2.0))
	return sw


func _info(key: String) -> String:
	if key == "build":
		var built := str(BuildInfo.BUILT)
		var vi := Engine.get_version_info()
		return "Wanderer %s%s \u00b7 Godot %d.%d.%d" % ["v" + str(BuildInfo.VERSION) + " " + str(BuildInfo.COMMIT), (" (" + built + ")") if built != "" else "",
			int(vi.get("major", 4)), int(vi.get("minor", 0)), int(vi.get("patch", 0))]
	return ""


func _wire_action(key: String, b: Button) -> void:
	match key:
		"replay_tutorial":
			if not GameState.tutorial_done:
				b.text = "TUTORIAL NEXT RUN"
			b.pressed.connect(func() -> void:
				GameState.tutorial_done = false
				GameState.save_profile()
				b.text = "TUTORIAL NEXT RUN")
		"credits":
			b.pressed.connect(show_credits)
		"feedback":
			b.pressed.connect(func() -> void: Feedback.open(self, get_parent() if on_close.is_valid() else null))
		"fullscreen":
			b.text = "FULLSCREEN ON" if DisplayFit.is_filled() else "FULLSCREEN"
			b.pressed.connect(func() -> void:
				DisplayFit.toggle_fill_screen()
				b.text = "FULLSCREEN ON" if DisplayFit.is_filled() else "FULLSCREEN")
		"reset_save":
			if in_run:
				b.disabled = true
				b.text = "RESET SAVE (NOT DURING A RUN)"
				return
			b.text = "RESET SAVE"
			_hold_btn = b
			b.button_down.connect(func() -> void: _hold_start = Time.get_ticks_msec())
			b.button_up.connect(func() -> void:
				if _hold_start >= 0:
					_hold_start = -1
					b.text = "RESET SAVE")


func _confirm_reset() -> void:
	Juice.haptic(Juice.HAPTIC_BIG)
	var box: Array = []
	var ov := modal("WIPE SAVE?", [["Every hero, all gear, scrap and campaign progress is erased. Settings are kept.", UiTheme.TEXT]], [
		["WIPE EVERYTHING", UiTheme.RUST, func() -> void:
			GameState.reset_profile()
			if is_instance_valid(box[0]):
				box[0].queue_free()
			if is_instance_valid(_hold_btn):
				_hold_btn.text = "PROGRESS RESET"
				_hold_btn.disabled = true],
		["CANCEL", UiTheme.LINE, func() -> void:
			if is_instance_valid(box[0]):
				box[0].queue_free()],
	], UiTheme.DANGER)
	ov.process_mode = Node.PROCESS_MODE_ALWAYS
	box.append(ov)


## --- credits & licences ---------------------------------------------------------

func show_credits() -> void:
	for k in _tab_btns:
		_style_choice(_tab_btns[k], false)
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	_reset_tab.visible = false
	var back := UiTheme.big_button("BACK TO ABOUT", UiTheme.TEAL, 64, 20)
	back.name = "CreditsBack"
	back.pressed.connect(show_tab.bind("about"))
	_list.add_child(back)
	var rt := RichTextLabel.new()
	rt.name = "Credits"
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.selection_enabled = false
	rt.mouse_filter = Control.MOUSE_FILTER_PASS
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_override("normal_font", UiTheme.font_body)
	rt.add_theme_font_override("bold_font", UiTheme.font_button)
	var fs := UiTheme.font_px(UiTheme.T_BODY)
	rt.add_theme_font_size_override("normal_font_size", fs)
	rt.add_theme_font_size_override("bold_font_size", fs)
	rt.add_theme_color_override("default_color", UiTheme.TEXT)
	rt.text = credits_bbcode()
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.plate("inset", 16.0))
	plate.add_child(rt)
	_list.add_child(plate)
	_scroll.scroll_vertical = 0


## ATTRIBUTION.md (code blocks dropped, tables as lines) + every licence
## text shipped under assets/ + the Godot Engine licence, as BBCode.
static func credits_bbcode() -> String:
	var out := "[font_size=%d][color=#ffc040]CREDITS[/color][/font_size]\n\n" % UiTheme.font_px(UiTheme.T_H1)
	for p in CREDIT_FILES:
		if FileAccess.file_exists(p):
			out += _md_to_bbcode(FileAccess.get_file_as_string(p)) + "\n"
	for p in licence_files():
		out += "[font_size=%d][color=#ffc040]%s[/color][/font_size]\n" % [UiTheme.font_px(UiTheme.T_H2), _esc(p.get_file().get_basename().replace("-", " ").to_upper())]
		out += _esc(FileAccess.get_file_as_string(p).strip_edges()) + "\n\n"
	out += "[font_size=%d][color=#ffc040]GODOT ENGINE[/color][/font_size]\n" % UiTheme.font_px(UiTheme.T_H2)
	out += _esc(Engine.get_license_text().strip_edges()) + "\n"
	return out


static func licence_files() -> Array[String]:
	var out: Array[String] = []
	for dir in LICENCE_DIRS:
		var d := DirAccess.open(str(dir))
		if d == null:
			continue
		for f in d.get_files():
			var u := f.to_upper()
			if (u.contains("LICENSE") or u.contains("LICENCE") or u.contains("OFL")) and not f.ends_with(".import"):
				var p := str(dir) + "/" + f
				if not out.has(p):
					out.append(p)
	return out


static func _esc(t: String) -> String:
	return t.replace("[", "[lb]")


static func _md_to_bbcode(md: String) -> String:
	## Blocks: [kind, text] with kind head1 / head2 / bullet / para / blank.
	## Soft-wrapped markdown lines are joined back into one paragraph.
	var blocks: Array = []
	var in_code := false
	for raw in md.split("\n"):
		var ln := raw.strip_edges(false, true)
		if ln.begins_with("```"):
			in_code = not in_code
			## Drop a "run this:" line that only introduced the code block.
			if in_code:
				var n := blocks.size() - 1
				while n >= 0 and blocks[n][0] == "blank":
					n -= 1
				if n >= 0 and blocks[n][0] == "para" and str(blocks[n][1]).ends_with(":"):
					blocks.resize(n)
			continue
		if in_code:
			continue
		var lead := ln.length() - ln.lstrip(" ").length()
		var t := ln.strip_edges()
		if t == "":
			blocks.append(["blank", ""])
			continue
		if t.begins_with("|"):
			var cells: PackedStringArray = []
			for c in t.trim_prefix("|").trim_suffix("|").split("|"):
				cells.append(c.strip_edges())
			if cells.size() > 0 and cells[0].begins_with("---"):
				continue
			blocks.append(["bullet", " / ".join(cells)])
			continue
		if t.begins_with("#"):
			var head := 0
			while head < t.length() and t[head] == "#":
				head += 1
			blocks.append(["head1" if head == 1 else "head2", t.substr(head).strip_edges()])
			continue
		if t.begins_with("- ") or t.begins_with("* "):
			blocks.append(["bullet", t.substr(2)])
			continue
		var last: String = str(blocks[-1][0]) if blocks.size() > 0 else "blank"
		if last == "para" or (last == "bullet" and lead > 0):
			blocks[-1][1] = str(blocks[-1][1]) + " " + t
		else:
			blocks.append(["para", t])
	var out: PackedStringArray = []
	for b in blocks:
		var body := _inline(_esc(str(b[1])))
		match str(b[0]):
			"head1", "head2":
				out.append("\n[font_size=%d][color=#ffc040]%s[/color][/font_size]" % [UiTheme.font_px(UiTheme.T_H2 if b[0] == "head1" else UiTheme.T_H3), body.to_upper()])
			"bullet":
				out.append("  \u2022 " + body)
			"para":
				out.append(body)
			_:
				if out.size() > 0 and out[out.size() - 1] != "":
					out.append("")
	return "\n".join(out)


## **bold** -> [b], `code` and <links> as plain text.
static func _inline(t: String) -> String:
	var s := t
	var on := false
	while s.contains("**"):
		s = _replace_first(s, "**", "[/b]" if on else "[b]")
		on = not on
	if on:
		s += "[/b]"
	s = s.replace("`", "").replace("<", "").replace(">", "")
	return s


static func _replace_first(s: String, what: String, with: String) -> String:
	var i := s.find(what)
	return s if i < 0 else s.substr(0, i) + with + s.substr(i + what.length())


## --- look -------------------------------------------------------------------

func _style_choice(b: Button, on: bool) -> void:
	UiTheme.skin_button(b, UiTheme.TEAL if on else UiTheme.LINE, 8.0)
	var c := Color(0.85, 1.0, 0.92) if on else UiTheme.TEXT_DIM
	for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, c)


func _style_toggle(b: Button) -> void:
	var on := b.button_pressed
	b.text = "ON" if on else "OFF"
	_style_choice(b, on)
