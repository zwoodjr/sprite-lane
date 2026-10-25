extends Node

## Settings screen captures: every tab (+ credits, hangar cog, pause overlay).
##   xvfb-run godot --path game --rendering-method gl_compatibility \
##     --resolution 720x1560 res://tools/settings_shots.tscn -- OUTDIR

const SettingsMenu = preload("res://scripts/ui/settings_menu.gd")
var _out: String = "/tmp/settings_shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name)


func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _run() -> void:
	var keep: Dictionary = GameState.settings.duplicate(true)
	var inst: Node = (load("res://scenes/ui/settings_menu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	await _wait(30)
	var i := 1
	for t in SettingsDefs.TABS:
		inst.call("show_tab", str(t["id"]))
		await _wait(12)
		await _snap("%d_%s" % [i, str(t["id"])])
		i += 1
	inst.call("show_credits")
	await _wait(12)
	await _snap("%d_credits" % i)
	inst.queue_free()
	await get_tree().process_frame
	var hg: Node = (load("res://scenes/ui/hangar.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(hg)
	get_tree().current_scene = hg
	await _wait(30)
	await _snap("hangar_cog")
	hg.queue_free()
	GameState.settings = keep
	get_tree().quit()
