class_name UnitAnim
extends RefCounted

## Shared in-run walk cycle for sheet-locked unit sprites.
## Uses a 4-frame horizontal strip (`*_walk.png`) when present; otherwise
## falls back to procedural bob/squash on the still. Never redesigns art.

const FRAME_COUNT := 4
const FRAME_SIZE := 96

var _frames: Array[Texture2D] = []
var _has_strip: bool = false
var _phase: float = 0.0
var _frame_i: int = 0
var _base_scale: float = 1.0
var _lean: float = 0.0


func setup_from_walk_path(walk_path: String, fallback_still: Texture2D = null) -> void:
	_frames.clear()
	_has_strip = false
	if walk_path != "" and ResourceLoader.exists(walk_path):
		var tex := load(walk_path) as Texture2D
		if tex != null and tex.get_width() >= FRAME_SIZE * 2:
			_slice_strip(tex)
			_has_strip = _frames.size() >= 2
	if not _has_strip and fallback_still != null:
		_frames = [fallback_still]


func _slice_strip(tex: Texture2D) -> void:
	var fw := FRAME_SIZE
	## Support non-96 strips: divide width by 4.
	if tex.get_width() % FRAME_COUNT == 0:
		fw = int(tex.get_width() / float(FRAME_COUNT))
	var fh := tex.get_height()
	for i in range(FRAME_COUNT):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		_frames.append(at)


func set_base_scale(s: float) -> void:
	_base_scale = s


func has_frames() -> bool:
	return _frames.size() > 0


func tick(sprite: Sprite2D, velocity: Vector2, delta: float, opts: Dictionary = {}) -> void:
	if sprite == null:
		return
	var move_thresh := float(opts.get("move_thresh", 28.0))
	var speed_ref := float(opts.get("speed_ref", 200.0))
	var bob_amp := float(opts.get("bob_amp", 3.0))
	## Pets / quadrupeds: keep near-zero so strip frames aren't re-hotdog'd.
	var squash_amp := float(opts.get("squash_amp", 0.045))
	var lean_amp := float(opts.get("lean_amp", 0.08))
	var attack := bool(opts.get("attack", false))
	var moving := velocity.length() > move_thresh
	## Face travel direction when moving; keep last facing when idle.
	if moving and absf(velocity.x) > 8.0:
		sprite.flip_h = velocity.x < 0.0
	var bs := _base_scale
	if moving:
		var spd := clampf(velocity.length() / maxf(speed_ref, 1.0), 0.45, 1.8)
		_phase += delta * 10.0 * spd
		if _has_strip and _frames.size() >= FRAME_COUNT:
			## Cycle 1→2→3→2 (skip hard idle snap) while moving.
			var cycle := [1, 2, 3, 2]
			_frame_i = cycle[int(_phase) % cycle.size()]
			sprite.texture = _frames[_frame_i]
		## Procedural secondary: bob + squash + lean into motion
		sprite.position.y = -absf(sin(_phase)) * bob_amp
		var squash := sin(_phase * 2.0)
		sprite.scale = Vector2(
			bs * (1.0 + squash * squash_amp),
			bs * (1.0 - squash * squash_amp)
		)
		var want_lean := clampf(velocity.x / maxf(speed_ref, 1.0), -1.0, 1.0) * lean_amp
		_lean = lerpf(_lean, want_lean, clampf(delta * 10.0, 0.0, 1.0))
		sprite.rotation = _lean
	else:
		if _has_strip and _frames.size() > 0:
			sprite.texture = _frames[0]
		sprite.position.y = lerpf(sprite.position.y, 0.0, clampf(delta * 12.0, 0.0, 1.0))
		sprite.scale = sprite.scale.lerp(Vector2.ONE * bs, clampf(delta * 10.0, 0.0, 1.0))
		_lean = lerpf(_lean, 0.0, clampf(delta * 10.0, 0.0, 1.0))
		sprite.rotation = _lean
	## Cheap attack punch: brief stretch toward facing
	if attack:
		sprite.scale = Vector2(bs * 1.12, bs * 0.92)
		sprite.position.y -= 2.0
