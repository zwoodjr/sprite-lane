extends Node

## Audio director (child of the Juice autoload, reachable as Juice.snd).
## - Buses Master > Music / SFX / Ambience / UI, created at runtime.
## - Every SFX id has 1..N variants: res://assets/audio/sfx/<id>_<n>.ogg.
## - Per-id voice limits, cooldowns, pitch/volume jitter, optional 2D position.
## - Music: original metal score (tools/audio/build_metal.py). Menu groove; three
##   phase-locked run loops (explore / combat / boss) crossfaded by an adaptive
##   state machine; a story piece under campaign dialogue; result stings.
## - Positional SFX pan by screen position (max ±PAN_MAX) and fade with distance.
## - Ambience: per-zone loop beds (+ hangar), crossfaded; storm overlay.
## Everything degrades to silence when a file is missing (headless-safe).

const SFX_DIR := "res://assets/audio/sfx/"
const MUS_DIR := "res://assets/audio/music/"
const AMB_DIR := "res://assets/audio/amb/"
const BUSES := ["Music", "SFX", "Ambience", "UI"]
const POOL_2D := 24
const POOL_FLAT := 18
const MAX_VARIANTS := 6

## id -> {bus, max, cd (ms), pitch, vol}
const IDS := [
	"fire_rook", "boom_rook", "fire_vesper", "fire_cinder", "fire_quill", "fire_helm", "drone_fire", "drone_servo",
	"swing_pebble", "impact_pebble", "swing_juno", "impact_juno", "swing_nyx", "impact_nyx", "swing_quill", "impact_quill",
	"reload_rifle", "reload_launcher", "reload_pistol", "reload_smg", "dry_fire", "hit_flesh", "hit_metal", "explosion",
	"ab_rush", "ab_vial", "ab_vial_break", "ab_slam", "ab_overload", "ab_heal", "ab_mark", "ab_blade", "ab_drone",
	"dash", "hurt_f", "hurt_m", "shield_block", "death_f", "death_m", "lowhp_loop", "level_up", "card_show", "card_pick", "reroll",
	"pick_scrap", "pick_xp", "pick_tonic", "pick_common", "pick_rare", "pick_epic", "pick_legendary", "pick_ammo", "pick_lore",
	"pack_full", "crate_land", "crate_open", "radio_blip", "radio_chatter", "ext_ping", "ext_open", "ext_close", "ext_last",
	"storm", "pad_channel", "pad_cancel", "ext_success", "run_wipe", "threat_up", "elite_spawn", "boss_roar_plague", "boss_roar_machine",
	"plague_attack", "plague_hurt", "plague_die", "plague_spit", "machine_attack", "machine_hurt", "machine_die", "machine_shot",
	"raider_attack", "raider_hurt", "raider_die", "raider_shot", "brute_slam",
	"noel_bark", "noel_growl", "bentley_yip", "lillie_charge", "lillie_hit", "mech_servo", "pet_gift",
	"mine_drop", "mine_boom", "break_wood", "break_metal", "event_start", "supply_crash",
	"ui_tap", "ui_back", "ui_tab", "ui_toggle", "ui_open", "ui_purchase", "ui_denied", "ui_equip",
]
## Overrides; anything unlisted uses _default_cfg().
const CFG := {
	"fire_quill": {"max": 3, "cd": 45, "pitch": 0.05},
	"fire_helm": {"max": 3, "cd": 40},
	"drone_fire": {"max": 3, "cd": 60},
	"hit_flesh": {"max": 4, "cd": 45, "pitch": 0.12},
	"hit_metal": {"max": 4, "cd": 45, "pitch": 0.12},
	"pick_scrap": {"max": 3, "cd": 55, "pitch": 0.12},
	"pick_xp": {"max": 3, "cd": 45, "pitch": 0.15},
	"plague_attack": {"max": 3, "cd": 120}, "plague_hurt": {"max": 3, "cd": 90}, "plague_die": {"max": 4, "cd": 60},
	"plague_spit": {"max": 3, "cd": 90},
	"machine_attack": {"max": 3, "cd": 120}, "machine_hurt": {"max": 3, "cd": 90}, "machine_die": {"max": 4, "cd": 60},
	"machine_shot": {"max": 3, "cd": 80},
	"raider_attack": {"max": 2, "cd": 150}, "raider_hurt": {"max": 2, "cd": 120}, "raider_die": {"max": 3, "cd": 80},
	"raider_shot": {"max": 3, "cd": 80},
	"explosion": {"max": 4, "cd": 50, "pitch": 0.08}, "boom_rook": {"max": 3, "cd": 50},
	"mine_boom": {"max": 3, "cd": 60},
	"boss_roar_plague": {"max": 1, "cd": 1500, "pitch": 0.02}, "boss_roar_machine": {"max": 1, "cd": 1500, "pitch": 0.02},
	"elite_spawn": {"max": 1, "cd": 1200, "pitch": 0.03},
	"lowhp_loop": {"max": 1, "pitch": 0.0},
	"radio_chatter": {"max": 1, "cd": 1500, "pitch": 0.02, "bus": "Voice"}, "radio_blip": {"max": 2, "cd": 200},
	"ext_open": {"max": 1, "cd": 1000, "pitch": 0.0}, "ext_last": {"max": 1, "cd": 1000, "pitch": 0.0},
	"ext_close": {"max": 1, "cd": 1000, "pitch": 0.0}, "storm": {"max": 1, "cd": 2000, "pitch": 0.0},
	"ext_success": {"max": 1, "cd": 2000, "pitch": 0.0}, "run_wipe": {"max": 1, "cd": 2000, "pitch": 0.0},
	"level_up": {"max": 1, "cd": 400, "pitch": 0.0}, "threat_up": {"max": 1, "cd": 800, "pitch": 0.0},
	"pick_legendary": {"max": 1, "cd": 300, "pitch": 0.0}, "pick_epic": {"max": 1, "cd": 200, "pitch": 0.02},
	"pad_channel": {"max": 1, "cd": 200, "pitch": 0.0},
	"noel_bark": {"max": 2, "cd": 250}, "bentley_yip": {"max": 2, "cd": 250}, "noel_growl": {"max": 1, "cd": 900},
	"dash": {"max": 2, "cd": 60},
}
## Big moments pull the music down for a beat. id -> [dB, hold seconds]
const DUCK := {
	"boom_rook": [-3.0, 0.25], "explosion": [-3.0, 0.25], "ab_slam": [-5.0, 0.4], "ab_overload": [-4.0, 0.4],
	"boss_roar_plague": [-8.0, 1.2], "boss_roar_machine": [-8.0, 1.2], "elite_spawn": [-6.0, 0.8],
	"ext_open": [-6.0, 1.5], "ext_last": [-6.0, 1.5], "ext_close": [-5.0, 0.8], "storm": [-8.0, 2.5],
	"radio_chatter": [-7.0, 1.4], "event_start": [-6.0, 1.2], "level_up": [-5.0, 0.8],
	"ext_success": [-12.0, 2.5], "run_wipe": [-12.0, 2.5], "threat_up": [-5.0, 0.8], "death_f": [-10.0, 2.0], "death_m": [-10.0, 2.0],
	"pick_legendary": [-6.0, 1.0], "supply_crash": [-5.0, 0.6],
}
## Zone grade (ZoneDefs) -> ambience bed.
const ZONE_AMB := {
	"": "amb_wasteland", "refinery": "amb_refinery", "city": "amb_city_night", "quarantine": "amb_quarantine",
	"raider": "amb_raider", "chemical": "amb_chemical", "military": "amb_military", "crater": "amb_crater", "dustfall": "amb_dustfall",
}
## Run loops share tempo (160 BPM), length (72 bars) and chord map, so they play
## in lockstep and the game only moves the faders.
const RUN_TRACKS := ["mus_explore", "mus_combat", "mus_boss"]
const LOOP_TRACKS := ["mus_menu", "mus_explore", "mus_combat", "mus_boss", "mus_story"]
const STINGS := ["mus_sting_death", "mus_sting_extract"]
## Threat (0..1) and enemies-near-hero thresholds for explore <-> combat, with hysteresis.
const COMBAT_ON := 0.55
const COMBAT_OFF := 0.4
const NEAR_ON := 6
const NEAR_OFF := 2
const NEAR_RADIUS := 460.0
## Minimum time a run track keeps the lead before the music may calm down again.
const COMBAT_HOLD := 8.0
## Stereo placement of world sounds: max pan at the screen edge, quantised to
## PAN_STEP so native builds can route through a few fixed panner buses.
const PAN_MAX := 0.6
const PAN_STEP := 0.2
## Default mix levels (dB) per player type.
const MUSIC_DB := -4.0
const AMB_DB := -3.0

