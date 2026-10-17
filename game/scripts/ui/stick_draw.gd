extends Control

## Full-screen IGNORE overlay — only draws floating sticks (paint from host).

var host: Node = null


func _draw() -> void:
	if host and host.has_method("paint_sticks"):
		host.paint_sticks(self)
