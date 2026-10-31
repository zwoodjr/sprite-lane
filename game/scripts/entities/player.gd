extends CharacterBody2D

signal died
signal health_changed(current: float, maximum: float)
signal buffs_changed(buffs: Dictionary)
signal ammo_changed(ammo: int, mag: int, reloading: bool)
signal dashed
signal ability_used(name: String)
## Fired when this player actually loses HP to an enemy (pets listen — Noel enrages).
signal attacked(attacker: Node)
## Who landed the last hit (Run History's cause of death).
const PetGear = preload("res://scripts/data/pet_gear_defs.gd")
const CraftSets = preload("res://scripts/data/craft_defs.gd")
var last_hit_by: String = ""
## Fired when the player takes damage (HUD red edge flash).
signal hurt(amount: float)

const BulletScene := preload("res://scenes/entities/bullet.tscn")
const DroneScript := preload("res://scripts/entities/helm_drone.gd")
const OrbitScript := preload("res://scripts/entities/orbit_blades.gd")
const TONIC_TEX := "res://assets/sprites/fx/fx_iron_tonic.png"
const OVERLOAD_TEX := "res://assets/sprites/fx/fx_overload_arc.png"
## Pixel VFX per weapon (assets/sprites/fx/px): muzzle by projectile, smear by weapon
## (with the smear's base reach in world px; bigger reach scales it up).
const MUZZLE_PX := {"rocket": "mz_launcher", "slug": "mz_rifle", "tracer": "mz_ar", "pistol": "mz_pistol", "smg": "mz_smg"}
const SMEAR_PX := {"scrap_maul": ["sm_maul", 100.0], "chain_gauntlet": ["sm_chain", 175.0],
	"bayonet_knife": ["sm_bayonet", 90.0], "dual_dustblades": ["sm_blade", 90.0]}
## --- Movement feel (tuned for thumbs) ---
@export var base_speed: float = 205.0
@export var accel: float = 2400.0       ## px/s² toward target velocity
@export var decel: float = 3000.0       ## px/s² when the stick is released
@export var turn_boost: float = 1.8     ## extra accel when reversing direction
@export var base_max_hp: float = 100.0

## --- Dash ---
const DASH_SPEED := 760.0
const DASH_TIME := 0.16
const DASH_IFRAMES := 0.24
const DASH_COOLDOWN := 1.3
## Invulnerability after taking a hit (prevents shotgun-stacked damage).
const HURT_IFRAMES := 0.5
## Targeting: keep the current target unless another is 10% closer, and keep it
## until it leaves trigger_range × (1 + hysteresis).
const TARGET_HYSTERESIS := 0.10
## Rough enemy body radius added to melee reach (centre-to-centre distances).
const ENEMY_BODY_R := 16.0 ## × body_scale (which includes UnitAnim.BODY_K)
## Shove when hit (px/s impulse, decays fast).
const KNOCK_TAKEN := 160.0

var max_hp: float = 100.0
var hp: float = 100.0
var damage_mult: float = 1.0
var move_mult: float = 1.0
var firerate_mult: float = 1.0
var resist_mult: float = 1.0

var _fire_cd: float = 0.0
var _reload_left: float = 0.0
var _ammo: int = 24
var _ability_cd: float = 0.0
var _post_heal_left: float = 0.0
var _rush_left: float = 0.0
var _last_stitch_available: bool = false
var _oos_timer: float = 0.0
var _iframes: float = 0.0
var _dash_left: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _step_t: float = 0.0
var _flash_left: float = 0.0
var _attack_hold: float = 0.0 ## >0 shortly after an attack (slows, faces target)
var _last_aim: Vector2 = Vector2.RIGHT
var _facing_left: bool = false
var _char: Dictionary = {}
var _weapon: Dictionary = {}
var _armor: Dictionary = {}
var _buffs: Dictionary = {}  ## id -> {time_left, def}
var _ability: Dictionary = {}
var _target: Node2D = null
var _swing_dir: Vector2 = Vector2.RIGHT
var _swing_index: int = 0
var _drones: Array = []
var _guard_left: float = 0.0 ## melee: half damage after a swing lands

## --- Phase 4: run upgrades + abilities ---
var _shot_count: int = 0      ## Split Shot cadence
var _swing_count: int = 0     ## Split Shot (melee) / Quarry Slam cadence
var _bell_charge: float = 0.0 ## Bell Tower bonus (0..cap)
var _bell_ring: Line2D
var _tonic_ready: bool = false
var _tonic_cd: float = 0.0
var _tonic_fx: Sprite2D
var _tonic_frames: Array[Texture2D] = []
var _hidden_left: float = 0.0 ## Back Way Out
var _bayonet_cd: float = 0.0
var _supply_t: float = 0.0
var _supply_drops: int = 0
var _mine_dist: float = 0.0
var _trail_dist: float = 0.0
var _burn_cd: float = 0.0
var _orbit: Node2D
var _temp_drones: Array = []
var _overclock_left: float = 0.0
var _vial_coat_left: float = 0.0
var _backstab_text_cd: float = 0.0
## Ability: effect fires on the ability strip's hit frame (or this deadline).
var _ability_pending: String = ""
var _ability_hit_left: float = 0.0
var _ability_target: Node2D = null
## Ability movement (Pebble leap, Quill lunge, Nyx blade rush).
var _amove_left: float = 0.0
var _amove_dir: Vector2 = Vector2.RIGHT
var _amove_speed: float = 0.0
var _amove_kind: String = ""
var _amove_hit: Array = []
var _ram_hit: Array = []
var _rush_active: bool = false
## Rook's Braced window: runs on through the rush and a beat after it.
var _brace_left: float = 0.0
## Crafted sets: Dust Ward cooldown, Ashwalker regen clock.
var _ward_cd: float = 0.0
var _craft_regen_t: float = 0.0
var _ram_healed: float = 0.0

## --- Phase B: gear sets + named Legendaries ---
var _ability_charges: int = 1
var _knock_v: Vector2 = Vector2.ZERO
var _kills: int = 0             ## this run (Demolition Crew 6)
var _dash_hit: Array = []       ## Demolition Crew 4: enemies hit this dash
var _stand_fast_used: bool = false
var _stand_fast_left: float = 0.0
var _last_rites: bool = false
var _static_t: float = 0.0
var _volley_t: float = 0.0
var _grave_stacks: int = 0
var _swing_total: int = 0       ## Live Line cadence
var _hit_total: int = 0         ## Censer cadence
var _debt_target: Node2D = null ## Twin Debts
var _bell_cd: float = 0.0       ## Bellwether
var _mayday_left: float = 0.0
var _mayday_cd: float = 0.0
var _rubble_cd: float = 0.0     ## Last Shift
## Depth Update: plague exposure stage penalties (set by plague_system.gd, ≤ 0).
var exposure_move: float = 0.0
var exposure_rate: float = 0.0
## Depth E3 evolution timers.
var _shard_t: float = 0.0
var _quake_t: float = 0.0
var _storm_left: float = 0.0
var _storm_t: float = 0.0
var _ghost_left: float = 0.0
var _raid_t: float = 0.0
## Depth E5 quirks: Hot Barrel heat, and the current plague stage (Dust Eater).
var _heat: float = 0.0
var _overheat_left: float = 0.0
var exposure_stage: int = -1

@onready var body: Sprite2D = $Body
@onready var gun: Node2D = $Gun
@onready var label: Label = $NameLabel
@onready var camera: Camera2D = $Camera2D

## One 128 px hero frame at native density (1 texel = 1 screen px).
const HERO_FRAME_WORLD := 128.0 * UnitAnim.TEXEL
## Local y where the hero's feet stand (collision centre is the origin).
const FEET_Y := 32.0
## Melee reach grew with the native-size hero (her maul / blades reach further on screen).
const MELEE_K := 1.25
var _anim: UnitAnim = UnitAnim.new()
## <id>_weapon.json: per-state/frame weapon tip, hit_frames, melee|ranged.
var _wpn_art: Dictionary = {}
var _swing_hits_left: int = 0
var _swing_atk_fps: float = 12.0
var _swing_hit_frames: Array = []
var _dead: bool = false

var _flash_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	_apply_loadout()
	hp = max_hp
	health_changed.emit(hp, max_hp)
	_build_visuals()
	if camera.has_method("set_target"):
		camera.call("set_target", self)
	_sync_drones.call_deferred()
	_sync_upgrades.call_deferred()

func _apply_loadout() -> void:
	_char = GameState.get_character()
	_weapon = GameState.weapon
	_armor = GameState.armor
	_ability = GameState.hero_ability()
	_refresh_run_stats(true)
	_last_stitch_available = bool(_char.get("has_last_stitch", false))
	_ability_charges = int(_ability.get("charges", 1))
	## Cathedral Vestments (3): Last Rites — first death revives at half health.
	_last_rites = GameState.has_set("cathedral_vestments", 3)
	var prefix := str(_char.get("anim", "res://assets/sprites/characters/ash_rook/ash_rook"))
	_anim.setup(body, prefix, HERO_FRAME_WORLD, FEET_Y)
	_anim.base_material = UnitAnim.rim_material()
	body.material = _anim.base_material
	_wpn_art = UnitAnim.load_json(prefix + "_weapon.json")
	if not _anim.frame_event.is_connected(_on_anim_frame):
		_anim.frame_event.connect(_on_anim_frame)
		_anim.finished.connect(_on_anim_finished)
	label.text = str(_char.get("display_name", "Wanderer"))
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", _char.get("accent", Color(0.9, 0.8, 0.5)))
	if not GameState.loadout_changed.is_connected(_on_loadout_changed):
		GameState.loadout_changed.connect(_on_loadout_changed)

func _on_loadout_changed() -> void:
	## In-run upgrade pick or meta refresh mid-match.
	var old_max := max_hp
	_refresh_run_stats(false)
	if max_hp > old_max:
		hp = minf(max_hp, hp + (max_hp - old_max))
		health_changed.emit(hp, max_hp)
	ammo_changed.emit(_ammo, _mag_size(), _reload_left > 0.0)
	_sync_drones()
	_sync_upgrades()

func _refresh_run_stats(reset_ammo: bool) -> void:
	var rm: Dictionary = GameState.run_mods
	max_hp = base_max_hp \
		+ float(_char.get("max_hp_bonus", 0)) \
		+ float(_armor.get("flat_armor", 0)) * 0.5 \
		+ GameState.starting_hp_bonus() \
		+ float(rm.get("max_hp", 0.0)) \
		+ GameState.tonic_fx("max_hp")
	if GameState.quirk_fx("max_hp_mult") > 0.0:
		max_hp *= GameState.quirk_fx("max_hp_mult")
	## Depth E7 Dust Pact: Brittle Bones.
	max_hp *= GameState.pact_fx("max_hp")
	damage_mult = (1.0 + GameState.quirk_fx("damage")) * float(_char.get("damage_mult", 1.0)) \
		* (1.0 + GameState.starting_damage_bonus()) \
		* (1.0 + float(rm.get("damage", 0.0))) \
		* GameState.pact_fx("hero_damage")
	move_mult = float(_char.get("move_speed_mult", 1.0)) \
		* (1.0 + float(rm.get("move", 0.0))) \
		* (1.0 + GameState.move_speed_bonus() + GameState.tonic_fx("move") + GameState.quirk_fx("move"))
	firerate_mult = (1.0 + float(rm.get("firerate", 0.0))) * (1.0 + GameState.gear_stat("firerate"))
	if reset_ammo:
		_ammo = _mag_size()

func is_melee() -> bool:
	return _weapon.has("melee")

func _mag_size() -> int:
	if is_melee():
		return 0
	return int(_weapon.get("mag_size", 24)) + int(GameState.run_mods.get("mag", 0.0))

func _build_visuals() -> void:
	## (Ground shadow is baked into the hero strips.)
	## Muzzle flash: per-weapon pixel strip played at the weapon tip (Juice.fx).
	UnitAnim.add_contact_shadow(self, 58.0, FEET_Y, 0.55)
	_add_ground_ring()
	_add_ammo_arc()
	gun.z_index = 2


var _ammo_arc: Node2D
var _ammo_arc_a: float = 0.0


## Ammo pips on a short arc beside the hero; while reloading the arc fills
## amber. Replaces the "RELOADING %" HUD text (audit: read it where you look).
func _add_ammo_arc() -> void:
	_ammo_arc = Node2D.new()
	_ammo_arc.name = "AmmoArc"
	_ammo_arc.z_index = 6
	_ammo_arc.position = Vector2(0.0, FEET_Y - 34.0)
	_ammo_arc.modulate.a = 0.0
	_ammo_arc.draw.connect(_draw_ammo_arc)
	add_child(_ammo_arc)


func _tick_ammo_arc(delta: float) -> void:
	if _ammo_arc == null or is_melee() or GameState.quirk_fx("no_reload") > 0.0:
		if _ammo_arc:
			_ammo_arc.visible = false
		return
	var want := 1.0 if (_reload_left > 0.0 or _ammo < _mag_size()) else 0.0
	_ammo_arc_a = move_toward(_ammo_arc_a, want, delta * (6.0 if want > 0.0 else 1.5))
	_ammo_arc.visible = _ammo_arc_a > 0.01
	_ammo_arc.modulate.a = _ammo_arc_a
	if _ammo_arc.visible:
		_ammo_arc.queue_redraw()