var _streams: Dictionary = {}       ## id -> Array[AudioStream]
var _last_variant: Dictionary = {}
var _last_ms: Dictionary = {}
var _flat: Array[AudioStreamPlayer] = []
## Positional voices are plain players too (see play()): AudioStreamPlayer2D
## re-sends its panning to the mixer every physics frame, which in Godot 4.3
## swaps the playback's bus details under the audio thread.
var _pos: Array[AudioStreamPlayer] = []
## Fade buses: looping beds fade by BUS volume (a plain float the mixer reads)
## instead of player.volume_db, which reallocates the playback's bus details
## on every write — the audio-thread SIGSEGV seen in 2/40 bot runs
## (StringName copy inside AudioServer::_mix_step).
const FADE_BUSES := {"MusMenu": "Music", "MusStem0": "Music", "MusStem1": "Music", "MusStem2": "Music",
	"MusStory": "Music", "AmbA": "Ambience", "AmbB": "Ambience", "Storm": "Ambience", "LowHP": "SFX"}
var _bus_db: Dictionary = {}
var _flat_i: int = 0
var _pos_i: int = 0

var _menu_player: AudioStreamPlayer
var _stem_players: Array[AudioStreamPlayer] = []
var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _storm_player: AudioStreamPlayer
var _lowhp_player: AudioStreamPlayer
var _amb_current: String = ""
var _music_state: String = ""
var _stem_target: Array[float] = [0.0, 0.0, 0.0]
var _stem_level: Array[float] = [0.0, 0.0, 0.0]
var _story_player: AudioStreamPlayer
var _sting_player: AudioStreamPlayer
var _story_level: float = 0.0
var _story_target: float = 0.0
## Which run loop leads ("explore" / "combat" / "boss") and how long it has led.
var run_track: String = "explore"
var _run_track_t: float = 0.0
var _sting_wait: float = 0.0
var _web: bool = false
## Web plays samples through WebAudio (no bus effects): positional voices there
## are AudioStreamPlayer2D, which WebAudio pans. Native builds keep plain
## players routed to fixed panner buses (no per-frame panning writes).
var _pos2d: Array[AudioStreamPlayer2D] = []
var _menu_level: float = 0.0
var _menu_target: float = 0.0
var _storm_level: float = 0.0
var _storm_target: float = 0.0
var _lowhp_level: float = 0.0
var _lowhp_target: float = 0.0
var _duck_db: float = 0.0
var _duck_hold: float = 0.0
var _ctx_t: float = 0.0
## Optional explicit intensity override (0..1) for tools / the review reel; <0 = automatic.
var intensity_override: float = -1.0
var intensity: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_web = OS.has_feature("web")
	_ensure_buses()
	for id in IDS:
		var arr: Array = []
		for i in range(1, MAX_VARIANTS + 1):
			var p := "%s%s_%d.ogg" % [SFX_DIR, id, i]
			if ResourceLoader.exists(p):
				arr.append(load(p))
		if not arr.is_empty():
			_streams[id] = arr
	for i in range(POOL_FLAT):
		var a := AudioStreamPlayer.new()
		a.bus = "SFX"
		add_child(a)
		_flat.append(a)
	for i in range(POOL_2D):
		if _web:
			var w := AudioStreamPlayer2D.new()
			w.bus = "SFX"
			w.attenuation = 0.0
			w.max_distance = POS_MAX_DIST * 4.0
			w.panning_strength = 3.0
			add_child(w)
			_pos2d.append(w)
		else:
			var b := AudioStreamPlayer.new()
			b.bus = "SFX"
			add_child(b)
			_pos.append(b)
	_menu_player = _loop_player("MusMenu", MUS_DIR + "mus_menu.ogg")
	for si in range(RUN_TRACKS.size()):
		_stem_players.append(_loop_player("MusStem%d" % si, MUS_DIR + RUN_TRACKS[si] + ".ogg"))
	_story_player = _loop_player("MusStory", MUS_DIR + "mus_story.ogg")
	_sting_player = AudioStreamPlayer.new()
	_sting_player.bus = "Music"
	_sting_player.volume_db = MUSIC_DB
	add_child(_sting_player)
	_amb_a = _loop_player("AmbA", "")
	_amb_b = _loop_player("AmbB", "")
	_storm_player = _loop_player("Storm", AMB_DIR + "amb_storm.ogg")
	_lowhp_player = _loop_player("LowHP", SFX_DIR + "lowhp_loop_1.ogg")
	apply_settings()


