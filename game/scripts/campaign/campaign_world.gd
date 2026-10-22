extends "res://scripts/world/wasteland_world.gd"

## Handcrafted campaign map: the wasteland's ground, decals and props, but the
## LAYOUT comes from the level def (fixed seed, authored set pieces / props /
## landmarks / roads, a walled boundary with a Dust wall beyond it). Nothing is
## random between attempts: same seed, same map.

var level: Dictionary = {}
var bounds: Rect2 = Rect2(-1400, -1400, 2800, 2800)
## Persistent authored props (landmark art, edge dressing): not chunk-bound.
var _fixed: Node2D
## Areas kept free of scatter (objective spots): [Vector2, r].
var _clear_zones: Array = []
const EDGE_KINDS := ["rock_large", "rubble_chunk", "barrier_scrap", "tire_stack", "scrap_pile", "rock_huge", "sandbags"]
const WALL_T := 400.0


func setup(p_seed: int, player: Node2D) -> void:
	bounds = level.get("bounds", bounds)
	for z in level.get("clear", []):
		_clear_zones.append([Vector2(float(z[0]), float(z[1])), float(z[2])])
	for o in level.get("objectives", []):
		if (o as Dictionary).has("at"):
			_clear_zones.append([o["at"], float((o as Dictionary).get("r", 90.0)) + 40.0])
	super.setup(p_seed, player)
	_fixed = Node2D.new()
	_fixed.name = "Fixed"
	_fixed.y_sort_enabled = true
	add_child(_fixed)
	for p in level.get("props", []):
		place_prop(str(p[0]), Vector2(float(p[1]), float(p[2])))
	for f in level.get("fires", []):
		LightFx.fire(_fixed, snap(Vector2(float(f[0]), float(f[1]))), float(f[2]) if (f as Array).size() > 2 else 1.0)
	_build_bounds()


## Authored landmarks + roads replace the random catalog.
func _build_landmark_catalog() -> void:
	landmarks.clear()
	for lm in level.get("landmarks", []):
		landmarks.append({"name": str(lm.get("name", "")), "position": lm["pos"], "kind": int(lm.get("kind", 0))})
	var rs: Array[Dictionary] = []
	for line in level.get("roads", []):
		var pts := PackedVector2Array()
		for q in line:
			pts.append(q)
		var offs := PackedFloat32Array()
		var acc := 0.0
		for k in range(pts.size()):
			if k > 0:
				acc += pts[k].distance_to(pts[k - 1])
			offs.append(acc)
		rs.append({"pts": pts, "off": offs})
	field.roads = rs


## Prop art lookup also covers the landmark art (depth/world/<name>.png).
func _tex(kind: String) -> Texture2D:
	if kind.begins_with("world/"):
		if _tex_cache.has(kind):
			return _tex_cache[kind]
		var p := "res://assets/sprites/depth/%s.png" % kind
		var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
		_tex_cache[kind] = t
		return t
	return super._tex(kind)


## Only the level's own set pieces, placed where the level says (no random sets).
func _populate_sets(chunk: Node2D, coord: Vector2i, _segs: Array[Dictionary], decals: Array) -> void:
	var r := Rect2(chunk.position, Vector2(CHUNK_SIZE, CHUNK_SIZE))
	var i := 0
	for e in level.get("sets", []):
		i += 1
		var at := Vector2(float(e[1]), float(e[2]))
		if not r.has_point(at) or not SETS.has(str(e[0])):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = int(level.get("seed", 1)) * 31 + i * 977
		_build_set(chunk, str(e[0]), at, rng, decals)
	for c in level.get("crates", []):
		var cp := Vector2(float(c[0]), float(c[1]))
		if r.has_point(cp):
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = int(cp.x) * 7 + int(cp.y) * 13
			_place_crate(chunk, cp - chunk.position, rng2)


## Scatter stays out of objective spots and off the far side of the wall.
func clear_at(p: Vector2, r: float) -> bool:
	for z in _clear_zones:
		if (z[0] as Vector2).distance_to(p) < float(z[1]) + r * 0.5:
			return false
	return super.clear_at(p, r)


