extends Area2D

signal extract_requested

@export var pad_name: String = "Extract"

var open: bool = false
var player_inside: bool = false

@onready var poly: Polygon2D = $Poly
@onready var label: Label = $Label
@onready var beacon: Polygon2D = $Beacon


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label.text = pad_name
	set_open(false)


func set_open(is_open: bool) -> void:
	open = is_open
	if open:
		poly.color = Color(0.95, 0.75, 0.25, 0.45)
		beacon.color = Color(1.0, 0.85, 0.3, 0.9)
		label.text = "%s — OPEN (E)" % pad_name
	else:
		poly.color = Color(0.35, 0.32, 0.28, 0.35)
		beacon.color = Color(0.4, 0.38, 0.35, 0.5)
		label.text = "%s — SEALED" % pad_name


func _process(_delta: float) -> void:
	if open and player_inside and Input.is_action_just_pressed("interact"):
		extract_requested.emit()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
