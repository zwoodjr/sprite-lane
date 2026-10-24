extends Control

## Top-down minimap: terrain bezel, then pixel icons (MapIcons) for mobs, elites,
## bosses, ground loot by rarity, medicine, ammo, lore pages, extract pads,
## events, radio jobs, cameos and POIs; a facing arrow for the hero; rim chevrons
## for important things beyond the map's range. Tap it for a legend.
## Gathers at ~10 Hz into preallocated buffers (no per-frame allocations).

@export var world_radius: float = 1000.0 ## world units shown from center to edge

const GATHER_DT := 0.1
const MAX_MOBS := 24
const MAX_ICONS := 96
const MAX_RIM := 7
const MAX_RIM_CAND := 32
const RIM_LABELS := 1
const PIXEL_FONT := "res://assets/fonts/PressStart2P.ttf"
const LEGEND_TIME := 8.0

var _player: Node2D
var _pads: Array = []
var _landmarks: Array = []
var _extract_open: bool = false
var _ping_t: float = 0.0
var _gather_t: float = 0.0
var _face: float = -PI * 0.5
var _layer: Control
var _font: Font
var _legend_t: float = 0.0
var _last_tap: int = -1000
var _events: Node = null
var _jobs: Node = null

## Icon buffers (world offsets from the hero, resolved to map space at draw).
var _n: int = 0
var _i_off := PackedVector2Array()
var _i_id := PackedInt32Array()
var _i_col := PackedColorArray()
var _i_k := PackedFloat32Array()
## Mobs: nearest MAX_MOBS (replace-farthest, no sort).
var _m_n: int = 0
var _m_off := PackedVector2Array()
var _m_d := PackedFloat32Array()
## Rim candidates, then the chosen few.
var _c_n: int = 0
var _c_ang := PackedFloat32Array()
var _c_id := PackedInt32Array()
var _c_col := PackedColorArray()
var _c_pri := PackedInt32Array()
var _c_dist := PackedFloat32Array()
var _r_n: int = 0
var _r_pick := PackedInt32Array()
## Pads currently on the map (for the ping rings).
var _p_n: int = 0
var _p_off := PackedVector2Array()
var _p_col := PackedColorArray()


func _init() -> void:
	_i_off.resize(MAX_ICONS)
	_i_id.resize(MAX_ICONS)
	_i_col.resize(MAX_ICONS)
	_i_k.resize(MAX_ICONS)
	_m_off.resize(MAX_MOBS)
	_m_d.resize(MAX_MOBS)
	_c_ang.resize(MAX_RIM_CAND)
	_c_id.resize(MAX_RIM_CAND)
	_c_col.resize(MAX_RIM_CAND)
	_c_pri.resize(MAX_RIM_CAND)
	_c_dist.resize(MAX_RIM_CAND)
	_r_pick.resize(MAX_RIM)
	_p_off.resize(8)
	_p_col.resize(8)


## New pads placed: rings pulse out from them for a few seconds.
func ping() -> void:
	_ping_t = 3.0
	_gather_t = GATHER_DT


func setup(player: Node2D, pads: Array, landmarks: Array) -> void:
	_player = player
	_pads = pads
	_landmarks = landmarks
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	if ResourceLoader.exists(PIXEL_FONT):
		_font = load(PIXEL_FONT)
	else:
		_font = UiTheme.font_button
	## Icons on a nearest-filtered child so the pixels stay crisp (the bezel art keeps linear).
	_layer = Control.new()
	_layer.name = "Icons"
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	_layer.draw.connect(_draw_icons)


func set_pads(pads: Array) -> void:
	_pads = pads


func set_landmarks(landmarks: Array) -> void:
	_landmarks = landmarks


func set_extract_open(is_open: bool) -> void:
	_extract_open = is_open
	_gather_t = GATHER_DT


func legend_visible() -> bool:
	return _legend_t > 0.0


func toggle_legend() -> void:
	_legend_t = 0.0 if _legend_t > 0.0 else LEGEND_TIME
	## Legend draws over the neighbouring HUD (phase strip) while it is up.
	z_index = 5 if _legend_t > 0.0 else 0
	if _layer:
		_layer.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tap := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		tap = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		tap = (event as InputEventScreenTouch).pressed
	if tap:
		accept_event()
		## Touch + emulated mouse can both arrive for one tap.
		var now := Time.get_ticks_msec()
		if now - _last_tap > 250:
			_last_tap = now
			toggle_legend()


