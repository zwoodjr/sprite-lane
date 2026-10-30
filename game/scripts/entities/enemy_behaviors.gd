extends RefCounted

## Wander mob behaviors on top of the 3 archetypes (shooter / lunger / slammer).
## Rides the enemy's `brain` slot: tick(e, delta) -> true when it owns the frame.
## Every attack has a wind-up with a ground telegraph (the red ring) first.
##
##   spitter   — lobs an acid glob at where you stand; it splashes and leaves a
##               puddle for a few seconds. (plague: Ash-Singer, Glow-Moth Queen)
##   burrower  — dives under the sand, tunnels at you (dust trail, can't be hit),
##               then bursts up under a red ring. (plague: Dune-Stalker, Dune-Serpent)
##   exploder  — runs you down, stops and blinks, then blows up. Kill it while it
##               blinks and the blast hits its friends instead. (machine: Coil-Spider;
##               plague: Void-Spider)
##   shield    — frontal shield (hit it from behind) + a shield bash that shoves you
##               when you hug its front. (machine: Iron-Horse, Fusion-Golem)
##   summoner  — hangs back and calls minions in a purple ring; kill it and they
##               crumble. (plague: Geist-Alpha, Apocalypse Wraith)

## Balance (bot A/B, Haze stay-3): the first pass took deaths 2/16 -> 12/15;
## softer hits, a longer fuse and a thinner puddle (the bot never dodges rings).
const SPIT := {"cd": 4.5, "windup": 0.85, "radius": 52.0, "flight": 0.55, "dmg": 0.9,
	"pool_time": 2.2, "pool_tick": 0.5, "pool_dmg": 0.15, "min": 110.0, "max": 430.0}
const BURROW := {"surface": 6.0, "under_max": 2.6, "under_speed": 1.6, "rise": 0.9, "radius": 58.0, "dmg": 1.0}
const BOOM := {"arm_at": 62.0, "fuse": 1.1, "radius": 80.0, "dmg": 1.3, "chase": 1.1, "chain_dmg": 1.6}
const BASH := {"reach": 88.0, "windup": 0.55, "cd": 3.5, "shove": 460.0, "dmg": 0.5}
## Share of each trick-kind spawn that actually uses its trick, by zone tier
## (Haze stays gentle; full from Smog up).
const SHARE_BY_TIER: Array = [0.5, 0.75, 1.0]
const SUMMON := {"cd": 8.0, "channel": 1.25, "max_alive": 4, "hp": 0.6, "global_cap": 14}

## Which kind gets which behavior (+ per-kind extras).
const BY_KIND := {
	"ash_singer": {"b": "spitter"},
	"glow_moth_queen": {"b": "spitter", "globs": 3},
	"dune_stalker": {"b": "burrower"},
	"dune_serpent": {"b": "burrower"},
	"coil_spider": {"b": "exploder"},
	"void_spider": {"b": "exploder"},
	"iron_horse": {"b": "shield"},
	"fusion_golem": {"b": "shield"},
	"geist_alpha": {"b": "summoner", "minion": "rad_bat", "n": 2},
	"apocalypse_wraith": {"b": "summoner", "minion": "chimera_rat", "n": 3},
}

var id: String = ""
var opts: Dictionary = {}
var _cd: float = 0.0
var _wind: float = 0.0
var _at: Vector2 = Vector2.ZERO
var _state: String = ""
var _t: float = 0.0
var _trail_t: float = 0.0
var _minions: Array = []
var _init_done: bool = false


static func for_kind(kind: String) -> RefCounted:
	if not BY_KIND.has(kind):
		return null
	var t := clampi(GameState.zone_tier(), 1, SHARE_BY_TIER.size())
	if randf() >= float(SHARE_BY_TIER[t - 1]):
		return null
	var b: RefCounted = load("res://scripts/entities/enemy_behaviors.gd").new()
	b.id = str(BY_KIND[kind]["b"])
	b.opts = BY_KIND[kind]
	return b


static func behavior_of(kind: String) -> String:
	return str((BY_KIND.get(kind, {}) as Dictionary).get("b", ""))


