class_name SettingsDefs
extends RefCounted

## Player settings: defaults, the tabbed Settings layout, old-save migration
## and the "effective value" helpers the game systems read (shake, flash,
## particles, haptics, fps). Values live in GameState.settings and are saved
## with the profile; GameState.set_setting() applies them live via apply().

## Bumped when a key is renamed or changes type (see migrate()).
## v3: Quality preset, Render scale, 120 fps cap, ULTRA effects, damage
## numbers OFF / FEWER / ALL (was an on/off switch).
const VERSION := 3

const DEFAULTS := {
	## AUDIO (volumes are linear 0..1, shown 0-100)
	"vol_master": 1.0, "vol_music": 0.7, "vol_sfx": 1.0, "vol_voice": 1.0, "vol_ui": 0.8, "vol_ambience": 0.8,
	"mute": false, "mute_background": true,
	## VIDEO
	## quality / fps_cap / render_scale / fx_quality / heat_shimmer start from
	## the device's auto preset (auto_video()); these are the High values.
	"quality": 2, "fps_cap": 2, "render_scale": 0, "battery_saver": false, "shake_level": 2, "flash_intensity": 1.0, "fx_quality": 2,
	"dmg_numbers": 2, "brightness": 0.5, "heat_shimmer": false, "edge_dither": false, "show_fps": false,
	## CONTROLS
	"left_handed": false, "stick_aim": false, "stick_scale": 1.0, "stick_opacity": 1.0, "haptics": true, "haptic_strength": 1.0,
	## ACCESSIBILITY / GAME
	"text_size": 0, "reduce_motion": false, "cb_loot": false, "caption_size": 0, "auto_salvage_commons": false, "auto_salvage_tier": 0, "auto_salvage_sets": false,
	"show_hints": true,
}

const FPS_NAMES := ["30", "60", "120"]
const FPS_VALUES := [30, 60, 120]
## Render scale: FULL draws at the screen's own resolution; HALF draws at the
## 720-wide design resolution and scales up (about half the pixels per side
## on a big screen: 48% on an iPhone Duo inner screen, 61% on an iPhone 15).
## A 2D canvas can't render at an arbitrary fraction without changing the UI
## size, so the two real steps are offered.
const RENDER_NAMES := ["100%", "50%"]
const QUALITY_NAMES := ["LOW", "MEDIUM", "HIGH", "ULTRA"]
## quality value when a preset key was changed by hand.
const QUALITY_CUSTOM := 4
## What each Quality preset sets. LOW keeps 60 fps (Battery saver is the 30
## fps mode); HIGH and ULTRA run at 120 on ProMotion screens.
const PRESETS := [
	{"fps_cap": 1, "render_scale": 1, "fx_quality": 0, "heat_shimmer": false},
	{"fps_cap": 1, "render_scale": 0, "fx_quality": 1, "heat_shimmer": false},
	{"fps_cap": 2, "render_scale": 0, "fx_quality": 2, "heat_shimmer": false},
	{"fps_cap": 2, "render_scale": 0, "fx_quality": 3, "heat_shimmer": true},
]
const DMG_NAMES := ["OFF", "FEWER", "ALL"]
const SHAKE_NAMES := ["OFF", "LOW", "FULL"]
const SHAKE_MULT := [0.0, 0.45, 1.0]
const FX_NAMES := ["LOW", "MED", "HIGH", "ULTRA"]
const FX_MULT := [0.35, 0.65, 1.0, 1.3]
const CAPTION_NAMES := ["NORMAL", "LARGE", "HUGE"]
const CAPTION_SCALE := [1.0, 1.25, 1.5]

