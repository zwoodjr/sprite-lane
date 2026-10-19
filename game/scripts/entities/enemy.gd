extends CharacterBody2D

## Wasteland enemy — sheet-locked looks via EnemyDefs; combat archetypes:
##   raider  – keeps mid range, telegraphs then fires single shots
##   charger – sprints in, winds up, lunges for contact damage
##   brute   – slow tank, fires a 3-bullet spread
## Every attack has a visible wind-up so a good dash always beats it.

signal died

const BulletScene := preload("res://scenes/entities/bullet.tscn")
## Built from EnemyDefs (sheet crops). Legacy raider/charger/brute still resolve.
static var KINDS: Dictionary = {}

var kind: String = "raider"
var hp: float = 40.0
var max_hp: float = 40.0
var damage: float = 8.0
var speed: float = 110.0
var _def: Dictionary = {}
var _fire_cd: float = 0.0
var _windup_left: float = 0.0
var _lunge_left: float = 0.0
var _lunge_dir: Vector2 = Vector2.ZERO
var _tele_at: Vector2 = Vector2.ZERO
var _knock: Vector2 = Vector2.ZERO
var _strafe_sign: float = 1.0
var _player: Node2D
var _dead: bool = false
var _spawn_in: float = 0.35
var _distract_left: float = 0.0
var _anim: UnitAnim = UnitAnim.new()
## <id>_attack.json: {hit_frames, origin per attack frame, type melee|ranged}.
var _atk: Dictionary = {}
var _atk_hits_left: int = 0
var _atk_dir: Vector2 = Vector2.RIGHT
var _facing_left: bool = false
var _hit_anim_cd: float = 0.0
## Size class multiplier from EnemyDefs (melee reach / hit radius use it).
var body_scale: float = 1.0
## 1 normal · 2 elite · 3 boss (off-screen arrow size, loot).
var tier: int = 1
## "" normal · "elite" · "boss" (set by the match's elite / boss schedule).
var role: String = ""
## Mechanical mob (Short Circuit bonus when stunned).
var machine: bool = false
## Depth Update: "plague" | "machine" | "raider" (EnemyDefs.faction).
var faction: String = "plague"
## Status effects (Phase 4): id -> {time, value}. poison / burn (value = dps),
## stun, slow (value = speed multiplier), mark (value = damage-taken mult).
var _status: Dictionary = {}
var _dot_t: float = 0.0
## Rubble Wall: briefly after a big knockback this mob smashes into others.
var _rubble_left: float = 0.0
var _rubble_hit: Array = []
const STATUS_TINT := {
	"stun": Color(1.25, 1.2, 0.6), "burn": Color(1.3, 0.8, 0.55), "poison": Color(0.75, 1.2, 0.6),
	"slow": Color(0.7, 0.95, 1.35), "mark": UpgradeDefs.MARK_TINT,
}
const STATUS_ORDER := ["stun", "mark", "burn", "poison", "slow"]
const RUBBLE_KNOCK := 150.0

@onready var body: Sprite2D = $Body
@onready var hp_bar: ProgressBar = $HpBar

var _warn: Polygon2D
## Red ground ring before charge / area attacks (top-level, world space).
var _tele: Sprite2D
var _tele_frames: Array[Texture2D] = []

## World px spanned by one 128 px mob frame at body_scale 1. Elite (192 px)
## and boss (256 px) art map to fixed size classes so they read bigger.
const MOB_FRAME_WORLD := 64.0
const ELITE_SCALE := 1.5
const BOSS_SCALE := 2.05
## Feet sit this far below the collision centre at body_scale 1.
const FEET_Y := 16.0
## Charger lunge: speed multiplier and contact radius (player r14 + mob ~16 + slack).
const LUNGE_SPEED_MULT := 3.4
const LUNGE_HIT_RADIUS := 38.0
## Health tonic drop chance by tier (normal / elite / boss) and heal amount.
const TONIC_CHANCE := [0.06, 0.15, 0.4]
const TONIC_HEAL := 12.0
const SEPARATION_PX := 54.0
const TELEGRAPH_TEX := "res://assets/sprites/fx/telegraph_ring.png"

func _ensure_kinds() -> void:
	if KINDS.is_empty():
		KINDS = EnemyDefs.combat_kinds_table()

