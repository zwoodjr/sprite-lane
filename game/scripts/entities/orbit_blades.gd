extends Node2D

## Orbiting Blades: scrap blades circle the hero, hitting enemies they touch
## (each enemy at most once per HIT_CD per blade set).

const TEX := "res://assets/sprites/fx/orbit_blade.png"
const WORLD_SIZE := 22.0

var player: Node2D
var _ang: float = 0.0
var _blades: Array[Sprite2D] = []
var _frames: Array[Texture2D] = []
var _last_hit: Dictionary = {} ## enemy instance id -> time
var _t: float = 0.0


func _ready() -> void:
	z_index = 4
	_frames = RunFx.frames(TEX, 2)


func _sync() -> void:
	var want := int(GameState.up("orbit_blades", "count", 0)) * int(GameState.up("blade_storm", "count_mult", 1))
	while _blades.size() < want:
		var s := Sprite2D.new()
		if not _frames.is_empty():
			s.texture = _frames[0]
			s.scale = Vector2.ONE * (WORLD_SIZE / float(_frames[0].get_width()))
		add_child(s)
		_blades.append(s)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.is_in_group("player"):
		queue_free()
		return
	_sync()
	_t += delta
	global_position = player.global_position + Vector2(0, -6)
	var spin := float(GameState.up("orbit_blades", "spin", 3.4))
	var radius := float(GameState.up("orbit_blades", "radius", 62.0))
	_ang = fmod(_ang + spin * delta, TAU)
	var dmg := float(GameState.up("orbit_blades", "damage", 9.0)) * float(player.get("damage_mult"))
	for i in range(_blades.size()):
		var a := _ang + TAU * i / float(_blades.size())
		var p := Vector2(cos(a), sin(a) * 0.7) * radius
		var b := _blades[i]
		b.position = p
		b.rotation += delta * 14.0
		if not _frames.is_empty():
			b.texture = _frames[int(_t * 12.0) % _frames.size()]
		for e in RunFx.enemies_in(get_tree(), global_position + p, UpgradeDefs.BLADE_HIT_R):
			var id := (e as Node).get_instance_id()
			if _t - float(_last_hit.get(id, -10.0)) < UpgradeDefs.BLADE_HIT_CD:
				continue
			_last_hit[id] = _t
			player.call("hit_enemy", e, dmg, ((e as Node2D).global_position - player.global_position).normalized(), 140.0, false, "blade")
