extends Control

## The smashed LCD readout used for the in-match health / XP bars (locked style,
## art from tools/gen_hud_readout.py): housing texture, then segmented phosphor
## cells lit by value/max_value (a couple of dead cells), soft glow, scanlines,
## a PressStart2P label + live number, and the cracked glass on top. A digit
## glitches only as a rare, brief flicker.

const ART_W := 520.0
const ART_H := 76.0
const SCREEN := Rect2(22, 20, 476, 36)      ## art units
const CELLS_X := Vector2(92, 398)
const CELLS := 26
const DEAD := [5, 13]
const FONT := "res://assets/fonts/PressStart2P.ttf"

var kind: String = "hp"                    ## "hp" (amber) | "xp" (green)
var value: float = 1.0
var max_value: float = 1.0
var label_text: String = "HP"
var number_text: String = ""
var on_color: Color = Color(0.87, 0.54, 0.14)
var off_color: Color = Color(0.16, 0.09, 0.03)
var _housing: Texture2D
var _glass: Texture2D
var _font: Font
var _glitch_t: float = 0.0
var _glitch_left: float = 0.0
var _glitch_i: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp := kind == "hp"
	var h := "res://assets/sprites/ui/readout_%s_housing.png" % ("hp" if hp else "xp")
	var g := "res://assets/sprites/ui/readout_%s_glass.png" % ("hp" if hp else "xp")
	if ResourceLoader.exists(h):
		_housing = load(h)
	if ResourceLoader.exists(g):
		_glass = load(g)
	_font = UiTheme.font_pixel if UiTheme.font_pixel else (load(FONT) if ResourceLoader.exists(FONT) else null)
	if not hp:
		on_color = Color(0.42, 0.86, 0.46)
		off_color = Color(0.05, 0.14, 0.06)
	_glitch_t = randf_range(6.0, 14.0)


func set_value(v: float, mx: float, num: String = "") -> void:
	if is_equal_approx(v, value) and is_equal_approx(mx, max_value) and num == number_text:
		return
	value = v
	max_value = maxf(mx, 0.001)
	number_text = num
	queue_redraw()


func _process(delta: float) -> void:
	## Rare glitch: one digit flickers to "I" for a split second.
	_glitch_t -= delta
	if _glitch_left > 0.0:
		_glitch_left -= delta
		if _glitch_left <= 0.0:
			_glitch_i = -1
			queue_redraw()
	elif _glitch_t <= 0.0 and number_text.length() > 0:
		_glitch_t = randf_range(7.0, 16.0)
		_glitch_left = 0.09
		_glitch_i = randi() % number_text.length()
		queue_redraw()


func _draw() -> void:
	var k := size.x / ART_W
	var ky := size.y / ART_H
	if _housing:
		draw_texture_rect(_housing, Rect2(Vector2.ZERO, size), false)
	var y0 := (SCREEN.position.y + 7.0) * ky
	var y1 := (SCREEN.end.y - 7.0) * ky
	var cw := (CELLS_X.y - CELLS_X.x) * k / float(CELLS)
	var lit := int(round(clampf(value / max_value, 0.0, 1.0) * CELLS))
	if value > 0.0:
		lit = maxi(lit, 1)
	var glow := Color(on_color.r, on_color.g, on_color.b, 0.22)
	for i in range(CELLS):
		var x := CELLS_X.x * k + i * cw
		var r := Rect2(x + 0.6, y0, cw - 1.2, y1 - y0)
		var on := i < lit and not (i in DEAD)
		if on:
			draw_rect(r.grow(1.5), glow)
			draw_rect(r, on_color)
		else:
			draw_rect(r, off_color if not (i in DEAD and i < lit) else off_color.darkened(0.4))
	## Scanlines across the screen.
	var sy := SCREEN.position.y * ky
	while sy < SCREEN.end.y * ky:
		draw_line(Vector2(SCREEN.position.x * k, sy), Vector2(SCREEN.end.x * k, sy), Color(0, 0, 0, 0.32), 1.0)
		sy += 3.0
	if _font:
		## PressStart2P only at multiples of its 8 px grid (square pixels).
		var fs := maxi(8, int(floor((y1 - y0) * 1.2 / 8.0)) * 8)
		var base_y := (y0 + y1) * 0.5 + fs * 0.5
		var tc := on_color.lightened(0.08)
		draw_string(_font, Vector2((SCREEN.position.x + 9.0) * k, base_y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
		var num := number_text
		if _glitch_i >= 0 and _glitch_i < num.length() and num[_glitch_i] != " ":
			num = num.substr(0, _glitch_i) + "I" + num.substr(_glitch_i + 1)
		var nw := _font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2((SCREEN.end.x - 8.0) * k - nw, base_y), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
	## (The cracked-glass overlay is gone: on a phone it read as dirt.)