func _archetype() -> String:
	## Combat behavior bucket (raider / charger / brute). Kind id is the sheet slug.
	var a := str(_def.get("archetype", ""))
	if a != "":
		return a
	## Legacy ids
	if kind in ["charger", "brute", "raider"]:
		return kind
	return "raider"

## Shadow Step decoy: walk to `pos` and ignore the hero for a while.
var _lure_left: float = 0.0
var _lure_pos: Vector2 = Vector2.ZERO

func lure(pos: Vector2, seconds: float) -> void:
	_lure_pos = pos
	_lure_left = maxf(_lure_left, seconds)
	_cancel_attack()

func distract(seconds: float) -> void:
	## Bentley bark — cancel wind-up / lunge and pause aggression briefly.
	_distract_left = maxf(_distract_left, seconds)
	_windup_left = 0.0
	_lunge_left = 0.0
	_fire_cd = maxf(_fire_cd, seconds)
	if _warn:
		_warn.color.a = 0.0
	if _tele:
		_tele.visible = false

func setup(spawn_pos: Vector2, hp_mult: float, dmg_mult: float, spd_mult: float = 1.0, kind_id: String = "rad_gator") -> void:
	global_position = spawn_pos
	_ensure_kinds()
	kind = kind_id if KINDS.has(kind_id) else "rad_gator"
	_def = KINDS[kind]
	body_scale = float(_def.get("scale", 1.0))
	tier = int(_def.get("tier", 1))
	machine = kind in EnemyDefs.MACHINE_IDS
	faction = EnemyDefs.faction(kind)
	max_hp = float(_def["hp"]) * hp_mult
	hp = max_hp
	damage = float(_def["damage"]) * dmg_mult
	speed = float(_def["speed"]) * spd_mult * randf_range(0.92, 1.08)
	_fire_cd = randf_range(0.6, 1.6)
	_strafe_sign = -1.0 if randf() < 0.5 else 1.0
	if is_inside_tree():
		_apply_look()

## Promote to an elite / boss (EnemyDefs.ROLE_STATS): tougher, bigger arrow, rewards.
func set_role(r: String) -> void:
	var st: Dictionary = EnemyDefs.ROLE_STATS.get(r, {})
	if st.is_empty():
		return
	role = r
	tier = int(st.get("tier", tier))
	max_hp *= float(st.get("hp", 1.0))
	hp = max_hp
	damage *= float(st.get("damage", 1.0))
	speed *= float(st.get("speed", 1.0))
	add_to_group("elites" if r == "elite" else "bosses")
	if is_inside_tree() and hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp

func _ready() -> void:
	add_to_group("enemies")
	_ensure_kinds()
	if _def.is_empty():
		_def = KINDS.get("rad_gator", {})
	if body and body.texture == null:
		body.texture = load(str(_def.get("sprite", "res://assets/sprites/enemies/rad_gator/rad_gator_idle.png")))
	## Wind-up warning: a pulsing red wedge toward the player.
	_warn = Polygon2D.new()
	_warn.polygon = PackedVector2Array([Vector2(16, -10), Vector2(70, 0), Vector2(16, 10)])
	_warn.color = Color(1.0, 0.25, 0.15, 0.0)
	_warn.z_index = 2
	add_child(_warn)
	_build_telegraph()
	_style_bar()
	_apply_look()
	_anim.frame_event.connect(_on_anim_frame)
	_spawn_entrance()

## Bosses roar on arrival, Dune-Serpent bursts out of the sand; everyone else
## fades in out of the dust. Nobody acts until their entrance is done.
func _spawn_entrance() -> void:
	Juice.dust_puff(global_position + Vector2(0, FEET_Y * body_scale), 6)
	if _anim.has_state("emerge"):
		_anim.play("emerge")
		_spawn_in = maxf(_spawn_in, _anim.frame_count("emerge") / 10.0)
		Juice.dust_puff(global_position + Vector2(0, FEET_Y * body_scale), 10)
		return
	if _anim.has_state("roar"):
		_anim.play("roar")
		_spawn_in = maxf(_spawn_in, _anim.frame_count("roar") / 10.0)
		Juice.shake(0.35)
		Juice.sfx("ability", 0.0, 0.5)
		return
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)

