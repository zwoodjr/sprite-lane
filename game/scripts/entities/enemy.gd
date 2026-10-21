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
## Depth E7 zone twists: Ash-Wraith phasing (untouchable), Crater City revive.
var phased: bool = false
var _downed_left: float = 0.0
var _revived: bool = false
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
## E2: elite traits (FactionDefs.TRAITS), raider crew, infighting foe.
var traits: Array = []
var crew: Node = null
var _foe: Node2D = null
var _foe_check: float = 0.0
var _infight_cd: float = 0.0
var _weak_text_cd: float = 0.0
var _spore_t: float = 0.0
var _repair_uses: int = 0
var _repair_left: float = 0.0
var _overheat_t: float = 0.0
var _overheat_left: float = 0.0
var _shield: Polygon2D
## Minimap marker colour when this mob carries a raider bag.
var map_color: Color = Color(1.0, 0.6, 0.2)
var _aura: Line2D
var _tag: Label
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
	## Military Base: the war machines are enraged.
	if faction == EnemyDefs.MACHINE and GameState.twist_on("machines_enraged"):
		var zs := ZoneDefs.strength(GameState.zone_tier())
		damage *= 1.0 + (float(ZoneDefs.MACHINES_ENRAGED["damage"]) - 1.0) * zs
		speed *= 1.0 + (float(ZoneDefs.MACHINES_ENRAGED["speed"]) - 1.0) * zs
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
		_style_bar()

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
		Juice.mob_sfx("roar", self)
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
		## Gameplay size (collision, reach, separation) grows with BODY_K; the art
		## itself always draws at native density (1 texel = 1 screen px).
		if fs >= 256:
			body_scale = BOSS_SCALE
		elif fs >= 192:
			body_scale = ELITE_SCALE
		else:
			body_scale = clampf(float(_def.get("scale", 1.0)), 0.85, 1.4)
		body_scale *= UnitAnim.BODY_K
		body.self_modulate = _def.get("tint", Color.WHITE)
		_anim.setup(body, prefix, UnitAnim.native(fs), FEET_Y * body_scale)
		_atk = UnitAnim.load_json(prefix + "_attack.json")
		var sh := get_node_or_null("ContactShadow") as Sprite2D
		if sh:
			sh.queue_free()
		UnitAnim.add_contact_shadow(self, 44.0 * body_scale, FEET_Y * body_scale, 0.5)
		var col := get_node_or_null("CollisionShape2D") as Node2D
		if col:
			col.scale = Vector2.ONE * body_scale
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		var top := FEET_Y * body_scale - _anim.world_frame_px() * 0.66
		hp_bar.offset_top = top
		hp_bar.offset_bottom = top + 4.0
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
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.92, 0.35, 0.25) if role != "elite" else Color(1.0, 0.7, 0.25)
	hp_bar.add_theme_stylebox_override("background", bg)
	hp_bar.add_theme_stylebox_override("fill", fill)
	hp_bar.visible = false  ## only shown once damaged

## Per-mob HP bars (audit #6): elites always, bosses use the top-of-screen
## bar instead, everyone else only for a moment after being hit.
const BAR_SHOW := 1.8
var _bar_left: float = 0.0


func _tick_bar(delta: float) -> void:
	if hp_bar == null or _dead:
		return
	_bar_left = maxf(0.0, _bar_left - delta)
	var want := false
	if role == "elite":
		want = true
	elif role != "boss":
		want = _bar_left > 0.0
	if hp_bar.visible != want:
		hp_bar.visible = want
	if want and role == "":
		hp_bar.modulate.a = clampf(_bar_left / 0.4, 0.0, 1.0)


