extends Node

## In-match side-by-side of a hero and the pet (art QA; needs a display, e.g. xvfb-run):
##   xvfb-run -a -s "-screen 0 1179x2556x24" godot --path game --rendering-method gl_compatibility \
##     --resolution 1179x2556 res://tools/hero_pet_capture.tscn -- OUTDIR HERO_ID PET_ID
## The hero walks a short step then stands; writes OUTDIR/hp_NN.png (full view) for the last frames.

var _out: String = "/tmp/hpcap"
var _hero: String = "ash_rook"
var _pet: String = "noel"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_hero = args[1]
	if args.size() > 2:
		_pet = args[2]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()


func _run() -> void:
	GameState.tutorial_done = true
	GameState.selected_character_id = _hero
	GameState.selected_pet_id = _pet
	TouchInput.touch_primary = true
	GameState.begin_run()
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	for f in range(150):
		_clear_enemies()
		await get_tree().process_frame
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var pet := get_tree().get_first_node_in_group("pets") as Node2D
	if p and pet:
		pet.global_position = p.global_position + Vector2(46, 4)
	for f in range(8):
		_clear_enemies()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/hp_%02d.png" % [_out, f])
	print("HPCAP_DONE")
	get_tree().quit()
