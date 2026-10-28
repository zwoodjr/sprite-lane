extends Area2D

## Layers: 1 world/breakables · 2 player · 4 enemies · 8 projectiles

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var damage: float = 10.0
var from_player: bool = true
var lifetime: float = 1.1
## Who fired — used to ignore self-hits and for pet enrage attribution.
var source: Node = null
var splash_radius: float = 0.0
var splash_mult: float = 0.5
## Look: rocket / slug / tracer / smg / pistol / drone (player); enemy shots ignore it.
var style: String = "pistol"
var crit: bool = false
## Phase 4: tag for the hero's hit pipeline (main / drone / chain / vial),
## pierce + ricochet counts, special-ammo look, Vesper's vial burst.
var src_tag: String = "main"
var pierce_left: int = 0
var pierce_falloff: float = 0.8
var bounces_left: int = 0
var bounce_mult: float = 0.6
var bounce_range: float = 220.0
var ammo: String = ""
var vial: bool = false
## Knockback per bullet hit (small flinch; melee/rockets bring their own).
var knock: float = 30.0
## Lock-on: player shots steer toward their target (turn rate in rad/s).
var homing_target: Node2D = null
var homing_turn: float = 0.0
var _hit_set: Array = []

## Per-style look (pixel strips in assets/sprites/fx/px, tools/gen_fx_px.py):
## projectile strip, tail colour (palette) + width/length in texels.
const STYLES := {
	"rocket": {"px": "pj_rocket", "tail": Color("e88a1c"), "w": 0.0, "len": 0, "smoke": true},
	"slug": {"px": "pj_slug", "tail": Color("57932f"), "w": 2.0, "len": 5},
	"tracer": {"px": "pj_tracer", "tail": Color("e88a1c"), "w": 2.0, "len": 5},
	"smg": {"px": "pj_smg", "tail": Color("ffc040"), "w": 1.0, "len": 3},
	"pistol": {"px": "pj_pistol", "tail": Color("e9dfc9"), "w": 1.0, "len": 4},
	"drone": {"px": "pj_drone", "tail": Color("5cd2c0"), "w": 1.0, "len": 4},
	"vial": {"px": "pj_vial", "tail": Color("9ccf3e"), "w": 1.0, "len": 6, "spin": 14.0},
}
const AMMO_PX := {"incendiary": "pj_incendiary", "shock": "pj_shock", "frost": "pj_frost", "explosive": "pj_explosive"}
const AMMO_TAIL := {"incendiary": Color("e88a1c"), "shock": Color("5cd2c0"), "frost": Color("9aa8ad"), "explosive": Color("ad5a2a")}
var _smoke_t: float = 0.0
var _smoke_on: bool = false
var _px_n: int = 1
var _px_t: float = 0.0
var _max_pts: int = 5
var _spin: float = 0.0

@onready var sprite: Sprite2D = $Sprite

var _trail: Line2D
var _hit: bool = false
var _arm_left: float = 0.04 ## brief spawn grace so muzzle overlap can't self-hit


func setup(
	origin: Vector2,
	dir: Vector2,
	spd: float,
	dmg: float,
	player_shot: bool,
	src: Node = null,
	life: float = -1.0,
	splash_r: float = 0.0,
	splash_m: float = 0.5
) -> void:
	global_position = origin
	direction = dir.normalized()
	speed = spd
	damage = dmg
	from_player = player_shot
	source = src
	splash_radius = splash_r
	splash_mult = splash_m
	rotation = direction.angle()
	## Enemy bullets live longer but are slower — readable and dodgeable.
	if life > 0.0:
		lifetime = life
	else:
		lifetime = 1.0 if player_shot else 1.8
	## Set masks before enter-tree so the first overlap uses the right team.
	_apply_team_collision()


func _apply_team_collision() -> void:
	collision_layer = 8
	if from_player:
		## World + enemies only — never the player layer (2).
		collision_mask = 1 | 4
	else:
		## World + player only.
		collision_mask = 1 | 2