func _process(delta: float) -> void:
	_anim.set_motion(velocity, speed)
	_anim.tick(delta)
	_tick_bar(delta)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _spawn_in > 0.0:
		_spawn_in -= delta
		return
	if _downed_left > 0.0:
		_tick_downed(delta)
		return
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_distract_left = maxf(0.0, _distract_left - delta)
	_hit_anim_cd = maxf(0.0, _hit_anim_cd - delta)
	_tick_status(delta)
	if _dead:
		return
	if _rubble_left > 0.0:
		_tick_rubble(delta)
	_weak_text_cd = maxf(0.0, _weak_text_cd - delta)
	_infight_cd = maxf(0.0, _infight_cd - delta)
	if not traits.is_empty() and _tick_traits(delta):
		return
	if kind == RadioDefs.WARDEN_KIND and role == "boss" and _tick_warden(delta):
		return
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _tick_infight(delta):
		return
	if crew != null and is_instance_valid(crew) and not bool(crew.call("is_hunting")):
		_follow_crew(delta)
		return
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
	if "overclocked" in traits:
		_fire_cd *= float(FactionDefs.TRAITS["overclocked"]["cooldown"])
	_atk_dir = dir
	_face(dir.x)
	if _atk_type() != "ranged":
		Juice.mob_sfx("attack", self, -2.0)
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
			Juice.mob_sfx("shot", self, 0.0)
		else:
			_fire_from(origin, aim, 430.0 if _archetype() != "brute" else 380.0, damage)
			Juice.mob_sfx("shot", self, -3.0)
		return
	## Melee: brutes slam the telegraphed ring; others bite / claw at the origin.
	var hit := false
	if _archetype() == "brute":
		var centre := global_position + Vector2(0, 12)
		hit = _player.global_position.distance_to(centre) <= 70.0 * body_scale + 10.0
		if first:
			Juice.shake(0.12 * body_scale / UnitAnim.BODY_K)
			Juice.dust_puff(centre, 10)
			Juice.sfx_at("brute_slam", centre, -3.0)
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
	## Phased Ash-Wraiths: hits pass straight through.
	if phased:
		return
	## Burrow ambushers (opening waves) can't be hit while still emerging.
	if _spawn_in > 0.0 and has_meta("ambush"):
		return
	## Downed (Crater City): any hit finishes it for good.
	if _downed_left > 0.0:
		_downed_left = 0.0
		modulate = Color.WHITE
		hp = 0.0
		_die()
		return
	amount *= damage_taken_mult()
	## Shielded elites shrug off hits from the front.
	if "shielded" in traits and from_dir.length() > 0.01:
		var face := Vector2.LEFT if _facing_left else Vector2.RIGHT
		var half := deg_to_rad(float(FactionDefs.TRAITS["shielded"]["arc_deg"])) * 0.5
		if absf(face.angle_to(-from_dir.normalized())) < half:
			amount *= 1.0 - float(FactionDefs.TRAITS["shielded"]["reduce"])
			if _shield:
				_shield.modulate.a = 1.0
	if _overheat_left > 0.0:
		amount *= float(FactionDefs.TRAITS["overclocked"]["overheat_taken"])
	hp -= amount
	if hp_bar:
		_bar_left = BAR_SHOW
		hp_bar.value = hp
	_anim.flash(0.08)
	if _hit_anim_cd <= 0.0 and _anim.has_state("hit") and not (_anim.is_busy() or _windup_left > 0.0 or _lunge_left > 0.0):
		_anim.play("hit")
		_hit_anim_cd = 0.35
	if num_color.a > 0.0:
		Juice.damage_number(global_position + Vector2(0, -26), amount, false, num_color, self)
	else:
		Juice.damage_number(global_position + Vector2(0, -26), amount, crit, Color(1, 0.97, 0.9), self)
		if crit:
			Juice.crit_stop()
		Juice.sfx_at("hit_metal" if faction == EnemyDefs.MACHINE else "hit_flesh", global_position, -3.0)
		Juice.mob_sfx("hurt", self, -5.0)
		Juice.fx_impact(global_position + Vector2(0, -6.0 * body_scale) - from_dir.normalized() * 8.0, faction)
	if from_dir.length() > 0.01:
		var resist := 0.35 if _archetype() == "brute" else 1.0
		var k := 220.0 if knock < 0.0 else knock
		_knock += from_dir.normalized() * k * resist
		if k * resist >= RUBBLE_KNOCK and GameState.run_rank("rubble_wall") > 0:
			_rubble_left = 0.35
			_rubble_hit.clear()
	if hp <= 0.0:
		if _try_go_down():
			return
		_die()

## Crater City: some mobs drop and get back up unless you finish them.
func _try_go_down() -> bool:
	if _revived or role != "" or crew != null or not GameState.twist_on("revive"):
		return false
	if randf() >= float(ZoneDefs.REVIVE["chance"]) * ZoneDefs.strength(GameState.zone_tier()):
		return false
	_revived = true
	hp = 1.0
	_downed_left = float(ZoneDefs.REVIVE["time"])
	modulate = Color(0.55, 0.5, 0.48)
	if hp_bar:
		hp_bar.value = hp
	Juice.float_text(global_position + Vector2(0, -40), "DOWN — finish it!", Color(1.0, 0.7, 0.4), 14)
	return true

