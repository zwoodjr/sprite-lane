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
var landmarks: Array[Dictionary] = [] ## {name, position, kind}
var _loaded: Dictionary = {} ## Vector2i -> Node2D
var _player: Node2D
var _prop_crate: Texture2D
var _prop_drum: Texture2D
var _prop_chest: Texture2D
var _prop_vial: Texture2D
var _chunks_root: Node2D
var _props_root: Node2D
const BreakableScene := preload("res://scenes/entities/breakable.tscn")
const DecalAtlas := preload("res://scripts/world/decal_atlas.gd")
const GroundShader := preload("res://scripts/world/ground.gdshader")

## World-scale pass: hand-designed SET PIECES (junkyards, pile-ups, ruined
## building footprints, camps, crater fields, barricade lines, bone fields and
## each zone's own flavour) on a jittered one-per-chunk grid, with clearings
## round them for combat. Entries: [kind, dx, dy] in WORLD px from the anchor
## (sprite centres); kind is a prop name (assets/sprites/props or depth/zone),
## "?kind" = placed ~55% of the time, "@decal" = floor decal, "crate" = a
## breakable slot, "fire" = camp fire. Offsets are authored for the bible-size
## art (car ~176 world px long, hero ~74), and blockers either overlap into one
## mass or leave >= 60 px gaps, so there are no stuck slots.
const SETS := {
	"junkyard": [["wreck_pile", -40, -50], ["%car", 110, 50], ["tire_stack", -150, -30], ["?tire", -120, 60],
		["scrap_pile", 30, 90], ["barrels_rust", 160, -60], ["@oil", 60, 10], ["@debris", -60, 40], ["@scrap", -130, 30],
		["@tracksh", 0, 120], ["@rubble", 100, -20], ["crate", -20, 45]],
	"pileup": [["%big", 20, -130], ["%car", -110, -10], ["%car", 90, 10], ["?tire", -190, 40],
		["scrap_pile", 160, 60], ["@oil", -20, 30], ["@debris", 80, 50], ["@tracksh", -40, 80], ["@scrap", -150, 0], ["crate", -40, 70]],
	"ruin_house": [["wall_ruin_b", 0, -90], ["wall_ruin", -140, -80], ["ruin_pillar", 110, -60], ["wall_collapsed", 90, 70],
		["rubble_chunk", -70, 60], ["?scrap_pile", -150, 80], ["@rubble", 0, -10], ["@rubble", -60, 20], ["@debris", 40, 20],
		["@rubble", 120, 110], ["@crack", -20, 40], ["crate", 10, 15]],
	"campsite": [["sandbags", -60, -60], ["wall_ruin", 110, -110], ["barrels_rust", 120, -30], ["fire", 20, 0], ["crate_stack", -150, 10],
		["?tire", 100, 50], ["scrap_pile", -80, 80], ["@stain", 20, 12], ["@tufts", -30, 40], ["@debris", 80, 70], ["crate", 150, 20]],
	"crater_field": [["@crater", -90, -40], ["@crater", 80, 10], ["@crater", -20, 100], ["rock_huge", 140, -80], ["rock_large", -150, 60],
		["rock_small", 30, -90], ["?rock_small", -60, 30], ["@rubble", -100, 0], ["@pebbles", 60, 60], ["@debris", 150, 50], ["?bones", 90, 100]],
	"barricade": [["sandbags", -130, 0], ["sandbags", 60, 0], ["barrier_scrap", 170, -10], ["barrels_rust", -20, -50],
		["?tire_stack", -210, 10], ["@debris", -30, 30], ["@pebbles", 100, 30], ["@scrap", -120, 40], ["crate", -20, 50]],
	"bone_field": [["beast_ribs", 0, -30], ["bones", -150, 40], ["bones", 120, 60], ["rock_small", -110, -70], ["dead_bush", 150, -40],
		["@bones", -60, 50], ["@bones", 60, 40], ["@bones", -170, -10], ["@tufts", 20, 80], ["@pebbles", 140, 10]],
	"rock_garden": [["rock_huge", 0, -20], ["rock_large", -100, 30], ["rock_small", 80, 40], ["rock_small", -60, -70], ["dead_bush", 110, -30],
		["@pebbles", -20, 40], ["@tufts", 60, 70], ["@pebbles", -120, -20], ["@crack", 40, -60], ["crate", -150, -10]],
	"junk_heap": [["scrap_pile", 0, 0], ["tire_stack", -70, -20], ["barrels_rust", 70, -10], ["?crate_stack", 10, -70],
		["@debris", -30, 40], ["@scrap", 50, 40], ["@oil", 0, 20], ["crate", -90, 40]],
	"fence_run": [["fence_broken", -90, -20], ["fence_broken", 90, -10], ["dead_bush", -200, 30], ["?tire", 180, 50],
		["@tufts", -40, 40], ["@pebbles", 60, 50], ["@debris", 150, 30]],
	## ---- zone flavour
	"pole_line": [["power_pole", -160, -40], ["power_pole", 0, -60], ["power_pole", 160, -80], ["%car", -40, 80],
		["?tire", 130, 60], ["@tracksh", 0, 30], ["@scrap", -110, 70], ["@debris", 90, 100]],
	"dune_wreck": [["buried_wreck", 0, -30], ["rock_large", -150, 40], ["bones", 120, 60], ["?dead_bush", 140, -60],
		["@tufts", -60, 60], ["@pebbles", 60, 50], ["@bones", -120, -10], ["crate", -60, 40]],
	"tank_farm": [["oil_tank", -100, -80], ["oil_tank", 80, -100], ["pipe_rack", 20, 70], ["barrels_rust", 180, 20],
		["@oil", 0, 10], ["@oil", -70, 110], ["@stain", 110, 50], ["@debris", -160, 40], ["crate", -170, 30]],
	"pipe_run": [["pipe_rack", -110, -20], ["pipe_rack", 130, -40], ["barrels_rust", 20, 60], ["?scrap_drum", -170, 70],
		["@oil", 10, 30], ["@stain", -80, 70], ["@debris", 120, 60], ["crate", 60, 70]],
	"street_block": [["shop_ruin", 0, -80], ["street_lamp", -170, -20], ["street_lamp", 170, 30], ["%car", 20, 100],
		["@rubble", -80, 30], ["@rubble", 100, 20], ["@debris", -40, 60], ["@crack", 120, 70], ["crate", -110, 50]],
	"q_camp": [["quarantine_tent", -60, -70], ["hazard_barrier", 110, 60], ["?%car", 150, -150], ["fence_broken", -170, 70], ["crate_stack", 140, -60],
		["@toxic", 30, 20], ["@debris", -40, 40], ["@stain", 130, 0], ["crate", 20, 20]],
	"raider_camp": [["spike_barricade", -50, -90], ["raider_totem", 140, -60], ["%moto", -110, -20], ["?%moto", 80, 90], ["raider_totem", -170, 40], ["fire", 0, 0],
		["barrels_rust", 90, 40], ["tire_stack", -80, 50], ["?spike_barricade", 60, 130], ["@stain", 0, 12], ["@bones", -40, 40],
		["@debris", 120, 80], ["crate", 30, 60]],
	"vat_bank": [["chem_vat", -90, -60], ["chem_vat", 60, -80], ["pipe_rack", 0, 60], ["barrels_rust", 170, 10],
		["@toxic", -20, 10], ["@toxic", 100, 40], ["@oil", -120, 50], ["@debris", 160, 70], ["crate", -160, 20]],
	"base_post": [["tank_wreck", -60, -60], ["guard_post", 150, -40], ["?%car", 120, 150], ["sandbags", -120, 70], ["sandbags", 50, 100],
		["?crate_stack", 170, 100], ["@tracksh", -40, 20], ["@debris", 60, 40], ["@rubble", -160, 10], ["crate", -10, 45]],
	"slab_field": [["slab_ruin", -40, -60], ["rubble_chunk", 130, 0], ["rubble_chunk", -160, 50], ["?wall_ruin", 120, -110],
		["@crater", 60, 80], ["@rubble", -60, 40], ["@rubble", 40, 20], ["@debris", -130, 100], ["crate", 0, 50]],
	"spire_field": [["dust_spire", 0, -80], ["slab_ruin", -150, 70], ["?rubble_chunk", 140, 40], ["@crater", 80, 90],
		["@rubble", -40, 20], ["@pebbles", 60, 20], ["@debris", 160, -20], ["crate", 50, 60]],
	## ---- small zone pieces (second piece in a chunk corner)
	"vat_single": [["chem_vat", 0, -30], ["barrels_rust", 80, 20], ["@toxic", -20, 40], ["@debris", 60, 50]],
	"drum_dump": [["barrels_rust", -40, 0], ["barrels_rust", 50, -20], ["?scrap_drum", 10, 40], ["@oil", 0, 30], ["@stain", -60, 30]],
	"lamp_car": [["street_lamp", -90, -40], ["%car", 60, 20], ["@rubble", -20, 50], ["@debris", 120, 60]],
	"tent_post": [["quarantine_tent", 0, -30], ["?crate_stack", 130, 20], ["@debris", -60, 60], ["@toxic", 60, 60]],
	"totem_post": [["raider_totem", 0, -40], ["spike_barricade", 30, 50], ["?tire_stack", -90, 10], ["@bones", -40, 70]],
	"sandbag_nest": [["sandbags", 0, 0], ["barrels_rust", 100, -30], ["?crate_stack", -100, -20], ["@debris", 20, 40], ["crate", 60, 40]],
	"pole_pair": [["power_pole", -60, -40], ["power_pole", 80, -60], ["?tire", 0, 40], ["@tracksh", 0, 20]],
	"dune_buried": [["buried_wreck", 0, -20], ["?rock_small", 100, 30], ["@tufts", -70, 40]],
	"rubble_heap": [["rubble_chunk", -40, 0], ["rubble_chunk", 50, 20], ["?rock_small", 0, -50], ["@rubble", 0, 40], ["@rubble", -70, 30]],
	"spire_small": [["dust_spire", 0, -40], ["@rubble", -50, 50], ["@pebbles", 60, 40]],
	"tank_hulk": [["%mil", 0, -40], ["sandbags", -150, 60], ["?barrels_rust", 140, 50], ["@tracksh", 0, 40],
		["@debris", -60, 70], ["@rubble", 100, 0], ["crate", 60, 70]],
}
## Vehicle wrecks (tools/art_world/vehicles.py): real vehicle types, 3 damage
## variants each. Set entries use pool tokens: "%car", "%big", "%mil",
## "%moto" (resolved per zone, see _veh). "%big" may roll a semi + trailer.
const VEH_CARS := ["veh_sedan_0", "veh_sedan_1", "veh_sedan_2", "veh_sedan_red_0", "veh_sedan_red_1", "veh_sedan_red_2",
	"veh_wagon_0", "veh_wagon_1", "veh_wagon_2", "veh_pickup_0", "veh_pickup_1", "veh_pickup_2"]
