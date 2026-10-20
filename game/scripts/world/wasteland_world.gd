extends Node2D

## Endless-feeling Dust Apothecary wasteland via chunk streaming.
## Chunks load/unload around the player — no nearby hard walls.
## Soft practical limit: unload beyond LOAD_RADIUS; world coords are unbounded.

signal landmarks_changed(landmarks: Array)

const CHUNK_SIZE := 512
const TILE := 64
const LOAD_RADIUS := 2 ## chunks in each direction (5×5 active)
const LANDMARK_NAMES := ["Scrapyard", "Flood Garage", "Signal Tower", "Neon Market", "Convoy Wreck", "Herb Cache"]

@export var player_path: NodePath

var run_seed: int = 1
var _decor: Array[Texture2D] = []
var landmarks: Array[Dictionary] = [] ## {name, position, kind}
var _loaded: Dictionary = {} ## Vector2i -> Node2D
var _player: Node2D
var _prop_wreck: Texture2D
var _prop_crate: Texture2D
var _prop_tower: Texture2D
var _prop_scrap: Texture2D
var _prop_drum: Texture2D
var _prop_chest: Texture2D
var _prop_vial: Texture2D
var _prop_wall: Texture2D
var _prop_pillar: Texture2D
var _chunks_root: Node2D
var _props_root: Node2D
const BreakableScene := preload("res://scenes/entities/breakable.tscn")
const DecalAtlas := preload("res://scripts/world/decal_atlas.gd")
const GroundShader := preload("res://scripts/world/ground.gdshader")

