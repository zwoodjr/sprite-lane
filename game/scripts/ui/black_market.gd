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
	dim.color = Color(0.04, 0.03, 0.02, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.plate("panel_hi", 24.0))
	var vp := get_viewport().get_visible_rect().size
	plate.custom_minimum_size = Vector2(minf(620.0, vp.x - 40.0), 0)
	center.add_child(plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	plate.add_child(v)
	v.add_child(UiTheme.title_label("NYX'S BLACK MARKET", 36))
	var sub := UiTheme.body_label("\"Scrap up front. No refunds, no questions.\"", 15, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_scrap = UiTheme.body_label("", 18, UiTheme.AMBER)
	_scrap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_scrap)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	v.add_child(_list)
	var leave := UiTheme.big_button("LEAVE", UiTheme.TEAL, 64, 22)
	leave.pressed.connect(close)
	v.add_child(leave)
	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_scrap.text = "Bag scrap: %d" % GameState.scrap_found
	for it in RadioDefs.MARKET:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiTheme.body_label(str(it["name"]), 19, UiTheme.AMBER, false))
		info.add_child(UiTheme.body_label(str(it["desc"]), 14, UiTheme.TEXT))
		row.add_child(info)
		var owned := str(it["id"]) == "lock" and GameState.run_pack_locked
		var can := GameState.scrap_found >= int(it["cost"]) and not owned
		var b := UiTheme.big_button("OWNED" if owned else "%d" % int(it["cost"]), UiTheme.TEAL if can else UiTheme.RUST, 56, 19)
		b.custom_minimum_size.x = 110
		b.disabled = not can
		b.pressed.connect(buy.bind(str(it["id"])))
		row.add_child(b)
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
