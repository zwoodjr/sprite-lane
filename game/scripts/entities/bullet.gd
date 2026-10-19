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
var _hit_set: Array = []

## Per-style look: sprite tint/scale, trail colour/width/length, glow texture.
const STYLES := {
	"rocket": {"color": Color(1.0, 0.62, 0.25), "scale": Vector2(0.55, 0.55), "trail": 4.0, "len": 6, "tex": "res://assets/sprites/fx/bullet_explosive.png", "smoke": true},
	"slug": {"color": Color(0.55, 1.0, 0.35), "scale": Vector2(1.7, 0.75), "trail": 3.0, "len": 7, "tex": ""},
	"tracer": {"color": Color(1.0, 0.72, 0.25), "scale": Vector2(0.9, 0.9), "trail": 2.5, "len": 6, "tex": "res://assets/sprites/fx/tracer_standard.png"},
	"smg": {"color": Color(1.0, 0.9, 0.55), "scale": Vector2(0.55, 0.55), "trail": 1.5, "len": 3, "tex": ""},
	"pistol": {"color": Color(1.0, 0.95, 0.75), "scale": Vector2(0.8, 0.8), "trail": 2.0, "len": 4, "tex": ""},
	"drone": {"color": Color(0.45, 1.0, 0.85), "scale": Vector2(0.6, 0.6), "trail": 1.5, "len": 4, "tex": ""},
	"vial": {"color": Color(0.55, 1.0, 0.3), "scale": Vector2(0.42, 0.42), "trail": 5.0, "len": 9, "tex": "res://assets/sprites/pickups/tonic_small.png", "spin": 14.0},
}
var _smoke: CPUParticles2D

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
	if sprite and sprite.texture == null:
		sprite.texture = load("res://assets/sprites/props/bullet.png")
	var look: Dictionary = (STYLES.get(style, STYLES["pistol"]) as Dictionary).duplicate() if from_player else {}
	if from_player and ammo != "" and not vial and UpgradeDefs.AMMO.has(ammo):
		## Special ammo: its own round + trail colour (rockets keep their body).
		var a: Dictionary = UpgradeDefs.AMMO[ammo]
		look["color"] = a["color"]
		if style != "rocket":
			look["tex"] = a["bullet"]
			look["scale"] = Vector2(0.75, 0.75)
	var col: Color = look.get("color", Color(1.0, 0.88, 0.4)) if from_player else Color(1.0, 0.32, 0.22)
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if sprite:
		if from_player:
			var tex_path := str(look.get("tex", ""))
			if tex_path != "" and ResourceLoader.exists(tex_path):
				sprite.texture = load(tex_path)
				sprite.modulate = Color(1, 1, 1)
			else:
				sprite.modulate = col * 1.5
			sprite.scale = look.get("scale", Vector2.ONE)
			if style != "rocket":
				sprite.material = glow
		else:
			## Slightly larger enemy shots so they read against dust at survivor FOV.
			sprite.scale = Vector2(1.25, 1.25)
			sprite.modulate = col * 1.4
	_trail = Line2D.new()
	_trail.width = float(look.get("trail", 3.0)) if from_player else 5.0
	_trail.top_level = true
	_trail.z_index = 4
	_trail.material = glow
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.set_color(1, Color(col.r, col.g, col.b, 0.75))
	_trail.gradient = g
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail)
	if from_player and bool(look.get("smoke", false)):
		_smoke = CPUParticles2D.new()
		_smoke.amount = 24
		_smoke.lifetime = 0.5
		_smoke.local_coords = false
		_smoke.direction = -direction
		_smoke.spread = 18.0
		_smoke.gravity = Vector2(0, -20)
		_smoke.initial_velocity_min = 10.0
		_smoke.initial_velocity_max = 30.0
		_smoke.scale_amount_min = 3.0
		_smoke.scale_amount_max = 6.0
		var sg := Gradient.new()
		sg.set_color(0, Color(0.75, 0.7, 0.65, 0.6))
		sg.set_color(1, Color(0.5, 0.48, 0.45, 0.0))
		_smoke.color_ramp = sg
		_smoke.z_index = 3
		add_child(_smoke)


