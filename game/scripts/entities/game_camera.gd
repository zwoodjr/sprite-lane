extends Camera2D

## Follow camera: zoomed in (1.35), hero sits ~45% down the screen, and the
## view leads 15% of the screen in the move direction. Plus Juice shake.

const SURVIVOR_ZOOM := 1.35
## Hero screen height as a fraction from the top (0.5 = centred).
const HERO_SCREEN_Y := 0.45
## Look-ahead as a fraction of the visible world size, along the move direction.
const LEAD_FRAC := 0.15

var shake_offset: Vector2 = Vector2.ZERO
var _look: Vector2 = Vector2.ZERO
var _target: Node2D = null


func set_target(t: Node2D) -> void:
	_target = t


func _ready() -> void:
	zoom = Vector2(SURVIVOR_ZOOM, SURVIVOR_ZOOM)
	make_current()
	_add_ambient_dust()


## Slow wind-blown dust drifting across the screen — sells the wasteland.
func _add_ambient_dust() -> void:
	var p := CPUParticles2D.new()
	p.amount = 60
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(520, 900)
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


## Visible world size at the current zoom (world px).
func view_world_size() -> Vector2:
	return get_viewport_rect().size / zoom


func _process(delta: float) -> void:
	var view := view_world_size()
	var want := Vector2.ZERO
	if _target and is_instance_valid(_target):
		var v: Vector2 = _target.get("velocity") if "velocity" in _target else Vector2.ZERO
		var mv := TouchInput.get_move()
		var dir := mv if mv.length() > 0.1 else (v / 240.0).limit_length(1.0)
		want = dir.limit_length(1.0) * view * LEAD_FRAC
	_look = _look.lerp(want, clampf(delta * 3.5, 0.0, 1.0))
	## Camera centre sits below the hero so the hero reads at 45% from the top.
	var drop := Vector2(0.0, (0.5 - HERO_SCREEN_Y) * view.y)
	offset = drop + _look + shake_offset
