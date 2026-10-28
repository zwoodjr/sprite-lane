extends Node

## In-run events (brief Part 8): 1–2 per run, announced over Helm's radio.
## Owned by the match controller; numbers live in EventDefs.IN_RUN.

const CRATE_TEX := "res://assets/sprites/pickups/supply_crate.png"
const HERB_COLOR := Color(0.55, 1.0, 0.5)

var match_ctl: Node
var player: Node2D
var world: Node2D
var hud: Node

var _times: Array = []        ## run seconds when the next events fire
var _done_ids: Array = []
var _active: String = ""
var _def: Dictionary = {}
var _left: float = 0.0
var _target_pos: Vector2 = Vector2.INF
var _target_node: Node2D = null
var _zone: Node2D = null
var _crate: Sprite2D = null
var _overlay: ColorRect = null
var _layer: CanvasLayer
var _radio: PanelContainer
var _radio_text: Label
var _radio_left: float = 0.0
var _chip: Label
var _arrow: Control
var _t: float = 0.0
var _entered_zone: bool = false
var rng := RandomNumberGenerator.new()


func setup(ctl: Node, p: Node2D, w: Node2D, h: Node) -> void:
	match_ctl = ctl
	player = p
	world = w
	hud = h
	rng.seed = GameState.run_seed ^ 0x5eed
	var ts := GameState.timer_scale()
	var n := rng.randi_range(EventDefs.EVENTS_PER_RUN.x, EventDefs.EVENTS_PER_RUN.y)
	_times = [rng.randf_range(EventDefs.FIRST_EVENT_AT.x, EventDefs.FIRST_EVENT_AT.y) * ts]
	if n >= 2:
		_times.append(rng.randf_range(EventDefs.SECOND_EVENT_AT.x, EventDefs.SECOND_EVENT_AT.y) * ts)
	_build_ui()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	_radio = PanelContainer.new()
	_radio.add_theme_stylebox_override("panel", UiTheme.plate("panel_steel", 14.0, Color(0.85, 1.0, 0.85, 0.95)))
	_radio.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	## Left of the minimap / loot / kill-chain column so it never covers them.
	var sm := MobileLayout.control_safe_margin()
	var vpw := 720.0
	if get_viewport():
		vpw = get_viewport().get_visible_rect().size.x
	var col_w := minf(135.0, vpw * 0.3) + 40.0 + 12.0
	_radio.offset_left = sm.position.x
	_radio.offset_right = -(col_w + (vpw - sm.position.x - sm.size.x))
	_radio.offset_top = sm.position.y + 150.0
	_radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radio.visible = false
	_layer.add_child(_radio)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radio.add_child(v)
	var head := UiTheme.body_label("HELM — RADIO", 15, Color(0.55, 0.95, 0.6), false)
	v.add_child(head)
	_radio_text = UiTheme.body_label("", 16, UiTheme.TEXT)
	v.add_child(_radio_text)
	_chip = UiTheme.body_label("", 17, UiTheme.AMBER, false)
	_chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_chip.offset_top = 238
	_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chip.visible = false
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_chip)
	_arrow = Control.new()
	_arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arrow.draw.connect(_draw_arrow)
	_layer.add_child(_arrow)


func radio(text: String) -> void:
	_radio_text.text = text
	_radio.visible = true
	_radio.modulate.a = 1.0
	_radio_left = 6.0
	Juice.sfx("radio_chatter")


func active_event() -> String:
	return _active


## Minimap: where the active event wants you ({} when there is no place to go).
func map_target() -> Dictionary:
	if _active == "":
		return {}
	var tgt := _target_pos
	if _target_node != null and is_instance_valid(_target_node):
		tgt = _target_node.global_position
	if tgt == Vector2.INF:
		return {}
	return {"pos": tgt, "id": _active}


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or GameState.run_finished:
		return
	_t += delta
	if _radio_left > 0.0:
		_radio_left -= delta
		_radio.modulate.a = clampf(_radio_left / 0.6, 0.0, 1.0)
		if _radio_left <= 0.0:
			_radio.visible = false
	var mt := float(match_ctl.get("_match_time"))
	if _active == "" and not _times.is_empty() and mt >= float(_times[0]):
		_times.pop_front()
		## No elites before ModeDefs.ELITE_FROM_TIER, so no Elite Hunt there either.
		var skip: Array = _done_ids.duplicate()
		if int(GameState.get_mode().get("tier", 1)) < ModeDefs.ELITE_FROM_TIER:
			skip.append("elite_hunt")
		start_event(EventDefs.roll_event(rng, skip))
	if _active != "":
		_tick_event(delta)
	_arrow.queue_redraw()


