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
var highlight: bool = false       ## pulses (e.g. EXTRACT available)
var _pulse_t: float = 0.0
var _press_scale: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	pivot_offset = size * 0.5


func center_global() -> Vector2:
	return global_position + size * 0.5


func hit(screen_pos: Vector2, slop: float = 1.25) -> bool:
	return visible and center_global().distance_to(screen_pos) <= radius * slop


func press(index: int) -> void:
	if disabled:
		Juice.sfx("empty", -6.0)
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


@export var icon_kind: String = "" ## rush / bolt / cross / drone / blades / maul / vial / ""

func _draw() -> void:
	var c := size * 0.5
	var r := radius
	## Scrap-metal / bottle-cap look — semi-transparent; fade further when idle.
	var idle_fade := 0.55 if (not held and cooldown_ratio < 0.05 and not highlight) else 0.88
	var a := 0.40 if disabled else (0.95 if held else idle_fade)
	var pulse := 0.0
	if highlight:
		pulse = 0.5 + 0.5 * sin(_pulse_t * 6.0)
		draw_circle(c, r + 6.0 + pulse * 6.0, Color(tint.r, tint.g, tint.b, 0.25 * pulse))
	## Bottle-cap body: dark scrap rim + dented face.
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.4 * a))
	var fill := Color(0.28, 0.22, 0.16).lerp(tint.darkened(0.45), 0.55)
	if held:
		fill = fill.lightened(0.12)
	draw_circle(c, r, Color(fill.r, fill.g, fill.b, 0.78 * a))
	## Cap ridges
	for i in range(12):
		var ang := TAU * float(i) / 12.0
		var p0 := c + Vector2(cos(ang), sin(ang)) * (r - 5.0)
		var p1 := c + Vector2(cos(ang), sin(ang)) * (r - 1.0)
		draw_line(p0, p1, Color(0.55, 0.45, 0.32, 0.55 * a), 2.0)
	draw_arc(c, r - 1.5, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, a * 0.9), 3.0, true)
	_draw_icon(c, r * 0.38, Color(1, 0.95, 0.85, a))
	## Cooldown sweep — skip hairline wedges (Godot triangulator errors on degenerate polys).
	if cooldown_ratio > 0.04:
		var start := -PI * 0.5
		var span := TAU * clampf(cooldown_ratio, 0.0, 1.0)
		var steps := maxi(3, int(ceil(span / (TAU / 32.0))))
		var pts := PackedVector2Array([c])
		for i in range(steps + 1):
			var ang := start + span * (float(i) / float(steps))
			pts.append(c + Vector2(cos(ang), sin(ang)) * (r - 3.0))
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	## Short label under icon (cap stamp), not a full text button.
	var font := ThemeDB.fallback_font
	var fs := int(r * 0.28)
	var tw := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ty := c.y + r * 0.55
	draw_string_outline(font, Vector2(c.x - tw * 0.5, ty), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.75 * a))
	draw_string(font, Vector2(c.x - tw * 0.5, ty), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.96, 0.88, a))


func _draw_icon(c: Vector2, s: float, col: Color) -> void:
	match icon_kind:
		"bolt":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.2, -s), c + Vector2(s * 0.35, -s * 0.15), c + Vector2(0, -s * 0.1),
				c + Vector2(s * 0.25, s), c + Vector2(-s * 0.35, s * 0.1), c + Vector2(0, s * 0.05),
			]), col)
		"cross":
			draw_rect(Rect2(c.x - s * 0.18, c.y - s, s * 0.36, s * 2.0), col)
			draw_rect(Rect2(c.x - s, c.y - s * 0.18, s * 2.0, s * 0.36), col)
		"rush":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s, -s * 0.4), c + Vector2(s * 0.2, 0), c + Vector2(-s, s * 0.4),
			]), col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.2, -s * 0.4), c + Vector2(s, 0), c + Vector2(-s * 0.2, s * 0.4),
			]), col)
		"drone":
			draw_circle(c, s * 0.45, col)
			draw_arc(c, s * 0.85, 0, TAU, 24, col, 2.0, true)
		"blades":
			draw_line(c + Vector2(-s * 0.6, s * 0.7), c + Vector2(s * 0.5, -s * 0.7), col, 3.0)
			draw_line(c + Vector2(s * 0.6, s * 0.7), c + Vector2(-s * 0.5, -s * 0.7), col, 3.0)
		"maul":
			draw_rect(Rect2(c.x - s * 0.15, c.y - s * 0.2, s * 0.3, s * 1.1), col)
			draw_rect(Rect2(c.x - s * 0.7, c.y - s * 0.85, s * 1.4, s * 0.55), col)
		"vial":
			draw_rect(Rect2(c.x - s * 0.35, c.y - s * 0.2, s * 0.7, s * 0.9), col)
			draw_rect(Rect2(c.x - s * 0.2, c.y - s * 0.85, s * 0.4, s * 0.4), col)
		_:
			pass
