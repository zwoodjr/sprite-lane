extends Node

## Game-feel helpers: screen shake, hit sparks, floating numbers, SFX pool.
## Autoload as "Juice". Everything is fire-and-forget and safe to call
## from any scene (no-ops when there's no camera / scene).

const SoundScript = preload("res://scripts/autoload/sound.gd")
const PxFxScript = preload("res://scripts/fx/px_fx.gd")

## Legacy one-word ids (pre sound pass) -> new ids. "@x" = per-hero lookup.
const LEGACY := {
	"shot": "@fire", "hurt": "@hurt", "reload": "@reload", "ability": "@ability", "pickup": "pick_common",
	"seal": "ext_close", "extract_win": "ext_success", "wipe": "run_wipe", "empty": "dry_fire",
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
## Pixel VFX player (pooled strips, decals, status overlays). See px_fx.gd.
var px: Node

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
	px = PxFxScript.new()
	px.name = "PxFx"
	add_child(px)
	_spark_tex = _make_spark_texture()
	if not GameState.run_level_up.is_connected(_on_run_level_up):
		GameState.run_level_up.connect(_on_run_level_up)
	if ResourceLoader.exists("res://assets/fonts/PressStart2P.ttf"):
		_pixel_font = load("res://assets/fonts/PressStart2P.ttf")
	## Settings that live outside the scene tree: flash strength, FPS readout,
	## and the frame-rate cap (not under the headless test runner, whose
	## frame-count loops would crawl at 30 / 60 fps).
	SettingsDefs.apply("flash_intensity")
	SettingsDefs.apply.call_deferred("show_fps")
	if DisplayServer.get_name() != "headless":
		SettingsDefs.apply_fps()


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


## Light haptics (Settings > Vibration). Tiers, all short: HAPTIC_TICK for a
## rare pickup, HAPTIC_HIT when the hero is hit, HAPTIC_BIG for an elite / boss
## kill or a Legendary, HAPTIC_EXTRACT for getting out. A small gap keeps a
## swarm of hits from turning into a constant buzz.
const HAPTIC_TICK := 12
const HAPTIC_HIT := 20
const HAPTIC_BIG := 35
const HAPTIC_EXTRACT := 60
const HAPTIC_GAP_MS := 90
var _haptic_last_ms: int = -100000


func haptic(ms: int = 20) -> void:
	if not GameState.settings.get("haptics", true) or not OS.has_feature("mobile"):
		return
	var now := Time.get_ticks_msec()
	if now - _haptic_last_ms < HAPTIC_GAP_MS and ms < HAPTIC_EXTRACT:
		return
	_haptic_last_ms = now
	## Settings > Vibration strength: shorter + softer taps.
	var k := SettingsDefs.haptic_k()
	Input.vibrate_handheld(maxi(5, int(round(float(ms) * k))), k)


## --- Screen shake ------------------------------------------------------------

func shake(amount: float) -> void:
	## Settings > Screen shake OFF / LOW / FULL (Reduce motion = off).
	var k := SettingsDefs.shake_mult()
	if k <= 0.0:
		return
	_trauma = clampf(_trauma + amount * k, 0.0, 1.0)


## Current shake trauma (0..1), for tests.
func shake_trauma() -> float:
	return _trauma


func hitstop(seconds: float) -> void:
	_hitstop_left = maxf(_hitstop_left, seconds)


## Dramatic slow motion for `real_seconds` of wall time (death, extract): time
## runs at `scale`, then eases back to 1. Hitstop still wins while it runs.
var _slowmo_left: float = 0.0
var _slowmo_total: float = 0.0
var _slowmo_scale: float = 1.0
var _slowmo_scene: Node = null

func slowmo(scale: float, real_seconds: float) -> void:
	if SettingsDefs.reduce_motion() and scale < 1.0:
		## Reduce motion: keep it short.
		real_seconds *= 0.4
	_slowmo_scale = clampf(scale, 0.05, 1.0)
	_slowmo_left = real_seconds
	_slowmo_total = maxf(real_seconds, 0.01)
	_slowmo_scene = get_tree().current_scene

func cancel_slowmo() -> void:
	_slowmo_left = 0.0
	_hitstop_left = 0.0
	Engine.time_scale = 1.0

func slowmo_active() -> bool:
	return _slowmo_left > 0.0

## Time scale outside of hitstop: the slow-mo curve (last 35% ramps back to 1).
func _base_time_scale() -> float:
	if _slowmo_left <= 0.0:
		return 1.0
	var k := _slowmo_left / _slowmo_total
	if k > 0.35:
		return _slowmo_scale
	return lerpf(1.0, _slowmo_scale, k / 0.35)


func _process(delta: float) -> void:
	_stop_cd -= delta / maxf(Engine.time_scale, 0.01)
	_tick_damage_numbers(delta)
	var real_dt := delta / maxf(Engine.time_scale, 0.01)
	if _slowmo_left > 0.0:
		## Scene changed (result screen, menu): drop the slow-mo with it.
		var cs := get_tree().current_scene
		if cs != _slowmo_scene:
			_slowmo_left = 0.0
			_hitstop_left = 0.0
			Engine.time_scale = 1.0
		_slowmo_left -= real_dt
		if _hitstop_left <= 0.0:
			Engine.time_scale = _base_time_scale()
	## Hitstop: briefly slow time on big hits for weight.
	if _hitstop_left > 0.0:
		_hitstop_left -= real_dt
		Engine.time_scale = 0.08 if _hitstop_left > 0.0 else _base_time_scale()
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

## Pixel debris: hard 2x2-texel squares in the nearest palette colour, fading
## in 4 alpha steps (bible §5; replaces the old soft tinted spark).
const BURST_CAP := 10
## Debris bursts come from a small pool of one-shot emitters owned by the
## current scene (reused oldest-first) with one cached colour ramp per colour,
## instead of a fresh CPUParticles2D + Gradient + timer per call.
const BURST_POOL := 16
var _burst_pool: Array[CPUParticles2D] = []
var _burst_i: int = 0
var _burst_scene: Node = null
var _ramp_cache: Dictionary = {}

func burst(pos: Vector2, color: Color, amount: int = 10, speed: float = 160.0, life: float = 0.4, scale: float = 1.0) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	## Settings > Effects quality (Battery saver = LOW) thins the debris.
	amount = int(round(float(amount) * SettingsDefs.fx_mult()))
	if amount <= 0:
		return
	if scene != _burst_scene:
		_burst_scene = scene
		_burst_pool.clear()
		_burst_i = 0
	var p: CPUParticles2D = null
	if _burst_pool.size() < BURST_POOL:
		p = CPUParticles2D.new()
		p.texture = _spark_tex
		p.one_shot = true
		p.explosiveness = 1.0
		p.direction = Vector2.UP
		p.spread = 180.0
		p.gravity = Vector2(0, 120)
		p.z_index = 20
		p.emitting = false
		scene.add_child(p)
		_burst_pool.append(p)
	else:
		## Prefer an idle emitter; otherwise recycle the oldest.
		for k in range(_burst_pool.size()):
			var c := _burst_pool[(_burst_i + k) % _burst_pool.size()]
			if is_instance_valid(c) and not c.emitting:
				p = c
				_burst_i = (_burst_i + k + 1) % _burst_pool.size()
				break
		if p == null:
			p = _burst_pool[_burst_i]
			_burst_i = (_burst_i + 1) % _burst_pool.size()
		if not is_instance_valid(p):
			_burst_pool.clear()
			return
	var col := pal(color)
	p.emitting = false
	p.amount = clampi(amount, 1, BURST_CAP)
	p.lifetime = life
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.2
	p.damping_max = speed * 2.0
	var tx := UnitAnim.TEXEL * (2.0 if scale >= 1.4 else 1.0)
	p.scale_amount_min = tx
	p.scale_amount_max = tx
	var a := 1.0 if color.a > 0.85 else (0.75 if color.a > 0.6 else 0.5)
	p.color_ramp = _burst_ramp(col, a)
	p.global_position = pos
	p.restart()
	p.emitting = true


func _burst_ramp(col: Color, a: float) -> Gradient:
	var key := Color(col, a).to_rgba32()
	if _ramp_cache.has(key):
		return _ramp_cache[key]
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	ramp.set_color(0, Color(col, a))
	ramp.set_offset(1, 0.4)
	ramp.set_color(1, Color(col, a * 0.75))
	ramp.add_point(0.65, Color(col, a * 0.5))
	ramp.add_point(0.85, Color(col, a * 0.25))
	_ramp_cache[key] = ramp
	return ramp


## Master palette (style bible §2) for snapping code colours to it.
const PAL := [
	"140c0e", "1f1a1d", "3a3436", "5d5654", "8f877e", "e9dfc9", "3a2d27", "5a4636", "7c6550", "a08669", "c8b08a",
	"3e1a12", "763420", "ad5a2a", "d98a45", "3e2a10", "7a5520", "b88a33", "e8c972", "1b222c", "36424f", "5e6d7a",
	"9aa8ad", "2a2a1c", "59563a", "8f8a5e", "4a2420", "8e4c3b", "c98060", "eeb48c", "142a18", "2b5a2c", "57932f",
	"9ccf3e", "dcf58a", "2e1830", "5a3254", "8a5474", "c08aa0", "5e260c", "a8520f", "e88a1c", "ffc040", "fff2c0",
	"9a1e26", "1f5a58", "5cd2c0", "ff4836",
]
var _pal: Array[Color] = []
var _pal_cache: Dictionary = {}


func pal(c: Color) -> Color:
	var key := c.to_html(false)
	if _pal_cache.has(key):
		return _pal_cache[key]
	if _pal.is_empty():
		for hx in PAL:
			_pal.append(Color.html(hx))
	var cc := Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0))
	var best := _pal[0]
	var bd := INF
	for q in _pal:
		var d := (q.r - cc.r) * (q.r - cc.r) * 0.3 + (q.g - cc.g) * (q.g - cc.g) * 0.59 + (q.b - cc.b) * (q.b - cc.b) * 0.11
		if d < bd:
			bd = d
			best = q
	_pal_cache[key] = best
	return best


