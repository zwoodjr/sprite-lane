extends StaticBody2D

## Destructible scrap / apothecary prop. Player bullets (and mounted ram) break it.

signal broken(global_pos: Vector2)

const PowerupDefs = preload("res://scripts/data/powerup_defs.gd")
const PickupScene := preload("res://scenes/entities/powerup_pickup.tscn")

@export var max_hp: float = 24.0
@export var drop_chance: float = 0.72

var hp: float = 24.0
var kind: String = "crate"

@onready var sprite: Sprite2D = $Sprite


func setup(kind_id: String, tex: Texture2D, p_hp: float = 24.0) -> void:
	kind = kind_id
	max_hp = p_hp
	hp = p_hp
	if sprite == null:
		sprite = $Sprite
	sprite.texture = tex
	sprite.centered = true


func _ready() -> void:
	add_to_group("breakables")
	collision_layer = 1
	collision_mask = 0
	hp = max_hp


func take_damage(amount: float) -> void:
	hp -= amount
	if sprite:
		sprite.modulate = Color(1.4, 1.1, 0.9)
		var t := get_tree().create_timer(0.06)
		t.timeout.connect(func() -> void:
			if is_instance_valid(sprite):
				sprite.modulate = Color.WHITE
		)
	if hp <= 0.0:
		_break_open()


func _break_open() -> void:
	var pos := global_position
	broken.emit(pos)
	if randf() <= drop_chance:
		var pickup: Area2D = PickupScene.instantiate()
		var parent := get_tree().current_scene
		parent.add_child(pickup)
		pickup.global_position = pos
		pickup.call("setup", PowerupDefs.random_powerup())
	## Scrap stub
	GameState.scrap_found += randi_range(1, 3)
	queue_free()
