extends "res://scripts/match/match_controller.gd"

## A CAMPAIGN level: the Wander match's hero, dog, mobs, HUD and level-ups, on
## a handcrafted map (campaign_world.gd) driven by the level's script
## (objective_runner.gd) instead of the stay-or-go phase clock. Story scenes,
## Helm's radio and the level cards sit on top.
##   intro card -> intro scene -> objectives -> extract -> outro scene -> outro card

const RunnerScript := preload("res://scripts/campaign/objective_runner.gd")
const StoryScript := preload("res://scripts/campaign/story_panel.gd")
const CardScript := preload("res://scripts/campaign/level_card.gd")

var level: Dictionary = {}
var runner: Node
var story: CanvasLayer
var card: CanvasLayer
var level_time: float = 0.0
var started: bool = false
var won: bool = false


func _ready() -> void:
	level = GameState.campaign_level()
	_mode = GameState.get_mode()
	_phases = []
	wasteland.set("level", level)
	wasteland.setup(int(level.get("seed", 1)), player)
	_clear_pads()
	player.died.connect(_on_player_died)
	if player.has_signal("hurt"):
		player.hurt.connect(func(_a: float) -> void:
			for pad in _pads:
				if is_instance_valid(pad) and pad.has_method("reset_channel"):
					pad.call("reset_channel")
		)
	player.health_changed.connect(hud.on_health_changed)
	if player.has_signal("buffs_changed"):
		player.buffs_changed.connect(hud.on_buffs_changed)
	hud.setup(self)
	hud.setup_nav(player, _pads, wasteland.get_landmarks())
	hud.call("set_campaign")
	var picker := CanvasLayer.new()
	picker.set_script(load("res://scripts/ui/run_upgrade_picker.gd"))
	add_child(picker)
	picker.chosen.connect(func(u: Dictionary) -> void:
		if is_instance_valid(hud):
			hud.show_toast(str(u.get("name", "Upgrade")) + "!", UiTheme.TEAL)
	)
	_spawn_pet()
	story = CanvasLayer.new()
	story.set_script(StoryScript)
	add_child(story)
	story.set("hero_name", str(GameState.get_character().get("display_name", "")))
	story.set("auto", GameState.campaign_autoplay)
	card = CanvasLayer.new()
	card.set_script(CardScript)
	add_child(card)
	if GameState.campaign_autoplay:
		card.set("auto", "default")
	runner = Node.new()
	runner.name = "ObjectiveRunner"
	runner.set_script(RunnerScript)
	add_child(runner)
	runner.call("setup", self, level)
	runner.level_won.connect(_on_level_won)
	runner.level_failed.connect(func(reason: String) -> void: _finish_wipe(reason))
	_start.call_deferred()


func _start() -> void:
	var first: Dictionary = {}
	for o in level.get("objectives", []):
		first = o
		break
	card.call("show_intro", level, GameState.selected_character_id, GameState.selected_pet_id if bool(GameState.pet.get("active", false)) else "", str(first.get("text", "")))
	await card.chosen
	if level.has("intro"):
		await play_scene(str(level["intro"]))
	started = true
	runner.call("start")


func _process(delta: float) -> void:
	if _ended:
		return
	if GameState.run_finished:
		_ended = true
		return
	if started:
		level_time += delta


## ---------------------------------------------------------------------------
## Called by the runner

func play_scene(id: String) -> void:
	var lines: Array = (level.get("scenes", {}) as Dictionary).get(id, [])
	if lines.is_empty():
		return
	await story.call("play", lines)


func radio(who: String, text: String) -> void:
	story.call("radio", who, text)


func toast(text: String, col: Color = UiTheme.AMBER) -> void:
	hud.show_toast(text, col)


func banner(title: String, sub: String = "") -> void:
	hud.show_banner(title, sub, UiTheme.AMBER)


func hud_objective(title: String, prog: String, ratio: float, hint: String) -> void:
	hud.call("set_objective", title, prog, ratio, hint)


func hud_objective_arrows(on: bool) -> void:
	hud.set_extract_open(on)


func boss_intro(boss_name: String, epithet: String) -> void:
	hud.boss_intro(boss_name)
	if epithet != "":
		hud.show_banner(boss_name.to_upper(), epithet, UiTheme.DANGER)