func tick(e: Node, delta: float) -> bool:
	if not _init_done:
		_init_done = true
		_cd = randf_range(1.2, 2.6)
		_t = randf_range(2.0, BURROW["surface"])
		if id == "shield" and not ("shielded" in (e.get("traits") as Array)):
			var tr: Array = (e.get("traits") as Array).duplicate()
			tr.append("shielded")
			e.call("set_traits", tr)
	var p := e.get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return false
	## Stunned: drop the wind-up, let the base AI drift.
	if e.call("has_status", "stun"):
		if _wind > 0.0:
			_wind = 0.0
			_hide_tele(e)
		if id == "burrower" and _state != "":
			_surface(e, false)
		return false
	_cd = maxf(0.0, _cd - delta)
	match id:
		"spitter":
			return _tick_spitter(e, p, delta)
		"burrower":
			return _tick_burrower(e, p, delta)
		"exploder":
			return _tick_exploder(e, p, delta)
		"shield":
			return _tick_shield(e, p, delta)
		"summoner":
			return _tick_summoner(e, p, delta)
	return false


func on_death(e: Node) -> void:
	_hide_tele(e)
	match id:
		"exploder":
			## Killed mid-fuse: the blast goes off on its friends (player's credit).
			if _wind > 0.0:
				var p := e.get_tree().get_first_node_in_group("player") as Node2D
				if p:
					RunFx.explosion(p, (e as Node2D).global_position, BOOM["radius"], float(e.get("damage")) * BOOM["chain_dmg"],
						Color(1.0, 0.55, 0.2), "blast", 300.0, 0.0, "fire")
		"summoner":
			for m in _minions:
				if is_instance_valid(m) and not bool(m.get("_dead")):
					m.call("take_damage", 99999.0, Vector2.ZERO, 0.0, false)
			_minions.clear()


## --- helpers -----------------------------------------------------------------

func _hold(e: Node, delta: float) -> void:
	var bv: Vector2 = e.get("_base_vel")
	e.set("_base_vel", bv.move_toward(Vector2.ZERO, 900.0 * delta))
	var kn: Vector2 = e.get("_knock")
	e.set("velocity", e.get("_base_vel") + kn)
	e.set("_knock", kn.move_toward(Vector2.ZERO, 1400.0 * delta))
	e.call("move_and_slide")


## Hold a ring around the hero at `pref` px: close in, back off, strafe.
func _kite(e: Node, p: Node2D, delta: float, pref: float) -> void:
	var me := e as Node2D
	var to := p.global_position - me.global_position
	var d := to.length()
	var dir := to / maxf(d, 0.001)
	var sp := float(e.get("speed")) * float(e.call("_slow_mult"))
	var want := Vector2.ZERO
	if d > pref * 1.25:
		want = dir * sp
	elif d < pref * 0.75:
		want = -dir * sp * 0.85
	else:
		want = dir.orthogonal() * sp * 0.5 * float(e.get("_strafe_sign"))
	want += (e.call("_separation") as Vector2) * sp
	var bv: Vector2 = e.get("_base_vel")
	e.set("_base_vel", bv.move_toward(want, 900.0 * delta))
	var kn: Vector2 = e.get("_knock")
	e.set("velocity", e.get("_base_vel") + kn)
	e.set("_knock", kn.move_toward(Vector2.ZERO, 1400.0 * delta))
	e.call("move_and_slide")
	e.call("_face", dir.x)
	e.call("_update_anim", false)


func _hide_tele(e: Node) -> void:
	var t: Variant = e.get("_tele")
	if t != null and is_instance_valid(t):
		(t as Node2D).visible = false


func _ctl(e: Node) -> Node:
	return e.get_tree().get_first_node_in_group("match_ctl")


func _hit_player_in(e: Node, p: Node2D, at: Vector2, r: float, dmg: float) -> void:
	if p.global_position.distance_to(at) <= r + 14.0 and p.has_method("take_damage"):
		p.call("take_damage", dmg, e)


## --- spitter -----------------------------------------------------------------

