extends VBoxContainer

## Reusable settings list (main-menu Settings screen + in-run pause menu).
## Every control writes straight to GameState.settings and saves.

signal changed

const ROWS := [
	{"key": "stick_scale", "type": "slider", "label": "Stick size", "desc": "Bigger = finer control, more thumb travel.", "min": 0.75, "max": 1.4, "step": 0.05},
	{"key": "left_handed", "type": "toggle", "label": "Left-handed layout", "desc": "Stick on the right, DASH / ABILITY on the left."},
	{"key": "show_hints", "type": "toggle", "label": "Show hints", "desc": "Ghost stick and rotating tips."},
	{"key": "mute", "type": "toggle", "label": "Mute all audio", "desc": ""},
	{"key": "vol_master", "type": "slider", "label": "Master volume", "desc": "", "min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "vol_music", "type": "slider", "label": "Music", "desc": "", "min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "vol_sfx", "type": "slider", "label": "Effects", "desc": "Weapons, mobs, pickups.", "min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "vol_ambience", "type": "slider", "label": "Ambience", "desc": "Wind, zone beds, the hangar.", "min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "vol_ui", "type": "slider", "label": "Interface", "desc": "", "min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "haptics", "type": "toggle", "label": "Vibration", "desc": ""},
	{"key": "screen_shake", "type": "toggle", "label": "Screen shake", "desc": ""},
	{"key": "heat_shimmer", "type": "toggle", "label": "Heat shimmer", "desc": "Faint heat haze over the map. Off saves battery."},
	{"key": "film_grain", "type": "toggle", "label": "Film grain", "desc": "Subtle grain over the wasteland."},
]


const ICON := {"stick_scale": "set_stick", "left_handed": "set_lefty", "show_hints": "set_hints", "mute": "set_mute",
	"vol_master": "set_volume", "vol_music": "set_music", "vol_sfx": "set_sfx", "vol_ambience": "set_ambience",
	"vol_ui": "set_ui", "haptics": "set_vibration", "screen_shake": "set_shake", "heat_shimmer": "set_shimmer",
	"film_grain": "set_grain"}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	for row in ROWS:
		add_child(_make_row(row))


func _make_row(row: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.plate("inset", 8.0))
	panel.tooltip_text = str(row.get("desc", ""))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	panel.add_child(h)
	h.add_child(IconSet.rect(str(ICON.get(str(row["key"]), "set_ui")), 48))
	var text := UiTheme.head_label(str(row["label"]), UiTheme.T_H3, UiTheme.TEXT)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(text)
	var key := str(row["key"])
	match str(row["type"]):
		"toggle":
			var b := Button.new()
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(112, 64)
			b.button_pressed = bool(GameState.settings.get(key, false))
			_style_toggle(b)
			b.toggled.connect(func(on: bool) -> void:
				GameState.set_setting(key, on)
				_style_toggle(b)
				Juice.apply_audio_settings()
				Juice.sfx("ui_toggle")
				changed.emit()
			)
			h.add_child(b)
		"slider":
			var box := HBoxContainer.new()
			box.add_theme_constant_override("separation", 8)
			var s := HSlider.new()
			s.min_value = float(row["min"])
			s.max_value = float(row["max"])
			s.step = float(row["step"])
			s.value = float(GameState.settings.get(key, row["min"]))
			s.custom_minimum_size = Vector2(200, 64)
			s.focus_mode = Control.FOCUS_NONE
			var val := UiTheme.pixel_label("", UiTheme.PX_M, UiTheme.AMBER)
			val.custom_minimum_size = Vector2(72, 0)
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			val.text = _fmt(key, s.value)
			s.value_changed.connect(func(v: float) -> void:
				val.text = _fmt(key, v)
				GameState.settings[key] = v
				if key.begins_with("vol_"):
					Juice.apply_audio_settings()
				changed.emit()
			)
			s.drag_ended.connect(func(_c: bool) -> void:
				GameState.save_profile()
				if key.begins_with("vol_"):
					Juice.sfx("ui_tap" if key == "vol_ui" else "pick_rare")
			)
			box.add_child(s)
			box.add_child(val)
			h.add_child(box)
	return panel


func _fmt(key: String, v: float) -> String:
	if key == "stick_scale":
		return "%d%%" % int(round(v * 100.0))
	return "%d%%" % int(round(v * 100.0))


func _style_toggle(b: Button) -> void:
	var on := b.button_pressed
	b.text = "ON" if on else "OFF"
	UiTheme.skin_button(b, UiTheme.TEAL if on else UiTheme.LINE, 12.0)
	var col := Color(0.85, 1.0, 0.92) if on else UiTheme.TEXT_DIM
	for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, col)
