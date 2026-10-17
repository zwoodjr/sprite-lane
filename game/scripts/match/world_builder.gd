extends Node2D

## Builds a small hub + 3 spokes map with placeholder silhouettes.

func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	## Dust ochre ground wash
	draw_rect(Rect2(-900, -700, 1800, 1400), Color(0.28, 0.20, 0.14))
	## Hub plaza
	draw_circle(Vector2.ZERO, 160.0, Color(0.34, 0.24, 0.16))
	draw_arc(Vector2.ZERO, 160.0, 0, TAU, 48, Color(0.75, 0.45, 0.22), 3.0)
	## Spokes
	_draw_spoke(Vector2(420, 0), Color(0.32, 0.28, 0.18), "Scrapyard")
	_draw_spoke(Vector2(-360, -280), Color(0.22, 0.28, 0.24), "Flood Garage")
	_draw_spoke(Vector2(-200, 340), Color(0.30, 0.22, 0.26), "Signal Tower")
	## Cover blocks
	for p in [
		Vector2(80, -90), Vector2(-110, 60), Vector2(200, 120),
		Vector2(-250, -40), Vector2(90, 200), Vector2(-40, -220),
		Vector2(300, -150), Vector2(-320, 180),
	]:
		draw_rect(Rect2(p, Vector2(36, 28)), Color(0.18, 0.14, 0.12))
	## Landmark markers
	draw_circle(Vector2(420, 0), 18.0, Color(0.55, 0.7, 0.35))
	draw_circle(Vector2(-360, -280), 18.0, Color(0.35, 0.55, 0.65))
	draw_circle(Vector2(-200, 340), 18.0, Color(0.7, 0.4, 0.55))


func _draw_spoke(center: Vector2, color: Color, _name: String) -> void:
	draw_circle(center, 120.0, color)
	draw_line(Vector2.ZERO, center, Color(0.4, 0.3, 0.2, 0.6), 40.0)
