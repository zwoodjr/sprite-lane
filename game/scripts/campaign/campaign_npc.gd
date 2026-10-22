extends Node2D

## A story character out in a campaign level: a survivor (hero art), a dog
## (pet art) or a raider (enemy art, e.g. Mother Vane). Modes:
##   idle    stand (optionally facing the hero)
##   follow  trail the hero (rescued, joined)
##   path    walk `path` while the hero stays within `lead` px (escort)
##   goto    walk to `goal` regardless
## `vulnerable` NPCs take hits from nearby mobs and can die (escort / defend);
## `ally` NPCs shoot the nearest mob in range.

signal arrived
signal died

var npc_id: String = ""
var hero: String = ""
var pet: String = ""
var enemy_art: String = ""
var label_text: String = ""
var mode: String = "idle"
var path: Array = []
var goal: Vector2 = Vector2.INF
var speed: float = 120.0
var lead: float = 300.0
var vulnerable: bool = false
var max_hp: float = 100.0
var hp: float = 100.0
var ally: bool = false
var ally_damage: float = 14.0
var ally_rate: float = 0.7
var ally_range: float = 360.0
var map_color: Color = Color("5cd2c0")
var dead: bool = false
## Read by the pad arrows / minimap when this NPC is the objective marker.
var last_chance: bool = false
## Shown only while being escorted / defended.
var show_bar: bool = false

var _anim: UnitAnim = UnitAnim.new()
var _body: Sprite2D
var _tag: Label
var _path_i: int = 0
var _player: Node2D
var _shoot_cd: float = 1.0
var _hurt_flash: float = 0.0
var _waiting: bool = false
var _feet: float = 32.0
var _since_hit: float = 99.0
const HIT_RADIUS := 48.0


func _ready() -> void:
	add_to_group("campaign_npcs")
	_body = Sprite2D.new()
	_body.z_index = 0
	add_child(_body)
	var prefix := ""
	var fs := 128.0
	if pet != "":
		prefix = str(PetDefs.get_pet(pet).get("anim", ""))
		_feet = 20.0
	elif enemy_art != "":
		prefix = "res://assets/sprites/enemies/%s/%s" % [enemy_art, enemy_art]
	else:
		prefix = str(CharacterDefs.get_character(hero).get("anim", ""))
		_feet = RadioDefs.NPC_FEET
	var st := UnitAnim.load_states(prefix)
	if st.has("idle"):
		fs = float((st["idle"]["tex"] as Texture2D).get_height())
	if enemy_art != "":
		_feet = 16.0 * (2.05 if fs >= 256.0 else (1.5 if fs >= 192.0 else 1.0)) * UnitAnim.BODY_K
	_anim.setup(_body, prefix, UnitAnim.native(fs), _feet)
	_anim.set_locomotion("idle")
	UnitAnim.add_contact_shadow(self, 40.0 if pet != "" else 58.0, _feet, 0.5)
	_tag = Label.new()
	_tag.text = label_text
	_tag.add_theme_font_override("font", UiTheme.font_button)
	_tag.add_theme_font_size_override("font_size", 16)
	_tag.add_theme_color_override("font_color", map_color)
	_tag.add_theme_constant_override("outline_size", 4)
	_tag.add_theme_color_override("font_outline_color", Color("140c0e"))
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.size = Vector2(200, 20)
	_tag.position = Vector2(-100, -(fs * UnitAnim.TEXEL) * 0.78 + _feet - 8.0)
	_tag.z_index = 20
	_tag.visible = label_text != ""
	add_child(_tag)
	hp = max_hp


func set_label(t: String) -> void:
	label_text = t
	if _tag:
		_tag.text = t
		_tag.visible = t != ""


func walk_path(pts: Array, p_lead: float = 300.0) -> void:
	path = pts
	_path_i = 0
	lead = p_lead
	mode = "path"


func go_to(p: Vector2) -> void:
	goal = p
	mode = "goto"


func path_progress() -> float:
	if path.is_empty():
		return 1.0
	return float(_path_i) / float(path.size())


func is_waiting() -> bool:
	return _waiting