func _tick_spitter(e: Node, p: Node2D, delta: float) -> bool:
	## Its own lob replaces the base shot.
	e.set("_fire_cd", 99.0)
	var d := (e as Node2D).global_position.distance_to(p.global_position)
	if _wind > 0.0:
		_wind -= delta
		var k := 1.0 - _wind / SPIT["windup"]
		var n := int(opts.get("globs", 1))
		e.call("_show_telegraph", _at, SPIT["radius"] * (1.0 if n == 1 else 1.6), k)
		e.call("_face", (p.global_position - (e as Node2D).global_position).x)
		_hold(e, delta)
		if _wind <= 0.0:
			_hide_tele(e)
			for i in range(n):
				var off := Vector2.ZERO if i == 0 else Vector2.RIGHT.rotated(TAU * float(i) / float(n - 1) + 0.4) * 52.0
				_lob(e, _at + off)
			_cd = SPIT["cd"] * (0.85 if n > 1 else 1.0)
		return true
	if _cd <= 0.0 and d >= SPIT["min"] and d <= SPIT["max"]:
		_wind = SPIT["windup"]
		_at = p.global_position
		var anim: Variant = e.get("_anim")
		if anim != null:
			anim.call("play_over", "windup", SPIT["windup"] * 1.08)
		Juice.sfx_at("hit_flesh", (e as Node2D).global_position, -8.0)
		return true
	_kite(e, p, delta, 260.0)
	return true


func _lob(e: Node, at: Vector2) -> void:
	var world := (e as Node).get_parent()
	if world == null:
		return
	var g := Glob.new()
	g.from = (e as Node2D).global_position + Vector2(0, -18.0 * float(e.get("body_scale")))
	g.to = at
	g.flight = SPIT["flight"]
	g.dmg = float(e.get("damage")) * SPIT["dmg"]
	g.src = e
	world.add_child(g)


class Glob extends Node2D:
	var from: Vector2
	var to: Vector2
	var flight: float = 0.5
	var dmg: float = 10.0
	var src: Node
	var _t: float = 0.0

	func _ready() -> void:
		z_index = 50
		global_position = from

	func _process(delta: float) -> void:
		_t += delta
		var k := clampf(_t / flight, 0.0, 1.0)
		global_position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 90.0)
		queue_redraw()
		if k >= 1.0:
			var p := get_tree().get_first_node_in_group("player") as Node2D
			if p and p.global_position.distance_to(to) <= SPIT["radius"] + 14.0 and p.has_method("take_damage"):
				p.call("take_damage", dmg, src if is_instance_valid(src) else null)
			Juice.fx("ex_plague", to + Vector2(0, -6))
			Juice.sfx_at("hit_flesh", to, -4.0)
			var pool := Pool.new()
			pool.at = to
			pool.dmg = dmg * SPIT["pool_dmg"] / SPIT["dmg"]
			get_parent().add_child(pool)
			queue_free()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 8.0, Color(0.55, 1.0, 0.3, 0.95))
		draw_circle(Vector2(-2, -2), 3.5, Color(0.9, 1.0, 0.7, 0.9))


class Pool extends Node2D:
	var at: Vector2
	var dmg: float = 3.0
	var _left: float = SPIT["pool_time"]
	var _tick: float = 0.0

	func _ready() -> void:
		z_index = -3
		global_position = at

	func _process(delta: float) -> void:
		_left -= delta
		_tick -= delta
		if _tick <= 0.0:
			_tick = SPIT["pool_tick"]
			var p := get_tree().get_first_node_in_group("player") as Node2D
			if p and p.global_position.distance_to(at) <= SPIT["radius"] and p.has_method("drain"):
				p.call("drain", dmg)
		modulate.a = clampf(_left / 0.6, 0.0, 1.0)
		if _left <= 0.0:
			queue_free()

	func _draw() -> void:
		var r: float = SPIT["radius"]
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, r, Color(0.35, 0.85, 0.2, 0.28))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(0.55, 1.0, 0.3, 0.55), 2.0)


## --- burrower ----------------------------------------------------------------

