class_name WastelandChunk
extends Node2D

## One 512 px chunk of floor. The ground itself is drawn by ground.gdshader in
## world space (biomes, riverbeds, roads all continuous across borders); a child
## layer draws the clustered small decals from one atlas (single batch).

const CHUNK_SIZE := 512

var _coord: Vector2i
var _decals: Node2D
var _atlas: Texture2D
## [region: Rect2, pos: Vector2, rot: float, flip: bool, tint: Color]
var _decal_list: Array = []


func configure(coord: Vector2i, mat: ShaderMaterial, atlas: Texture2D, decal_list: Array) -> void:
	_coord = coord
	material = mat
	_atlas = atlas
	_decal_list = decal_list
	_decals = Node2D.new()
	_decals.name = "Decals"
	_decals.z_index = 1
	_decals.draw.connect(_draw_decals)
	add_child(_decals)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(0.33, 0.26, 0.2))


func _draw_decals() -> void:
	if _atlas == null:
		return
	for d in _decal_list:
		var region: Rect2 = d[0]
		var pos: Vector2 = d[1]
		var rot: float = d[2]
		var flip: bool = d[3]
		var tint: Color = d[4]
		var size := region.size
		if flip:
			size.x = -size.x
		if rot != 0.0:
			_decals.draw_set_transform(pos, rot, Vector2.ONE)
			_decals.draw_texture_rect_region(_atlas, Rect2(-size * 0.5, size), region, tint)
			_decals.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_decals.draw_texture_rect_region(_atlas, Rect2((pos - size * 0.5).floor(), size), region, tint)
