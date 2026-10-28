extends Control

## Red arrows at the screen edge for off-screen enemies (closest few only).
## Elites (tier 2) and bosses (tier 3) get bigger arrows.

const MAX_ARROWS := 8
const SHOW_WITHIN := 900.0 ## world px from the hero
const MARGIN := 26.0

var _player: Node2D
var _tex: Array[Texture2D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n in ["arrow_enemy", "arrow_elite", "arrow_boss"]:
		var p := "res://assets/sprites/ui/%s.png" % n
		_tex.append(load(p) if ResourceLoader.exists(p) else null)


func setup(player: Node2D) -> void:
	_player = player
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var vp := get_viewport_rect().size
	var xform: Transform2D = get_viewport().get_canvas_transform()
	var hero_screen: Vector2 = xform * _player.global_position
	var list: Array = []
	var hp := _player.global_position
	var r2 := SHOW_WITHIN * SHOW_WITHIN
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		var d2 := e.global_position.distance_squared_to(hp)
		if d2 > r2:
			continue
		var d := sqrt(d2)
		var s: Vector2 = xform * e.global_position
		if s.x > 0.0 and s.y > 0.0 and s.x < vp.x and s.y < vp.y:
			continue
		list.append([d, e, s])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in range(mini(MAX_ARROWS, list.size())):
		var e: Node2D = list[i][1]
		var s: Vector2 = list[i][2]
		var dir := (s - hero_screen).normalized()
		if dir.length() < 0.01:
			continue
		var tier := clampi(int(e.get("tier")) if "tier" in e else 1, 1, 3)
		var tex: Texture2D = _tex[tier - 1]
		var arrow_size: float = [26.0, 34.0, 44.0][tier - 1]
		var edge := _edge_point(hero_screen, dir, vp, MARGIN + arrow_size * 0.5)
		var near: float = clampf(1.0 - (float(list[i][0]) - 450.0) / 450.0, 0.35, 1.0)
		if tex:
			var sc: float = arrow_size / float(tex.get_width())
			draw_set_transform(edge, dir.angle(), Vector2(sc, sc))
			draw_texture(tex, -tex.get_size() * 0.5, Color(1, 1, 1, near))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var tip: Vector2 = edge + dir * arrow_size * 0.5
			draw_colored_polygon(PackedVector2Array([tip, tip - dir.rotated(0.6) * arrow_size, tip - dir.rotated(-0.6) * arrow_size]), Color(1, 0.3, 0.2, near))


func _edge_point(center: Vector2, dir: Vector2, vp: Vector2, margin: float) -> Vector2:
	var t_x := INF
	var t_y := INF
	if absf(dir.x) > 0.001:
		t_x = (((vp.x - margin) if dir.x > 0.0 else margin) - center.x) / dir.x
	if absf(dir.y) > 0.001:
		t_y = (((vp.y - margin) if dir.y > 0.0 else margin) - center.y) / dir.y
	return center + dir * minf(absf(t_x), absf(t_y))
