extends Node2D

## Lingering ground patch spawned by upgrades / abilities (RunFx.ground):
##   burn   — Firewalk trail: enemies standing in it burn (value = dps)
##   heal   — Sanctuary puddle: the hero heals while inside (value = HP/s)
##   poison — Vial Shot cloud: enemies inside are poisoned (value = dps)

const TICK := 0.25
const ART := {
	"burn": {"path": "res://assets/sprites/fx/fx_firewalk.png", "n": 4, "fps": 10.0, "tint": Color(1, 1, 1, 0.95), "size_k": 1.6},
	"heal": {"path": "res://assets/sprites/fx/fx_heal_puddle.png", "n": 2, "fps": 4.0, "tint": Color(1, 1, 1, 0.85), "size_k": 2.2},
	"poison": {"path": "res://assets/sprites/depth/world/plague_fog.png", "n": 1, "fps": 1.0, "tint": Color(0.85, 1.2, 0.6, 0.85), "size_k": 2.3},
	## Depth E2: enemy spore cloud (Sporing / Bloated elites) — hurts the hero.
	"spore": {"path": "res://assets/sprites/depth/world/plague_fog.png", "n": 1, "fps": 1.0, "tint": Color(1.0, 1.0, 1.0, 0.95), "size_k": 2.3},
	## Campaign: raider fire bottles (Mother Vane) — a fire patch that burns the hero.
	"flame": {"path": "res://assets/sprites/fx/fx_firewalk.png", "n": 4, "fps": 10.0, "tint": Color(1, 1, 1, 0.95), "size_k": 1.6},
}

var mode: String = "burn"
var radius: float = 30.0
var life: float = 2.5
var value: float = 10.0
var player: Node2D

var _age: float = 0.0
var _tick: float = 0.0
var _sprite: Sprite2D
var _frames: Array[Texture2D] = []
var _fps: float = 8.0


func _ready() -> void:
	add_to_group("ground_fx")
	z_index = -3
	var art: Dictionary = ART.get(mode, ART["burn"])
	_frames = RunFx.frames(str(art["path"]), int(art["n"]))
	_fps = float(art["fps"])
	_sprite = Sprite2D.new()
	if not _frames.is_empty():
		_sprite.texture = _frames[0]
		var w := radius * float(art["size_k"])
		_sprite.scale = Vector2.ONE * (w / float(_frames[0].get_width()))
	_sprite.modulate = art["tint"]
	if mode in ["spore", "poison"]:
		_sprite.scale.y *= 0.62
	if mode in ["burn", "flame"]:
		_sprite.offset = Vector2(0, -float(_frames[0].get_height()) * 0.35) if not _frames.is_empty() else Vector2.ZERO
	add_child(_sprite)
	if mode in ["burn", "flame"]:
		LightFx.lamp(self, Vector2.ZERO, radius * 2.6, Color(1.0, 0.5, 0.2, 0.35), 0.25)
	## Pixel layer (bible §5): flame tongues on a fire patch, bubbles in a cloud.
	var px_id: String = str({"burn": "st_burn", "flame": "st_burn", "poison": "st_poison", "spore": "st_poison"}.get(mode, ""))
	if px_id != "":
		if mode in ["burn", "flame"]:
			_sprite.visible = false
		var n := clampi(int(radius / 12.0), 2, 7)
		for i in range(n):
			var a := TAU * (float(i) + randf() * 0.5) / float(n)
			var r := radius * (0.25 + randf() * 0.55)
			var s := Juice.px_loop(self, px_id, Vector2(cos(a) * r, sin(a) * r * 0.55)) as Node2D
			if s:
				s.set("frame", randi() % 4)
	_sprite.modulate.a = 0.0
	var tw := _sprite.create_tween()
	tw.tween_property(_sprite, "modulate:a", float((art["tint"] as Color).a), 0.12)


func _physics_process(delta: float) -> void:
	_age += delta
	if not _frames.is_empty():
		_sprite.texture = _frames[int(_age * _fps) % _frames.size()]
	if _age > life - 0.3:
		_sprite.modulate.a = maxf(0.0, (life - _age) / 0.3)
		## Pixel children step out in alpha (75 / 50 / 25 %).
		modulate.a = [0.25, 0.5, 0.75][clampi(int((life - _age) / 0.1), 0, 2)]
	if _age >= life:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	match mode:
		"heal":
			if player and is_instance_valid(player) and player.is_in_group("player") \
					and player.global_position.distance_to(global_position) <= radius + 14.0:
				player.call("heal", value * TICK)
		"burn":
			for e in RunFx.enemies_in(get_tree(), global_position, radius):
				e.call("apply_status", "burn", 1.2, value)
		"poison":
			for e in RunFx.enemies_in(get_tree(), global_position, radius):
				e.call("apply_status", "poison", 2.0, value)
		"flame":
			var pf := get_tree().get_first_node_in_group("player") as Node2D
			if pf != null and pf.global_position.distance_to(global_position) <= radius + 8.0:
				if pf.has_method("drain") and not bool(pf.call("is_dashing")):
					pf.call("drain", value * TICK)
		"spore":
			var p := get_tree().get_first_node_in_group("player") as Node2D
			if p != null and p.global_position.distance_to(global_position) <= radius + 10.0:
				if p.has_method("drain") and not bool(p.call("is_dashing")):
					p.call("drain", value * TICK)
				GameState.add_exposure(float(FactionDefs.TRAITS["sporing"]["exposure"]) * TICK)
