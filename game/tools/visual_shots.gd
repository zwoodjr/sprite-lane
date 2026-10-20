extends Node

## Visual tier review shots (needs a display, e.g. xvfb-run):
##   xvfb-run -a -s "-screen 0 720x1560x24" godot --path game --rendering-method gl_compatibility \
##     --resolution 720x1560 res://tools/visual_shots.tscn -- OUTDIR [zones] [hero]
## zones: comma list of mode ids (default haze,pall,shroud,blackout,dustfall).
## Each shot: a match in that zone, a radio landmark next to the hero, a small
## pack of mobs closing in, the pet. Plus the hangar. Save restored afterwards.

var _out: String = "/tmp/visual"
var _zones: PackedStringArray = PackedStringArray(["haze", "pall", "shroud", "blackout", "dustfall"])
var _hero: String = "ash_rook"
var _save: String = ""
const JOBS := ["black_box", "field_tent", "vault", "overwatch", "defend_relay"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1 and args[1] != "":
		_zones = args[1].split(",")
	if args.size() > 2:
		_hero = args[2]
	DirAccess.make_dir_recursive_absolute(_out)
	_save = FileAccess.get_file_as_string(GameState.SAVE_PATH) if FileAccess.file_exists(GameState.SAVE_PATH) else ""
	_run.call_deferred()


func _run() -> void:
	TouchInput.touch_primary = true
	GameState.tutorial_done = true
	GameState.best_tier_extracted = 10
	var i := 0
	for z in _zones:
		await _zone_shot(z, i)
		i += 1
	if _zones.size() > 1:
		var h: Node = (load("res://scenes/ui/hangar.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(h)
		get_tree().current_scene = h
		await _frames(30)
		await _snap("hangar")
		h.queue_free()
		await _frames(3)
	get_tree().paused = false
	if _save != "":
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(_save)
			f.close()
	print("VISUAL_SHOTS_DONE")
	get_tree().quit()


func _zone_shot(mode: String, idx: int) -> void:
	GameState.selected_mode_id = mode
	GameState.selected_character_id = _hero
	GameState.fast_timers = false
	GameState.begin_run()
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	await _frames(20)
	var player: Node2D = m.get_node("World/Player")
	player.set("max_hp", 9999.0)
	player.set("hp", 9999.0)
	var jobs: Node = m.get_node_or_null("RadioJobs")
	if jobs:
		jobs.call("start", JOBS[idx % JOBS.size()], player.global_position + Vector2(170, -190))
	var kinds := ["scrap_hound", "scrap_hound", "toxic_scorp", "raider_grunt", "rad_gator"]
	for k in range(kinds.size()):
		var a := -0.6 + k * 0.55
		_mob(m, kinds[k], player.global_position + Vector2(cos(a), sin(a)) * (300.0 + 30.0 * k))
	await _frames(70)
	await _snap("%02d_%s" % [idx + 1, mode])
	m.queue_free()
	await _frames(3)


func _mob(m: Node, kind: String, at: Vector2) -> Node2D:
	var e: CharacterBody2D = (load("res://scenes/entities/enemy.tscn") as PackedScene).instantiate()
	e.setup(at, 1.0, 0.2, 1.0, kind)
	m.get_node("World").add_child(e)
	return e


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name, " ", img.get_size())


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