func _build_telegraph() -> void:
	if not ResourceLoader.exists(TELEGRAPH_TEX):
		return
	var tex := load(TELEGRAPH_TEX) as Texture2D
	var fw := tex.get_height()
	for i in range(maxi(1, tex.get_width() / fw)):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fw)
		_tele_frames.append(at)
	_tele = Sprite2D.new()
	_tele.top_level = true
	_tele.z_index = -2
	_tele.texture = _tele_frames[0]
	_tele.visible = false
	add_child(_tele)

## Show the ground ring at `where` with world radius r; k = windup progress 0..1.
func _show_telegraph(where: Vector2, r: float, k: float) -> void:
	if _tele == null:
		return
	_tele.visible = true
	_tele.global_position = where
	var base := r * 2.0 / float(_tele_frames[0].get_width())
	_tele.scale = Vector2(base, base * 0.55) * (0.7 + 0.3 * k)
	_tele.texture = _tele_frames[mini(_tele_frames.size() - 1, int(k * _tele_frames.size()))]
	_tele.modulate = Color(1.0, 0.25, 0.2, 0.45 + 0.5 * k)

func _apply_look() -> void:
	if body:
		var prefix := str(_def.get("anim", "res://assets/sprites/enemies/rad_gator/rad_gator"))
		var states := UnitAnim.load_states(prefix)
		var fs := 128
		if states.has("idle"):
			fs = (states["idle"]["tex"] as Texture2D).get_height()
		## Size class from the art: normal 128 (per-kind scale), elite 192, boss 256.
		if fs >= 256:
			body_scale = BOSS_SCALE
		elif fs >= 192:
			body_scale = ELITE_SCALE
		else:
			body_scale = clampf(float(_def.get("scale", 1.0)), 0.85, 1.4)
		body.self_modulate = _def.get("tint", Color.WHITE)
		_anim.setup(body, prefix, MOB_FRAME_WORLD * body_scale, FEET_Y * body_scale)
		_atk = UnitAnim.load_json(prefix + "_attack.json")
		var col := get_node_or_null("CollisionShape2D") as Node2D
		if col:
			col.scale = Vector2.ONE * body_scale
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		var top := FEET_Y * body_scale - MOB_FRAME_WORLD * body_scale * 0.92
		hp_bar.offset_top = top
		hp_bar.offset_bottom = top + 6.0
		hp_bar.offset_left = -16.0 * sqrt(body_scale)
		hp_bar.offset_right = 16.0 * sqrt(body_scale)

## Art-driven attack kind: "ranged" fires from the JSON origin, "melee" hits
## around it. Chargers always lunge (their strip plays during the lunge).
func _atk_type() -> String:
	return str(_atk.get("type", "ranged" if _archetype() != "charger" else "melee"))

func _atk_hit_frames() -> Array:
	var hf: Variant = _atk.get("hit_frames", [1])
	return hf if hf is Array and not (hf as Array).is_empty() else [1]

## Attack origin (mouth / claw / muzzle) of attack frame f, in world space.
func _atk_origin(f: int) -> Vector2:
	var arr: Array = _atk.get("origin", [])
	if arr.is_empty() or not _anim.is_ready():
		return global_position + _atk_dir * 18.0 * body_scale
	var o: Array = arr[clampi(f, 0, arr.size() - 1)]
	return global_position + _anim.frame_to_local(Vector2(float(o[0]), float(o[1])))

## Melee mobs (non-chargers) must close in: start the windup at bite reach.
func _melee_reach() -> float:
	if _archetype() == "brute":
		return 70.0 * body_scale * 0.75
	var arr: Array = _atk.get("origin", [])
	var ox := 24.0 * body_scale
	if not arr.is_empty() and _anim.is_ready():
		ox = absf(_anim.frame_to_local(Vector2(float((arr[0] as Array)[0]), 0.0)).x)
	return ox + 22.0

func _attack_range() -> float:
	if _archetype() != "charger" and _atk_type() == "melee":
		return _melee_reach()
	return float(_def["range"])

func _pref_range() -> float:
	if _archetype() != "charger" and _atk_type() == "melee":
		return 0.0
	return float(_def["pref"])

func _style_bar() -> void:
	if hp_bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.03, 0.02, 0.8)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.92, 0.35, 0.25)
	fill.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("background", bg)
	hp_bar.add_theme_stylebox_override("fill", fill)
	hp_bar.visible = false  ## only shown once damaged

