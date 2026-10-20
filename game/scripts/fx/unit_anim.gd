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
##
## Optional sidecar `<prefix>_anim.json`: {"fps": {state: fps}, "alive": {...}}
## overrides the default fps per unit (smoother idle / walk with more frames).
## "Alive" layer (subtle, data-driven, all units): random start phase + small
## rate jitter on looping states so packs never animate in lockstep, a lean
## into the move direction (rotation about the feet) and a squash-and-recover
## on hits / stops (scale about the feet).

signal frame_event(state: String, frame: int)
signal finished(state: String)

const FEET_FROM_BOTTOM := 10.0
## Visual tier: every unit / prop texel draws as exactly one screen pixel.
## The match camera zoom (world px -> screen px) ...
const SCREEN_ZOOM := 1.35
## ... so one art texel spans this many world px.
const TEXEL := 1.0 / SCREEN_ZOOM
## Units / props grew ~1.5x in world space when they went native (bodies were
## drawn at ~0.44-0.5 world px per texel); gameplay body sizes scale with it.
const BODY_K := 1.4
## World art sized before the visual tier (props, landmarks: 0.5 world px per
## painted texel) grows by this to reach native density.
const ART_GROW := 2.0 * TEXEL


## World scale for a prop texture: the painted 2x set (props_hd, and every
## native-res landmark) draws 1 texel = 1 screen px; the old 1x pixel props
## draw at an exact 2x so they keep their relative size.
static func prop_scale(tex: Texture2D) -> float:
	if tex and tex.resource_path.contains("/props/"):
		return 2.0 * TEXEL
	return TEXEL


static var _shadow_tex: Texture2D = null


