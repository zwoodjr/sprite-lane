extends Node2D

## Small stylised flame (barrel / camp fires): three cel tongues that lick
## up and down, drawn additively. Cheap: one _draw of 3 polygons per frame.

var size: float = 1.0
var _t: float = 0.0


func _ready() -> void:
	_t = randf() * 10.0
	material = LightFx.add_mat()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var cols := [Color(1.0, 0.42, 0.12, 0.85), Color(1.0, 0.72, 0.28, 0.9), Color(1.0, 0.95, 0.7, 0.95)]
	var ws := [11.0, 7.0, 3.6]
	var hs := [26.0, 18.0, 9.0]
	for i in range(3):
		var w: float = ws[i] * size
		var h: float = hs[i] * size * (0.85 + 0.2 * sin(_t * (9.0 + i * 3.0) + i))
		var lean := sin(_t * 5.3 + i) * 3.0 * size
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w, 0), Vector2(-w * 0.55, -h * 0.45), Vector2(lean, -h),
			Vector2(w * 0.6, -h * 0.5), Vector2(w, 0), Vector2(0, w * 0.25),
		]), cols[i])
