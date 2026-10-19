extends Node

## Map-detail review shots (needs a display, e.g. xvfb-run).
##   godot --path game --rendering-method gl_compatibility res://tools/map_shots.tscn -- OUTDIR SEED "x,y;x,y;..."
## Starts a match with a fixed seed, teleports the hero to each world point,
## lets the world stream in, and saves shot_N.png.

var _out := "/tmp/map_shots"
var _seed := 4242
var _pts: Array[Vector2] = [Vector2.ZERO]


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	if a.size() > 1: _seed = int(a[1])
	if a.size() > 2 and a[2] != "":
		_pts.clear()
		for s in a[2].split(";"):
			var xy := s.split(",")
			if xy.size() == 2:
				_pts.append(Vector2(float(xy[0]), float(xy[1])))
	## arg 4: tier / mode id (zone set), e.g. "blackout".
	if a.size() > 4 and a[4] != "":
		GameState.selected_mode_id = a[4]
	if a.size() > 3 and a[3] == "shimmer":
		GameState.settings["heat_shimmer"] = true
	DirAccess.make_dir_recursive_absolute(_out)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	GameState.tutorial_done = true
	TouchInput.touch_primary = true
	GameState.begin_run()
	GameState.run_seed = _seed
	seed(_seed)
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	var player: Node2D = m.get_node("World/Player")
	for f in range(30):
		await get_tree().process_frame
	var amb := m.find_child("AmbientFx", true, false)
	var wl := m.get_node_or_null("World/Wasteland")
	if wl and wl.get("field"):
		for road in wl.get("field").roads:
			print("ROAD ", road["pts"])
	var args := OS.get_cmdline_user_args()
	if args.size() > 3 and args[3] == "bench":
		## Stand still for 20 s with the field cleared; print average fps.
		var sum := 0.0
		var n := 0
		var t0 := Time.get_ticks_msec()
		var last := t0
		while Time.get_ticks_msec() - t0 < 20000:
			for e in get_tree().get_nodes_in_group("enemies"):
				e.queue_free()
			if "hp" in player:
				player.set("hp", 9999.0)
			await get_tree().process_frame
			var now := Time.get_ticks_msec()
			if now - t0 > 4000:
				sum += float(now - last)
				n += 1
			last = now
		print("BENCH avg_fps=%.1f frames=%d" % [1000.0 * n / maxf(sum, 1.0), n])
		get_tree().quit()
		return
	for i in range(_pts.size()):
		player.global_position = _pts[i]
		for e in get_tree().get_nodes_in_group("enemies"):
			if (e as Node2D).global_position.distance_to(_pts[i]) < 260.0:
				e.queue_free()
		for f in range(150):
			if f == 125 and amb:
				amb.set("_next", 0.01) ## a tumbleweed rolls in during each shot
			if "hp" in player:
				player.set("hp", 9999.0)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%d.png" % [_out, i])
		print("SHOT %d at %s" % [i, _pts[i]])
	get_tree().quit()
