extends Node

## Depth Update E4 — Helm's radio jobs (RadioDefs): 1–2 contracts and 1–2 camp
## cameo services per run, each run by a survivor you are NOT playing.
## Contract rewards are paid on extract (scrap + ingredients); helping a cameo
## moves that survivor's story on. Also runs the stay-or-go stakes and spawns
## the Dust Warden on the pads at the last window (called by the match).

const NpcScript := preload("res://scripts/entities/cameo_npc.gd")
const MarketScript := preload("res://scripts/ui/black_market.gd")
const PROP := "res://assets/sprites/depth/world/%s.png"

var match_ctl: Node
var player: Node2D
var world: Node2D
var hud: Node
var events: Node
var rng := RandomNumberGenerator.new()
## Queue of [time, job id]; jobs live in `active` (id -> state dict).
var _queue: Array = []
var active: Dictionary = {}
var done: Array = []
var _market_id: String = ""
var _layer: CanvasLayer
var _arrow: Control
var _stake: String = ""
var _t: float = 0.0


func setup(ctl: Node, p: Node2D, w: Node2D, h: Node, ev: Node) -> void:
	match_ctl = ctl
	player = p
	world = w
	hud = h
	events = ev
	rng.seed = GameState.run_seed ^ 0x7ad10
	var hero := GameState.selected_character_id
	var ts := GameState.timer_scale()
	var tier := int(GameState.get_mode().get("tier", 1))
	var contracts := RadioDefs.jobs_for("contract", hero, tier)
	var services := RadioDefs.jobs_for("service", hero, tier)
	var nc := rng.randi_range(RadioDefs.CONTRACTS_PER_RUN.x, RadioDefs.CONTRACTS_PER_RUN.y)
	var ns := rng.randi_range(RadioDefs.SERVICES_PER_RUN.x, RadioDefs.SERVICES_PER_RUN.y)
	var givers: Array = []
	for i in range(nc):
		var id := _pick(contracts, givers)
		if id != "":
			var at: Vector2 = RadioDefs.CONTRACT_AT[mini(i, RadioDefs.CONTRACT_AT.size() - 1)]
			_queue.append([rng.randf_range(at.x, at.y) * ts, id])
	for i in range(ns):
		var id2 := _pick(services, givers)
		if id2 == "":
			continue
		if bool(RadioDefs.job(id2).get("at_window", false)):
			_market_id = id2
			continue
		var at2: Vector2 = RadioDefs.SERVICE_AT[mini(i, RadioDefs.SERVICE_AT.size() - 1)]
		_queue.append([rng.randf_range(at2.x, at2.y) * ts, id2])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	## Onboarding: contracts / services switch on after the third finished run.
	if not GameState.feature_on("jobs"):
		_queue.clear()
		_market_id = ""
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	_arrow = Control.new()
	_arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arrow.draw.connect(_draw_arrows)
	_layer.add_child(_arrow)


## One job, never two from the same survivor in a run.
func _pick(pool: Array, givers: Array) -> String:
	var opts: Array = []
	for id in pool:
		if not str(RadioDefs.job(str(id))["giver"]) in givers and not str(id) in done:
			opts.append(str(id))
	if opts.is_empty():
		return ""
	var id: String = opts[rng.randi() % opts.size()]
	givers.append(str(RadioDefs.job(id)["giver"]))
	pool.erase(id)
	return id


func queued_ids() -> Array:
	var out: Array = []
	for q in _queue:
		out.append(q[1])
	if _market_id != "":
		out.append(_market_id)
	return out


func _radio(text: String) -> void:
	if events and events.has_method("radio"):
		events.call("radio", text)


func _spot(r: Vector2) -> Vector2:
	var best := player.global_position
	for k in range(8):
		var a := rng.randf() * TAU
		best = player.global_position + Vector2(cos(a), sin(a)) * rng.randf_range(r.x, r.y)
		if bool(match_ctl.call("_spot_free", best, 50.0)):
			break
	return best


