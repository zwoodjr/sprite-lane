extends Control

## Thin run-XP line under the HP readout (slim HUD): dark track, green fill,
## a brighter leading edge.

var ratio: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_ratio(r: float) -> void:
	r = clampf(r, 0.0, 1.0)
	if not is_equal_approx(r, ratio):
		ratio = r
		queue_redraw()


func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(Vector2(10, 0), Vector2(w, 5)), Color(0.05, 0.04, 0.03, 0.85))
	if ratio > 0.0:
		var fw := (w - 2.0) * ratio
		draw_rect(Rect2(Vector2(11, 1), Vector2(fw, 3)), Color(0.36, 0.78, 0.46))
		draw_rect(Rect2(Vector2(11 + fw - 2.0, 1), Vector2(2, 3)), Color(0.8, 1.0, 0.82))
