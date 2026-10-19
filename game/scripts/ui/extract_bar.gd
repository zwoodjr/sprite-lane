extends Control

## Vertical extract-window bar on the left screen edge.
##   Sealed: amber fill climbs toward the next window opening.
##   Open:   green fill drains as the window closes (red on the last window).

var _ratio: float = 0.0
var _open: bool = false
var _last: bool = false
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_open(is_open: bool) -> void:
	_open = is_open


func set_state(phase: Dictionary, time_left: float) -> void:
	var dur := maxf(float(phase.get("duration", 1.0)), 0.01)
	_open = bool(phase.get("extract_open", false))
	_last = bool(phase.get("is_last", false))
	if _open:
		_ratio = clampf(time_left / dur, 0.0, 1.0)
	else:
		_ratio = clampf(1.0 - time_left / dur, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := 12.0
	var x := (size.x - w) * 0.5
	var h := size.y
	var frame := Rect2(x - 3.0, -3.0, w + 6.0, h + 6.0)
	draw_rect(frame, Color(0.06, 0.045, 0.03, 0.85), true)
	draw_rect(frame, Color(0.45, 0.34, 0.2, 0.95), false, 2.0)
	var col := UiTheme.AMBER
	if _open:
		col = UiTheme.DANGER if _last else Color(0.45, 0.95, 0.55)
	var fh := h * _ratio
	if fh > 0.5:
		var pulse := 0.85 + 0.15 * sin(_t * 6.0) if _open else 1.0
		draw_rect(Rect2(x, h - fh, w, fh), Color(col.r, col.g, col.b, pulse), true)
		draw_rect(Rect2(x, h - fh, w * 0.35, fh), Color(1, 1, 1, 0.18), true)
	## Little gate icon: open = up-arrow, sealed = bar.
	var c := Vector2(size.x * 0.5, -16.0)
	if _open:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 4), c + Vector2(-7, 4)]), col)
	else:
		draw_rect(Rect2(c - Vector2(7, 2), Vector2(14, 4)), col, true)