## Mid-scale landmark props. "block": collision rect size + centre offset from
## the sprite centre (footprint only — most props stay walk-through).
const MID_PROPS := {
	"wreck_car": {},
	"wreck_truck": {"block": Vector2(108, 18), "off": Vector2(0, 12)},
	"wreck_bus": {"block": Vector2(162, 24), "off": Vector2(0, 15)},
	"wall_collapsed": {"block": Vector2(46, 24), "off": Vector2(-26, 3)},
	"sandbags": {"block": Vector2(84, 22), "off": Vector2(0, 4)},
	"fence_broken": {},
	"pole_down": {},
	"barrels_rust": {},
	"crater": {"ground": true},
}
## Biome → [prop, weight] (rolled 0-2 times per chunk).
const BIOME_PROPS := {
	0: [["crater", 25], ["barrels_rust", 20], ["fence_broken", 15], ["wreck_car", 10]],
	1: [["crater", 20], ["barrels_rust", 10], ["wreck_car", 12]],
	2: [["fence_broken", 40], ["barrels_rust", 15], ["sandbags", 10]],
	3: [["wall_collapsed", 45], ["sandbags", 25], ["barrels_rust", 25], ["fence_broken", 15]],
}
## Visual tier: hand-designed debris CLUSTERS with clearings between them
## (replaces the uniform scatter). Each entry: [kind, dx, dy] in world px from
## the cluster anchor; kind is a prop texture name, "@decal" for a floor decal,
## or "crate" for a breakable slot (filled ~55% of the time).
const CLUSTERS := {
	"camp": [["wall_ruin", 0, 0], ["barrels_rust", 92, 22], ["fire", 96, -6], ["scrap_pile", -84, 44], ["tire", 34, 64],
		["@stain", 8, 46], ["@scrap", -30, 70], ["@scrap", 70, 60], ["crate", -10, 96]],
	"sandbag_nest": [["sandbags", 0, 0], ["barrier_scrap", 110, -30], ["scrap_drum", -96, -14], ["bones", 44, 58],
		["@pebbles", -40, 46], ["@stain", 20, 30], ["crate", 120, 40]],
	"boneyard": [["bones", 0, 0], ["rock_large", -72, -14], ["rock_small", 58, 18], ["dead_bush", -26, -60],
		["bones", 70, -40], ["@bones", -40, 40], ["@grass", 30, -20], ["@pebbles", 90, 30]],
	"rock_garden": [["rock_large", 0, 0], ["rock_small", 64, 30], ["rock_small", -54, 34], ["dead_bush", 30, -56],
		["@pebbles", -10, 50], ["@pebbles", 70, 60], ["@grass", -70, -10], ["crate", -110, 20]],
	"ruins": [["ruin_pillar", -50, -12], ["wall_collapsed", 56, 0], ["rock_small", 0, 56], ["scrap_pile", 120, 50],
		["@crack", 10, 70], ["@stain", 40, 40], ["@pebbles", -60, 50], ["crate", -20, 110]],
	"wreck_site": [["wreck_car", 0, 0], ["tire", -96, 40], ["scrap_pile", 92, 46], ["@oil", 10, 40], ["@oil", 60, 70],
		["@tracks", -40, 80], ["@scrap", -50, 60], ["crate", 140, -10]],
	"signpost": [["sign_post", 0, 0], ["tire", 46, 24], ["dead_bush", -50, 12], ["@tracks", 0, 46], ["@grass", 30, -30]],
	"fence_line": [["fence_broken", 0, 0], ["dead_bush", 130, 10], ["rock_small", -120, 16], ["@grass", 60, 30], ["@pebbles", -60, 30]],
	"cactus_patch": [["cactus", 0, 0], ["cactus", 54, 26], ["rock_small", -40, 30], ["@grass", 20, 40], ["@pebbles", 70, 50]],
}
## Biome → [cluster, weight].
const BIOME_CLUSTERS := {
	0: [["camp", 18], ["boneyard", 14], ["rock_garden", 18], ["wreck_site", 10], ["signpost", 10], ["fence_line", 10], ["ruins", 10]],
	1: [["rock_garden", 20], ["boneyard", 20], ["cactus_patch", 25], ["signpost", 10], ["wreck_site", 8]],
	2: [["fence_line", 25], ["rock_garden", 20], ["boneyard", 15], ["camp", 15], ["signpost", 10]],
	3: [["ruins", 30], ["sandbag_nest", 25], ["camp", 25], ["wreck_site", 10]],
}
## Props that block movement (footprint only, at native density via ART_GROW).
const CLUSTER_BLOCK := {
	"wall_ruin": Vector2(60, 18), "sandbags": Vector2(84, 22), "wall_collapsed": Vector2(46, 24), "rock_large": Vector2(34, 16),
}
## Chance a chunk is a clearing (no cluster), else 1-2 clusters.
const CLEARING_CHANCE := 0.26
## Rare foreground occluder (dead bush / grass drawn OVER units), per chunk.
const OCCLUDER_CHANCE := 0.12
## Biome → decal kinds for clusters (repeats = weight).
const BIOME_DECALS := {
	0: ["crack", "crack", "pebbles", "pebbles", "scrap", "stain", "grass"],
	1: ["bones", "pebbles", "pebbles", "pebbles", "grass", "stain"],
	2: ["grass", "grass", "grass", "grass", "pebbles", "bones"],
	3: ["scrap", "scrap", "pebbles", "pebbles", "crack", "oil", "toxic"],
}
const RIVER_DECALS := ["crack", "pebbles", "pebbles", "toxic", "toxic", "bones"]
## Keep blockers off the drop point and landmark/extract spots.
const BLOCK_CLEAR_ORIGIN := 420.0
const BLOCK_CLEAR_LANDMARK := 200.0

var field: GroundField
var _mid_tex: Dictionary = {}
var _atlas: Texture2D
var _ground_tex: Dictionary = {}
## Depth E7: the tier's zone (ground set, props, tint — ZoneDefs).
var zone: Dictionary = {}
var _zone_tex: Dictionary = {}
## Chunks waiting for their one-off floor bake (one per frame, nearest first).
var _bake_queue: Array[WastelandChunk] = []


