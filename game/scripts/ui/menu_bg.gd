extends Control

## Animated menu backdrop with depth: the painted dusk wasteland
## (tools/gen_ui_kit.py) drifts slowly as the far layer, two hard-edged dune
## silhouettes slide past at mid and near speed, and three layers of dust
## motes (1 / 2 / 3 px, slow to fast) blow across. The sun glow breathes.
## The only soft gradient is the backdrop itself (bible §1.5). Cheap on mobile.

const BACKDROP := "res://assets/sprites/ui/menu_backdrop.png"
const DUNE_MID := Color(0.227, 0.176, 0.153, 0.85) ## EARTH 0
const DUNE_NEAR := Color(0.122, 0.102, 0.114, 0.95) ## ASH 0
const MOTE := Color(1.0, 0.95, 0.75) ## DUST 4

var _t: float = 0.0
var _motes: Array[Dictionary] = []
var _tex: Texture2D
var _dunes: Array = [] ## [[heights...], speed, base_frac, color]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(BACKDROP):
		_tex = load(BACKDROP) as Texture2D
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(72):
		var layer := i % 3
		_motes.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"v": [0.006, 0.016, 0.034][layer] * rng.randf_range(0.8, 1.2),
			"s": float(layer + 1),
			"a": [0.25, 0.4, 0.6][layer] * rng.randf_range(0.6, 1.0),
			"ph": rng.randf() * TAU,
		})
	for d in [[6.0, 0.86, DUNE_MID, 0.6], [14.0, 0.94, DUNE_NEAR, 1.0]]:
		var hs: Array[float] = []
		var h := 0.0
		for i in range(64):
			h = clampf(h + rng.randf_range(-1.0, 1.0) * 6.0, -18.0, 18.0)
			hs.append(h * float(d[3]))
		_dunes.append([hs, d[0], d[1], d[2]])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var sz := size
	var cover := Rect2(Vector2.ZERO, sz)
	if _tex:
		## Cover-fit (slightly oversized so the far layer can drift), anchored
		## to the horizon so tall phones show more sky.
		var ts := Vector2(_tex.get_size())
		var k := maxf(sz.x / ts.x, sz.y / ts.y) * 1.04
		var ds := ts * k
		var drift := Vector2(sin(_t * 0.07) * ds.x * 0.015, 0.0)
		cover = Rect2(((sz - ds) * Vector2(0.5, 0.55) + drift).floor(), ds)
		draw_texture_rect(_tex, cover, false)
	else:
		draw_rect(cover, Color(0.2, 0.11, 0.08))
	## Sun breathes a little
	var sun := cover.position + cover.size * Vector2(0.68, 0.5)
	var pulse := 0.5 + 0.5 * sin(_t * 0.6)
	for i in range(3):
		draw_circle(sun, (90.0 + i * 40.0) * cover.size.x / 720.0, Color(1.0, 0.75, 0.25, 0.02 + 0.015 * pulse))
	## Dune silhouettes: mid then near, pixel-stepped tops, sliding left.
	for d in _dunes:
		var hs: Array = d[0]
		var spd: float = d[1]
		var base := sz.y * float(d[2])
		var col: Color = d[3]
		var seg := sz.x / 12.0
		var off := fposmod(_t * spd, seg * hs.size())
		var pts := PackedVector2Array()
		var n := int(ceil(sz.x / seg)) + 2
		var i0 := int(floor(off / seg))
		for j in range(n + 1):
			var idx := (i0 + j) % hs.size()
			var x := j * seg - fposmod(off, seg)
			var a: float = hs[idx]
			var b: float = hs[(idx + 1) % hs.size()]
			for q in range(4):
				var f := q / 4.0
				var y := base + lerpf(a, b, f * f * (3.0 - 2.0 * f))
				pts.append(Vector2(x + f * seg, y).floor())
		pts.append(Vector2(sz.x + seg, sz.y))
		pts.append(Vector2(-seg, sz.y))
		draw_colored_polygon(pts, col)
	## Dust motes, three depths.
	for m in _motes:
		var p: Vector2 = m["p"]
		var x := fposmod(p.x + _t * float(m["v"]), 1.0) * sz.x
		var y := (p.y + sin(_t * 0.8 + float(m["ph"])) * 0.01) * sz.y
		var s: float = m["s"]
		draw_rect(Rect2(Vector2(x, y).floor(), Vector2(s, s)), Color(MOTE, float(m["a"])))