func _tick_burrower(e: Node, p: Node2D, delta: float) -> bool:
	var me := e as Node2D
	match _state:
		"":
			_t -= delta
			if _t <= 0.0 and not bool(e.get("_dead")):
				_dive(e)
				return true
			return false
		"under":
			_t += delta
			var to := p.global_position - me.global_position
			e.set("velocity", to.normalized() * float(e.get("speed")) * BURROW["under_speed"] * float(e.call("_slow_mult")))
			e.call("move_and_slide")
			_trail_t -= delta
			if _trail_t <= 0.0:
				_trail_t = 0.12
				Juice.dust_puff(me.global_position + Vector2(0, 10), 2)
			if (to.length() < 36.0 and _t >= 0.8) or _t >= BURROW["under_max"]:
				_state = "rise"
				_wind = BURROW["rise"]
				_at = me.global_position
			return true
		"rise":
			_wind -= delta
			e.call("_show_telegraph", _at, BURROW["radius"], 1.0 - _wind / BURROW["rise"])
			if int(Engine.get_process_frames()) % 6 == 0:
				Juice.dust_puff(_at + Vector2(randf_range(-20, 20), 8), 1)
			if _wind <= 0.0:
				_hide_tele(e)
				_hit_player_in(e, p, _at, BURROW["radius"], float(e.get("damage")) * BURROW["dmg"])
				Juice.dust_puff(_at + Vector2(0, 8), 10)
				Juice.shake(0.12)
				_surface(e, true)
			return true
	return false


func _dive(e: Node) -> void:
	_state = "under"
	_t = 0.0
	e.set("phased", true)
	e.call("_cancel_attack")
	(e as Node).remove_from_group("enemies")
	_set_seen(e, false)
	Juice.dust_puff((e as Node2D).global_position + Vector2(0, 10), 8)


func _surface(e: Node, ok: bool) -> void:
	_state = ""
	_t = BURROW["surface"] + randf_range(-1.0, 1.5)
	e.set("phased", false)
	if not (e as Node).is_in_group("enemies") and not bool(e.get("_dead")):
		(e as Node).add_to_group("enemies")
	_set_seen(e, true)
	if not ok:
		_hide_tele(e)


func _set_seen(e: Node, on: bool) -> void:
	for nm in ["body", "hp_bar", "_tag", "_aura", "_shield"]:
		var n: Variant = e.get(nm)
		if n != null and is_instance_valid(n) and n is CanvasItem:
			(n as CanvasItem).visible = on


## --- exploder ----------------------------------------------------------------

func _tick_exploder(e: Node, p: Node2D, delta: float) -> bool:
	var me := e as Node2D
	e.set("_fire_cd", 99.0)
	var d := me.global_position.distance_to(p.global_position)
	if _wind > 0.0:
		_wind -= delta
		var k := 1.0 - _wind / BOOM["fuse"]
		e.call("_show_telegraph", me.global_position + Vector2(0, 10), BOOM["radius"], k)
		## Blink faster as the fuse burns.
		var blink := fmod(k * (6.0 + 10.0 * k), 1.0) < 0.5
		me.modulate = Color(1.6, 0.5, 0.4) if blink else Color.WHITE
		_hold(e, delta)
		if _wind <= 0.0:
			_hide_tele(e)
			me.modulate = Color.WHITE
			_hit_player_in(e, p, me.global_position, BOOM["radius"], float(e.get("damage")) * BOOM["dmg"])
			Juice.fx("ex_fire" if str(e.get("faction")) == EnemyDefs.MACHINE else "ex_plague", me.global_position)
			Juice.shake(0.25)
			Juice.sfx_at("explosion" if ResourceLoader.exists("res://assets/audio/sfx/explosion.ogg") else "hit_metal", me.global_position, -2.0)
			## Self-destruct: gone, no blast on its friends, no loot.
			_wind = 0.0
			e.set_meta("no_loot", true)
			e.set("hp", 0.0)
			e.call("_die")
		return true
	if d <= BOOM["arm_at"]:
		_wind = BOOM["fuse"]
		Juice.sfx_at("hit_metal", me.global_position, -6.0)
		return true
	## Always runs you down (a touch faster than its base chase).
	var dir := (p.global_position - me.global_position) / maxf(d, 0.001)
	var want := dir * float(e.get("speed")) * BOOM["chase"] * float(e.call("_slow_mult")) + (e.call("_separation") as Vector2) * float(e.get("speed"))
	var bv: Vector2 = e.get("_base_vel")
	e.set("_base_vel", bv.move_toward(want, 900.0 * delta))
	var kn: Vector2 = e.get("_knock")
	e.set("velocity", e.get("_base_vel") + kn)
	e.set("_knock", kn.move_toward(Vector2.ZERO, 1400.0 * delta))
	e.call("move_and_slide")
	e.call("_face", dir.x)
	e.call("_update_anim", false)
	return true