## --- Pixel VFX (px_fx.gd) ---------------------------------------------------

## Play a pixel strip once. opts: dir, follow, k, z, tint, speed.
func fx(id: String, pos: Vector2, opts: Dictionary = {}) -> Node:
	return px.call("play", id, pos, opts) if px else null


func fx_impact(pos: Vector2, material: String) -> void:
	if px:
		px.call("impact", pos, material)


func fx_explosion(pos: Vector2, radius: float, scorch: bool = true) -> void:
	if px:
		px.call("explosion", pos, radius, scorch)


func fx_slam(pos: Vector2) -> void:
	if px:
		px.call("slam", pos)


func fx_death(pos: Vector2, faction: String, big: bool = false) -> void:
	if px:
		px.call("death", pos, faction, big)


func decal(id: String, pos: Vector2, life: float = 5.0) -> void:
	if px:
		px.call("decal", id, pos, life)


func status_fx(unit: Node2D, ids: Dictionary, head_y: float) -> void:
	if px:
		px.call("status", unit, ids, head_y)


## Looping strip attached to a node (sparkles, beams).
func px_loop(parent: Node, id: String, local_pos: Vector2 = Vector2.ZERO) -> Node:
	return px.call("loop_on", parent, id, local_pos) if px else null


func _on_run_level_up(_lvl: int, _choices: Array) -> void:
	var pl := get_tree().get_first_node_in_group("player") as Node2D if get_tree() else null
	if pl:
		fx("fx_levelup", pl.global_position + Vector2(0, 30), {"follow": pl})
		## Warm gold pop behind the cards (the HUD flash layer keeps running).
		var hud := get_tree().current_scene.get_node_or_null("HUD") if get_tree().current_scene else null
		if hud and hud.has_method("screen_flash"):
			hud.call("screen_flash", Color(1.0, 0.8, 0.3), 0.35, 0.4)