const VEH_BIG := ["veh_school_bus_0", "veh_school_bus_1", "veh_school_bus_2", "veh_city_bus_0", "veh_city_bus_1", "veh_city_bus_2",
	"veh_box_truck_0", "veh_box_truck_1", "veh_box_truck_2", "veh_semi_0", "veh_semi_0"]
const VEH_MIL := ["tank_wreck", "veh_tank_1", "veh_tank_2", "veh_apc_0", "veh_apc_1", "veh_apc_2", "veh_humvee_0", "veh_humvee_1", "veh_humvee_2"]
const VEH_MOTO := ["veh_moto_0", "veh_moto_1", "veh_moto_2"]
## Zone flavour: extra cars mixed into "%car" (and what "%big" leans to).
const ZONE_VEH := {
	"city": [["veh_police_0", "veh_police_1", "veh_police_2", "veh_sedan_0", "veh_wagon_1"], ["veh_city_bus_0", "veh_city_bus_1", "veh_city_bus_2", "veh_box_truck_0"]],
	"quarantine": [["veh_ambulance_0", "veh_ambulance_1", "veh_ambulance_2", "veh_police_0", "veh_police_2"], ["veh_ambulance_0", "veh_ambulance_2", "veh_box_truck_1"]],
	"military": [["veh_humvee_0", "veh_humvee_1", "veh_humvee_2", "veh_pickup_2"], ["veh_tank_1", "veh_apc_0", "veh_apc_2", "veh_semi_0"]],
	"raider": [["veh_pickup_0", "veh_pickup_1", "veh_pickup_2", "veh_moto_0", "veh_moto_1"], ["veh_school_bus_1", "veh_semi_0", "veh_box_truck_2"]],
	"dustfall": [["veh_humvee_1", "veh_sedan_1", "veh_pickup_1"], ["veh_tank_2", "veh_apc_1", "veh_school_bus_2"]],
	"refinery": [["veh_pickup_0", "veh_pickup_1", "veh_box_truck_0"], ["veh_semi_0", "veh_box_truck_1", "veh_box_truck_2"]],
}
## Hero feet sit this far below the unit origin (player FEET_Y): a prop's
## y-sort node goes this far above its base line, so a unit draws in front
## exactly when its feet are below the prop's base (mobs' feet are higher,
## within the collision block).
const SORT_FEET := 30.0

