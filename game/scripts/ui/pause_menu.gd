extends CanvasLayer

## In-run pause: Resume · How to play · Settings · Abandon run.
## Pauses the tree; this layer keeps processing.

const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const HelpViewer = preload("res://scripts/ui/help_viewer.gd")
var _dim: ColorRect
var _frame: MarginContainer
var _content: Control
var _confirm_abandon: bool = false

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.04, 0.03, 0.02, 0.78)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_frame = MarginContainer.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)

func open() -> void:
	if GameState.run_finished:
		return
	get_tree().paused = true
	TouchInput.clear_sticks()
	_dim.color = Color(0.04, 0.03, 0.02, 0.78)
	visible = true
	_show_main()

func close() -> void:
	get_tree().paused = false
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()

func _set_content(c: Control) -> void:
	for ch in _frame.get_children():
		ch.queue_free()
	var m := MobileLayout.control_safe_margin()
	var vp := get_viewport().get_visible_rect().size
	_frame.add_theme_constant_override("margin_left", int(m.position.x + vp.x * 0.06))
	_frame.add_theme_constant_override("margin_right", int(vp.x - m.position.x - m.size.x + vp.x * 0.06))
	_frame.add_theme_constant_override("margin_top", int(m.position.y + 10))
	_frame.add_theme_constant_override("margin_bottom", int(vp.y - m.position.y - m.size.y + 10))
	_frame.add_child(c)
	_content = c