func setup(p_seed: int, player: Node2D) -> void:
	run_seed = p_seed
	_player = player
	zone = ZoneDefs.zone(GameState.zone_tier())
	_load_textures()
	_chunks_root = Node2D.new()
	_chunks_root.name = "Chunks"
	_chunks_root.z_index = -10
	_chunks_root.modulate = zone.get("tint", Color.WHITE)
	add_child(_chunks_root)
	_props_root = Node2D.new()
	_props_root.name = "Props"
	_props_root.z_index = -5
	add_child(_props_root)
	field = GroundField.new(run_seed)
	_build_landmark_catalog()
	landmarks_changed.emit(landmarks)
	_sync_chunks(true)
	## First frame: bake what the camera sees right away, the rest streams in.
	_bake_queue.sort_custom(func(a: WastelandChunk, b: WastelandChunk) -> bool:
		return a.position.distance_squared_to(_player.global_position) < b.position.distance_squared_to(_player.global_position))
	for i in range(mini(9, _bake_queue.size())):
		_bake_queue.pop_front().bake()


func _load_textures() -> void:
	var grade := str(zone.get("grade", ""))
	for k in ["earth", "sand", "scrub", "rubble", "riverbed", "asphalt"]:
		var zp := "res://assets/sprites/tiles/zones/ground_%s_%s.png" % [k, grade]
		if grade != "" and ResourceLoader.exists(zp):
			_ground_tex[k] = load(zp) as Texture2D
		else:
			_ground_tex[k] = load("res://assets/sprites/tiles/ground_%s.png" % k) as Texture2D
	for zk in zone.get("props", []):
		var zpath := ZoneDefs.PROP_DIR % str(zk)
		if ResourceLoader.exists(zpath):
			_zone_tex[str(zk)] = load(zpath) as Texture2D
	for k in MID_PROPS.keys():
		_mid_tex[k] = prop_tex(str(k))
	_atlas = load("res://assets/sprites/decals/decal_atlas.png") as Texture2D
	_decor.clear()
	for n in [
		"rock_small", "rock_small", "rock_large", "dead_bush", "dead_bush",
		"bones", "tire", "cactus", "sign_post", "scrap_pile",
		"wall_ruin", "barrier_scrap", "ruin_pillar",
	]:
		_decor.append(prop_tex(n))
	_prop_wreck = prop_tex("wreck")
	_prop_crate = prop_tex("herb_crate")
	_prop_tower = prop_tex("signal_tower")
	_prop_scrap = prop_tex("scrap_pile")
	_prop_drum = prop_tex("scrap_drum")
	_prop_chest = prop_tex("apothecary_chest")
	_prop_vial = prop_tex("vial_crate")
	_prop_wall = prop_tex("wall_ruin")
	_prop_pillar = prop_tex("ruin_pillar")


## Painted 2x prop art (tools/paint_pass.py) when it exists, else the original.
static func prop_tex(n: String) -> Texture2D:
	var hd := "res://assets/sprites/props_hd/%s.png" % n
	if ResourceLoader.exists(hd):
		return load(hd) as Texture2D
	return load("res://assets/sprites/props/%s.png" % n) as Texture2D


## World scale for a prop texture (native density, see UnitAnim.prop_scale).
static func prop_scale(tex: Texture2D) -> float:
	return UnitAnim.prop_scale(tex)


func _build_landmark_catalog() -> void:
	## Sparse landmarks across a huge ring — used for extract scatter + minimap.
	landmarks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 9176 + 11
	for i in range(14):
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(900.0, 4200.0)
		var pos := Vector2(cos(ang), sin(ang)) * dist
		## Jitter so they don't form a perfect circle
		pos += Vector2(rng.randf_range(-200, 200), rng.randf_range(-200, 200))
		if pos.length() < 500.0:
			pos = pos.normalized() * 700.0
		landmarks.append({
			"name": LANDMARK_NAMES[i % LANDMARK_NAMES.size()],
			"position": pos,
			"kind": i % 4, ## 0 wreck field, 1 garage, 2 tower, 3 market
		})


func get_landmarks() -> Array[Dictionary]:
	return landmarks


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_sync_chunks(false)
	_bake_next()