## Generic set pieces per biome: [set, weight].
const BIOME_SETS := {
	0: [["junkyard", 12], ["pileup", 8], ["ruin_house", 10], ["campsite", 12], ["crater_field", 10], ["barricade", 8],
		["rock_garden", 10], ["junk_heap", 12], ["fence_run", 8]],
	1: [["bone_field", 16], ["rock_garden", 14], ["crater_field", 10], ["junk_heap", 8], ["campsite", 8], ["pileup", 6]],
	2: [["fence_run", 14], ["rock_garden", 14], ["campsite", 12], ["bone_field", 8], ["junk_heap", 10], ["barricade", 8]],
	3: [["ruin_house", 22], ["barricade", 14], ["crater_field", 12], ["campsite", 10], ["junkyard", 10], ["pileup", 8]],
}
## Zone flavour set pieces (by zone grade) and how often they win over generics.
const ZONE_SETS := {
	"haze": ["pole_line", "junkyard"], "drift": ["dune_wreck", "bone_field"], "refinery": ["tank_farm", "pipe_run"],
	"city": ["street_block", "ruin_house"], "quarantine": ["q_camp", "fence_run"], "raider": ["raider_camp", "barricade"],
	"chemical": ["vat_bank", "vat_bank", "pipe_run"], "military": ["base_post", "tank_hulk"], "crater": ["slab_field", "ruin_house"],
	"dustfall": ["spire_field", "slab_field", "tank_hulk"],
}
const ZONE_SET_CHANCE := 0.62
## Small zone pieces for the second (corner) slot.
const ZONE_SMALL := {
	"haze": ["pole_pair", "junk_heap"], "drift": ["dune_buried", "rock_garden"], "refinery": ["drum_dump", "junk_heap"],
	"city": ["lamp_car", "rubble_heap"], "quarantine": ["tent_post", "junk_heap"], "raider": ["totem_post", "drum_dump"],
	"chemical": ["vat_single", "drum_dump"], "military": ["sandbag_nest", "junk_heap"], "crater": ["rubble_heap", "rock_garden"],
	"dustfall": ["spire_small", "rubble_heap"],
}
## Chance a chunk holds a set piece (else an open clearing with scatter).
const SET_CHANCE := 0.72
## Small walk-through fill per biome (mid detail between set pieces).
const BIOME_FILL := {
	0: ["rock_small", "dead_bush", "tire", "bones", "scrap_pile", "rock_large", "scrap_drum"],
	1: ["rock_small", "bones", "cactus", "rock_large", "dead_bush", "bones"],
	2: ["dead_bush", "dead_bush", "rock_small", "tire", "bones", "cactus"],
	3: ["rock_small", "scrap_pile", "rubble_chunk", "tire", "scrap_drum", "rock_large"],
}
## Rare foreground occluder (dead bush / grass drawn OVER units), per chunk.
const OCCLUDER_CHANCE := 0.12
## Ground detail layer: decal kinds per biome (repeats = weight). Every chunk is
## covered on a jittered 4x4 grid so no screen is bare ground.
const BIOME_DECALS := {
	0: ["crack", "crack", "pebbles", "scrap", "stain", "grass", "debris", "debris", "rubble", "tufts", "tufts"],
	1: ["bones", "pebbles", "pebbles", "grass", "stain", "tufts", "tufts", "crack", "rubble"],
	2: ["grass", "grass", "tufts", "tufts", "tufts", "pebbles", "bones", "crack", "debris"],
	3: ["scrap", "rubble", "rubble", "pebbles", "pebbles", "crack", "oil", "debris", "stain"],
}
const RIVER_DECALS := ["crack", "pebbles", "pebbles", "stain", "toxic", "bones"]
## Decals round the base of each big prop (anchor it into the ground).
const SKIRT_DECALS := ["rubble", "debris", "pebbles", "stain", "rubble", "scrap"]
## Keep blockers off the drop point and landmark/extract spots.
const BLOCK_CLEAR_ORIGIN := 420.0
const BLOCK_CLEAR_LANDMARK := 260.0
## Landmark rooms keep other dressing out (their own set-piece fills them).
const LANDMARK_ROOM := 360.0

var field: GroundField
var _atlas: Texture2D
var _ground_tex: Dictionary = {}
## Depth E7: the tier's zone (ground set, props, tint — ZoneDefs).
var zone: Dictionary = {}
## Zone grade (ground / decal set suffix) and its 4 ground colours.
var _grade: String = "haze"
## Chunks waiting for their one-off floor bake (one per frame, nearest first).
var _bake_queue: Array[WastelandChunk] = []
## Prop textures by name (props/ or depth/zone/), loaded once per run.
var _tex_cache: Dictionary = {}
## Placed prop footprints per chunk (world Rect2): spacing for fill and the
## pad / spawn clear-spot check (clear_at).
var _occ: Dictionary = {}
## Collision blocks per chunk: [world Rect2, group id]. Blockers from different
## groups never sit closer than BLOCK_GAP (no slots to wedge in).
var _blk: Dictionary = {}
var _gid: int = 0
const BLOCK_GAP := 64.0


