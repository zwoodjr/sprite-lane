class_name WastelandChunk
extends Node2D

## Draws a dust tile grid for one chunk (batched _draw for mobile perf).

var _tiles: Array[Texture2D] = []
var _coord: Vector2i
var _run_seed: int = 1
var _noise: FastNoiseLite
const TILE := 64
const CHUNK_SIZE := 512


func configure(world: Node, coord: Vector2i, run_seed: int, tiles: Array[Texture2D]) -> void:
	_coord = coord
	_run_seed = run_seed
	_tiles = tiles
	_noise = world.get("terrain_noise")
	queue_redraw()


func _draw() -> void:
	if _tiles.is_empty():
		draw_rect(Rect2(Vector2.ZERO, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(0.28, 0.20, 0.14))
		return
	var n := int(CHUNK_SIZE / TILE)
	for x in range(n):
		for y in range(n):
			var h := ((_coord.x * 73856093) ^ (_coord.y * 19349663) ^ (x * 83492791) ^ (y * 5039) ^ _run_seed) & 0x7fffffff
			## Mostly plain tiles; detail tiles sprinkled in.
			var idx := 0 if (h % 100) < 55 else h % _tiles.size()
			var tex := _tiles[idx]
			## Large soft patches (darker hardpan / pale sand) break up the grid.
			var tint := Color.WHITE
			if _noise:
				var wx := float(_coord.x * CHUNK_SIZE + x * TILE)
				var wy := float(_coord.y * CHUNK_SIZE + y * TILE)
				var nz := _noise.get_noise_2d(wx, wy)
				var k := 1.0 + nz * 0.09
				tint = Color(k, k * (1.0 - nz * 0.03), k * (1.0 - nz * 0.06))
			draw_texture(tex, Vector2(x * TILE, y * TILE), tint)
