class_name RunFx
extends RefCounted

## Shared helpers for Phase 4 upgrade / ability / ammo effects: AoE blasts,
## electric zaps, rings, sprite-sheet one-shots and the deployables.

const PickupScene := preload("res://scenes/entities/powerup_pickup.tscn")
const GROUND_FX := "res://scripts/entities/ground_fx.gd"
const MINE := "res://scripts/entities/spore_mine.gd"
const CRATE := "res://scripts/entities/supply_crate.gd"
const ENEMY_BODY_R := 16.0


## Slice a horizontal strip into frames (frame width = height × aspect).
static func frames(path: String, n: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if not ResourceLoader.exists(path):
		return out
	var tex := load(path) as Texture2D
	var fw := tex.get_width() / maxi(1, n)
	for i in range(n):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, tex.get_height())
		out.append(at)
	return out


## Enemies whose body overlaps a circle (centre-to-edge distance).
static func enemies_in(tree: SceneTree, pos: Vector2, radius: float) -> Array:
	var out: Array = []
	for n in tree.get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n) or not n.has_method("take_damage"):
			continue
		var e := n as Node2D
		var br := ENEMY_BODY_R * float(e.get("body_scale") if "body_scale" in e else 1.0)
		if pos.distance_to(e.global_position) - br <= radius:
			out.append(e)
	return out


## Crates / wrecks caught in a blast or ram take the hit too.
static func damage_breakables(tree: SceneTree, pos: Vector2, radius: float, dmg: float, skip: Array = []) -> Array:
	var out: Array = []
	if tree == null:
		return out
	for n in tree.get_nodes_in_group("breakables"):
		if n in skip or not (n is Node2D) or not is_instance_valid(n) or not n.has_method("take_damage"):
			continue
		if pos.distance_to((n as Node2D).global_position) - 16.0 <= radius:
			n.call("take_damage", dmg)
			out.append(n)
	return out


static func nearest_enemy(tree: SceneTree, pos: Vector2, radius: float, skip: Array = []) -> Node2D:
	var best: Node2D = null
	var bd := radius
	for n in tree.get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n) or n in skip:
			continue
		var d := pos.distance_to((n as Node2D).global_position)
		if d < bd:
			bd = d
			best = n
	return best


## Damage every enemy in radius through the hero's hit pipeline (on-hit
## upgrades / ammo apply). `src` "blast" never re-triggers explosive ammo.
static func explosion(player: Node2D, pos: Vector2, radius: float, dmg: float, color: Color, src: String = "blast", knock: float = 260.0, stun: float = 0.0) -> int:
	if player == null or not is_instance_valid(player):
		return 0
	var tree := player.get_tree()
	var hits := 0
	if src != "mine":
		Juice.sfx_at("explosion", pos, -2.0 if radius < 100.0 else 0.0)
	for e in enemies_in(tree, pos, radius):
		var dir: Vector2 = ((e as Node2D).global_position - pos).normalized()
		player.call("hit_enemy", e, dmg, dir, knock, false, src)
		if stun > 0.0 and is_instance_valid(e) and e.has_method("apply_status"):
			e.call("apply_status", "stun", stun)
		hits += 1
	damage_breakables(tree, pos, radius, dmg)
	ring(player.get_parent(), pos, radius, color, 0.32)
	LightFx.flash(player.get_parent(), pos, radius * 2.4, Color(1.0, 0.6, 0.25, 0.7), 0.35)
	Juice.burst(pos, color, 18, radius * 2.6, 0.35, 1.5)
	Juice.burst(pos, Color(0.5, 0.45, 0.4, 0.7), 8, radius, 0.6, 2.0)
	return hits


## Expanding ground ring (squashed for the 3/4 view).
static func ring(parent: Node, pos: Vector2, radius: float, color: Color, life: float = 0.3, width: float = 5.0) -> void:
	if parent == null:
		return
	var l := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(33):
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a), sin(a) * 0.6) * radius)
	l.points = pts
	l.width = width
	l.default_color = color
	l.global_position = pos
	l.z_index = 3
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l.material = add
	l.scale = Vector2(0.35, 0.35)
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, life).set_delay(life * 0.4)
	tw.chain().tween_callback(l.queue_free)


