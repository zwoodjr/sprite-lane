extends Node

## Runs a campaign level's script: objectives in order, area triggers and
## actions. Objective keys (all optional except type / text):
##   type    reach | talk | hold | defend | survive | kill | clear | collect |
##           escort | carry | boss | extract | wait
##   text    tracker line ("Reach the quarry")       hint  sub line
##   at, r   target spot / radius (reach, talk, hold, defend, extract, boss)
##   time    seconds (hold, defend, survive, wait)
##   count   kills needed (kill)                     kinds  restrict kill count
##   items   [Vector2] (collect)                     icon   icon-set id
##   npc     npc id (talk / escort; escort walks its `path`)
##   path    [Vector2] escort route                  lead   max gap before it waits
##   carry   {from: [Vector2], to: Vector2, slow, icon, label, npc}
##   boss    {kind, name, epithet, at, hp, brain}
##   hp      defend target HP (default 100)
##   waves   [{t, kinds, n, at?, r?, elite?}]        spawned when the objective clock hits t
##   trickle {every, kinds, cap}                     steady pressure during the objective
##   on_start / on_done   [actions]
##   if_flag / unless_flag  [key, value]  skip unless / if the story flag matches
## Actions: ["scene", id] (blocks) · ["radio", who, text] · ["flag", k, v] ·
##   ["spawn", kinds, n, at?, r?] · ["npc", {...}] · ["npc_mode", id, mode, arg?] ·
##   ["npc_remove", id] · ["npc_label", id, text] · ["pet_join", npc_id] ·
##   ["banner", title, sub] · ["toast", text] · ["heal"] · ["shake", amt] ·
##   ["prop", kind, x, y] · ["wait", s] · ["if", [k, v], [then], [else]] ·
##   ["clear_enemies"] · ["fail", reason] · ["scrap", n] ·
##   ["hazard", "spore"|"flame", at, r, life, dps] (ground that hurts the hero)
## boss {role: "elite"} = a named elite (HP bar over its head, no top bar).

signal level_won
signal level_failed(reason: String)

const MarkerScript := preload("res://scripts/campaign/campaign_marker.gd")
const NpcScript := preload("res://scripts/campaign/campaign_npc.gd")
const POOLS := {
	"plague": ["rad_gator", "toxic_scorp", "glow_moth", "chimera_rat", "rad_bat", "ash_singer", "scav_bear_cub"],
	"machine": ["scrap_hound", "coil_spider", "iron_horse"],
	"raider": ["raider_grunt", "raider_grunt", "raider_brute"],
	"t1": ["rad_gator", "toxic_scorp", "glow_moth", "scrap_hound", "dune_stalker", "coil_spider", "rad_bat", "chimera_rat"],
	"t2": ["scav_bear", "dune_serpent", "fusion_golem", "glow_moth_queen", "geist_alpha", "mech_wyrm"],
	"swarm": ["ash_wraiths", "rad_bat", "chimera_rat"],
}

var mc: Node
var level: Dictionary
var objectives: Array = []
var idx: int = -1
var obj: Dictionary = {}
var t_obj: float = 0.0
var count: float = 0.0
var need: float = 1.0
var finished: bool = false
var busy: bool = false
var npcs: Dictionary = {}
var marker: Node2D
var _items: Array = []
var _triggers: Array = []
var _waves_done: Dictionary = {}
var _trickle_t: float = 0.0
var _spawned: Array = []
var _kills0: int = 0
var _zone: Node2D
var _target_hp: float = 100.0
var _target_max: float = 100.0
var _carry_from: Array = []
var _carrying: bool = false
var _carry_sprite: Node2D
var _boss: Node2D
var _pad: Node2D
var _rng := RandomNumberGenerator.new()


func setup(controller: Node, lv: Dictionary) -> void:
	mc = controller
	level = lv
	objectives = lv.get("objectives", [])
	for t in lv.get("triggers", []):
		var d: Dictionary = (t as Dictionary).duplicate()
		d["fired"] = false
		_triggers.append(d)
	_rng.seed = int(lv.get("seed", 1)) * 13 + 5


func player() -> Node2D:
	return mc.get("player") as Node2D


func start() -> void:
	_next()


## ---------------------------------------------------------------------------
## Objective flow