func _tick_downed(delta: float) -> void:
	velocity = Vector2.ZERO
	_downed_left -= delta
	if _downed_left <= 0.0:
		_downed_left = 0.0
		hp = max_hp * float(ZoneDefs.REVIVE["hp"])
		modulate = Color.WHITE
		if hp_bar:
			hp_bar.value = hp
		Juice.float_text(global_position + Vector2(0, -40), "BACK UP!", Color(1.0, 0.45, 0.35), 15)
		Juice.dust_puff(global_position + Vector2(0, 10), 8)

## True while lying downed (Crater City) — still a target, one hit finishes it.
func is_downed() -> bool:
	return _downed_left > 0.0

func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	_evo_on_death()
	if "bloated" in traits:
		_bloat_burst()
	elif faction == EnemyDefs.PLAGUE and role == "" and GameState.twist_on("infected_burst") and randf() < float(ZoneDefs.INFECTED_BURST["chance"]) * ZoneDefs.strength(GameState.zone_tier()):
		_bloat_burst(ZoneDefs.INFECTED_BURST)
	if crew != null and is_instance_valid(crew):
		crew.call("on_member_died", self)
	if _aura:
		_aura.visible = false
	if _tag:
		_tag.visible = false
	var range_v: Vector2i = _def.get("scrap", Vector2i(1, 3))
	## Find bonuses (Scavenger's Eye etc.) apply once, on pickup (GameState.add_scrap).
	var scrap := randi_range(range_v.x, range_v.y)
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
	if GameState.pact_fx("no_tonics") <= 0.0 and randf() < TONIC_CHANCE[clampi(tier, 1, 3) - 1]:
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
		## Depth E7: this tier's exclusive legendary, now and then.
		var zt := GameState.zone_tier()
		if not ZoneDefs.exclusive(zt).is_empty() and randf() < (ZoneDefs.EXCLUSIVE_BOSS_CHANCE if role == "boss" else ZoneDefs.EXCLUSIVE_ELITE_CHANCE):
			GearPickup.spawn(parent, global_position + Vector2(0, -20), GameState.make_exclusive(zt))
		GameState.quest_event("elite")
		if role == "boss":
			var bb := GameState.boss_loot_bonus
			GameState.on_boss_killed(kind)
			var gained := GameState.boss_loot_bonus - bb
			Juice.float_text(global_position + Vector2(0, -60), ("BOSS DOWN  +×%.1f LOOT" % gained) if gained > 0.0 else "BOSS DOWN", UiTheme.AMBER, 22)
	else:
		GearPickup.maybe_drop(parent, global_position, GearDefs.KILL_DROP_CHANCE)
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("on_kill"):
		pl.call("on_kill", self)
	Juice.mob_sfx("die", self)
	Juice.fx_death(global_position + Vector2(0, (FEET_Y - 10.0) * body_scale), faction, _archetype() == "brute" or role != "")
	Juice.shake(0.12 if _archetype() != "brute" else 0.3)
	## Kill hitstop for every hero (light; heavy for brutes / elites / bosses).
	Juice.kill_stop(_archetype() == "brute" or role != "")
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
			dps += status_value("burn") * FactionDefs.weakness(faction, "fire")
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
	if phased:
		body.modulate = Color(0.6, 0.8, 1.0, 0.35)
		return
	if _distract_left > 0.0:
		c = Color(1.15, 1.05, 0.7)
	for id in STATUS_ORDER:
		if _status.has(id):
			c = STATUS_TINT[id]
			break
	body.modulate = c
	Juice.status_fx(self, _status, FEET_Y * body_scale - _anim.world_frame_px() * 0.62 - 6.0)

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

## =============================================================================
## Depth Update E2: elite traits, infighting, raider crews