## Row types: slider (min/max/step, shown 0-100 unless "fmt"), toggle,
## choice (segmented "options"), action (a button handled by the screen),
## info (a read-only line).
const TABS := [
	{"id": "audio", "label": "AUDIO", "icon": "set_volume", "rows": [
		{"key": "vol_master", "type": "slider", "label": "Master", "icon": "set_volume"},
		{"key": "vol_music", "type": "slider", "label": "Music", "icon": "set_music"},
		{"key": "vol_sfx", "type": "slider", "label": "Sound effects", "icon": "set_sfx", "preview": "pick_rare"},
		{"key": "vol_voice", "type": "slider", "label": "Voice", "icon": "camp_radio_tower", "preview": "radio_chatter", "desc": "Spoken lines and radio chatter."},
		{"key": "vol_ui", "type": "slider", "label": "UI sounds", "icon": "set_ui", "preview": "ui_tap"},
		{"key": "vol_ambience", "type": "slider", "label": "Ambience", "icon": "set_ambience", "desc": "Wind, zone beds, the hangar."},
		{"key": "mute", "type": "toggle", "label": "Mute all", "icon": "set_mute"},
		{"key": "mute_background", "type": "toggle", "label": "Mute in background", "icon": "set_mute", "desc": "Silence the game when you switch apps."},
	]},
	{"id": "video", "label": "VIDEO", "icon": "set_shimmer", "rows": [
		{"key": "quality", "type": "choice", "label": "Quality", "icon": "set_shimmer", "options": QUALITY_NAMES, "desc": "Sets frame rate, render scale, effects and heat haze. Changing one of those makes it CUSTOM."},
		{"key": "video_auto", "type": "action", "label": "Auto-detect for this device", "icon": "tab_workshop"},
		{"key": "fps_cap", "type": "choice", "label": "Frame rate cap", "icon": "hud_timer", "options": FPS_NAMES, "desc": "120 needs a ProMotion screen (others stop at 60)."},
		{"key": "render_scale", "type": "choice", "label": "Render scale", "icon": "set_grain", "options": RENDER_NAMES, "desc": "50% draws at the base resolution and scales up: lighter on the GPU, softer text."},
		{"key": "fx_quality", "type": "choice", "label": "Particles & effects", "icon": "set_grain", "options": FX_NAMES, "desc": "Debris, dust and particle counts."},
		{"key": "battery_saver", "type": "toggle", "label": "Battery saver", "icon": "camp_generator", "desc": "30 fps, 50% render, low effects, no heat haze."},
		{"key": "shake_level", "type": "choice", "label": "Screen shake", "icon": "set_shake", "options": SHAKE_NAMES},
		{"key": "flash_intensity", "type": "slider", "label": "Flash & hit-flash", "icon": "ammo_shock", "desc": "Hit flashes on units and the screen edge."},
		{"key": "dmg_numbers", "type": "choice", "label": "Damage numbers", "icon": "hud_kills", "options": DMG_NAMES, "desc": "FEWER: crits, and at most 6 numbers on screen."},
		{"key": "brightness", "type": "slider", "label": "Brightness", "icon": "set_shimmer", "fmt": "signed", "desc": "Match world gamma. Make the left swatch barely visible.", "swatch": true},
		{"key": "heat_shimmer", "type": "toggle", "label": "Heat shimmer", "icon": "set_shimmer", "desc": "Faint heat haze over the map."},
		{"key": "edge_dither", "type": "toggle", "label": "Edge dither", "icon": "set_grain", "desc": "Pixel-dither shading at the screen edges."},
		{"key": "show_fps", "type": "toggle", "label": "Show FPS", "icon": "hud_timer", "admin": true, "desc": "Admin only."},
	]},
	{"id": "controls", "label": "CONTROLS", "icon": "set_stick", "rows": [
		{"key": "left_handed", "type": "toggle", "label": "Left-handed", "icon": "set_lefty", "desc": "DASH / ABILITY on the left."},
		{"key": "stick_aim", "type": "toggle", "label": "Aim with the stick", "icon": "set_stick", "desc": "Fire still auto-triggers, but picks the enemy you're steering toward."},
		{"key": "stick_scale", "type": "slider", "label": "Stick size", "icon": "set_stick", "min": 0.75, "max": 1.4, "step": 0.05, "fmt": "pct", "desc": "Bigger = finer control, more thumb travel."},
		{"key": "stick_opacity", "type": "slider", "label": "Stick opacity", "icon": "set_stick", "min": 0.3, "max": 1.0, "step": 0.05, "fmt": "pct"},
		{"key": "haptics", "type": "toggle", "label": "Vibration", "icon": "set_vibration", "desc": "Taps for hits, elite kills, rare pickups, extracting."},
		{"key": "haptic_strength", "type": "slider", "label": "Vibration strength", "icon": "set_vibration", "min": 0.2, "max": 1.0, "step": 0.05, "fmt": "pct", "preview_haptic": true},
	]},
	{"id": "access", "label": "ACCESS", "icon": "set_hints", "rows": [
		{"key": "text_size", "type": "choice", "label": "Text size", "icon": "tab_notes", "options": ["NORMAL", "LARGE", "XL"]},
		{"key": "caption_size", "type": "choice", "label": "Caption size", "icon": "tab_stories", "options": CAPTION_NAMES, "desc": "Story dialogue and radio subtitles."},
		{"key": "reduce_motion", "type": "toggle", "label": "Reduce motion", "icon": "set_shake", "desc": "No shake, pops, wipes or drifting menus."},
		{"key": "cb_loot", "type": "toggle", "label": "Colour-blind loot", "icon": "hud_loot", "desc": "Shapes on rarity: ● common  ▲ rare  ◆ epic  ★ legendary."},
		{"key": "show_hints", "type": "toggle", "label": "Tutorial hints", "icon": "set_hints", "desc": "Ghost stick and rotating tips."},
		{"key": "auto_salvage_tier", "type": "choice", "label": "Auto-salvage", "icon": "cur_scrap", "options": ["OFF", "COMMONS", "UP TO RARE", "UP TO EPIC"], "desc": "On extract, finds at or under this rarity turn into scrap. Never Legendary, locked, insured, worn or upgrades; set pieces only with the Stash toggle. Buy back from the stash."},
		{"key": "replay_tutorial", "type": "action", "label": "Replay tutorial", "icon": "set_tutorial"},
	]},
	{"id": "about", "label": "ABOUT", "icon": "tab_notes", "rows": [
		{"key": "build", "type": "info", "label": "Build", "icon": "tab_workshop"},
		{"key": "credits", "type": "action", "label": "Credits & licences", "icon": "tab_notes"},
		{"key": "feedback", "type": "action", "label": "Send feedback", "icon": "tab_notes"},
		{"key": "fullscreen", "type": "action", "label": "Fullscreen", "icon": "tab_workshop", "desktop": true},
		{"key": "reset_save", "type": "action", "label": "Reset save", "icon": "set_reset", "desc": "Hold 2 s, then confirm. Wipes all progress."},
	]},
]


