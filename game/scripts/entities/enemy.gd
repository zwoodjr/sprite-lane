extends CharacterBody2D

signal died

const BulletScene := preload("res://scenes/entities/bullet.tscn")

@export var base_speed: float = 110.0
@export var base_hp: float = 40.0
@export var base_damage: float = 8.0
@export var attack_range: float = 280.0
@export var preferred_range: float = 180.0

var hp: float = 40.0
var max_hp: float = 40.0
var damage: float = 8.0
var speed: float = 110.0
var _fire_cd: float = 0.0
var _player: Node2D

@onready var body: Polygon2D = $Body
@onready var hp_bar: ProgressBar = $HpBar


func setup(spawn_pos: Vector2, hp_mult: float, dmg_mult: float, spd_mult: float = 1.0) -> void:
	global_position = spawn_pos
	max_hp = base_hp * hp_mult
	hp = max_hp
	damage = base_damage * dmg_mult
	speed = base_speed * spd_mult
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp


func _ready() -> void:
	add_to_group("enemies")
	body.color = Color(0.55, 0.18, 0.14)
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp


func _physics_process(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	if dist > preferred_range:
		velocity = dir * speed
	elif dist < preferred_range * 0.6:
		velocity = -dir * speed * 0.7
	else:
		velocity = dir.orthogonal() * speed * 0.5
	move_and_slide()
	if dist <= attack_range and _fire_cd <= 0.0:
		_shoot(dir)


func _shoot(dir: Vector2) -> void:
	_fire_cd = 1.1
	var bullet: Area2D = BulletScene.instantiate()
	bullet.setup(global_position + dir * 14.0, dir, 420.0, damage, false)
	get_tree().current_scene.add_child(bullet)


func take_damage(amount: float) -> void:
	hp -= amount
	if hp_bar:
		hp_bar.value = hp
	if hp <= 0.0:
		GameState.kills += 1
		GameState.scrap_found += randi_range(1, 4)
		died.emit()
		queue_free()