func _draw_ammo_arc() -> void:
	## Arc on the side away from the facing direction, 100 degrees tall.
	var centre := 0.0 if _facing_left else PI
	var r := 30.0
	## Fills bottom -> top on either side.
	var a0 := centre + deg_to_rad(50.0) * (1.0 if _facing_left else -1.0)
	var span := deg_to_rad(100.0) * (-1.0 if _facing_left else 1.0)
	var mag := maxi(1, _mag_size())
	var shade := Color(0.04, 0.03, 0.02, 0.7)
	if _reload_left > 0.0:
		var t := get_reload_ratio()
		_arc_seg(a0, a0 + span, r, 4.0, shade)
		_arc_seg(a0, a0 + span * t, r, 2.5, Color(1.0, 0.72, 0.25))
		return
	if mag <= 16:
		var gap := 0.18
		for i in mag:
			var s0 := a0 + span * (float(i) + gap * 0.5) / float(mag)
			var s1 := a0 + span * (float(i) + 1.0 - gap * 0.5) / float(mag)
			var on := i < _ammo
			_arc_seg(s0, s1, r, 4.0, shade)
			if on:
				_arc_seg(s0, s1, r, 2.5, Color(1.0, 0.93, 0.7) if _ammo > mag / 4 else Color(1.0, 0.45, 0.35))
	else:
		var f := float(_ammo) / float(mag)
		_arc_seg(a0, a0 + span, r, 4.0, shade)
		_arc_seg(a0, a0 + span * f, r, 2.5, Color(1.0, 0.93, 0.7) if f > 0.25 else Color(1.0, 0.45, 0.35))


func _arc_seg(a: float, b: float, r: float, w: float, c: Color) -> void:
	if absf(b - a) < 0.001:
		return
	_ammo_arc.draw_arc(Vector2.ZERO, r, minf(a, b), maxf(a, b), 10, c, w)


## Team-colour ground ring under the hero (audit value pass): the hero is
## findable in any crowd at a glance. Drawn under the body, over the ground.
func _add_ground_ring() -> void:
	var ring := Node2D.new()
	ring.name = "HeroRing"
	ring.z_index = -1
	ring.position = Vector2(2.0, FEET_Y - 1.0)
	var col: Color = _char.get("accent", Color(1.0, 0.82, 0.4)) if _char else Color(1.0, 0.82, 0.4)
	col = col.lerp(Color(1.0, 0.86, 0.5), 0.35)
	ring.draw.connect(func() -> void:
		var pts := PackedVector2Array()
		for i in 33:
			var a := TAU * float(i) / 32.0
			pts.append(Vector2(cos(a) * 24.0, sin(a) * 9.0))
		ring.draw_polyline(pts, Color(0, 0, 0, 0.35), 3.0)
		ring.draw_polyline(pts, Color(col, 0.75), 1.5))
	add_child(ring)
	move_child(ring, 1)

## Drones: Helm = weapon base + Squadron + Scrap Drone ranks (max 4).
## Everyone else: Scrap Drone ranks, with the card's own drone stats.
func _sync_drones() -> void:
	if not is_inside_tree() or _dead:
		return
	var base := int(_weapon.get("drone_count", 0))
	var wdef: Dictionary = _weapon
	var want := 0
	if base > 0:
		want = clampi(base + GameState.run_rank("squadron") + GameState.run_rank("scrap_drone") + int(GameState.up("hive", "drones", 0)), 0, int(_weapon.get("drone_max", 4)))
	else:
		want = int(GameState.up("scrap_drone", "drones", 0)) + int(GameState.up("hive", "drones", 0))
		wdef = UpgradeDefs.get_def("scrap_drone").get("drone", {})
	if want <= 0:
		return
	while _drones.size() < want:
		var d := Node2D.new()
		d.set_script(DroneScript)
		if base <= 0:
			d.set("tint", Color(1.0, 0.82, 0.55))
			d.set("scavenge", true)
		get_parent().add_child(d)
		d.call("setup", self, _drones.size(), wdef)
		_drones.append(d)
	for d in _drones:
		if is_instance_valid(d):
			d.call("set_slot", _drones.find(d), want)

func get_drones() -> Array:
	var out: Array = _drones.duplicate()
	for d in _temp_drones:
		if is_instance_valid(d):
			out.append(d)
	return out

## Wingman ranks × DRONE-call overclock.
func drone_rate_mult() -> float:
	var m := 1.0 + float(GameState.up("wingman", "firerate", 0.0)) + float(GameState.up("hive", "rate", 0.0))
	if GameState.has_set("flight_crew_gear", 2):
		m *= float(GearDefs.SURVIVOR_SETS["flight_crew_gear"]["drone_rate"])
	if _overclock_left > 0.0:
		m *= float(_ability.get("overclock", 2.0))
	return m

## Orbiting Blades node, Iron Tonic shield, Bell Tower ring.
func _sync_upgrades() -> void:
	if not is_inside_tree() or _dead:
		return
	if GameState.run_rank("orbit_blades") > 0 and (_orbit == null or not is_instance_valid(_orbit)):
		_orbit = Node2D.new()
		_orbit.set_script(OrbitScript)
		_orbit.set("player", self)
		get_parent().add_child(_orbit)
	if GameState.run_rank("iron_tonic") > 0 and _tonic_fx == null:
		_tonic_frames = RunFx.frames(TONIC_TEX, 2)
		_tonic_fx = Sprite2D.new()
		if not _tonic_frames.is_empty():
			_tonic_fx.texture = _tonic_frames[0]
			_tonic_fx.scale = Vector2.ONE * (60.0 / float(_tonic_frames[0].get_width()))
		_tonic_fx.position = Vector2(0, -6)
		_tonic_fx.z_index = 3
		add_child(_tonic_fx)
		_tonic_ready = true
	if GameState.run_rank("bell_tower") > 0 and _bell_ring == null:
		_bell_ring = Line2D.new()
		var pts := PackedVector2Array()
		for i in range(25):
			var a := TAU * i / 24.0
			pts.append(Vector2(cos(a) * 22.0, sin(a) * 9.0))
		_bell_ring.points = pts
		_bell_ring.width = 2.5
		_bell_ring.default_color = Color(0.6, 1.0, 0.45, 0.0)
		_bell_ring.position = Vector2(0, FEET_Y)
		_bell_ring.z_index = -1
		add_child(_bell_ring)

## =============================================================================
func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_tick_buffs(delta)
	_update_movement(delta)
	_update_combat(delta)
	_update_actions()
	_update_regen(delta)
	_update_run_upgrades(delta)
	_update_visuals(delta)