func _loop_player(bus: String, path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = 0.0
	_fade(bus, -80.0)
	if path != "" and ResourceLoader.exists(path):
		p.stream = _looped(load(path))
	add_child(p)
	return p


func _looped(s: AudioStream) -> AudioStream:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return s


func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	for fb in FADE_BUSES:
		if AudioServer.get_bus_index(fb) == -1:
			AudioServer.add_bus()
			var fi := AudioServer.bus_count - 1
			AudioServer.set_bus_name(fi, fb)
			AudioServer.set_bus_send(fi, FADE_BUSES[fb])
	## Panner buses for positional voices (native builds): SfxPanL3..SfxPanR3 -> SFX.
	for k in range(-3, 4):
		if k == 0:
			continue
		var pb := pan_bus_name(k * PAN_STEP)
		if AudioServer.get_bus_index(pb) == -1:
			AudioServer.add_bus()
			var pbi := AudioServer.bus_count - 1
			AudioServer.set_bus_name(pbi, pb)
			AudioServer.set_bus_send(pbi, "SFX")
			var pe := AudioEffectPanner.new()
			pe.pan = k * PAN_STEP
			AudioServer.add_bus_effect(pbi, pe)
	## Glue + safety: gentle compression on SFX, a limiter on Master so hordes never clip.
	var sfx_i := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx_i) == 0:
		var c := AudioEffectCompressor.new()
		c.threshold = -14.0
		c.ratio = 3.0
		c.attack_us = 3000.0
		c.release_ms = 140.0
		AudioServer.add_bus_effect(sfx_i, c)
	if AudioServer.get_bus_effect_count(0) == 0:
		var l := AudioEffectHardLimiter.new()
		l.ceiling_db = -0.8
		AudioServer.add_bus_effect(0, l)


