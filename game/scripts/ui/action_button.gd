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


func _draw() -> void:
	var c := size * 0.5
	var r := radius
	var a := 0.45 if disabled else (1.0 if held else 0.9)
	var cdr := clampf(cooldown_ratio, 0.0, 1.0)
	if highlight:
		var pulse := 0.5 + 0.5 * sin(_pulse_t * 6.0)
		draw_circle(c, r + 6.0 + pulse * 6.0, Color(tint.r, tint.g, tint.b, 0.25 * pulse))
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
	var fs := int(r * 0.36)
	var tw := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ty := c.y + fs * 0.35 - (fs * 0.35 if sub_text != "" else 0.0)
	draw_string_outline(font, Vector2(c.x - tw * 0.5, ty), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.8 * a))
	draw_string(font, Vector2(c.x - tw * 0.5, ty), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.96, 0.88, a))
	if sub_text != "":
		var sfs := int(r * 0.24)
		var sw := font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		draw_string(font, Vector2(c.x - sw * 0.5, ty + sfs + 4), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(tint.r, tint.g, tint.b, a))
