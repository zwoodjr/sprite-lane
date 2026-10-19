extends Node

## In-game capture of a pet for animation review (needs a display, e.g. xvfb-run):
##   xvfb-run -a -s "-screen 0 720x1280x24" godot --path game --rendering-method gl_compatibility \
##     --fixed-fps 24 res://tools/pet_capture.tscn -- OUTDIR PET_ID
## Writes OUTDIR/fNNNN.png (full 720x1280 view): hero runs a loop with the pet
## following, stops (pet idles, sits, rests), then a mob walks in for a bite.

var _out: String = "/tmp/petcap"
var _pet: String = "noel"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_pet = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()


func _run() -> void:
	GameState.tutorial_done = true
	GameState.selected_character_id = "ash_rook"
	GameState.selected_pet_id = _pet
	TouchInput.touch_primary = true
	GameState.begin_run()
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	var tc: Node = null
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.has_method("paint_sticks"):
			tc = n
	for f in range(30):
		_clear_enemies()
		await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	var c := Vector2(vp.x * 0.3, vp.y * 0.78)
	var k := 0
	## 0-3.5 s run a slow arc, 3.5-8 s stand (idle -> sit -> rest), 8-10 s a bite.
	for f in range(240):
		_clear_enemies()
		if f == 0 and tc:
			tc.call("_begin_touch", 0, c)
		if f < 84 and tc:
			var a := -0.4 + f * 0.035
			tc.call("_drag_touch", 0, c + Vector2(cos(a), sin(a) * 0.6) * 48.0)
		if f == 84 and tc:
			tc.call("_end_touch", 0)
		await _snap(k)
		k += 1
	var pet := get_tree().get_first_node_in_group("pets") as Node2D
	if pet:
		var e: Node = (load("res://scenes/entities/enemy.tscn") as PackedScene).instantiate()
		e.call("setup", pet.global_position + Vector2(70, 10), 3.0, 0.2, 1.0, "scrap_hound")
		m.get_node("World").add_child(e)
	for f in range(60):
		await _snap(k)
		k += 1
	print("PETCAP_DONE ", k)
	get_tree().quit()


func _snap(i: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/f%04d.png" % [_out, i])