func icon_count() -> int:
	return _n


func rim_count() -> int:
	return _r_n


## Debug / tests: icon ids currently on the map and on the rim.
func icon_ids() -> Array:
	var a: Array = []
	for i in range(_n):
		a.append(_i_id[i])
	return a


func rim_ids() -> Array:
	var a: Array = []
	for i in range(_r_n):
		a.append(_c_id[_r_pick[i]])
	return a


func _process(delta: float) -> void:
	_ping_t = maxf(0.0, _ping_t - delta)
	if _legend_t > 0.0:
		_legend_t = maxf(0.0, _legend_t - delta)
		if _legend_t <= 0.0 and _layer:
			z_index = 0
			_layer.queue_redraw()
	_gather_t += delta
	if _gather_t >= GATHER_DT:
		_gather_t = 0.0
		_gather()
		queue_redraw()
		if _layer:
			_layer.queue_redraw()
	elif _ping_t > 0.0 and _layer:
		_layer.queue_redraw()


func _map_r() -> float:
	var side := minf(size.x, size.y)
	return side * 0.5 * (80.0 / 96.0) if UiTheme.tex("minimap_bezel") else side * 0.5 - 4.0


## ---------------------------------------------------------------- gather ----

func _gather() -> void:
	_n = 0
	_m_n = 0
	_c_n = 0
	_r_n = 0
	_p_n = 0
	if _player == null or not is_instance_valid(_player):
		return
	var origin := _player.global_position
	if _player is CharacterBody2D:
		var v := (_player as CharacterBody2D).velocity
		if v.length_squared() > 100.0:
			_face = v.angle()
	var reach := world_radius * 0.94 ## icons past this go to the rim instead
	var tree := get_tree()
	_find_systems()
	## POIs (landmarks): terrain-level, drawn first.
	for lm in _landmarks:
		var off: Vector2 = Vector2(lm["position"]) - origin
		var lid := _landmark_icon(int(lm.get("kind", 0)))
		if off.length() <= reach:
			_add(off, lid, Color(MapIcons.C_POI, 0.7), 1.0)
	## Ground loot.
	for g in tree.get_nodes_in_group("gear_drops"):
		var gn := g as Node2D
		if gn == null or not is_instance_valid(gn):
			continue
		var off2 := gn.global_position - origin
		if off2.length() > reach:
			continue
		var it: Dictionary = gn.get("item") if gn.get("item") is Dictionary else {}
		var rar := str(it.get("rarity", "epic" if str(gn.get("material_id")) != "" else "common"))
		_add(off2, MapIcons.GEM, MapIcons.rarity_color(rar), 1.0)
	for p in tree.get_nodes_in_group("powerups"):
		var pn := p as Node2D
		if pn == null or not is_instance_valid(pn):
			continue
		var off3 := pn.global_position - origin
		if off3.length() > reach:
			continue
		var d: Dictionary = pn.get("def") if pn.get("def") is Dictionary else {}
		var pc: Color = d.get("color", Color.WHITE) if d.get("color") is Color else Color.WHITE
		_add(off3, MapIcons.AMMO if str(d.get("id", "")) == "ammo" else MapIcons.KEY, pc, 1.0)
	for c in tree.get_nodes_in_group("supply_crates"):
		var cn := c as Node2D
		if cn and is_instance_valid(cn) and (cn.global_position - origin).length() <= reach:
			_add(cn.global_position - origin, MapIcons.CRATE, MapIcons.C_CRATE, 1.0)
	for l in tree.get_nodes_in_group("lore_pages"):
		var ln := l as Node2D
		if ln and is_instance_valid(ln) and (ln.global_position - origin).length() <= reach:
			_add(ln.global_position - origin, MapIcons.PAGE, MapIcons.C_PAGE, 1.0)
	## Depth markers: medicine, bunkers, zone pickups (radio-job props/NPCs come from RadioJobs).
	for mk in tree.get_nodes_in_group("map_markers"):
		var mn := mk as Node2D
		if mn == null or not is_instance_valid(mn) or mn.is_in_group("cameos") or mn.is_in_group("enemies"):
			continue
		var id := -1
		var col := MapIcons.C_JOB
		var pri := 6
		if mn.is_in_group("medicine_crates"):
			id = MapIcons.CROSS
			col = MapIcons.C_MED
		elif mn.is_in_group("bunkers"):
			id = MapIcons.BUNKER
			col = MapIcons.C_BUNKER
		elif mn.is_in_group("zone_pickups"):
			id = MapIcons.KEY
			col = mn.get_meta("map_color") if mn.has_meta("map_color") else MapIcons.C_BUNKER
		elif _jobs == null:
			id = MapIcons.BANG
		if id < 0:
			continue
		var off4 := mn.global_position - origin
		if off4.length() <= reach:
			_add(off4, id, col, 1.0)
		elif id == MapIcons.BUNKER and off4.length() <= world_radius * 3.0:
			_cand(off4, id, col, pri)
	## Enemies: nearest mobs, every elite, bosses (bigger) and marked targets.
	var enemies := tree.get_nodes_in_group("enemies")
	for e in enemies:
		var en := e as Node2D
		if en == null or not is_instance_valid(en):
			continue
		var off5 := en.global_position - origin
		var dist := off5.length()
		var marked := en.is_in_group("hunt_target") or en.is_in_group("map_markers")
		var t := int(en.get("tier")) if "tier" in en else 1
		var boss := en.is_in_group("bosses") or t >= 3
		var elite := not boss and (en.is_in_group("elites") or t == 2)
		if dist > reach:
			if marked:
				_cand(off5, MapIcons.TARGET, MapIcons.C_HUNT, 2)
			elif boss:
				_cand(off5, MapIcons.SKULL_BIG, MapIcons.C_BOSS, 2)
			continue
		if boss or elite or marked:
			continue ## second pass, so they draw above the mobs
		_add_mob(off5, dist)
	for i in range(_m_n):
		_add(_m_off[i], MapIcons.SKULL, MapIcons.C_MOB, 1.0)
	for e in enemies:
		var en2 := e as Node2D
		if en2 == null or not is_instance_valid(en2):
			continue
		var off6 := en2.global_position - origin
		if off6.length() > reach:
			continue
		var t2 := int(en2.get("tier")) if "tier" in en2 else 1
		var boss2 := en2.is_in_group("bosses") or t2 >= 3
		var marked2 := en2.is_in_group("hunt_target") or en2.is_in_group("map_markers")
		if boss2:
			_add(off6, MapIcons.SKULL_BIG, MapIcons.C_BOSS, 2.0)
		elif en2.is_in_group("elites") or t2 == 2:
			_add(off6, MapIcons.SKULL_BIG, MapIcons.C_ELITE, 1.0)
		elif marked2:
			_add(off6, MapIcons.SKULL, MapIcons.C_MOB, 1.0)
		if marked2:
			_add(off6, MapIcons.TARGET, MapIcons.C_HUNT, 1.0)
	## Radio jobs (contracts / services / cameos).
	if _jobs and _jobs.has_method("map_targets"):
		for jt in _jobs.call("map_targets"):
			var off7: Vector2 = Vector2(jt["pos"]) - origin
			var jid := _job_icon(str(jt["id"]), str(jt.get("kind", "contract")))
			if off7.length() <= reach:
				_add(off7, jid, MapIcons.C_JOB, 1.0)
			else:
				_cand(off7, jid, MapIcons.C_JOB, 3)
	## In-run event.
	if _events and _events.has_method("map_target"):
		var ev: Dictionary = _events.call("map_target")
		if not ev.is_empty():
			var off8: Vector2 = Vector2(ev["pos"]) - origin
			var eid := _event_icon(str(ev["id"]))
			var ecol := MapIcons.C_HUNT if str(ev["id"]) == "elite_hunt" else MapIcons.C_EVENT
			if off8.length() <= reach:
				_add(off8, eid, ecol, 1.0)
			else:
				_cand(off8, eid, ecol, 1)
	## Extract pads.
	for pad in _pads:
		if not is_instance_valid(pad):
			continue
		var off9: Vector2 = (pad as Node2D).global_position - origin
		var last := bool(pad.get("last_chance"))
		var pcol := MapIcons.C_PAD_LAST if last else (MapIcons.C_PAD_OPEN if _extract_open else MapIcons.C_PAD_SEALED)
		## Campaign objective markers carry their own glyph (meta "map_glyph").
		var pg := MapIcons.PAD
		if (pad as Node).has_meta("map_glyph"):
			pg = int((pad as Node).get_meta("map_glyph"))
			pcol = Color("5cd2c0")
		if off9.length() <= reach:
			_add(off9, pg, pcol, 1.0)
			if _p_n < _p_off.size():
				_p_off[_p_n] = off9
				_p_col[_p_n] = pcol
				_p_n += 1
		else:
			_cand(off9, pg, pcol, 0 if (_extract_open or last) else 5)
	_pick_rim()