## Give this elite its traits (FactionDefs.TRAITS): aura ring + a name tag.
func set_traits(ids: Array) -> void:
	traits = ids.duplicate()
	if traits.is_empty():
		return
	_repair_uses = int(FactionDefs.TRAITS["self_repair"]["uses"])
	_overheat_t = float(FactionDefs.TRAITS["overclocked"]["every"])
	if "overclocked" in traits:
		speed *= float(FactionDefs.TRAITS["overclocked"]["speed"])
	var col: Color = FactionDefs.TRAITS[str(traits[0])]["color"]
	_aura = Line2D.new()
	var pts := PackedVector2Array()
	for i in range(33):
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a) * 26.0, sin(a) * 10.0) * body_scale)
	_aura.points = pts
	_aura.width = 3.0
	_aura.default_color = Color(col.r, col.g, col.b, 0.75)
	_aura.position = Vector2(0, FEET_Y * body_scale - 2)
	_aura.z_index = -1
	add_child(_aura)
	_tag = Label.new()
	var names: PackedStringArray = []
	for t in traits:
		names.append(FactionDefs.trait_name(str(t)).to_upper())
	_tag.text = " · ".join(names)
	_tag.add_theme_font_size_override("font_size", 11)
	_tag.add_theme_color_override("font_color", col)
	_tag.add_theme_constant_override("outline_size", 4)
	_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.size = Vector2(160, 16)
	_tag.position = Vector2(-80, FEET_Y * body_scale - _anim.world_frame_px() * 0.66 - 18.0)
	_tag.z_index = 4
	add_child(_tag)
	if "shielded" in traits:
		_shield = Polygon2D.new()
		var sp := PackedVector2Array()
		var half := deg_to_rad(float(FactionDefs.TRAITS["shielded"]["arc_deg"])) * 0.5
		for i in range(9):
			var a2 := lerpf(-half, half, i / 8.0)
			sp.append(Vector2(cos(a2), sin(a2) * 0.8) * 30.0 * body_scale)
		for i in range(8, -1, -1):
			var a3 := lerpf(-half, half, i / 8.0)
			sp.append(Vector2(cos(a3), sin(a3) * 0.8) * 24.0 * body_scale)
		_shield.polygon = sp
		_shield.color = Color(0.45, 0.75, 1.0, 0.55)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shield.material = add
		_shield.position = Vector2(0, -8 * body_scale)
		_shield.z_index = 3
		_shield.modulate.a = 0.5
		add_child(_shield)


func trait_names() -> String:
	var out: PackedStringArray = []
	for t in traits:
		out.append(FactionDefs.trait_name(str(t)))
	return " ".join(out)


## Per-frame trait upkeep. True = this frame is spent (repairing / venting).
func _tick_traits(delta: float) -> bool:
	if _shield:
		_shield.scale.x = -1.0 if _facing_left else 1.0
		_shield.modulate.a = move_toward(_shield.modulate.a, 0.5, delta * 2.0)
	if "regrowing" in traits and not has_status("burn") and hp < max_hp:
		hp = minf(max_hp, hp + max_hp * float(FactionDefs.TRAITS["regrowing"]["regen"]) * delta)
		if hp_bar:
			hp_bar.value = hp
	if "sporing" in traits and velocity.length() > 20.0:
		_spore_t -= delta
		if _spore_t <= 0.0:
			var sd: Dictionary = FactionDefs.TRAITS["sporing"]
			_spore_t = float(sd["every"])
			_spore_cloud(global_position + Vector2(0, FEET_Y * body_scale - 4), float(sd["radius"]), float(sd["time"]), float(sd["dps"]))
	if "self_repair" in traits:
		var rd: Dictionary = FactionDefs.TRAITS["self_repair"]
		if _repair_left > 0.0:
			if has_status("stun"):
				_repair_left = 0.0
				Juice.float_text(global_position + Vector2(0, -50), "REPAIR BROKEN", UiTheme.TEAL, 13)
			else:
				_repair_left -= delta
				hp = minf(max_hp, hp + max_hp * float(rd["heal"]) / float(rd["time"]) * delta)
				if hp_bar:
					hp_bar.value = hp
				if randf() < 0.3:
					Juice.burst(global_position + Vector2(randf_range(-14, 14), -10), Color(0.55, 1.0, 0.75), 2, 60.0, 0.3)
				velocity = Vector2.ZERO
				_update_anim(false)
				return true
		elif _repair_uses > 0 and hp < max_hp * float(rd["below"]) and not has_status("stun"):
			_repair_uses -= 1
			_repair_left = float(rd["time"])
			_cancel_attack()
			Juice.float_text(global_position + Vector2(0, -50), "SELF-REPAIR", Color(0.55, 1.0, 0.75), 14)
	if "overclocked" in traits:
		var od: Dictionary = FactionDefs.TRAITS["overclocked"]
		if _overheat_left > 0.0:
			_overheat_left -= delta
			if randf() < 0.25:
				Juice.burst(global_position + Vector2(0, -20), Color(0.8, 0.8, 0.8, 0.7), 2, 50.0, 0.5, 1.4)
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			move_and_slide()
			_update_anim(false)
			return true
		_overheat_t -= delta
		if _overheat_t <= 0.0:
			_overheat_t = float(od["every"])
			_overheat_left = float(od["overheat"])
			_cancel_attack()
			Juice.float_text(global_position + Vector2(0, -50), "OVERHEAT", Color(1.0, 0.55, 0.25), 14)
	return false


