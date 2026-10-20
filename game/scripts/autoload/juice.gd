extends Node

## Game-feel helpers: screen shake, hit sparks, floating numbers, SFX pool.
## Autoload as "Juice". Everything is fire-and-forget and safe to call
## from any scene (no-ops when there's no camera / scene).

const SoundScript = preload("res://scripts/autoload/sound.gd")

## Legacy one-word ids (pre sound pass) -> new ids. "@x" = per-hero lookup.
const LEGACY := {
	"shot": "@fire", "shoot": "fire_helm", "enemy_shot": "machine_shot", "hit": "hit_flesh", "enemy_die": "plague_die",
	"hurt": "@hurt", "dash": "dash", "reload": "@reload", "break": "break_wood", "pickup": "pick_common",
	"extract_open": "ext_open", "seal": "ext_close", "extract_win": "ext_success", "wipe": "run_wipe",
	"threat_up": "threat_up", "ability": "@ability", "empty": "dry_fire", "mount": "dash",
}
## Per-hero sound kit.
const HERO_SFX := {
	"ash_rook": {"fire": "fire_rook", "impact": "boom_rook", "reload": "reload_launcher", "ability": "ab_rush"},
	"vesper_thorn": {"fire": "fire_vesper", "reload": "reload_rifle", "ability": "ab_vial"},
	"pebble": {"swing": "swing_pebble", "impact": "impact_pebble", "ability": "swing_pebble"},
	"bolt_juno": {"swing": "swing_juno", "impact": "impact_juno", "ability": "swing_juno", "voice": "m"},
	"sister_cinder": {"fire": "fire_cinder", "reload": "reload_rifle", "ability": "ab_heal"},
	"quill_marrow": {"fire": "fire_quill", "swing": "swing_quill", "impact": "impact_quill", "reload": "reload_smg", "ability": "ab_mark"},
	"nyx_caldera": {"swing": "swing_nyx", "impact": "impact_nyx", "ability": "ab_blade"},
	"helm_wisp": {"fire": "fire_helm", "reload": "reload_pistol", "ability": "ab_drone"},
}

## Audio director (buses, pools, music, ambience). See sound.gd.
var snd: Node

var _trauma: float = 0.0
var _shake_t: float = 0.0
var _hitstop_left: float = 0.0
var _spark_tex: Texture2D
var _pixel_font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	snd = SoundScript.new()
	snd.name = "Sound"
	add_child(snd)
	_spark_tex = _make_spark_texture()
	if ResourceLoader.exists("res://assets/fonts/PressStart2P.ttf"):
		_pixel_font = load("res://assets/fonts/PressStart2P.ttf")


## --- Audio -----------------------------------------------------------------

## Fire-and-forget SFX. `name` is a sound id (see sound.gd) or a legacy word.
## pitch_jitter < 0 uses the id's own default. Returns the voice (or null).
func sfx(name: String, volume_db: float = 0.0, pitch_jitter: float = -1.0) -> Node:
	if snd == null:
		return null
	return snd.call("play", resolve(name), volume_db, pitch_jitter, Vector2.INF)


## Positional SFX in world space: pans + fades with distance from the camera.
func sfx_at(name: String, pos: Vector2, volume_db: float = 0.0, pitch_jitter: float = -1.0) -> Node:
	if snd == null:
		return null
	return snd.call("play", resolve(name), volume_db, pitch_jitter, pos)


## The selected hero's sound for a slot (fire / swing / impact / reload / ability / hurt / death).
func hero_sfx(kind: String, volume_db: float = 0.0) -> Node:
	return sfx("@" + kind, volume_db)


## A mob's voice for an event (attack / hurt / die / shot), by faction + role.
func mob_sfx(event: String, mob: Node, volume_db: float = 0.0) -> Node:
	if mob == null or not (mob is Node2D):
		return null
	var fac := str(mob.get("faction")) if mob.get("faction") != null else "plague"
	if fac != "machine" and fac != "raider":
		fac = "plague"
	var id := fac + "_" + event
	if event == "shot" and fac == "plague":
		id = "plague_spit"
	var role := str(mob.get("role")) if mob.get("role") != null else ""
	if event == "roar":
		id = "elite_spawn" if role != "boss" else ("boss_roar_machine" if fac == "machine" else "boss_roar_plague")
	if role == "boss" or role == "elite":
		volume_db += 3.0
	return sfx_at(id, (mob as Node2D).global_position, volume_db)


