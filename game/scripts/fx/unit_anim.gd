class_name UnitAnim
extends RefCounted

## State animator for the per-state art strips (`<prefix>_<state>.png`).
## Each strip is one row of square frames (128 / 192 / 256 px); the frame count
## is width / height. States are discovered from the files that exist, so a
## unit only plays what its art set covers (bosses: roar, Dune-Serpent: emerge,
## pets: sit / rampage / bark / drop / charge / impact).
##
## Drives a plain Sprite2D (hframes), no SpriteFrames resources:
##   - per-state fps (idle 8, walk 14 × speed, windup over the enemy's windup
##     time, attack 12, hit 12, death 10), looping vs one-shot vs hold-last
##   - feet anchored: frame bottom − 10 px sits on `feet_y` of the unit
##   - frame size → world size via world_frame_px (per-unit scale)
##   - facing flip, white hit flash (shared shader, so batching survives)
## `frame_event(state, frame)` fires whenever a frame is shown (frame 0
## included), which is how weapon/attack JSON hit frames trigger damage.

signal frame_event(state: String, frame: int)
signal finished(state: String)

const FEET_FROM_BOTTOM := 10.0
const STATE_NAMES := [
	"idle", "walk", "windup", "attack", "hit", "death", "dash", "ability",
	"sit", "roar", "emerge", "rampage", "bark", "drop", "charge", "impact",
]
const DEFAULT_FPS := {
	"idle": 8.0, "walk": 14.0, "windup": 10.0, "attack": 12.0, "hit": 12.0,
	"death": 10.0, "dash": 24.0, "ability": 12.0, "sit": 6.0, "roar": 10.0,
	"emerge": 10.0, "rampage": 12.0, "bark": 12.0, "drop": 10.0,
	"charge": 14.0, "impact": 12.0,
}
## Loop forever until something else is played.
const LOOPING := {"idle": true, "walk": true, "rampage": true, "charge": true}
## One-shot that freezes on its last frame (never returns to locomotion).
const HOLD_LAST := {"death": true, "sit": true}

## prefix -> {state: {"tex": Texture2D, "n": int}} ; shared by every unit.
static var _cache: Dictionary = {}
static var _flash_mat: ShaderMaterial = null

var sprite: Sprite2D
var states: Dictionary = {}
var frame_size: int = 128
var state: String = ""
var frame: int = 0
var feet_y: float = 0.0

var _t: float = 0.0
var _fps: float = 8.0
var _done: bool = false
var _loco: String = "idle"
var _loco_fps_mult: float = 1.0
var _flash_left: float = 0.0
var _px_scale: float = 1.0


## Load (and cache) every state strip for `prefix` (e.g.
## "res://assets/sprites/enemies/rad_gator/rad_gator").
static func load_states(prefix: String) -> Dictionary:
	if _cache.has(prefix):
		return _cache[prefix]
	var out: Dictionary = {}
	for s in STATE_NAMES:
		var p := "%s_%s.png" % [prefix, s]
		if not ResourceLoader.exists(p):
			continue
		var tex := load(p) as Texture2D
		if tex == null or tex.get_height() <= 0:
			continue
		out[s] = {"tex": tex, "n": maxi(1, int(round(float(tex.get_width()) / float(tex.get_height()))))}
	_cache[prefix] = out
	return out


static func has_art(prefix: String) -> bool:
	return ResourceLoader.exists(prefix + "_idle.png")


## Read a JSON sidecar (weapon / attack data). Empty dict when missing.
static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func flash_material() -> ShaderMaterial:
	if _flash_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 t = texture(TEXTURE, UV);\n\tCOLOR = vec4(mix(t.rgb, vec3(1.0), 0.9), t.a * COLOR.a);\n}\n"
		_flash_mat = ShaderMaterial.new()
		_flash_mat.shader = sh
	return _flash_mat


## world_frame_px: how many world px one full frame spans on screen.
## feet: local y (unit space) where the feet should stand.
func setup(spr: Sprite2D, prefix: String, world_frame_px: float, feet: float = 0.0) -> bool:
	sprite = spr
	states = load_states(prefix)
	if states.is_empty() or sprite == null:
		return false
	var any: Dictionary = states.get("idle", states.values()[0])
	frame_size = (any["tex"] as Texture2D).get_height()
	feet_y = feet
	_px_scale = world_frame_px / float(frame_size)
	sprite.centered = true
	sprite.scale = Vector2.ONE * _px_scale
	sprite.rotation = 0.0
	sprite.position = Vector2(0.0, feet_y)
	sprite.offset = Vector2(0.0, -(frame_size * 0.5 - FEET_FROM_BOTTOM))
	state = ""
	_loco = "idle"
	play("idle")
	return true


