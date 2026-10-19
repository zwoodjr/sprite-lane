class_name WastelandChunk
extends Node2D

## Draws the quiet ground texture for one 512 px chunk.

var _tiles: Array[Texture2D] = []
var _coord: Vector2i
var _run_seed: int = 1
var _noise: FastNoiseLite
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
	## One seamless low-contrast 512 px texture per chunk (1:1 world scale) so
	## heroes, mobs and pickups pop off the floor. A very gentle large-scale
	## tint (from terrain noise) keeps it from reading as a repeating grid.
	var tint := Color.WHITE
	if _noise:
		var c := Vector2(_coord.x * CHUNK_SIZE + CHUNK_SIZE * 0.5, _coord.y * CHUNK_SIZE + CHUNK_SIZE * 0.5)
		var nz := _noise.get_noise_2d(c.x, c.y)
		var k := 1.0 + nz * 0.04
		tint = Color(k, k, k * (1.0 - nz * 0.02))
	draw_texture(_tiles[0], Vector2.ZERO, tint)