func _spore_cloud(at: Vector2, r: float, life: float, dps: float) -> void:
	var g := Node2D.new()
	g.set_script(load(RunFx.GROUND_FX))
	g.set("mode", "spore")
	g.set("radius", r)
	g.set("life", life)
	g.set("value", dps)
	g.position = at
	get_parent().add_child.call_deferred(g)


## Bloated: bursts in a spray of plague when it dies.
func _bloat_burst(params: Dictionary = {}) -> void:
	var bd: Dictionary = params if not params.is_empty() else FactionDefs.TRAITS["bloated"]
	var r := float(bd["radius"])
	RunFx.ring(get_parent(), global_position + Vector2(0, 8), r, Color(0.75, 0.9, 0.35), 0.45, 6.0)
	Juice.fx("ex_plague", global_position + Vector2(0, -8))
	Juice.burst(global_position, Color(0.7, 0.85, 0.3), 10, r * 2.2, 0.6, 1.6)
	Juice.shake(0.25)
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null and p.global_position.distance_to(global_position) <= r and p.has_method("take_damage"):
		p.call("take_damage", float(bd["damage"]), self)
		GameState.add_exposure(MedicineDefs.HIT_GAIN)
	_spore_cloud(global_position, r * 0.6, float(bd["pool_time"]), float(bd["pool_dps"]))


## Infighting: hostile factions brawl when they get close (not while the hero is on them).
func _tick_infight(delta: float) -> bool:
	_foe_check -= delta
	if _foe_check <= 0.0:
		_foe_check = FactionDefs.INFIGHT_CHECK * randf_range(0.8, 1.2)
		var hero_close := _player != null and _player.global_position.distance_to(global_position) < FactionDefs.INFIGHT_IGNORE_HERO_WITHIN
		if hero_close or _windup_left > 0.0 or _lunge_left > 0.0:
			_foe = null
		elif _foe == null or not is_instance_valid(_foe) or bool(_foe.get("_dead")) \
				or _foe.global_position.distance_to(global_position) > FactionDefs.INFIGHT_LEASH:
			_foe = _find_foe()
	if _foe == null or not is_instance_valid(_foe) or bool(_foe.get("_dead")):
		_foe = null
		return false
	var to := _foe.global_position - global_position
	var d := to.length()
	_face(to.x)
	if d > FactionDefs.INFIGHT_HIT_RANGE * maxf(body_scale, 1.0):
		velocity = velocity.move_toward(to / maxf(d, 0.01) * speed * _slow_mult(), 900.0 * delta) + _knock
		_knock = _knock.move_toward(Vector2.ZERO, 1400.0 * delta)
		move_and_slide()
		_update_anim(false)
		return true
	velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	if _infight_cd <= 0.0 and not _anim.is_playing("attack"):
		_infight_cd = FactionDefs.INFIGHT_COOLDOWN * randf_range(0.85, 1.2)
		_anim.play("attack")
		Juice.burst(_foe.global_position + Vector2(0, -10), Color(1.0, 0.8, 0.5), 6, 120.0, 0.25)
		var foe := _foe
		foe.call("take_damage", damage * FactionDefs.INFIGHT_DAMAGE, to / maxf(d, 0.01), FactionDefs.INFIGHT_KNOCK)
		if is_instance_valid(foe) and not bool(foe.get("_dead")) and foe.get("_foe") == null:
			foe.set("_foe", self)
	else:
		_update_anim(false)
	return true


func _find_foe() -> Node2D:
	var best: Node2D = null
	var bd := FactionDefs.INFIGHT_RANGE * maxf(body_scale, 1.0)
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == self or not is_instance_valid(n) or not (n is Node2D):
			continue
		if not FactionDefs.hostile(faction, str(n.get("faction"))):
			continue
		var d := (n as Node2D).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = n
	return best


