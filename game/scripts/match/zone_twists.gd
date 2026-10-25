extends Node

## Depth E7: the tier's zone twists (ZoneDefs.ZONES[tier]["twists"]). Owned by
## the match controller. Each twist is a small block below; the enemy side
## (phasing, revive, enraged machines, infected bursts) lives in enemy.gd and
## the dead pads in extract_pad.gd.

const PlagueZoneScript := preload("res://scripts/entities/plague_zone.gd")
const ZONE_DIR := "res://assets/sprites/depth/zone/%s.png"
const PickupScript := preload("res://scripts/entities/zone_pickup.gd")
const BunkerScript := preload("res://scripts/entities/zone_bunker.gd")
const NIGHT_SHADER := """
shader_type canvas_item;
uniform vec2 center = vec2(360.0, 640.0);
uniform vec2 screen = vec2(720.0, 1280.0);
uniform float radius = 230.0;
uniform float dark = 0.86;
void fragment() {
	vec2 p = SCREEN_UV * screen;
	float d = distance(p, center);
	float a = smoothstep(radius * 0.55, radius, d) * dark;
	COLOR = vec4(0.015, 0.02, 0.05, a);
}
"""

var match_ctl: Node
var player: Node2D
var world: Node2D
var hud: Node
var tier: int = 1
var twists: Array = []
var rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _origin: Vector2 = Vector2.ZERO
## Twist strength on this tier (ZoneDefs.strength: Dustfall softens its full stack).
var power: float = 1.0

## Smog patches: [{node, r, life}].
var smog: Array = []
## Night.
var _night: CanvasLayer
var _night_mat: ShaderMaterial
var flare_left: float = 0.0
## Wraith phase clock.
var _phase_t: float = 0.0
var _phasing: bool = false
## Raider hunt done.
var _hunt_done: bool = false
## Crater City hazards.
var sinkholes: Array = []   ## [{pos, r, node}]
var _sink_cd: float = 0.0
var _rubble_t: float = 0.0
var _serpent_at: float = INF
## Dustfall storm.
var storm_radius: float = INF
var _storm_node: Node2D
var _storm_total: float = 1.0
var _storm_warn_cd: float = 0.0


func setup(ctl: Node, p: Node2D, w: Node2D, h: Node) -> void:
	match_ctl = ctl
	player = p
	world = w
	hud = h
	add_to_group("zone_twists")
	tier = GameState.zone_tier()
	power = ZoneDefs.strength(tier)
	twists = (ZoneDefs.zone(tier)["twists"] as Array).duplicate()
	## Weekly Dust modifiers can switch on extra twists (Heavy Dust, Blackout Nights).
	for t in DustModDefs.twists_of(GameState.dust_mods()):
		if not t in twists:
			twists.append(t)
	rng.seed = GameState.run_seed * 31 + 7
	_origin = player.global_position if is_instance_valid(player) else Vector2.ZERO
	if has("smog"):
		for i in range(int(ZoneDefs.SMOG["patches"])):
			_spawn_smog()
	if has("bunkers"):
		for i in range(int(ZoneDefs.BUNKERS["count"])):
			var b := Node2D.new()
			b.set_script(BunkerScript)
			b.position = _ring_spot(ZoneDefs.BUNKERS["dist"])
			world.add_child(b)
	if has("night"):
		_build_night()
		for i in range(int(ZoneDefs.NIGHT["flares"])):
			spawn_pickup("flare", _ring_spot(ZoneDefs.NIGHT["flare_dist"]))
	if has("toxic_air"):
		GameState.run_filter = 100.0
		for i in range(int(ZoneDefs.TOXIC_AIR["filters"])):
			spawn_pickup("filter", _ring_spot(ZoneDefs.TOXIC_AIR["filter_dist"]))
	if has("sinkholes"):
		var sk: Dictionary = ZoneDefs.SINKHOLES
		for i in range(int(sk["count"])):
			_spawn_sinkhole(_ring_spot(sk["dist"]), rng.randf_range(sk["radius"].x, sk["radius"].y))
	if has("serpent_ambush"):
		_serpent_at = float(ZoneDefs.SERPENT_AMBUSH["first"]) * GameState.timer_scale()
	if has("dust_storm"):
		_storm_total = 0.0
		for ph in match_ctl.get("_phases"):
			_storm_total += float(ph["duration"])
		_storm_total = maxf(1.0, _storm_total)
		storm_radius = float(ZoneDefs.DUST_STORM["start"])
		_storm_node = Node2D.new()
		_storm_node.z_index = 20
		_storm_node.draw.connect(_draw_storm)
		world.add_child(_storm_node)
	if not twists.is_empty() and hud and hud.has_method("show_toast"):
		hud.call("show_toast", "%s — %s" % [str(ZoneDefs.zone(tier)["name"]), _twist_hint()], UiTheme.AMBER)


