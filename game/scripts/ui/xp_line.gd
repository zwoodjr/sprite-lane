extends Control

## Run XP under the HP readout (slim HUD): "LV n" in the pixel face (8 px, its
## native grid) then a dark track with a green fill and a bright leading edge.

var ratio: float = 0.0
var level: int = 1
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiTheme.font_pixel


func set_ratio(r: float) -> void:
	r = clampf(r, 0.0, 1.0)
	if not is_equal_approx(r, ratio):
		ratio = r
		queue_redraw()


func set_level(lv: int) -> void:
	if lv != level:
		level = lv
		queue_redraw()


func _draw() -> void:
	var x0 := 10.0
	if _font:
		var t := "LV %d" % level
		draw_string_outline(_font, Vector2(x0, 9), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.04, 0.03, 0.02, 0.9))
		draw_string(_font, Vector2(x0, 9), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.62, 0.92, 0.6))
		x0 += _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 6.0
	var w := size.x - x0 + 10.0
	draw_rect(Rect2(Vector2(x0, 2), Vector2(w, 6)), Color(0.05, 0.04, 0.03, 0.85))
	if ratio > 0.0:
		var fw := (w - 2.0) * ratio
		draw_rect(Rect2(Vector2(x0 + 1, 3), Vector2(fw, 4)), Color(0.36, 0.78, 0.46))
		draw_rect(Rect2(Vector2(x0 + 1 + fw - 2.0, 3), Vector2(2, 4)), Color(0.8, 1.0, 0.82))