func _next() -> void:
	busy = false
	idx += 1
	_clear_objective_bits()
	while idx < objectives.size() and not _cond_ok(objectives[idx]):
		idx += 1
	if idx >= objectives.size():
		finished = true
		level_won.emit()
		return
	obj = objectives[idx]
	t_obj = 0.0
	count = 0.0
	need = 1.0
	match str(obj.get("type", "")):
		"kill":
			need = float(obj.get("count", 10))
		"hold", "defend", "survive", "wait":
			need = float(obj.get("time", 10.0))
		"collect":
			need = float((obj.get("items", []) as Array).size())
		"carry":
			need = float(((obj.get("carry", {}) as Dictionary).get("from", []) as Array).size())
	_waves_done = {}
	_trickle_t = 0.0
	_spawned = []
	_kills0 = _kill_count()
	## Scene / setup first, then the objective starts (boss spawns, pads open).
	_update_hud()
	if obj.has("on_start"):
		busy = true
		await run_actions(obj["on_start"])
		busy = false
	if finished or mc == null or bool(mc.call("is_run_over")):
		return
	t_obj = 0.0
	_kills0 = _kill_count()
	_begin(obj)
	_update_hud()


func _cond_ok(o: Dictionary) -> bool:
	if o.has("if_flag"):
		var c: Array = o["if_flag"]
		if not GameState.campaign_flag_is(str(c[0]), c[1] if c.size() > 1 else null):
			return false
	if o.has("unless_flag"):
		var c2: Array = o["unless_flag"]
		if GameState.campaign_flag_is(str(c2[0]), c2[1] if c2.size() > 1 else null):
			return false
	return true


func _begin(o: Dictionary) -> void:
	var typ := str(o.get("type", "reach"))
	var at: Vector2 = o.get("at", Vector2.INF)
	match typ:
		"reach", "talk":
			if typ == "talk" and npcs.has(str(o.get("npc", ""))):
				at = (npcs[str(o["npc"])] as Node2D).global_position
			_set_marker(at, float(o.get("r", 70.0)), "target")
		"hold", "defend":
			need = float(o.get("time", 10.0))
			_zone = _make_marker(at, float(o.get("r", 140.0)), "zone")
			_set_marker(at, float(o.get("r", 140.0)), "target", true)
			if typ == "defend":
				_target_max = float(o.get("hp", 100.0))
				_target_hp = _target_max
		"survive", "wait":
			need = float(o.get("time", 20.0))
		"kill":
			need = float(o.get("count", 10))
		"collect":
			var pts: Array = o.get("items", [])
			need = float(pts.size())
			for p in pts:
				var it := _make_marker(p, 44.0, "item")
				it.set("icon_path", IconSet.path(str(o.get("icon", "ing_medicine")), true))
				_items.append(it)
				## Minimap glyph + screen-edge arrows for every item.
				_pads().append(it)
			if not pts.is_empty():
				mc.call("hud_objective_arrows", true)
		"escort":
			var n: Node = npcs.get(str(o.get("npc", "")), null)
			if n:
				n.set("vulnerable", true)
				n.set("show_bar", true)
				n.call("walk_path", o.get("path", []), float(o.get("lead", 300.0)))
				_set_marker_node(n)
		"carry":
			var c: Dictionary = o.get("carry", {})
			_carry_from = (c.get("from", []) as Array).duplicate()
			need = float(_carry_from.size())
			_carrying = false
			_point_carry()
		"boss":
			var b: Dictionary = o.get("boss", {})
			_boss = _spawn_boss(b)
		"extract":
			_pad = _spawn_pad(at)
			marker = _pad


func _clear_objective_bits() -> void:
	if marker and is_instance_valid(marker):
		if marker.get_script() == MarkerScript:
			marker.queue_free()
	marker = null
	_pads().clear()
	if _zone and is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	for it in _items:
		if is_instance_valid(it):
			it.queue_free()
	_items = []
	if _carry_sprite and is_instance_valid(_carry_sprite):
		_carry_sprite.queue_free()
	_carry_sprite = null
	_carrying = false
	GameState.campaign_carry_slow = 1.0
	_boss = null


func _pads() -> Array:
	return mc.call("get_pads")


func _make_marker(at: Vector2, r: float, kind: String) -> Node2D:
	var m: Node2D = MarkerScript.new()
	m.set("kind", kind)
	m.set("radius", r)
	mc.get("world").add_child(m)
	m.global_position = at
	return m


func _set_marker(at: Vector2, r: float, kind: String, hidden: bool = false) -> void:
	if at == Vector2.INF:
		return
	marker = _make_marker(at, r, kind)
	if hidden:
		marker.visible = false
	_pads().append(marker)
	mc.call("hud_objective_arrows", true)