func _ready() -> void:
	_apply_team_collision()
	body_entered.connect(_on_body_entered)
	var look: Dictionary = STYLES.get(style, STYLES["pistol"]) if from_player else {}
	var px_id := str(look.get("px", "pj_pistol"))
	var tail: Color = look.get("tail", Color("e9dfc9"))
	if from_player and ammo != "" and not vial and AMMO_PX.has(ammo) and style != "rocket":
		## Special ammo: its own round + tail colour (rockets keep their body).
		px_id = AMMO_PX[ammo]
		tail = AMMO_TAIL[ammo]
	elif not from_player:
		var fac: Variant = source.get("faction") if source != null and is_instance_valid(source) else null
		px_id = "pj_spit" if str(fac) == "plague" else "pj_enemy"
		tail = Color("ff4836")
		look = {"w": 2.0, "len": 5}
	_dress_sprite(px_id)
	_trail = Line2D.new()
	_trail.width = float(look.get("w", 1.0)) * UnitAnim.TEXEL
	_trail.top_level = true
	_trail.z_index = 4
	_trail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_trail.gradient = _tail_gradient(tail)
	_max_pts = int(look.get("len", 5))
	_trail.visible = float(look.get("w", 0.0)) > 0.0
	add_child(_trail)
	_smoke_on = from_player and bool(look.get("smoke", false))
	_spin = float(look.get("spin", 0.0)) if from_player else 0.0


## Hard tail: four alpha steps toward the round, no soft glow. One shared
## Gradient per tail colour (every shot used to build its own).
static var _grad_cache: Dictionary = {}

static func _tail_gradient(tail: Color) -> Gradient:
	var key := tail.to_rgba32()
	if _grad_cache.has(key):
		return _grad_cache[key]
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.set_color(0, Color(tail, 0.25))
	g.set_offset(1, 0.75)
	g.set_color(1, Color(tail, 1.0))
	g.add_point(0.25, Color(tail, 0.5))
	g.add_point(0.5, Color(tail, 0.75))
	_grad_cache[key] = g
	return g


## Projectile strip on the Sprite child: texel scale, anchored at the round's head.
func _dress_sprite(id: String) -> void:
	if sprite == null:
		return
	var info: Dictionary = Juice.px.call("info", id) if Juice.px else {}
	var path := "res://assets/sprites/fx/px/%s.png" % id
	if info.is_empty() or not ResourceLoader.exists(path):
		if sprite.texture == null:
			sprite.texture = load("res://assets/sprites/props/bullet.png")
		return
	sprite.texture = load(path)
	_px_n = int(info.get("n", 1))
	sprite.hframes = _px_n
	sprite.frame = 0
	sprite.centered = true
	sprite.offset = Vector2(float(info["w"]) * 0.5 - float(info["ox"]), float(info["h"]) * 0.5 - float(info["oy"]))
	sprite.scale = Vector2.ONE * UnitAnim.TEXEL
	sprite.modulate = Color.WHITE
	sprite.material = null
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(delta: float) -> void:
	if _hit:
		return
	if _arm_left > 0.0:
		_arm_left -= delta
		if _arm_left <= 0.0 and from_player and monitoring:
			## Spawned already touching a crate (point blank): body_entered fired
			## during the arm grace and was ignored, so resolve it now.
			for b in get_overlapping_bodies():
				if b.is_in_group("breakables"):
					_on_body_entered(b)
					if _hit:
						return
	if homing_turn > 0.0 and homing_target != null and is_instance_valid(homing_target) and not homing_target.is_queued_for_deletion():
		var want := homing_target.global_position - global_position
		if want.length() > 4.0:
			var diff := direction.angle_to(want)
			var step := clampf(diff, -homing_turn * delta, homing_turn * delta)
			direction = direction.rotated(step).normalized()
			rotation = direction.angle()
	global_position += direction * speed * delta
	if _spin != 0.0 and sprite:
		sprite.rotation += _spin * delta
	_trail.add_point(global_position)
	while _trail.get_point_count() > _max_pts:
		_trail.remove_point(0)
	if _px_n > 1 and sprite:
		_px_t += delta
		sprite.frame = int(_px_t * 12.0) % _px_n
	## Rocket: pixel smoke puffs (ASH / BONE, 4 alpha steps) every ~30 ms.
	if _smoke_on:
		_smoke_t -= delta
		if _smoke_t <= 0.0:
			_smoke_t = 0.03
			Juice.fx("smoke_puff", global_position - direction * 9.0 + Vector2(randf_range(-1, 1), randf_range(-1, 1)))
	lifetime -= delta
	if lifetime <= 0.0:
		_fizzle()


func _is_friendly(body: Node) -> bool:
	if body == null:
		return true
	if source != null and is_instance_valid(source) and body == source:
		return true
	if from_player:
		return body.is_in_group("player") or body.is_in_group("pets")
	## Enemy shots shouldn't hurt other enemies.
	return body.is_in_group("enemies")