## Starts an event now (also used by tests / the bot).
func start_event(id: String) -> void:
	if _active != "":
		_finish(false)
	_def = EventDefs.get_in_run(id)
	if _def.is_empty():
		return
	_active = id
	_done_ids.append(id)
	_left = float(_def.get("duration", 25.0)) * maxf(GameState.timer_scale(), 0.35)
	_target_pos = Vector2.INF
	_target_node = null
	_entered_zone = false
	hud.show_banner(str(_def["name"]).to_upper(), "Helm on the radio", Color(0.55, 1.0, 0.6))
	radio(str(_def["radio"]))
	match id:
		"scrap_spike":
			_target_pos = _spot(_def["distance"])
			_zone = _make_zone(_target_pos, float(_def["radius"]), Color(1.0, 0.78, 0.3))
		"pad_heat":
			match_ctl.call("heat_next_window", float(_def["open_in"]), int(_def["guards"]))
			_left = 9999.0
		"herb_bloom":
			for i in range(int(_def["count"])):
				LootDrop.spawn_burst(world, _spot(_def["distance"]), "tonic", 1, float(_def["heal"]))
			RunFx.ring(world, player.global_position, 160.0, HERB_COLOR, 0.6, 4.0)
		"supply_crash":
			_target_pos = _spot(_def["distance"])
			_crate = Sprite2D.new()
			_crate.texture = load(CRATE_TEX)
			_crate.scale = Vector2.ONE * (46.0 / float(_crate.texture.get_width()))
			_crate.global_position = _target_pos + Vector2(0, -420)
			world.add_child(_crate)
			var tw := _crate.create_tween()
			tw.tween_property(_crate, "global_position", _target_pos, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void:
				Juice.dust_puff(_target_pos + Vector2(0, 10), 16)
				Juice.shake(0.2))
			_zone = _make_zone(_target_pos, 46.0, Color(0.6, 0.9, 1.0))
			var es: PackedScene = load("res://scenes/entities/enemy.tscn")
			for i in range(int(_def["pack"])):
				var e: CharacterBody2D = es.instantiate()
				var a := TAU * float(i) / float(_def["pack"])
				e.call("setup", _target_pos + Vector2(cos(a), sin(a)) * 150.0, 1.0, 1.0, 1.1, str(_def["pack_kind"]))
				world.add_child(e)
			_left = 9999.0
		"dust_surge":
			GameState.event_enemy_damage = float(_def["enemy_damage"])
			_overlay = ColorRect.new()
			_overlay.color = Color(0.3, 0.2, 0.1, 0.0)
			_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var ol := CanvasLayer.new()
			ol.layer = 2
			add_child(ol)
			ol.add_child(_overlay)
			_overlay.create_tween().tween_property(_overlay, "color:a", float(_def["dark"]), 1.2)
		"elite_hunt":
			var e2: Node = match_ctl.call("spawn_special", "elite")
			if e2 != null:
				_target_node = e2 as Node2D
				e2.add_to_group("hunt_target")
				e2.connect("died", _on_hunt_killed)
			_left = 9999.0


func _tick_event(delta: float) -> void:
	_left -= delta
	match _active:
		"scrap_spike":
			var inside := player.global_position.distance_to(_target_pos) <= float(_def["radius"])
			GameState.event_scrap_mult = float(_def["scrap_mult"]) if inside else 1.0
			if inside and not _entered_zone:
				_entered_zone = true
				hud.show_toast("Scrap Spike: double scrap in here!", UiTheme.AMBER)
			_chip.text = "SCRAP SPIKE  %ds%s" % [ceili(_left), "  ×2 SCRAP" if inside else ""]
			if _left <= 0.0:
				_finish(_entered_zone)
		"pad_heat":
			_chip.text = "PAD HEAT — pads open early"
			if bool(match_ctl.call("is_extract_open")):
				_finish(true)
		"herb_bloom":
			_chip.text = "HERB BLOOM  %ds" % ceili(_left)
			if _left <= 0.0:
				_finish(true)
		"supply_crash":
			_chip.text = "SUPPLY CRASH — reach the crate"
			if player.global_position.distance_to(_target_pos) < 50.0:
				var it := GearDefs.roll_drop(int(GameState.get_mode().get("tier", 1)), GameState.selected_character_id,
					GameState.gear_luck(), rng, "", str(_def["min_rarity"]))
				GearPickup.spawn(world, _target_pos + Vector2(0, -10), it)
				if _crate:
					Juice.burst(_target_pos, Color(0.6, 0.9, 1.0), 20, 200.0, 0.5)
					_crate.queue_free()
					_crate = null
				_finish(true)
		"dust_surge":
			_chip.text = "DUST SURGE — hold on %ds" % ceili(_left)
			if _left <= 0.0:
				GameState.scrap_found += int(_def["bonus_scrap"])
				hud.show_toast("Surge passed: +%d bag scrap" % int(_def["bonus_scrap"]), UiTheme.AMBER)
				_finish(true)
		"elite_hunt":
			_chip.text = "ELITE HUNT — take it down"
			if _target_node == null or not is_instance_valid(_target_node):
				_finish(false)
	_chip.visible = _active != ""