## Raider crew on the move (looting a crate, regrouping): follow the crew's goal.
func _follow_crew(delta: float) -> void:
	var goal: Vector2 = crew.call("goal_for", self)
	var to := goal - global_position
	var want := Vector2.ZERO
	if to.length() > 14.0:
		want = to.normalized() * speed * FactionDefs.CREW_SPEED * _slow_mult()
	want += _separation() * speed * 0.6
	velocity = velocity.move_toward(want, 900.0 * delta) + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	move_and_slide()
	_update_anim(false)


## Damage-number hint when a weakness lands.
func note_weak_hit() -> void:
	if _weak_text_cd > 0.0:
		return
	_weak_text_cd = FactionDefs.WEAK_TEXT_CD
	Juice.float_text(global_position + Vector2(0, -46), "WEAK!", Color(1.0, 0.8, 0.35), 13)


## Depth E3 evolutions that trigger on a kill: Plague Bloom (poisoned burst),
## Death Knell (marked explode), Fortune's Favor (ammo drops).
func _evo_on_death() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	if GameState.has_evo("plague_bloom") and has_status("poison"):
		RunFx.ground(get_parent(), p, global_position + Vector2(0, 8), "poison",
			float(GameState.up("plague_bloom", "cloud_r", 70.0)), float(GameState.up("plague_bloom", "cloud_time", 3.5)),
			float(GameState.up("plague_bloom", "cloud_dps", 14.0)))
		Juice.burst(global_position, Color(0.55, 1.0, 0.35), 14, 140.0, 0.45, 1.3)
	if GameState.has_evo("death_knell") and has_status("mark"):
		RunFx.explosion(p, global_position, float(GameState.up("death_knell", "radius", 90.0)),
			float(GameState.up("death_knell", "damage", 40.0)) * float(p.get("damage_mult")), Color(1.0, 0.55, 0.85), "blast", 220.0)
		Juice.float_text(global_position + Vector2(0, -40), "KNELL", Color(1.0, 0.6, 0.9), 15)
	if GameState.has_evo("fortune") and randf() < float(GameState.up("fortune", "ammo_chance", 0.0)):
		RunFx.spawn_ammo_pickup(get_parent(), global_position + Vector2(10, 10), RunFx.random_ammo_id())


## Dust Warden (boss variant): every few seconds it vents a Dust pulse around
## itself — red ring telegraph, then damage + plague exposure.
var _pulse_t: float = RadioDefs.WARDEN_PULSE_EVERY
var _pulse_wind: float = 0.0

func _tick_warden(delta: float) -> bool:
	if _pulse_wind > 0.0:
		_pulse_wind -= delta
		var k := 1.0 - _pulse_wind / RadioDefs.WARDEN_PULSE_WINDUP
		_show_telegraph(global_position + Vector2(0, 10), RadioDefs.WARDEN_PULSE_RADIUS, k)
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		if _pulse_wind <= 0.0:
			if _tele:
				_tele.visible = false
			RunFx.ring(get_parent(), global_position + Vector2(0, 10), RadioDefs.WARDEN_PULSE_RADIUS, Color(0.6, 0.9, 0.35), 0.5, 7.0)
			Juice.burst(global_position, Color(0.75, 0.6, 0.3), 30, RadioDefs.WARDEN_PULSE_RADIUS * 2.0, 0.6, 1.8)
			Juice.shake(0.35)
			var p := get_tree().get_first_node_in_group("player") as Node2D
			if p != null and p.global_position.distance_to(global_position) <= RadioDefs.WARDEN_PULSE_RADIUS and p.has_method("take_damage"):
				p.call("take_damage", RadioDefs.WARDEN_PULSE_DAMAGE * float(GameState.get_mode().get("enemy_damage", 1.0)), self)
				GameState.add_exposure(MedicineDefs.HIT_GAIN * 2.0)
		return true
	_pulse_t -= delta
	if _pulse_t <= 0.0 and _windup_left <= 0.0 and _lunge_left <= 0.0:
		_pulse_t = RadioDefs.WARDEN_PULSE_EVERY
		_pulse_wind = RadioDefs.WARDEN_PULSE_WINDUP
		_cancel_attack()
		if _anim.has_state("roar"):
			_anim.play("roar")
		return true
	return false