func _show_main() -> void:
	_confirm_abandon = false
	var center := CenterContainer.new()
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.plate("panel_hi", 28.0))
	center.add_child(plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(420, 0)
	plate.add_child(v)
	plate.pivot_offset = Vector2(240, 240)
	plate.scale = Vector2(0.92, 0.92)
	plate.modulate.a = 0.0
	var tw := plate.create_tween().set_parallel(true)
	tw.tween_property(plate, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(plate, "modulate:a", 1.0, 0.12)
	v.add_child(UiTheme.title_label("PAUSED", 48))
	var info := UiTheme.body_label("%s · %s · Threat %d · Scrap %d" % [
		GameState.get_character().get("display_name", ""),
		GameState.get_mode().get("display_name", ""),
		GameState.threat_level,
		GameState.scrap_found,
	], 15, UiTheme.TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var resume := UiTheme.big_button("RESUME", UiTheme.TEAL, 70, 26)
	resume.pressed.connect(close)
	v.add_child(resume)
	var pack := UiTheme.big_button("BACKPACK  %d/%d" % [GameState.pack_weight(), GameState.pack_capacity()], UiTheme.TEAL, 58, 20)
	pack.pressed.connect(show_pack)
	v.add_child(pack)
	var help := UiTheme.big_button("HOW TO PLAY", UiTheme.AMBER, 58, 20)
	help.pressed.connect(_show_help)
	v.add_child(help)
	var settings := UiTheme.big_button("SETTINGS", UiTheme.AMBER, 58, 20)
	settings.pressed.connect(_show_settings)
	v.add_child(settings)
	var quit := UiTheme.big_button("ABANDON RUN", UiTheme.RUST, 58, 20)
	quit.pressed.connect(func() -> void:
		if not _confirm_abandon:
			_confirm_abandon = true
			quit.text = "TAP AGAIN — counts as a wipe"
			return
		if not GameState.run_finished:
			GameState.on_wipe()
			GameState.result_summary = "Abandoned the run.\n" + GameState.result_summary
		GameState.go_result()
	)
	v.add_child(quit)
	_set_content(center)

## Backpack: what you carry home. Medicine fills the pack; ingredients ride
## in a weightless pouch. A centred painted plate over a darker backdrop.
func show_pack() -> void:
	_dim.color = Color(0.03, 0.02, 0.015, 0.92)
	var center := CenterContainer.new()
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.plate("panel_hi", 24.0))
	var vp := get_viewport().get_visible_rect().size
	plate.custom_minimum_size = Vector2(minf(600.0, vp.x - 60.0), 0)
	center.add_child(plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	plate.add_child(v)
	v.add_child(UiTheme.title_label("BACKPACK", 40))
	var slow := 1.0 - GameState.carry_speed_mult()
	var info := UiTheme.body_label("%d / %d carried. Medicine weighs %d%s. Everything here is lost if you go down." % [
		GameState.pack_weight(), GameState.pack_capacity(), MedicineDefs.MEDICINE_WEIGHT,
		(" and slows you %d%%" % int(round(slow * 100.0))) if slow > 0.0 else ""], 15, UiTheme.TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(420.0, vp.y * 0.42))
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	list.add_child(UiTheme.body_label("PACK", 16, UiTheme.AMBER))
	var heavy := 0
	for id in GameState.run_pack.keys():
		if MedicineDefs.is_pouch(str(id)):
			continue
		heavy += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_pack_icon(str(id), 48))
		var l := UiTheme.body_label("%s ×%d  (weight %d each)" % [MedicineDefs.item_name(str(id)), int(GameState.run_pack[id]), MedicineDefs.weight(str(id))], 17)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var drop := UiTheme.big_button("DROP", UiTheme.RUST, 52, 18)
		drop.custom_minimum_size.x = 100
		drop.pressed.connect(drop_item.bind(str(id)))
		row.add_child(drop)
		list.add_child(row)
	if heavy == 0:
		list.add_child(UiTheme.body_label("Empty. Medicine crates are marked on the map — a new one each extract window.", 15))
	list.add_child(UiTheme.body_label("INGREDIENT POUCH  ·  weightless", 16, UiTheme.AMBER))
	var pouch := GameState.pouch()
	if pouch.is_empty():
		list.add_child(UiTheme.body_label("Nothing yet. Kills and crates drop ingredients for Cinder's tonics.", 15))
	else:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 16)
		list.add_child(flow)
		for id in pouch.keys():
			var h := HBoxContainer.new()
			h.add_child(_pack_icon(str(id), 40))
			h.add_child(UiTheme.body_label("%s ×%d" % [MedicineDefs.item_name(str(id)), int(pouch[id])], 16, UiTheme.TEXT, false))
			flow.add_child(h)
	var done := UiTheme.big_button("DONE", UiTheme.TEAL, 60, 22)
	done.pressed.connect(func() -> void:
		_dim.color = Color(0.04, 0.03, 0.02, 0.78)
		_show_main())
	v.add_child(done)
	_set_content(center)


func _pack_icon(id: String, px: float) -> TextureRect:
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(px, px)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = load(MedicineDefs.icon_path(id))
	return ic

## Drop one of an item on the ground at the hero's feet (pick it up again later).
func drop_item(id: String) -> void:
	if not GameState.drop_from_pack(id, 1):
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null:
		var h := HaulPickup.spawn(p.get_parent(), p.global_position + Vector2(randf_range(-20, 20), 18), id, 1, false)
		if h:
			h.dropped = true
	Juice.sfx("pack_full")
	show_pack()

func _show_help() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var viewer: VBoxContainer = VBoxContainer.new()
	viewer.set_script(HelpViewer)
	viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewer.finished.connect(_show_main)
	v.add_child(viewer)
	var back := UiTheme.big_button("BACK TO PAUSE", UiTheme.LINE, 50, 18)
	back.pressed.connect(_show_main)
	v.add_child(back)
	_set_content(v)

func _show_settings() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_child(UiTheme.title_label("SETTINGS", 34))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var back := UiTheme.big_button("DONE", UiTheme.TEAL, 52, 20)
	back.pressed.connect(_show_main)
	head.add_child(back)
	v.add_child(head)
	v.add_child(UiTheme.body_label("Layout changes (stick size, left-handed) apply next run.", 13, UiTheme.TEXT_DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var panel: VBoxContainer = VBoxContainer.new()
	panel.set_script(SettingsPanel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	v.add_child(scroll)
	_set_content(v)