func _on_hunt_killed() -> void:
	if _active != "elite_hunt":
		return
	var pos := _target_node.global_position if _target_node != null and is_instance_valid(_target_node) else player.global_position
	GameState.scrap_found += int(_def["bonus_scrap"])
	GearPickup.spawn(world, pos, GearDefs.roll_drop(int(GameState.get_mode().get("tier", 1)), GameState.selected_character_id,
		GameState.gear_luck(), rng, "", str(_def["bonus_min_rarity"])))
	hud.show_toast("Hunt done: +%d bag scrap and a bounty drop" % int(_def["bonus_scrap"]), UiTheme.AMBER)
	_target_node = null
	_finish(true)


func _finish(success: bool) -> void:
	var was := _active
	_active = ""
	_chip.visible = false
	GameState.event_scrap_mult = 1.0
	GameState.event_enemy_damage = 1.0
	if _zone and is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	if _crate and is_instance_valid(_crate):
		_crate.queue_free()
	_crate = null
	if _overlay and is_instance_valid(_overlay):
		var tw := _overlay.create_tween()
		tw.tween_property(_overlay, "color:a", 0.0, 0.8)
		tw.tween_callback(_overlay.get_parent().queue_free)
	_overlay = null
	_target_pos = Vector2.INF
	if success and was != "":
		GameState.events_done_run += 1
		GameState.quest_event("event")


func _spot(range_v: Vector2) -> Vector2:
	var a := rng.randf() * TAU
	return player.global_position + Vector2(cos(a), sin(a)) * rng.randf_range(range_v.x, range_v.y)


func _make_zone(pos: Vector2, r: float, col: Color) -> Node2D:
	var z := Node2D.new()
	z.global_position = pos
	z.z_index = -1
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(41):
		var a := TAU * i / 40.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.6))
	ring.points = pts
	ring.width = 4.0
	ring.default_color = Color(col.r, col.g, col.b, 0.8)
	z.add_child(ring)
	var fill := Polygon2D.new()
	fill.polygon = pts
	fill.color = Color(col.r, col.g, col.b, 0.12)
	z.add_child(fill)
	world.add_child(z)
	var tw := ring.create_tween().set_loops()
	tw.tween_property(ring, "modulate:a", 0.4, 0.6)
	tw.tween_property(ring, "modulate:a", 1.0, 0.6)
	return z


## Screen-edge arrow toward the event's target when it's off screen.
func _draw_arrow() -> void:
	var tgt := _target_pos
	if _target_node != null and is_instance_valid(_target_node):
		tgt = _target_node.global_position
	if _active == "" or tgt == Vector2.INF or player == null or not is_instance_valid(player):
		return
	var vp := _arrow.get_viewport()
	var sp: Vector2 = vp.get_canvas_transform() * tgt
	var r := vp.get_visible_rect().grow(-40.0)
	if r.has_point(sp):
		return
	var c := r.get_center()
	var d := (sp - c).normalized()
	var tx := INF if absf(d.x) < 0.001 else (r.size.x * 0.5) / absf(d.x)
	var ty := INF if absf(d.y) < 0.001 else (r.size.y * 0.5) / absf(d.y)
	var p := c + d * minf(tx, ty)
	## Same icon language as the minimap: cyan "!" (crate / crosshair for those events).
	var hunt := _active == "elite_hunt"
	var col := MapIcons.C_HUNT if hunt else MapIcons.C_EVENT
	var icon := MapIcons.TARGET if hunt else (MapIcons.CRATE if _active == "supply_crash" else MapIcons.BANG)
	MapIcons.draw_chevron(_arrow, p + d * 18.0, d, col, 16.0, 11.0)
	MapIcons.draw(_arrow, icon, p - d * 14.0, col, 2.0)