func has(twist: String) -> bool:
	return twist in twists


func _twist_hint() -> String:
	if has("dust_storm"):
		return "everything at once, and the storm closes in"
	if has("smog"):
		return "smog hides them; elites carry bunker keys"
	if has("night"):
		return "stay in the light; grab flares"
	if has("infected_burst"):
		return "the infected burst when they drop"
	if has("shroud"):
		return "you won't see them until they're close"
	if has("toxic_air"):
		return "watch your air filter; pick up filters"
	if has("power_cells"):
		return "pads are dead — carry a power cell to one"
	if has("sinkholes"):
		return "mind the sinkholes, falling rubble and serpents"
	return ""


## Dustfall storm centre (the drop point).
func storm_origin() -> Vector2:
	return _origin


func _ring_spot(d: Vector2) -> Vector2:
	var base := player.global_position if is_instance_valid(player) else _origin
	for attempt in range(8):
		var a := rng.randf() * TAU
		var p := base + Vector2(cos(a), sin(a)) * rng.randf_range(d.x, d.y)
		## Never inside the Dust storm (Dustfall): keep it well within the wall.
		if storm_radius < INF and p.distance_to(_origin) > storm_radius * 0.85:
			p = _origin + (p - _origin).limit_length(storm_radius * 0.85)
		if match_ctl == null or not match_ctl.has_method("_spot_clear") or bool(match_ctl.call("_spot_clear", p)):
			return p
	var a2 := rng.randf() * TAU
	return base + Vector2(cos(a2), sin(a2)) * d.x


func spawn_pickup(kind: String, at: Vector2) -> Node2D:
	var n := Node2D.new()
	n.set_script(PickupScript)
	n.set("kind", kind)
	n.position = at
	world.add_child(n)
	return n


## ZonePickup calls this when the hero walks over it.
func on_pickup(kind: String, _at: Vector2) -> void:
	match kind:
		"key":
			GameState.run_keys += 1
			_toast("Bunker key — find a locked bunker (yellow on the map)")
		"flare":
			flare_left = float(ZoneDefs.NIGHT["flare_time"]) + maxf(0.0, flare_left)
			_toast("Flare lit — the dark pulls back")
		"filter":
			GameState.run_filter = minf(100.0, GameState.run_filter + float(ZoneDefs.TOXIC_AIR["refill"]))
			_toast("Fresh air filter")
		"power_cell":
			GameState.run_has_cell = true
			_toast("Power cell — carry it to a pad")
	_sync_hud()


## The window's pads were just placed (its ping, or its opening when there was
## no ping). Military Base: kill the pads and drop a power cell on the way to
## the nearer one right away, so the cell run starts with the ping, not with
## the (short) window itself.
func on_window_ping(pads: Array) -> void:
	if not has("power_cells"):
		return
	for pad in pads:
		if is_instance_valid(pad) and pad.has_method("set_powered"):
			pad.call("set_powered", false)
	if GameState.run_has_cell:
		_toast("Pads are dead — you carry a power cell, take it to a pad")
		return
	if _cell_on_ground() == null:
		spawn_pickup("power_cell", _cell_spot(pads))
	_toast("Pads are dead — grab the power cell (blue on the map) first")