func setup(p_seed: int, player: Node2D) -> void:
	run_seed = p_seed
	_player = player
	zone = ZoneDefs.zone(GameState.zone_tier())
	_load_textures()
	_chunks_root = Node2D.new()
	_chunks_root.name = "Chunks"
	_chunks_root.z_index = -10
	## Y-sort: World > Wasteland > Chunks > chunk > prop sprites all merge into
	## the World's sort with the units (floor / decals stay on lower z layers).
	y_sort_enabled = true
	_chunks_root.y_sort_enabled = true
	## Style bible: the floor is authored in the zone's own 4 ground colours,
	## so it gets no tint at all (mood comes from light pools).
	_chunks_root.modulate = Color.WHITE
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
	_grade = grade if grade != "" else "haze"
	for k in ["earth", "sand", "scrub", "rubble", "riverbed", "asphalt"]:
		var zp := "res://assets/sprites/tiles/zones/ground_%s_%s.png" % [k, grade]
		if grade != "" and ResourceLoader.exists(zp):
			_ground_tex[k] = load(zp) as Texture2D
		else:
			_ground_tex[k] = load("res://assets/sprites/tiles/ground_%s.png" % k) as Texture2D
	var ap := "res://assets/sprites/decals/decal_atlas_%s.png" % _grade
	_atlas = load(ap if ResourceLoader.exists(ap) else "res://assets/sprites/decals/decal_atlas.png") as Texture2D
	_prop_crate = prop_tex("herb_crate")
	_prop_drum = prop_tex("scrap_drum")
	_prop_chest = prop_tex("apothecary_chest")
	_prop_vial = prop_tex("vial_crate")


## Any world prop by name: chunk dressing (props/) or zone art (depth/zone/).
func _tex(kind: String) -> Texture2D:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var t: Texture2D = null
	var p1 := "res://assets/sprites/props/%s.png" % kind
	var p2 := ZoneDefs.PROP_DIR % kind
	if ResourceLoader.exists(p1):
		t = load(p1) as Texture2D
	elif ResourceLoader.exists(p2):
		t = load(p2) as Texture2D
	_tex_cache[kind] = t
	return t


## Style-bible prop art (tools/art_world/build.py), one density for everything.
static func prop_tex(n: String) -> Texture2D:
	return load("res://assets/sprites/props/%s.png" % n) as Texture2D


## Positions are floored to whole art texels (bible 1.1).
static func snap(p: Vector2) -> Vector2:
	return (p / UnitAnim.TEXEL).floor() * UnitAnim.TEXEL


