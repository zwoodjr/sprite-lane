class_name SettingsDefs
extends RefCounted

## Player settings: defaults, the tabbed Settings layout, old-save migration
## and the "effective value" helpers the game systems read (shake, flash,
## particles, haptics, fps). Values live in GameState.settings and are saved
## with the profile; GameState.set_setting() applies them live via apply().

## Bumped when a key is renamed or changes type (see migrate()).
const VERSION := 2

const DEFAULTS := {
	## AUDIO (volumes are linear 0..1, shown 0-100)
	"vol_master": 1.0, "vol_music": 0.7, "vol_sfx": 1.0, "vol_voice": 1.0, "vol_ui": 0.8, "vol_ambience": 0.8,
	"mute": false, "mute_background": true,
	## VIDEO
	"fps_cap": 1, "battery_saver": false, "shake_level": 2, "flash_intensity": 1.0, "fx_quality": 2,
	"damage_numbers": true, "brightness": 0.5, "heat_shimmer": false, "edge_dither": false, "show_fps": false,
	## CONTROLS
	"left_handed": false, "stick_scale": 1.0, "stick_opacity": 1.0, "haptics": true, "haptic_strength": 1.0,
	## ACCESSIBILITY / GAME
	"text_size": 0, "reduce_motion": false, "cb_loot": false, "caption_size": 0, "auto_salvage_commons": false,
	"show_hints": true,
}

const FPS_NAMES := ["30", "60", "MAX"]
const FPS_VALUES := [30, 60, 0]
const SHAKE_NAMES := ["OFF", "LOW", "FULL"]
const SHAKE_MULT := [0.0, 0.45, 1.0]
const FX_NAMES := ["LOW", "MEDIUM", "HIGH"]
const FX_MULT := [0.35, 0.65, 1.0]
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
		{"key": "fps_cap", "type": "choice", "label": "Frame rate cap", "icon": "hud_timer", "options": FPS_NAMES, "desc": "MAX follows the screen (up to 120 on ProMotion)."},
		{"key": "battery_saver", "type": "toggle", "label": "Battery saver", "icon": "camp_generator", "desc": "30 fps, low effects, no heat haze."},
		{"key": "shake_level", "type": "choice", "label": "Screen shake", "icon": "set_shake", "options": SHAKE_NAMES},
		{"key": "flash_intensity", "type": "slider", "label": "Flash & hit-flash", "icon": "ammo_shock", "desc": "Hit flashes on units and the screen edge."},
		{"key": "fx_quality", "type": "choice", "label": "Effects quality", "icon": "set_grain", "options": FX_NAMES, "desc": "Debris, dust and particle counts."},
		{"key": "damage_numbers", "type": "toggle", "label": "Damage numbers", "icon": "hud_kills"},
		{"key": "brightness", "type": "slider", "label": "Brightness", "icon": "set_shimmer", "fmt": "signed", "desc": "Match world gamma. Make the left swatch barely visible.", "swatch": true},
		{"key": "heat_shimmer", "type": "toggle", "label": "Heat shimmer", "icon": "set_shimmer", "desc": "Faint heat haze over the map."},
		{"key": "edge_dither", "type": "toggle", "label": "Edge dither", "icon": "set_grain", "desc": "Pixel-dither shading at the screen edges."},
		{"key": "show_fps", "type": "toggle", "label": "Show FPS", "icon": "hud_timer"},
	]},
	{"id": "controls", "label": "CONTROLS", "icon": "set_stick", "rows": [
		{"key": "left_handed", "type": "toggle", "label": "Left-handed", "icon": "set_lefty", "desc": "DASH / ABILITY on the left."},
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
		{"key": "auto_salvage_commons", "type": "toggle", "label": "Auto-salvage Commons", "icon": "cur_scrap", "desc": "On extract, plain Commons turn into scrap. Buy back from the stash."},
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
	for k in ["fps_cap", "shake_level", "fx_quality", "caption_size"]:
		st[k] = clampi(int(st[k]), 0, 2)
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


## Default values for one tab's stored keys.
static func tab_defaults(id: String) -> Dictionary:
	var out := {}
	for r in tab(id)["rows"]:
		var k := str(r["key"])
		if DEFAULTS.has(k):
			out[k] = DEFAULTS[k]
	return out


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
	return 0 if battery_saver() else clampi(int(get_value("fx_quality")), 0, 2)


static func fx_mult() -> float:
	return float(FX_MULT[fx_level()])


## Engine.max_fps for the cap (0 = uncapped; Battery saver = 30).
static func target_fps() -> int:
	if battery_saver():
		return 30
	return int(FPS_VALUES[clampi(int(get_value("fps_cap")), 0, 2)])


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
	if all or key == "flash_intensity":
		UnitAnim.flash_material().set_shader_parameter("amount", flash_k())
	if all or key == "show_fps":
		var adm: Node = Engine.get_main_loop().root.get_node_or_null("Admin") if Engine.get_main_loop() is SceneTree else null
		if adm and adm.has_method("set_fps_visible"):
			adm.call("set_fps_visible", bool(get_value("show_fps")))


static func apply_fps() -> void:
	Engine.max_fps = target_fps()
