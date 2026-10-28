extends Node

## Polish pass 2 capture: frame sequences for review GIFs.
##   xvfb-run godot --path game --rendering-method gl_compatibility --fixed-fps 60 \
##     --resolution 720x1560 res://tools/fx_capture.tscn -- OUTDIR wipe
##   ... -- OUTDIR combat <hero_id>   (hero fighting a small pack, cropped)
##   ... -- OUTDIR fog <hero_id>      (same, next to a plague fog patch)

var _out := "/tmp/fx_capture"
var _mode := "wipe"
var _hero := "ash_rook"


func _ready() -> void:
	GameState.onboard_skip = true ## dev tool: every system on
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	if a.size() > 1:
		_mode = a[1]
	if a.size() > 2:
		_hero = a[2]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _grab(name: String, crop: Rect2i = Rect2i()) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if crop.size.x > 0:
		img = img.get_region(crop)
	img.save_png("%s/%s.png" % [_out, name])


func _scene(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	return inst


func _run() -> void:
	GameState.tutorial_done = true
	if _mode == "wipe":
		var a := _scene("res://scenes/ui/main_menu.tscn")
		await _wait(60)
		for i in range(4):
			await _grab("f%03d" % i)
		a.queue_free()
		_scene("res://scenes/ui/mode_select.tscn")
		for i in range(4, 30):
			await _grab("f%03d" % i)
			await get_tree().process_frame
	else:
		GameState.selected_character_id = _hero
		TouchInput.touch_primary = true
		GameState.begin_run()
		var m := _scene("res://scenes/match/match.tscn")
		await _wait(40)
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if _mode == "fog":
			var z := Node2D.new()
			z.set_script(load("res://scripts/entities/plague_zone.gd"))
			z.set("radius", 150.0)
			z.position = p.global_position + Vector2(90, 40)
			p.get_parent().add_child(z)
		var kinds := ["scrap_hound", "toxic_scorp", "raider_grunt"]
		for i in range(7):
			var ang := TAU * float(i) / 7.0
			m.call("spawn_at", "normal", kinds[i % 3], p.global_position + Vector2(cos(ang), sin(ang)) * (150.0 + 30.0 * float(i % 3)))
		await _wait(10)
		var vp := get_viewport().get_visible_rect().size
		var c := Vector2i(int(vp.x * 0.5), int(vp.y * 0.45))
		var crop := Rect2i(c - Vector2i(220, 220), Vector2i(440, 440))
		for i in range(70):
			p.set("hp", float(p.get("max_hp")))
			await _grab("f%03d" % i, crop)
			await get_tree().process_frame
	print("CAPTURE_DONE")
	get_tree().quit()
