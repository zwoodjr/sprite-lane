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
var _hold: float = 0.0
var _tick_t: float = 0.0
var _crew: Node = null
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
	## Onboarding: radio events switch on after the first finished run.
	if not GameState.feature_on("events"):
		_times.clear()
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
		## Late pool (and tier gates) via EventDefs.pool.
		var ok := EventDefs.pool(GameState.onboarding_done(), int(GameState.get_mode().get("tier", 1)))
		for k in EventDefs.IN_RUN.keys():
			if not str(k) in ok and not str(k) in skip:
				skip.append(str(k))
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
		"toxic_rain":
			_target_pos = _spot(_def["distance"])
			_zone = _make_zone(_target_pos, float(_def["radius"]), Color(0.55, 0.9, 1.0))
			_overlay = _tint_overlay(Color(0.35, 0.55, 0.15, 0.0), 0.22)
			_tick_t = float(_def["tick"])
		"caravan_wreck":
			_target_pos = _spot(_def["distance"])
			for i in range(int(_def["crates"])):
				HaulPickup.spawn(world, _target_pos + Vector2(-24 + 48 * i, 0), "medicine", 1, false)
			LootDrop.spawn_burst(world, _target_pos + Vector2(0, 30), "scrap", 4, float(_def["scrap"]))
			_zone = _make_zone(_target_pos, 60.0, Color(1.0, 0.45, 0.4))
			_left = 9999.0
		"distress_flare":
			_target_pos = _spot(_def["distance"])
			_zone = _make_zone(_target_pos, float(_def["radius"]), Color(1.0, 0.4, 0.3))
			RunFx.ring(world, _target_pos, 200.0, Color(1.0, 0.4, 0.3), 1.0, 6.0)
		"raider_ambush":
			var a2 := rng.randf() * TAU
			_crew = match_ctl.call("spawn_crew", player.global_position + Vector2(cos(a2), sin(a2)) * 520.0) if match_ctl.has_method("spawn_crew") else null
			if _crew == null:
				_finish(false)
				return
		"helms_wager":
			_target_pos = _spot(_def["distance"])
			_zone = _make_zone(_target_pos, float(_def["radius"]), Color(1.0, 0.78, 0.3))
			_hold = 0.0
		"plague_nest":
			_target_pos = _spot(_def["distance"])
			var nest: Node = match_ctl.call("spawn_at", "elite", str(_def["kind"]), _target_pos) if match_ctl.has_method("spawn_at") else null
			if nest == null:
				_finish(false)
				return
			nest.set("display_name", "Plague Nest")
			nest.set("speed", 0.0)
			nest.add_to_group("map_markers")
			_target_node = nest as Node2D
			nest.connect("died", _on_nest_killed)
			_tick_t = float(_def["every"])
			_left = float(_def["max"])


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
		"toxic_rain":
			var under := player.global_position.distance_to(_target_pos) <= float(_def["radius"])
			GameState.event_scrap_mult = 1.0 if under else float(_def["scrap_mult"])
			_tick_t -= delta
			if _tick_t <= 0.0:
				_tick_t = float(_def["tick"])
				if not under and player.has_method("drain"):
					player.call("drain", float(_def["drain"]))
			_chip.text = "TOXIC RAIN  %ds  %s" % [ceili(_left), "SHELTERED" if under else "×1.5 SCRAP, BURNING"]
			if _left <= 0.0:
				_finish(true)
		"caravan_wreck":
			_chip.text = "CARAVAN WRECK — medicine crates"
			if player.global_position.distance_to(_target_pos) < 70.0:
				_finish(true)
		"distress_flare":
			_chip.text = "DISTRESS FLARE  %ds" % ceili(_left)
			if player.global_position.distance_to(_target_pos) <= float(_def["radius"]):
				GameState.scrap_found += int(_def["bonus_scrap"])
				for i in range(int(_def["tonics"])):
					LootDrop.spawn_burst(world, _target_pos + Vector2(rng.randf_range(-30, 30), 10), "tonic", 1, float(_def["heal"]))
				for i in range(int(_def["wave"])):
					if match_ctl.has_method("spawn_mob"):
						match_ctl.call("spawn_mob", "", _target_pos + Vector2.RIGHT.rotated(TAU * i / float(_def["wave"])) * 300.0)
				hud.show_toast("Flare reached: +%d bag scrap — and company" % int(_def["bonus_scrap"]), UiTheme.AMBER)
				_finish(true)
			elif _left <= 0.0:
				_finish(false)
		"raider_ambush":
			var alive := false
			if _crew != null and is_instance_valid(_crew) and not bool(_crew.get("done")):
				for m in (_crew.get("members") as Array):
					if is_instance_valid(m) and not bool(m.get("_dead")):
						alive = true
						break
			_chip.text = "RAIDER AMBUSH  %ds" % ceili(_left)
			if not alive:
				GameState.scrap_found += int(_def["bonus_scrap"])
				hud.show_toast("Crew broken: +%d bag scrap" % int(_def["bonus_scrap"]), UiTheme.AMBER)
				_finish(true)
			elif _left <= 0.0:
				hud.show_toast("The crew lost interest.", UiTheme.TEXT_DIM)
				_finish(false)
		"helms_wager":
			var inside := player.global_position.distance_to(_target_pos) <= float(_def["radius"])
			_hold = _hold + delta if inside else 0.0
			_chip.text = "HELM'S WAGER  %s" % ("%.1fs" % maxf(0.0, float(_def["hold"]) - _hold) if inside else "%ds to decide" % ceili(_left))
			if _hold >= float(_def["hold"]):
				GameState.boss_loot_bonus += float(_def["loot"])
				GameState.windows_skipped += int(_def["greed"])
				hud.show_toast("Wager taken: loot +%.1f, Greed +%d" % [float(_def["loot"]), int(_def["greed"])], UiTheme.RUST)
				Juice.shake(0.2)
				_finish(true)
			elif _left <= 0.0:
				_finish(false)
		"plague_nest":
			_chip.text = "PLAGUE NEST — burn it or keep clear"
			if _target_node == null or not is_instance_valid(_target_node):
				if _active == "plague_nest":
					_finish(false)
				return
			_tick_t -= delta
			if _tick_t <= 0.0:
				_tick_t = float(_def["every"])
				for i in range(int(_def["spawn"])):
					if match_ctl.has_method("spawn_mob"):
						match_ctl.call("spawn_mob", "", _target_node.global_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * 80.0)
			if _left <= 0.0:
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


func _on_nest_killed() -> void:
	if _active != "plague_nest":
		return
	var pos := _target_node.global_position if _target_node != null and is_instance_valid(_target_node) else player.global_position
	GameState.scrap_found += int(_def["bonus_scrap"])
	GearPickup.spawn(world, pos, GearDefs.roll_drop(int(GameState.get_mode().get("tier", 1)), GameState.selected_character_id,
		GameState.gear_luck(), rng, "", str(_def["bonus_min_rarity"])))
	hud.show_toast("Nest burned: +%d bag scrap and a drop" % int(_def["bonus_scrap"]), UiTheme.AMBER)
	_target_node = null
	_finish(true)


func _tint_overlay(col: Color, alpha: float) -> ColorRect:
	var o := ColorRect.new()
	o.color = col
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ol := CanvasLayer.new()
	ol.layer = 2
	add_child(ol)
	ol.add_child(o)
	o.create_tween().tween_property(o, "color:a", alpha, 1.2)
	return o


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