## --- shield-bearer -----------------------------------------------------------

func _tick_shield(e: Node, p: Node2D, delta: float) -> bool:
	var me := e as Node2D
	var to := p.global_position - me.global_position
	if _wind > 0.0:
		_wind -= delta
		var k := 1.0 - _wind / BASH["windup"]
		e.call("_show_telegraph", me.global_position + to.normalized() * BASH["reach"] * 0.6, BASH["reach"] * 0.55, k)
		_hold(e, delta)
		if _wind <= 0.0:
			_hide_tele(e)
			if to.length() <= BASH["reach"] + 14.0:
				p.call("take_damage", float(e.get("damage")) * BASH["dmg"], e)
				if "_knock_v" in p:
					p.set("_knock_v", (p.get("_knock_v") as Vector2) + to.normalized() * BASH["shove"])
			Juice.shake(0.1)
			Juice.sfx_at("hit_metal", me.global_position, -3.0)
			_cd = BASH["cd"]
		return true
	## Keep the shield on you.
	e.call("_face", to.x)
	if _cd <= 0.0 and to.length() <= BASH["reach"]:
		_wind = BASH["windup"]
		e.call("_cancel_attack")
		return true
	return false


## --- summoner ----------------------------------------------------------------

func _tick_summoner(e: Node, p: Node2D, delta: float) -> bool:
	var me := e as Node2D
	_minions = _minions.filter(func(m: Variant) -> bool: return is_instance_valid(m) and not bool(m.get("_dead")))
	if _wind > 0.0:
		_wind -= delta
		var k := 1.0 - _wind / SUMMON["channel"]
		e.call("_show_telegraph", me.global_position + Vector2(0, 10), 70.0, k)
		var t: Variant = e.get("_tele")
		if t != null and is_instance_valid(t):
			(t as Node2D).modulate = Color(0.75, 0.35, 1.0, 0.5 + 0.5 * k)
		_hold(e, delta)
		if _wind <= 0.0:
			_hide_tele(e)
			_call_minions(e)
			_cd = SUMMON["cd"]
		return true
	var d := me.global_position.distance_to(p.global_position)
	if _cd <= 0.0 and d < 620.0 and _minions.size() < int(SUMMON["max_alive"]) \
			and e.get_tree().get_nodes_in_group("summoned").size() < int(SUMMON["global_cap"]):
		_wind = SUMMON["channel"]
		e.call("_cancel_attack")
		var anim: Variant = e.get("_anim")
		if anim != null:
			anim.call("play_over", "windup", SUMMON["channel"] * 1.05)
		return true
	## Hangs back behind its minions; its own shot still fires in range.
	if d < 180.0:
		_kite(e, p, delta, 320.0)
		return true
	return false


func _call_minions(e: Node) -> void:
	var mc := _ctl(e)
	if mc == null or not mc.has_method("spawn_mob"):
		return
	var me := e as Node2D
	var n := int(opts.get("n", 2))
	for i in range(n):
		var at := me.global_position + Vector2.RIGHT.rotated(TAU * float(i) / float(n) + randf()) * 54.0
		var m: Node = mc.call("spawn_mob", str(opts.get("minion", "rad_bat")), at, "", SUMMON["hp"])
		if m:
			m.add_to_group("summoned")
			m.set_meta("summoned", true)
			_minions.append(m)
			Juice.dust_puff(at + Vector2(0, 8), 4)