func _on_body_entered(body: Node2D) -> void:
	if _hit or _arm_left > 0.0:
		return
	if _is_friendly(body):
		return
	## Walls / props never stopped shots (the bullet couldn't see static bodies
	## until it became monitorable) — keep that feel: only crates catch rounds.
	if (body is StaticBody2D or body is TileMap) and not body.is_in_group("breakables"):
		return

	if from_player:
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			if body in _hit_set:
				return
			_hit_set.append(body)
			homing_target = null
			## Through the hero's hit pipeline (on-hit upgrades / special ammo).
			if source != null and is_instance_valid(source) and source.has_method("hit_enemy"):
				source.call("hit_enemy", body, damage, direction, knock, crit, src_tag)
			else:
				body.take_damage(damage, direction, knock, crit)
			_apply_splash(body)
			if pierce_left > 0:
				## Piercing Slugs: keep flying, a little weaker.
				pierce_left -= 1
				damage *= pierce_falloff
				Juice.fx_impact(global_position, "spark")
				return
			if ammo != "" and not vial:
				Juice.fx_impact(global_position, ammo)
			if bounces_left > 0 and _bounce():
				return
			_impact(Color(1, 0.85, 0.45), "")
		elif body.is_in_group("breakables") and body.has_method("take_damage"):
			body.take_damage(damage)
			_apply_splash(body)
			_impact(Color(1, 0.85, 0.45), "prop")
		elif body is StaticBody2D or body is TileMap:
			_apply_splash(null)
			_impact(Color(0.8, 0.7, 0.55), "ground")
	else:
		if body.is_in_group("player"):
			if body.has_method("is_dashing") and body.is_dashing():
				return  ## dashed through it
			if body.has_method("take_damage"):
				## Player signature: (float, Node attacker)
				var attacker: Node = source if source != null and is_instance_valid(source) else null
				body.take_damage(damage, attacker)
			_impact(Color(1, 0.35, 0.25), "spark")
		elif body is StaticBody2D or body is TileMap:
			_impact(Color(0.8, 0.7, 0.55), "ground")


func _apply_splash(primary: Node) -> void:
	if splash_radius <= 0.0 or not from_player:
		return
	Juice.sfx_at("boom_rook", global_position)
	LightFx.flash(get_parent(), global_position, splash_radius * 2.6, Color(1.0, 0.58, 0.22, 0.7), 0.3)
	var tree := get_tree()
	if tree == null:
		return
	var splash_dmg := damage * splash_mult * GameState.aoe_damage_mult()
	var r2 := splash_radius * splash_radius
	for n in tree.get_nodes_in_group("enemies"):
		if n == primary or not is_instance_valid(n):
			continue
		if not (n is Node2D) or not n.has_method("take_damage"):
			continue
		var other := n as Node2D
		if global_position.distance_squared_to(other.global_position) > r2:
			continue
		var kdir := (other.global_position - global_position).normalized()
		if kdir.length_squared() < 0.01:
			kdir = direction
		other.take_damage(splash_dmg, kdir)
	for n in tree.get_nodes_in_group("breakables"):
		if n == primary or not is_instance_valid(n):
			continue
		if not (n is Node2D) or not n.has_method("take_damage"):
			continue
		var crate := n as Node2D
		if global_position.distance_squared_to(crate.global_position) > r2:
			continue
		crate.take_damage(splash_dmg)


## Ricochet Rounds: redirect to the nearest enemy not yet hit.
func _bounce() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var nxt := RunFx.nearest_enemy(tree, global_position, bounce_range, _hit_set)
	if nxt == null:
		return false
	bounces_left -= 1
	damage *= bounce_mult
	direction = (nxt.global_position - global_position).normalized()
	rotation = direction.angle()
	lifetime = maxf(lifetime, bounce_range / maxf(speed, 1.0) + 0.1)
	src_tag = "chain"
	Juice.fx_impact(global_position, "spark")
	return true


## material "" = the enemy's own hit fx already played (take_damage).
func _impact(_col: Color, material: String = "") -> void:
	_hit = true
	if vial and from_player and source != null and is_instance_valid(source) and source.has_method("vial_burst"):
		source.call("vial_burst", global_position)
	if splash_radius > 0.0 and from_player:
		## Rocket splash: pixel blast + scorch decal.
		Juice.fx_explosion(global_position, splash_radius)
		Juice.shake(0.06)
	elif material != "":
		Juice.fx_impact(global_position, material)
	_cleanup()


func _fizzle() -> void:
	_hit = true
	if vial and from_player and source != null and is_instance_valid(source) and source.has_method("vial_burst"):
		source.call("vial_burst", global_position)
	_cleanup()


func _cleanup() -> void:
	set_deferred("monitoring", false)
	if sprite:
		sprite.visible = false
	_smoke_on = false
	var tw := _trail.create_tween()
	tw.tween_property(_trail, "modulate:a", 0.0, 0.08)
	tw.tween_callback(queue_free)
