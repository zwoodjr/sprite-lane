extends Camera2D

## Follow camera with look-ahead (toward aim when shooting, toward movement
## otherwise) plus screen-shake offset fed by Juice.

var shake_offset: Vector2 = Vector2.ZERO
var _look: Vector2 = Vector2.ZERO
var _target: Node2D = null


func set_target(t: Node2D) -> void:
	_target = t


func _ready() -> void:
	make_current()
	_add_ambient_dust()


## Slow wind-blown dust drifting across the screen — sells the wasteland.
func _add_ambient_dust() -> void:
	var p := CPUParticles2D.new()
	p.amount = 60
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(900, 500)
	p.direction = Vector2(1, 0.15)
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.9, 0.7, 0.0))
	g.add_point(0.3, Color(1, 0.9, 0.7, 0.35))
	g.set_color(g.get_point_count() - 1, Color(1, 0.9, 0.7, 0.0))
	p.color_ramp = g
	p.local_coords = false
	p.z_index = 30
	add_child(p)
	var cm := CanvasModulate.new()
	cm.color = Color(1.0, 0.95, 0.88)
	add_child(cm)


func _process(delta: float) -> void:
	var want := Vector2.ZERO
	if _target and is_instance_valid(_target):
		var aim := TouchInput.aim_vector
		if aim.length() > 0.01:
			want = aim * 90.0
		else:
			var v: Vector2 = _target.get("velocity") if "velocity" in _target else Vector2.ZERO
			want = v.limit_length(300.0) * 0.22
	_look = _look.lerp(want, clampf(delta * 3.5, 0.0, 1.0))
	offset = _look + shake_offset
