extends Camera2D

## Follow camera: zoomed in (1.35 at 720 wide; integer texel scale on devices), hero sits ~45% down the screen, and the
## view leads 15% of the screen in the move direction. Plus Juice shake.

const SURVIVOR_ZOOM := UnitAnim.SCREEN_ZOOM
## Hero screen height as a fraction from the top (0.5 = centred).
const HERO_SCREEN_Y := 0.45
## Look-ahead as a fraction of the visible world size, along the move direction.
const LEAD_FRAC := 0.15

var shake_offset: Vector2 = Vector2.ZERO
## Extra zoom multiplier for short punch-ins (boss spawn); eased back to 1.
var punch: float = 1.0
## Integer texel scale in use (1 art texel = pixel_scale x pixel_scale device px).
var pixel_scale: int = 1
var _look: Vector2 = Vector2.ZERO
var _target: Node2D = null


func set_target(t: Node2D) -> void:
	_target = t


func _ready() -> void:
	_apply_pixel_zoom()
	make_current()
	var grade := CanvasLayer.new()
	grade.name = "ScreenGrade"
	grade.set_script(load("res://scripts/fx/screen_grade.gd"))
	add_child(grade)
	_add_ambient_dust()
	_add_motes()
	var amb := Node2D.new()
	amb.name = "AmbientFx"
	amb.set_script(load("res://scripts/fx/ambient_fx.gd"))
	add_child(amb)
	amb.call("setup", self)


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
	cm.color = Color(1.0, 0.975, 0.94)
	add_child(cm)


## Per-zone drifting motes: tiny 1-2 px flecks (dust / ash / spores / embers)
## floating slowly over the world, separate from the wind-blown dust.
const MOTES := {
	"haze": Color(1.0, 0.86, 0.62, 0.5), "drift": Color(1.0, 0.86, 0.62, 0.5),
	"smog": Color(0.75, 0.72, 0.7, 0.55), "pall": Color(0.78, 0.8, 0.86, 0.5),
	"blight": Color(0.72, 0.95, 0.5, 0.55), "shroud": Color(1.0, 0.6, 0.35, 0.6),
	"choke": Color(0.86, 0.95, 0.45, 0.55), "blackout": Color(0.82, 0.8, 0.72, 0.5),
	"deadfall": Color(0.8, 0.76, 0.72, 0.55), "dustfall": Color(1.0, 0.74, 0.4, 0.65),
}


func _add_motes() -> void:
	var zid := str(ZoneDefs.zone(GameState.zone_tier()).get("id", "haze"))
	var col: Color = MOTES.get(zid, MOTES["haze"])
	var p := CPUParticles2D.new()
	p.name = "Motes"
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(420, 760)
	p.direction = Vector2(0.4, -1.0)
	p.spread = 40.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.add_point(0.25, col)
	g.add_point(0.75, col)
	g.set_color(g.get_point_count() - 1, Color(col, 0.0))
	p.color_ramp = g
	p.local_coords = false
	p.z_as_relative = false
	p.z_index = 31
	add_child(p)


## Visible world size at the current zoom (world px).
func view_world_size() -> Vector2:
	return get_viewport_rect().size / zoom


## Integer pixel scaling. The UI canvas stretches by a fractional factor s
## (e.g. 1179 / 720 = 1.64 on an iPhone 15), which made each art texel 1-2 px
## wide and shimmer. The world camera instead picks N = round(s) and zooms so
## one texel (UnitAnim.TEXEL world px) lands on exactly N x N device px.
static func stretch_factor(vp: Viewport) -> float:
	var win := vp.get_window() if vp else null
	## Headless (tests / bots) reports a 64 px window: keep the design scale.
	if win == null or DisplayServer.get_name() == "headless":
		return 1.0
	var design := win.get_visible_rect().size
	if design.x <= 0.0:
		return 1.0
	return maxf(float(win.size.x) / design.x, 0.01)


static func pixel_zoom_for(s: float) -> float:
	var n := maxi(1, roundi(s))
	return float(n) / (s * UnitAnim.TEXEL)


func _apply_pixel_zoom() -> void:
	var s := stretch_factor(get_viewport())
	pixel_scale = maxi(1, roundi(s))
	var z := pixel_zoom_for(s) * punch
	zoom = Vector2(z, z)


func _process(delta: float) -> void:
	if punch != 1.0:
		punch = move_toward(punch, 1.0, delta * 0.35)
	_apply_pixel_zoom()
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