func resolve(name: String) -> String:
	var id: String = LEGACY.get(name, name)
	if not id.begins_with("@"):
		return id
	var kind := id.substr(1)
	var hero := GameState.selected_character_id
	var kit: Dictionary = HERO_SFX.get(hero, HERO_SFX["helm_wisp"])
	match kind:
		"hurt":
			return "hurt_m" if kit.get("voice", "f") == "m" else "hurt_f"
		"death":
			return "death_m" if kit.get("voice", "f") == "m" else "death_f"
		"fire":
			return str(kit.get("fire", kit.get("swing", "fire_helm")))
		"swing":
			return str(kit.get("swing", kit.get("fire", "dash")))
		"impact":
			return str(kit.get("impact", "hit_flesh"))
		"reload":
			return str(kit.get("reload", "reload_rifle"))
		"ability":
			return str(kit.get("ability", "ab_rush"))
	return kind


func apply_audio_settings() -> void:
	if snd:
		snd.call("apply_settings")


func haptic(ms: int = 20) -> void:
	if GameState.settings.get("haptics", true) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## --- Screen shake ------------------------------------------------------------

func shake(amount: float) -> void:
	if not GameState.settings.get("screen_shake", true):
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func hitstop(seconds: float) -> void:
	_hitstop_left = maxf(_hitstop_left, seconds)


func _process(delta: float) -> void:
	## Hitstop: briefly slow time on big hits for weight.
	if _hitstop_left > 0.0:
		_hitstop_left -= delta / maxf(Engine.time_scale, 0.01)
		Engine.time_scale = 0.08 if _hitstop_left > 0.0 else 1.0
	var cam := _camera()
	if cam == null:
		_trauma = 0.0
		return
	_shake_t += delta * 40.0
	_trauma = maxf(0.0, _trauma - delta * 1.8)
	var s := _trauma * _trauma
	var off := Vector2(
		sin(_shake_t * 1.3) + sin(_shake_t * 2.9) * 0.5,
		cos(_shake_t * 1.7) + cos(_shake_t * 3.3) * 0.5
	) * 14.0 * s
	cam.set("shake_offset", off)


func _camera() -> Camera2D:
	var vp := get_viewport()
	if vp == null:
		return null
	return vp.get_camera_2d()


## --- Particles / floating text -------------------------------------------

func burst(pos: Vector2, color: Color, amount: int = 10, speed: float = 160.0, life: float = 0.4, scale: float = 1.0) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := CPUParticles2D.new()
	p.texture = _spark_tex
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.2
	p.damping_max = speed * 2.0
	p.scale_amount_min = 0.5 * scale
	p.scale_amount_max = 1.2 * scale
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	p.global_position = pos
	p.z_index = 20
	scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)


func dust_puff(pos: Vector2, amount: int = 4) -> void:
	burst(pos, Color(0.78, 0.64, 0.45, 0.55), amount, 50.0, 0.45, 1.3)


func float_text(pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 18) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var l := Label.new()
	l.text = text
	l.z_index = 50
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(120, 30)
	l.position = pos - Vector2(60, 30) + Vector2(randf_range(-10, 10), 0)
	l.pivot_offset = Vector2(60, 15)
	l.scale = Vector2(0.6, 0.6)
	scene.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 38.0, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)


## Pixel-font damage number. Crits are amber and bigger.
func damage_number(pos: Vector2, amount: float, crit: bool = false, color: Color = Color(1, 0.97, 0.9)) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var l := Label.new()
	l.text = str(maxi(1, int(round(amount))))
	l.z_index = 50
	if _pixel_font:
		l.add_theme_font_override("font", _pixel_font)
	var size := 15 if crit else 10
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1.0, 0.72, 0.2) if crit else color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	l.add_theme_constant_override("outline_size", 6 if crit else 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(80, 24)
	l.pivot_offset = Vector2(40, 12)
	l.position = pos - Vector2(40, 12) + Vector2(randf_range(-12, 12), randf_range(-4, 4))
	l.scale = Vector2(1.6, 1.6) if crit else Vector2(1.2, 1.2)
	scene.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - (34.0 if crit else 24.0), 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func flash(node: CanvasItem, color: Color = Color(3, 3, 3), dur: float = 0.07) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.modulate = color
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", Color.WHITE, dur)


func _make_spark_texture() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for x in range(8):
		for y in range(8):
			var d := Vector2(x - 3.5, y - 3.5).length() / 4.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
