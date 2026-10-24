extends Control

## Round, multi-touch action button. Drawn only — input is routed by
## touch_controls.gd (Godot's Button only listens to the first finger, which
## made FIRE/DASH unreliable while the move stick was held).

signal pressed_down
signal released

@export var label_text: String = "FIRE"
@export var sub_text: String = ""
@export var radius: float = 54.0
@export var tint: Color = Color(0.95, 0.72, 0.30)

var held: bool = false
var touch_index: int = -1
var cooldown_ratio: float = 0.0  ## 0 = ready, 1 = just used
var disabled: bool = false
var highlight: bool = false       ## pulses
## Bottle-cap art (HD pack). When set, drawn instead of the flat disc + label.
var icon: Texture2D = null
## Visual tier: simple worn cap (dark glass disc, chipped brass ring, pixel label;
## the ability shows its icon small inside). Set by touch_controls.
var slim: bool = false
static var _pixel: Font = null
var _pulse_t: float = 0.0
var _press_scale: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	pivot_offset = size * 0.5


func center_global() -> Vector2:
	return global_position + size * 0.5


## Touch radius: the drawn radius plus slop, but never under a 44-pt target
## (UiTheme.MIN_TOUCH across) so small caps like pause stay easy to hit.
func hit(screen_pos: Vector2, slop: float = 1.25) -> bool:
	var reach := maxf(radius * slop, UiTheme.MIN_TOUCH * 0.5 * maxf(1.0, slop / 1.25))
	return visible and center_global().distance_to(screen_pos) <= reach


func press(index: int) -> void:
	if disabled:
		Juice.sfx("ui_denied", -4.0)
		return
	held = true
	touch_index = index
	_press_scale = 0.86
	pressed_down.emit()
	queue_redraw()


func release() -> void:
	if not held:
		return
	held = false
	touch_index = -1
	released.emit()
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_t += delta
	_press_scale = lerpf(_press_scale, 1.0, clampf(delta * 14.0, 0.0, 1.0))
	scale = Vector2.ONE * _press_scale
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := radius
	var a := 0.45 if disabled else (1.0 if held else 0.9)
	var cdr := clampf(cooldown_ratio, 0.0, 1.0)
	if highlight:
		var pulse := 0.5 + 0.5 * sin(_pulse_t * 6.0)
		draw_circle(c, r + 6.0 + pulse * 6.0, Color(tint.r, tint.g, tint.b, 0.25 * pulse))
	if slim:
		_draw_slim(c, r, a, cdr)
		return
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.3 * a))
	if icon != null:
		var d := r * 2.0
		var mod := Color(1, 1, 1, a) if cdr <= 0.01 else Color(0.55, 0.55, 0.55, a)
		draw_texture_rect(icon, Rect2(c - Vector2(r, r), Vector2(d, d)), false, mod)
	else:
		var fill := tint.darkened(0.55 if not held else 0.3)
		draw_circle(c, r, Color(fill.r, fill.g, fill.b, 0.82 * a))
		draw_arc(c, r - 1.5, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, a), 3.0, true)
	## Cooldown: dark sweep + a bright ring that fills back up as it recharges.
	## (Ratio is clamped: a >360° fan self-intersects → "Invalid polygon data".)
	if cdr >= 0.995:
		draw_circle(c, r - 3.0, Color(0, 0, 0, 0.45))
	elif cdr > 0.02:
		var pts := PackedVector2Array([c])
		var start := -PI * 0.5
		var end := start + TAU * cdr
		var steps := maxi(3, int(ceil(32.0 * cdr)))
		for i in range(steps + 1):
			var ang := lerpf(start, end, float(i) / steps)
			pts.append(c + Vector2(cos(ang), sin(ang)) * (r - 3.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.45))
	if cdr > 0.02:
		var ready_frac := 1.0 - cdr
		draw_arc(c, r + 3.0, -PI * 0.5, -PI * 0.5 + TAU * ready_frac, 48, Color(tint.r, tint.g, tint.b, 0.95), 4.0, true)
	if icon != null:
		return
	## Text (fallback when there's no art)
	var font := ThemeDB.fallback_font
	var fs := UiTheme.font_px(int(r * 0.36))
	var tw := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ty := c.y + fs * 0.35 - (fs * 0.35 if sub_text != "" else 0.0)
	draw_string_outline(font, Vector2(c.x - tw * 0.5, ty), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.8 * a))
	draw_string(font, Vector2(c.x - tw * 0.5, ty), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.96, 0.88, a))
	if sub_text != "":
		var sfs := UiTheme.font_px(int(r * 0.24))
		var sw := font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		draw_string(font, Vector2(c.x - sw * 0.5, ty + sfs + 4), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(tint.r, tint.g, tint.b, a))



func _draw_slim(c: Vector2, r: float, a: float, cdr: float) -> void:
	var brass := Color(0.66, 0.5, 0.26)
	draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.22 * a))
	draw_circle(c, r, Color(0.08, 0.06, 0.045, (0.62 if not held else 0.8) * a))
	## Worn brass ring: a few chipped gaps, brighter on the lit top-left.
	var segs := 10
	for i in range(segs):
		var a0 := TAU * float(i) / segs + 0.05
		var a1 := TAU * float(i + 1) / segs - (0.16 if i % 4 == 1 else 0.05)
		var lit := 0.5 + 0.5 * cos((a0 + a1) * 0.5 + PI * 0.75)
		var col := brass.lerp(Color(0.95, 0.82, 0.55), lit * 0.45)
		draw_arc(c, r - 1.5, a0, a1, 8, Color(col.r, col.g, col.b, 0.9 * a), 3.0, true)
	draw_arc(c, r - 5.0, 0.0, TAU, 40, Color(0, 0, 0, 0.35 * a), 1.0, true)
	if icon != null:
		## Pixel icon at an integer size (48-px art x1, or x2 on big buttons).
		var d := 96.0 if r * 1.25 >= 90.0 else 48.0
		var mod := Color(1, 1, 1, 0.9 * a) if cdr <= 0.01 else Color(0.5, 0.5, 0.5, 0.8 * a)
		draw_texture_rect(icon, Rect2((c - Vector2(d, d) * 0.5).floor(), Vector2(d, d)), false, mod)
	if cdr >= 0.995:
		draw_circle(c, r - 3.0, Color(0, 0, 0, 0.45))
	elif cdr > 0.02:
		var pts := PackedVector2Array([c])
		var start := -PI * 0.5
		var end := start + TAU * cdr
		var steps := maxi(3, int(ceil(32.0 * cdr)))
		for i in range(steps + 1):
			var ang := lerpf(start, end, float(i) / steps)
			pts.append(c + Vector2(cos(ang), sin(ang)) * (r - 3.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.45))
		draw_arc(c, r + 3.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - cdr), 48, Color(tint.r, tint.g, tint.b, 0.95), 3.0, true)
	if icon != null or label_text == "":
		return
	if _pixel == null and ResourceLoader.exists("res://assets/fonts/PressStart2P.ttf"):
		_pixel = load("res://assets/fonts/PressStart2P.ttf")
	var font: Font = _pixel if _pixel else ThemeDB.fallback_font
	## Pixel face never under 16 (the old 8 px pause label was unreadable).
	var fs := UiTheme.pixel_px(UiTheme.PX_M)
	var tw := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(c.x - tw * 0.5, c.y + fs * 0.5)
	draw_string_outline(font, p, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8 * a))
	draw_string(font, p, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.92, 0.82, 0.6, a))
