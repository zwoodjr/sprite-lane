class_name GroundField
extends RefCounted

## CPU mirror of ground.gdshader: same hash / value noise / thresholds, so
## props and decals can be placed by biome, riverbed and road. Also builds the
## run's seeded road network (long bending polylines crossing the world).

enum Biome { EARTH, SAND, SCRUB, RUBBLE }

const ROAD_HALF := 40.0
const ROAD_STEP := 700.0
const ROAD_STEPS := 9 ## per direction from the anchor (±6300 px)

var seed_off := Vector2.ZERO
## Each road: {"pts": PackedVector2Array, "off": PackedFloat32Array (arc length at each point)}
var roads: Array[Dictionary] = []


func _init(run_seed: int) -> void:
	seed_off = Vector2(fposmod(float(run_seed) * 0.6180339, 1.0) * 1000.0, fposmod(float(run_seed) * 0.4142135, 1.0) * 1000.0)
	_build_roads(run_seed)


static func _fract(x: float) -> float:
	return x - floor(x)


static func hash12(p: Vector2) -> float:
	var x := _fract(p.x * 0.1031)
	var y := _fract(p.y * 0.1031)
	var z := _fract(p.x * 0.1031)
	var dd := x * (y + 33.33) + y * (z + 33.33) + z * (x + 33.33)
	x += dd
	y += dd
	z += dd
	return _fract((x + y) * z)


static func vnoise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3, 3) - 2.0 * f)
	var a := hash12(i)
	var b := hash12(i + Vector2(1, 0))
	var c := hash12(i + Vector2(0, 1))
	var d := hash12(i + Vector2(1, 1))
	return lerpf(lerpf(a, b, u.x), lerpf(c, d, u.x), u.y)


func biome_at(p: Vector2) -> int:
	var wq := (vnoise(p / 350.0 + seed_off + Vector2(91, 91)) - 0.5) * 320.0
	var pw := p + Vector2(wq, -wq)
	var m := vnoise(pw / 1300.0 + seed_off)
	var n := vnoise(pw / 1100.0 + Vector2(seed_off.y, seed_off.x) + Vector2(57, 57))
	if n > 0.69:
		return Biome.RUBBLE
	if m > 0.64:
		return Biome.SAND
	if m < 0.32:
		return Biome.SCRUB
	return Biome.EARTH


func is_riverbed(p: Vector2) -> bool:
	var gate := vnoise(p / 2400.0 + Vector2(seed_off.y, seed_off.x) * 0.9 + Vector2(13, 13))
	if gate <= 0.58:
		return false
	var r := vnoise(p / 1100.0 + seed_off * 0.7 + Vector2(200, 200)) * 0.85 + vnoise(p / 300.0 + seed_off + Vector2(31, 31)) * 0.15
	var width := 0.02 * smoothstep(0.58, 0.65, gate)
	return absf(r - 0.5) < width


func _build_roads(run_seed: int) -> void:
	roads.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 48271 + 101
	for i in range(3):
		var ang := rng.randf() * TAU
		## Road 0 runs close past the drop point so it's seen early.
		var off := rng.randf_range(180.0, 320.0) if i == 0 else rng.randf_range(900.0, 2600.0)
		var nrm := Vector2(cos(ang + PI * 0.5), sin(ang + PI * 0.5))
		var anchor := nrm * off * (1.0 if rng.randf() < 0.5 else -1.0)
		var fwd: Array[Vector2] = [anchor]
		var back: Array[Vector2] = []
		for dir_sign in [1.0, -1.0]:
			var h := ang if dir_sign > 0.0 else ang + PI
			var p := anchor
			for s in range(ROAD_STEPS):
				h += rng.randf_range(-0.22, 0.22)
				p += Vector2(cos(h), sin(h)) * ROAD_STEP
				if dir_sign > 0.0:
					fwd.append(p)
				else:
					back.append(p)
		back.reverse()
		var pts := PackedVector2Array(back + fwd)
		var offs := PackedFloat32Array()
		var acc := 0.0
		for k in range(pts.size()):
			if k > 0:
				acc += pts[k].distance_to(pts[k - 1])
			offs.append(acc)
		roads.append({"pts": pts, "off": offs})


## Road segments touching `rect` (grown by `margin`): [{a, b, off}] (max 8).
func segments_in(rect: Rect2, margin: float = 40.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := rect.grow(margin + ROAD_HALF)
	for road in roads:
		var pts: PackedVector2Array = road["pts"]
		var offs: PackedFloat32Array = road["off"]
		for k in range(pts.size() - 1):
			var a := pts[k]
			var b := pts[k + 1]
			var bb := Rect2(a, Vector2.ZERO).expand(b)
			if not bb.intersects(r):
				continue
			if not _seg_hits_rect(a, b, r):
				continue
			out.append({"a": a, "b": b, "off": offs[k]})
			if out.size() >= 8:
				return out
	return out


static func _seg_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	## Sample along the segment (segments are long, rects are chunk-sized).
	var n := int(ceil(a.distance_to(b) / 64.0))
	for i in range(n + 1):
		if r.has_point(a.lerp(b, float(i) / float(n))):
			return true
	return false


## Distance from `p` to the nearest road centre line (INF if none in `segs`).
static func road_dist(p: Vector2, segs: Array[Dictionary]) -> float:
	var best := INF
	for s in segs:
		var cp := Geometry2D.get_closest_point_to_segment(p, s["a"], s["b"])
		best = minf(best, p.distance_to(cp))
	return best
