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
	v.add_child(UiTheme.title_label("PAUSED", UiTheme.T_TITLE_XL))
	## Run so far: three icon + pixel-number chips (no sentence).
	var info := HBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 16)
	v.add_child(info)
	for pair in [["hud_threat", str(GameState.threat_level), UiTheme.DANGER], ["cur_scrap", str(GameState.scrap_found), UiTheme.AMBER],
			["hud_kills", str(GameState.kills), UiTheme.TEXT]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		h.add_child(IconSet.rect(str(pair[0]), 48))
		var l := UiTheme.pixel_label(str(pair[1]), UiTheme.PX_M, pair[2])
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		info.add_child(h)
	var resume := UiTheme.big_button("RESUME", UiTheme.AMBER, 80, 32)
	resume.pressed.connect(close)
	v.add_child(resume)
	var pack := UiTheme.big_button("BACKPACK  %d/%d" % [GameState.pack_weight(), GameState.pack_capacity()], UiTheme.TEAL, 64, 20)
	pack.icon = IconSet.tex("camp_backpack", false)
	pack.pressed.connect(show_pack)
	v.add_child(pack)
	var help := UiTheme.big_button("HOW TO PLAY", UiTheme.LINE, 64, 20)
	help.icon = IconSet.tex("set_hints", false)
	help.pressed.connect(_show_help)
	v.add_child(help)
	var settings := UiTheme.big_button("SETTINGS", UiTheme.LINE, 64, 20)
	settings.icon = IconSet.tex("tab_workshop", false)
	settings.pressed.connect(_show_settings)
	v.add_child(settings)
	var quit := UiTheme.big_button("ABANDON RUN", UiTheme.RUST, 64, 20)
	quit.pressed.connect(func() -> void:
		if not _confirm_abandon:
			_confirm_abandon = true
			quit.text = "TAP AGAIN: COUNTS AS A WIPE"
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
	## Style bible + Track D: icon-led rows (set icons at integer scale), PACK
	## readout in the pixel font, Barlow at fixed sizes, 8-px grid.
	_dim.color = Color(UiTheme.INK, 0.92)
	var center := CenterContainer.new()
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.plate("panel_hi", 24.0))
	var vp := get_viewport().get_visible_rect().size
	plate.custom_minimum_size = Vector2(floorf(minf(624.0, vp.x - 48.0) / 8.0) * 8.0, 0)
	center.add_child(plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	plate.add_child(v)
	v.add_child(UiTheme.title_label("BACKPACK", 40))
	var cap := HBoxContainer.new()
	cap.alignment = BoxContainer.ALIGNMENT_CENTER
	cap.add_theme_constant_override("separation", 8)
	v.add_child(cap)
	cap.add_child(IconSet.rect("hud_pack", 48))
	var full := GameState.pack_weight() >= GameState.pack_capacity()
	var rd := UiTheme.pixel_label("%d/%d" % [GameState.pack_weight(), GameState.pack_capacity()], UiTheme.PX_L, UiTheme.DANGER if full else UiTheme.AMBER)
	rd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_child(rd)
	var slow := 1.0 - GameState.carry_speed_mult()
	var info := UiTheme.body_label("Medicine weighs %d%s. Lost if you go down." % [MedicineDefs.MEDICINE_WEIGHT,
		(", slows you %d%%" % int(round(slow * 100.0))) if slow > 0.0 else ""], UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, floorf(minf(424.0, vp.y * 0.42) / 8.0) * 8.0)
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	list.add_child(UiTheme.head_label("PACK", UiTheme.T_H3, UiTheme.AMBER))
	var heavy := 0
	for id in GameState.run_pack.keys():
		if MedicineDefs.is_pouch(str(id)):
			continue
		heavy += 1
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiTheme.plate("inset", 8.0))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		row.add_child(h)
		h.add_child(IconSet.stuff_rect(str(id), 48))
		var nv := VBoxContainer.new()
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.alignment = BoxContainer.ALIGNMENT_CENTER
		nv.add_theme_constant_override("separation", 0)
		h.add_child(nv)
		nv.add_child(UiTheme.head_label("%s  x%d" % [MedicineDefs.item_name(str(id)).to_upper(), int(GameState.run_pack[id])], UiTheme.T_H3, UiTheme.TEXT))
		nv.add_child(UiTheme.body_label("Weight %d each" % MedicineDefs.weight(str(id)), UiTheme.T_SMALL, UiTheme.TEXT_DIM))
		var drop := UiTheme.big_button("DROP", UiTheme.RUST, 64, 20)
		drop.custom_minimum_size.x = 112
		drop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		drop.pressed.connect(drop_item.bind(str(id)))
		h.add_child(drop)
		list.add_child(row)
	if heavy == 0:
		list.add_child(UiTheme.body_label("Empty. Medicine crates are marked on the map, a new one each extract window.", UiTheme.T_SMALL, UiTheme.TEXT_DIM))
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 8)
	ph.add_child(UiTheme.head_label("INGREDIENT POUCH", UiTheme.T_H3, UiTheme.AMBER))
	ph.add_child(UiTheme.chip("weightless", UiTheme.TEAL))
	list.add_child(ph)
	var pouch := GameState.pouch()
	if pouch.is_empty():
		list.add_child(UiTheme.body_label("Nothing yet. Kills and crates drop ingredients for Cinder's tonics.", UiTheme.T_SMALL, UiTheme.TEXT_DIM))
	else:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 16)
		flow.add_theme_constant_override("v_separation", 8)
		list.add_child(flow)
		for id in pouch.keys():
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			h.add_child(IconSet.stuff_rect(str(id), 48))
			var nl := UiTheme.body_label("%s x%d" % [MedicineDefs.item_name(str(id)), int(pouch[id])], UiTheme.T_BODY, UiTheme.TEXT, false)
			nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(nl)
			flow.add_child(h)
	var done := UiTheme.big_button("DONE", UiTheme.LINE, 64, 24)
	done.pressed.connect(func() -> void:
		_dim.color = Color(0.04, 0.03, 0.02, 0.78)
		_show_main())
	v.add_child(done)
	_set_content(center)


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