## --- settings ----------------------------------------------------------------

func apply_settings() -> void:
	var st: Dictionary = GameState.settings
	var mute := bool(st.get("mute", false)) or (_in_background and bool(st.get("mute_background", true)))
	_set_bus("Master", float(st.get("vol_master", 1.0)), mute)
	_set_bus("Music", float(st.get("vol_music", 0.7)), false)
	var sfx_on := bool(st.get("sfx", true))
	_set_bus("SFX", float(st.get("vol_sfx", 1.0)), not sfx_on)
	_set_bus("UI", float(st.get("vol_ui", 0.8)), not sfx_on)
	_set_bus("Ambience", float(st.get("vol_ambience", 0.8)), false)
	ensure_voice_bus()
	_set_bus(VOICE_BUS, float(st.get("vol_voice", 1.0)), false)


## Settings > Voice drives a "Voice" bus (spoken lines / radio). Created here
## when nothing else has made it yet, so voice players can just use it.
const VOICE_BUS := "Voice"


func ensure_voice_bus() -> int:
	var i := AudioServer.get_bus_index(VOICE_BUS)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, VOICE_BUS)
		AudioServer.set_bus_send(i, "Master")
	return i


## Settings > Mute in background: silence while the app is not in front.
var _in_background: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		set_background(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		set_background(false)


func set_background(on: bool) -> void:
	if _in_background == on:
		return
	_in_background = on
	apply_settings()


func _set_bus(name: String, lin: float, muted: bool) -> void:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		return
	var m := muted or lin <= 0.001
	if AudioServer.is_bus_mute(i) != m:
		AudioServer.set_bus_mute(i, m)
	var extra := _duck_db if name == "Music" else 0.0
	_fade(name, linear_to_db(maxf(lin, 0.001)) + extra)


## Bus volume write, skipped when it wouldn't be audible (no per-frame churn).
func _fade(bus: String, db: float) -> void:
	if absf(float(_bus_db.get(bus, 999.0)) - db) < 0.05:
		return
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	_bus_db[bus] = db
	AudioServer.set_bus_volume_db(i, db)


func _fade_db(bus: String) -> float:
	return float(_bus_db.get(bus, -80.0))


## --- one-shots -----------------------------------------------------------------

func has(id: String) -> bool:
	return _streams.has(id)


func _cfg(id: String) -> Dictionary:
	var d := {"max": 4, "cd": 35, "pitch": 0.06, "bus": "UI" if id.begins_with("ui_") else "SFX"}
	if CFG.has(id):
		for k in CFG[id]:
			d[k] = CFG[id][k]
	return d


## Plays a variant of `id`. at = world position for positional sounds (Vector2.INF = flat).
func play(id: String, volume_db: float = 0.0, pitch_jitter: float = -1.0, at: Vector2 = Vector2.INF) -> Node:
	if not _streams.has(id):
		return null
	var c := _cfg(id)
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(id, -100000)) < int(c["cd"]):
		return null
	## Voice limit: count live voices of this id.
	var live := 0
	var oldest: Node = null
	var oldest_t := 1 << 62
	for p in _flat:
		if p.playing and p.get_meta("sid", "") == id:
			live += 1
			if int(p.get_meta("t", 0)) < oldest_t:
				oldest_t = int(p.get_meta("t", 0))
				oldest = p
	for p2 in _pos_voices():
		if p2.playing and p2.get_meta("sid", "") == id:
			live += 1
			if int(p2.get_meta("t", 0)) < oldest_t:
				oldest_t = int(p2.get_meta("t", 0))
				oldest = p2
	if live >= int(c["max"]):
		## Hordes: skip rather than cut; one-off big sounds restart.
		if int(c["max"]) > 1 or oldest == null:
			return null
		oldest.call("stop")
	_last_ms[id] = now
	var arr: Array = _streams[id]
	var vi := randi() % arr.size()
	if arr.size() > 1 and vi == int(_last_variant.get(id, -1)):
		vi = (vi + 1) % arr.size()
	_last_variant[id] = vi
	var jit := float(c["pitch"]) if pitch_jitter < 0.0 else pitch_jitter
	var vol := volume_db + randf_range(-1.2, 0.6)
	var player: Node
	var bus := str(c["bus"])
	if at != Vector2.INF:
		## Distance falloff from the view centre, decided once at start.
		var d := _listener_dist(at)
		if d >= POS_MAX_DIST:
			return null
		vol += POS_ATTEN_DB * pow(d / POS_MAX_DIST, 1.6)
		player = _next_pos()
		if player is AudioStreamPlayer2D:
			(player as AudioStreamPlayer2D).global_position = at
		elif bus == "SFX":
			bus = pan_bus_name(pan_at(at))
	else:
		player = _next_flat()
	if player == null:
		return null
	player.set("bus", bus)
	player.set("stream", arr[vi])
	player.set("volume_db", vol)
	player.set("pitch_scale", 1.0 + randf_range(-jit, jit))
	player.set_meta("sid", id)
	player.set_meta("t", now)
	player.call("play")
	if DUCK.has(id):
		duck(float(DUCK[id][0]), float(DUCK[id][1]))
	return player