## Jagged electric arc between two points.
static func zap(parent: Node, a: Vector2, b: Vector2, color: Color = Color(0.55, 0.85, 1.0), life: float = 0.22, width: float = 3.0) -> void:
	if parent == null:
		return
	var l := Line2D.new()
	var pts := PackedVector2Array()
	var seg := 7
	var nrm := (b - a).orthogonal().normalized()
	for i in range(seg + 1):
		var t := float(i) / seg
		var jitter := 0.0 if i == 0 or i == seg else randf_range(-10.0, 10.0)
		pts.append(a.lerp(b, t) + nrm * jitter)
	l.points = pts
	l.width = width
	l.default_color = color * 1.4
	l.z_index = 6
	l.top_level = true
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l.material = add
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, life)
	tw.tween_callback(l.queue_free)


## Play a sprite strip once at pos (world_size = on-screen frame width).
static func sheet_once(parent: Node, path: String, n: int, pos: Vector2, world_size: float, fps: float = 14.0, tint: Color = Color.WHITE, additive: bool = true) -> void:
	var fr := frames(path, n)
	if fr.is_empty() or parent == null:
		return
	var s := Sprite2D.new()
	s.texture = fr[0]
	s.global_position = pos
	s.z_index = 6
	s.modulate = tint
	s.scale = Vector2.ONE * (world_size / float(fr[0].get_width()))
	if additive:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = add
	parent.add_child(s)
	var tw := s.create_tween()
	for i in range(1, fr.size()):
		tw.tween_interval(1.0 / fps)
		tw.tween_callback(func() -> void: s.texture = fr[i])
	tw.tween_interval(1.0 / fps)
	tw.tween_property(s, "modulate:a", 0.0, 0.12)
	tw.tween_callback(s.queue_free)


## Lingering ground patch: mode "burn" (fire trail), "heal" (Sanctuary),
## "poison" (vial cloud). Ticks apply statuses / healing.
static func ground(parent: Node, player: Node2D, pos: Vector2, mode: String, radius: float, life: float, value: float) -> Node2D:
	var g := Node2D.new()
	g.set_script(load(GROUND_FX))
	g.set("mode", mode)
	g.set("radius", radius)
	g.set("life", life)
	g.set("value", value)
	g.set("player", player)
	g.position = pos
	parent.add_child(g)
	return g


static func spore_mine(parent: Node, player: Node2D, pos: Vector2) -> Node2D:
	var m := Node2D.new()
	m.set_script(load(MINE))
	m.set("player", player)
	m.position = pos
	parent.add_child(m)
	return m


static func supply_crate(parent: Node, pos: Vector2) -> Node2D:
	var c := Node2D.new()
	c.set_script(load(CRATE))
	c.position = pos
	parent.add_child(c)
	return c


static func random_ammo_id() -> String:
	var keys := UpgradeDefs.AMMO.keys()
	return str(keys[randi() % keys.size()])


## Ammo Bench pickups: only the types the bench rank allows ("" = none).
static func random_bench_ammo_id() -> String:
	var types: Array = GameState.ammo_pickup_types() if GameState else []
	if types.is_empty():
		return ""
	return str(types[randi() % types.size()])


static func ammo_def(ammo_id: String) -> Dictionary:
	var a: Dictionary = UpgradeDefs.AMMO.get(ammo_id, UpgradeDefs.AMMO["incendiary"])
	return {
		"id": "ammo", "ammo": ammo_id,
		"name": "%s Ammo" % str(a["name"]),
		"color": a["color"],
		"sprite": a["pickup"],
		"sprite_world": 30.0,
		"duration": UpgradeDefs.AMMO_DURATION + (GameState.ammo_duration_bonus() if GameState else 0.0),
	}


static func spawn_ammo_pickup(parent: Node, pos: Vector2, ammo_id: String = "") -> void:
	if parent == null:
		return
	var p: Area2D = PickupScene.instantiate()
	p.position = pos
	parent.add_child.call_deferred(p)
	p.call_deferred("setup", ammo_def(ammo_id if ammo_id != "" else random_ammo_id()))