## Every stored setting key with a row (actions / info excluded).
static func keys() -> Array:
	var out: Array = []
	for t in TABS:
		for r in t["rows"]:
			if str(r["type"]) in ["slider", "toggle", "choice"]:
				out.append(str(r["key"]))
	return out


static func tab(id: String) -> Dictionary:
	for t in TABS:
		if str(t["id"]) == id:
			return t
	return TABS[0]


static func row(key: String) -> Dictionary:
	for t in TABS:
		for r in t["rows"]:
			if str(r["key"]) == key:
				return r
	return {}


## Brings any saved settings dictionary up to date in place: old keys are
## carried over (screen_shake on/off -> shake_level FULL/OFF), JSON numbers
## are coerced back to their real types, missing keys get defaults, and
## out-of-range values are clamped.
static func migrate(st: Dictionary) -> void:
	upgrade_keys(st)
	for k in DEFAULTS:
		var d: Variant = DEFAULTS[k]
		if not st.has(k):
			st[k] = d
			continue
		var v: Variant = st[k]
		match typeof(d):
			TYPE_BOOL:
				st[k] = bool(v) if typeof(v) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] else d
			TYPE_INT:
				st[k] = int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL] else d
			TYPE_FLOAT:
				st[k] = float(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else d
	for k in ["fps_cap", "shake_level", "caption_size", "dmg_numbers"]:
		st[k] = clampi(int(st[k]), 0, 2)
	st["fx_quality"] = clampi(int(st["fx_quality"]), 0, FX_NAMES.size() - 1)
	st["render_scale"] = clampi(int(st["render_scale"]), 0, RENDER_NAMES.size() - 1)
	## -1 = an old save without a preset: the preset its values match, else CUSTOM.
	if int(st["quality"]) < 0:
		st["quality"] = preset_for(st)
	st["quality"] = clampi(int(st["quality"]), 0, QUALITY_CUSTOM)
	st["text_size"] = clampi(int(st["text_size"]), 0, 2)
	for k in ["vol_master", "vol_music", "vol_sfx", "vol_voice", "vol_ui", "vol_ambience", "flash_intensity", "brightness"]:
		st[k] = clampf(float(st[k]), 0.0, 1.0)
	st["stick_scale"] = clampf(float(st["stick_scale"]), 0.75, 1.4)
	st["stick_opacity"] = clampf(float(st["stick_opacity"]), 0.3, 1.0)
	st["haptic_strength"] = clampf(float(st["haptic_strength"]), 0.2, 1.0)
	st["settings_v"] = VERSION


## Renamed keys in a saved settings block (call on the saved dictionary
## before it is merged over the defaults).
static func upgrade_keys(st: Dictionary) -> void:
	if st.has("screen_shake") and not st.has("shake_level"):
		st["shake_level"] = 2 if bool(st["screen_shake"]) else 0
	st.erase("screen_shake")
	## The old "film_grain" key has driven the edge dither since the style pass.
	if st.has("film_grain") and not st.has("edge_dither"):
		st["edge_dither"] = bool(st["film_grain"])
	st.erase("film_grain")
	## v3: damage numbers on/off -> ALL / OFF.
	if st.has("damage_numbers") and not st.has("dmg_numbers"):
		st["dmg_numbers"] = 2 if bool(st["damage_numbers"]) else 0
	st.erase("damage_numbers")
	## v3: saves from before the Quality preset keep their own video values
	## (and full render scale); the preset is worked out from them in migrate().
	if not st.has("quality"):
		st["quality"] = -1
		if not st.has("render_scale"):
			st["render_scale"] = 0


## Default values for one tab's stored keys (video: this device's auto preset).
static func tab_defaults(id: String) -> Dictionary:
	var out := {}
	var auto := auto_video()
	for r in tab(id)["rows"]:
		var k := str(r["key"])
		if auto.has(k):
			out[k] = auto[k]
		elif DEFAULTS.has(k):
			out[k] = DEFAULTS[k]
	return out


## --- quality presets + device auto-detect ----------------------------------------

## The preset index whose values all match `st`, else QUALITY_CUSTOM.
static func preset_for(st: Dictionary) -> int:
	for i in range(PRESETS.size()):
		var ok := true
		for k in PRESETS[i]:
			var want: Variant = PRESETS[i][k]
			var have: Variant = st.get(k, DEFAULTS.get(k))
			if typeof(want) == TYPE_BOOL:
				ok = ok and bool(have) == bool(want)
			else:
				ok = ok and int(have) == int(want)
		if ok:
			return i
	return QUALITY_CUSTOM


## Device class from the chip / model: 2 = A17 Pro and newer (A18, A19, the
## iPhone Duo's A20 Pro), M-series iPads and desktops; 1 = A14-A16 phones,
## the web build on other GPUs and mid Android; 0 = older.
static func device_tier() -> int:
	return device_tier_for(OS.get_model_name(), RenderingServer.get_video_adapter_name(),
		OS.has_feature("web"), OS.has_feature("mobile"), OS.get_processor_count())


static func device_tier_for(model: String, gpu: String, web: bool, mobile: bool, cores: int) -> int:
	## Web: Apple GPUs (iPhone / iPad / Mac browsers) handle HIGH; the
	## browser itself holds the frame rate to what the screen allows.
	if web:
		return 2 if gpu.contains("Apple") else 1
	for chip in ["A17", "A18", "A19", "A20", "A21", " M1", " M2", " M3", " M4", " M5"]:
		if gpu.contains(chip):
			return 2
	var fam := ""
	for f in ["iPhone", "iPad"]:
		if model.begins_with(f):
			fam = f
	if fam != "":
		var major := model.substr(fam.length()).get_slice(",", 0).to_int()
		if fam == "iPhone":
			## iPhone16,x = 15 Pro (A17 Pro); 13,x = 12 (A14).
			return 2 if major >= 16 else (1 if major >= 13 else 0)
		## iPad13,x = first M1 iPads; iPad8,x = A12X.
		return 2 if major >= 13 else (1 if major >= 8 else 0)
	if mobile:
		return 1 if cores >= 8 else 0
	return 2


## Video values for this device: A20-class (iPhone Duo) and other fast chips
## get HIGH at 120, mid phones MEDIUM at 60, old ones LOW.
static func auto_video(tier: int = -1) -> Dictionary:
	if tier < 0:
		tier = device_tier()
	var q: int = clampi(tier, 0, 2)
	var out: Dictionary = (PRESETS[q] as Dictionary).duplicate()
	out["quality"] = q
	return out


## Apply a preset's values (live + saved by the caller).
static func apply_preset(q: int) -> void:
	if q < 0 or q >= PRESETS.size():
		return
	_preset_busy = true
	for k in PRESETS[q]:
		GameState.set_setting(str(k), PRESETS[q][k], false)
	_preset_busy = false
	GameState.settings["quality"] = q


static var _preset_busy: bool = false


## --- effective values (read by the game systems) ----------------------------

static func _s() -> Dictionary:
	return GameState.settings


static func get_value(key: String) -> Variant:
	return _s().get(key, DEFAULTS.get(key))


static func reduce_motion() -> bool:
	return bool(get_value("reduce_motion"))


static func battery_saver() -> bool:
	return bool(get_value("battery_saver"))


## Screen-shake multiplier (Reduce motion turns it off).
static func shake_mult() -> float:
	if reduce_motion():
		return 0.0
	return float(SHAKE_MULT[clampi(int(get_value("shake_level")), 0, 2)])


## 0..1 strength of hit flashes (units, screen edge, light bursts).
static func flash_k() -> float:
	return clampf(float(get_value("flash_intensity")), 0.0, 1.0)


## Particle / debris count multiplier (Battery saver forces LOW).
static func fx_level() -> int:
	return 0 if battery_saver() else clampi(int(get_value("fx_quality")), 0, FX_NAMES.size() - 1)


static func fx_mult() -> float:
	return float(FX_MULT[fx_level()])


## Engine.max_fps for the cap (Battery saver = 30).
static func target_fps() -> int:
	if battery_saver():
		return 30
	return int(FPS_VALUES[clampi(int(get_value("fps_cap")), 0, 2)])


## Render at the base (design) resolution instead of the screen's own.
static func render_low() -> bool:
	return battery_saver() or int(get_value("render_scale")) == 1


## Damage numbers: 0 off, 1 fewer (crits, soft cap 6), 2 all.
static func dmg_numbers() -> int:
	return clampi(int(get_value("dmg_numbers")), 0, 2)


static func heat_shimmer_on() -> bool:
	return bool(get_value("heat_shimmer")) and not battery_saver()


static func haptic_k() -> float:
	return clampf(float(get_value("haptic_strength")), 0.2, 1.0)


static func caption_scale() -> float:
	return float(CAPTION_SCALE[clampi(int(get_value("caption_size")), 0, 2)])


static func cb_loot() -> bool:
	return bool(get_value("cb_loot"))


## Brightness slider 0..1 -> gamma exponent for the match grade (0.5 = 1.0).
static func gamma() -> float:
	var b := clampf(float(get_value("brightness")), 0.0, 1.0)
	return lerpf(1.45, 1.0, b * 2.0) if b < 0.5 else lerpf(1.0, 0.6, (b - 0.5) * 2.0)


## --- live application ---------------------------------------------------------

## Apply one changed key to the running game (or everything with "").
static func apply(key: String = "") -> void:
	var all := key == ""
	if all or key.begins_with("vol_") or key in ["mute", "mute_background"]:
		Juice.apply_audio_settings()
	if all or key in ["fps_cap", "battery_saver"]:
		apply_fps()
	if key == "quality" and not _preset_busy:
		apply_preset(int(get_value("quality")))
	if all or key in ["render_scale", "battery_saver"]:
		var df: Node = Engine.get_main_loop().root.get_node_or_null("DisplayFit") if Engine.get_main_loop() is SceneTree else null
		if df and df.has_method("sync_stretch"):
			df.call("sync_stretch")
	## Changing one preset value by hand turns the preset into CUSTOM (or the
	## preset the values now match).
	if not all and not _preset_busy and key in ["fps_cap", "render_scale", "fx_quality", "heat_shimmer"]:
		GameState.settings["quality"] = preset_for(GameState.settings)
	if all or key == "flash_intensity":
		UnitAnim.flash_material().set_shader_parameter("amount", flash_k())
	if all or key == "show_fps":
		var adm: Node = Engine.get_main_loop().root.get_node_or_null("Admin") if Engine.get_main_loop() is SceneTree else null
		if adm and adm.has_method("set_fps_visible"):
			## The counter is an admin tool: only while admin mode is on.
			adm.call("set_fps_visible", bool(get_value("show_fps")) and bool(adm.get("enabled")))


## Engine.max_fps = the cap, vsync on (no tearing; the display link paces
## frames, the cap stops ProMotion screens at 30 / 60 when asked).
static func apply_fps() -> void:
	Engine.max_fps = target_fps()
	if DisplayServer.get_name() != "headless":
		if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_ENABLED:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
