extends Area2D

## Temporary buff pickup — walk over / touch to collect.

var def: Dictionary = {}
var _bob_base_y: float = 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var label: Label = $Label


func setup(powerup: Dictionary) -> void:
	def = powerup
	if sprite == null:
		sprite = $Sprite
	if label == null:
		label = $Label
	if sprite and powerup.has("sprite"):
		sprite.texture = load(str(powerup["sprite"])) as Texture2D
	if label:
		label.text = str(powerup.get("name", "Boost"))
		label.add_theme_color_override("font_color", powerup.get("color", Color.WHITE))
	call_deferred("_start_bob")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2


func _start_bob() -> void:
	_bob_base_y = position.y
	var tw := create_tween().set_loops()
	tw.tween_property(self, "position:y", _bob_base_y - 6.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position:y", _bob_base_y, 0.45).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("apply_powerup"):
		body.apply_powerup(def)
		queue_free()
