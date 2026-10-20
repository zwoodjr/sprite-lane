extends Node2D

## A camp survivor out in the Dust (Depth E4 cameos): their own animated strips,
## an optional prop (tent, tower, relay, vault, stall, wreck) and a name tag.
## Shows on the minimap. Can follow a target (Pebble's escort).

var hero: String = "pebble"
var label_text: String = ""
var prop_path: String = ""
var prop_world: float = 90.0
var prop_offset: Vector2 = Vector2(-50, 0)
## Stand on top of the prop (Vesper's tower): body raised by this many px.
var perch: float = 0.0
var follow: Node2D = null
var follow_speed: float = 160.0
var map_color: Color = RadioDefs.MAP_COLOR
var _anim: UnitAnim = UnitAnim.new()
var _body: Sprite2D
var _prop: Sprite2D
var _tag: Label
var _busy_t: float = 0.0


func _ready() -> void:
	add_to_group("map_markers")
	add_to_group("cameos")
	z_index = 0
	if prop_path != "" and ResourceLoader.exists(prop_path):
		_prop = Sprite2D.new()
		_prop.texture = load(prop_path)
		var k := prop_world * UnitAnim.ART_GROW / float(maxi(_prop.texture.get_width(), _prop.texture.get_height()))
		_prop.scale = Vector2(k, k)
		_prop.offset = Vector2(0, -float(_prop.texture.get_height()) * 0.5)
		_prop.position = prop_offset * UnitAnim.ART_GROW + Vector2(0, 10)
		_prop.z_index = -1 if perch <= 0.0 else 0
		add_child(_prop)
	_body = Sprite2D.new()
	_body.position = Vector2(0, -perch * UnitAnim.ART_GROW)
	_body.z_index = 1
	add_child(_body)
	var c := CharacterDefs.get_character(hero)
	_anim.setup(_body, str(c.get("anim", "")), RadioDefs.NPC_WORLD, RadioDefs.NPC_FEET)
	_anim.set_locomotion("idle")
	_tag = Label.new()
	_tag.text = label_text if label_text != "" else str(c.get("display_name", hero))
	_tag.add_theme_font_size_override("font_size", 12)
	_tag.add_theme_color_override("font_color", RadioDefs.MAP_COLOR)
	_tag.add_theme_constant_override("outline_size", 4)
	_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.size = Vector2(200, 16)
	_tag.position = Vector2(-100, -perch * UnitAnim.ART_GROW - 110)
	_tag.z_index = 4
	add_child(_tag)


## Play a one-shot strip (ability / attack) then settle back.
func act(state: String, hold: float = 0.6) -> void:
	if _anim.has_state(state):
		_anim.play(state)
		_busy_t = hold


func face(x: float) -> void:
	if absf(x) > 0.5:
		_anim.set_facing(x < 0.0)


func _process(delta: float) -> void:
	_anim.tick(delta)
	_busy_t = maxf(0.0, _busy_t - delta)
	if follow != null and is_instance_valid(follow):
		var to := follow.global_position - global_position
		if to.length() > 70.0:
			var step := to.normalized() * minf(follow_speed * delta, to.length() - 60.0)
			global_position += step
			face(step.x)
			if _busy_t <= 0.0:
				_anim.set_locomotion("walk")
			return
	if _busy_t <= 0.0:
		_anim.set_locomotion("idle")
