extends Node

## Enemy art review shots in a real match (needs a display, e.g. xvfb-run):
##   xvfb-run -a -s "-screen 0 390x844x24" godot --path game --rendering-method gl_compatibility \
##     --resolution 390x844 res://tools/enemy_shots.tscn -- OUTDIR [kinds] [boss[:brain]]
## kinds: comma list of enemy kinds for the mixed-pack shots; boss: one boss
## kind (optionally with a campaign brain, e.g. raider_captain:vane).
## Three pack shots a few frames apart (jitter check), then the boss fight.

var _out := "/tmp/enemy_shots"
var _kinds := PackedStringArray(["raider_grunt", "raider_brute", "scrap_hound", "rad_gator", "toxic_scorp", "rad_bat", "glow_moth", "coil_spider"])
var _boss := "dust_warden"
var _save := ""


func _ready() -> void:
	GameState.onboard_skip = true
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	if a.size() > 1 and a[1] != "":
		_kinds = a[1].split(",")
	if a.size() > 2 and a[2] != "":
		_boss = a[2]
	DirAccess.make_dir_recursive_absolute(_out)
	_save = FileAccess.get_file_as_string(GameState.SAVE_PATH) if FileAccess.file_exists(GameState.SAVE_PATH) else ""
	_run.call_deferred()


func _run() -> void:
	TouchInput.touch_primary = true
	GameState.tutorial_done = true
	GameState.selected_mode_id = "haze"
	GameState.selected_character_id = "ash_rook"
	GameState.fast_timers = false
	GameState.begin_run()
	var m: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	await _frames(20)
	var player: Node2D = m.get_node("World/Player")
	player.set("max_hp", 99999.0)
	player.set("hp", 99999.0)
	player.set("damage_mult", 0.0)
	for k in range(_kinds.size()):
		var ang := -PI * 0.5 + TAU * float(k) / float(_kinds.size())
		var e := m.call("spawn_mob", _kinds[k], player.global_position + Vector2(cos(ang), sin(ang)) * 150.0) as Node2D
		if e:
			e.set("damage", 0.0)
	await _frames(45)
	player.set("damage_mult", 0.0)
	for i in range(3):
		await _snap("pack_%d" % i)
		await _frames(4)
	await _frames(60)
	await _snap("pack_fight")
	for e in get_tree().get_nodes_in_group("enemies"):
		(e as Node).queue_free()
	await _frames(5)
	var parts := _boss.split(":")
	var b := m.call("spawn_mob", parts[0], player.global_position + Vector2(40, -150), "boss") as Node2D
	if b and parts.size() > 1:
		m.call("attach_brain", b, parts[1])
	if b:
		b.set("damage", 0.0)
	await _frames(30)
	await _snap("boss_0")
	await _frames(40)
	await _snap("boss_1")
	await _frames(40)
	await _snap("boss_2")
	get_tree().paused = false
	if _save != "":
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(_save)
			f.close()
	print("ENEMY_SHOTS_DONE")
	get_tree().quit()


func _snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, n])
	print("SHOT ", n, " ", img.get_size())


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