func on_window_open(_index: int, pads: Array) -> void:
	if has("power_cells"):
		var dead := false
		for pad in pads:
			if is_instance_valid(pad) and not bool(pad.get("powered")):
				dead = true
		## Pads placed without a ping: do the ping work now.
		if not dead:
			on_window_ping(pads)
		elif not GameState.run_has_cell and _cell_on_ground() == null:
			spawn_pickup("power_cell", _cell_spot(pads))


func _cell_on_ground() -> Node2D:
	for zp in get_tree().get_nodes_in_group("zone_pickups"):
		if is_instance_valid(zp) and str(zp.get("kind")) == "power_cell" and not zp.is_queued_for_deletion():
			return zp as Node2D
	return null


## Part of the way from the hero to the nearer pad, nudged sideways a little.
func _cell_spot(pads: Array) -> Vector2:
	if not is_instance_valid(player):
		return _ring_spot(ZoneDefs.POWER_CELL["dist"])
	var near: Node2D = null
	var bd := INF
	for pad in pads:
		if is_instance_valid(pad):
			var d: float = (pad as Node2D).global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				near = pad
	if near == null:
		return _ring_spot(ZoneDefs.POWER_CELL["dist"])
	var lim: Vector2 = ZoneDefs.POWER_CELL["dist"]
	var to := near.global_position - player.global_position
	var along := clampf(to.length() * float(ZoneDefs.POWER_CELL["along"]), lim.x, minf(lim.y, to.length() - 80.0))
	for attempt in range(6):
		var side := rng.randf_range(-0.35, 0.35) * (1.0 + attempt * 0.3)
		var p := player.global_position + to.normalized().rotated(side) * along
		if storm_radius < INF and p.distance_to(_origin) > storm_radius * 0.85:
			p = _origin + (p - _origin).limit_length(storm_radius * 0.85)
		if match_ctl == null or not match_ctl.has_method("_spot_clear") or bool(match_ctl.call("_spot_clear", p)):
			return p
	return player.global_position + to.normalized() * along


## Extra open seconds for dead-pad windows (Military Base).
func window_bonus() -> float:
	return float(ZoneDefs.POWER_CELL["window_bonus"]) if has("power_cells") else 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(player) or match_ctl == null or bool(match_ctl.get("_ended")):
		return
	_t += delta
	if has("smog"):
		_tick_smog(delta)
	if has("bunkers"):
		_hook_elite_keys()
	if has("night"):
		_tick_night(delta)
	if has("wraith_phase"):
		_tick_wraiths(delta)
	if has("shroud"):
		_tick_shroud()
	if has("raider_hunt") and not _hunt_done and _t >= ZoneDefs.RAIDER_HUNT_AT * GameState.timer_scale():
		_hunt_done = true
		var a := rng.randf() * TAU
		var crew: Node = match_ctl.call("spawn_crew", player.global_position + Vector2(cos(a), sin(a)) * 620.0)
		if crew != null:
			crew.set("hunting", true)
		_toast("A rival crew has your scent — they're hunting you")
	if has("toxic_air"):
		_tick_air(delta)
	if has("sinkholes"):
		_tick_sinkholes(delta)
	if has("rubble_fall"):
		_tick_rubble(delta)
	if has("serpent_ambush") and _t >= _serpent_at:
		_serpent_at = _t + float(ZoneDefs.SERPENT_AMBUSH["every"]) / power * GameState.timer_scale()
		serpent_ambush()
	if has("dust_storm"):
		_tick_storm(delta)
	if int(_t * 4.0) != int((_t - delta) * 4.0):
		_sync_hud()


func _sync_hud() -> void:
	if hud and hud.has_method("set_zone"):
		hud.call("set_zone", GameState.run_keys, GameState.run_has_cell, GameState.run_filter if has("toxic_air") else -1.0, flare_left)


func _toast(t: String) -> void:
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", t, UiTheme.AMBER)


