extends CanvasLayer

## Nyx's black market (Depth E4): pauses the run; spend the bag's scrap on a
## medkit, a can of special ammo, a Pack Lock or an extra reroll.

var _jobs: Node
var _list: VBoxContainer
var _scrap: Label
var bought: int = 0


func open(jobs: Node) -> void:
	_jobs = jobs
	layer = 41
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	TouchInput.clear_sticks()
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.INK, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	## Style bible + Track D: worn plate, icon-led rows, value in DUST amber
	## (pixel readout), amber primary price buttons, steel secondary LEAVE.
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.plate("panel_hi", 24.0))
	var vp := get_viewport().get_visible_rect().size
	plate.custom_minimum_size = Vector2(floorf(minf(624.0, vp.x - 48.0) / 8.0) * 8.0, 0)
	center.add_child(plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	plate.add_child(v)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	v.add_child(head)
	head.add_child(UiTheme.title_label("BLACK MARKET", 40))
	var sub := UiTheme.body_label("Nyx: \"Scrap up front. No refunds, no questions.\"", UiTheme.T_SMALL, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(sub)
	var bag := HBoxContainer.new()
	bag.alignment = BoxContainer.ALIGNMENT_CENTER
	bag.add_theme_constant_override("separation", 8)
	v.add_child(bag)
	bag.add_child(UiTheme.head_label("BAG", UiTheme.T_H3, UiTheme.TEXT_DIM))
	bag.add_child(IconSet.rect("cur_scrap", 48))
	_scrap = UiTheme.pixel_label("", UiTheme.PX_L, UiTheme.AMBER)
	_scrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bag.add_child(_scrap)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	v.add_child(_list)
	var leave := UiTheme.big_button("LEAVE", UiTheme.LINE, 64, 24)
	leave.pressed.connect(close)
	v.add_child(leave)
	_rebuild()


const ICONS := {"medkit": "ing_medicine", "ammo": "ammo_explosive", "lock": "hud_pack", "reroll": "up_lucky_vial"}


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_scrap.text = "%d" % GameState.scrap_found
	for it in RadioDefs.MARKET:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiTheme.plate("inset", 8.0))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		row.add_child(h)
		h.add_child(UiTheme.icon_well(str(ICONS.get(str(it["id"]), "cur_scrap")), "common", 64))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_theme_constant_override("separation", 0)
		info.add_child(UiTheme.head_label(str(it["name"]).to_upper(), UiTheme.T_H2, UiTheme.TEXT))
		info.add_child(UiTheme.body_label(str(it["desc"]), UiTheme.T_SMALL, UiTheme.TEXT_DIM))
		h.add_child(info)
		var owned := str(it["id"]) == "lock" and GameState.run_pack_locked
		var can := GameState.scrap_found >= int(it["cost"]) and not owned
		var b := UiTheme.big_button("OWNED" if owned else "%d" % int(it["cost"]), UiTheme.AMBER, 64, 24)
		if not owned:
			b.icon = IconSet.tex("cur_scrap", false)
			b.add_theme_constant_override("h_separation", 8)
		b.custom_minimum_size.x = 136
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = not can
		b.pressed.connect(buy.bind(str(it["id"])))
		h.add_child(b)
		_list.add_child(row)


func buy(id: String) -> bool:
	var it: Dictionary = {}
	for m in RadioDefs.MARKET:
		if str(m["id"]) == id:
			it = m
	if it.is_empty() or GameState.scrap_found < int(it["cost"]):
		return false
	var p := get_tree().get_first_node_in_group("player") as Node2D
	match id:
		"medkit":
			if p:
				p.call("heal", float(p.get("max_hp")) * float(it["heal_frac"]))
		"ammo":
			if p:
				p.call("apply_powerup", RunFx.ammo_def(RunFx.random_ammo_id()))
		"lock":
			if GameState.run_pack_locked:
				return false
			GameState.run_pack_locked = true
		"reroll":
			GameState.run_rerolls_left += 1
	GameState.scrap_found -= int(it["cost"])
	bought += 1
	Juice.sfx("ui_purchase")
	if _jobs and is_instance_valid(_jobs):
		_jobs.call("on_market_buy")
	_rebuild()
	return true


func close() -> void:
	get_tree().paused = false
	queue_free()
