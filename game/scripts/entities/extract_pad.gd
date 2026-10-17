extends Area2D

signal extract_requested

@export var pad_name: String = "Extract"

var open: bool = false
var player_inside: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var label: Label = $Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label.text = pad_name
	set_open(false)


func set_open(is_open: bool) -> void:
	open = is_open
	if sprite:
		sprite.texture = load(
			"res://assets/sprites/props/extract_open.png" if open else "res://assets/sprites/props/extract_sealed.png"
		) as Texture2D
	if open:
		label.text = "%s — OPEN" % pad_name
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	else:
		label.text = "%s — SEALED" % pad_name
		label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))


func _process(_delta: float) -> void:
	if open and player_inside and Input.is_action_just_pressed("interact"):
		extract_requested.emit()


func try_touch_extract() -> bool:
	if open and player_inside:
		extract_requested.emit()
		return true
	return false


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
