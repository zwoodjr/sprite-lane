class_name WastelandChunk
extends Node2D

## One 512 px chunk of floor. The ground (biomes, riverbeds, roads — all in
## world space so they run across borders) and the clustered decals are baked
## ONCE into a SubViewport texture when the chunk streams in; every frame after
## that the chunk is a single plain texture draw (as cheap as the old floor).

const CHUNK_SIZE := 512
## Bake resolution: native density (one baked pixel = one screen pixel).
const BAKE_PX := 692
## Decal atlas texels are native too: one texel = one bake px.
const DECAL_TEXEL := float(CHUNK_SIZE) / float(BAKE_PX)

var _coord: Vector2i
var _vp: SubViewport
var _atlas: Texture2D
## [region: Rect2, pos: Vector2, rot: float, flip: bool, tint: Color]
var _decal_list: Array = []
var _decals: Node2D


func configure(coord: Vector2i, mat: ShaderMaterial, atlas: Texture2D, decal_list: Array) -> void:
	_coord = coord
	_atlas = atlas
	_decal_list = decal_list
	_vp = SubViewport.new()
	_vp.name = "Bake"
	_vp.size = Vector2i(BAKE_PX, BAKE_PX)
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	## Baked later via bake() — the world staggers bakes (one per frame).
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var ground := Node2D.new()
	ground.material = mat
	ground.draw.connect(func() -> void:
		ground.draw_rect(Rect2(Vector2.ZERO, Vector2(BAKE_PX, BAKE_PX)), Color.WHITE))
	_vp.add_child(ground)
	_decals = Node2D.new()
	## Decals draw in bake-pixel space (see _draw_decals).
	_decals.draw.connect(_draw_decals)
	_vp.add_child(_decals)
	add_child(_vp)
	queue_redraw()


## Queue one more floor decal (before the bake): [region, pos, rot, flip, tint].
func add_decal(d: Array) -> void:
	_decal_list.append(d)


## Render the floor + decals into the chunk texture (once).
func bake() -> void:
	if _decals:
		_decals.queue_redraw()
	if _vp:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _draw() -> void:
	if _vp:
		draw_texture_rect(_vp.get_texture(), Rect2(Vector2.ZERO, Vector2(CHUNK_SIZE, CHUNK_SIZE)), false)


func _draw_decals() -> void:
	if _atlas == null:
		return
	for d in _decal_list:
		var region: Rect2 = d[0]
		var pos: Vector2 = d[1]
		var tint: Color = d[4]
		## Bake-pixel space: one atlas texel = one bake px, top-left snapped to a
		## whole pixel (no rotation: pixel art is never rotated, bible 1.1).
		var size := region.size
		var half := size * 0.5 * DECAL_TEXEL
		if not Rect2(half, Vector2(CHUNK_SIZE, CHUNK_SIZE) - half * 2.0).has_point(pos):
			continue ## would be clipped by the chunk edge
		var tl := (pos / DECAL_TEXEL - size * 0.5).floor()
		## `flip` is ignored: decals are lit top-left and are never mirrored.
		_decals.draw_texture_rect_region(_atlas, Rect2(tl, size), region, tint)