const POS_MAX_DIST := 1500.0
const POS_ATTEN_DB := -18.0


## Stereo pan for a world-space sound: its offset from the view centre as a
## share of half the visible width, scaled to ±PAN_MAX (UI / flat sounds stay centred).
static func pan_for(dx: float, half_width: float) -> float:
	if half_width <= 1.0:
		return 0.0
	return clampf(dx / half_width, -1.0, 1.0) * PAN_MAX


func pan_at(at: Vector2) -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp else null
	if cam == null:
		return 0.0
	var half := vp.get_visible_rect().size.x * 0.5 / maxf(absf(cam.zoom.x), 0.01)
	return pan_for(at.x - cam.get_screen_center_position().x, half)


## Bus for a pan value, snapped to PAN_STEP ("SFX" when centred).
static func pan_bus_name(p: float) -> String:
	var k := clampi(roundi(p / PAN_STEP), -3, 3)
	if k == 0:
		return "SFX"
	return ("SfxPanL%d" if k < 0 else "SfxPanR%d") % absi(k)


func _pos_voices() -> Array:
	return _pos2d if _web else _pos


func _listener_dist(at: Vector2) -> float:
	var cam := get_viewport().get_camera_2d() if get_viewport() else null
	if cam == null:
		return 0.0
	return cam.get_screen_center_position().distance_to(at)