func _find_systems() -> void:
	if _events != null and is_instance_valid(_events) and _jobs != null and is_instance_valid(_jobs):
		return
	var roots: Array = []
	if get_tree().current_scene:
		roots.append(get_tree().current_scene)
	if _player.get_parent() and _player.get_parent().get_parent():
		roots.append(_player.get_parent().get_parent())
	for r in roots:
		var ev := (r as Node).get_node_or_null("RunEvents")
		var jb := (r as Node).get_node_or_null("RadioJobs")
		if ev and (_events == null or not is_instance_valid(_events)):
			_events = ev
		if jb and (_jobs == null or not is_instance_valid(_jobs)):
			_jobs = jb


func _add(off: Vector2, id: int, col: Color, k: float) -> void:
	if _n >= MAX_ICONS:
		return
	_i_off[_n] = off
	_i_id[_n] = id
	_i_col[_n] = col
	_i_k[_n] = k
	_n += 1


func _add_mob(off: Vector2, d: float) -> void:
	if _m_n < MAX_MOBS:
		_m_off[_m_n] = off
		_m_d[_m_n] = d
		_m_n += 1
		return
	var far := 0
	for i in range(1, MAX_MOBS):
		if _m_d[i] > _m_d[far]:
			far = i
	if d < _m_d[far]:
		_m_off[far] = off
		_m_d[far] = d


