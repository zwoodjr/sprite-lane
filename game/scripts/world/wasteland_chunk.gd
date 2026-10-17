class_name WastelandChunk
extends Node2D

## Draws a dust tile grid for one chunk (batched _draw for mobile perf).

var _tiles: Array[Texture2D] = []
var _coord: Vector2i
var _run_seed: int = 1
const TILE := 64
const CHUNK_SIZE := 512


func configure(world: Node, coord: Vector2i, run_seed: int, tiles: Array[Texture2D]) -> void:
	_coord = coord
	_run_seed = run_seed
	_tiles = tiles
	queue_redraw()


func _draw() -> void:
	if _tiles.is_empty():
		draw_rect(Rect2(Vector2.ZERO, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(0.28, 0.20, 0.14))
		return
	var n := int(CHUNK_SIZE / TILE)
	for x in range(n):
		for y in range(n):
			var h := ((_coord.x * 73856093) ^ (_coord.y * 19349663) ^ (x * 83492791) ^ (y * 5039) ^ _run_seed) & 0x7fffffff
			var tex := _tiles[h % _tiles.size()]
			draw_texture(tex, Vector2(x * TILE, y * TILE))
