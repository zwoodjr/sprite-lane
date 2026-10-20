class_name LightFx
extends RefCounted

## Visual tier light pools: additive radial sprites (one shared texture, one
## draw each — cheap on iPhone with gl_compatibility / mobile, no Light2D).
##   flash(): short burst (muzzle, explosion), fades out and frees itself
##   lamp():  a steady pool that flickers a little (street lamps, fires, vats)
##   fire():  small animated flame + its flickering pool (barrel fires)

static var _tex: Texture2D = null
static var _add: CanvasItemMaterial = null


static func tex() -> Texture2D:
	if _tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		g.add_point(0.7, Color(1, 1, 1, 0.12))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_tex = t
	return _tex


static func add_mat() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add


static func _pool(radius: float, color: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex()
	s.material = add_mat()
	## Ground pools are squashed for the 3/4 view.
	s.scale = Vector2(radius / 64.0, radius * 0.72 / 64.0)
	s.modulate = color
	s.z_as_relative = false
	s.z_index = 25
	return s


## A short light burst at `pos` (world) that fades over `life` seconds.
static func flash(parent: Node, pos: Vector2, radius: float, color: Color, life: float = 0.12) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var s := _pool(radius, color)
	s.global_position = pos
	parent.add_child(s)
	s.global_position = pos
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, life).set_ease(Tween.EASE_OUT)
	tw.tween_callback(s.queue_free)


## A steady flickering pool, child of `parent` at local `at`.
static func lamp(parent: Node2D, at: Vector2, radius: float, color: Color, flicker: float = 0.08) -> Sprite2D:
	var s := _pool(radius, color)
	s.position = at
	parent.add_child(s)
	if flicker > 0.0:
		var tw := s.create_tween().set_loops()
		var base := color.a
		for k in range(4):
			tw.tween_property(s, "modulate:a", base * (1.0 - flicker * (0.4 + 0.6 * randf())), 0.09 + randf() * 0.12)
		tw.tween_property(s, "modulate:a", base, 0.12)
	return s


## A small barrel / campfire flame with its light, child of `parent` at `at`.
static func fire(parent: Node2D, at: Vector2, size: float = 1.0) -> Node2D:
	var n := Node2D.new()
	n.position = at
	n.z_index = 3
	n.set_script(load("res://scripts/fx/flame.gd"))
	n.set("size", size)
	parent.add_child(n)
	lamp(parent, at + Vector2(0, 6), 120.0 * size, Color(1.0, 0.55, 0.2, 0.42), 0.22)
	return n