func _cand(off: Vector2, id: int, col: Color, pri: int) -> void:
	if _c_n >= MAX_RIM_CAND:
		return
	_c_ang[_c_n] = off.angle()
	_c_id[_c_n] = id
	_c_col[_c_n] = col
	_c_pri[_c_n] = pri
	_c_dist[_c_n] = off.length()
	_c_n += 1


## Best MAX_RIM candidates by priority then distance; skip ones crowding a better marker.
func _pick_rim() -> void:
	_r_n = 0
	for _round in range(MAX_RIM):
		var best := -1
		for i in range(_c_n):
			if _taken(i):
				continue
			if best < 0 or _c_pri[i] < _c_pri[best] or (_c_pri[i] == _c_pri[best] and _c_dist[i] < _c_dist[best]):
				best = i
		if best < 0:
			return
		_r_pick[_r_n] = best
		_r_n += 1


func _taken(i: int) -> bool:
	for k in range(_r_n):
		var j := _r_pick[k]
		if j == i:
			return true
		if absf(angle_difference(_c_ang[i], _c_ang[j])) < 0.22:
			return true
	return false


func _landmark_icon(kind: int) -> int:
	match kind:
		1: return MapIcons.GARAGE
		2: return MapIcons.TOWER
		3: return MapIcons.MARKET
	return MapIcons.WRECK


func _job_icon(id: String, kind: String) -> int:
	match id:
		"bounty": return MapIcons.TARGET
		"medicine_cache": return MapIcons.CROSS
		"black_box": return MapIcons.PLANE
		"field_tent", "rescue": return MapIcons.TENT
		"black_market": return MapIcons.MARKET
		"overwatch", "defend_relay": return MapIcons.TOWER
		"vault": return MapIcons.VAULT
		"care_package": return MapIcons.CRATE
	return MapIcons.TENT if kind == "cameo" else MapIcons.BANG