## --- Smog ---------------------------------------------------------------------
func _spawn_smog() -> void:
	var sm: Dictionary = ZoneDefs.SMOG
	var r := rng.randf_range(sm["radius"].x, sm["radius"].y)
	## Pixel smog (polish pass 2): ASH-ramp cloud strip at world size.
	var sp := AnimatedSprite2D.new()
	var fid: String = PlagueZoneScript.fog_id("fog_smog", r, [["_s", 160.0], ["_m", 195.0], ["_l", 230.0]])
	if Juice.px:
		Juice.px.call("dress", sp, fid)
	sp.modulate = Color(1, 1, 1, 0.0)
	sp.z_index = 8
	sp.position = _ring_spot(sm["dist"])
	world.add_child(sp)
	sp.play("default")
	var tw := sp.create_tween()
	for a in [0.25, 0.5, 0.75, 1.0]:
		tw.tween_interval(0.5)
		tw.tween_property(sp, "modulate:a", a, 0.0)
	smog.append({"node": sp, "r": r, "life": float(sm["life"]) * rng.randf_range(0.8, 1.2)})


func in_smog(p: Vector2) -> bool:
	for s in smog:
		var n: Node2D = s["node"]
		if is_instance_valid(n) and _ell_dist(p, n.global_position, float(s["r"])) < 1.0:
			return true
	return false


func _ell_dist(p: Vector2, c: Vector2, r: float) -> float:
	var d := p - c
	return sqrt(d.x * d.x / (r * r) + d.y * d.y / (r * r * 0.4))


func _tick_smog(delta: float) -> void:
	for s in smog.duplicate():
		s["life"] = float(s["life"]) - delta
		var n: Node2D = s["node"]
		if float(s["life"]) <= 0.0 or not is_instance_valid(n) or n.global_position.distance_to(player.global_position) > 1600.0:
			if is_instance_valid(n):
				var tw := n.create_tween()
				for a in [0.75, 0.5, 0.25, 0.0]:
					tw.tween_property(n, "modulate:a", a, 0.0)
					tw.tween_interval(0.375)
				tw.tween_callback(n.queue_free)
			smog.erase(s)
			_spawn_smog()
	var reveal := float(ZoneDefs.SMOG["reveal"])
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node2D
		if en == null:
			continue
		var hide := in_smog(en.global_position) and en.global_position.distance_to(player.global_position) > reveal
		en.set_meta("smog_hidden", hide)
		if not has("shroud"):
			en.modulate.a = move_toward(en.modulate.a, 0.07 if hide else 1.0, delta * 4.0)


## --- Bunker keys from elites ------------------------------------------------------
func _hook_elite_keys() -> void:
	for e in get_tree().get_nodes_in_group("elites"):
		if e.has_meta("key_hooked"):
			continue
		e.set_meta("key_hooked", true)
		if randf() < float(ZoneDefs.BUNKERS["key_elite_chance"]):
			var en := e as Node2D
			e.connect("died", func() -> void:
				if is_instance_valid(en):
					spawn_pickup("key", en.global_position + Vector2(0, 16)))


## --- Night ------------------------------------------------------------------------
func _build_night() -> void:
	_night = CanvasLayer.new()
	_night.layer = 1
	add_child(_night)
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = NIGHT_SHADER
	_night_mat = ShaderMaterial.new()
	_night_mat.shader = sh
	r.material = _night_mat
	_night.add_child(r)


func light_radius() -> float:
	var base := float(ZoneDefs.NIGHT["dustfall_radius"] if has("dust_storm") else ZoneDefs.NIGHT["radius"])
	return float(ZoneDefs.NIGHT["flare_radius"]) if flare_left > 0.0 else base


func _tick_night(delta: float) -> void:
	flare_left = maxf(0.0, flare_left - delta)
	if _night_mat == null:
		return
	var xf := get_viewport().get_canvas_transform()
	var vs := get_viewport().get_visible_rect().size
	_night_mat.set_shader_parameter("center", xf * player.global_position)
	_night_mat.set_shader_parameter("screen", vs)
	_night_mat.set_shader_parameter("radius", light_radius() * xf.get_scale().x)
	_night_mat.set_shader_parameter("dark", float(ZoneDefs.NIGHT["dark"]))


