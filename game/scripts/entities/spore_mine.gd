extends Node2D

## Spore Mines: dropped behind the moving hero; arms, then bursts when an
## enemy steps close (damage through the hero's hit pipeline, so Dust Rounds
## poison and special ammo ride along).

const TEX := "res://assets/sprites/fx/spore_mine.png"
const WORLD_SIZE := 22.0

var player: Node2D
var _age: float = 0.0
var _life: float = 14.0
var _sprite: Sprite2D
var _frames: Array[Texture2D] = []
var _done: bool = false


func _ready() -> void:
	add_to_group("spore_mines")
	z_index = -2
	_life = float(GameState.up("spore_mines", "life", 14.0))
	_frames = RunFx.frames(TEX, 2)
	_sprite = Sprite2D.new()
	if not _frames.is_empty():
		_sprite.texture = _frames[0]
		_sprite.scale = Vector2.ONE * (WORLD_SIZE / float(_frames[0].get_width()))
	_sprite.modulate = Color(1, 1, 1, 0.6)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if _age >= _life or player == null or not is_instance_valid(player):
		queue_free()
		return
	if _age < UpgradeDefs.MINE_ARM_TIME:
		return
	_sprite.modulate.a = 1.0
	## Blink faster as it ages.
	if not _frames.is_empty():
		_sprite.texture = _frames[int(_age * (2.0 + _age * 0.3)) % 2]
	if RunFx.nearest_enemy(get_tree(), global_position, UpgradeDefs.MINE_TRIGGER_R + 14.0) != null:
		_burst()


func _burst() -> void:
	_done = true
	var dmg := float(GameState.up("spore_mines", "damage", 22.0)) * float(player.get("damage_mult"))
	var r := float(GameState.up("spore_mines", "radius", 70.0))
	## Plague Bloom: bigger, nastier mines.
	var pb := float(GameState.up("plague_bloom", "mine_mult", 1.0))
	dmg *= pb
	r *= sqrt(pb)
	RunFx.explosion(player, global_position, r, dmg, Color(0.55, 0.95, 0.35), "mine", 180.0)
	Juice.sfx_at("mine_boom", global_position)
	queue_free()