func dust_puff(pos: Vector2, amount: int = 4) -> void:
	## Bigger puffs (landings, slams, spawns) get the lit pixel kick-up strip.
	if amount >= 6 and SettingsDefs.fx_level() > 0:
		fx("fx_kickup", pos + Vector2(0, 4))
		if amount >= 12 and SettingsDefs.fx_level() > 1:
			fx("fx_kickup", pos + Vector2(-14, 6))
			fx("fx_kickup", pos + Vector2(14, 6))
	burst(pos, Color(0.63, 0.53, 0.41), mini(amount, 6), 50.0, 0.45, 1.0)


## Floating callouts ("BLOCKED", "+12", "NOEL RAMPAGE!") from a small per-scene
## label pool (oldest recycled). Each label keeps its last font size / colour
## so a reuse only touches overrides that changed.
const FT_POOL := 24
var _ft_pool: Array[Label] = []
var _ft_tw: Array = []
var _ft_i: int = 0
var _ft_scene: Node = null

func float_text(pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 18) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene != _ft_scene:
		_ft_scene = scene
		_ft_pool.clear()
		_ft_tw.clear()
		_ft_i = 0
	var l: Label
	var slot := -1
	if _ft_pool.size() < FT_POOL:
		l = Label.new()
		l.z_index = 50
		l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
		l.add_theme_constant_override("outline_size", 5)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.size = Vector2(120, 30)
		l.pivot_offset = Vector2(60, 15)
		scene.add_child(l)
		_ft_pool.append(l)
		_ft_tw.append(null)
		slot = _ft_pool.size() - 1
	else:
		slot = _ft_i
		_ft_i = (_ft_i + 1) % FT_POOL
		l = _ft_pool[slot]
		if not is_instance_valid(l):
			_ft_pool.clear()
			_ft_tw.clear()
			return
		var old: Variant = _ft_tw[slot]
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	l.text = text
	if int(l.get_meta("fs", -1)) != size:
		l.set_meta("fs", size)
		l.add_theme_font_size_override("font_size", size)
	if l.get_meta("fc", Color(0, 0, 0, 0)) != color:
		l.set_meta("fc", color)
		l.add_theme_color_override("font_color", color)
	l.visible = true
	l.modulate.a = 1.0
	l.position = pos - Vector2(60, 30) + Vector2(randf_range(-10, 10), 0)
	l.scale = Vector2(0.6, 0.6)
	var tw := l.create_tween()
	_ft_tw[slot] = tw
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 38.0, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.chain().tween_callback(func() -> void: l.visible = false)