func _physics_process(delta: float) -> void:
	if _hit:
		return
	if _arm_left > 0.0:
		_arm_left -= delta
	global_position += direction * speed * delta
	if sprite and from_player and STYLES.has(style) and (STYLES[style] as Dictionary).has("spin"):
		sprite.rotation += float(STYLES[style]["spin"]) * delta
	_trail.add_point(global_position)
	var max_pts := int((STYLES.get(style, {}) as Dictionary).get("len", 5)) if from_player else 7
	while _trail.get_point_count() > max_pts:
		_trail.remove_point(0)
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

	if from_player:
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			if body in _hit_set:
				return
			_hit_set.append(body)
			## Through the hero's hit pipeline (on-hit upgrades / special ammo).
			if source != null and is_instance_valid(source) and source.has_method("hit_enemy"):
				source.call("hit_enemy", body, damage, direction, -1.0, crit, src_tag)
			else:
				body.take_damage(damage, direction, -1.0, crit)
			_apply_splash(body)
			if pierce_left > 0:
				## Piercing Slugs: keep flying, a little weaker.
				pierce_left -= 1
				damage *= pierce_falloff
				Juice.burst(global_position, Color(1, 0.85, 0.45), 4, 120.0, 0.2, 0.7)
				return
			if bounces_left > 0 and _bounce():
				return
			_impact(Color(1, 0.85, 0.45))
		elif body.is_in_group("breakables") and body.has_method("take_damage"):
			body.take_damage(damage)
			_apply_splash(body)
			_impact(Color(1, 0.85, 0.45))
		elif body is StaticBody2D or body is TileMap:
			_apply_splash(null)
			_impact(Color(0.8, 0.7, 0.55))
	else:
		if body.is_in_group("player"):
			if body.has_method("is_dashing") and body.is_dashing():
				return  ## dashed through it
			if body.has_method("take_damage"):
				## Player signature: (float, Node attacker)
				var attacker: Node = source if source != null and is_instance_valid(source) else null
				body.take_damage(damage, attacker)
			_impact(Color(1, 0.35, 0.25))
		elif body is StaticBody2D or body is TileMap:
			_impact(Color(0.8, 0.7, 0.55))


func _apply_splash(primary: Node) -> void:
	if splash_radius <= 0.0 or not from_player:
		return
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
		var knock := (other.global_position - global_position).normalized()
		if knock.length_squared() < 0.01:
			knock = direction
		other.take_damage(splash_dmg, knock)
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
	Juice.burst(global_position, Color(1, 0.9, 0.6), 6, 140.0, 0.2, 0.8)
	return true


func _impact(col: Color) -> void:
	_hit = true
	if vial and from_player and source != null and is_instance_valid(source) and source.has_method("vial_burst"):
		source.call("vial_burst", global_position)
	if splash_radius > 0.0 and from_player:
		## Small blast ring for the rocket splash.
		Juice.burst(global_position, Color(1.0, 0.55, 0.2), 16, 260.0, 0.3, 1.6)
		Juice.burst(global_position, Color(0.5, 0.45, 0.4, 0.7), 10, 90.0, 0.6, 2.2)
		Juice.shake(0.06)
	var amount := 10 if splash_radius > 0.0 else 6
	var spd := 180.0 if splash_radius > 0.0 else 140.0
	Juice.burst(global_position, col, amount, spd, 0.28, 1.1 if splash_radius > 0.0 else 0.8)
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
	if _smoke:
		_smoke.emitting = false
	var tw := _trail.create_tween()
	tw.tween_property(_trail, "modulate:a", 0.0, 0.3 if _smoke else 0.08)
	tw.tween_callback(queue_free)