func _npc(hero: String, at: Vector2, prop: String = "", prop_world: float = 90.0, prop_off: Vector2 = Vector2(-52, 0), label: String = "", perch: float = 0.0) -> Node2D:
	var n := Node2D.new()
	n.set_script(NpcScript)
	n.set("hero", hero)
	n.set("prop_path", (PROP % prop) if prop != "" else "")
	n.set("prop_world", prop_world)
	n.set("prop_offset", prop_off)
	n.set("label_text", label)
	n.set("perch", perch)
	n.position = at
	world.add_child(n)
	return n


func _prop(name: String, at: Vector2, size: float) -> Sprite2D:
	var s := Sprite2D.new()
	if ResourceLoader.exists(PROP % name):
		s.texture = load(PROP % name)
		## Native density (style bible): the art is drawn at its size class.
		s.scale = Vector2.ONE * UnitAnim.TEXEL
		## Y-sorted with the units: node SORT_FEET above the base line.
		s.offset = Vector2(0, -float(s.texture.get_height()) * 0.5 + 30.0 / UnitAnim.TEXEL)
	s.position = at + Vector2(0, 10 - 30.0)
	s.z_index = 0
	s.add_to_group("map_markers")
	s.set_meta("map_color", RadioDefs.MAP_COLOR)
	world.add_child(s)
	return s


func _mob(at: Vector2, kind: String = "") -> Node:
	var e: CharacterBody2D = (load("res://scenes/entities/enemy.tscn") as PackedScene).instantiate()
	var mode := GameState.get_mode()
	var tl := ModeDefs.run_table(GameState.threat_level, GameState.windows_skipped)
	e.setup(at, float(tl["hp"]) * float(mode.get("enemy_hp", 1.0)), float(tl["damage"]) * float(mode.get("enemy_damage", 1.0)), 1.0,
		kind if kind != "" else str(match_ctl.call("_roll_enemy_kind")))
	world.add_child(e)
	return e


## =============================================================================

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or GameState.run_finished:
		return
	_t += delta
	var mt := float(match_ctl.get("_match_time"))
	while not _queue.is_empty() and mt >= float(_queue[0][0]):
		var q: Array = _queue.pop_front()
		start(str(q[1]))
	for id in active.keys():
		_tick(str(id), delta)
	_push_hud()
	_arrow.queue_redraw()