func _process(delta: float) -> void:
	_anim.tick(delta)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _spawn_in > 0.0:
		_spawn_in -= delta
		return
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_distract_left = maxf(0.0, _distract_left - delta)
	_hit_anim_cd = maxf(0.0, _hit_anim_cd - delta)
	_tick_status(delta)
	if _dead:
		return
	if _rubble_left > 0.0:
		_tick_rubble(delta)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	## Stunned, or the hero vanished (Nyx's Back Way Out): no attacks, drift.
	var hidden := _player != null and _player.has_method("is_hidden") and bool(_player.call("is_hidden"))
	if has_status("stun") or hidden:
		_cancel_attack()
		var drift := Vector2.ZERO
		if hidden and not has_status("stun") and _player:
			drift = (global_position - _player.global_position).normalized().orthogonal() * speed * 0.3 * _strafe_sign
		velocity = velocity.move_toward(drift, 900.0 * delta) + _knock
		_knock = _knock.move_toward(Vector2.ZERO, 1400.0 * delta)
		move_and_slide()
		_update_anim(false)
		return
	if _lure_left > 0.0:
		_lure_left -= delta
		var to_lure := _lure_pos - global_position
		var want := to_lure.normalized() * speed if to_lure.length() > 20.0 else Vector2.ZERO
		velocity = velocity.move_toward(want, 900.0 * delta) + _knock
		_knock = _knock.move_toward(Vector2.ZERO, 1400.0 * delta)
		move_and_slide()
		_update_anim(false)
		return
	if _player == null:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		_update_anim(false)
		return
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player / maxf(dist, 0.001)

	if _distract_left > 0.0:
		velocity = velocity.move_toward(dir.orthogonal() * speed * 0.35, 700.0 * delta)
		move_and_slide()
		_update_anim(false)
		return

	## Wind-up in progress: hold still and telegraph.
	if _windup_left > 0.0:
		_windup_left -= delta
		_warn.rotation = dir.angle()
		var k := 1.0 - _windup_left / float(_def["windup"])
		_warn.color.a = 0.25 + 0.55 * k
		_warn.scale = Vector2(0.6 + 0.6 * k, 1.0)
		match _archetype():
			"charger":
				## Where the lunge will land: the hero's spot when the wind-up began.
				_show_telegraph(_tele_at, LUNGE_HIT_RADIUS * body_scale + 10.0, k)
			"brute":
				_show_telegraph(global_position + Vector2(0, 12), 70.0 * body_scale, k)
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta) + _knock
		move_and_slide()
		_knock = _knock.move_toward(Vector2.ZERO, 1400.0 * delta)
		_face(dir.x)
		if _windup_left <= 0.0:
			_warn.color.a = 0.0
			if _tele:
				_tele.visible = false
			_attack(dir)
		return

	if _lunge_left > 0.0:
		_lunge_left -= delta
		velocity = _lunge_dir * speed * LUNGE_SPEED_MULT * _slow_mult()
		move_and_slide()
		## Enemies don't collide with the player layer, so test contact by
		## distance after the move: player radius (14) + body half-width + slack.
		var contact := global_position.distance_to(_player.global_position)
		if contact <= LUNGE_HIT_RADIUS * body_scale and _player.has_method("take_damage"):
			_player.take_damage(damage, self)
			_lunge_left = 0.0
			_knock = -_lunge_dir * 160.0
		return

	var chase := speed * _slow_mult()
	## Carried medicine: the plague smells it and comes faster.
	if faction == EnemyDefs.PLAGUE and GameState.smells_medicine():
		chase *= MedicineDefs.SMELL_PLAGUE_SPEED
	if _player.has_method("get_active_buffs") and (_player.get_active_buffs() as Dictionary).has("quiet") and dist > 220.0:
		chase *= 0.75
	var pref := _pref_range()
	var want := Vector2.ZERO
	if _archetype() == "charger" or dist > pref:
		want = dir * chase
	elif dist < pref * 0.6:
		want = -dir * chase * 0.7
	else:
		want = dir.orthogonal() * chase * 0.55 * _strafe_sign
	want += _separation() * chase * 1.1
	velocity = velocity.move_toward(want, 900.0 * delta) + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	move_and_slide()
	_update_anim(false)
	if dist <= _attack_range() and _fire_cd <= 0.0 and not _anim.is_playing("attack"):
		_windup_left = float(_def["windup"])
		_tele_at = _player.global_position
		_face(dir.x)
		## Windup strip spans the windup (a hair longer so it never snaps to idle).
		_anim.play_over("windup", _windup_left * 1.08)
		if randf() < 0.3:
			_strafe_sign *= -1.0