func _tick_timers(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_ability_cd = maxf(0.0, _ability_cd - delta)
	_post_heal_left = maxf(0.0, _post_heal_left - delta)
	_rush_left = maxf(0.0, _rush_left - delta)
	_brace_left = maxf(0.0, _brace_left - delta)
	_ward_cd = maxf(0.0, _ward_cd - delta)
	## Ashwalker's Shroud (2): slow regen (Greed still shrinks it).
	if GameState.has_set("ashwalker", 2) and hp > 0.0 and hp < max_hp:
		_craft_regen_t += delta
		if _craft_regen_t >= float(CraftSets.SETS["ashwalker"]["regen_every"]):
			_craft_regen_t = 0.0
			heal(float(CraftSets.SETS["ashwalker"]["regen"]))
	_iframes = maxf(0.0, _iframes - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_flash_left = maxf(0.0, _flash_left - delta)
	_attack_hold = maxf(0.0, _attack_hold - delta)
	_guard_left = maxf(0.0, _guard_left - delta)
	_hidden_left = maxf(0.0, _hidden_left - delta)
	_overclock_left = maxf(0.0, _overclock_left - delta)
	_vial_coat_left = maxf(0.0, _vial_coat_left - delta)
	_burn_cd = maxf(0.0, _burn_cd - delta)
	_backstab_text_cd = maxf(0.0, _backstab_text_cd - delta)
	_stand_fast_left = maxf(0.0, _stand_fast_left - delta)
	_mayday_left = maxf(0.0, _mayday_left - delta)
	_mayday_cd = maxf(0.0, _mayday_cd - delta)
	_bell_cd = maxf(0.0, _bell_cd - delta)
	_rubble_cd = maxf(0.0, _rubble_cd - delta)
	_knock_v = _knock_v.move_toward(Vector2.ZERO, 900.0 * delta)
	if _ability_pending != "":
		_ability_hit_left -= delta
		if _ability_hit_left <= 0.0:
			_fire_ability()
	if _rush_active and _rush_left <= 0.0:
		_rush_active = false
		_on_rush_end()
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			_ammo = _mag_size()
			ammo_changed.emit(_ammo, _mag_size(), false)

func is_attacking() -> bool:
	return _attack_hold > 0.0

func _current_speed() -> float:
	var s := base_speed * move_mult * _buff_move() * (1.0 + exposure_move) * GameState.carry_speed_mult()
	if _rush_left > 0.0:
		s *= float(_ability.get("speed_mult", 1.3))
	## Slightly slower while attacking so dodging is a choice, not automatic.
	if _attack_hold > 0.0:
		s *= 0.9
	return s

func _update_movement(delta: float) -> void:
	var dir := TouchInput.get_move()
	if _amove_left > 0.0:
		_tick_ability_move(delta)
		return
	if _dash_left > 0.0:
		_dash_left -= delta
		var before := global_position
		velocity = _dash_dir * DASH_SPEED
		move_and_slide()
		_firewalk_step(global_position.distance_to(before))
		_demolition_dash()
		if _dash_left <= 0.0 and is_melee():
			## Dash-cancel into swing: come out of a dash ready to hit.
			_fire_cd = 0.0
		if int(_dash_left * 60.0) % 2 == 0:
			_spawn_afterimage()
		return
	var target := dir * _current_speed()
	var rate := accel if dir.length() > 0.01 else decel
	## Reversing? Snap harder so it doesn't feel like ice.
	if dir.length() > 0.01 and velocity.length() > 10.0 and velocity.normalized().dot(dir.normalized()) < 0.2:
		rate *= turn_boost
	velocity = velocity.move_toward(target, rate * delta)
	velocity += _knock_v
	var before_walk := global_position
	move_and_slide()
	velocity -= _knock_v
	if GameState.has_evo("hellfire_stride"):
		_firewalk_step(global_position.distance_to(before_walk))

func _update_actions() -> void:
	if Input.is_action_just_pressed("ability") or TouchInput.consume_ability():
		_try_ability()
	if TouchInput.consume_dash():
		_try_dash()

func _update_regen(delta: float) -> void:
	if velocity.length() < 10.0 and _attack_hold <= 0.0:
		_oos_timer += delta
	else:
		_oos_timer = 0.0
	## Bloodthirst: no regeneration at all (kills heal instead).
	if GameState.quirk_fx("no_regen") > 0.0:
		return
	if _oos_timer > 1.5 and hp < max_hp:
		hp = minf(max_hp, hp + float(_armor.get("regen_oos", 0.0)) * delta * _greed_heal())
		health_changed.emit(hp, max_hp)
	## Gear regen (Vials etc.) and Mender's Draught tick always.
	var rg := GameState.gear_stat("regen") + GameState.tonic_fx("regen")
	if rg > 0.0 and hp < max_hp and hp > 0.0:
		hp = minf(max_hp, hp + rg * delta * _greed_heal())
		health_changed.emit(hp, max_hp)

func _facing_dir() -> Vector2:
	return Vector2.LEFT if _facing_left else Vector2.RIGHT

## Animation runs in _process so the death strip still plays after physics stops.
func _process(delta: float) -> void:
	_anim.set_motion(velocity)
	_anim.tick(delta)
	_tick_ammo_arc(delta)
	## A swing interrupted (hit / dash) before its hit frames still lands.
	if _swing_hits_left > 0 and not (_anim.state == "windup" or _anim.state == "attack"):
		while _swing_hits_left > 0:
			_melee_impact()

func _update_visuals(delta: float) -> void:
	var moving := velocity.length() > 30.0
	## Face the target while attacking, otherwise face where you run.
	if _attack_hold > 0.0 and absf(_last_aim.x) > 0.05:
		_facing_left = _last_aim.x < 0.0
	elif absf(velocity.x) > 20.0:
		_facing_left = velocity.x < 0.0
	_anim.set_facing(_facing_left)
	## Real walk cycle; its rate follows actual speed (no procedural bob).
	if moving:
		_anim.set_locomotion("walk", clampf(velocity.length() / base_speed, 0.55, 1.6))
	else:
		_anim.set_locomotion("idle")
	if moving:
		_step_t += delta
		if _step_t > 0.26:
			_step_t = 0.0
			Juice.dust_puff(global_position + Vector2(0, 18), 3)
	## Blink during i-frames
	if _hidden_left > 0.0:
		body.modulate.a = 0.3
	elif _iframes > 0.0 and _dash_left <= 0.0:
		body.modulate.a = 0.45 if int(_iframes * 30.0) % 2 == 0 else 1.0
	else:
		body.modulate.a = 1.0

## =============================================================================
## Buffs

func _buff_move() -> float:
	return 1.35 if _buffs.has("speed") else 1.0

func _buff_damage() -> float:
	return 1.45 if _buffs.has("damage") else 1.0

func _buff_firerate() -> float:
	var f := firerate_mult
	if _post_heal_left > 0.0:
		f *= float(_char.get("post_heal_firerate_mult", 1.0))
	if _buffs.has("rapid"):
		f *= 1.75
	if GameState.quirk_fx("rage") > 0.0 and hp < max_hp * GameState.quirk_fx("below"):
		f *= 1.0 + GameState.quirk_fx("rage")
	return f * (1.0 + exposure_rate)

func _tick_buffs(delta: float) -> void:
	var changed := false
	for id in _buffs.keys():
		if not (_buffs[id] is Dictionary):
			_buffs[id] = {"time_left": float(_buffs[id]) if (_buffs[id] is float or _buffs[id] is int) else 0.0, "def": {"name": str(id).to_upper()}}
		_buffs[id]["time_left"] = float(_buffs[id].get("time_left", 0.0)) - delta
		if float(_buffs[id]["time_left"]) <= 0.0:
			_buffs.erase(id)
			changed = true
	resist_mult = 0.55 if _buffs.has("shield") else 1.0
	if changed:
		buffs_changed.emit(_buffs)

func apply_powerup(def: Dictionary) -> void:
	var id := str(def.get("id", ""))
	Juice.sfx("pick_ammo" if def.has("ammo") or id.ends_with("ammo") else "pick_rare")
	Juice.haptic(Juice.HAPTIC_TICK)
	Juice.burst(global_position, def.get("color", Color.WHITE), 16, 180.0, 0.5)
	Juice.float_text(global_position + Vector2(0, -30), str(def.get("name", "Boost")), def.get("color", Color.WHITE), 20)
	if id == "heal" or def.has("instant_heal"):
		var amt := float(def.get("instant_heal", 35.0)) * _greed_heal()
		hp = minf(max_hp, hp + amt)
		health_changed.emit(hp, max_hp)
	if def.has("ammo"):
		GameState.run_ammo_seen[str(def["ammo"])] = true
	var dur := float(def.get("duration", 10.0))
	if dur > 0.2:
		## Special ammo lives in the "ammo" buff slot (one type at a time).
		_buffs[id] = {"time_left": dur, "def": def}
	buffs_changed.emit(_buffs)
	if id == "magnet":
		GameState.add_scrap(randi_range(4, 8))

func get_active_buffs() -> Dictionary:
	return _buffs

## Current special ammo id ("" = standard rounds).
func special_ammo() -> String:
	if not _buffs.has("ammo"):
		return ""
	return str((_buffs["ammo"]["def"] as Dictionary).get("ammo", ""))

## =============================================================================
## Dash

func _try_dash() -> void:
	if _dash_cd > 0.0 or _dash_left > 0.0:
		return
	var dir := TouchInput.get_move()
	if dir.length() < 0.1:
		dir = velocity.normalized() if velocity.length() > 20.0 else _facing_dir()
	_dash_dir = dir.normalized()
	_dash_left = DASH_TIME
	_dash_cd = DASH_COOLDOWN * GameState.dash_cooldown_mult()
	_iframes = maxf(_iframes, DASH_IFRAMES)
	Juice.sfx("dash")
	Juice.dust_puff(global_position + Vector2(0, 16), 8)
	if absf(_dash_dir.x) > 0.1:
		_facing_left = _dash_dir.x < 0.0
		_anim.set_facing(_facing_left)
	_anim.play_over("dash", DASH_TIME + 0.04)
	## Second Wind / Back Way Out / Firewalk.
	var sw := float(GameState.up("second_wind", "heal", 0.0))
	if sw > 0.0:
		heal(sw)
		Juice.float_text(global_position + Vector2(0, -34), "+%d" % int(sw), UiTheme.TEAL, 14)
	var inv := float(GameState.up("back_way_out", "time", 0.0))
	if inv > 0.0:
		_hidden_left = inv
		Juice.burst(global_position, Color(0.4, 0.5, 0.9, 0.7), 14, 120.0, 0.4, 1.4)
	_trail_dist = 999.0
	_firewalk_step(0.0)
	_dash_hit.clear()
	if GameState.has_evo("phoenix"):
		heal(float(GameState.up("phoenix", "heal", 6.0)))
		RunFx.explosion(self, global_position, float(GameState.up("phoenix", "radius", 110.0)),
			float(GameState.up("phoenix", "damage", 30.0)) * damage_mult, Color(1.0, 0.55, 0.2), "blast", 280.0)
	if GameState.has_evo("ghost_debt"):
		_ghost_left = float(GameState.up("ghost_debt", "time", 2.0))
	_gear_on_dash()
	dashed.emit()

func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = body.texture
	ghost.hframes = body.hframes
	ghost.frame = body.frame
	ghost.offset = body.offset
	ghost.flip_h = body.flip_h
	ghost.scale = body.scale
	ghost.global_position = body.global_position
	ghost.modulate = Color(0.6, 0.95, 0.85, 0.5)
	ghost.z_index = -1
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ghost.queue_free)

func get_dash_cooldown_ratio() -> float:
	var cd := DASH_COOLDOWN * GameState.dash_cooldown_mult()
	return clampf(_dash_cd / cd, 0.0, 1.0) if cd > 0.0 else 0.0

## =============================================================================
## Ability (data-driven from character_defs "ability")

func has_ability() -> bool:
	return not _ability.is_empty()

func get_ability_short_name() -> String:
	return str(_ability.get("short", "ABILITY"))

func _ability_cooldown() -> float:
	var cd := float(_ability.get("cooldown", 12.0))
	var reduce := float(GameState.run_mods.get("ability_cd", 0.0))
	return cd * maxf(0.4, 1.0 - reduce)

func get_ability_cooldown_ratio() -> float:
	var cd := _ability_cooldown()
	return clampf(_ability_cd / cd, 0.0, 1.0) if cd > 0.0 else 0.0

func ability_ready() -> bool:
	return has_ability() and _ability_cd <= 0.0 and not _dead

func _try_ability() -> void:
	if not has_ability() or _dead:
		return
	if _ability_cd > 0.0 or _ability_pending != "" or _amove_left > 0.0:
		Juice.sfx("empty", -6.0)
		return
	var id := str(_ability.get("id", ""))
	## Cast: instant part (movement / buffs). False = nothing to use it on.
	if not _ability_cast(id):
		Juice.sfx("empty", -6.0)
		return
	## Foreman's Kit (3): Second Charge — Rush can be used twice per cooldown.
	_ability_charges -= 1
	if _ability_charges > 0:
		_ability_cd = 0.5
	else:
		_ability_cd = _ability_cooldown()
		_ability_charges = int(_ability.get("charges", 1))
	_anim.play("ability")
	## The effect lands on the ability strip's hit frame (deadline fallback).
	_ability_pending = id
	var hf := int(_art_hit_frames("ability", [3])[0])
	_ability_hit_left = float(hf) / float(UnitAnim.DEFAULT_FPS.get("ability", 12.0)) + 0.03
	Juice.sfx("ability")
	ability_used.emit(str(_ability.get("name", "Ability")))
	GameState.quest_event("ability")

## Closest on-screen enemy within r of the hero (abilities).
func _ability_pick(r: float) -> Node2D:
	var best: Node2D = null
	var bd := r
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var d := global_position.distance_to((n as Node2D).global_position)
		if d < bd and is_on_screen(self, (n as Node2D).global_position):
			bd = d
			best = n
	return best

func _start_ability_move(dir: Vector2, speed: float, time: float, kind: String) -> void:
	_amove_dir = dir.normalized() if dir.length() > 0.01 else _facing_dir()
	_amove_speed = speed
	_amove_left = time
	_amove_kind = kind
	_amove_hit.clear()
	_iframes = maxf(_iframes, time + 0.12)
	if absf(_amove_dir.x) > 0.1:
		_facing_left = _amove_dir.x < 0.0
		_anim.set_facing(_facing_left)
	_last_aim = _amove_dir

func _ability_cast(id: String) -> bool:
	var a := _ability
	match id:
		"rattle_rush":
			_rush_left = float(a.get("duration", 3.0))
			_rush_active = true
			_brace_left = _rush_left + float(a.get("brace_after", 0.0))
			_ram_healed = 0.0
			_ram_hit.clear()
			_iframes = maxf(_iframes, 0.3)
			for crate in get_tree().get_nodes_in_group("breakables"):
				if crate is Node2D and global_position.distance_to((crate as Node2D).global_position) < 900.0:
					if crate.has_method("ping"):
						crate.call("ping")
		"maul_slam":
			var t := _ability_pick(float(a.get("lunge_range", 220.0)))
			var dir := (t.global_position - global_position) if t else (TouchInput.get_move() if TouchInput.get_move().length() > 0.1 else _facing_dir())
			var dist := dir.length() if t else 90.0
			var time := clampf((dist - 40.0) / float(a.get("lunge_speed", 560.0)), 0.06, float(a.get("lunge_time", 0.2)))
			_start_ability_move(dir, float(a.get("lunge_speed", 560.0)), time, "leap")
		"dissect":
			var t2 := _ability_pick(float(a.get("range", 280.0)))
			if t2 == null:
				return false
			_ability_target = t2
			var d2 := t2.global_position - global_position
			var time2 := maxf(0.0, d2.length() - float(a.get("stop_dist", 30.0))) / float(a.get("lunge_speed", 760.0))
			_start_ability_move(d2, float(a.get("lunge_speed", 760.0)), clampf(time2, 0.02, 0.4), "lunge")
		"blade_rush":
			var t3 := _ability_pick(float(a.get("aim_range", 300.0)))
			var mv := TouchInput.get_move()
			var dir3 := (t3.global_position - global_position) if t3 else (mv if mv.length() > 0.1 else _facing_dir())
			_start_ability_move(dir3, float(a.get("dash_speed", 920.0)), float(a.get("dash_time", 0.26)), "blade")
			Juice.sfx("dash")
			if a.has("hide"):
				_hidden_left = maxf(_hidden_left, float(a["hide"]))
		"rig_assist":
			_rush_left = float(a.get("duration", 4.0))
		_:
			pass
	return true

func _on_anim_ability_frame(frame: int) -> void:
	if _ability_pending != "" and frame in _art_hit_frames("ability", [3]):
		_fire_ability()

## The ability's payoff, on its hit frame.
func _fire_ability() -> void:
	var id := _ability_pending
	_ability_pending = ""
	if _dead:
		return
	var a := _ability
	match id:
		"field_draught":
			var amt := float(a.get("heal", 28.0))
			heal(amt)
			## Smoke Censer (E5 ability B): a healing smoke where she stands.
			if a.has("puddle_radius"):
				RunFx.ground(get_parent(), self, global_position + Vector2(0, FEET_Y - 4), "heal",
					float(a["puddle_radius"]), float(a.get("puddle_time", 5.0)), float(a.get("puddle_hps", 7.0)))
			## Cinder's draught also burns the plague out of the blood.
			if GameState.exposure > 0.0:
				GameState.cleanse_exposure(MedicineDefs.CINDER_HEAL_CLEANSE)
			_post_heal_left = float(_char.get("post_heal_duration", 0.0))
			Juice.float_text(global_position + Vector2(0, -34), "+%d" % int(amt), UiTheme.TEAL, 22)
			Juice.fx("fx_heal", global_position + Vector2(0, FEET_Y - 2), {"follow": self})
			if GameState.run_rank("sanctuary") > 0:
				RunFx.ground(get_parent(), self, global_position + Vector2(0, FEET_Y - 4), "heal",
					float(GameState.up("sanctuary", "radius", 72.0)), float(GameState.up("sanctuary", "time", 4.0)),
					float(GameState.up("sanctuary", "hps", 6.0)))
				if GameState.has_evo("cathedral_fire"):
					RunFx.ground(get_parent(), self, global_position + Vector2(0, FEET_Y - 4), "burn",
						float(GameState.up("sanctuary", "radius", 72.0)), float(GameState.up("sanctuary", "time", 4.0)),
						float(GameState.up("cathedral_fire", "dps", 18.0)))
		"rattle_rush":
			Juice.dust_puff(global_position + Vector2(0, FEET_Y - 6), 12)
			Juice.fx("ex_tiny", global_position + Vector2(0, FEET_Y - 10))
			Juice.shake(0.12)
		"vial_shot":
			var t := _ability_pick(get_trigger_range() * 1.1)
			var aim := (t.global_position - global_position).normalized() if t else _facing_dir()
			_last_aim = aim
			_face_aim()
			var roll := _roll_damage(float(a.get("vial_mult", 1.8)))
			var b := _spawn_bullet(global_position + _muzzle_offset(), aim, float(roll[0]), bool(roll[1]), float(a.get("vial_speed", 640.0)))
			b.set("style", "vial")
			b.set("vial", true)
			b.set("ammo", "")
			b.set("pierce_left", 0)
			b.set("bounces_left", 0)
			_vial_coat_left = float(a.get("coat_time", 4.0))
			Juice.sfx("fire_vesper", -5.0)
		"maul_slam":
			var centre := global_position + _facing_dir() * 18.0 + Vector2(0, 8)
			var roll2 := _roll_damage(float(a.get("damage_mult", 2.2)))
			RunFx.explosion(self, centre, float(a.get("radius", 120.0)), float(roll2[0]), Color(1.0, 0.75, 0.4), "ability",
				float(a.get("knockback", 480.0)), float(a.get("stun", 0.8)), "slam")
			Juice.shake(float(a.get("shake", 0.4)))
			Juice.hitstop(0.07)
			Juice.sfx("ab_slam")
		"overload":
			_overload()
		"dissect":
			var tg := _ability_target
			_ability_target = null
			if tg != null and is_instance_valid(tg) and tg.has_method("apply_status"):
				tg.call("apply_status", "mark", float(a.get("mark_time", 5.0)), float(a.get("mark_mult", 1.5)))
				var roll3 := _roll_damage(float(a.get("damage_mult", 2.5)))
				var d3 := (tg.global_position - global_position).normalized()
				_spawn_smear("arc", {"px": "sm_bayonet", "radius": 60.0}, d3)
				Juice.fx("fx_mark", tg.global_position + Vector2(0, -10), {"follow": tg})
				hit_enemy(tg, float(roll3[0]), d3, 220.0, true, "ability")
				Juice.float_text(tg.global_position + Vector2(0, -40), "MARKED", UpgradeDefs.MARK_TINT, 14)
				Juice.sfx("impact_quill", 2.0)
				Juice.hitstop(0.05)
		"blade_rush":
			Juice.shake(0.1)
			Juice.sfx("impact_nyx", 1.0)
		"rig_assist":
			_overclock_left = float(a.get("overclock_time", 4.0))
			for i in range(int(a.get("temp_drones", 1))):
				var d := Node2D.new()
				d.set_script(DroneScript)
				d.set("temp_left", float(a.get("temp_time", 8.0)))
				get_parent().add_child(d)
				d.call("setup", self, 4 + i, _weapon)
				_temp_drones.append(d)
			for d in get_drones():
				if is_instance_valid(d):
					Juice.fx("fx_drone_call", (d as Node2D).global_position, {"follow": d})
			Juice.float_text(global_position + Vector2(0, -44), "OVERCLOCK", Color(0.5, 1.0, 0.85), 16)

## Juno OVERLOAD: burst around her, then an arc that jumps enemy to enemy.
func _overload() -> void:
	var a := _ability
	var parent := get_parent()
	var dmg_mult := float(a.get("damage_mult", 1.6))
	var stun := float(a.get("stun", 1.3))
	Juice.fx("ex_shock", global_position + Vector2(0, -6), {"follow": self})
	RunFx.ring(parent, global_position + Vector2(0, 8), float(a.get("burst_radius", 80.0)), Color(0.5, 0.8, 1.0), 0.3)
	var hit: Array = []
	for e in RunFx.enemies_in(get_tree(), global_position, float(a.get("burst_radius", 80.0))):
		e.call("apply_status", "stun", stun)
		var roll := _roll_damage(dmg_mult)
		hit_enemy(e, float(roll[0]), ((e as Node2D).global_position - global_position).normalized(), 200.0, bool(roll[1]), "ability")
		hit.append(e)
	var links := int(a.get("chain", 4)) + int(GameState.up("live_wire", "extra", 0))
	var prev := global_position + Vector2(0, -8)
	var cur := RunFx.nearest_enemy(get_tree(), global_position, float(a.get("range", 230.0)), hit)
	var n := 0
	while cur != null and n < links:
		RunFx.zap(parent, prev, cur.global_position, Color(0.55, 0.85, 1.0), 0.28, 3.5)
		Juice.fx_impact(cur.global_position + Vector2(0, -8), "shock")
		cur.call("apply_status", "stun", stun)
		var roll2 := _roll_damage(dmg_mult)
		hit_enemy(cur, float(roll2[0]), (cur.global_position - prev).normalized(), 120.0, bool(roll2[1]), "ability")
		hit.append(cur)
		prev = cur.global_position
		n += 1
		cur = RunFx.nearest_enemy(get_tree(), prev, float(a.get("jump", 170.0)), hit)
	Juice.shake(0.15)
	Juice.sfx("ab_overload")
	if GameState.has_evo("thunderhead"):
		_storm_left = float(GameState.up("thunderhead", "time", 5.0))

## Movement abilities: leap (Pebble), lunge (Quill), blade dash (Nyx).
func _tick_ability_move(delta: float) -> void:
	_amove_left -= delta
	velocity = _amove_dir * _amove_speed
	move_and_slide()
	if int(_amove_left * 60.0) % 2 == 0:
		_spawn_afterimage()
	if _amove_kind == "blade":
		var a := _ability
		for e in RunFx.enemies_in(get_tree(), global_position, float(a.get("hit_radius", 48.0))):
			if e in _amove_hit:
				continue
			_amove_hit.append(e)
			var roll := _roll_damage(float(a.get("damage_mult", 1.8)))
			_spawn_smear("arc", {"px": "sm_blade", "radius": 56.0}, _amove_dir)
			hit_enemy(e, float(roll[0]), _amove_dir.orthogonal() * (1.0 if randf() < 0.5 else -1.0), float(a.get("knockback", 260.0)), bool(roll[1]), "ability")
			Juice.hitstop(0.02)
	elif _amove_kind == "lunge" and _ability_target != null and is_instance_valid(_ability_target):
		if global_position.distance_to(_ability_target.global_position) <= float(_ability.get("stop_dist", 30.0)):
			_amove_left = 0.0
	if _amove_left <= 0.0:
		_amove_left = 0.0
		velocity *= 0.2
		if is_melee():
			_fire_cd = 0.0

## Rook: ram through enemies while rushing; Aftershock when it ends.
func _update_rush_ram() -> void:
	if not _rush_active or str(_ability.get("id", "")) != "rattle_rush":
		return
	var a := _ability
	for e in RunFx.enemies_in(get_tree(), global_position, float(a.get("ram_radius", 36.0))):
		if e in _ram_hit:
			continue
		_ram_hit.append(e)
		var dir := ((e as Node2D).global_position - global_position).normalized()
		hit_enemy(e, float(a.get("ram_damage", 22.0)) * damage_mult, dir, float(a.get("ram_knock", 380.0)), false, "ability")
		if is_instance_valid(e) and a.has("ram_stun") and e.has_method("apply_status") and str(e.get("role")) != "boss":
			e.call("apply_status", "stun", float(a["ram_stun"]))
		if a.has("ram_heal") and _ram_healed < float(a.get("ram_heal_cap", 15.0)):
			var h := minf(float(a["ram_heal"]), float(a.get("ram_heal_cap", 15.0)) - _ram_healed)
			_ram_healed += h
			heal(h)
		Juice.shake(0.08)
	## Demolition: Rook smashes crates and wrecks he charges through.
	var smashed := RunFx.damage_breakables(get_tree(), global_position, float(a.get("ram_radius", 36.0)),
		maxf(float(a.get("ram_damage", 22.0)) * damage_mult, 999.0), _ram_hit)
	if not smashed.is_empty():
		_ram_hit.append_array(smashed)
		Juice.shake(0.08)

func _on_rush_end() -> void:
	## Short Charge (E5 ability B): the charge ends in a ground slam.
	if str(_ability.get("id", "")) == "rattle_rush" and _ability.has("end_slam_radius"):
		RunFx.explosion(self, global_position + Vector2(0, 10), float(_ability["end_slam_radius"]),
			float(_ability.get("end_slam_damage", 40.0)) * damage_mult, Color(1.0, 0.75, 0.4), "ability", 420.0, 0.6, "slam")
		Juice.shake(0.3)
		Juice.sfx("brute_slam")
	if str(_ability.get("id", "")) != "rattle_rush" or GameState.run_rank("aftershock") <= 0:
		return
	var dmg := float(GameState.up("aftershock", "damage", 45.0)) * damage_mult * float(GameState.up("earthquake", "aftershock_mult", 1.0))
	RunFx.explosion(self, global_position, float(GameState.up("aftershock", "radius", 120.0)), dmg, Color(1.0, 0.55, 0.2), "ability", 360.0)
	Juice.shake(0.35)
	Juice.hitstop(0.05)

## Vesper's vial lands: a poison cloud that lingers.
func vial_burst(pos: Vector2) -> void:
	var a := _ability
	var r := float(a.get("cloud_radius", 85.0))
	for e in RunFx.enemies_in(get_tree(), pos, r):
		e.call("apply_status", "poison", float(a.get("cloud_time", 3.5)), float(a.get("cloud_dps", 12.0)))
		if a.has("cloud_slow"):
			e.call("apply_status", "slow", float(a.get("cloud_time", 3.5)), float(a["cloud_slow"]))
	RunFx.ground(get_parent(), self, pos, "poison", r, float(a.get("cloud_time", 3.5)), float(a.get("cloud_dps", 12.0)))
	RunFx.ring(get_parent(), pos, r, Color(0.55, 1.0, 0.35), 0.35)
	Juice.fx("ex_plague", pos + Vector2(0, -10))
	Juice.decal("dc_plague_pool", pos + Vector2(0, 8), float(a.get("cloud_time", 3.5)) + 1.2)
	Juice.sfx_at("ab_vial_break", pos)

## =============================================================================
## Targeting & attacks (auto: fire / swing only when an enemy is in range)

func get_trigger_range() -> float:
	return float(_weapon.get("trigger_range", 400.0)) * (MELEE_K if is_melee() else 1.0)

func get_target() -> Node2D:
	return _target if _target != null and is_instance_valid(_target) else null

## Weapon tip for a state/frame from <id>_weapon.json, in local space
## (mirrored with facing). Falls back to the data muzzle when art has none.
## Returns {"pos": Vector2, "dir": Vector2}.
func _tip_info(state: String = "", frame: int = -1) -> Dictionary:
	var st := state if state != "" else _anim.state
	var fr := frame if frame >= 0 else _anim.frame
	var arr: Array = (_wpn_art.get("states", {}) as Dictionary).get(st, [])
	if arr.is_empty() or not _anim.is_ready():
		var m: Vector2 = _weapon.get("muzzle", Vector2(18, -4))
		return {"pos": Vector2(-m.x if _facing_left else m.x, m.y), "dir": _facing_dir()}
	var e: Dictionary = arr[clampi(fr, 0, arr.size() - 1)]
	var tip: Array = e.get("tip", [64.0, 64.0])
	return {
		"pos": _anim.frame_to_local(Vector2(float(tip[0]), float(tip[1]))),
		"dir": _anim.angle_to_dir(float(e.get("angle", 0.0))),
	}

func _muzzle_offset() -> Vector2:
	return _tip_info()["pos"]

func _art_hit_frames(state: String, fallback: Array) -> Array:
	var hf: Variant = (_wpn_art.get("hit_frames", {}) as Dictionary).get(state, fallback)
	return hf if hf is Array and not (hf as Array).is_empty() else fallback

## Turn to face the current aim (attacks always face their target).
func _face_aim() -> void:
	if absf(_last_aim.x) > 0.05:
		_facing_left = _last_aim.x < 0.0
		_anim.set_facing(_facing_left)

func muzzle_global() -> Vector2:
	return global_position + _muzzle_offset()

## True when a world point is inside the visible screen (never target off-screen).
static func is_on_screen(node: Node2D, world_pos: Vector2, margin: float = 6.0) -> bool:
	var vp := node.get_viewport()
	if vp == null:
		return true
	var screen: Vector2 = vp.get_canvas_transform() * world_pos
	var r := vp.get_visible_rect()
	return screen.x >= r.position.x + margin and screen.y >= r.position.y + margin \
		and screen.x <= r.end.x - margin and screen.y <= r.end.y - margin

## Distance used for range checks: melee measures to the enemy's edge.
func _reach_dist(e: Node2D, from: Vector2) -> float:
	var d := from.distance_to(e.global_position)
	if is_melee():
		d -= ENEMY_BODY_R * float(e.get("body_scale") if "body_scale" in e else 1.0)
	return d

## Always the closest on-screen enemy within range (re-checked every frame).
## Hysteresis only keeps a target that drifts just past range (× 1.1).
func _pick_target(range_px: float) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		var d := _reach_dist(e, global_position)
		if d > range_px or d >= best_d:
			continue
		if not is_on_screen(self, e.global_position):
			continue
		best = e
		best_d = d
	var cur := get_target()
	if cur != null and cur.is_in_group("enemies") and is_on_screen(self, cur.global_position):
		var cd := _reach_dist(cur, global_position)
		if cd <= range_px * (1.0 + TARGET_HYSTERESIS):
			if best == null:
				return cur
	return best

## Closest enemy within ±35° of `dir` and in range (stick aim).
const STICK_AIM_COS := 0.82

func _pick_target_cone(range_px: float, dir: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		var to := e.global_position - global_position
		var d := _reach_dist(e, global_position)
		if d > range_px or d >= best_d or to.length_squared() < 1.0:
			continue
		if to.normalized().dot(dir) < STICK_AIM_COS or not is_on_screen(self, e.global_position):
			continue
		best = e
		best_d = d
	return best

func _pick_breakable(range_px: float) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("breakables"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var b := n as Node2D
		var d := _reach_dist(b, global_position)
		if d > range_px or not is_on_screen(self, b.global_position):
			continue
		if "_ping_left" in b and float(b.get("_ping_left")) > 0.0:
			d *= 0.5
		if d < best_d:
			best = b
			best_d = d
	return best

func _update_combat(_delta: float) -> void:
	if _dash_left > 0.0 or _amove_left > 0.0:
		return
	if Input.is_action_just_pressed("reload") and not is_melee() and _ammo < _mag_size() and _reload_left <= 0.0:
		_start_reload()
	## Re-evaluate the target every frame (cheap: ≤ ~14 mobs) — every shot uses the
	## closest one in range.
	_target = _pick_target(get_trigger_range())
	## Settings > Aim with the stick: prefer the enemy in the steer direction.
	if bool(SettingsDefs.get_value("stick_aim")):
		var sd := TouchInput.get_move()
		if sd.length() > 0.3:
			var ct := _pick_target_cone(get_trigger_range(), sd.normalized())
			if ct != null:
				_target = ct
	if _target == null:
		## No enemies in range: break the nearest on-screen crate/wreck
		## (glowing pinged ones first) so lootables actually open.
		_target = _pick_breakable(get_trigger_range())
	if _target == null:
		## Nothing in range: top the mag up so the next fight starts loaded.
		if not is_melee() and _reload_left <= 0.0 and _ammo < _mag_size():
			_start_reload()
		return
	var to := _target.global_position - global_position
	if to.length() > 0.5:
		_last_aim = to.normalized()
	_attack_hold = 0.35
	if _fire_cd > 0.0 or _swing_hits_left > 0 or _ability_pending != "" or _amove_left > 0.0:
		return
	if is_melee():
		_start_swing()
	else:
		_try_shoot()

func _try_shoot() -> void:
	## Hot Barrel: no reloads, but sustained fire overheats the gun.
	if GameState.quirk_fx("no_reload") > 0.0:
		if _overheat_left > 0.0:
			return
		_ammo = _mag_size()
	if _reload_left > 0.0:
		return
	if _ammo <= 0:
		_start_reload()
		return
	var rate := float(_weapon.get("fire_rate", 8.0)) * _buff_firerate()
	_fire_cd = 1.0 / maxf(0.1, rate)
	_fire_one_shot()

func _roll_damage(mult: float = 1.0) -> Array:
	var dmg := float(_weapon.get("damage", 12)) * damage_mult * _buff_damage() * mult * _quirk_damage()
	if _grave_stacks > 0:
		dmg *= 1.0 + float(GearDefs.LEGENDARIES["gravedigger"]["per_stack"]) * float(_grave_stacks)
	var crit := false
	if randf() < GameState.crit_chance():
		crit = true
		dmg *= 1.5 + GameState.crit_damage_bonus()
	return [dmg, crit]

func _fire_one_shot() -> void:
	_ammo -= 1
	_face_aim()
	## Standing: play the firing strip (recoil on its hit frame). Moving: keep
	## the walk cycle and fire from the gun tip of the current walk frame.
	var tip_state := _anim.state
	var tip_frame := _anim.frame
	if velocity.length() < 60.0 and _anim.has_state("attack") and not _anim.is_playing("dash") and not _anim.is_playing("ability"):
		var hf := int(_art_hit_frames("attack", [0])[0])
		var atk_fps := maxf(12.0, float(_anim.frame_count("attack")) * float(_weapon.get("fire_rate", 8.0)) * _buff_firerate() * 0.5)
		_anim.play("attack", atk_fps)
		tip_state = "attack"
		tip_frame = hf
	var tip := _tip_info(tip_state, tip_frame)
	_flash_pos = tip["pos"]
	var origin := global_position + _flash_pos
	var aim := _last_aim
	var tgt := get_target()
	if tgt != null:
		## Lead the target: aim where it will be when the shot arrives.
		var tpos := tgt.global_position
		var tvel = tgt.get("velocity")
		var pspd := float(_weapon.get("projectile_speed", 720.0))
		if tvel is Vector2 and pspd > 1.0:
			tpos += (tvel as Vector2) * (origin.distance_to(tpos) / pspd)
		var from_muzzle := tpos - origin
		if from_muzzle.length() > 24.0:
			aim = from_muzzle.normalized()
	var spread := deg_to_rad(float(_weapon.get("spread_deg", 3.0))) * 0.5
	if _buffs.has("quiet"):
		spread *= 0.7
	aim = aim.rotated(randf_range(-spread, spread))
	## Bell Tower (standing still) and Vial coat boost the shot.
	var mult := 1.0 + _bell_charge
	if _vial_coat_left > 0.0:
		mult *= float(_ability.get("coat_mult", 1.35))
	var roll := _roll_damage(mult)
	_shot_count += 1
	var count := 1
	var fan := 0.0
	var every := int(GameState.up("split_shot", "every", 0))
	if every > 0 and _shot_count % every == 0:
		count = int(GameState.up("split_shot", "count", 3))
		fan = deg_to_rad(float(GameState.up("split_shot", "spread_deg", 12.0)))
	## Lead Rain: every shot is a fan; split shots become a wall of lead.
	if GameState.has_evo("lead_rain"):
		count = int(GameState.up("lead_rain", "split_count", 7)) if count > 1 else int(GameState.up("lead_rain", "count", 3))
		fan = maxf(fan, deg_to_rad(float(GameState.up("lead_rain", "fan_deg", 9.0))) * (1.6 if count > 3 else 1.0))
	## Weapon pattern: extra pellets per trigger (e.g. Flare Sidearm double tap).
	var pellets := int(_weapon.get("pellets", 0))
	if pellets > 0 and count < 1 + pellets:
		count = 1 + pellets
		fan = maxf(fan, deg_to_rad(6.0))
	## Bell Ringer's Shroud (3): Ghost Round — every Nth shot passes through everything.
	var ghost := false
	if GameState.has_set("bell_ringers_shroud", 3):
		ghost = _shot_count % int(GearDefs.SURVIVOR_SETS["bell_ringers_shroud"]["ghost_every"]) == 0
	for i in range(count):
		var off := 0.0 if count == 1 else lerpf(-fan, fan, float(i) / float(count - 1))
		var bl := _spawn_bullet(origin, aim.rotated(off), float(roll[0]), bool(roll[1]))
		if ghost:
			bl.set("pierce_left", 99)
			bl.set("pierce_falloff", 1.0)
			bl.modulate = Color(0.75, 0.9, 1.4, 0.8)
	_flash_left = 0.05
	LightFx.flash(get_parent(), origin, 110.0, Color(1.0, 0.7, 0.32, 0.55), 0.09)
	Juice.fx(MUZZLE_PX.get(str(_weapon.get("projectile", "pistol")), "mz_pistol"), origin, {"dir": aim, "follow": self})
	Juice.sfx("shot", -4.0)
	Juice.shake(float(_weapon.get("shake", 0.035)))
	ammo_changed.emit(_ammo, _mag_size(), false)
	GameState.weapon["weapon_xp"] = int(GameState.weapon.get("weapon_xp", 0)) + 1
	if _ammo <= 0:
		_start_reload()

## --- Melee -------------------------------------------------------------------

func _start_swing() -> void:
	var m: Dictionary = _weapon["melee"]
	var rate := float(_weapon.get("fire_rate", 1.0)) * _buff_firerate()
	_fire_cd = 1.0 / maxf(0.1, rate)
	_swing_dir = _last_aim
	var alt := deg_to_rad(float(m.get("alternate_deg", 0.0)))
	if alt > 0.0:
		## Twin blades: alternate the slash left / right of the target line.
		_swing_dir = _swing_dir.rotated(alt if _swing_index % 2 == 0 else -alt)
	_swing_index += 1
	_swing_count += 1
	_face_aim()
	## Windup strip over the weapon's windup, then the attack strip; damage
	## lands on the art's hit frames (split evenly across them).
	_swing_hit_frames = _art_hit_frames("attack", [1])
	_swing_hits_left = _swing_hit_frames.size()
	var windup := float(m.get("windup", 0.1))
	_swing_atk_fps = maxf(12.0, float(_anim.frame_count("attack")) / maxf(_fire_cd - windup, 0.08))
	if not _anim.has_state("attack"):
		while _swing_hits_left > 0:
			_melee_impact()
	elif windup > 0.02 and _anim.has_state("windup"):
		_anim.play_over("windup", windup)
	else:
		_anim.play("attack", _swing_atk_fps)
	Juice.hero_sfx("swing", -1.0)

func _on_anim_finished(state: String) -> void:
	if state == "windup" and _swing_hits_left > 0:
		_anim.play("attack", _swing_atk_fps)

func _on_anim_frame(state: String, frame: int) -> void:
	if state == "attack" and _swing_hits_left > 0 and frame in _swing_hit_frames:
		_melee_impact()
	elif state == "ability":
		_on_anim_ability_frame(frame)

## Melee hitbox with Piercing Slugs' melee adaptation (+arc / reach).
func _melee_params() -> Dictionary:
	var m: Dictionary = (_weapon["melee"] as Dictionary).duplicate()
	for key in ["radius", "length", "width"]:
		if m.has(key):
			m[key] = float(m[key]) * MELEE_K
	var reach := float(GameState.up("piercing", "reach", 0.0))
	if reach > 0.0:
		m["radius"] = float(m.get("radius", 70.0)) * (1.0 + reach)
		m["arc_deg"] = minf(float(m.get("arc_deg", 120.0)) * (1.0 + reach), 300.0)
		m["length"] = float(m.get("length", 140.0)) * (1.0 + reach)
		m["width"] = float(m.get("width", 30.0)) * (1.0 + reach * 0.5)
	return m

## Damage is applied once, at the impact moment, to every enemy in the hitbox.
func _melee_impact() -> void:
	if _swing_hits_left <= 0:
		return
	var first := _swing_hits_left == _swing_hit_frames.size()
	var share := 1.0 / float(maxi(1, _swing_hit_frames.size()))
	_swing_hits_left -= 1
	var m := _melee_params()
	var shape := str(m.get("shape", "arc"))
	var res := _melee_pass(_swing_dir, m, share, 1.0 if first else 0.35)
	var hit: Array = res[0]
	var dealt: float = res[1]
	var any_crit: bool = res[2]
	for n in get_tree().get_nodes_in_group("breakables"):
		if n is Node2D and is_instance_valid(n) and n.has_method("take_damage") and _in_melee_box(n as Node2D, shape, m, _swing_dir):
			n.call("take_damage", float(_weapon.get("damage", 12)) * damage_mult * share)
	if first:
		_spawn_smear(shape, m, _swing_dir)
		_melee_upgrades_on_swing(hit, m)
		_live_line_swing()
	if hit.size() > 0:
		## Melee survival kit: heal a slice of the damage dealt, brief guard.
		var ls := float(m.get("lifesteal", 0.0))
		if ls > 0.0 and dealt > 0.0:
			heal(dealt * ls)
		_guard_left = maxf(_guard_left, float(m.get("guard_on_hit", 0.0)))
		if first:
			Juice.hitstop(0.05)
		Juice.hero_sfx("impact", -1.0)
		var sh := float(m.get("shake", 0.0))
		if sh > 0.0:
			Juice.shake(sh * (1.3 if any_crit else 1.0))
		GameState.weapon["weapon_xp"] = int(GameState.weapon.get("weapon_xp", 0)) + 1

## One sweep of the hitbox along dir. Returns [hit enemies, damage, any crit].
func _melee_pass(dir: Vector2, m: Dictionary, mult: float, knock_scale: float) -> Array:
	var shape := str(m.get("shape", "arc"))
	var hit: Array = []
	var dealt := 0.0
	var any_crit := false
	var vial := float(_ability.get("coat_mult", 1.35)) if _vial_coat_left > 0.0 else 1.0
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n) or not n.has_method("take_damage"):
			continue
		var e := n as Node2D
		if not _in_melee_box(e, shape, m, dir):
			continue
		var roll := _roll_damage(mult * vial)
		dealt += float(roll[0])
		any_crit = any_crit or bool(roll[1])
		var kdir := (e.global_position - global_position).normalized()
		hit_enemy(e, float(roll[0]), kdir, float(m.get("knockback", 200.0)) * knock_scale, bool(roll[1]), "main")
		hit.append(e)
	return [hit, dealt, any_crit]

## Melee adaptations: Ricochet arcs, Split Shot second slash, Quarry Slam.
func _melee_upgrades_on_swing(hit: Array, m: Dictionary) -> void:
	## Ricochet: the swing arcs on to nearby enemies.
	var chains := int(GameState.up("ricochet", "bounces", 0))
	if chains > 0 and not hit.is_empty():
		var from: Node2D = hit[0]
		var done: Array = hit.duplicate()
		var mult := float(GameState.up("ricochet", "mult", 0.6))
		var rng := float(GameState.up("ricochet", "range", 220.0)) * 0.6
		for i in range(chains):
			if from == null or not is_instance_valid(from):
				break
			var nxt := RunFx.nearest_enemy(get_tree(), from.global_position, rng, done)
			if nxt == null:
				break
			RunFx.zap(get_parent(), from.global_position, nxt.global_position, (m.get("smear", Color(1, 0.9, 0.7)) as Color), 0.18, 2.5)
			var roll := _roll_damage(mult)
			hit_enemy(nxt, float(roll[0]), (nxt.global_position - from.global_position).normalized(), 120.0, bool(roll[1]), "chain")
			done.append(nxt)
			from = nxt
	## Split Shot (melee): every Nth swing adds a mirrored second slash.
	var every := int(GameState.up("split_shot", "every", 0))
	if GameState.has_evo("lead_rain"):
		every = 1
	if every > 0 and _swing_count % every == 0:
		var dir2 := _swing_dir.rotated(deg_to_rad(18.0) * (1.0 if _swing_count % 2 == 0 else -1.0))
		var mult2 := float(GameState.up("split_shot", "slash_mult", 0.6))
		get_tree().create_timer(0.12, false).timeout.connect(func() -> void:
			if _dead or not is_inside_tree():
				return
			var mm := _melee_params()
			_spawn_smear(str(mm.get("shape", "arc")), mm, dir2)
			_melee_pass(dir2, mm, mult2, 0.5)
		)
	## Quarry Slam (Pebble): every Nth swing slams the ground and stuns.
	var q := int(GameState.up("quarry_slam", "every", 0))
	if GameState.has_evo("mountain"):
		q = int(GameState.up("mountain", "every", 2))
	if q > 0 and _swing_count % q == 0:
		if GameState.has_evo("mountain"):
			_guard_left = maxf(_guard_left, float(GameState.up("mountain", "guard", 2.0)))
		var roll2 := _roll_damage(float(GameState.up("quarry_slam", "mult", 0.5)))
		RunFx.explosion(self, global_position + Vector2(0, 10), float(GameState.up("quarry_slam", "radius", 110.0)), float(roll2[0]),
			Color(1.0, 0.8, 0.45), "main", 260.0, float(GameState.up("quarry_slam", "stun", 0.8)), "slam")
		Juice.shake(0.2)

func _in_melee_box(e: Node2D, shape: String, m: Dictionary, dir: Vector2) -> bool:
	var to := e.global_position - global_position
	var body_r := ENEMY_BODY_R * float(e.get("body_scale") if "body_scale" in e else 1.0)
	if shape == "line":
		var along := to.dot(dir)
		var side := absf(to.cross(dir))
		return along > -body_r and along <= float(m.get("length", 140.0)) + body_r \
			and side <= float(m.get("width", 30.0)) * 0.5 + body_r
	var d := to.length()
	if d > float(m.get("radius", 70.0)) + body_r:
		return false
	if d < body_r + 14.0:
		return true ## overlapping the hero — always caught
	var half := deg_to_rad(float(m.get("arc_deg", 120.0))) * 0.5
	return absf(dir.angle_to(to)) <= half + asin(clampf(body_r / d, 0.0, 1.0))

## Swing smear: the weapon's pixel strip along the hitbox (mirrored to one of
## 16 directions, never rotated). m["px"] overrides the strip (abilities).
func _spawn_smear(shape: String, m: Dictionary, dir: Vector2) -> void:
	var def: Array = SMEAR_PX.get(str(_weapon.get("id", "")), ["sm_chain" if shape == "line" else "sm_blade", 90.0 if shape != "line" else 175.0])
	var id := str(m.get("px", def[0]))
	var base := float(m.get("px_base", def[1]))
	var reach := float(m.get("length", 140.0)) if id == "sm_chain" else float(m.get("radius", 70.0))
	## Reach upgrades never scale the pixel art: pick the strip drawn
	## pixel-exact at the nearest longer reach (gen_fx_px.py "_r125"/"_r150").
	var ratio := reach / base
	if ratio >= 1.38 and Juice.px and Juice.px.call("has", id + "_r150"):
		id += "_r150"
	elif ratio >= 1.12 and Juice.px and Juice.px.call("has", id + "_r125"):
		id += "_r125"
	Juice.fx(id, global_position + Vector2(0, -10), {"dir": dir, "follow": self})


## One hero projectile with the run's Piercing / Ricochet / special ammo.
func _spawn_bullet(origin: Vector2, aim: Vector2, dmg: float, crit: bool, spd: float = -1.0) -> Area2D:
	var bullet: Area2D = BulletScene.instantiate()
	bullet.setup(
		origin,
		aim,
		spd if spd > 0.0 else float(_weapon.get("projectile_speed", 720.0)),
		dmg,
		true,
		self,
		float(_weapon.get("lifetime", -1.0)),
		float(_weapon.get("splash_radius", 0.0)),
		float(_weapon.get("splash_mult", 0.5))
	)
	bullet.set("style", str(_weapon.get("projectile", "pistol")))
	bullet.set("crit", crit)
	bullet.set("ammo", special_ammo())
	bullet.set("knock", float(_weapon.get("bullet_knock", 30.0)))
	var lock := get_target()
	if lock != null:
		bullet.set("homing_target", lock)
		bullet.set("homing_turn", float(_weapon.get("homing_turn", 10.0)))
	bullet.set("pierce_left", int(GameState.up("piercing", "pierce", 0)) + int(_weapon.get("pierce", 0)))
	bullet.set("pierce_falloff", float(GameState.up("piercing", "falloff", 0.8)))
	bullet.set("bounces_left", int(GameState.up("ricochet", "bounces", 0)) + int(GameState.up("arc_storm", "bounces", 0)))
	bullet.set("bounce_mult", float(GameState.up("ricochet", "mult", 0.6)))
	bullet.set("bounce_range", float(GameState.up("ricochet", "range", 220.0)))
	get_tree().current_scene.add_child(bullet)
	return bullet

func _start_reload() -> void:
	if _reload_left > 0.0 or is_melee() or GameState.quirk_fx("no_reload") > 0.0:
		return
	_reload_total = _reload_time()
	_reload_left = _reload_total
	Juice.sfx("reload")
	ammo_changed.emit(0, _mag_size(), true)

func get_reload_ratio() -> float:
	var t := _reload_total
	return 1.0 - _reload_left / t if _reload_left > 0.0 and t > 0.0 else 1.0


## Reload tuning (audit #7): ranged heroes spent 50-65% of a run reloading.
## Every reload is 40% shorter; reloading while on the move with nothing in
## range (the auto top-up) is quicker still, so fights start loaded.
var _reload_total: float = 1.0
const RELOAD_TUNE := 0.6
const RELOAD_MOVING_TUNE := 0.75


func _reload_time() -> float:
	var t := float(_weapon.get("reload_time", 1.4)) * RELOAD_TUNE
	if _target == null and velocity.length() > 40.0:
		t *= RELOAD_MOVING_TUNE
	return t

## =============================================================================
## Damage

func take_damage(amount: float, attacker: Node = null) -> void:
	if _iframes > 0.0 or hp <= 0.0 or Admin.god:
		return
	## Run history: what landed the last hit (cause of death).
	if attacker != null and is_instance_valid(attacker):
		var an: Variant = attacker.get("display_name")
		if (an == null or str(an) == "") and attacker.get("kind") != null:
			an = EnemyDefs.get_kind(str(attacker.get("kind"))).get("display_name", attacker.get("kind"))
		last_hit_by = str(an).replace("_", " ").capitalize() if an != null and str(an) != "" else "Enemy"
	else:
		last_hit_by = "Hazard / stray shot"
	## Dust Sidestep — full avoid (soft-capped in GameState).
	if randf() < GameState.dodge_chance():
		_iframes = 0.2
		Juice.float_text(global_position + Vector2(0, -30), "DODGE", UiTheme.TEAL, 16)
		Juice.sfx("dash", -8.0)
		return
	## Iron Tonic: the shield eats one whole hit, then recharges.
	if _tonic_ready:
		_tonic_ready = false
		_tonic_cd = float(GameState.up("bulwark", "recharge", GameState.up("iron_tonic", "recharge", 14.0)))
		## Bulwark: the block blasts everything back.
		if GameState.has_evo("bulwark"):
			RunFx.explosion(self, global_position, float(GameState.up("bulwark", "radius", 120.0)),
				float(GameState.up("bulwark", "damage", 25.0)) * damage_mult, Color(0.95, 0.85, 0.55), "blast", 420.0)
		_iframes = HURT_IFRAMES * 0.6
		Juice.float_text(global_position + Vector2(0, -36), "BLOCKED", Color(0.9, 0.85, 0.6), 16)
		Juice.fx("fx_shield_hit", global_position + Vector2(0, -6), {"follow": self})
		Juice.sfx("shield_block")
		return
	var dmg := float(amount) * resist_mult * float(_char.get("damage_taken_mult", 1.0))
	if _brace_left > 0.0:
		dmg *= float(_ability.get("brace_mult", 1.0))
	dmg *= Admin.def_mult() * GameState.craft_taken_mult(attacker) * GameState.zone_guard
	## Pet gear / bond perks: dodge and guard while the pet is close.
	if _pet_near():
		if randf() < GameState.pet_fx("dodge"):
			_iframes = HURT_IFRAMES * 0.4
			Juice.float_text(global_position + Vector2(0, -36), "DODGE", Color(0.75, 0.9, 1.0), 15)
			return
		dmg *= 1.0 - clampf(GameState.pet_fx("guard"), 0.0, 0.5)
	## Dustborn Regalia (6): Dust Ward eats one big hit every 30 s.
	if _ward_cd <= 0.0 and GameState.has_set("dustborn", 6) and dmg >= max_hp * float(CraftSets.SETS["dustborn"]["ward_frac"]):
		_ward_cd = float(CraftSets.SETS["dustborn"]["ward_cd"])
		_iframes = HURT_IFRAMES * 0.6
		Juice.float_text(global_position + Vector2(0, -36), "DUST WARD", Color(1.0, 0.8, 0.4), 16)
		Juice.fx("fx_shield_hit", global_position + Vector2(0, -6), {"follow": self})
		return
	## Dust Surge: enemies hit harder while it lasts.
	if attacker != null and is_instance_valid(attacker) and attacker.is_in_group("enemies"):
		dmg *= GameState.event_enemy_damage
		## Plague Ward tonic: plague creatures hit softer.
		if str(attacker.get("faction")) == EnemyDefs.PLAGUE:
			dmg *= 1.0 - GameState.tonic_fx("plague_resist")
	## Gear: armor resist; Plague Doctor (2) halves poison / Dust hazards.
	dmg *= 1.0 - GameState.gear_stat("resist")
	var hazard := attacker == null or not is_instance_valid(attacker) or not attacker.is_in_group("enemies")
	if hazard and GameState.has_set("plague_doctor", 2):
		dmg *= float(GearDefs.GENERAL_SETS["plague_doctor"]["hazard_resist"])
	if _stand_fast_left > 0.0:
		dmg *= float(GearDefs.SURVIVOR_SETS["quarry_plate"]["stand_mult"])
	if _mayday_left > 0.0:
		dmg *= float(GearDefs.LEGENDARIES["mayday"]["mult"])
	## Unbreakable (Pebble): less damage below half HP.
	if hp < max_hp * 0.5:
		dmg *= 1.0 - float(GameState.up("unbreakable", "reduce", 0.0))
	if is_melee():
		dmg *= float((_weapon["melee"] as Dictionary).get("resist", 1.0))
		if _guard_left > 0.0:
			dmg *= 0.5
	## Brace Plate — half damage on proc (full rate with block_affinity kits).
	if randf() < GameState.block_chance():
		dmg *= 0.5
		Juice.float_text(global_position + Vector2(0, -42), "BLOCK", UiTheme.AMBER, 14)
	hp -= dmg
	_iframes = HURT_IFRAMES
	## Gravedigger stacks fall off on a hit.
	_grave_stacks = 0
	## A little shove away from the attacker (Demolition Crew 2 halves it).
	if not hazard and attacker is Node2D:
		var kd := (global_position - (attacker as Node2D).global_position).normalized()
		var kk := KNOCK_TAKEN * (float(GearDefs.GENERAL_SETS["demolition_crew"]["knock_taken"]) if GameState.has_set("demolition_crew", 2) else 1.0)
		_knock_v = kd * kk
	_gear_after_hurt()
	if attacker != null and is_instance_valid(attacker) and attacker != self:
		attacked.emit(attacker)
	hurt.emit(dmg)
	Juice.sfx("hurt")
	Juice.shake(0.28)
	Juice.haptic(Juice.HAPTIC_HIT)
	Juice.flash(body, Color(2.5, 0.6, 0.5), 0.15)
	_anim.squash(0.12)
	if not (_anim.is_playing("dash") or _anim.is_playing("ability")):
		_anim.play("hit")
	Juice.damage_number(global_position + Vector2(0, -30), dmg, false, UiTheme.DANGER, self)
	if hp <= 0.0 and _last_rites:
		_last_rites = false
		hp = max_hp * float(GearDefs.SURVIVOR_SETS["cathedral_vestments"]["revive_frac"])
		_iframes = 1.5
		Juice.float_text(global_position + Vector2(0, -50), "LAST RITES", Color(1.0, 0.95, 0.7), 24)
		Juice.burst(global_position, Color(1.0, 0.95, 0.7), 30, 220.0, 0.8)
		health_changed.emit(hp, max_hp)
		return
	if hp <= 0.0 and _last_stitch_available:
		_last_stitch_available = false
		hp = 1.0
		_iframes = 1.2
		Juice.float_text(global_position + Vector2(0, -50), "LAST STITCH!", UiTheme.TEAL, 24)
		health_changed.emit(hp, max_hp)
		return
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_go_down()

## HP lost to sickness (plague exposure): no i-frames, no flinch.
func drain(amount: float) -> void:
	if _dead or hp <= 0.0 or amount <= 0.0 or Admin.god:
		return
	hp -= amount
	if hp <= 0.0:
		if _last_rites:
			_last_rites = false
			hp = max_hp * float(GearDefs.SURVIVOR_SETS["cathedral_vestments"]["revive_frac"])
			Juice.float_text(global_position + Vector2(0, -50), "LAST RITES", Color(1.0, 0.95, 0.7), 24)
		elif _last_stitch_available:
			_last_stitch_available = false
			hp = 1.0
			Juice.float_text(global_position + Vector2(0, -50), "LAST STITCH!", UiTheme.TEAL, 24)
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_go_down()

func _go_down() -> void:
	if _dead:
		return
	Juice.burst(global_position, Color(0.9, 0.3, 0.2), 30, 240.0, 0.7, 1.5)
	Juice.hitstop(0.12)
	Juice.hero_sfx("death")
	remove_from_group("player")
	died.emit()
	set_physics_process(false)
	_dead = true
	_swing_hits_left = 0
	body.modulate = Color.WHITE
	_anim.play("death")
	collision_layer = 0
	_ability_pending = ""
	for d in get_drones():
		if is_instance_valid(d):
			d.queue_free()
	_drones.clear()
	_temp_drones.clear()
	if _orbit and is_instance_valid(_orbit):
		_orbit.queue_free()

func heal(amount: float) -> void:
	if hp <= 0.0 or amount <= 0.0:
		return
	## Burn It Down (Cinder): healing while hurt ignites everything nearby.
	if GameState.run_rank("burn_it_down") > 0 and _burn_cd <= 0.0 \
			and hp < max_hp * float(GameState.up("burn_it_down", "below", 0.7)):
		_burn_cd = UpgradeDefs.BURN_IT_DOWN_CD
		var r := float(GameState.up("burn_it_down", "radius", 120.0))
		for e in RunFx.enemies_in(get_tree(), global_position, r):
			e.call("apply_status", "burn", float(GameState.up("burn_it_down", "time", 3.0)), float(GameState.up("burn_it_down", "dps", 10.0)))
		RunFx.ring(get_parent(), global_position + Vector2(0, 8), r, Color(1.0, 0.5, 0.2), 0.4, 6.0)
		Juice.burst(global_position, Color(1.0, 0.5, 0.2), 20, r * 2.0, 0.4, 1.4)
	var amt := amount * _greed_heal()
	if GameState.has_set("plague_doctor", 4):
		amt *= float(GearDefs.GENERAL_SETS["plague_doctor"]["heal_mult"])
	hp = minf(max_hp, hp + amt)
	health_changed.emit(hp, max_hp)

## Greed pressure: healing shrinks with every extract window you stayed past.
func _pet_near() -> bool:
	var p := get_tree().get_first_node_in_group("pets") as Node2D
	return p != null and p.global_position.distance_to(global_position) <= PetGear.NEAR

func _greed_heal() -> float:
	if GameState.in_campaign_run():
		return 1.0
	return float(ModeDefs.greed(GameState.windows_skipped)["heal"])

func is_hidden() -> bool:
	return _hidden_left > 0.0

## =============================================================================
## Hit pipeline: every hero-side hit (shots, swings, drones, blades, mines,
## abilities) goes through here so on-hit upgrades and special ammo stack.

func hit_enemy(e: Node, dmg: float, dir: Vector2, knock: float = -1.0, crit: bool = false, src: String = "main") -> void:
	if e == null or not is_instance_valid(e) or not e.has_method("take_damage"):
		return
	if bool(e.get("_dead")):
		return
	dmg *= _damage_vs(e as Node2D, src) * Admin.dmg_mult() * GameState.craft_damage_mult(e)
	## Depth E2: plague burns, machines short out.
	var weak := FactionDefs.weakness(str(e.get("faction")), hit_element(src))
	if weak > 1.0:
		dmg *= weak
		if e.has_method("note_weak_hit"):
			e.call("note_weak_hit")
	var is_crit := crit
	if not is_crit and _forced_crit(e as Node2D, src):
		dmg *= 1.5 + GameState.crit_damage_bonus()
		is_crit = true
	## Status first so Short Circuit / Marked already count on this hit.
	_on_hit_effects(e as Node2D, dmg, src)
	var at := (e as Node2D).global_position
	if is_instance_valid(e):
		e.call("take_damage", dmg, dir, knock, is_crit)
	_legendary_on_hit(at, src)

## Element of a hit ("fire" / "shock" / ""): special ammo, weapon coatings,
## Juno's electric ability + chains, explosions count as fire.
func hit_element(src: String) -> String:
	match special_ammo():
		"incendiary", "explosive":
			return "fire"
		"shock":
			return "shock"
	if src in ["ability", "chain"] and GameState.selected_character_id == CharacterDefs.BOLT_JUNO_ID:
		return "shock"
	if src == "blast":
		return "fire"
	if src == "arc":
		return "shock"
	var coats: Variant = _weapon.get("coats", [])
	if coats is Array:
		for c in coats:
			if c is Dictionary:
				match str(c.get("coat", "")):
					"fire":
						return "fire"
					"shock":
						return "shock"
	return ""

## Field Notes (per-kind kills) and Double Cross (hits from behind).
func _damage_vs(e: Node2D, src: String) -> float:
	var m := 1.0
	## Field Notes weak spots (kept across runs).
	m *= 1.0 + GameState.bestiary_bonus(str(e.get("kind")))
	## Tonics: Firebrand (plague) / Spark (machines).
	match str(e.get("faction")):
		EnemyDefs.PLAGUE:
			m *= 1.0 + GameState.tonic_fx("vs_plague")
		EnemyDefs.MACHINE:
			m *= 1.0 + GameState.tonic_fx("vs_machine")
	var per := float(GameState.up("field_notes", "per_kill", 0.0))
	if per > 0.0:
		var k := int(GameState.run_kind_kills.get(str(e.get("kind")), 0))
		m *= 1.0 + minf(per * k, float(GameState.up("field_notes", "cap", 0.3)) * float(GameState.up("autopsy_table", "cap_mult", 1.0)))
	if GameState.run_rank("double_cross") > 0 and src in ["main", "ability", "chain"]:
		var facing := Vector2.LEFT if bool(e.get("_facing_left")) else Vector2.RIGHT
		var to_me := (global_position - e.global_position).normalized()
		var cone := deg_to_rad(float(GameState.up("double_cross", "cone_deg", 90.0)))
		if _ghost_left > 0.0 or absf(facing.angle_to(to_me)) >= PI - cone * 0.5:
			m *= float(GameState.up("double_cross", "mult", 3.0))
			if _backstab_text_cd <= 0.0:
				_backstab_text_cd = 0.6
				Juice.float_text(e.global_position + Vector2(0, -44), "BACKSTAB", Color(0.6, 0.75, 1.0), 13)
	return m

func _on_hit_effects(e: Node2D, dmg: float, src: String) -> void:
	if not e.has_method("apply_status"):
		return
	## Arc Storm: hits can arc lightning on to a nearby enemy.
	if GameState.has_evo("arc_storm") and src in ["main", "chain", "drone"] and randf() < float(GameState.up("arc_storm", "chance", 0.45)):
		var nx := RunFx.nearest_enemy(get_tree(), e.global_position, float(GameState.up("arc_storm", "range", 170.0)), [e])
		if nx != null:
			RunFx.zap(get_parent(), e.global_position + Vector2(0, -10), nx.global_position + Vector2(0, -10), Color(0.55, 0.85, 1.0), 0.2, 3.0)
			nx.call("apply_status", "stun", float(GameState.up("arc_storm", "stun", 0.35)))
			hit_enemy.call_deferred(nx, dmg * float(GameState.up("arc_storm", "mult", 0.5)), (nx.global_position - e.global_position).normalized(), 60.0, false, "arc")
	if GameState.run_rank("dust_rounds") > 0:
		e.call("apply_status", "poison", float(GameState.up("dust_rounds", "time", 3.0)), float(GameState.up("dust_rounds", "dps", 4.0)))
	if GameState.run_rank("marked") > 0 and src in ["main", "chain", "ability", "drone"]:
		e.call("apply_status", "mark", float(GameState.up("marked", "time", 3.0)), float(GameState.up("marked", "mult", 1.15)))
	if _vial_coat_left > 0.0 and src in ["main", "chain"]:
		e.call("apply_status", "poison", float(_ability.get("coat_poison_time", 3.0)), float(_ability.get("coat_dps", 6.0)))
	## Weapon element / coating mods.
	var coats: Variant = _weapon.get("coats", [])
	if coats is Array:
		for c in coats:
			if not (c is Dictionary) or not is_instance_valid(e):
				continue
			var ce: Dictionary = GearDefs.COAT_EFFECT.get(str(c.get("coat", "")), {})
			if ce.is_empty():
				continue
			var v := float(c.get("val", 0.0))
			match str(c.get("coat", "")):
				"poison", "fire":
					e.call("apply_status", str(ce["status"]), float(ce["time"]), v)
				"shock":
					if randf() < v / 100.0:
						e.call("apply_status", "stun", float(ce["time"]))
				"frost":
					e.call("apply_status", "slow", float(ce["time"]), clampf(1.0 - v / 100.0, 0.3, 1.0))
	var ammo := special_ammo()
	if ammo == "":
		return
	var a: Dictionary = UpgradeDefs.AMMO[ammo]
	match ammo:
		"incendiary":
			e.call("apply_status", "burn", float(a["burn_time"]), float(a["burn_dps"]))
		"shock":
			if randf() < float(a["stun_chance"]):
				e.call("apply_status", "stun", float(a["stun_time"]))
				RunFx.zap(get_parent(), e.global_position + Vector2(-10, -14), e.global_position + Vector2(10, 6), a["color"], 0.15, 2.0)
		"frost":
			e.call("apply_status", "slow", float(a["slow_time"]), float(a["slow_mult"]))
		"explosive":
			if src not in ["blast", "mine"]:
				RunFx.explosion(self, e.global_position, float(a["blast_radius"]), dmg * float(a["blast_mult"]), a["color"], "blast", 140.0)

## Per-frame run-upgrade upkeep: mines, bayonet, supply drops, Bell Tower,
## Iron Tonic recharge, Rook's ram.
func _update_run_upgrades(delta: float) -> void:
	_update_rush_ram()
	_update_evolutions(delta)
	_update_gear(delta)
	## Bell Tower: standing still charges stronger shots.
	if GameState.run_rank("bell_tower") > 0:
		if velocity.length() < 12.0:
			_bell_charge = minf(_bell_charge + float(GameState.up("bell_tower", "per_sec", 0.35)) * delta, float(GameState.up("bell_tower", "cap", 0.7)) + float(GameState.up("death_knell", "bell_cap", 0.0)))
		elif velocity.length() > 40.0:
			_bell_charge = 0.0
		if _bell_ring:
			var k := _bell_charge / maxf(0.01, float(GameState.up("bell_tower", "cap", 0.7)))
			_bell_ring.default_color = Color(0.6, 1.0, 0.45, 0.85 * k)
			_bell_ring.scale = Vector2.ONE * (0.7 + 0.5 * k)
	## Iron Tonic recharge + bubble.
	if GameState.run_rank("iron_tonic") > 0:
		if not _tonic_ready:
			_tonic_cd -= delta
			if _tonic_cd <= 0.0:
				_tonic_ready = true
				Juice.float_text(global_position + Vector2(0, -36), "SHIELD UP", Color(0.9, 0.85, 0.6), 12)
		if _tonic_fx:
			_tonic_fx.visible = _tonic_ready
			if not _tonic_frames.is_empty():
				_tonic_fx.texture = _tonic_frames[int(Time.get_ticks_msec() / 220) % _tonic_frames.size()]
			_tonic_fx.modulate = Color(1, 1, 1, 0.45)
	## Spore Mines: drop one every few steps.
	var every_px := float(GameState.up("spore_mines", "every_px", 0.0))
	if every_px > 0.0:
		_mine_dist += velocity.length() * delta
		if _mine_dist >= every_px:
			_mine_dist = 0.0
			if get_tree().get_nodes_in_group("spore_mines").size() < int(GameState.up("spore_mines", "max_alive", 5)):
				RunFx.spore_mine(get_parent(), self, global_position + Vector2(0, FEET_Y - 6))
	## Bayonet (Quill): stab whatever gets too close.
	if GameState.run_rank("bayonet") > 0:
		_bayonet_cd -= delta
		if _bayonet_cd <= 0.0:
			var near := RunFx.enemies_in(get_tree(), global_position, float(GameState.up("bayonet", "radius", 44.0)))
			if not near.is_empty():
				_bayonet_cd = float(GameState.up("bayonet", "every", 0.6))
				for e in near:
					var dir := ((e as Node2D).global_position - global_position).normalized()
					var roll := _roll_damage(float(GameState.up("bayonet", "mult", 0.6)))
					if GameState.has_evo("autopsy_table"):
						e.call("apply_status", "mark", float(GameState.up("autopsy_table", "mark_time", 3.0)), float(GameState.up("autopsy_table", "mark", 1.3)))
					_spawn_smear("line", {"length": 44.0, "width": 16.0, "smear": Color(0.95, 0.9, 0.8)}, dir)
					hit_enemy(e, float(roll[0]), dir, 160.0, bool(roll[1]), "main")
	## Supply Drop (Helm): a crate of special ammo every N seconds.
	var sd := float(GameState.up("supply_drop", "every", 0.0))
	if sd > 0.0:
		_supply_t += delta
		if _supply_t >= (sd if _supply_drops > 0 else minf(sd, UpgradeDefs.SUPPLY_FIRST_DROP)):
			_supply_drops += 1
			_supply_t = 0.0
			var ang := randf() * TAU
			RunFx.supply_crate(get_parent(), global_position + Vector2(cos(ang), sin(ang)) * randf_range(90.0, 150.0))
			Juice.float_text(global_position + Vector2(0, -44), "SUPPLY DROP", Color(0.55, 0.85, 0.55), 14)

## Firewalk: fire patches along the dash path.
func _firewalk_step(moved: float) -> void:
	if GameState.run_rank("firewalk") <= 0:
		return
	_trail_dist += moved
	var r := float(GameState.up("firewalk", "radius", 30.0))
	if _trail_dist >= r * 0.9:
		_trail_dist = 0.0
		RunFx.ground(get_parent(), self, global_position + Vector2(0, FEET_Y - 4), "burn", r,
			float(GameState.up("firewalk", "time", 2.5)), float(GameState.up("firewalk", "dps", 14.0)) * float(GameState.up("hellfire_stride", "burn_mult", 1.0)))

func is_dashing() -> bool:
	return _dash_left > 0.0

## =============================================================================
## HUD text helpers

func get_ammo_text() -> String:
	if is_melee():
		return ""
	if _reload_left > 0.0:
		return "RELOADING"
	return "%d / %d" % [_ammo, _mag_size()]

func get_ammo() -> int:
	return _ammo

func get_mag_size() -> int:
	return _mag_size()

func is_reloading() -> bool:
	return _reload_left > 0.0

## =============================================================================
## Gear: general / survivor set bonuses and named Legendaries (Part 7)

## Kill hook from enemy._die().
func on_kill(e: Node) -> void:
	if _dead:
		return
	_kills += 1
	if GameState.quirk_fx("kill_heal") > 0.0 and hp > 0.0:
		hp = minf(max_hp, hp + GameState.quirk_fx("kill_heal"))
		health_changed.emit(hp, max_hp)
	var pos: Vector2 = (e as Node2D).global_position if e is Node2D else global_position
	var parent := get_parent()
	var gs: Dictionary = GearDefs.GENERAL_SETS
	var ss: Dictionary = GearDefs.SURVIVOR_SETS
	var lg: Dictionary = GearDefs.LEGENDARIES
	## Plague Doctor (6): kills may drop a small heal.
	if GameState.has_set("plague_doctor", 6) and randf() < float(gs["plague_doctor"]["kill_heal_chance"]):
		LootDrop.spawn_burst(parent, pos, "tonic", 1, float(gs["plague_doctor"]["kill_heal"]))
	## Rustwright's Harness (6): Overcharge shock nova every Nth kill.
	if GameState.has_set("rustwright", 6) and _kills % int(CraftSets.SETS["rustwright"]["nova_every"]) == 0:
		var rw: Dictionary = CraftSets.SETS["rustwright"]
		RunFx.explosion(self, global_position, float(rw["nova_radius"]), float(rw["nova_damage"]) * damage_mult,
			Color(0.45, 0.85, 1.0), "ability", 260.0, float(rw["nova_stun"]), "slam")
		Juice.shake(0.15)
	## Ashwalker's Shroud (6): Ash Bloom where the kill fell.
	if GameState.has_set("ashwalker", 6):
		var aw: Dictionary = CraftSets.SETS["ashwalker"]
		RunFx.ground(parent, self, pos, "poison", float(aw["bloom_radius"]), float(aw["bloom_time"]), float(aw["bloom_dps"]))
	## Demolition Crew (6): every Nth kill sets off a blast around you.
	if GameState.has_set("demolition_crew", 6) and _kills % int(gs["demolition_crew"]["blast_every"]) == 0:
		RunFx.explosion(self, global_position, float(gs["demolition_crew"]["blast_radius"]),
			float(gs["demolition_crew"]["blast_damage"]) * damage_mult, Color(1.0, 0.6, 0.25), "blast", 300.0)
		Juice.shake(0.2)
	## Surgeon's Coat (3): Autopsy — a heal vial or a short damage buff.
	if GameState.has_set("surgeons_coat", 3) and randf() < float(ss["surgeons_coat"]["autopsy_chance"]):
		if randf() < 0.5:
			LootDrop.spawn_burst(parent, pos, "tonic", 1, float(ss["surgeons_coat"]["autopsy_heal"]))
		else:
			apply_powerup({"id": "damage", "name": "Autopsy Vial", "color": Color(1.0, 0.45, 0.6), "duration": float(ss["surgeons_coat"]["autopsy_buff"])})
	match GameState.gear_legendary():
		"gravedigger":
			_grave_stacks = mini(_grave_stacks + 1, int(lg["gravedigger"]["max_stacks"]))
		"bellwether":
			if _bell_cd <= 0.0:
				_bell_cd = float(lg["bellwether"]["cooldown"])
				for n in get_tree().get_nodes_in_group("enemies"):
					if n is Node2D and is_instance_valid(n) and is_on_screen(self, (n as Node2D).global_position) and n.has_method("apply_status"):
						n.call("apply_status", "slow", float(lg["bellwether"]["slow_time"]), float(lg["bellwether"]["slow_mult"]))
				RunFx.ring(parent, pos, 140.0, Color(1.0, 0.85, 0.4), 0.5, 4.0)
				Juice.float_text(pos + Vector2(0, -40), "BELL", Color(1.0, 0.85, 0.4), 16)
		"twin_debts":
			_debt_target = RunFx.nearest_enemy(get_tree(), pos, float(lg["twin_debts"]["range"]), [e])
			if _debt_target != null:
				Juice.float_text(_debt_target.global_position + Vector2(0, -44), "DEBT", Color(0.8, 0.6, 1.0), 13)


## Bonesaw (back / marked always crits) and Twin Debts (marked debtor crits).
func _forced_crit(e: Node2D, src: String) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	match GameState.gear_legendary():
		"bonesaw":
			if src not in ["main", "chain", "ability"]:
				return false
			if e.has_method("has_status") and bool(e.call("has_status", "mark")):
				return true
			var facing := Vector2.LEFT if bool(e.get("_facing_left")) else Vector2.RIGHT
			var to_me := (global_position - e.global_position).normalized()
			var cone := deg_to_rad(float(GearDefs.LEGENDARIES["bonesaw"]["cone_deg"]))
			return absf(facing.angle_to(to_me)) >= PI - cone * 0.5
		"twin_debts":
			if _debt_target != null and is_instance_valid(_debt_target) and e == _debt_target:
				_debt_target = null
				return true
	return false


## Last Shift (burning rubble) and Censer (healing smoke) after a hit.
func _legendary_on_hit(at: Vector2, src: String) -> void:
	if src != "main":
		return
	var lg: Dictionary = GearDefs.LEGENDARIES
	match GameState.gear_legendary():
		"last_shift":
			if _rubble_cd <= 0.0:
				_rubble_cd = 0.25
				RunFx.ground(get_parent(), self, at, "burn", float(lg["last_shift"]["radius"]), float(lg["last_shift"]["time"]), float(lg["last_shift"]["dps"]))
		"censer":
			_hit_total += 1
			if _hit_total % int(lg["censer"]["every"]) == 0:
				RunFx.ground(get_parent(), self, at, "heal", float(lg["censer"]["radius"]), float(lg["censer"]["time"]), float(lg["censer"]["hps"]))


## Live Line: every Nth punch arcs lightning to the nearest enemy.
func _live_line_swing() -> void:
	if GameState.gear_legendary() != "live_line":
		return
	_swing_total += 1
	var ll: Dictionary = GearDefs.LEGENDARIES["live_line"]
	if _swing_total % int(ll["every"]) != 0:
		return
	var t := RunFx.nearest_enemy(get_tree(), global_position, float(ll["range"]))
	if t == null:
		return
	RunFx.zap(get_parent(), global_position + Vector2(0, -8), t.global_position, Color(0.55, 0.85, 1.0), 0.25, 3.5)
	var roll := _roll_damage(float(ll["mult"]))
	t.call("apply_status", "stun", float(ll["stun"]))
	hit_enemy(t, float(roll[0]), (t.global_position - global_position).normalized(), 120.0, bool(roll[1]), "chain")


## Quarry Plate (3) Stand Fast and Mayday after taking damage.
func _gear_after_hurt() -> void:
	if hp <= 0.0:
		return
	var qp: Dictionary = GearDefs.SURVIVOR_SETS["quarry_plate"]
	if not _stand_fast_used and GameState.has_set("quarry_plate", 3) and hp < max_hp * float(qp["stand_below"]):
		_stand_fast_used = true
		_stand_fast_left = float(qp["stand_time"])
		Juice.float_text(global_position + Vector2(0, -50), "STAND FAST", Color(0.95, 0.85, 0.6), 20)
		RunFx.ring(get_parent(), global_position + Vector2(0, 8), 60.0, Color(0.95, 0.85, 0.6), 0.5, 5.0)
	var md: Dictionary = GearDefs.LEGENDARIES["mayday"]
	if GameState.gear_legendary() == "mayday" and _mayday_cd <= 0.0 and hp < max_hp * float(md["below"]):
		_mayday_left = float(md["time"])
		_mayday_cd = float(md["cooldown"])
		Juice.float_text(global_position + Vector2(0, -50), "MAYDAY!", Color(0.5, 1.0, 0.85), 20)
		for d in get_drones():
			if is_instance_valid(d):
				RunFx.zap(get_parent(), (d as Node2D).global_position, global_position, Color(0.5, 1.0, 0.85), 0.4, 3.0)


## Night Runner (6) vanish and Smuggler's Wraps (3) Shadow Step decoy.
func _gear_on_dash() -> void:
	if GameState.has_set("night_runner", 6):
		var nr: Dictionary = GearDefs.GENERAL_SETS["night_runner"]
		for e in RunFx.enemies_in(get_tree(), global_position, float(nr["vanish_radius"])):
			if e.has_method("distract"):
				e.call("distract", float(nr["vanish_time"]))
	if GameState.has_set("smugglers_wraps", 3):
		var sw: Dictionary = GearDefs.SURVIVOR_SETS["smugglers_wraps"]
		var at := global_position
		var ghost := Sprite2D.new()
		ghost.texture = body.texture
		ghost.hframes = body.hframes
		ghost.frame = body.frame
		ghost.offset = body.offset
		ghost.flip_h = body.flip_h
		ghost.scale = body.scale
		ghost.global_position = body.global_position
		ghost.modulate = Color(0.55, 0.5, 0.9, 0.7)
		get_parent().add_child(ghost)
		var tw := ghost.create_tween()
		tw.tween_interval(float(sw["decoy_time"]) * 0.8)
		tw.tween_property(ghost, "modulate:a", 0.0, float(sw["decoy_time"]) * 0.2)
		tw.tween_callback(ghost.queue_free)
		for e in RunFx.enemies_in(get_tree(), at, float(sw["decoy_radius"])):
			if e.has_method("lure"):
				e.call("lure", at, float(sw["decoy_time"]))


## Demolition Crew (4): the dash itself hits enemies.
func _demolition_dash() -> void:
	if not GameState.has_set("demolition_crew", 4):
		return
	var dc: Dictionary = GearDefs.GENERAL_SETS["demolition_crew"]
	for e in RunFx.enemies_in(get_tree(), global_position, float(dc["dash_radius"])):
		if e in _dash_hit:
			continue
		_dash_hit.append(e)
		hit_enemy(e, float(dc["dash_damage"]) * damage_mult, _dash_dir, 260.0, false, "blast")


## Per-frame gear upkeep: Lineman's Static Field, Flight Crew Air Support.
func _update_gear(delta: float) -> void:
	if GameState.has_set("linemans_rig", 3):
		var lr: Dictionary = GearDefs.SURVIVOR_SETS["linemans_rig"]
		_static_t += delta
		if _static_t >= float(lr["static_every"]):
			_static_t = 0.0
			for e in RunFx.enemies_in(get_tree(), global_position, float(lr["static_radius"])):
				RunFx.zap(get_parent(), global_position + Vector2(0, -6), (e as Node2D).global_position, Color(0.55, 0.85, 1.0), 0.12, 2.0)
				e.call("apply_status", "stun", float(lr["static_stun"]))
				hit_enemy(e, float(lr["static_damage"]) * damage_mult, ((e as Node2D).global_position - global_position).normalized(), 60.0, false, "blast")
	if GameState.has_set("flight_crew_gear", 3):
		var fc: Dictionary = GearDefs.SURVIVOR_SETS["flight_crew_gear"]
		_volley_t += delta
		if _volley_t >= float(fc["volley_every"]):
			_volley_t = 0.0
			_air_support(fc)


func _air_support(fc: Dictionary) -> void:
	var targets: Array = []
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Node2D and is_instance_valid(n) and is_on_screen(self, (n as Node2D).global_position):
			targets.append(n)
	if targets.is_empty():
		_volley_t = float(fc["volley_every"]) - 1.0
		return
	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	var from := global_position + Vector2(0, -30)
	var ds := get_drones()
	if not ds.is_empty() and is_instance_valid(ds[0]):
		from = (ds[0] as Node2D).global_position
	Juice.float_text(global_position + Vector2(0, -48), "AIR SUPPORT", Color(0.5, 1.0, 0.85), 15)
	for i in range(int(fc["volley_count"])):
		var t: Node2D = targets[i % targets.size()]
		if not is_instance_valid(t):
			continue
		var at := t.global_position + Vector2(randf_range(-14, 14), randf_range(-14, 14))
		RunFx.zap(get_parent(), from, at, Color(1.0, 0.7, 0.35), 0.3, 2.5)
		RunFx.explosion(self, at, float(fc["volley_radius"]), float(fc["volley_damage"]) * damage_mult, Color(1.0, 0.6, 0.3), "blast", 140.0)
	Juice.shake(0.15)

## =============================================================================
## Depth E3 evolutions with their own timers (RecipeDefs).

func _update_evolutions(delta: float) -> void:
	_ghost_left = maxf(0.0, _ghost_left - delta)
	_tick_heat(delta)
	## Blade Storm: the blades fling shards in every direction.
	if GameState.has_evo("blade_storm"):
		_shard_t -= delta
		if _shard_t <= 0.0:
			_shard_t = float(GameState.up("blade_storm", "shard_every", 1.1))
			var n := int(GameState.up("blade_storm", "shards", 8))
			var dmg := float(GameState.up("orbit_blades", "damage", 9.0)) * damage_mult * float(GameState.up("blade_storm", "shard_mult", 0.5)) * 2.0
			var off := randf() * TAU
			for i in range(n):
				var d := Vector2.RIGHT.rotated(off + TAU * i / float(n))
				var b := _spawn_bullet(global_position + d * 20.0 + Vector2(0, -6), d, dmg, false, 560.0)
				b.set("homing_target", null)
				b.set("pierce_left", 1)
				b.set("lifetime", 0.55)
	## Earthquake: RUSH shakes the ground as Rook goes.
	if GameState.has_evo("earthquake") and _rush_active:
		_quake_t -= delta
		if _quake_t <= 0.0:
			_quake_t = float(GameState.up("earthquake", "every", 0.25))
			RunFx.explosion(self, global_position + Vector2(0, 10), float(GameState.up("earthquake", "radius", 75.0)),
				float(GameState.up("earthquake", "damage", 18.0)) * damage_mult, Color(0.9, 0.7, 0.4), "blast", 200.0)
			Juice.dust_puff(global_position + Vector2(0, 14), 8)
	## Thunderhead: a storm around Juno zaps enemies after OVERLOAD.
	if _storm_left > 0.0:
		_storm_left -= delta
		_storm_t -= delta
		if _storm_t <= 0.0:
			_storm_t = float(GameState.up("thunderhead", "every", 0.35))
			var t := RunFx.nearest_enemy(get_tree(), global_position, float(GameState.up("thunderhead", "range", 210.0)))
			if t != null:
				RunFx.zap(get_parent(), global_position + Vector2(randf_range(-30, 30), -70), t.global_position, Color(0.6, 0.85, 1.0), 0.18, 3.5)
				t.call("apply_status", "stun", float(GameState.up("thunderhead", "stun", 0.3)))
				var roll := _roll_damage(float(GameState.up("thunderhead", "mult", 0.6)))
				hit_enemy(t, float(roll[0]), (t.global_position - global_position).normalized(), 80.0, bool(roll[1]), "arc")
	## Air Raid: every few seconds each drone fires a missile.
	if GameState.has_evo("air_raid"):
		_raid_t -= delta
		if _raid_t <= 0.0:
			_raid_t = float(GameState.up("air_raid", "every", 6.0))
			for d in get_drones():
				if not is_instance_valid(d):
					continue
				var t2 := RunFx.nearest_enemy(get_tree(), (d as Node2D).global_position, 420.0)
				if t2 == null:
					continue
				RunFx.zap(get_parent(), (d as Node2D).global_position, t2.global_position, Color(1.0, 0.7, 0.35), 0.3, 2.5)
				RunFx.explosion(self, t2.global_position, float(GameState.up("air_raid", "radius", 70.0)),
					float(GameState.up("air_raid", "damage", 34.0)) * damage_mult, Color(1.0, 0.6, 0.3), "blast", 180.0)


## =============================================================================
## Depth E5 quirks

## Damage multiplier from the run's quirk (situational ones checked live).
func _quirk_damage() -> float:
	var q := 1.0
	if GameState.quirk_fx("rage") > 0.0 and hp < max_hp * GameState.quirk_fx("below"):
		q *= 1.0 + GameState.quirk_fx("rage")
	if GameState.quirk_fx("still_damage") > 0.0 and velocity.length() < 12.0:
		q *= 1.0 + GameState.quirk_fx("still_damage")
	if GameState.quirk_fx("stage_damage") > 0.0 and exposure_stage >= 0:
		q *= 1.0 + GameState.quirk_fx("stage_damage") * float(exposure_stage + 1)
	if GameState.quirk_fx("pet_damage") > 0.0:
		for pt in get_tree().get_nodes_in_group("pets"):
			if pt is Node2D and (pt as Node2D).global_position.distance_to(global_position) <= GameState.quirk_fx("pet_range"):
				q *= 1.0 + GameState.quirk_fx("pet_damage")
				break
	return q


## Hot Barrel: heat builds while shooting, cools when not; full heat = overheat.
func _tick_heat(delta: float) -> void:
	if GameState.quirk_fx("no_reload") <= 0.0:
		return
	if _overheat_left > 0.0:
		_overheat_left -= delta
		if randf() < 0.2:
			Juice.burst(global_position + _muzzle_offset(), Color(0.8, 0.8, 0.8, 0.6), 1, 40.0, 0.5, 1.2)
		return
	if _fire_cd > 0.0 and get_target() != null:
		_heat += delta
		if _heat >= GameState.quirk_fx("heat_max"):
			_heat = 0.0
			_overheat_left = GameState.quirk_fx("overheat")
			Juice.float_text(global_position + Vector2(0, -44), "OVERHEAT", Color(1.0, 0.55, 0.25), 15)
	else:
		_heat = maxf(0.0, _heat - delta * 1.5)


func heat_ratio() -> float:
	if _overheat_left > 0.0:
		return 1.0
	var mx := GameState.quirk_fx("heat_max")
	return clampf(_heat / mx, 0.0, 1.0) if mx > 0.0 else 0.0