## --- Ash-Wraith phasing --------------------------------------------------------------
func _tick_wraiths(delta: float) -> void:
	var wp: Dictionary = ZoneDefs.WRAITH_PHASE
	_phase_t += delta
	var cycle := float(wp["every"])
	var now := fmod(_phase_t, cycle) > cycle - float(wp["on"])
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (str(e.get("kind")) in (wp["kinds"] as Array)):
			continue
		e.set("phased", now)
	_phasing = now


## --- Shroud: unseen until close (marked = seen) ---------------------------------------
func _tick_shroud() -> void:
	var sh: Dictionary = ZoneDefs.SHROUD
	var hide := float(sh["hide"])
	var fade := float(sh["fade"])
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node2D
		if en == null:
			continue
		var d := en.global_position.distance_to(player.global_position)
		var a := clampf((hide - d) / fade + 1.0, 0.0, 1.0)
		if en.has_method("has_status") and bool(en.call("has_status", "mark")):
			a = 1.0
		if bool(en.get_meta("smog_hidden", false)):
			a = minf(a, 0.07)
		en.modulate.a = maxf(a, 0.0)
		en.set_meta("shrouded", a < 0.05)


## --- Toxic air ----------------------------------------------------------------------
var _filter_t: float = 0.0

func _tick_air(delta: float) -> void:
	var ta: Dictionary = ZoneDefs.TOXIC_AIR
	_filter_t += delta
	if _filter_t >= float(ta["respawn"]) * GameState.timer_scale():
		_filter_t = 0.0
		var out := 0
		for zp in get_tree().get_nodes_in_group("zone_pickups"):
			if str(zp.get("kind")) == "filter":
				out += 1
		if out < int(ta["max_out"]):
			spawn_pickup("filter", _ring_spot(ta["filter_dist"]))
	GameState.run_filter = maxf(0.0, GameState.run_filter - float(ta["drain"]) * power * delta / GameState.timer_scale())
	if GameState.run_filter <= 0.0 and player.has_method("drain"):
		player.call("drain", float(ta["hurt"]) * delta)
		if int(_t * 2.0) != int((_t - delta) * 2.0):
			Juice.float_text(player.global_position + Vector2(0, -50), "NO AIR", UiTheme.DANGER, 13)


## --- Crater City --------------------------------------------------------------------
func _spawn_sinkhole(at: Vector2, r: float) -> void:
	var sp := Sprite2D.new()
	## Native-density art in three sizes per zone; pick the closest (no scaling).
	var grade := str(ZoneDefs.zone(tier).get("grade", "crater"))
	if grade != "dustfall":
		grade = "crater"
	var want := r * 2.3 / UnitAnim.TEXEL
	var size := "s" if want < 215.0 else ("m" if want < 265.0 else "l")
	var path := ZONE_DIR % ("sinkhole_%s_%s" % [grade, size])
	if ResourceLoader.exists(path):
		sp.texture = load(path)
		sp.scale = Vector2.ONE * UnitAnim.TEXEL
	sp.z_index = -4
	sp.position = at
	world.add_child(sp)
	sinkholes.append({"pos": at, "r": r, "node": sp})


func _tick_sinkholes(delta: float) -> void:
	_sink_cd = maxf(0.0, _sink_cd - delta)
	if _sink_cd > 0.0:
		return
	for s in sinkholes:
		var c: Vector2 = s["pos"]
		var r := float(s["r"])
		if _ell_dist(player.global_position, c, r * 0.8) < 1.0:
			_sink_cd = float(ZoneDefs.SINKHOLES["cd"])
			var dir := (player.global_position - c).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.DOWN
			## A fall, not a hit: no dodge / block.
			player.call("drain", float(player.get("max_hp")) * float(ZoneDefs.SINKHOLES["damage"]) * power)
			player.global_position = c + dir * (r + float(ZoneDefs.SINKHOLES["fling"]) * 0.4)
			Juice.dust_puff(player.global_position, 12)
			Juice.float_text(player.global_position + Vector2(0, -50), "SINKHOLE!", UiTheme.DANGER, 16)
			Juice.shake(0.2)
			return