func _face(x: float) -> void:
	if absf(x) > 0.05:
		_facing_left = x < 0.0
		_anim.set_facing(_facing_left)

## Walk / idle from actual velocity (walk rate follows speed); faces travel.
func _update_anim(_attacking: bool) -> void:
	var v := velocity.length()
	if v > 20.0:
		if absf(velocity.x) > 8.0:
			_face(velocity.x)
		_anim.set_locomotion("walk", clampf(v / maxf(speed, 60.0), 0.6, 1.6))
	else:
		_anim.set_locomotion("idle")

## Mobs push apart (size-aware) so hordes flow around each other.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == self or not (n is Node2D):
			continue
		var other := n as Node2D
		var d := global_position - other.global_position
		var l := d.length()
		var reach := SEPARATION_PX * (body_scale + float(other.get("body_scale"))) * 0.5
		if l < 0.1:
			d = Vector2.RIGHT.rotated(randf() * TAU)
			l = 0.1
		if l < reach:
			push += d / l * (1.0 - l / reach)
	return push.limit_length(1.5)

func _attack(dir: Vector2) -> void:
	_fire_cd = float(_def["cooldown"]) * randf_range(0.85, 1.2)
	_atk_dir = dir
	_face(dir.x)
	if _archetype() == "charger":
		_lunge_dir = dir
		## Long enough to actually reach where the player stood (+ a little overshoot).
		var to_p := _player.global_position.distance_to(global_position) if _player else 120.0
		_lunge_left = clampf((to_p + 30.0) / maxf(speed * LUNGE_SPEED_MULT, 1.0), 0.18, 0.4)
		Juice.dust_puff(global_position + Vector2(0, FEET_Y * body_scale), 5)
		_atk_hits_left = 0
		_anim.play("attack", float(_anim.frame_count("attack")) / maxf(_lunge_left + 0.1, 0.2))
		return
	## Damage / projectiles land on the attack strip's hit frames.
	_atk_hits_left = _atk_hit_frames().size()
	_anim.play("attack")
	if not _anim.has_state("attack"):
		while _atk_hits_left > 0:
			_atk_hit(0)

func _on_anim_frame(state: String, f: int) -> void:
	if state == "attack" and _atk_hits_left > 0 and f in _atk_hit_frames():
		_atk_hit(f)

func _atk_hit(f: int) -> void:
	if _dead or _player == null or not is_instance_valid(_player):
		_atk_hits_left = 0
		return
	var first := _atk_hits_left == _atk_hit_frames().size()
	_atk_hits_left -= 1
	var origin := _atk_origin(f)
	var share := 1.0 / float(_atk_hit_frames().size())
	if _atk_type() == "ranged":
		var aim := (_player.global_position - origin).normalized()
		if aim.length() < 0.1:
			aim = _atk_dir
		if _archetype() == "brute" and first:
			for a in [-0.22, 0.0, 0.22]:
				_fire_from(origin, aim.rotated(a), 360.0, damage)
			Juice.sfx("enemy_shot", -2.0)
		else:
			_fire_from(origin, aim, 430.0 if _archetype() != "brute" else 380.0, damage)
			Juice.sfx("enemy_shot", -6.0)
		return
	## Melee: brutes slam the telegraphed ring; others bite / claw at the origin.
	var hit := false
	if _archetype() == "brute":
		var centre := global_position + Vector2(0, 12)
		hit = _player.global_position.distance_to(centre) <= 70.0 * body_scale + 10.0
		if first:
			Juice.shake(0.12 * body_scale)
			Juice.dust_puff(centre, 10)
	else:
		hit = _player.global_position.distance_to(origin) <= 18.0 + 12.0 * body_scale
	if hit and _player.has_method("take_damage"):
		_player.take_damage(damage * share, self)

