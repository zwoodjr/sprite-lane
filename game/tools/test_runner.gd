extends Node

## Headless test harness (autoloads active).
##   godot --headless --path game res://tools/test_runner.tscn
## 1) loads + instantiates every script/scene
## 2) opens each menu for a few frames
## 3) plays a fast-timer match with a bot driving the touch inputs
## Prints TEST_PASS / TEST_FAIL. Watch stderr for SCRIPT ERRORs.

const MENUS := [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/mode_select.tscn",
	"res://scenes/ui/character_select.tscn",
	"res://scenes/ui/how_to_play.tscn",
	"res://scenes/ui/settings_menu.tscn",
	"res://scenes/ui/result_screen.tscn",
	"res://scenes/ui/hangar.tscn",
]

var _bad: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	## 1. Load everything
	for path in _walk("res://scripts") + _walk("res://scenes"):
		if not (path.ends_with(".gd") or path.ends_with(".tscn")):
			continue
		var r := ResourceLoader.load(path)
		if r == null:
			print("FAIL load ", path)
			_bad += 1
	print("LOAD_OK")
	## 2. Menus
	for m in MENUS:
		var inst: Node = (load(m) as PackedScene).instantiate()
		get_tree().root.add_child(inst)
		for i in range(10):
			await get_tree().process_frame
		inst.queue_free()
		await get_tree().process_frame
	print("MENUS_OK")
	## 3. Match with a bot, per character and mode
	var chars: Array = ["ash_rook", "sister_cinder"]
	var modes: Array = ["easy", "medium"]
	for i in range(2):
		GameState.selected_character_id = chars[i]
		GameState.selected_mode_id = modes[i]
		GameState.fast_timers = true
		GameState.tutorial_done = (i == 1)  ## first pass exercises the tutorial
		GameState.begin_run()
		var match_scene: Node = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
		get_tree().root.add_child(match_scene)
		get_tree().current_scene = match_scene
		var t := 0.0
		var frames := 0
		var player: Node2D = match_scene.get_node("World/Player")
		var hud: Node = match_scene.get_node("HUD")
		var paused_once := false
		while frames < 3600 and is_instance_valid(match_scene) and not bool(match_scene.get("_ended")):
			var dt := get_process_delta_time()
			t += dt
			frames += 1
			## Bot: circle-strafe; single-stick run-aim toward nearest enemy.
			var target := Vector2(cos(t * 0.7), sin(t * 0.9)).normalized()
			var en := get_tree().get_nodes_in_group("enemies")
			if en.size() > 0 and is_instance_valid(player):
				target = ((en[0] as Node2D).global_position - player.global_position).normalized()
			TouchInput.set_move(target)
			if bool(GameState.settings.get("twin_stick", false)):
				TouchInput.set_aim(target * 0.9)
			if frames % 120 == 0:
				TouchInput.pulse_dash()
			if frames % 400 == 0:
				TouchInput.pulse_ability()
			if frames % 700 == 0:
				TouchInput.pulse_mount()
			if frames == 300 and not paused_once:
				paused_once = true
				hud.call("_open_pause")
				await get_tree().process_frame
				get_tree().paused = false
				var pm := get_tree().root.find_children("*", "CanvasLayer", true, false)
				for n in pm:
					if n.has_method("close"):
						n.call("close")
			## Walk to an open pad whenever extracts are up (windows are shorter now).
			if bool(match_scene.call("is_extract_open")) and frames > 400 and is_instance_valid(player):
				var pads: Array = match_scene.call("get_pads")
				for pad in pads:
					if is_instance_valid(pad) and bool(pad.get("open")):
						player.global_position = (pad as Node2D).global_position
						break
			await get_tree().physics_frame
		print("MATCH_%d frames=%d kills=%d scrap=%d tl=%d extracted=%s wiped=%s" % [
			i, frames, GameState.kills, GameState.scrap_found, GameState.threat_level,
			GameState.extracted, GameState.wiped])
		TouchInput.clear_sticks()
		## The match changes scene to results on its own; give it time, then clean up.
		for k in range(150):
			await get_tree().process_frame
		for n in get_tree().root.get_children():
			if n != self and not (n.name in ["GameState", "TouchInput", "DisplayFit", "Juice", "UiTheme"]):
				n.queue_free()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	print("TEST_PASS" if _bad == 0 else "TEST_FAIL bad=%d" % _bad)
	get_tree().quit(0 if _bad == 0 else 1)


func _walk(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_walk(dir + "/" + sub))
	return out