func _process(delta: float) -> void:
	if dead:
		return
	_anim.tick(delta)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	modulate = Color(1, 0.55, 0.5) if _hurt_flash > 0.0 else Color.WHITE
	var step := Vector2.ZERO
	_waiting = false
	match mode:
		"follow":
			if _player:
				var to := _player.global_position + Vector2(-46, 26) - global_position
				if to.length() > 60.0:
					step = to.normalized() * minf(maxf(speed, 220.0) * delta, to.length() - 40.0)
		"path":
			if _path_i < path.size():
				var target: Vector2 = path[_path_i]
				if _player and _player.global_position.distance_to(global_position) > lead:
					_waiting = true
				else:
					var to2 := target - global_position
					if to2.length() < 8.0:
						_path_i += 1
						if _path_i >= path.size():
							arrived.emit()
					else:
						step = to2.normalized() * minf(speed * delta, to2.length())
		"goto":
			if goal != Vector2.INF:
				var to3 := goal - global_position
				if to3.length() < 8.0:
					goal = Vector2.INF
					mode = "idle"
					arrived.emit()
				else:
					step = to3.normalized() * minf(speed * delta, to3.length())
	if step != Vector2.ZERO:
		global_position += step
		if absf(step.x) > 0.2:
			_anim.set_facing(step.x < 0.0)
		_anim.set_locomotion("walk")
	else:
		_anim.set_locomotion("idle")
		if _player and mode == "idle" and absf(_player.global_position.x - global_position.x) > 20.0:
			_anim.set_facing(_player.global_position.x < global_position.x)
	if vulnerable:
		_take_mob_hits(delta)
		## Out of the fight for a moment: they patch themselves up a little.
		_since_hit += delta
		if _since_hit > 2.5 and hp < max_hp:
			hp = minf(max_hp, hp + max_hp * 0.03 * delta)
	if ally:
		_tick_ally(delta)
	queue_redraw()


## Mobs crowding a vulnerable NPC wear it down (no dodging for civilians).
func _take_mob_hits(delta: float) -> void:
	var dmg := 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node2D
		if en == null or not is_instance_valid(en) or bool(en.get("_dead")):
			continue
		var reach := HIT_RADIUS * float(en.get("body_scale"))
		if en.global_position.distance_to(global_position) <= reach:
			dmg += float(en.get("damage")) * 0.4
	if dmg > 0.0:
		hurt(dmg * delta)


func hurt(amount: float) -> void:
	if dead or not vulnerable:
		return
	hp = maxf(0.0, hp - amount)
	_hurt_flash = 0.12
	_since_hit = 0.0
	if hp <= 0.0:
		dead = true
		if _anim.has_state("death"):
			_anim.play("death")
		died.emit()


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


## Allies (Mother Vane at the gate): shoot the nearest mob in range.
func _tick_ally(delta: float) -> void:
	_shoot_cd -= delta
	if _shoot_cd > 0.0:
		return
	var best: Node2D = null
	var bd := ally_range
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node2D
		if en == null or not is_instance_valid(en) or bool(en.get("_dead")):
			continue
		var d := en.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = en
	if best == null:
		_shoot_cd = 0.3
		return
	_shoot_cd = ally_rate
	_anim.set_facing(best.global_position.x < global_position.x)
	if _anim.has_state("attack"):
		_anim.play("attack")
	var from := global_position + Vector2(0, -30)
	var tracer := Line2D.new()
	tracer.width = 2.0
	tracer.default_color = Color("ffc040")
	tracer.top_level = true
	tracer.z_index = 30
	tracer.points = PackedVector2Array([from, best.global_position + Vector2(0, -10)])
	get_parent().add_child(tracer)
	var tw := tracer.create_tween()
	tw.tween_property(tracer, "modulate:a", 0.0, 0.12)
	tw.tween_callback(tracer.queue_free)
	if best.has_method("take_damage"):
		best.call("take_damage", ally_damage, (best.global_position - global_position).normalized(), 60.0, false)


func _draw() -> void:
	if not (show_bar and vulnerable) or dead:
		return
	## Small TEAL friendly bar above the head (INK frame, 2-px fill).
	var w := 56.0
	var y := -(110.0 if pet == "" else 64.0)
	draw_rect(Rect2(-w * 0.5 - 2.0, y - 2.0, w + 4.0, 8.0), Color("140c0e"))
	draw_rect(Rect2(-w * 0.5, y, w * clampf(hp / max_hp, 0.0, 1.0), 4.0), Color("5cd2c0") if hp > max_hp * 0.3 else Color("ff4836"))