## One mob of `kind` at `at` (INF = just off screen), scaled to the level.
func spawn_mob(kind: String, at: Vector2 = Vector2.INF, role: String = "", hp_k: float = 1.0) -> Node:
	if not is_instance_valid(player):
		return null
	var spot := at
	if spot == Vector2.INF:
		var ang := randf() * TAU
		spot = _spawn_point_outside_view(Vector2(cos(ang), sin(ang)))
	var b: Rect2 = wasteland.get("bounds")
	spot = spot.clamp(b.position + Vector2(40, 40), b.end - Vector2(40, 40))
	for k in range(5):
		if _spot_free(spot, 26.0):
			break
		spot += Vector2.RIGHT.rotated(k * 1.7) * 40.0
	var enemy: CharacterBody2D = EnemyScene.instantiate()
	enemy.setup(spot, float(_mode.get("enemy_hp", 1.0)) * hp_k, float(_mode.get("enemy_damage", 1.0)), 1.0, kind)
	if role != "":
		enemy.call("set_role", role)
	world.add_child(enemy)
	if role == "elite":
		Juice.mob_sfx("roar", enemy)
	return enemy


## Kept for the admin panel's "Spawn elite / boss".
func spawn_special(role: String, kind: String = "") -> Node:
	var k := kind if kind != "" else ("cyber_juggernaut" if role == "elite" else "dread_naught")
	var e := spawn_mob(k, Vector2.INF, role)
	if role == "boss" and e:
		hud.boss_intro(str(EnemyDefs.get_kind(k).get("display_name", k)))
	return e


func spawn_extract_pad(at: Vector2) -> Node2D:
	var pad: Area2D = ExtractPadScene.instantiate()
	pads_root.add_child(pad)
	pad.global_position = at
	pad.pad_name = "Extract"
	if pad.has_signal("extract_requested"):
		pad.extract_requested.connect(_on_extract_requested)
	if pad.has_signal("channel_changed"):
		pad.channel_changed.connect(hud._on_channel)
	_pads.append(pad)
	_extract_open = true
	pad.call("set_open", true)
	hud.set_extract_open(true)
	if hud.has_method("ping_pads"):
		hud.call("ping_pads")
	Juice.sfx("ext_open")
	return pad


## A rescued dog joins as the run's companion.
func pet_join(pid: String, at: Vector2) -> void:
	if not PetDefs.is_equipable(pid):
		return
	for p in get_tree().get_nodes_in_group("pets"):
		p.queue_free()
	GameState.selected_pet_id = pid
	GameState.pet = HangarDefs.apply_kennel(LoadoutStubs.default_pet(pid), GameState.kennel_rank(pid))
	GameState.pet["active"] = true
	var pet: CharacterBody2D = PetScene.instantiate()
	world.add_child(pet)
	pet.global_position = at
	if pet.has_method("setup"):
		pet.call("setup", player, GameState.pet)


## Admin / tests.
func debug_complete_objective() -> void:
	if runner:
		runner.call("debug_complete")


## ---------------------------------------------------------------------------
## Level end

func _on_extract_requested() -> void:
	if _ended:
		return
	_ended = true
	won = true
	GameState.complete_campaign_level(level_time)
	Juice.sfx("extract_win")
	Juice.haptic(60)
	hud.show_banner("EXTRACTED", str(level.get("title", "")), Color(0.55, 1.0, 0.6))
	if is_instance_valid(player):
		Juice.burst(player.global_position, Color(1, 0.85, 0.4), 40, 260.0, 0.9, 1.4)
		var tw := player.create_tween()
		tw.tween_property(player, "modulate:a", 0.0, 0.8)
	_outro()


func _on_level_won() -> void:
	## The script ran out of objectives without an extract: count it as one.
	_on_extract_requested()


func _outro() -> void:
	await get_tree().create_timer(1.2, false).timeout
	if level.has("outro"):
		await play_scene(str(level["outro"]))
	card.call("show_outro", level, GameState.campaign_result)
	var a: String = await card.chosen
	match a:
		"next":
			var nxt := str(GameState.campaign_result.get("next", ""))
			if nxt != "" and CampaignDefs.is_playable(nxt):
				GameState.go_campaign_level(nxt)
			else:
				GameState.go_campaign_map()
		_:
			GameState.go_campaign_map()


func _finish_wipe(reason: String) -> void:
	if _ended:
		return
	_ended = true
	GameState.fail_campaign_level(reason)
	Juice.sfx("wipe")
	hud.show_banner("DOWN", reason, UiTheme.DANGER)
	await get_tree().create_timer(1.6, false).timeout
	card.call("show_fail", level, reason)
	var a: String = await card.chosen
	if a == "retry":
		GameState.go_campaign_level(str(level.get("id", "")), GameState.selected_character_id)
	else:
		GameState.go_campaign_map()


func is_run_over() -> bool:
	return _ended or GameState.run_finished


func request_auto_pause() -> void:
	if is_run_over() or (story and bool(story.get("active"))) or (card and card.visible):
		return
	super.request_auto_pause()


func is_extract_open() -> bool:
	return _extract_open


func get_phase_progress() -> float:
	return 0.0