func _fire_from(origin: Vector2, dir: Vector2, spd: float, dmg: float) -> void:
	var bullet: Area2D = BulletScene.instantiate()
	bullet.setup(origin, dir, spd, dmg, false, self)
	get_tree().current_scene.add_child(bullet)

## knock < 0 → default bullet knockback. crit → bigger amber damage number.
## num_color (alpha > 0) tints the number (status ticks).
func take_damage(amount: float, from_dir: Vector2 = Vector2.ZERO, knock: float = -1.0, crit: bool = false, num_color: Color = Color(0, 0, 0, 0)) -> void:
	if _dead:
		return
	amount *= damage_taken_mult()
	hp -= amount
	if hp_bar:
		hp_bar.visible = true
		hp_bar.value = hp
	_anim.flash(0.08)
	if _hit_anim_cd <= 0.0 and _anim.has_state("hit") and not (_anim.is_busy() or _windup_left > 0.0 or _lunge_left > 0.0):
		_anim.play("hit")
		_hit_anim_cd = 0.35
	if num_color.a > 0.0:
		Juice.damage_number(global_position + Vector2(0, -26), amount, false, num_color)
	else:
		Juice.damage_number(global_position + Vector2(0, -26), amount, crit)
		Juice.sfx("hit", -8.0)
	if from_dir.length() > 0.01:
		var resist := 0.35 if _archetype() == "brute" else 1.0
		var k := 220.0 if knock < 0.0 else knock
		_knock += from_dir.normalized() * k * resist
		if k * resist >= RUBBLE_KNOCK and GameState.run_rank("rubble_wall") > 0:
			_rubble_left = 0.35
			_rubble_hit.clear()
	if hp <= 0.0:
		_die()

func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	var range_v: Vector2i = _def.get("scrap", Vector2i(1, 3))
	var scrap := int(round(float(randi_range(range_v.x, range_v.y)) * GameState.run_scrap_mult()))
	GameState.kills += 1
	GameState.note_kill(kind)
	_status.clear()
	## Loot pops out and magnets to the hero: scrap bolts + Dust-shard XP,
	## sometimes a small health tonic (more often from elites/bosses).
	var parent := get_parent()
	var xp := int(_def.get("xp", 3))
	LootDrop.spawn_burst(parent, global_position, "scrap", clampi(scrap, 1, 4), float(scrap))
	LootDrop.spawn_burst(parent, global_position, "xp", clampi(xp / 4 + 1, 1, 4), float(xp))
	HaulPickup.drop_kill(parent, global_position + Vector2(randf_range(-10, 10), 6), faction, role)
	if randf() < TONIC_CHANCE[clampi(tier, 1, 3) - 1]:
		LootDrop.spawn_burst(parent, global_position, "tonic", 1, TONIC_HEAL)
	## Rare special-ammo can (more likely from elites / bosses).
	## Gated behind the Hangar's Ammo Bench (rank = types, odds).
	if GameState.ammo_pickups_enabled() and randf() < float(UpgradeDefs.AMMO_DROP_CHANCE[clampi(tier, 1, 3) - 1]) * GameState.ammo_odds_mult():
		var aid := RunFx.random_bench_ammo_id()
		if aid != "":
			RunFx.spawn_ammo_pickup(parent, global_position + Vector2(randf_range(-20, 20), 10), aid)
	## Gear: elites / bosses pay out their rewards; everyone else rolls a small chance.
	if role != "":
		GearPickup.drop_role_reward(parent, global_position, role, kind)
		GameState.quest_event("elite")
		if role == "boss":
			GameState.on_boss_killed(kind)
			Juice.float_text(global_position + Vector2(0, -60), "BOSS DOWN  +×%.1f LOOT" % GearDefs.BOSS_LOOT_BONUS, UiTheme.AMBER, 22)
	else:
		GearPickup.maybe_drop(parent, global_position, GearDefs.KILL_DROP_CHANCE)
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("on_kill"):
		pl.call("on_kill", self)
	Juice.sfx("enemy_die", -2.0)
	Juice.burst(global_position, Color(0.95, 0.55, 0.3), 18, 220.0, 0.5)
	Juice.burst(global_position, Color(0.6, 0.5, 0.4, 0.8), 10, 90.0, 0.7, 1.6)
	Juice.shake(0.12 if _archetype() != "brute" else 0.3)
	if _archetype() == "brute":
		Juice.hitstop(0.06)
	died.emit()
	collision_layer = 0
	_warn.visible = false
	if _tele:
		_tele.visible = false
	hp_bar.visible = false
	_atk_hits_left = 0
	## Death strip (it fades itself out), then a short fade and free.
	var dur := 0.2
	if _anim.has_state("death"):
		_anim.play("death")
		dur = _anim.frame_count("death") / 10.0
	var tw := create_tween()
	tw.tween_interval(dur * 0.85)
	tw.tween_property(self, "modulate:a", 0.0, dur * 0.15 + 0.1)
	tw.tween_callback(queue_free)