## Start a job now (also used by tests / review shots). Returns its state.
func start(id: String, at: Vector2 = Vector2.INF) -> Dictionary:
	var j := RadioDefs.job(id)
	if j.is_empty() or active.has(id):
		return {}
	var s := {"id": id, "t": 0.0, "pos": Vector2.INF, "node": null, "npc": null, "phase": ""}
	active[id] = s
	_radio(str(j["radio"]))
	if str(j["kind"]) == "contract":
		hud.show_toast("RADIO: %s — +%d scrap on extract, Greed −1" % [str(j["name"]), int(j.get("reward_scrap", 0))], RadioDefs.MAP_COLOR)
	else:
		hud.show_toast("RADIO: %s" % str(j["name"]), RadioDefs.MAP_COLOR)
	var giver := str(j["giver"])
	match id:
		"bounty":
			var e: Node = match_ctl.call("spawn_special", "elite")
			if e != null:
				e.add_to_group("map_markers")
				e.set("map_color", RadioDefs.MAP_COLOR)
				s["node"] = e
				e.connect("died", func() -> void: _complete(id))
		"medicine_cache":
			s["pos"] = at if at != Vector2.INF else _spot(j["distance"])
			for i in range(int(j["crates"])):
				HaulPickup.spawn(world, s["pos"] + Vector2(-20 + 40 * i, 0), "medicine", 1, false)
			for i in range(int(j["guards"])):
				_mob(s["pos"] + Vector2.RIGHT.rotated(TAU * i / float(j["guards"])) * 110.0)
		"defend_relay":
			s["pos"] = at if at != Vector2.INF else _spot(j["distance"])
			s["npc"] = _npc(giver, s["pos"], "relay", 92.0, Vector2(-80, 0), "Juno — hold the relay")
			s["hold"] = 0.0
			s["wave_t"] = 0.0
		"rescue":
			s["pos"] = at if at != Vector2.INF else _spot(j["distance"])
			s["npc"] = _npc(giver, s["pos"], "", 0.0, Vector2.ZERO, "Pebble + a sick survivor")
			s["phase"] = "find"
		"black_box":
			s["pos"] = at if at != Vector2.INF else _spot(j["distance"])
			s["node"] = _prop("plane_wreck", s["pos"], 150.0)
			s["channel"] = 0.0
			s["phase"] = "find"
			if player.has_signal("hurt"):
				player.hurt.connect(func(_a: float) -> void:
					if active.has("black_box"):
						active["black_box"]["channel"] = 0.0)
		"field_tent":
			s["pos"] = at if at != Vector2.INF else _spot(j["distance"])
			s["npc"] = _npc(giver, s["pos"], "field_tent", 110.0, Vector2(-104, 0), "Cinder's field tent")
		"overwatch":
			s["pos"] = at if at != Vector2.INF else _spot(j["distance"])
			s["npc"] = _npc(giver, s["pos"], "watch_tower", 150.0, Vector2(0, 0), "Vesper — overwatch", 118.0)
			s["fire_t"] = 1.0
		"vault":
			s["pos"] = at if at != Vector2.INF else _spot(j["distance"])
			s["node"] = _prop("vault", s["pos"], 120.0)
			s["npc"] = _npc(giver, s["pos"] + Vector2(70, 26), "", 0.0, Vector2.ZERO, "Rook — cover the fuse")
			s["phase"] = "find"
		"care_package":
			_care_package(j)
			_complete(id)
		"black_market":
			s["pos"] = at
			s["npc"] = _npc(giver, at, "market_stall", 110.0, Vector2(-104, 0), "Nyx's black market")
			s["inside"] = false
	return s