func _tick_rubble(delta: float) -> void:
	_rubble_t += delta
	var rf: Dictionary = ZoneDefs.RUBBLE_FALL
	if _rubble_t < float(rf["every"]) / power * GameState.timer_scale():
		return
	_rubble_t = 0.0
	for i in range(int(rf["count"])):
		var a := rng.randf() * TAU
		drop_rubble(player.global_position + Vector2(cos(a), sin(a)) * rng.randf_range(0.0, float(rf["near"])))


## Telegraphed falling rubble: ring + shadow, then the slab lands.
func drop_rubble(at: Vector2) -> void:
	var rf: Dictionary = ZoneDefs.RUBBLE_FALL
	var r := float(rf["radius"])
	var delay := float(rf["delay"])
	RunFx.ring(world, at, r, Color(1.0, 0.5, 0.3, 0.9), delay, 3.0)
	var chunk := Sprite2D.new()
	var path := ZONE_DIR % "rubble_chunk"
	if ResourceLoader.exists(path):
		chunk.texture = load(path)
		chunk.scale = Vector2.ONE * UnitAnim.TEXEL
	chunk.position = at + Vector2(0, -420)
	chunk.z_index = 12
	world.add_child(chunk)
	var tw := chunk.create_tween()
	tw.tween_property(chunk, "position", at, delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		_rubble_land(at, r, float(rf["damage"]))
		var t2 := chunk.create_tween()
		t2.tween_property(chunk, "modulate:a", 0.0, 1.2)
		t2.tween_callback(chunk.queue_free))


func _rubble_land(at: Vector2, r: float, dmg: float) -> void:
	Juice.dust_puff(at, 14)
	Juice.shake(0.15)
	if is_instance_valid(player) and _ell_dist(player.global_position, at, r) < 1.0:
		player.call("take_damage", dmg, null)
	for e in RunFx.enemies_in(get_tree(), at, r):
		e.call("take_damage", dmg * 2.0, ((e as Node2D).global_position - at).normalized(), 200.0)


func serpent_ambush() -> Node:
	var sa: Dictionary = ZoneDefs.SERPENT_AMBUSH
	var a := rng.randf() * TAU
	var at := player.global_position + Vector2(cos(a), sin(a)) * float(sa["dist"])
	RunFx.ring(world, at, 70.0, Color(1.0, 0.75, 0.35), 0.6, 4.0)
	Juice.dust_puff(at, 16)
	_toast("SERPENT AMBUSH!")
	return match_ctl.call("spawn_at", "", str(sa["kind"]), at)


## --- Dustfall storm -------------------------------------------------------------------
func _tick_storm(delta: float) -> void:
	var ds: Dictionary = ZoneDefs.DUST_STORM
	var k := clampf(float(match_ctl.get("_elapsed_in_phases")) / _storm_total, 0.0, 1.0)
	storm_radius = lerpf(float(ds["start"]), float(ds["end"]), k)
	if _storm_node:
		_storm_node.global_position = _origin
		_storm_node.queue_redraw()
	_storm_warn_cd = maxf(0.0, _storm_warn_cd - delta)
	var d := player.global_position.distance_to(_origin)
	if d > storm_radius:
		player.call("drain", float(ds["hurt"]) * power * delta)
		if _storm_warn_cd <= 0.0:
			_storm_warn_cd = 4.0
			_toast("The Dust storm is eating you — get back inside the wall")
	elif d > storm_radius - float(ds["warn"]) and _storm_warn_cd <= 0.0:
		_storm_warn_cd = 6.0
		_toast("The storm wall is close")


func _draw_storm() -> void:
	if _storm_node == null:
		return
	var r := storm_radius
	_storm_node.draw_arc(Vector2.ZERO, r + 50.0, 0.0, TAU, 160, Color(0.55, 0.36, 0.18, 0.35), 110.0)
	_storm_node.draw_arc(Vector2.ZERO, r, 0.0, TAU, 160, Color(1.0, 0.72, 0.35, 0.8), 6.0)
	_storm_node.draw_arc(Vector2.ZERO, r + 18.0, 0.0, TAU, 160, Color(0.9, 0.6, 0.3, 0.35), 3.0)