## Streamed chunks sit 1-2 chunks outside the view, so baking one per frame
## (nearest first) never shows a blank floor and avoids a 5-bake hitch.
func _bake_next() -> void:
	while not _bake_queue.is_empty():
		## Untyped: a queued chunk may already be freed (unloaded while waiting).
		var c: Variant = _bake_queue.pop_front()
		if is_instance_valid(c) and not (c as Node).is_queued_for_deletion():
			(c as WastelandChunk).bake()
			return


func _chunk_coord(world: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world.x / float(CHUNK_SIZE))),
		int(floor(world.y / float(CHUNK_SIZE)))
	)


func _sync_chunks(force: bool) -> void:
	var center := _chunk_coord(_player.global_position)
	var needed: Dictionary = {}
	for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			needed[Vector2i(center.x + dx, center.y + dy)] = true
	## Unload
	var to_drop: Array[Vector2i] = []
	for key in _loaded.keys():
		if not needed.has(key):
			to_drop.append(key)
	for key in to_drop:
		(_loaded[key] as Node).queue_free()
		_loaded.erase(key)
	## Load
	for key in needed.keys():
		if force or not _loaded.has(key):
			if not _loaded.has(key):
				_loaded[key] = _spawn_chunk(key)


func _hash2(cx: int, cy: int, salt: int = 0) -> int:
	var h: int = run_seed
	h = (h ^ int(cx * 374761393)) & 0x7fffffff
	h = (h ^ int(cy * 668265263)) & 0x7fffffff
	h = (h ^ (salt * 1274126177)) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177
	return h & 0x7fffffff


func _spawn_chunk(coord: Vector2i) -> Node2D:
	var chunk := WastelandChunk.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk.position = Vector2(coord.x * CHUNK_SIZE, coord.y * CHUNK_SIZE)
	var rect := Rect2(chunk.position, Vector2(CHUNK_SIZE, CHUNK_SIZE))
	var segs := field.segments_in(rect)
	var decals: Array = []
	chunk.configure(coord, _ground_material(segs, chunk.position), _atlas, decals)
	_chunks_root.add_child(chunk)
	var taken: Array[Vector2] = [] ## world positions of mid props (spacing)
	_populate_road(chunk, coord, segs, decals, taken)
	_populate_clusters(chunk, coord, segs, decals, taken)
	_populate_zone_props(chunk, coord, segs, taken)
	_populate_decals(chunk, coord, segs, decals)
	_maybe_landmark_sprite(chunk, coord)
	_bake_queue.append(chunk)
	return chunk


func _ground_material(segs: Array[Dictionary], origin: Vector2) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GroundShader
	mat.set_shader_parameter("tex_earth", _ground_tex["earth"])
	mat.set_shader_parameter("tex_sand", _ground_tex["sand"])
	mat.set_shader_parameter("tex_scrub", _ground_tex["scrub"])
	mat.set_shader_parameter("tex_rubble", _ground_tex["rubble"])
	mat.set_shader_parameter("tex_river", _ground_tex["riverbed"])
	mat.set_shader_parameter("tex_asphalt", _ground_tex["asphalt"])
	mat.set_shader_parameter("seed_off", field.seed_off)
	mat.set_shader_parameter("chunk_origin", origin)
	mat.set_shader_parameter("road_half", GroundField.ROAD_HALF)
	mat.set_shader_parameter("texel", float(WastelandChunk.CHUNK_SIZE) / float(WastelandChunk.BAKE_PX))
	var sv := PackedVector4Array()
	var so := PackedFloat32Array()
	for s in segs:
		var a: Vector2 = s["a"]
		var b: Vector2 = s["b"]
		sv.append(Vector4(a.x, a.y, b.x, b.y))
		so.append(float(s["off"]))
	while sv.size() < 8:
		sv.append(Vector4(0, 0, 1, 0))
		so.append(0.0)
	mat.set_shader_parameter("road_seg", sv)
	mat.set_shader_parameter("road_off", so)
	mat.set_shader_parameter("road_count", segs.size())
	return mat