## Point the arrows at a moving thing (an NPC).
func _set_marker_node(n: Node) -> void:
	marker = n as Node2D
	marker.set_meta("map_glyph", MapIcons.BANG)
	_pads().append(marker)
	mc.call("hud_objective_arrows", true)


func _complete() -> void:
	if busy or finished:
		return
	busy = true
	var o := obj
	Juice.sfx("pick_rare", -4.0)
	if o.has("on_done"):
		await run_actions(o["on_done"])
	_next()


## Admin / tests: finish the current objective right now.
func debug_complete() -> void:
	if busy or finished or obj.is_empty():
		return
	match str(obj.get("type", "")):
		"boss":
			if _boss and is_instance_valid(_boss) and _boss.has_method("take_damage"):
				_boss.call("take_damage", 999999.0, Vector2.ZERO, 0.0, false)
		"extract":
			mc.call("_on_extract_requested")
			return
		"escort":
			var n: Node2D = npcs.get(str(obj.get("npc", "")), null)
			var path: Array = obj.get("path", [])
			if n and not path.is_empty():
				n.global_position = path[path.size() - 1]
	_complete()


func current_target() -> Vector2:
	if marker and is_instance_valid(marker):
		return marker.global_position
	if str(obj.get("type", "")) == "collect":
		var p := player()
		var best := Vector2.INF
		for it in _items:
			if is_instance_valid(it) and p and (best == Vector2.INF or (it as Node2D).global_position.distance_to(p.global_position) < best.distance_to(p.global_position)):
				best = (it as Node2D).global_position
		return best
	if _boss and is_instance_valid(_boss):
		return _boss.global_position
	return Vector2.INF


## ---------------------------------------------------------------------------
## Per frame

func _process(delta: float) -> void:
	if finished or obj.is_empty() or mc == null or bool(mc.call("is_run_over")):
		return
	var p := player()
	if p == null or not is_instance_valid(p):
		return
	_tick_triggers(p)
	if busy:
		_update_hud()
		return
	t_obj += delta
	_tick_waves()
	_tick_trickle(delta)
	var typ := str(obj.get("type", "reach"))
	match typ:
		"reach":
			if p.global_position.distance_to(obj["at"]) <= float(obj.get("r", 70.0)):
				_complete()
		"talk":
			var n: Node2D = npcs.get(str(obj.get("npc", "")), null)
			var at: Vector2 = n.global_position if n else obj.get("at", Vector2.ZERO)
			if marker and is_instance_valid(marker) and n:
				marker.global_position = at
			if p.global_position.distance_to(at) <= float(obj.get("r", 90.0)):
				_complete()
		"hold", "defend":
			var inside := p.global_position.distance_to(obj["at"]) <= float(obj.get("r", 140.0))
			if inside:
				count += delta
			elif typ == "hold":
				count = maxf(0.0, count - delta * 0.5)
			if typ == "defend":
				_tick_defend_target(delta)
			if _zone:
				_zone.set("progress", count / need)
			if count >= need:
				_complete()
		"survive", "wait":
			count += delta
			if count >= need:
				_complete()
		"kill":
			count = float(_kill_count() - _kills0)
			if count >= need:
				_complete()
		"clear":
			if _all_waves_fired() and _alive_spawned() == 0 and t_obj > 1.0:
				_complete()
		"collect":
			for it in _items.duplicate():
				if is_instance_valid(it) and p.global_position.distance_to((it as Node2D).global_position) <= 46.0:
					_items.erase(it)
					_pads().erase(it)
					Juice.sfx("pick_lore", -2.0)
					Juice.float_text((it as Node2D).global_position + Vector2(0, -40), "+1", UiTheme.TEAL, 16)
					(it as Node).queue_free()
					count += 1.0
			if count >= need:
				_complete()
		"escort":
			var en: Node2D = npcs.get(str(obj.get("npc", "")), null)
			if en == null or bool(en.get("dead")):
				_fail(str(obj.get("fail", "They didn't make it.")))
				return
			var path: Array = obj.get("path", [])
			if not path.is_empty() and en.global_position.distance_to(path[path.size() - 1]) < 12.0:
				_complete()
		"carry":
			_tick_carry(p)
		"boss":
			if _boss == null or not is_instance_valid(_boss) or bool(_boss.get("_dead")):
				_complete()
		"extract":
			pass
	_update_hud()


