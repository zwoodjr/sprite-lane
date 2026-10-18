extends Camera2D

## Follow camera with look-ahead (toward aim when shooting, toward movement
## otherwise) plus screen-shake offset fed by Juice.
##
## FOV for sheet-detail heroes/mobs on portrait phones (Xogot / iPhone).
## Slightly pulled out vs 1.12 so 96px wasteland units read without clogging.
## ~52px player footprint ≈ 1/14 of 720-wide frame at zoom 1.0.

const SURVIVOR_ZOOM := 1.0

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


func _process(delta: float) -> void:
	var want := Vector2.ZERO
	if _target and is_instance_valid(_target):
		var aim := TouchInput.aim_vector
		## Pulled-out survivor FOV — lighter look-ahead so the battlefield stays readable.
		var look_scale := 48.0 if TouchInput.is_single_stick() else 84.0
		if aim.length() > 0.01 and not TouchInput.is_single_stick():
			want = aim * look_scale
		else:
			var v: Vector2 = _target.get("velocity") if "velocity" in _target else Vector2.ZERO
			## Lighter lead so sheet-detail sprites stay centered while running.
			want = v.limit_length(240.0) * (0.12 if TouchInput.is_single_stick() else 0.20)
	_look = _look.lerp(want, clampf(delta * 4.2, 0.0, 1.0))
	offset = _look + shake_offset