func _rng_for(coord: Vector2i, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash2(coord.x, coord.y, salt)
	return rng


func _decal(kind: String, rng: RandomNumberGenerator) -> Rect2:
	var n := 2 if kind in ["oil", "toxic", "tracks", "stain"] else 3
	return DecalAtlas.REGIONS["%s_%d" % [kind, rng.randi() % n]]


## Wrecks and downed power poles along roads, tyre tracks and oil on the asphalt.
func _populate_road(chunk: Node2D, coord: Vector2i, segs: Array[Dictionary], decals: Array, taken: Array[Vector2]) -> void:
	if segs.is_empty():
		return
	var rng := _rng_for(coord, 41)
	var rect := Rect2(chunk.position, Vector2(CHUNK_SIZE, CHUNK_SIZE)).grow(-30.0)
	for s in segs:
		var a: Vector2 = s["a"]
		var b: Vector2 = s["b"]
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		for i in range(3):
			var p := _point_on_seg(a, b, rect, rng)
			if p.x == INF:
				break
			var lat := rng.randf_range(-0.6, 0.6) * GroundField.ROAD_HALF
			decals.append([_decal("tracks", rng), p + nrm * lat - chunk.position, dir.angle(), false, Color(1, 1, 1, rng.randf_range(0.6, 1.0))])
			if rng.randf() < 0.6:
				var q := p + dir * rng.randf_range(-60, 60) + nrm * rng.randf_range(-20, 20)
				decals.append([_decal("oil", rng), q - chunk.position, 0.0, rng.randf() < 0.5, Color.WHITE])
			if rng.randf() < 0.5:
				var q2 := p + nrm * (GroundField.ROAD_HALF + rng.randf_range(4, 22)) * (1.0 if rng.randf() < 0.5 else -1.0)
				decals.append([_decal("scrap" if rng.randf() < 0.6 else "pebbles", rng), q2 - chunk.position, 0.0, rng.randf() < 0.5, Color.WHITE])
		## Abandoned vehicle on the road (sometimes).
		if rng.randf() < 0.42:
			var p := _point_on_seg(a, b, rect.grow(-40.0), rng)
			if p.x != INF:
				var roll := rng.randf()
				var kind := "wreck_bus" if roll < 0.2 else ("wreck_truck" if roll < 0.5 else "wreck_car")
				_place_mid(chunk, kind, p + nrm * rng.randf_range(-0.5, 0.5) * GroundField.ROAD_HALF, rng, taken)
		## Toppled power pole on the verge, lines sagging toward the road.
		if rng.randf() < 0.3:
			var p2 := _point_on_seg(a, b, rect.grow(-60.0), rng)
			if p2.x != INF:
				_place_mid(chunk, "pole_down", p2 + nrm * (GroundField.ROAD_HALF + 46.0) * (1.0 if rng.randf() < 0.5 else -1.0), rng, taken)


func _point_on_seg(a: Vector2, b: Vector2, rect: Rect2, rng: RandomNumberGenerator) -> Vector2:
	for attempt in range(8):
		var p := a.lerp(b, rng.randf())
		if rect.has_point(p):
			return p
	return Vector2(INF, INF)


## Debris clusters with clearings between them; crates live inside clusters.
func _populate_clusters(chunk: Node2D, coord: Vector2i, segs: Array[Dictionary], decals: Array, taken: Array[Vector2]) -> void:
	var rng := _rng_for(coord, 57)
	var n := 0 if rng.randf() < CLEARING_CHANCE else (1 if rng.randf() < 0.62 else 2)
	for c in range(n):
		var anchor := chunk.position + Vector2(rng.randf_range(130, CHUNK_SIZE - 130), rng.randf_range(110, CHUNK_SIZE - 110))
		var biome: int = field.biome_at(anchor)
		var name := _weighted(BIOME_CLUSTERS[biome], rng)
		var near_road := GroundField.road_dist(anchor, segs) < GroundField.ROAD_HALF + 150.0
		if near_road and name != "wreck_site" and name != "signpost":
			continue
		if near_road and GroundField.road_dist(anchor, segs) < GroundField.ROAD_HALF + 70.0:
			continue
		var clash := false
		for t in taken:
			if t.distance_to(anchor) < 260.0:
				clash = true
		if clash:
			continue
		taken.append(anchor)
		var flip := rng.randf() < 0.5
		for e in CLUSTERS[name]:
			var kind := str(e[0])
			var off := Vector2(float(e[1]) * (-1.0 if flip else 1.0), float(e[2])) + Vector2(rng.randf_range(-8, 8), rng.randf_range(-6, 6))
			var wp := anchor + off
			if kind.begins_with("@"):
				var dk := kind.substr(1)
				var rot := rng.randf_range(-0.5, 0.5) if dk in ["crack", "tracks"] else 0.0
				decals.append([_decal(dk, rng), (wp - chunk.position).floor(), rot, rng.randf() < 0.5, Color.WHITE])
			elif kind == "crate":
				if rng.randf() < 0.75 and wp.length() > 160.0:
					_place_crate(chunk, wp - chunk.position, rng)
			elif kind == "fire":
				if rng.randf() < 0.7:
					LightFx.fire(chunk, (wp - chunk.position).floor(), 0.9)
			else:
				_place_cluster_prop(chunk, kind, wp, flip != (rng.randf() < 0.3))
	## A lone crate out in the open now and then (clearings keep some loot).
	if n == 0 and rng.randf() < 0.6:
		var lp := Vector2(rng.randf_range(60, CHUNK_SIZE - 60), rng.randf_range(60, CHUNK_SIZE - 60))
		if (chunk.position + lp).length() > 160.0:
			_place_crate(chunk, lp, rng)
	## Sparse singles so clearings aren't sterile (no blockers).
	for i in range(rng.randi() % 2):
		var p := Vector2(rng.randf_range(30, CHUNK_SIZE - 30), rng.randf_range(30, CHUNK_SIZE - 30))
		if GroundField.road_dist(chunk.position + p, segs) < GroundField.ROAD_HALF + 20.0:
			continue
		var sp := Sprite2D.new()
		sp.texture = prop_tex(["rock_small", "dead_bush", "tire", "bones"][rng.randi() % 4])
		sp.scale = Vector2.ONE * prop_scale(sp.texture)
		sp.position = p.floor()
		sp.flip_h = rng.randf() < 0.5
		sp.z_index = 2
		chunk.add_child(sp)
	## Rare foreground occluder: a dead bush drawn over the units, slightly see-through.
	if rng.randf() < OCCLUDER_CHANCE:
		var p2 := Vector2(rng.randf_range(40, CHUNK_SIZE - 40), rng.randf_range(40, CHUNK_SIZE - 40))
		if GroundField.road_dist(chunk.position + p2, segs) > GroundField.ROAD_HALF + 30.0 and (chunk.position + p2).length() > 300.0:
			var oc := Sprite2D.new()
			oc.texture = prop_tex("dead_bush")
			oc.scale = Vector2.ONE * prop_scale(oc.texture) * 1.2
			oc.position = p2.floor()
			oc.z_as_relative = false
			oc.z_index = 40
			oc.modulate = Color(0.8, 0.76, 0.72, 0.82)
			chunk.add_child(oc)


func _place_cluster_prop(chunk: Node2D, kind: String, world_pos: Vector2, flip: bool) -> void:
	var tex := prop_tex(kind)
	if tex == null:
		return
	var blocks := CLUSTER_BLOCK.has(kind) or (MID_PROPS.has(kind) and (MID_PROPS[kind] as Dictionary).has("block"))
	if blocks:
		if world_pos.length() < BLOCK_CLEAR_ORIGIN:
			return
		for lm in landmarks:
			if (lm["position"] as Vector2).distance_to(world_pos) < BLOCK_CLEAR_LANDMARK:
				return
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.scale = Vector2.ONE * prop_scale(tex)
	sp.position = (world_pos - chunk.position).floor()
	sp.flip_h = flip
	sp.z_index = 1 if kind == "crater" else 2
	chunk.add_child(sp)
	if blocks:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = sp.position
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		var size: Vector2 = CLUSTER_BLOCK.get(kind, (MID_PROPS.get(kind, {}) as Dictionary).get("block", Vector2(40, 16)))
		shape.size = size * UnitAnim.ART_GROW
		cs.shape = shape
		var off: Vector2 = (MID_PROPS.get(kind, {}) as Dictionary).get("off", Vector2(0, 6)) * UnitAnim.ART_GROW
		if flip:
			off.x = -off.x
		cs.position = off
		body.add_child(cs)
		chunk.add_child(body)


func _place_crate(chunk: Node2D, local: Vector2, rng: RandomNumberGenerator) -> void:
	var br: StaticBody2D = BreakableScene.instantiate()
	br.position = local.floor()
	br.z_index = 2
	chunk.add_child(br)
	match rng.randi() % 4:
		0:
			br.setup("herb_crate", _prop_crate, 18.0)
		1:
			br.setup("scrap_drum", _prop_drum, 28.0)
		2:
			br.setup("apothecary_chest", _prop_chest, 32.0)
		_:
			br.setup("vial_crate", _prop_vial, 20.0)


## Depth E7: this zone's own props (refinery tanks, city lamps, chem vats...).
func _populate_zone_props(chunk: Node2D, coord: Vector2i, segs: Array[Dictionary], taken: Array[Vector2]) -> void:
	if _zone_tex.is_empty():
		return
	var rng := _rng_for(coord, 71)
	var keys: Array = _zone_tex.keys()
	var count := rng.randi_range(ZoneDefs.PROPS_PER_CHUNK.x, ZoneDefs.PROPS_PER_CHUNK.y)
	for i in range(count):
		var p := chunk.position + Vector2(rng.randf_range(70, CHUNK_SIZE - 70), rng.randf_range(60, CHUNK_SIZE - 60))
		var kind := str(keys[rng.randi() % keys.size()])
		if GroundField.road_dist(p, segs) < GroundField.ROAD_HALF + 70.0 or p.length() < BLOCK_CLEAR_ORIGIN:
			continue
		var near := false
		for t in taken:
			if t.distance_to(p) < 190.0:
				near = true
		for lm in landmarks:
			if (lm["position"] as Vector2).distance_to(p) < BLOCK_CLEAR_LANDMARK:
				near = true
		if near:
			continue
		taken.append(p)
		var info: Array = ZoneDefs.PROP_INFO.get(kind, [110.0, Vector2.ZERO])
		var tex: Texture2D = _zone_tex[kind]
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.scale = Vector2.ONE * (float(info[0]) * UnitAnim.ART_GROW / float(tex.get_height()))
		sp.offset = Vector2(0, -tex.get_height() * 0.5 + tex.get_height() * 0.08)
		sp.position = (p - chunk.position).floor()
		sp.flip_h = rng.randf() < 0.5
		sp.z_index = 2
		## Visual tier: lit zone props cast a pool of light.
		if kind == "street_lamp":
			LightFx.lamp(chunk, sp.position + Vector2(38 if not sp.flip_h else -38, -6), 150.0, Color(1.0, 0.78, 0.45, 0.38), 0.05)
		elif kind == "chem_vat":
			LightFx.lamp(chunk, sp.position + Vector2(0, -60), 130.0, Color(0.5, 1.0, 0.3, 0.26), 0.1)
		var block: Vector2 = info[1]
		if block.x > 0.0:
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			body.position = sp.position
			var cs := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = block * UnitAnim.ART_GROW
			cs.shape = shape
			body.add_child(cs)
			chunk.add_child(body)
		chunk.add_child(sp)


func _weighted(table: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for e in table:
		total += int(e[1])
	var r := rng.randi() % total
	for e in table:
		r -= int(e[1])
		if r < 0:
			return e[0]
	return table[0][0]


func _place_mid(chunk: Node2D, kind: String, world_pos: Vector2, rng: RandomNumberGenerator, taken: Array[Vector2]) -> void:
	for t in taken:
		if t.distance_to(world_pos) < 150.0:
			return
	var info: Dictionary = MID_PROPS[kind]
	if info.has("block"):
		if world_pos.length() < BLOCK_CLEAR_ORIGIN:
			return
		for lm in landmarks:
			if (lm["position"] as Vector2).distance_to(world_pos) < BLOCK_CLEAR_LANDMARK:
				return
	taken.append(world_pos)
	var sp := Sprite2D.new()
	sp.texture = _mid_tex[kind]
	sp.scale = Vector2.ONE * prop_scale(sp.texture)
	sp.position = (world_pos - chunk.position).floor()
	sp.flip_h = rng.randf() < 0.5
	sp.z_index = 1 if info.get("ground", false) else 2
	if info.has("block"):
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = sp.position
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = info["block"] * UnitAnim.ART_GROW
		cs.shape = shape
		var off: Vector2 = info["off"] * UnitAnim.ART_GROW
		if sp.flip_h:
			off.x = -off.x
		cs.position = off
		body.add_child(cs)
		chunk.add_child(body)
	chunk.add_child(sp)


## Small decals in clusters (2-4 per chunk) flavoured by biome / riverbed,
## plus a light sprinkle of singles. All inside the floor's value range.
func _populate_decals(chunk: Node2D, coord: Vector2i, segs: Array[Dictionary], decals: Array) -> void:
	var rng := _rng_for(coord, 63)
	var clusters := 1 + rng.randi() % 2
	for c in range(clusters):
		var center := Vector2(rng.randf_range(30, CHUNK_SIZE - 30), rng.randf_range(30, CHUNK_SIZE - 30))
		var wc := chunk.position + center
		var pool: Array = RIVER_DECALS if field.is_riverbed(wc) else BIOME_DECALS[field.biome_at(wc)]
		if GroundField.road_dist(wc, segs) < GroundField.ROAD_HALF:
			pool = ["oil", "scrap", "pebbles", "crack"]
		var n := 2 + rng.randi() % 4
		var spread := rng.randf_range(18.0, 40.0)
		## Cluster has a dominant kind, with a few mixed in.
		var main_kind: String = pool[rng.randi() % pool.size()]
		for i in range(n):
			var kind: String = main_kind if rng.randf() < 0.6 else pool[rng.randi() % pool.size()]
			if kind == "toxic" and rng.randf() < 0.5:
				kind = "pebbles"
			var off := Vector2(rng.randfn(0.0, spread), rng.randfn(0.0, spread * 0.7))
			var rot := rng.randf_range(-0.6, 0.6) if kind == "crack" else 0.0
			decals.append([_decal(kind, rng), (center + off).floor(), rot, rng.randf() < 0.5, Color.WHITE])
	for i in range(rng.randi() % 3):
		var p := Vector2(rng.randf_range(10, CHUNK_SIZE - 10), rng.randf_range(10, CHUNK_SIZE - 10))
		decals.append([_decal(["pebbles", "grass", "crack"][rng.randi() % 3], rng), p.floor(), 0.0, rng.randf() < 0.5, Color.WHITE])


func _maybe_landmark_sprite(chunk: Node2D, coord: Vector2i) -> void:
	for lm in landmarks:
		var lp: Vector2 = lm["position"]
		var lc := _chunk_coord(lp)
		if lc == coord:
			var sp := Sprite2D.new()
			## kind: 0 wreck · 1 wall/garage · 2 tower · 3 market pillar
			var k := int(lm["kind"])
			if k == 2:
				sp.texture = _prop_tower
			elif k == 1:
				sp.texture = _prop_wall
			elif k == 3:
				sp.texture = _prop_pillar
			else:
				sp.texture = _prop_wreck
			sp.position = lp - chunk.position
			sp.centered = true
			sp.scale = Vector2.ONE * prop_scale(sp.texture)
			sp.z_index = 3
			chunk.add_child(sp)
			var label := Label.new()
			label.text = str(lm["name"])
			label.position = sp.position + Vector2(-40, -50)
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
			label.z_index = 3
			chunk.add_child(label)