## Soft cool contact shadow under a unit's feet (one shared radial texture).
## Returns the Sprite2D (child of `parent`, drawn below its siblings).
static func add_contact_shadow(parent: Node2D, width: float, feet_y: float, alpha: float = 0.5) -> Sprite2D:
	if _shadow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.05, 0.04, 0.08, 1.0))
		g.add_point(0.45, Color(0.05, 0.04, 0.08, 0.7))
		g.set_color(g.get_point_count() - 1, Color(0.05, 0.04, 0.08, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_shadow_tex = t
	var s := Sprite2D.new()
	s.name = "ContactShadow"
	s.texture = _shadow_tex
	s.scale = Vector2(width / 64.0, width * 0.3 / 64.0)
	s.position = Vector2(3.0, feet_y - 1.0)
	s.modulate = Color(1, 1, 1, alpha)
	s.z_index = -1
	parent.add_child(s)
	parent.move_child(s, 0)
	return s


## World size of a `px`-texel art span drawn at the native density.
static func native(px: float) -> float:
	return px * TEXEL
const STATE_NAMES := [
	"idle", "walk", "windup", "attack", "hit", "death", "dash", "ability",
	"sit", "roar", "emerge", "rampage", "bark", "drop", "charge", "impact",
	"sit_idle",
]
const DEFAULT_FPS := {
	"idle": 8.0, "walk": 14.0, "windup": 10.0, "attack": 12.0, "hit": 12.0,
	"death": 10.0, "dash": 24.0, "ability": 12.0, "sit": 6.0, "roar": 10.0,
	"emerge": 10.0, "rampage": 12.0, "bark": 12.0, "drop": 10.0,
	"charge": 14.0, "impact": 12.0, "sit_idle": 10.0,
}
## Loop forever until something else is played.
const LOOPING := {"idle": true, "walk": true, "rampage": true, "charge": true, "sit_idle": true}
## One-shot that freezes on its last frame (never returns to locomotion).
const HOLD_LAST := {"death": true, "sit": true}
## A finished one-shot that hands over to a resting loop (sit -> sit_idle).
const REST_LOOP := {"sit": "sit_idle"}
## Alive layer defaults (per unit override: "alive" in <prefix>_anim.json).
##   lean: max rotation (rad) into the move direction at ref_speed
##   lean_rate: how fast the lean follows (1/s)
##   rate_jitter: ± fraction applied to looping fps per unit
##   hit_squash / stop_squash: scale kick (x wider, y shorter), springs back
const ALIVE := {
	"lean": 0.07, "lean_rate": 10.0, "ref_speed": 220.0, "rate_jitter": 0.06,
	"hit_squash": 0.14, "stop_squash": 0.05, "squash_freq": 9.0, "squash_damp": 0.35,
}

## prefix -> {state: {"tex": Texture2D, "n": int}} ; shared by every unit.
static var _cache: Dictionary = {}
static var _flash_mat: ShaderMaterial = null
## prefix -> "alive" overrides from the sidecar.
static var _alive_cache: Dictionary = {}

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
var _alive: Dictionary = ALIVE
var _rate: float = 1.0
var _lean: float = 0.0
var _lean_target: float = 0.0
var _sq: float = 0.0
var _sq_v: float = 0.0


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
	var side := load_json(prefix + "_anim.json")
	var fps_over: Dictionary = side.get("fps", {})
	for s in fps_over:
		if out.has(s):
			out[s]["fps"] = float(fps_over[s])
	_alive_cache[prefix] = side.get("alive", {})
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
	_alive = ALIVE.duplicate()
	_alive.merge(_alive_cache.get(prefix, {}), true)
	if states.is_empty() or sprite == null:
		return false
	_rate = 1.0 + randf_range(-1.0, 1.0) * float(_alive["rate_jitter"])
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


## fps for `s`: the unit's sidecar value, else the shared default.
func state_fps(s: String) -> float:
	if states.has(s) and states[s].has("fps"):
		return float(states[s]["fps"])
	return float(DEFAULT_FPS.get(s, 10.0))


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
	var prev := state
	state = s
	_fps = fps if fps > 0.0 else state_fps(s)
	_t = 0.0
	_done = false
	if LOOPING.has(s):
		_fps *= _rate
		## Entering a loop from nothing / another loop: random phase, so a
		## pack of the same unit never breathes or trots in lockstep.
		if prev == "" or LOOPING.has(prev):
			_t = randf() * float(frame_count(s))
	_show(int(_t))


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
	if _loco == "walk" and s == "idle":
		squash(float(_alive["stop_squash"]))
	_loco = s
	_loco_fps_mult = fps_mult
	## Death never yields; a finished sit holds until the unit moves.
	if state == "death" or (is_busy() and state != "sit"):
		return
	if (state == "sit" or state == "sit_idle") and s == "idle":
		return
	if state != s:
		play(s, state_fps(s) * fps_mult)
	else:
		_fps = state_fps(s) * fps_mult * _rate


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
	squash(float(_alive["hit_squash"]))


## Squash kick (positive = wider + shorter), springs back with overshoot.
func squash(amount: float) -> void:
	_sq_v -= amount * TAU * float(_alive["squash_freq"])


## Feed the unit's velocity each frame for the lean-into-motion layer.
func set_motion(vel: Vector2, ref_speed: float = -1.0) -> void:
	var ref := ref_speed if ref_speed > 0.0 else float(_alive["ref_speed"])
	_lean_target = clampf(vel.x / maxf(ref, 1.0), -1.0, 1.0) * float(_alive["lean"])


func _alive_tick(delta: float) -> void:
	if state == "death":
		_lean_target = 0.0
	_lean = lerpf(_lean, _lean_target, clampf(delta * float(_alive["lean_rate"]), 0.0, 1.0))
	var w := TAU * float(_alive["squash_freq"])
	var steps := 4
	var h := delta / float(steps)
	for _i in steps:
		var a := -w * w * _sq - 2.0 * float(_alive["squash_damp"]) * w * _sq_v
		_sq_v += a * h
		_sq += _sq_v * h
	_sq = clampf(_sq, -0.3, 0.3)
	sprite.rotation = _lean
	## Volume-preserving squash about the feet (sprite origin = feet).
	sprite.scale = Vector2(_px_scale * (1.0 - _sq), _px_scale * (1.0 + _sq))


func tick(delta: float) -> void:
	if sprite == null or state == "":
		return
	_alive_tick(delta)
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
			if REST_LOOP.has(state) and states.has(REST_LOOP[state]):
				play(REST_LOOP[state])
			elif HOLD_LAST.has(state):
				_show(n - 1, false)
			else:
				## Back to locomotion (on this same frame, no blank tick).
				play(_loco, state_fps(_loco) * _loco_fps_mult)
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