## One persistent prop (landmark art included). Standing art is y-sorted with
## the units and blocks along its base; flat pieces don't.
func place_prop(kind: String, at: Vector2) -> Node2D:
	var tex := _tex(kind)
	if tex == null:
		return null
	var holder := Node2D.new()
	holder.position = Vector2.ZERO
	holder.y_sort_enabled = true
	_fixed.add_child(holder)
	var sp := prop_sprite(kind, tex, snap(at))
	sp.z_index = 0 if not PropMeta.info(kind).get("flat", false) else -5
	var foot_w := float(tex.get_width()) * UnitAnim.TEXEL
	if kind.begins_with("world/"):
		## Landmark art: block a band along the base, shadow under it.
		var h := float(tex.get_height()) * UnitAnim.TEXEL
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = snap(at)
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(foot_w * 0.66, 22.0)
		cs.shape = shape
		cs.position = Vector2(0, h * 0.5 - 18.0)
		body.add_child(cs)
		holder.add_child(body)
		var s := Sprite2D.new()
		s.texture = UnitAnim.pixel_shadow_tex(int(round(foot_w * 0.7 / UnitAnim.TEXEL)), 14)
		s.scale = Vector2.ONE * UnitAnim.TEXEL
		s.position = snap(at) + Vector2(2, h * 0.5 - 6.0)
		s.z_index = -6
		holder.add_child(s)
	else:
		add_prop_shadow(holder, kind, snap(at))
		if blocks(kind):
			add_prop_block(holder, kind, snap(at))
	holder.add_child(sp)
	return holder


## The map's edge: a solid wall just outside the bounds, rubble dressing along
## it, and the Dust beyond (4 alpha steps, bible §1.5).
func _build_bounds() -> void:
	var b := bounds
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	for r in [Rect2(b.position.x - WALL_T, b.position.y - WALL_T, b.size.x + WALL_T * 2.0, WALL_T),
			Rect2(b.position.x - WALL_T, b.end.y, b.size.x + WALL_T * 2.0, WALL_T),
			Rect2(b.position.x - WALL_T, b.position.y, WALL_T, b.size.y),
			Rect2(b.end.x, b.position.y, WALL_T, b.size.y)]:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = (r as Rect2).size
		cs.shape = sh
		cs.position = (r as Rect2).get_center()
		walls.add_child(cs)
	add_child(walls)
	## Rubble along the edge (deterministic), sitting on the boundary line.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1)) * 101 + 7
	var step := 150.0
	var edges := [[b.position, Vector2(b.end.x, b.position.y)], [Vector2(b.position.x, b.end.y), b.end],
		[b.position, Vector2(b.position.x, b.end.y)], [Vector2(b.end.x, b.position.y), b.end]]
	for e in edges:
		var a: Vector2 = e[0]
		var z: Vector2 = e[1]
		var n := int(a.distance_to(z) / step)
		for k in range(n + 1):
			var p := a.lerp(z, float(k) / maxf(1.0, float(n))) + Vector2(rng.randf_range(-24, 24), rng.randf_range(-16, 16))
			var kind: String = EDGE_KINDS[rng.randi() % EDGE_KINDS.size()]
			var tex := _tex(kind)
			if tex == null:
				continue
			var sp := prop_sprite(kind, tex, snap(p))
			sp.z_index = 0
			_fixed.add_child(sp)
	var fog := _DustWall.new()
	fog.bounds = b
	fog.col = ZoneDefs.ground_colors(_grade)[0]
	fog.z_index = 60
	add_child(fog)


func in_bounds(p: Vector2, margin: float = 60.0) -> bool:
	return bounds.grow(-margin).has_point(p)


## Dust beyond the map edge: bands at 25 / 50 / 75 / 100 %.
class _DustWall extends Node2D:
	var bounds: Rect2
	var col: Color = Color("433428")

	func _draw() -> void:
		var steps := [[0.0, 0.25], [48.0, 0.5], [96.0, 0.75], [144.0, 1.0]]
		var far := 3000.0
		for i in range(steps.size()):
			var o: float = steps[i][0]
			var o2: float = steps[i + 1][0] if i + 1 < steps.size() else far
			var c := Color(col.darkened(0.35), float(steps[i][1]))
			var outer := bounds.grow(o2)
			var inner := bounds.grow(o)
			draw_rect(Rect2(outer.position.x, outer.position.y, outer.size.x, inner.position.y - outer.position.y), c)
			draw_rect(Rect2(outer.position.x, inner.end.y, outer.size.x, outer.end.y - inner.end.y), c)
			draw_rect(Rect2(outer.position.x, inner.position.y, inner.position.x - outer.position.x, inner.size.y), c)
			draw_rect(Rect2(inner.end.x, inner.position.y, outer.end.x - inner.end.x, inner.size.y), c)