## Idle voices only: a full pool drops the new sound rather than restarting a
## voice the mixer is still reading (fewer cross-thread stop/start swaps).
func _next_flat() -> AudioStreamPlayer:
	for k in range(_flat.size()):
		var i := (_flat_i + k) % _flat.size()
		if not _flat[i].playing:
			_flat_i = (i + 1) % _flat.size()
			return _flat[i]
	return null


func _next_pos() -> Node:
	var pool := _pos_voices()
	for k in range(pool.size()):
		var i := (_pos_i + k) % pool.size()
		if not pool[i].playing:
			_pos_i = (i + 1) % pool.size()
			return pool[i]
	return null


func stop(handle: Node) -> void:
	if handle != null and is_instance_valid(handle) and handle.has_method("stop"):
		handle.call("stop")


func duck(amount_db: float, hold: float) -> void:
	_duck_db = minf(_duck_db, amount_db)
	_duck_hold = maxf(_duck_hold, hold)


## --- music / ambience ------------------------------------------------------------

## States: "menu" (hangar groove), "run" (adaptive loops), "story" (campaign
## dialogue / map; run loops keep their place underneath), "result" (sting,
## then the menu groove), "none". Re-entering the current state never restarts it.
func set_music(state: String) -> void:
	if state == _music_state:
		return
	var prev := _music_state
	_music_state = state
	_menu_target = 0.0
	_story_target = 0.0
	if state != "run":
		_stem_target = [0.0, 0.0, 0.0]
	match state:
		"menu":
			_menu_target = 1.0
			if _menu_player.stream and not _menu_player.playing:
				_menu_player.play()
		"story":
			_story_target = 1.0
			if _story_player.stream and not _story_player.playing:
				_story_player.play()
		"run":
			## Back from a story beat: the loops never stopped, just fade back in.
			var running := false
			for p in _stem_players:
				running = running or p.playing
			if prev != "story" or not running:
				run_track = "explore"
				_run_track_t = 0.0
				## Phase-locked: all three loops start together.
				for p in _stem_players:
					if p.stream:
						p.play(0.0)
			_apply_run_track()
		"result":
			## The sting is the moment: no leftover duck from the run's last SFX.
			_duck_db = 0.0
			_duck_hold = 0.0
			_sting_wait = 0.1
			var sid := "mus_sting_extract" if GameState.extracted else "mus_sting_death"
			var path := MUS_DIR + sid + ".ogg"
			if ResourceLoader.exists(path):
				_sting_player.stream = load(path)
				_sting_player.play()
				_sting_wait = maxf(0.1, _sting_player.stream.get_length())