func _tick(id: String, delta: float) -> void:
	if not active.has(id):
		return
	var s: Dictionary = active[id]
	var j := RadioDefs.job(id)
	s["t"] = float(s["t"]) + delta
	var pos: Vector2 = s["pos"]
	var near := pos != Vector2.INF and player.global_position.distance_to(pos) <= float(j.get("radius", 80.0))
	match id:
		"bounty":
			if s["node"] == null or not is_instance_valid(s["node"]):
				if active.has(id):
					_fail(id)
		"medicine_cache":
			if near:
				_complete(id)
		"defend_relay":
			if near:
				s["hold"] = float(s["hold"]) + delta
				s["wave_t"] = float(s["wave_t"]) - delta
				if float(s["wave_t"]) <= 0.0:
					s["wave_t"] = float(j["wave_every"])
					for i in range(int(j["wave"])):
						_mob(pos + Vector2.RIGHT.rotated(rng.randf() * TAU) * 340.0)
				if s["npc"] and rng.randf() < delta * 2.0:
					RunFx.zap(world, pos + Vector2(-46, -80), pos + Vector2(-46 + rng.randf_range(-20, 20), -120), Color(0.55, 0.85, 1.0), 0.15, 2.0)
			if float(s["hold"]) >= float(j["hold"]):
				_complete(id)
			elif float(s["t"]) > float(j["give_up"]):
				_fail(id)
		"rescue":
			var npc: Node2D = s["npc"]
			if str(s["phase"]) == "find" and npc and player.global_position.distance_to(npc.global_position) < 90.0:
				s["phase"] = "escort"
				npc.set("follow", player)
				npc.set("follow_speed", float(j["follow_speed"]))
				hud.show_toast("Pebble: \"Lead the way. Not too fast.\"", RadioDefs.MAP_COLOR)
		"black_box":
			if str(s["phase"]) == "find" and near:
				s["channel"] = float(s["channel"]) + delta
				if float(s["channel"]) >= float(j["channel"]):
					s["phase"] = "carry"
					Juice.float_text(pos + Vector2(0, -60), "BLACK BOX", RadioDefs.MAP_COLOR, 18)
					hud.show_toast("Black box recovered — extract to deliver it", RadioDefs.MAP_COLOR)
		"field_tent":
			if near:
				var hp_max := float(player.get("max_hp"))
				player.call("heal", hp_max * float(j["heal_frac"]))
				GameState.cleanse_exposure(float(j["cleanse"]))
				Juice.float_text(player.global_position + Vector2(0, -50), "PATCHED UP", UiTheme.TEAL, 18)
				if s["npc"]:
					(s["npc"] as Node).call("act", "ability", 1.0)
				_complete(id)
			elif float(s["t"]) > float(j["life"]):
				_fail(id)
		"overwatch":
			s["fire_t"] = float(s["fire_t"]) - delta
			if float(s["fire_t"]) <= 0.0:
				s["fire_t"] = float(j["every"])
				_snipe(s, j)
			if float(s["t"]) > float(j["life"]):
				_complete(id)
		"vault":
			if str(s["phase"]) == "find" and near:
				s["phase"] = "fuse"
				s["fuse"] = float(j["fuse"])
				if s["npc"]:
					(s["npc"] as Node).call("act", "ability", 1.2)
				for i in range(int(j["guards"])):
					_mob(pos + Vector2.RIGHT.rotated(rng.randf() * TAU) * 320.0)
				hud.show_toast("Rook: \"Fuse is lit! Keep them off me!\"", RadioDefs.MAP_COLOR)
			elif str(s["phase"]) == "fuse":
				s["fuse"] = float(s["fuse"]) - delta
				if float(s["fuse"]) <= 0.0:
					_open_vault(s, j)
					_complete(id)
		"black_market":
			if s["npc"] == null:
				return
			var inside := player.global_position.distance_to((s["npc"] as Node2D).global_position) <= float(j["radius"])
			if inside and not bool(s["inside"]):
				_open_market()
			s["inside"] = inside


## Vesper picks off the biggest threat near you.
func _snipe(s: Dictionary, j: Dictionary) -> void:
	var npc: Node2D = s["npc"]
	if npc == null:
		return
	var from := npc.global_position + Vector2(0, -float(npc.get("perch")) * UnitAnim.ART_GROW - 30.0)
	var best: Node2D = null
	var bs := -1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		var d := (e as Node2D).global_position.distance_to(npc.global_position)
		if d > float(j["range"]):
			continue
		var sc := 1000.0 if str(e.get("role")) != "" else 0.0
		sc += float(e.get("max_hp")) - d * 0.1
		if sc > bs:
			bs = sc
			best = e
	if best == null:
		return
	npc.call("face", best.global_position.x - npc.global_position.x)
	npc.call("act", "attack", 0.4)
	RunFx.zap(world, from, best.global_position + Vector2(0, -12), Color(0.7, 1.0, 0.5), 0.12, 2.5)
	Juice.burst(best.global_position, Color(0.7, 1.0, 0.5), 8, 140.0, 0.3)
	var dmg := float(j["damage"]) * float(GameState.get_mode().get("enemy_hp", 1.0))
	best.call("take_damage", dmg, (best.global_position - from).normalized(), 120.0, true)
	Juice.sfx_at("drone_fire", best.global_position)