func _tick_defend_target(delta: float) -> void:
	var at: Vector2 = obj["at"]
	var dmg := 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node2D
		if en and is_instance_valid(en) and not bool(en.get("_dead")) and en.global_position.distance_to(at) <= 90.0 * maxf(1.0, float(en.get("body_scale")) * 0.6):
			dmg += float(en.get("damage")) * 0.18
	_target_hp = maxf(0.0, _target_hp - dmg * delta)
	if _zone:
		_zone.set("hp_ratio", _target_hp / _target_max)
	if _target_hp <= 0.0:
		_fail(str(obj.get("fail", "They broke through.")))


func _point_carry() -> void:
	if marker and is_instance_valid(marker):
		_pads().erase(marker)
		marker.queue_free()
	marker = null
	var c: Dictionary = obj.get("carry", {})
	if _carrying:
		_set_marker(c["to"], float(c.get("r", 90.0)), "target")
	elif not _carry_from.is_empty():
		var nearest: Vector2 = _carry_from[0]
		var p := player()
		if p:
			for q in _carry_from:
				if (q as Vector2).distance_to(p.global_position) < nearest.distance_to(p.global_position):
					nearest = q
		_set_marker(nearest, 50.0, "target")
		if marker and c.has("icon"):
			marker.set("icon_path", IconSet.path(str(c["icon"]), true))


func _tick_carry(p: Node2D) -> void:
	var c: Dictionary = obj.get("carry", {})
	if not _carrying:
		for q in _carry_from.duplicate():
			if p.global_position.distance_to(q) <= 54.0:
				_carry_from.erase(q)
				_carrying = true
				GameState.campaign_carry_slow = float(c.get("slow", 0.6))
				_carry_sprite = _make_carry_sprite(str(c.get("icon", "ing_medicine")))
				p.add_child(_carry_sprite)
				Juice.sfx("pickup")
				var lbl := str(c.get("pickup_toast", ""))
				if lbl != "":
					mc.call("toast", lbl, UiTheme.TEAL)
				_point_carry()
				break
	else:
		if p.global_position.distance_to(c["to"]) <= float(c.get("r", 90.0)):
			_carrying = false
			GameState.campaign_carry_slow = 1.0
			if _carry_sprite:
				_carry_sprite.queue_free()
				_carry_sprite = null
			count += 1.0
			Juice.sfx("ui_purchase", -4.0)
			if count >= need:
				_complete()
				return
			_point_carry()


func _make_carry_sprite(icon: String) -> Node2D:
	var s := Sprite2D.new()
	s.texture = IconSet.tex(icon, true)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * UnitAnim.TEXEL
	s.position = Vector2(0, -118)
	s.z_index = 30
	return s


func _tick_triggers(p: Node2D) -> void:
	for t in _triggers:
		if bool(t["fired"]):
			continue
		if t.has("obj") and int(t["obj"]) != idx:
			continue
		if p.global_position.distance_to(t["at"]) <= float(t.get("r", 160.0)):
			t["fired"] = true
			run_actions(t.get("do", []))


func _tick_waves() -> void:
	var waves: Array = obj.get("waves", [])
	for i in range(waves.size()):
		if _waves_done.has(i):
			continue
		var w: Dictionary = waves[i]
		if t_obj >= float(w.get("t", 0.0)):
			_waves_done[i] = true
			_spawn_group(w.get("kinds", "t1"), int(w.get("n", 4)), w.get("at", Vector2.INF), float(w.get("r", 120.0)), str(w.get("role", "")))


## Kills toward a kill objective: all kills, or only `kinds` (ids / pools).
func _kill_count() -> int:
	if not obj.has("kinds"):
		return GameState.kills
	var ids: Array = []
	var ks: Variant = obj["kinds"]
	for k in (ks if ks is Array else [ks]):
		if POOLS.has(str(k)):
			ids.append_array(POOLS[str(k)])
		else:
			ids.append(str(k))
	var n := 0
	for id in ids:
		n += int(GameState.run_kind_kills.get(str(id), 0))
	return n


func _all_waves_fired() -> bool:
	return _waves_done.size() >= (obj.get("waves", []) as Array).size()


func _alive_spawned() -> int:
	var n := 0
	for e in _spawned:
		if is_instance_valid(e) and not bool(e.get("_dead")):
			n += 1
	return n