## Damage numbers (audit quick win #4): ONE number per target that sums every
## hit landing inside AGG_WINDOW (no more "1515 15" stacks), drawn in screen
## space on a pooled set of labels, in the pixel face at 16 / 24 px (its 8 px
## grid, so glyph pixels stay square and the device oversamples them crisply).
const AGG_WINDOW := 0.3
const DN_POOL := 48
const DN_LIFE := 0.75
const DN_SOFT_CAP := 14
var _dn_layer: CanvasLayer
var _dn_pool: Array[Label] = []
var _dn_live: Array[Dictionary] = []
var _dn_by_key: Dictionary = {}


func damage_number(pos: Vector2, amount: float, crit: bool = false, color: Color = Color(1, 0.97, 0.9), target: Node2D = null) -> void:
	if get_tree().current_scene == null or not bool(GameState.settings.get("damage_numbers", true)):
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
	## A horde under a blade storm would paint the screen with numbers:
	## past DN_SOFT_CAP live numbers only crits start new ones.
	if _dn_live.size() >= DN_SOFT_CAP and not crit:
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
	var n := maxi(1, int(round(float(e["total"]))))
	l.text = ("%d!" % n) if crit else str(n)
	## Size tiers: chip damage stays small so big hits (and aggregated bursts)
	## read at a glance. Pixel font: keep to multiples of 4.
	var fs := 16
	if n >= 250:
		fs = 24
	elif n >= 80:
		fs = 20
	if crit:
		fs += 8
	if int(e.get("fs", -1)) != fs:
		e["fs"] = fs
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_constant_override("outline_size", 8 if fs >= 24 else 6)
	var col: Color = Color(1.0, 0.72, 0.2) if crit else (e["color"] as Color)
	if e.get("fc", Color(0, 0, 0, 0)) != col:
		e["fc"] = col
		l.add_theme_color_override("font_color", col)
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
		var calm := SettingsDefs.reduce_motion()
		var rise := 0.0 if calm else 26.0 * (1.0 - pow(1.0 - minf(t / DN_LIFE, 1.0), 2.0))
		var sp: Vector2 = xf * (e["pos"] as Vector2)
		l.position = (sp - l.size * 0.5 + Vector2(0, -rise)).round()
		var s := 1.0 if calm else 1.0 + 0.35 * float(e["pop"]) * (1.4 if bool(e["crit"]) else 1.0)
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
	## Settings > Flash & hit-flash intensity.
	var k := SettingsDefs.flash_k()
	if k <= 0.01:
		return
	node.modulate = Color.WHITE.lerp(color, k)
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", Color.WHITE, dur)


func _make_spark_texture() -> Texture2D:
	## One hard 2x2 white square (tinted per burst; no soft falloff).
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)