func _open_vault(s: Dictionary, j: Dictionary) -> void:
	var pos: Vector2 = s["pos"]
	Juice.shake(0.45)
	Juice.burst(pos, Color(1.0, 0.7, 0.3), 40, 280.0, 0.7, 1.6)
	Juice.dust_puff(pos, 24)
	Juice.sfx_at("explosion", pos)
	Juice.sfx("crate_open")
	if s["node"] and is_instance_valid(s["node"]):
		(s["node"] as Node2D).modulate = Color(0.55, 0.5, 0.45)
	var tier := int(GameState.get_mode().get("tier", 1))
	GearPickup.spawn(world, pos + Vector2(0, 20), GearDefs.roll_drop(tier, GameState.selected_character_id, GameState.gear_luck(), rng, "", str(j["min_rarity"])))
	HaulPickup.spawn(world, pos + Vector2(30, 30), "medicine", 1)
	LootDrop.spawn_burst(world, pos, "scrap", 5, float(j["scrap"]))


func _care_package(j: Dictionary) -> void:
	var at := player.global_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * 110.0
	RunFx.supply_crate(world, at)
	for i in range(int(j["tonics"])):
		LootDrop.spawn_burst(world, at + Vector2(rng.randf_range(-30, 30), rng.randf_range(-20, 20)), "tonic", 1, float(j["heal"]))
	## Helm's drone streaks over on the way.
	var d := Sprite2D.new()
	var tex := "res://assets/sprites/characters/helm_drone_hover.png"
	if ResourceLoader.exists(tex):
		var t: Texture2D = load(tex)
		var fr := AtlasTexture.new()
		fr.atlas = t
		fr.region = Rect2(0, 0, t.get_height(), t.get_height())
		d.texture = fr
		d.scale = Vector2.ONE * (40.0 / float(t.get_height()))
	d.z_index = 6
	d.global_position = at + Vector2(-500, -260)
	world.add_child(d)
	var tw := d.create_tween()
	tw.tween_property(d, "global_position", at + Vector2(500, -260), 1.6)
	tw.tween_callback(d.queue_free)


func _open_market() -> void:
	var m := CanvasLayer.new()
	m.set_script(MarketScript)
	add_child(m)
	m.call("open", self)


## The market reports a purchase (story moves on the first time).
func on_market_buy() -> void:
	if _market_id != "" and not _market_id in done:
		done.append(_market_id)
		GameState.cameo_help(str(RadioDefs.job(_market_id)["giver"]))


## Match hook: an extract window opened (black market), with its pads.
func on_window_open(index: int, pads: Array) -> void:
	if _market_id == "" or index < 1 or active.has(_market_id) or pads.is_empty() or not is_instance_valid(pads[0]):
		return
	var pad := pads[0] as Node2D
	start(_market_id, pad.global_position + Vector2(float(RadioDefs.job(_market_id)["offset"]), -40))


func on_window_close() -> void:
	if active.has("black_market"):
		var s: Dictionary = active["black_market"]
		if s["npc"] and is_instance_valid(s["npc"]):
			(s["npc"] as Node).queue_free()
		active.erase("black_market")


## Match hook at extract: deliver escorts / black boxes.
func on_extract() -> void:
	if active.has("rescue"):
		var s: Dictionary = active["rescue"]
		var npc: Node2D = s["npc"]
		if str(s["phase"]) == "escort" and npc and is_instance_valid(npc) \
				and npc.global_position.distance_to(player.global_position) <= float(RadioDefs.job("rescue")["near"]):
			_complete("rescue")
	if active.has("black_box") and str(active["black_box"]["phase"]) == "carry":
		_complete("black_box")