func _event_icon(id: String) -> int:
	match id:
		"supply_crash": return MapIcons.CRATE
		"elite_hunt": return MapIcons.TARGET
	return MapIcons.BANG


## ---------------------------------------------------------------- draw ----

func _draw() -> void:
	var r := size
	var center := r * 0.5
	var side := minf(r.x, r.y)
	## Painted brass bezel (192 px art: rim 82..95 of a 96 radius).
	var bezel := UiTheme.tex("minimap_bezel")
	var map_r := _map_r()
	if bezel:
		draw_texture_rect(bezel, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false)
	else:
		draw_circle(center, map_r, Color(0.22, 0.16, 0.11, 0.75))
		draw_arc(center, map_r, 0, TAU, 48, Color(0.85, 0.65, 0.3, 0.8), 2.0, true)
	## Faint range ring at half radius helps read distance.
	draw_arc(center, map_r * 0.5, 0, TAU, 40, Color(1, 0.9, 0.7, 0.10), 1.0, true)


func _draw_icons() -> void:
	var r := size
	var center := (r * 0.5).round()
	var map_r := _map_r()
	var scale_k := map_r / world_radius
	var ci: CanvasItem = _layer
	for i in range(_n):
		var p := center + _i_off[i] * scale_k
		MapIcons.draw(ci, _i_id[i], p, _i_col[i], _i_k[i])
	## Ping rings on freshly placed pads.
	if _ping_t > 0.0:
		var ph := fmod(3.0 - _ping_t, 1.0)
		for i in range(_p_n):
			var pc := _p_col[i]
			ci.draw_arc(center + _p_off[i] * scale_k, 5.0 + ph * 16.0, 0.0, TAU, 24, Color(pc.r, pc.g, pc.b, 1.0 - ph), 2.0, true)
	## Rim chevrons + icons for the important things out of range.
	var labels := 0
	for k in range(_r_n):
		var j := _r_pick[k]
		var dir := Vector2.from_angle(_c_ang[j])
		var col := _c_col[j]
		var tip := center + dir * (map_r + 1.0)
		MapIcons.draw_chevron(ci, tip, dir, col, 7.0, 5.0)
		var ip := center + dir * (map_r - 13.0)
		MapIcons.draw(ci, _c_id[j], ip, col, 1.0)
		if labels < RIM_LABELS and _c_pri[j] <= 3 and _font:
			labels += 1
			var txt := _dist_text(_c_dist[j])
			## Barlow Condensed at the iPhone floor (the 8-px pixel face was
			## unreadable; the 16-px one is too wide for the ring).
			var lf: Font = UiTheme.font_button if UiTheme.font_button else _font
			var fs := UiTheme.font_px(UiTheme.MIN_FONT)
			var tw := lf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			## Inside the ring, just past the rim icon: the whole text box stays
			## within the map circle (audit #10: labels poked outside the bezel).
			var hd := Vector2(tw * 0.5 + 2.0, fs * 0.4).length()
			var lc := center + dir * minf(map_r - 26.0, map_r - 3.0 - hd)
			var lp := (lc + Vector2(-tw * 0.5, fs * 0.35)).round()
			ci.draw_string_outline(lf, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, MapIcons.DARK)
			ci.draw_string(lf, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	## Hero: facing arrow.
	var f := Vector2.from_angle(_face)
	var o := f.orthogonal()
	var tip2 := center + f * 7.0
	var pts := PackedVector2Array([tip2, center - f * 4.0 + o * 5.0, center - f * 1.5, center - f * 4.0 - o * 5.0])
	var outl := PackedVector2Array([tip2 + f * 1.8, center - f * 5.5 + o * 6.8, center - f * 3.0, center - f * 5.5 - o * 6.8])
	ci.draw_colored_polygon(outl, MapIcons.DARK)
	ci.draw_colored_polygon(pts, MapIcons.C_PLAYER)
	## Status plate on the lower rim (fits inside the box at any size).
	## Campaign levels have no extract clock: no plate.
	if GameState.in_campaign_run():
		if _legend_t > 0.0:
			_draw_legend(ci)
		return
	var txt2 := "OPEN" if _extract_open else "SEALED"
	var fnt: Font = UiTheme.font_button
	var fs2 := UiTheme.font_px(UiTheme.MIN_FONT)
	var tw2 := fnt.get_string_size(txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	var ph := float(fs2) + 2.0
	var pr := Rect2(Vector2(center.x - tw2 * 0.5 - 6, r.y - ph + 6.0), Vector2(tw2 + 12, ph))
	ci.draw_rect(pr, Color(0.07, 0.05, 0.035, 0.92))
	ci.draw_rect(pr, Color(0.55, 0.4, 0.22, 0.9), false, 1.0)
	ci.draw_string(fnt, Vector2(pr.position.x + 6, pr.end.y - ph * 0.2), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2,
		MapIcons.C_PAD_OPEN if _extract_open else Color(0.78, 0.72, 0.62))
	if _legend_t > 0.0:
		_draw_legend(ci)


func _dist_text(d: float) -> String:
	var m := int(d / 10.0)
	if m >= 1000:
		return "%.1fk" % (m / 1000.0)
	return "%dm" % m


const LEGEND := [
	[MapIcons.SKULL, "MOB", "mob"], [MapIcons.SKULL_BIG, "ELITE", "elite"], [MapIcons.SKULL_BIG, "BOSS", "boss"],
	[MapIcons.GEM, "LOOT", "loot"], [MapIcons.CROSS, "MEDICINE", "med"], [MapIcons.AMMO, "AMMO", "ammo"],
	[MapIcons.PAGE, "LORE PAGE", "page"], [MapIcons.PAD, "EXTRACT", "pad"], [MapIcons.BANG, "EVENT", "event"],
	[MapIcons.BANG, "RADIO JOB", "job"], [MapIcons.TENT, "CAMEO", "job"], [MapIcons.TARGET, "TARGET", "hunt"],
	[MapIcons.BUNKER, "BUNKER", "bunker"], [MapIcons.TOWER, "POI", "poi"],
]


## Tiny legend to the left of the map (tap the map to hide). Nothing pauses.
func _draw_legend(ci: CanvasItem) -> void:
	var lfs := UiTheme.font_px(UiTheme.MIN_FONT)
	var row_h := float(lfs) + 4.0
	var w := 150.0 * UiTheme.text_scale
	var h := LEGEND.size() * row_h + 10.0
	var box := Rect2(Vector2(-w - 6.0, 0.0), Vector2(w, h))
	ci.draw_rect(box, Color(0.06, 0.045, 0.03, 0.9))
	ci.draw_rect(box, Color(0.55, 0.4, 0.22, 0.9), false, 1.0)
	var y := box.position.y + 5.0 + row_h * 0.5
	for row in LEGEND:
		var ix := box.position.x + 10.0
		var tag := str(row[2])
		if tag == "loot":
			var k := 0
			for rar in ["common", "rare", "epic", "legendary"]:
				MapIcons.draw(ci, MapIcons.GEM, Vector2(ix - 3.0 + k * 6.0, y), MapIcons.rarity_color(rar), 1.0)
				k += 1
		elif tag == "pad":
			MapIcons.draw(ci, MapIcons.PAD, Vector2(ix - 3.0, y), MapIcons.C_PAD_OPEN, 1.0)
			MapIcons.draw(ci, MapIcons.PAD, Vector2(ix + 7.0, y), MapIcons.C_PAD_SEALED, 1.0)
		else:
			MapIcons.draw(ci, int(row[0]), Vector2(ix, y), _legend_col(tag), 1.0)
		var tx := box.position.x + (34.0 if tag == "loot" or tag == "pad" else 22.0)
		ci.draw_string(UiTheme.font_button, Vector2(tx, y + lfs * 0.35).round(), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(0.9, 0.85, 0.75))
		y += row_h


func _legend_col(tag: String) -> Color:
	match tag:
		"mob": return MapIcons.C_MOB
		"elite": return MapIcons.C_ELITE
		"boss": return MapIcons.C_BOSS
		"med": return MapIcons.C_MED
		"ammo": return Color(1.0, 0.55, 0.25)
		"page": return MapIcons.C_PAGE
		"event": return MapIcons.C_EVENT
		"job": return MapIcons.C_JOB
		"hunt": return MapIcons.C_HUNT
		"bunker": return MapIcons.C_BUNKER
	return MapIcons.C_POI