## World prop sprite centred on `centre` (chunk-local). Standing props are
## Y-SORTED with the units: the node sits SORT_FEET above the prop's base line
## (PropMeta "base", the bottom of its collision footprint) and the texture is
## offset back, so heroes / mobs walk behind tall props and in front of them.
## Flat ground pieces keep drawing under every unit.
static func prop_sprite(kind: String, tex: Texture2D, centre: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.scale = Vector2.ONE * UnitAnim.TEXEL
	var m := PropMeta.info(kind)
	if m.get("flat", false):
		sp.position = centre
		sp.z_index = 2
		return sp
	var key := PropMeta.base_y(kind, float(tex.get_height())) - SORT_FEET
	sp.position = centre + Vector2(0.0, key)
	sp.offset = Vector2(0.0, -key / UnitAnim.TEXEL)
	## The chunk layer sits at z -10: +10 puts standing props on the units' layer.
	sp.z_index = 10
	return sp


## Engine contact shadow for a prop (never baked into the art): the hard pixel
## ellipse under its footprint (PropMeta "foot"), below the prop's sprite.
static func add_prop_shadow(parent: Node2D, kind: String, at: Vector2, flip: bool = false) -> void:
	var m := PropMeta.info(kind)
	if m.is_empty() or m.get("flat", false):
		return
	var f: Vector2 = m["foot"]
	var sz: Vector2 = m["size"]
	var fx := (f.x + f.y) * 0.5
	if flip:
		fx = -fx
	var s := Sprite2D.new()
	## Props are deep, not round: the ellipse is 0.8 x footprint wide but at
	## most 12 texels tall, so a sandbag wall doesn't drag a huge oval.
	s.texture = UnitAnim.pixel_shadow_tex(int(round((f.y - f.x) * 0.8)), 12)
	s.scale = Vector2.ONE * UnitAnim.TEXEL
	s.position = at + Vector2(fx + 2.0, sz.y * 0.5) * UnitAnim.TEXEL
	s.z_index = 1
	parent.add_child(s)


## Static collision footprint from PropMeta (no-op for walk-through props).
static func add_prop_block(parent: Node2D, kind: String, at: Vector2, flip: bool = false) -> bool:
	var r := PropMeta.block_rect(kind, flip)
	if r.size == Vector2.ZERO:
		return false
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	body.add_child(cs)
	parent.add_child(body)
	return true


static func blocks(kind: String) -> bool:
	return (PropMeta.info(kind) as Dictionary).has("block")


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
	chunk.y_sort_enabled = true
	var rect := Rect2(chunk.position, Vector2(CHUNK_SIZE, CHUNK_SIZE))
	var segs := field.segments_in(rect)
	var decals: Array = []
	chunk.configure(coord, _ground_material(segs, chunk.position), _atlas, decals)
	_chunks_root.add_child(chunk)
	_occ[coord] = []
	_blk[coord] = []
	chunk.tree_exiting.connect(func() -> void:
		_occ.erase(coord)
		_blk.erase(coord))
	_maybe_landmark_sprite(chunk, coord)
	_populate_road(chunk, coord, segs, decals)
	_populate_sets(chunk, coord, segs, decals)
	_populate_fill(chunk, coord, segs)
	_populate_decals(chunk, coord, segs, decals)
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
	var zc: Array = ZoneDefs.ground_colors(_grade)
	for i in range(4):
		var c: Color = zc[i]
		mat.set_shader_parameter("zc%d" % i, Vector3(c.r, c.g, c.b))
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
	var n := 2 if kind in ["oil", "toxic", "stain", "crater"] or kind.begins_with("tracks") else 3
	if not DecalAtlas.REGIONS.has("%s_0" % kind):
		kind = "pebbles"
	return DecalAtlas.REGIONS["%s_%d" % [kind, rng.randi() % n]]


## Tyre tracks are pre-drawn in 4 directions (pixel art is never rotated):
## pick the one closest to the road direction.
func _tracks_kind(dir: Vector2) -> String:
	var a := fposmod(dir.angle(), PI)
	if a < PI / 8.0 or a >= PI * 7.0 / 8.0:
		return "tracksh"
	if a < PI * 3.0 / 8.0:
		return "tracksd"
	if a < PI * 5.0 / 8.0:
		return "tracksv"
	return "tracksa"


## Roads: abandoned convoys (2-3 vehicles nose to tail), downed power poles on
## the verge, road blocks; tyre tracks and oil on the asphalt.
func _populate_road(chunk: Node2D, coord: Vector2i, segs: Array[Dictionary], decals: Array) -> void:
	if segs.is_empty():
		return
	var rng := _rng_for(coord, 41)
	var rect := Rect2(chunk.position, Vector2(CHUNK_SIZE, CHUNK_SIZE)).grow(-30.0)
	var did_convoy := false
	for s in segs:
		var a: Vector2 = s["a"]
		var b: Vector2 = s["b"]
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		for i in range(5):
			var p := _point_on_seg(a, b, rect, rng)
			if p.x == INF:
				break
			var lat := rng.randf_range(-0.6, 0.6) * GroundField.ROAD_HALF
			decals.append([_decal(_tracks_kind(dir), rng), (p + nrm * lat - chunk.position).floor(), 0.0, false, Color.WHITE])
			if rng.randf() < 0.45:
				var q := p + dir * rng.randf_range(-60, 60) + nrm * rng.randf_range(-20, 20)
				decals.append([_decal("oil", rng), (q - chunk.position).floor(), 0.0, false, Color.WHITE])
			## Verge: debris, rubble, dead grass both sides.
			for side: float in [-1.0, 1.0]:
				if rng.randf() < 0.7:
					var q2: Vector2 = p + dir * rng.randf_range(-40, 40) + nrm * (GroundField.ROAD_HALF + rng.randf_range(8, 40)) * side
					var vk: String = ["debris", "pebbles", "tufts", "scrap", "rubble"][rng.randi() % 5]
					decals.append([_decal(vk, rng), q2 - chunk.position, 0.0, false, Color.WHITE])
		## Abandoned convoy: vehicles nose to tail along the road.
		if not did_convoy and rng.randf() < 0.55:
			var p0 := _point_on_seg(a, b, rect.grow(-90.0), rng)
			if p0.x != INF and _room_ok(p0, 120.0):
				did_convoy = true
				_gid += 1
				var n := 2 + rng.randi() % 2
				var kinds: Array[String] = []
				var exts: Array[float] = []
				var total := 0.0
				for k in range(n):
					var kind := _veh("%big" if rng.randf() < 0.3 else ("%moto" if rng.randf() < 0.08 else "%car"), rng)
					if kind == "veh_semi_0":
						kind = "veh_box_truck_0"
					var t := _tex(kind)
					var ext := 120.0
					if t:
						ext = (absf(dir.x) * t.get_width() + absf(dir.y) * t.get_height() * 0.8) * UnitAnim.TEXEL + 24.0
					kinds.append(kind)
					exts.append(ext)
					total += ext
				var along := -total * 0.5
				for k in range(n):
					along += exts[k] * 0.5
					var vp := p0 + dir * along + nrm * rng.randf_range(-0.4, 0.4) * GroundField.ROAD_HALF
					along += exts[k] * 0.5
					var kind := kinds[k]
					_put(chunk, kind, vp, true)
					decals.append([_decal("oil", rng), (vp + Vector2(rng.randf_range(-30, 30), 24) - chunk.position).floor(), 0.0, false, Color.WHITE])
					if rng.randf() < 0.6:
						var junk: Array[String] = ["tire", "scrap_pile", "scrap_drum"]
						_put(chunk, junk[rng.randi() % 3], vp + nrm * (GroundField.ROAD_HALF + 50.0) * (1.0 if rng.randf() < 0.5 else -1.0), false)
		## Toppled power pole on the verge, lines sagging toward the road.
		if rng.randf() < 0.3:
			var p2 := _point_on_seg(a, b, rect.grow(-60.0), rng)
			if p2.x != INF:
				_put(chunk, "pole_down", p2 + nrm * (GroundField.ROAD_HALF + 60.0) * (1.0 if rng.randf() < 0.5 else -1.0), false)


func _point_on_seg(a: Vector2, b: Vector2, rect: Rect2, rng: RandomNumberGenerator) -> Vector2:
	for attempt in range(8):
		var p := a.lerp(b, rng.randf())
		if rect.has_point(p):
			return p
	return Vector2(INF, INF)


static func rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return sqrt(dx * dx + dy * dy)


## Would a block here leave a slot (or overlap) against another group's block?
func _block_ok(r: Rect2, gid: int) -> bool:
	var c := _chunk_coord(r.get_center())
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for e in _blk.get(Vector2i(c.x + dx, c.y + dy), []):
				if int(e[1]) != gid and rect_gap(r, e[0]) < BLOCK_GAP:
					return false
	return true


func _register(chunk: Node2D, kind: String, local: Vector2, tex: Texture2D, gid: int) -> void:
	var wp := chunk.position + local
	var sz := Vector2(tex.get_width(), tex.get_height()) * UnitAnim.TEXEL
	var fh := minf(sz.y, maxf(24.0, sz.y * 0.35))
	var cc := _chunk_coord(chunk.position + Vector2(1, 1))
	if _occ.has(cc):
		(_occ[cc] as Array).append(Rect2(wp + Vector2(-sz.x * 0.5, sz.y * 0.5 - fh), Vector2(sz.x, fh)))
	var br := PropMeta.block_rect(kind)
	if br.size != Vector2.ZERO and _blk.has(cc):
		(_blk[cc] as Array).append([Rect2(br.position + wp, br.size), gid])


## Is there room for a set piece here (no landmark room, no other footprint)?
func _room_ok(p: Vector2, r: float) -> bool:
	for lm in landmarks:
		if (lm["position"] as Vector2).distance_to(p) < LANDMARK_ROOM + r:
			return false
	return clear_at(p, r)


## True when no prop footprint lies within r world px of p (pads, spawns).
func clear_at(p: Vector2, r: float) -> bool:
	var c := _chunk_coord(p)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for rc in _occ.get(Vector2i(c.x + dx, c.y + dy), []):
				var rr: Rect2 = rc
				var q := p.clamp(rr.position, rr.end)
				if q.distance_to(p) < r:
					return false
	return true


## One hand-designed set piece per chunk (jittered off the grid so it never
## reads as tiles), or an open clearing. Zone flavour pieces win half the time.
func _populate_sets(chunk: Node2D, coord: Vector2i, segs: Array[Dictionary], decals: Array) -> void:
	var rng := _rng_for(coord, 57)
	var biome_c: int = field.biome_at(chunk.position + Vector2(256, 256))
	if rng.randf() < SET_CHANCE:
		var anchor := chunk.position + Vector2(256, 256) + Vector2(rng.randf_range(-70, 70), rng.randf_range(-70, 70))
		## Near a road: slide the piece off the verge instead of dropping it.
		for s in segs:
			var rd := GroundField.road_dist(anchor, segs)
			if rd >= GroundField.ROAD_HALF + 150.0:
				break
			var a: Vector2 = s["a"]
			var b: Vector2 = s["b"]
			var q := Geometry2D.get_closest_point_to_segment(anchor, a, b)
			var away := (anchor - q).normalized() if anchor.distance_to(q) > 1.0 else Vector2(-(b - a).normalized().y, (b - a).normalized().x)
			anchor = q + away * (GroundField.ROAD_HALF + 160.0)
		if anchor.length() >= 260.0 and GroundField.road_dist(anchor, segs) >= GroundField.ROAD_HALF + 140.0 and _room_ok(anchor, 150.0):
			var biome: int = field.biome_at(anchor)
			var name := ""
			var zs: Array = ZONE_SETS.get(_grade, [])
			if not zs.is_empty() and rng.randf() < ZONE_SET_CHANCE:
				name = str(zs[rng.randi() % zs.size()])
			else:
				name = _weighted(BIOME_SETS[biome], rng)
			_build_set(chunk, name, anchor, rng, decals)
	## A second, smaller piece in a free corner (mid detail between the big ones).
	if rng.randf() < 0.55:
		var corners: Array[Vector2] = [Vector2(110, 110), Vector2(402, 110), Vector2(110, 402), Vector2(402, 402)]
		var c0 := rng.randi() % 4
		for i in range(4):
			var ap := chunk.position + corners[(c0 + i) % 4] + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
			if ap.length() < 300.0 or GroundField.road_dist(ap, segs) < GroundField.ROAD_HALF + 110.0 or not _room_ok(ap, 110.0):
				continue
			var small: Array = ["junk_heap", "rock_garden", "junk_heap", "fence_run", "barricade"]
			if biome_c == 1:
				small = ["rock_garden", "junk_heap", "bone_field"]
			if ZONE_SMALL.has(_grade) and rng.randf() < 0.6:
				small = ZONE_SMALL[_grade]
			_build_set(chunk, str(small[rng.randi() % small.size()]), ap, rng, decals)
			break


## Resolve a vehicle pool token ("%car", "%big", "%mil", "%moto") for this zone.
func _veh(token: String, rng: RandomNumberGenerator) -> String:
	var zv: Array = ZONE_VEH.get(_grade, [[], []])
	match token:
		"%car":
			if not (zv[0] as Array).is_empty() and rng.randf() < 0.6:
				return str(zv[0][rng.randi() % (zv[0] as Array).size()])
			return VEH_CARS[rng.randi() % VEH_CARS.size()]
		"%big":
			if not (zv[1] as Array).is_empty() and rng.randf() < 0.6:
				return str(zv[1][rng.randi() % (zv[1] as Array).size()])
			return VEH_BIG[rng.randi() % VEH_BIG.size()]
		"%mil":
			return VEH_MIL[rng.randi() % VEH_MIL.size()]
		"%moto":
			return VEH_MOTO[rng.randi() % VEH_MOTO.size()]
	return token


## Place a vehicle; a semi tractor brings its trailer (hitched behind it, in
## the same 3/4 angle). Returns the world-px length taken along x.
func _put_vehicle(chunk: Node2D, kind: String, wp: Vector2, decals: Array, rng: RandomNumberGenerator) -> void:
	_put(chunk, kind, wp, true, decals, rng)
	if kind == "veh_semi_0":
		var st := _tex(kind)
		var tt := _tex("veh_trailer_0")
		if st and tt:
			var dx := (st.get_width() * 0.5 + tt.get_width() * 0.5 - 70.0) * UnitAnim.TEXEL
			_put(chunk, "veh_trailer_0", wp + Vector2(dx, -dx * 0.15), true, decals, rng)


func _build_set(chunk: Node2D, name: String, anchor: Vector2, rng: RandomNumberGenerator, decals: Array) -> void:
	_gid += 1
	## Mirror the layout half the time (positions only: sprites are never
	## flipped, they are lit from the top-left).
	var mx := -1.0 if rng.randf() < 0.5 else 1.0
	for e in SETS[name]:
		var kind := str(e[0])
		var wp := anchor + Vector2(float(e[1]) * mx, float(e[2])) + Vector2(rng.randf_range(-5, 5), rng.randf_range(-4, 4))
		if kind.begins_with("?"):
			if rng.randf() > 0.55:
				continue
			kind = kind.substr(1)
		if kind.begins_with("@"):
			var dk := kind.substr(1)
			if dk == "tracksh":
				dk = ["tracksh", "tracksd", "tracksa"][rng.randi() % 3]
			decals.append([_decal(dk, rng), (wp - chunk.position).floor(), 0.0, false, Color.WHITE])
		elif kind == "crate":
			if rng.randf() < 0.75 and wp.length() > 160.0:
				_place_crate(chunk, wp - chunk.position, rng)
		elif kind == "fire":
			LightFx.fire(chunk, (wp - chunk.position).floor(), 0.9)
		elif kind.begins_with("%"):
			_put_vehicle(chunk, _veh(kind, rng), wp, decals, rng)
		else:
			_put(chunk, kind, wp, true, decals, rng)


## Mid detail between set pieces: small walk-through props, kept clear of
## footprints (combat lanes stay open).
func _populate_fill(chunk: Node2D, coord: Vector2i, segs: Array[Dictionary]) -> void:
	var rng := _rng_for(coord, 59)
	var n := 6 + rng.randi() % 5
	for i in range(n):
		var p := chunk.position + Vector2(rng.randf_range(30, CHUNK_SIZE - 30), rng.randf_range(30, CHUNK_SIZE - 30))
		if GroundField.road_dist(p, segs) < GroundField.ROAD_HALF + 20.0 or not clear_at(p, 60.0):
			continue
		var pool: Array = BIOME_FILL[field.biome_at(p)]
		_gid += 1
		_put(chunk, str(pool[rng.randi() % pool.size()]), p, false)
	## A lone crate out in the open now and then (clearings keep some loot).
	if rng.randf() < 0.35:
		var lp := chunk.position + Vector2(rng.randf_range(60, CHUNK_SIZE - 60), rng.randf_range(60, CHUNK_SIZE - 60))
		if lp.length() > 160.0 and clear_at(lp, 40.0):
			_place_crate(chunk, lp - chunk.position, rng)
	## Rare foreground occluder: a dead bush drawn over the units, slightly see-through.
	if rng.randf() < OCCLUDER_CHANCE:
		var p2 := Vector2(rng.randf_range(40, CHUNK_SIZE - 40), rng.randf_range(40, CHUNK_SIZE - 40))
		if GroundField.road_dist(chunk.position + p2, segs) > GroundField.ROAD_HALF + 30.0 and (chunk.position + p2).length() > 300.0:
			var oc := Sprite2D.new()
			oc.texture = prop_tex("dead_bush")
			oc.scale = Vector2.ONE * prop_scale(oc.texture)
			oc.position = snap(p2)
			oc.z_as_relative = false
			oc.z_index = 40
			## Bible alpha steps only (25/50/75/100%): the occluder sits at 75%.
			oc.modulate = Color(1, 1, 1, 0.75)
			chunk.add_child(oc)


## Place one prop sprite (centre at world_pos): contact shadow, collision from
## PropMeta, zone light pool, footprint registered. Blockers stay off the drop
## point and landmark rooms. `big` props get a skirt of floor decals.
func _put(chunk: Node2D, kind: String, world_pos: Vector2, big: bool, decals: Array = [], rng: RandomNumberGenerator = null) -> void:
	var tex := _tex(kind)
	if tex == null:
		return
	var is_block := blocks(kind)
	if is_block:
		if world_pos.length() < BLOCK_CLEAR_ORIGIN:
			return
		for lm in landmarks:
			if (lm["position"] as Vector2).distance_to(world_pos) < BLOCK_CLEAR_LANDMARK:
				return
	var local := snap(world_pos - chunk.position)
	if is_block and not _block_ok(Rect2(PropMeta.block_rect(kind).position + chunk.position + local, PropMeta.block_rect(kind).size), _gid):
		return
	var sp := prop_sprite(kind, tex, local)
	var m := PropMeta.info(kind)
	if m.has("light"):
		var lp: Vector2 = m["light"]
		if kind == "street_lamp":
			LightFx.lamp(chunk, local + lp * UnitAnim.TEXEL, 150.0, Color(1.0, 0.75, 0.25, 0.38), 0.05)
		elif kind == "chem_vat":
			LightFx.lamp(chunk, local + lp * UnitAnim.TEXEL, 130.0, Color(0.61, 0.81, 0.24, 0.26), 0.1)
	add_prop_shadow(chunk, kind, local)
	if is_block:
		add_prop_block(chunk, kind, local)
	chunk.add_child(sp)
	_register(chunk, kind, local, tex, _gid)
	var sz := Vector2(tex.get_width(), tex.get_height()) * UnitAnim.TEXEL
	if big and rng != null and sz.x > 70.0:
		for k in range(2 + rng.randi() % 2):
			var dp := world_pos + Vector2(rng.randf_range(-0.5, 0.5) * sz.x, sz.y * 0.5 + rng.randf_range(-6, 14))
			decals.append([_decal(SKIRT_DECALS[rng.randi() % SKIRT_DECALS.size()], rng), (dp - chunk.position).floor(), 0.0, false, Color.WHITE])


func _place_crate(chunk: Node2D, local: Vector2, rng: RandomNumberGenerator) -> void:
	var br: StaticBody2D = BreakableScene.instantiate()
	br.position = snap(local)
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
	add_prop_shadow(chunk, br.kind, br.position)


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


## Ground detail layer: a jittered 4x4 grid of decals over every chunk (cracks,
## debris, dead grass, oil, rubble...) flavoured by biome / riverbed / road, so
## no screen is bare ground. All inside the floor's value range.
func _populate_decals(chunk: Node2D, coord: Vector2i, segs: Array[Dictionary], decals: Array) -> void:
	var rng := _rng_for(coord, 63)
	var cell := CHUNK_SIZE / 4.0
	for gx in range(4):
		for gy in range(4):
			for k in range(2 + int(rng.randf() < 0.5)):
				var lp := Vector2((gx + rng.randf_range(0.15, 0.85)) * cell, (gy + rng.randf_range(0.15, 0.85)) * cell)
				var wc := chunk.position + lp
				var pool: Array = RIVER_DECALS if field.is_riverbed(wc) else BIOME_DECALS[field.biome_at(wc)]
				if GroundField.road_dist(wc, segs) < GroundField.ROAD_HALF:
					pool = ["oil", "scrap", "pebbles", "crack"]
				var kind: String = pool[rng.randi() % pool.size()]
				if kind == "toxic" and rng.randf() < 0.5:
					kind = "pebbles"
				decals.append([_decal(kind, rng), lp.floor(), 0.0, false, Color.WHITE])
	## Old off-road tyre tracks wandering across the ground.
	if rng.randf() < 0.4:
		var tp := Vector2(rng.randf_range(100, CHUNK_SIZE - 100), rng.randf_range(100, CHUNK_SIZE - 100))
		if GroundField.road_dist(chunk.position + tp, segs) > GroundField.ROAD_HALF + 80.0:
			decals.append([_decal(["tracksh", "tracksd", "tracksa", "tracksv"][rng.randi() % 4], rng), tp.floor(), 0.0, false, Color.WHITE])
	## Old shell craters (they used to be a prop): a flat ground decal now.
	if rng.randf() < 0.45 and field.biome_at(chunk.position + Vector2(256, 256)) != 2:
		var cp := Vector2(rng.randf_range(70, CHUNK_SIZE - 70), rng.randf_range(50, CHUNK_SIZE - 50))
		if GroundField.road_dist(chunk.position + cp, segs) > GroundField.ROAD_HALF + 60.0:
			decals.append([_decal("crater", rng), cp.floor(), 0.0, false, Color.WHITE])


## Landmark set-pieces (bible: max 1 per screen; the world composed as rooms
## round one landmark). The hero prop stands at the back of the room and the
## dressing rings a clearing of ~160 px, where the extract pads land (they are
## rolled within 80 px of the landmark). Entries: [kind, dx, dy] in world px;
## "@x" = floor decal. The first entry is the hero prop (label anchor).
const LANDMARK_SETS := [
	## 0 wreck field (Scrapyard, Convoy Wreck)
	[["%big", 0, -215], ["%car", -235, -50], ["%car", 235, -60], ["barrels_rust", 240, 100], ["tire_stack", -290, 50],
		["scrap_pile", 160, 200], ["%car", -200, 190], ["?%moto", 60, 160], ["tire", 110, -300], ["@oil", 20, -140], ["@oil", -110, -20],
		["@tracksh", -40, 40], ["@debris", 80, 100], ["@scrap", -60, -60], ["@stain", 0, -150], ["@rubble", 200, 20],
		["@debris", -180, 110]],
	## 1 garage / wall ruin (Flood Garage)
	[["wall_ruin_b", 0, -210], ["wall_ruin", -125, -200], ["ruin_pillar", 130, -200], ["wall_collapsed", 230, 60],
		["barrels_rust", -240, 60], ["rubble_chunk", -150, 180], ["crate_stack", 220, -140], ["@stain", -20, -110],
		["@rubble", 60, 40], ["@rubble", -90, 30], ["@crack", 30, 110], ["@debris", -200, -60], ["@rubble", 120, -120]],
	## 2 signal tower
	[["signal_tower", 0, -235], ["fence_broken", -210, -150], ["fence_broken", 210, -140], ["barrels_rust", 200, 80],
		["sign_post", -190, 90], ["crate_stack", -250, -20], ["scrap_pile", 150, 200], ["@tracksv", 30, 40], ["@pebbles", -30, -100],
		["@debris", 70, 90], ["@crack", -110, 120], ["@rubble", 20, -130]],
	## 3 ruined arcade (Neon Market, Herb Cache)
	[["shop_ruin", 0, -225], ["street_lamp", -200, -120], ["street_lamp", 205, -110], ["ruin_pillar", -240, 100],
		["sandbags", -150, 190], ["rock_large", 230, 130], ["dead_bush", -260, -10], ["@rubble", 0, -100], ["@pebbles", 0, 30],
		["@bones", 60, 50], ["@tufts", -80, 110], ["@debris", 120, -40], ["@rubble", -120, -60]],
]


func _maybe_landmark_sprite(chunk: Node2D, coord: Vector2i) -> void:
	for lm in landmarks:
		var lp: Vector2 = lm["position"]
		var lc := _chunk_coord(lp)
		if lc == coord:
			var k := int(lm["kind"])
			var set_rng := _rng_for(coord, 97)
			_gid += 1
			for e in LANDMARK_SETS[k]:
				var kind := str(e[0])
				var wp := lp + Vector2(float(e[1]), float(e[2]))
				if kind.begins_with("?"):
					if set_rng.randf() > 0.55:
						continue
					kind = kind.substr(1)
				if kind.begins_with("@"):
					(chunk as WastelandChunk).add_decal([_decal(kind.substr(1), set_rng), (wp - chunk.position).floor(), 0.0, false, Color.WHITE])
					continue
				if kind.begins_with("%"):
					kind = _veh(kind, set_rng)
				var tex := _tex(kind)
				if tex == null:
					continue
				var local := snap(wp - chunk.position)
				var sp := prop_sprite(kind, tex, local)
				var m := PropMeta.info(kind)
				if kind == "street_lamp" and m.has("light"):
					LightFx.lamp(chunk, local + (m["light"] as Vector2) * UnitAnim.TEXEL, 150.0, Color(1.0, 0.75, 0.25, 0.38), 0.05)
				add_prop_shadow(chunk, kind, local)
				add_prop_block(chunk, kind, local)
				chunk.add_child(sp)
				_register(chunk, kind, local, tex, _gid)
			var hero: Array = LANDMARK_SETS[k][0]
			var sp_pos := snap(lp + Vector2(float(hero[1]), float(hero[2])) - chunk.position)
			var sp_tex := _tex(str(hero[0]) if not str(hero[0]).begins_with("%") else "wreck_bus")
			var label := Label.new()
			label.text = str(lm["name"])
			label.position = sp_pos + Vector2(-40, -sp_tex.get_height() * 0.5 * UnitAnim.TEXEL - 18.0)
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
			label.z_index = 3
			chunk.add_child(label)
