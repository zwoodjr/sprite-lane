extends Control

## Special ammo slots on the HUD (top-left, under the vitals): one small chip
## per active type, oldest first. Each chip is the ammo icon in a frame of its
## colour, a stack count ("x2", "x3") on the icon's corner and a timer strip
## under it. Active combos ("MELT", "SHATTER" …) read on one line below.
## Drawn, not built from nodes, so it stays tiny at every text size.

const ICON := 48.0
const PAD := 3.0
const GAP := 6.0
const BAR_H := 4.0

var _player: Node = null
var _font: Font
var _slots: Array = []
var _combos: Array = []
var _sig: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiTheme.font_pixel


func bind(player: Node) -> void:
	_player = player


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.has_method("get_ammo_slots"):
		if not _slots.is_empty():
			set_slots([], [])
		return
	set_slots(_player.call("get_ammo_slots"), _player.call("get_ammo_combos"))


func set_slots(slots: Array, combos: Array) -> void:
	_slots = slots
	_combos = combos
	## Size only changes with the slot / combo set; timers just redraw.
	var sig := "%d|%s" % [slots.size(), ",".join(PackedStringArray(combos))]
	if sig != _sig:
		_sig = sig
		custom_minimum_size = _want_size()
		visible = not slots.is_empty()
		update_minimum_size()
	queue_redraw()


func _fs() -> int:
	return UiTheme.pixel_px(UiTheme.PX_S)


func _chip_w() -> float:
	return ICON + PAD * 2.0


func _want_size() -> Vector2:
	if _slots.is_empty():
		return Vector2.ZERO
	var w := _chip_w() * _slots.size() + GAP * (_slots.size() - 1)
	var h := ICON + PAD * 2.0 + BAR_H + 2.0
	## One combo per line (three types make at most two combos).
	if _font:
		for cid in _combos:
			h += float(_fs()) + 6.0
			w = maxf(w, _font.get_string_size(_combo_name(cid), HORIZONTAL_ALIGNMENT_LEFT, -1, _fs()).x + 4.0)
	return Vector2(w, h)


func _combo_name(cid: Variant) -> String:
	return str(UpgradeDefs.AMMO_COMBOS.get(str(cid), {}).get("name", str(cid).to_upper()))


func _draw() -> void:
	if _slots.is_empty():
		return
	var x := 0.0
	var fs := _fs()
	var outline := Color(0.04, 0.03, 0.02, 0.9)
	for sl in _slots:
		var aid := str(sl.get("ammo", ""))
		var a: Dictionary = UpgradeDefs.AMMO.get(aid, {})
		var col: Color = a.get("color", Color.WHITE)
		var cw := _chip_w()
		var box := Rect2(Vector2(x, 0), Vector2(cw, ICON + PAD * 2.0))
		draw_rect(box, Color(0.05, 0.04, 0.03, 0.72))
		draw_rect(box, col, false, 2.0)
		var tex := IconSet.tex("ammo_" + aid, true)
		if tex:
			draw_texture_rect(tex, Rect2(Vector2(x + PAD, PAD), Vector2(ICON, ICON)), false)
		var n := int(sl.get("stacks", 1))
		if n > 1 and _font:
			var t := "x%d" % n
			var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var p := Vector2(x + cw - tw - 2.0, ICON + PAD * 2.0 - 3.0)
			draw_string_outline(_font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, outline)
			draw_string(_font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.95, 0.75))
		## Timer strip under the chip.
		var r := clampf(float(sl.get("time_left", 0.0)) / maxf(0.1, float(sl.get("max_time", 1.0))), 0.0, 1.0)
		var by := ICON + PAD * 2.0 + 2.0
		draw_rect(Rect2(Vector2(x, by), Vector2(cw, BAR_H)), Color(0.05, 0.04, 0.03, 0.85))
		var fc := col if float(sl.get("time_left", 0.0)) > 3.0 or int(Time.get_ticks_msec() / 200) % 2 == 0 else Color(1.0, 0.4, 0.3)
		draw_rect(Rect2(Vector2(x, by), Vector2(cw * r, BAR_H)), fc)
		x += cw + GAP
	if _font:
		var py := ICON + PAD * 2.0 + BAR_H + 2.0
		for cid in _combos:
			py += float(fs) + 6.0
			var cc: Color = UpgradeDefs.AMMO_COMBOS.get(str(cid), {}).get("color", UiTheme.AMBER)
			draw_string_outline(_font, Vector2(0, py), _combo_name(cid), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, outline)
			draw_string(_font, Vector2(0, py), _combo_name(cid), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cc)