## Pure: which run loop should lead. `current` gives hysteresis so the score
## doesn't flip-flop at the threshold.
static func pick_run_track(current: String, threat: float, near: int, boss: bool, last_window: bool) -> String:
	if boss or last_window:
		return "boss"
	if current == "combat" or current == "boss":
		return "explore" if threat < COMBAT_OFF and near <= NEAR_OFF else "combat"
	return "combat" if threat >= COMBAT_ON or near >= NEAR_ON else "explore"


func _apply_run_track() -> void:
	var i := RUN_TRACKS.find("mus_" + run_track)
	for k in range(_stem_target.size()):
		_stem_target[k] = 1.0 if k == i else 0.0


## Feeds the adaptive score (called by _auto_context; tools may call it directly).
func update_run_music(threat: float, near: int, boss: bool, last_window: bool, delta: float = 0.0) -> void:
	intensity = clampf(threat, 0.0, 1.0)
	_run_track_t += delta
	var want := pick_run_track(run_track, intensity, near, boss, last_window)
	if want != run_track:
		## Calming down waits out COMBAT_HOLD; escalating is immediate.
		var calmer := (want == "explore") or (want == "combat" and run_track == "boss")
		if not calmer or _run_track_t >= COMBAT_HOLD:
			run_track = want
			_run_track_t = 0.0
	if _music_state == "run":
		_apply_run_track()


func set_ambience(id: String) -> void:
	if id == _amb_current:
		return
	_amb_current = id
	## Swap into the quiet player and crossfade.
	var tmp := _amb_a
	_amb_a = _amb_b
	_amb_b = tmp
	var path := AMB_DIR + id + ".ogg"
	if id != "" and ResourceLoader.exists(path):
		_amb_a.stream = _looped(load(path))
		_fade(_amb_a.bus, -60.0)
		_amb_a.play(randf() * 20.0)
	else:
		_amb_a.stop()


func set_storm(on: bool) -> void:
	_storm_target = 1.0 if on else 0.0
	if on and _storm_player.stream and not _storm_player.playing:
		_storm_player.play()


func set_low_hp(on: bool) -> void:
	_lowhp_target = 1.0 if on else 0.0
	if on and _lowhp_player.stream and not _lowhp_player.playing:
		_lowhp_player.play()


func _process(delta: float) -> void:
	_ctx_t -= delta
	if _ctx_t <= 0.0:
		_ctx_t = 0.25
		_auto_context()
	_menu_level = move_toward(_menu_level, _menu_target, delta * 0.5)
	_fade("MusMenu", _lin_db(_menu_level) + MUSIC_DB)
	if _menu_level <= 0.001 and _menu_player.playing and _menu_target == 0.0:
		_menu_player.stop()
	_story_level = move_toward(_story_level, _story_target, delta * 0.6)
	_fade("MusStory", _lin_db(_story_level) + MUSIC_DB - 2.0)
	if _story_level <= 0.001 and _story_player.playing and _story_target == 0.0:
		_story_player.stop()
	for i in range(_stem_players.size()):
		## Boss / combat hit fast (~1 s); calming down takes ~3 s.
		var up := _stem_target[i] > _stem_level[i]
		_stem_level[i] = move_toward(_stem_level[i], _stem_target[i], delta * (1.0 if up else 0.33))
		_fade("MusStem%d" % i, _lin_db(_stem_level[i]) + MUSIC_DB)
	if _music_state != "run" and _music_state != "story" and _stem_players.size() > 0 and _stem_level.max() <= 0.001:
		for p in _stem_players:
			if p.playing:
				p.stop()
	if _music_state == "result" and _sting_wait > 0.0:
		_sting_wait -= delta
		if _sting_wait <= 0.0:
			set_music("menu")
	## Ambience crossfade (2 s).
	_fade(_amb_a.bus, move_toward(_fade_db(_amb_a.bus), AMB_DB if _amb_current != "" else -60.0, delta * 30.0))
	_fade(_amb_b.bus, move_toward(_fade_db(_amb_b.bus), -60.0, delta * 30.0))
	if _amb_b.playing and _fade_db(_amb_b.bus) <= -59.0:
		_amb_b.stop()
	_storm_level = move_toward(_storm_level, _storm_target, delta * 0.4)
	_fade("Storm", _lin_db(_storm_level))
	if _storm_level <= 0.001 and _storm_player.playing:
		_storm_player.stop()
	_lowhp_level = move_toward(_lowhp_level, _lowhp_target, delta * 1.5)
	_fade("LowHP", _lin_db(_lowhp_level) - 4.0)
	if _lowhp_level <= 0.001 and _lowhp_player.playing:
		_lowhp_player.stop()
	## Ducking recovers after its hold.
	if _duck_hold > 0.0:
		_duck_hold -= delta
	else:
		_duck_db = move_toward(_duck_db, 0.0, delta * 8.0)
	_set_bus("Music", float(GameState.settings.get("vol_music", 0.7)), false)


