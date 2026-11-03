extends Node2D

## Campaign objective pointer (blind playtest: "Grab the med kits" / "Get
## inside" were easy to miss): a pulsing chevron that circles the hero and
## points at the current objective, with the distance under it. Hides when
## the target is close or there is none.

const RING := 74.0
const NEAR := 150.0

var runner: Node
var hero: Node2D
var _t: float = 0.0
var _boost: float = 0.0
var _dir: Vector2 = Vector2.UP
var _dist_m: int = -1
var _label: Label


func _ready() -> void:
	z_index = 40
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", UiTheme.TEAL)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.95))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(90, 26)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## A bigger, brighter pulse for a few seconds (idle hint).
func pulse() -> void:
	_boost = 3.0


func target() -> Vector2:
	if runner == null or not is_instance_valid(runner) or bool(runner.get("finished")) or bool(runner.get("busy")):
		return Vector2.INF
	return runner.call("current_target")


func _process(delta: float) -> void:
	_t += delta
	_boost = maxf(0.0, _boost - delta)
	if hero == null or not is_instance_valid(hero):
		visible = false
		return
	var t := target()
	var d := INF if t == Vector2.INF else hero.global_position.distance_to(t)
	visible = d > NEAR and d < INF
	if not visible:
		return
	_dir = (t - hero.global_position).normalized()
	global_position = hero.global_position + Vector2(0, -30) + _dir * RING
	_dist_m = int(round(d / 32.0))
	_label.text = "%d m" % _dist_m
	_label.position = _dir * 30.0 - _label.size * 0.5
	queue_redraw()


func _draw() -> void:
	var k := 1.0 + 0.12 * sin(_t * 6.0) + (0.45 if _boost > 0.0 else 0.0)
	var a := _dir.angle()
	var pts := PackedVector2Array([Vector2(16, 0), Vector2(-10, -13), Vector2(-4, 0), Vector2(-10, 13)])
	var out := PackedVector2Array()
	var ink := PackedVector2Array()
	for p in pts:
		out.append((p * k * 1.25).rotated(a))
		ink.append((p * k).rotated(a))
	draw_colored_polygon(out, Color(0.04, 0.03, 0.02, 0.85))
	var col := UiTheme.TEAL
	col.a = 0.75 + 0.25 * sin(_t * 6.0)
	draw_colored_polygon(ink, col)