func _tick_trickle(delta: float) -> void:
	if not obj.has("trickle"):
		return
	var tr: Dictionary = obj["trickle"]
	_trickle_t += delta
	if _trickle_t < float(tr.get("every", 4.0)):
		return
	_trickle_t = 0.0
	if get_tree().get_nodes_in_group("enemies").size() >= int(tr.get("cap", 8)):
		return
	var centre: Vector2 = Vector2.INF
	if str(obj.get("type", "")) == "defend":
		centre = obj["at"]
	_spawn_group(tr.get("kinds", "t1"), int(tr.get("n", 1)), Vector2.INF, 0.0, "", centre)


## kinds: an id, a pool name (POOLS) or an array of either.
func _pick_kind(kinds: Variant) -> String:
	var pool: Array = []
	if kinds is Array:
		for k in kinds:
			if POOLS.has(str(k)):
				pool.append_array(POOLS[str(k)])
			else:
				pool.append(str(k))
	elif POOLS.has(str(kinds)):
		pool = POOLS[str(kinds)]
	else:
		pool = [str(kinds)]
	return str(pool[_rng.randi() % pool.size()])


func _spawn_group(kinds: Variant, n: int, at: Vector2, r: float, role: String = "", centre: Vector2 = Vector2.INF) -> void:
	for i in range(n):
		var spot := Vector2.INF
		if at != Vector2.INF:
			spot = at + Vector2.RIGHT.rotated(TAU * float(i) / maxf(1.0, float(n)) + _rng.randf_range(-0.3, 0.3)) * _rng.randf_range(r * 0.4, r)
		elif centre != Vector2.INF:
			spot = centre + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(480.0, 620.0)
		var e: Node = mc.call("spawn_mob", _pick_kind(kinds), spot, role)
		if e:
			_spawned.append(e)


func _spawn_boss(b: Dictionary) -> Node2D:
	var at: Vector2 = b.get("at", Vector2.INF)
	var e: Node2D = mc.call("spawn_mob", str(b.get("kind", "dread_naught")), at, str(b.get("role", "boss")), float(b.get("hp", 1.0)))
	if e == null:
		return null
	if b.has("name"):
		e.set("display_name", str(b["name"]))
	## Ranged bosses that would kite a melee hero forever stand and fight.
	if b.has("pref"):
		var d: Dictionary = (e.get("_def") as Dictionary).duplicate()
		d["pref"] = float(b["pref"])
		e.set("_def", d)
	if b.has("brain"):
		var path := "res://scripts/campaign/bosses/%s.gd" % str(b["brain"])
		if ResourceLoader.exists(path):
			var br: RefCounted = (load(path) as Script).new()
			if br.has_method("setup"):
				br.call("setup", e, mc)
			e.set("brain", br)
	mc.call("boss_intro", str(b.get("name", EnemyDefs.get_kind(str(b.get("kind", ""))).get("display_name", ""))), str(b.get("epithet", "")))
	_spawned.append(e)
	return e


func _spawn_pad(at: Vector2) -> Node2D:
	var pad: Node2D = mc.call("spawn_extract_pad", at)
	return pad


func _fail(reason: String) -> void:
	if finished:
		return
	finished = true
	level_failed.emit(reason)


## ---------------------------------------------------------------------------
## Actions

func run_actions(list: Array) -> void:
	for a in list:
		if not is_inside_tree() or (mc and bool(mc.call("is_run_over")) and str((a as Array)[0]) != "scene"):
			return
		await _act(a)