func _complete(id: String) -> void:
	if not active.has(id) and id in done:
		return
	var j := RadioDefs.job(id)
	var s: Dictionary = active.get(id, {})
	active.erase(id)
	done.append(id)
	if str(j["kind"]) == "contract":
		GameState.add_job_reward(int(j.get("reward_scrap", 0)), j.get("reward", {}))
		## Deepened (Oct 2026): a finished contract also draws the Dust off you —
		## Greed −1 — so detouring for a job is a real answer to staying greedy.
		if GameState.windows_skipped > 0:
			GameState.windows_skipped -= 1
			hud.show_toast("%s done — Greed −1 (now %d). Reward paid on extract" % [str(j["name"]), GameState.windows_skipped], RadioDefs.MAP_COLOR)
		else:
			hud.show_toast("%s done — reward paid on extract (Greed −1 once you've stayed)" % str(j["name"]), RadioDefs.MAP_COLOR)
	else:
		hud.show_toast("%s — thanks!" % str(j["name"]), RadioDefs.MAP_COLOR)
	GameState.cameo_help(str(j["giver"]))
	Juice.sfx("pick_rare")
	## The survivor heads home (escorts leave at extract anyway).
	var npc: Variant = s.get("npc", null)
	if npc is Node2D and is_instance_valid(npc) and id != "rescue":
		var tw := (npc as Node2D).create_tween()
		tw.tween_interval(2.5)
		tw.tween_property(npc, "modulate:a", 0.0, 1.0)
		tw.tween_callback((npc as Node2D).queue_free)


func _fail(id: String) -> void:
	var s: Dictionary = active.get(id, {})
	active.erase(id)
	var npc: Variant = s.get("npc", null)
	if npc is Node2D and is_instance_valid(npc):
		(npc as Node2D).queue_free()
	hud.show_toast("%s — missed it" % str(RadioDefs.job(id).get("name", id)), UiTheme.TEXT_DIM)


func is_done(id: String) -> bool:
	return id in done


func _push_hud() -> void:
	if not hud.has_method("set_jobs"):
		return
	var lines: PackedStringArray = []
	for id in active.keys():
		var s: Dictionary = active[id]
		var j := RadioDefs.job(str(id))
		match str(id):
			"bounty":
				lines.append("BOUNTY: kill the marked elite")
			"medicine_cache":
				lines.append("CACHE: recover Nyx's medicine")
			"defend_relay":
				lines.append("RELAY: hold near Juno %ds" % ceili(float(j["hold"]) - float(s["hold"])))
			"rescue":
				lines.append("ESCORT: find Pebble" if str(s["phase"]) == "find" else "ESCORT: extract with Pebble beside you")
			"black_box":
				lines.append("BLACK BOX: hold still by the wreck" if str(s["phase"]) == "find" else "BLACK BOX: extract to deliver it")
			"field_tent":
				lines.append("Cinder's tent is up — heal & cleanse")
			"overwatch":
				lines.append("Vesper on overwatch %ds" % ceili(float(j["life"]) - float(s["t"])))
			"vault":
				lines.append("VAULT: reach Rook" if str(s["phase"]) == "find" else "VAULT: hold %ds" % ceili(float(s.get("fuse", 0.0))))
			"black_market":
				lines.append("Nyx is trading by the pad")
	if _stake != "":
		lines.append("STAY → next: %s" % str(RadioDefs.STAKES[_stake]["label"]).to_upper())
	hud.call("set_jobs", lines)


## =============================================================================
## Stay-or-go stakes (shown from window 2) and the Dust Warden.

## Window opened: roll what staying past it will bring (window index is 1-based).
func roll_stake(window_index: int) -> String:
	_stake = ""
	if window_index < RadioDefs.STAKES_FROM_WINDOW:
		return ""
	var opts := RadioDefs.stakes_for(int(GameState.get_mode().get("tier", 1)))
	if opts.is_empty():
		return ""
	_stake = str(opts[rng.randi() % opts.size()])
	return _stake


func current_stake() -> String:
	return _stake


## The window closed and you stayed: the stake comes due.
func apply_stake() -> void:
	if _stake == "":
		return
	var st := _stake
	_stake = ""
	match st:
		"elite_pair":
			match_ctl.call("spawn_special", "elite")
			match_ctl.call("spawn_special", "elite")
		"raider_crew":
			match_ctl.call("spawn_crew")
		"boss":
			match_ctl.call("spawn_special", "boss")
		"swarm":
			for i in range(int(RadioDefs.STAKES["swarm"]["count"])):
				match_ctl.call("_spawn_enemy_force")
		"plague_fog":
			var ps: Node = match_ctl.get("plague")
			for i in range(int(RadioDefs.STAKES["plague_fog"]["zones"])):
				ps.call("spawn_zone", player.global_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(220.0, 460.0))
	hud.show_toast("You stayed — here comes %s" % str(RadioDefs.STAKES[st]["label"]), UiTheme.RUST)