func _lin_db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)


## Campaign dialogue on screen: a blocking story scene, or Helm's radio plate.
func _dialogue_state() -> int:
	for n in get_tree().get_nodes_in_group("story_panel"):
		if n.get("active") == true:
			return 2
		if n.has_method("radio_busy") and bool(n.call("radio_busy")):
			return 1
	return 0


## Reads the running scene and game state to pick music/ambience on its own,
## so menus and the match never need to call into audio explicitly.
func _auto_context() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path := scene.scene_file_path
	if path.ends_with("match.tscn"):
		var talk := _dialogue_state()
		set_music("story" if talk == 2 else "run")
		if talk == 1:
			## Duck under Helm's radio.
			duck(-7.0, 0.35)
		var grade := str(ZoneDefs.zone(GameState.zone_tier()).get("grade", ""))
		set_ambience(str(ZONE_AMB.get(grade, "amb_wasteland")))
		var storming := scene.has_method("is_storming") and bool(scene.call("is_storming"))
		set_storm(storming)
		var boss := false
		var elites := 0
		var near := 0
		var pl := get_tree().get_first_node_in_group("player") as Node2D
		for e in get_tree().get_nodes_in_group("enemies"):
			var r := str(e.get("role")) if e.get("role") != null else ""
			if r == "boss":
				boss = true
			elif r == "elite":
				elites += 1
			if pl != null and e is Node2D and (e as Node2D).global_position.distance_squared_to(pl.global_position) < NEAR_RADIUS * NEAR_RADIUS:
				near += 1
		var v := 0.15 + 0.1 * float(GameState.threat_level)
		v += 0.12 * float(elites)
		if scene.get("_extract_open") == true:
			v += 0.1
		var last := _last_window(scene)
		if last:
			v = maxf(v, 0.75)
		if storming:
			v = 1.0
		if intensity_override >= 0.0:
			v = intensity_override
		update_run_music(v, near, boss, last or storming, 0.25)
		if pl != null and pl.get("max_hp") != null:
			var hp_r := float(pl.get("hp")) / maxf(float(pl.get("max_hp")), 1.0)
			set_low_hp(hp_r > 0.0 and hp_r < 0.3)
		else:
			set_low_hp(false)
	else:
		set_storm(false)
		set_low_hp(false)
		if path.ends_with("result_screen.tscn"):
			if _music_state != "menu":
				set_music("result")
			set_ambience("amb_wasteland")
		elif path.ends_with("campaign_map.tscn"):
			set_music("story")
			set_ambience("amb_hangar")
		else:
			set_music("menu")
			set_ambience("amb_hangar")


func _last_window(scene: Node) -> bool:
	var phases: Variant = scene.get("_phases")
	var idx: Variant = scene.get("_phase_index")
	if phases is Array and idx is int and int(idx) < (phases as Array).size():
		var ph: Variant = (phases as Array)[int(idx)]
		return ph is Dictionary and bool((ph as Dictionary).get("is_last", false)) and scene.get("_extract_open") == true
	return false
