extends Node2D

## Campaign world markers, all in the friendly TEAL (bible §4):
##   target   objective spot: hard pixel ring on the ground + bouncing chevron
##   item     something to pick up (specimen, power cell, medicine): icon + ring
##   zone     hold / defend area: big dashed ring, fills as the hold progresses
## Markers in the controller's pad list get edge arrows + a minimap glyph
## (meta "map_glyph"). `last_chance` keeps the pad-arrow code happy.

var kind: String = "target"
var radius: float = 60.0
var icon_path: String = ""
var progress: float = -1.0
var hp_ratio: float = -1.0
var last_chance: bool = false
var label_text: String = ""
var _t: float = 0.0
var _icon: Sprite2D
var _label: Label
const TEAL := Color("5cd2c0")
const TEAL_D := Color("1f5a58")
const INK := Color("140c0e")
const BONE := Color("e9dfc9")


func _ready() -> void:
	z_index = -1 if kind != "item" else 1
	if not has_meta("map_glyph"):
		set_meta("map_glyph", MapIcons.BANG if kind != "item" else MapIcons.GEM)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_icon = Sprite2D.new()
		_icon.texture = load(icon_path)
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		## 48-px icon-set art at the world texel (one art px = one screen px).
		_icon.scale = Vector2.ONE * UnitAnim.TEXEL
		_icon.position = Vector2(0, -22)
		_icon.z_index = 2
		add_child(_icon)
	if label_text != "":
		_label = Label.new()
		_label.text = label_text
		_label.add_theme_font_override("font", UiTheme.font_button)
		_label.add_theme_font_size_override("font_size", 16)
		_label.add_theme_color_override("font_color", TEAL)
		_label.add_theme_constant_override("outline_size", 4)
		_label.add_theme_color_override("font_outline_color", INK)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.size = Vector2(240, 20)
		_label.position = Vector2(-120, -radius * 0.55 - 64.0)
		_label.z_index = 20
		add_child(_label)


func _process(delta: float) -> void:
	_t += delta
	if _icon:
		_icon.position.y = -22.0 - floorf(3.0 * (0.5 + 0.5 * sin(_t * 3.0)))
	queue_redraw()


## Hard 1-px ellipse ring (ground plane, 0.55 squash), no AA.
func _ring(r: float, col: Color, w: float = 2.0, dashed: bool = false, frac: float = 1.0) -> void:
	var n := maxi(24, int(r * 0.6))
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var a := TAU * float(i) / float(n) * frac - PI * 0.5
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.55).floor())
	if dashed:
		for i in range(0, pts.size() - 1, 2):
			draw_line(pts[i], pts[i + 1], col, w)
	else:
		draw_polyline(pts, col, w)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	match kind:
		"zone":
			draw_colored_polygon(_ellipse(radius), Color(TEAL, 0.12 + 0.06 * pulse))
			_ring(radius + 2.0, INK, 4.0, true)
			_ring(radius, TEAL, 2.0, true)
			if progress >= 0.0:
				_ring(radius - 8.0, Color("ffc040"), 4.0, false, clampf(progress, 0.0, 1.0))
		"item":
			_ring(radius * 0.5 + 2.0 * pulse, TEAL, 2.0)
		_:
			_ring(radius + 2.0, INK, 4.0)
			_ring(radius, Color(TEAL, 0.65 + 0.35 * pulse), 2.0)
			## Bouncing chevron above the spot.
			var y := -radius * 0.55 - 34.0 - floorf(6.0 * pulse)
			var tri := PackedVector2Array([Vector2(-10, y), Vector2(10, y), Vector2(0, y + 12)])
			draw_colored_polygon(PackedVector2Array([Vector2(-13, y - 3), Vector2(13, y - 3), Vector2(0, y + 15)]), INK)
			draw_colored_polygon(tri, TEAL)
	if hp_ratio >= 0.0:
		var w := 96.0
		var yy := -radius * 0.55 - 52.0
		draw_rect(Rect2(-w * 0.5 - 2.0, yy - 2.0, w + 4.0, 10.0), INK)
		draw_rect(Rect2(-w * 0.5, yy, w * clampf(hp_ratio, 0.0, 1.0), 6.0), TEAL if hp_ratio > 0.3 else Color("ff4836"))


func _ellipse(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(32):
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.55))
	return pts