## Last window: the Dust Warden rises on the pads.
func spawn_warden(pads: Array) -> Node:
	var at := player.global_position + Vector2(0, -420)
	if not pads.is_empty() and is_instance_valid(pads[0]):
		at = (pads[0] as Node2D).global_position + Vector2(0, -30)
	var tier := int(GameState.get_mode().get("tier", 1))
	var role := "boss" if tier >= RadioDefs.WARDEN_BOSS_TIER else "elite"
	var e: Node = match_ctl.call("spawn_at", role, RadioDefs.WARDEN_KIND, at)
	if e != null:
		hud.show_banner("DUST WARDEN", "It guards the last pads", UiTheme.DANGER)
		## A real fight from boss tier up: sand dash, dust hounds, storm ring.
		if role == "boss" and match_ctl.has_method("attach_brain"):
			match_ctl.call("attach_brain", e, "warden")
	return e


## Screen-edge arrows toward active job targets.
## Minimap: one entry per active job with somewhere to go ({pos, id, kind}).
func map_targets() -> Array:
	var out: Array = []
	for id in active.keys():
		var s: Dictionary = active[id]
		var tgt: Vector2 = s["pos"]
		if s["node"] != null and is_instance_valid(s["node"]):
			tgt = (s["node"] as Node2D).global_position
		elif s["npc"] != null and is_instance_valid(s["npc"]):
			tgt = (s["npc"] as Node2D).global_position
		if tgt == Vector2.INF:
			continue
		out.append({"pos": tgt, "id": str(id), "kind": str(RadioDefs.job(str(id)).get("kind", "contract"))})
	return out


## Shared with the minimap: crosshair / cross / plane / tent / market / tower / vault / crate, else "!".
static func job_icon(id: String) -> int:
	match id:
		"bounty": return MapIcons.TARGET
		"medicine_cache": return MapIcons.CROSS
		"black_box": return MapIcons.PLANE
		"field_tent", "rescue": return MapIcons.TENT
		"black_market": return MapIcons.MARKET
		"overwatch", "defend_relay": return MapIcons.TOWER
		"vault": return MapIcons.VAULT
		"care_package": return MapIcons.CRATE
	return MapIcons.BANG


func _draw_arrows() -> void:
	if player == null or not is_instance_valid(player):
		return
	var vp := _arrow.get_viewport()
	var r := vp.get_visible_rect().grow(-46.0)
	for id in active.keys():
		var s: Dictionary = active[id]
		var tgt: Vector2 = s["pos"]
		if s["node"] != null and is_instance_valid(s["node"]):
			tgt = (s["node"] as Node2D).global_position
		elif s["npc"] != null and is_instance_valid(s["npc"]):
			tgt = (s["npc"] as Node2D).global_position
		if tgt == Vector2.INF:
			continue
		var sp: Vector2 = vp.get_canvas_transform() * tgt
		if r.has_point(sp):
			continue
		var c := r.get_center()
		var d := (sp - c).normalized()
		var tx := INF if absf(d.x) < 0.001 else (r.size.x * 0.5) / absf(d.x)
		var ty := INF if absf(d.y) < 0.001 else (r.size.y * 0.5) / absf(d.y)
		var p := c + d * minf(tx, ty)
		MapIcons.draw_chevron(_arrow, p + d * 18.0, d, RadioDefs.MAP_COLOR, 15.0, 10.0)
		MapIcons.draw(_arrow, job_icon(str(id)), p - d * 13.0, RadioDefs.MAP_COLOR, 2.0)
