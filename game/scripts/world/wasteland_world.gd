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
var terrain_noise: FastNoiseLite
var _decor: Array[Texture2D] = []
var landmarks: Array[Dictionary] = [] ## {name, position, kind}
var _loaded: Dictionary = {} ## Vector2i -> Node2D
var _player: Node2D
var _tile_tex: Array[Texture2D] = []
var _prop_wreck: Texture2D
var _prop_crate: Texture2D
var _prop_tower: Texture2D
var _prop_scrap: Texture2D
var _prop_drum: Texture2D
var _prop_chest: Texture2D
var _prop_vial: Texture2D
var _chunks_root: Node2D
var _props_root: Node2D
const BreakableScene := preload("res://scenes/entities/breakable.tscn")


func setup(p_seed: int, player: Node2D) -> void:
	run_seed = p_seed
	_player = player
	_load_textures()
	_chunks_root = Node2D.new()
	_chunks_root.name = "Chunks"
	_chunks_root.z_index = -10
	add_child(_chunks_root)
	_props_root = Node2D.new()
	_props_root.name = "Props"
	_props_root.z_index = -5
	add_child(_props_root)
	_build_landmark_catalog()
	landmarks_changed.emit(landmarks)
	_sync_chunks(true)


func _load_textures() -> void:
	_tile_tex.clear()
	for i in range(6):
		_tile_tex.append(load("res://assets/sprites/tiles/ground_%d.png" % i) as Texture2D)
	_decor.clear()
	for n in ["rock_small", "rock_small", "rock_large", "dead_bush", "dead_bush", "bones", "tire", "cactus", "sign_post", "scrap_pile"]:
		_decor.append(load("res://assets/sprites/props/%s.png" % n) as Texture2D)
	terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = run_seed
	terrain_noise.frequency = 0.0016
	terrain_noise.fractal_octaves = 2
	_prop_wreck = load("res://assets/sprites/props/wreck.png")
	_prop_crate = load("res://assets/sprites/props/herb_crate.png")
	_prop_tower = load("res://assets/sprites/props/signal_tower.png")
	_prop_scrap = load("res://assets/sprites/props/scrap_pile.png")
	_prop_drum = load("res://assets/sprites/props/scrap_drum.png")
	_prop_chest = load("res://assets/sprites/props/apothecary_chest.png")
	_prop_vial = load("res://assets/sprites/props/vial_crate.png")


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
	chunk.configure(self, coord, run_seed, _tile_tex)
	_chunks_root.add_child(chunk)
	_populate_props(chunk, coord)
	_maybe_landmark_sprite(chunk, coord)
	return chunk


func _populate_props(chunk: Node2D, coord: Vector2i) -> void:
	var h := _hash2(coord.x, coord.y, 3)
	## Decorative (non-breakable) scrap / wrecks
	## Sparse, varied decor. Occasional wreck as a mini-landmark.
	var decor := 2 + (h % 4)
	for i in range(decor):
		var ph := _hash2(coord.x, coord.y, 100 + i)
		var sp := Sprite2D.new()
		sp.texture = _decor[ph % _decor.size()]
		sp.position = Vector2((ph >> 3) % (CHUNK_SIZE - 40) + 20, (ph >> 9) % (CHUNK_SIZE - 40) + 20)
		sp.flip_h = ((ph >> 5) & 1) == 1
		sp.centered = true
		sp.z_index = 0
		chunk.add_child(sp)
	if (h % 7) == 0:
		var wr := Sprite2D.new()
		wr.texture = _prop_wreck
		var wh := _hash2(coord.x, coord.y, 77)
		wr.position = Vector2((wh >> 3) % (CHUNK_SIZE - 80) + 40, (wh >> 9) % (CHUNK_SIZE - 80) + 40)
		wr.scale = Vector2(1.3, 1.3)
		chunk.add_child(wr)
	## Destructible crates — sparse (~⅕ prior density). Power-ups are rare finds.
	var breaks := 1 if (h % 10) < 7 else 0
	for i in range(breaks):
		var ph := _hash2(coord.x, coord.y, 500 + i)
		var br: StaticBody2D = BreakableScene.instantiate()
		var local := Vector2((ph >> 2) % (CHUNK_SIZE - 48) + 24, (ph >> 8) % (CHUNK_SIZE - 48) + 24)
		br.position = local
		chunk.add_child(br)
		var roll := ph % 4
		match roll:
			0:
				br.setup("herb_crate", _prop_crate, 18.0)
			1:
				br.setup("scrap_drum", _prop_drum, 28.0)
			2:
				br.setup("apothecary_chest", _prop_chest, 32.0)
			_:
				br.setup("vial_crate", _prop_vial, 20.0)


func _maybe_landmark_sprite(chunk: Node2D, coord: Vector2i) -> void:
	for lm in landmarks:
		var lp: Vector2 = lm["position"]
		var lc := _chunk_coord(lp)
		if lc == coord:
			var sp := Sprite2D.new()
			sp.texture = _prop_tower if int(lm["kind"]) == 2 else _prop_wreck
			sp.position = lp - chunk.position
			sp.centered = true
			sp.scale = Vector2(1.4, 1.4)
			sp.z_index = 1
			chunk.add_child(sp)
			var label := Label.new()
			label.text = str(lm["name"])
			label.position = sp.position + Vector2(-40, -50)
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
			chunk.add_child(label)