func _act(a: Array) -> void:
	var op := str(a[0])
	match op:
		"scene":
			await mc.call("play_scene", str(a[1]))
		"radio":
			mc.call("radio", str(a[1]), str(a[2]))
		"flag":
			GameState.set_campaign_flag(str(a[1]), a[2] if a.size() > 2 else true)
		"spawn":
			_spawn_group(a[1], int(a[2]), a[3] if a.size() > 3 else Vector2.INF, float(a[4]) if a.size() > 4 else 120.0, str(a[5]) if a.size() > 5 else "")
		"npc":
			spawn_npc(a[1])
		"npc_mode":
			var n: Node = npcs.get(str(a[1]), null)
			if n:
				match str(a[2]):
					"follow":
						n.set("mode", "follow")
					"idle":
						n.set("mode", "idle")
					"goto":
						n.call("go_to", a[3])
					"path":
						n.call("walk_path", a[3], float(a[4]) if a.size() > 4 else 300.0)
					"ally":
						n.set("ally", true)
		"npc_label":
			var n2: Node = npcs.get(str(a[1]), null)
			if n2:
				n2.call("set_label", str(a[2]))
		"npc_remove":
			var n3: Node = npcs.get(str(a[1]), null)
			if n3:
				npcs.erase(str(a[1]))
				var tw := (n3 as Node2D).create_tween()
				tw.tween_property(n3, "modulate:a", 0.0, 0.4)
				tw.tween_callback(n3.queue_free)
		"pet_join":
			var n4: Node2D = npcs.get(str(a[1]), null)
			var at := n4.global_position if n4 else player().global_position
			if n4:
				npcs.erase(str(a[1]))
				n4.queue_free()
			mc.call("pet_join", str(a[2]) if a.size() > 2 else "noel", at)
		"banner":
			mc.call("banner", str(a[1]), str(a[2]) if a.size() > 2 else "")
		"toast":
			mc.call("toast", str(a[1]), UiTheme.AMBER)
		"heal":
			var p := player()
			if p and p.has_method("heal"):
				p.call("heal", 999.0)
		"shake":
			Juice.shake(float(a[1]) if a.size() > 1 else 0.3)
		"prop":
			var w: Node = mc.get("wasteland")
			if w and w.has_method("place_prop"):
				w.call("place_prop", str(a[1]), Vector2(float(a[2]), float(a[3])))
		"wait":
			await get_tree().create_timer(float(a[1]), false).timeout
		"if":
			var c: Array = a[1]
			var ok := GameState.campaign_flag_is(str(c[0]), c[1] if c.size() > 1 else null)
			var br: Array = a[2] if ok else (a[3] if a.size() > 3 else [])
			await run_actions(br)
		"hazard":
			var g := Node2D.new()
			g.set_script(load(RunFx.GROUND_FX))
			g.set("mode", str(a[1]))
			g.set("radius", float(a[3]) if a.size() > 3 else 90.0)
			g.set("life", float(a[4]) if a.size() > 4 else 8.0)
			g.set("value", float(a[5]) if a.size() > 5 else 6.0)
			g.position = a[2]
			mc.get("world").add_child(g)
		"scrap":
			var got := GameState.add_scrap(int(a[1]))
			mc.call("toast", "+%d scrap" % got, UiTheme.AMBER)
		"clear_enemies":
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and str(e.get("role")) != "boss":
					e.queue_free()
		"fail":
			_fail(str(a[1]))


func spawn_npc(d: Dictionary) -> Node2D:
	var n: Node2D = NpcScript.new()
	n.set("npc_id", str(d.get("id", "")))
	n.set("hero", str(d.get("hero", "")))
	n.set("pet", str(d.get("pet", "")))
	n.set("enemy_art", str(d.get("enemy", "")))
	n.set("label_text", str(d.get("label", "")))
	n.set("speed", float(d.get("speed", 120.0)))
	n.set("max_hp", float(d.get("hp", 100.0)))
	n.set("ally", bool(d.get("ally", false)))
	n.set("mode", str(d.get("mode", "idle")))
	mc.get("world").add_child(n)
	n.global_position = d.get("at", Vector2.ZERO)
	npcs[str(d.get("id", ""))] = n
	return n


## ---------------------------------------------------------------------------
## HUD tracker

func _update_hud() -> void:
	if obj.is_empty():
		return
	var typ := str(obj.get("type", ""))
	var prog := ""
	var ratio := -1.0
	match typ:
		"hold", "defend", "survive":
			prog = "%d" % int(ceil(maxf(0.0, need - count)))
			ratio = count / maxf(need, 0.01)
		"kill", "collect", "carry":
			prog = "%d/%d" % [int(count), int(need)]
			ratio = count / maxf(need, 0.01)
		"escort":
			var en: Node2D = npcs.get(str(obj.get("npc", "")), null)
			if en:
				ratio = float(en.call("path_progress"))
				prog = "%d%%" % int(round(ratio * 100.0))
		"boss":
			if _boss and is_instance_valid(_boss):
				ratio = 1.0 - float(_boss.get("hp")) / maxf(1.0, float(_boss.get("max_hp")))
	var hint := str(obj.get("hint", ""))
	if typ == "defend" and count < need and player() and player().global_position.distance_to(obj["at"]) > float(obj.get("r", 140.0)):
		hint = "Get back in the ring!"
	if typ == "escort":
		var en2: Node2D = npcs.get(str(obj.get("npc", "")), null)
		if en2 and bool(en2.call("is_waiting")):
			hint = "Stay close: they won't move without you"
	if typ == "carry" and _carrying:
		hint = str((obj.get("carry", {}) as Dictionary).get("carry_hint", "Bring it home. Heavy load: you're slower"))
	mc.call("hud_objective", str(obj.get("text", "")), prog, ratio, hint)
