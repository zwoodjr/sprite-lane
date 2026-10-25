extends "res://scripts/ui/menu_base.gd"

## Tester feedback sheet (opened by feedback.gd, which owns pause + capture).
## Category, optional 1-5 fun rating, a note, the screenshot and the context.
## SEND hands everything to the device: web share sheet / download, or a
## user://feedback file + clipboard on native.

const Feedback = preload("res://scripts/ui/feedback.gd")

var shot: Image = null
var ctx: Dictionary = {}
var on_close: Callable = Callable()

var category: String = ""
var fun: int = 0
var note: TextEdit
var status: Label
var send_btn: Button
var _cat_btns: Array[Button] = []
var _fun_btns: Array[Button] = []
var _web := false
var _sent := false
var _closed := false
var _last_status := ""
var _share_kick := -1.0


func _ready() -> void:
	_web = OS.has_feature("web")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	super()


func build(c: VBoxContainer) -> void:
	c.add_theme_constant_override("separation", 12)
	c.add_child(header("FEEDBACK", close))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	scroll.add_child(v)

	## What kind of report.
	v.add_child(UiTheme.head_label("WHAT KIND?", UiTheme.T_H3, UiTheme.AMBER))
	var cats := HBoxContainer.new()
	cats.name = "Categories"
	cats.add_theme_constant_override("separation", 8)
	v.add_child(cats)
	for cat in Feedback.CATEGORIES:
		var b := _seg(cat)
		b.name = "Cat_" + cat
		b.pressed.connect(func() -> void:
			category = "" if category == cat else cat
			_paint())
		cats.add_child(b)
		_cat_btns.append(b)

	## Optional fun rating.
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 8)
	fh.add_child(UiTheme.head_label("HOW FUN?", UiTheme.T_H3, UiTheme.AMBER))
	var opt := UiTheme.body_label("optional  ·  1 meh  5 great", UiTheme.T_SMALL, UiTheme.TEXT_DIM, false)
	opt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fh.add_child(opt)
	v.add_child(fh)
	var funs := HBoxContainer.new()
	funs.name = "Fun"
	funs.add_theme_constant_override("separation", 8)
	v.add_child(funs)
	for i in range(1, 6):
		var b := _seg(str(i))
		b.name = "Fun_%d" % i
		b.pressed.connect(func() -> void:
			fun = 0 if fun == i else i
			_paint())
		funs.add_child(b)
		_fun_btns.append(b)

	## The note. Web: the browser's prompt (reliable phone keyboard).
	v.add_child(UiTheme.head_label("NOTE", UiTheme.T_H3, UiTheme.AMBER))
	note = TextEdit.new()
	note.name = "Note"
	note.custom_minimum_size = Vector2(0, 200)
	note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	note.placeholder_text = "Tap to write: what happened, what you expected..." if _web else "What happened? What did you expect?"
	note.add_theme_font_size_override("font_size", UiTheme.T_BODY)
	if UiTheme.font_body:
		note.add_theme_font_override("font", UiTheme.font_body)
	note.add_theme_color_override("font_color", UiTheme.TEXT)
	note.add_theme_color_override("font_placeholder_color", UiTheme.TEXT_DIM)
	note.add_theme_color_override("caret_color", UiTheme.AMBER)
	var sb := UiTheme.plate("inset", 14.0)
	for s in ["normal", "focus", "read_only"]:
		note.add_theme_stylebox_override(s, sb)
	if _web:
		note.editable = false
		note.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		note.gui_input.connect(_web_note_input)
	v.add_child(note)

	## Screenshot + the context that rides along.
	var pc := card(UiTheme.LINE)
	v.add_child(pc)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 16)
	pc.add_child(ph)
	var thumb := TextureRect.new()
	thumb.name = "Shot"
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.custom_minimum_size = Vector2(152, 280)
	if shot != null:
		thumb.texture = ImageTexture.create_from_image(shot)
	ph.add_child(thumb)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	ph.add_child(info)
	info.add_child(UiTheme.head_label("ATTACHED", UiTheme.T_H3, UiTheme.TEAL))
	var lines := PackedStringArray()
	lines.append("Screenshot of this moment" if shot != null else "No screenshot on this device")
	lines.append(str(ctx.get("hero", "")))
	lines.append(str(ctx.get("mode", "")))
	if bool(ctx.get("in_run", false)):
		lines.append("Run Lv %s  ·  %s  ·  HP %s  ·  %s kills" % [str(ctx.get("run_level", "")), str(ctx.get("run_time", "")), str(ctx.get("hp", "")), str(ctx.get("kills", ""))])
	lines.append("%s fps  ·  build %s" % [str(ctx.get("fps", "")), str(ctx.get("build", ""))])
	lines.append("Settings and the last log lines too.")
	var il := UiTheme.body_label("\n".join(lines), UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	info.add_child(il)

	## Send.
	status = UiTheme.body_label(_hint(), UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(status)
	send_btn = UiTheme.big_button("SEND", UiTheme.AMBER, 88, 32)
	send_btn.name = "SendButton"
	send_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_btn.button_down.connect(_on_send_down)
	send_btn.pressed.connect(_on_send)
	c.add_child(send_btn)
	_paint()


func _hint() -> String:
	if _web:
		return "SEND opens your phone's share sheet: pick Messages or Mail."
	return "SEND saves the screenshot + text on this device and copies the text."


func _seg(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	b.clip_text = true
	b.add_theme_font_size_override("font_size", UiTheme.ui_size(20))
	if UiTheme.font_button:
		b.add_theme_font_override("font", UiTheme.font_button)
	b.pressed.connect(func() -> void: Juice.sfx("ui_toggle"))
	return b


func _paint() -> void:
	for b in _cat_btns:
		_skin(b, b.text == category)
	for i in range(_fun_btns.size()):
		_skin(_fun_btns[i], i + 1 <= fun)


func _skin(b: Button, on: bool) -> void:
	UiTheme.skin_button(b, UiTheme.AMBER if on else UiTheme.LINE, 8.0)
	var col := UiTheme.AMBER if on else UiTheme.TEXT_DIM
	for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, col)


func _web_note_input(e: InputEvent) -> void:
	var tap := (e is InputEventMouseButton and not (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventScreenTouch and not (e as InputEventScreenTouch).pressed)
	if not tap:
		return
	note.accept_event()
	var r: Variant = Feedback.web_prompt("Wanderer feedback: what happened?", note.text)
	if r != null:
		note.text = str(r)


func report() -> String:
	return Feedback.report_text(ctx, category, fun, note.text if note else "")


func _png() -> PackedByteArray:
	return shot.save_png_to_buffer() if shot != null else PackedByteArray()


## Web: stage the payload and hook the browser's own pointerup/touchend for
## this same tap, so navigator.share runs inside a real user gesture.
func _on_send_down() -> void:
	if _sent or not _web:
		return
	if Feedback.web_prepare(_png(), report(), Feedback.file_stem(ctx)):
		Feedback.web_call("arm")


func _on_send() -> void:
	if _sent:
		close()
		return
	if _web:
		## The gesture hook usually fired already; if not, share directly.
		_share_kick = 0.25
		status.text = "Opening the share sheet..."
		return
	var path := Feedback.save_native(Feedback.file_stem(ctx), _png(), report())
	if path == "":
		status.text = "Couldn't save the files. The text is on the clipboard."
		status.add_theme_color_override("font_color", UiTheme.DANGER)
		return
	_done("Saved to %s\nText copied: paste it into Messages or Mail with the PNG." % path)


func _done(msg: String) -> void:
	_sent = true
	status.text = msg
	status.add_theme_color_override("font_color", UiTheme.TEAL)
	send_btn.text = "DONE"
	UiTheme.skin_button(send_btn, UiTheme.TEAL, 18.0)


func _process(d: float) -> void:
	if not _web or _closed:
		return
	if _share_kick > 0.0:
		_share_kick -= d
		if _share_kick <= 0.0 and Feedback.web_status() == "ready":
			Feedback.web_call("share")
	var s := Feedback.web_status()
	if s == _last_status:
		return
	_last_status = s
	match s:
		"sharing":
			status.text = "Share sheet open: pick Messages or Mail."
		"shared":
			_done("Sent to the share sheet. Thanks!")
		"shared_text":
			_done("Text shared; the screenshot was downloaded. Attach it too.")
		"downloaded":
			_done("Screenshot downloaded and text copied: paste both into a message.")
		"cancelled":
			status.text = "Cancelled. Tap SEND to try again."
		_:
			if s.begins_with("error:"):
				status.text = "Couldn't share (%s). Text copied if allowed." % s.substr(6)
				status.add_theme_color_override("font_color", UiTheme.DANGER)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause_menu"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if _closed:
		return
	_closed = true
	if on_close.is_valid():
		on_close.call()
	elif is_instance_valid(self):
		queue_free()
