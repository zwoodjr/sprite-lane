extends Node

## Busy-moment minimap review shots (needs a display, e.g. xvfb-run):
##   godot --path game --rendering-method gl_compatibility --resolution 720x1560 res://tools/minimap_shots.tscn -- OUTDIR
## Event + radio jobs active, elite + boss near, gear drops by rarity, pads open off-map.
## Writes busy.png, busy_legend.png and minimap_x3.png (3x nearest crop of the map).

var _out: String = "/tmp/minimap_shots"


func _ready() -> void:
	GameState.onboard_skip = true ## dev tool: every system on
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _snap(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name, " ", img.get_size())
	return img


func _mob(m: Node, kind: String, at: Vector2) -> Node2D:
	var e: CharacterBody2D = (load("res://scenes/entities/enemy.tscn") as PackedScene).instantiate()
	e.setup(at, 50.0, 0.0, 1.0, kind)
	m.get_node("World").add_child(e)
	e.set("_spawn_in", 0.0)
	return e


func _run() -> void:
	GameState.selected_character_id = "sister_cinder"
	GameState.selected_mode_id = "drift"
	GameState.fast_timers = false
	GameState.tutorial_done = true
	var adm := get_node_or_null("/root/Admin")
	if adm:
		adm.call("set_enabled", true)
	GameState.begin_run()
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	await _wait(10)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(2)
	var player: Node2D = m.get_node("World/Player")
	var world: Node2D = m.get_node("World")
	var o := player.global_position
	## Mobs all round, an elite and a boss inside the map, a boss beyond it.
	var kinds := ["scrap_hound", "coil_spider", "scrap_hound"]
	for i in range(30):
		var a := TAU * float(i) / 30.0 + 0.3
		_mob(m, str(kinds[i % kinds.size()]), o + Vector2(cos(a), sin(a)) * (220.0 + 40.0 * float(i % 9)))
	var el: Node = m.call("spawn_special", "elite")
	if el:
		(el as Node2D).global_position = o + Vector2(380, -260)
	var bs: Node = m.call("spawn_special", "boss")
	if bs:
		(bs as Node2D).global_position = o + Vector2(-620, 420)
	var bs2: Node = m.call("spawn_special", "boss")
	if bs2:
		(bs2 as Node2D).global_position = o + Vector2(-2600, -900)
	## Gear drops by rarity, medicine, ammo.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var r_i := 0
	for rar in ["common", "rare", "epic", "legendary"]:
		var it := GearDefs.roll_drop(2, GameState.selected_character_id, 0.0, rng, "", rar)
		if it.is_empty():
			it = {"rarity": rar}
		it["rarity"] = rar
		GearPickup.spawn(world, o + Vector2(-500 + 150 * r_i, 600), it)
		r_i += 1
	HaulPickup.spawn(world, o + Vector2(700, 300), "medicine", 1, false)
	RunFx.spawn_ammo_pickup(world, o + Vector2(560, 650))
	## Event + radio jobs (one close, one far for a rim marker).
	var ev: Node = m.get_node("RunEvents")
	ev.call("start_event", "scrap_spike")
	var jobs: Node = m.get_node("RadioJobs")
	jobs.call("start", "field_tent", o + Vector2(-560, -300))
	jobs.call("start", "medicine_cache", o + Vector2(2400, 2600))
	## Open the extract window (pads are placed far out → rim chevrons).
	var phases: Array = m.get("_phases")
	for i in range(phases.size()):
		if bool(phases[i].get("extract_open", false)):
			m.call("_start_phase", i)
			break
	await _wait(40)
	## Keep everyone still for the shot.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	TouchInput.set_move(Vector2(0.6, -0.8))
	await _wait(12)
	TouchInput.set_move(Vector2.ZERO)
	await _wait(4)
	var img := await _snap("busy")
	var hud: Node = m.get_node("HUD")
	var mm: Control = hud.get("_minimap")
	_crop(img, mm, "minimap_x3")
	print("MINIMAP icons=%d rim=%d ids=%s rim_ids=%s" % [int(mm.call("icon_count")), int(mm.call("rim_count")), str(mm.call("icon_ids")), str(mm.call("rim_ids"))])
	mm.call("toggle_legend")
	await _wait(3)
	var img2 := await _snap("busy_legend")
	var lr := mm.get_global_rect()
	var big := Rect2(lr.position - Vector2(130, 0), lr.size + Vector2(130, 70))
	_crop_rect(img2, big, "legend_x3")
	get_tree().quit()


func _crop(img: Image, c: Control, name: String) -> void:
	var r := c.get_global_rect().grow(4.0)
	r.size.y += 60.0
	_crop_rect(img, r, name)


func _crop_rect(img: Image, r: Rect2, name: String) -> void:
	## Viewport -> image pixels (stretch may scale).
	var vr := get_viewport().get_visible_rect().size
	var k := Vector2(img.get_width(), img.get_height()) / vr
	var ri := Rect2i(Vector2i((r.position * k).floor()), Vector2i((r.size * k).ceil()))
	ri = ri.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var sub := img.get_region(ri)
	sub.resize(sub.get_width() * 3, sub.get_height() * 3, Image.INTERPOLATE_NEAREST)
	sub.save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name)