func is_ready() -> bool:
	return sprite != null and not states.is_empty()


func has_state(s: String) -> bool:
	return states.has(s)


func frame_count(s: String) -> int:
	return int(states[s]["n"]) if states.has(s) else 0


func px_scale() -> float:
	return _px_scale


## Play `s`. fps <= 0 → state default. Looping states loop; others run once
## then fall back to locomotion (or hold the last frame for death / sit).
func play(s: String, fps: float = -1.0, restart: bool = true) -> void:
	if not states.has(s):
		return
	if s == state and not restart and not _done:
		if fps > 0.0:
			_fps = fps
		return
	state = s
	_fps = fps if fps > 0.0 else float(DEFAULT_FPS.get(s, 10.0))
	_t = 0.0
	_done = false
	_show(0)


## Play `s` so the whole strip lasts `seconds`.
func play_over(s: String, seconds: float) -> void:
	var n := frame_count(s)
	if n <= 0:
		return
	play(s, float(n) / maxf(seconds, 0.03))


## Locomotion state shown whenever no one-shot is running.
func set_locomotion(s: String, fps_mult: float = 1.0) -> void:
	if not states.has(s):
		s = "idle"
	_loco = s
	_loco_fps_mult = fps_mult
	## Death never yields; a finished sit holds until the unit moves.
	if state == "death" or (is_busy() and state != "sit"):
		return
	if state == "sit" and s == "idle":
		return
	if state != s:
		play(s, float(DEFAULT_FPS.get(s, 8.0)) * fps_mult)
	else:
		_fps = float(DEFAULT_FPS.get(s, 8.0)) * fps_mult


## True while a non-looping state is still playing.
func is_busy() -> bool:
	return state != "" and not LOOPING.has(state) and not _done


func is_playing(s: String) -> bool:
	return state == s and (LOOPING.has(s) or not _done)


func set_facing(left: bool) -> void:
	if sprite:
		sprite.flip_h = left


func facing_left() -> bool:
	return sprite != null and sprite.flip_h


func flash(dur: float = 0.07) -> void:
	_flash_left = maxf(_flash_left, dur)
	if sprite:
		sprite.material = flash_material()


func tick(delta: float) -> void:
	if sprite == null or state == "":
		return
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			sprite.material = null
	if _done:
		return
	var n := frame_count(state)
	_t += delta * _fps
	var f := int(_t)
	if f >= n:
		if LOOPING.has(state):
			_t = fmod(_t, float(n))
			f = int(_t)
		else:
			var ended := state
			_done = true
			if HOLD_LAST.has(state):
				_show(n - 1, false)
			else:
				## Back to locomotion (on this same frame, no blank tick).
				play(_loco, float(DEFAULT_FPS.get(_loco, 8.0)) * _loco_fps_mult)
			finished.emit(ended)
			return
	if f != frame:
		_show(f)


func _show(f: int, emit: bool = true) -> void:
	var entry: Dictionary = states[state]
	var tex: Texture2D = entry["tex"]
	var n := int(entry["n"])
	f = clampi(f, 0, n - 1)
	if sprite.texture != tex or sprite.hframes != n:
		sprite.frame = 0
		sprite.texture = tex
		sprite.hframes = n
		sprite.vframes = 1
	sprite.frame = f
	frame = f
	if emit:
		frame_event.emit(state, f)


## Frame-pixel point (x right, y down, origin top-left of the frame) → the
## unit's local space, honouring scale, feet anchor and facing flip.
func frame_to_local(px: Vector2) -> Vector2:
	var x := (px.x - frame_size * 0.5) * _px_scale
	if sprite != null and sprite.flip_h:
		x = -x
	var y := (px.y - (frame_size - FEET_FROM_BOTTOM)) * _px_scale + feet_y
	return Vector2(x, y)


## JSON angle (degrees, 0 = +x, CCW positive with y up) → world-space
## direction in Godot coordinates (y down), mirrored with facing.
func angle_to_dir(deg: float) -> Vector2:
	var d := Vector2(cos(deg_to_rad(deg)), -sin(deg_to_rad(deg)))
	if sprite != null and sprite.flip_h:
		d.x = -d.x
	return d


## World height (px) of the frame — for hp bars / labels.
func world_frame_px() -> float:
	return frame_size * _px_scale
