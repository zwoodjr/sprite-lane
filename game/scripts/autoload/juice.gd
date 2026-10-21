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
	_stop_cd -= delta / maxf(Engine.time_scale, 0.01)
	_tick_damage_numbers(delta)
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


## Damage numbers (audit quick win #4): ONE number per target that sums every
## hit landing inside AGG_WINDOW (no more "1515 15" stacks), drawn in screen
## space on a pooled set of labels, in the pixel face at 16 / 24 px (its 8 px
## grid, so glyph pixels stay square and the device oversamples them crisply).
const AGG_WINDOW := 0.3
const DN_POOL := 48
const DN_LIFE := 0.75
var _dn_layer: CanvasLayer
var _dn_pool: Array[Label] = []
var _dn_live: Array[Dictionary] = []
var _dn_by_key: Dictionary = {}


func damage_number(pos: Vector2, amount: float, crit: bool = false, color: Color = Color(1, 0.97, 0.9), target: Node2D = null) -> void:
	if get_tree().current_scene == null:
		return
	_ensure_dn_layer()
	var key: Variant = null
	if target != null and is_instance_valid(target):
		key = "%d:%s" % [target.get_instance_id(), color.to_html()]
	var e: Dictionary = _dn_by_key.get(key, {}) if key != null else {}
	if not e.is_empty() and float(e["since_add"]) < AGG_WINDOW and is_instance_valid(e["label"]):
		e["total"] = float(e["total"]) + amount
		e["crit"] = bool(e["crit"]) or crit
		e["since_add"] = 0.0
		e["t"] = minf(float(e["t"]), 0.12)
		e["pop"] = 1.0
		_dn_style(e)
		return
	var l := _dn_take()
	e = {"label": l, "target": weakref(target) if target else null, "pos": pos,
		"off": pos - (target.global_position if target and is_instance_valid(target) else pos) + Vector2(randf_range(-8, 8), 0),
		"total": amount, "crit": crit, "color": color, "t": 0.0, "since_add": 0.0, "pop": 1.0, "key": key}
	_dn_live.append(e)
	if key != null:
		_dn_by_key[key] = e
	_dn_style(e)


func _ensure_dn_layer() -> void:
	if _dn_layer and is_instance_valid(_dn_layer):
		return
	_dn_layer = CanvasLayer.new()
	_dn_layer.name = "DamageNumbers"
	_dn_layer.layer = 5
	add_child(_dn_layer)
	_dn_pool.clear()
	for i in DN_POOL:
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.visible = false
		var f: Font = UiTheme.font_pixel if UiTheme.font_pixel else _pixel_font
		if f:
			l.add_theme_font_override("font", f)
		l.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
		_dn_layer.add_child(l)
		_dn_pool.append(l)


func _dn_take() -> Label:
	for l in _dn_pool:
		if not l.visible:
			l.visible = true
			return l
	## Pool exhausted: recycle the oldest live number.
	var old: Dictionary = _dn_live.pop_front()
	_dn_by_key.erase(old.get("key"))
	return old["label"]


func _dn_style(e: Dictionary) -> void:
	var l: Label = e["label"]
	var crit: bool = e["crit"]
	l.text = str(maxi(1, int(round(float(e["total"])))))
	l.add_theme_font_size_override("font_size", 24 if crit else 16)
	l.add_theme_constant_override("outline_size", 8 if crit else 6)
	l.add_theme_color_override("font_color", Color(1.0, 0.72, 0.2) if crit else (e["color"] as Color))
	l.size = Vector2(160, 32)
	l.pivot_offset = l.size * 0.5


func _tick_damage_numbers(delta: float) -> void:
	if _dn_live.is_empty():
		return
	var scene := get_tree().current_scene
	var xf: Transform2D = get_viewport().get_canvas_transform() if scene else Transform2D.IDENTITY
	var i := 0
	while i < _dn_live.size():
		var e: Dictionary = _dn_live[i]
		e["t"] = float(e["t"]) + delta
		e["since_add"] = float(e["since_add"]) + delta
		e["pop"] = maxf(0.0, float(e["pop"]) - delta * 7.0)
		var l: Label = e["label"]
		var t := float(e["t"])
		if t >= DN_LIFE or scene == null or not is_instance_valid(l):
			if is_instance_valid(l):
				l.visible = false
			if e.get("key") != null and is_same(_dn_by_key.get(e["key"]), e):
				_dn_by_key.erase(e["key"])
			_dn_live.remove_at(i)
			continue
		var wr: WeakRef = e["target"]
		var tgt: Node2D = wr.get_ref() if wr else null
		if tgt and is_instance_valid(tgt) and tgt.is_inside_tree():
			e["pos"] = tgt.global_position + (e["off"] as Vector2)
		var rise := 26.0 * (1.0 - pow(1.0 - minf(t / DN_LIFE, 1.0), 2.0))
		var sp: Vector2 = xf * (e["pos"] as Vector2)
		l.position = (sp - l.size * 0.5 + Vector2(0, -rise)).round()
		var s := 1.0 + 0.35 * float(e["pop"]) * (1.4 if bool(e["crit"]) else 1.0)
		l.scale = Vector2(s, s)
		l.modulate.a = clampf((DN_LIFE - t) / 0.25, 0.0, 1.0)
		i += 1


## Light hitstop for kills / crits on every weapon (audit #4), throttled so a
## horde wipe doesn't turn into slow motion.
var _stop_cd: float = 0.0


func kill_stop(big: bool = false) -> void:
	if big:
		hitstop(0.07)
		_stop_cd = 0.3
	elif _stop_cd <= 0.0:
		hitstop(0.03)
		_stop_cd = 0.22


func crit_stop() -> void:
	if _stop_cd <= 0.0:
		hitstop(0.025)
		_stop_cd = 0.3


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
