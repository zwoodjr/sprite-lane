extends Node2D

## Admin > DEBUG > Hitboxes: draws every player / enemy / pickup / pad
## collision shape in world space. Lives under the match world while on.

const GROUPS := {
	"player": Color(0.3, 1.0, 0.45, 0.9),
	"enemies": Color(1.0, 0.3, 0.25, 0.9),
	"pets": Color(0.4, 0.8, 1.0, 0.9),
	"breakables": Color(1.0, 0.85, 0.3, 0.7),
}


func _ready() -> void:
	z_index = 4000
	z_as_relative = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for g in GROUPS:
		var col: Color = GROUPS[g]
		for n in get_tree().get_nodes_in_group(g):
			if not (n is Node2D) or not is_instance_valid(n):
				continue
			var cs := (n as Node).get_node_or_null("CollisionShape2D") as CollisionShape2D
			if cs == null or cs.shape == null:
				continue
			var at := to_local(cs.global_position)
			var sc := cs.global_scale
			if cs.shape is CircleShape2D:
				draw_arc(at, (cs.shape as CircleShape2D).radius * sc.x, 0.0, TAU, 24, col, 1.5)
			elif cs.shape is RectangleShape2D:
				var sz := (cs.shape as RectangleShape2D).size * sc
				draw_rect(Rect2(at - sz * 0.5, sz), col, false, 1.5)
			elif cs.shape is CapsuleShape2D:
				var cap := cs.shape as CapsuleShape2D
				var r := cap.radius * sc.x
				var hh := maxf(0.0, cap.height * 0.5 * sc.y - r)
				draw_arc(at + Vector2(0, -hh), r, PI, TAU, 12, col, 1.5)
				draw_arc(at + Vector2(0, hh), r, 0.0, PI, 12, col, 1.5)
				draw_line(at + Vector2(-r, -hh), at + Vector2(-r, hh), col, 1.5)
				draw_line(at + Vector2(r, -hh), at + Vector2(r, hh), col, 1.5)
			## Enemies: their attack reach as a faint ring.
			if g == "enemies" and n.get("attack_range") != null:
				draw_arc(to_local((n as Node2D).global_position), float(n.get("attack_range")), 0.0, TAU, 24, Color(col, 0.3), 1.0)