## =============================================================================
## Status effects (upgrades, special ammo, abilities)

func apply_status(id: String, time: float, value: float = 0.0) -> void:
	if _dead:
		return
	var cur: Dictionary = _status.get(id, {})
	var v := value
	if id == "slow":
		## Slow keeps the strongest (lowest) multiplier.
		v = minf(value, float(cur.get("value", 1.0))) if cur.size() > 0 else value
	else:
		v = maxf(value, float(cur.get("value", 0.0)))
	_status[id] = {"time": maxf(time, float(cur.get("time", 0.0))), "value": v}
	if id == "stun":
		_cancel_attack()

func has_status(id: String) -> bool:
	return _status.has(id)

func status_value(id: String, default: float = 0.0) -> float:
	return float((_status.get(id, {}) as Dictionary).get("value", default))

func _cancel_attack() -> void:
	_windup_left = 0.0
	_lunge_left = 0.0
	if _warn:
		_warn.color.a = 0.0
	if _tele:
		_tele.visible = false

func _slow_mult() -> float:
	return status_value("slow", 1.0) if has_status("slow") else 1.0

## Marked (Vesper / Quill) and Short Circuit (Juno: stunned machines) bonuses.
func damage_taken_mult() -> float:
	var m := 1.0
	if has_status("mark"):
		m *= status_value("mark", 1.0)
	if has_status("stun") and GameState.run_rank("short_circuit") > 0:
		m *= float(GameState.up("short_circuit", "machine" if machine else "other", 1.0))
	return m

func _tick_status(delta: float) -> void:
	if _status.is_empty():
		_apply_status_tint()
		return
	for id in _status.keys():
		_status[id]["time"] = float(_status[id]["time"]) - delta
		if float(_status[id]["time"]) <= 0.0:
			_status.erase(id)
	_dot_t += delta
	if _dot_t >= UpgradeDefs.POISON_TICK:
		_dot_t = 0.0
		var dps := 0.0
		var col := Color(0.6, 1.0, 0.45)
		if has_status("burn"):
			dps += status_value("burn")
			col = Color(1.0, 0.6, 0.3)
		if has_status("poison"):
			dps += status_value("poison")
		if dps > 0.0:
			take_damage(dps * UpgradeDefs.POISON_TICK, Vector2.ZERO, 0.0, false, col)
	_apply_status_tint()

func _apply_status_tint() -> void:
	if body == null:
		return
	var c := Color.WHITE
	if _distract_left > 0.0:
		c = Color(1.15, 1.05, 0.7)
	for id in STATUS_ORDER:
		if _status.has(id):
			c = STATUS_TINT[id]
			break
	body.modulate = c

## Rubble Wall: a mob flying from a big knockback smashes the ones it meets.
func _tick_rubble(delta: float) -> void:
	_rubble_left -= delta
	if _knock.length() < 60.0:
		return
	var r := float(GameState.up("rubble_wall", "radius", 46.0)) * body_scale
	var p := get_tree().get_first_node_in_group("player")
	var dmg := float(GameState.up("rubble_wall", "damage", 14.0)) * (float(p.get("damage_mult")) if p else 1.0)
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == self or n in _rubble_hit or not is_instance_valid(n):
			continue
		var o := n as Node2D
		if o.global_position.distance_to(global_position) > r:
			continue
		_rubble_hit.append(o)
		o.call("take_damage", dmg, _knock.normalized(), 120.0)
		take_damage(dmg * 0.5, Vector2.ZERO, 0.0)
		Juice.dust_puff(o.global_position, 6)
		Juice.shake(0.05)
		if _dead:
			return
