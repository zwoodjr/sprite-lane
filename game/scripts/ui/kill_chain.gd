extends Control

## Kill chain readout (overnight polish pass): kills landed within CHAIN_WINDOW
## of each other stack into a chain. The number punches in on every kill, its
## colour heats up bone -> amber -> rust -> red, and milestones call out a word
## ("CARNAGE") with a small shake. Polls GameState.kills, so every kill source
## (bullets, pets, mines, explosions) counts with no extra wiring. Pure
## presentation: no gameplay effect, nothing saved.

const CHAIN_WINDOW := 2.2
const SHOW_AT := 5
const MILESTONES := {10: "RAMPAGE", 25: "CARNAGE", 50: "MASSACRE", 100: "WASTELAND LEGEND"}
const HEAT := [Color("e9dfc9"), Color("ffc040"), Color("e88a1c"), Color("ff4836")]

var _last_kills: int = -1
var _chain: int = 0
var _left: float = 0.0
var _num: Label
var _word: Label
var _bar: ColorRect
var _best: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var font: Font = UiTheme.font_display
	_num = Label.new()
	_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_num.add_theme_font_override("font", font)
	_num.add_theme_font_size_override("font_size", 40)
	_num.add_theme_constant_override("outline_size", 8)
	_num.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.95))
	add_child(_num)
	_word = Label.new()
	_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_word.add_theme_font_override("font", UiTheme.font_button)
	_word.add_theme_font_size_override("font_size", 20)
	_word.add_theme_constant_override("outline_size", 6)
	_word.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.95))
	_word.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_word.text = "KILL CHAIN"
	add_child(_word)
	## Timer sliver: how long until the chain drops.
	_bar = ColorRect.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.color = UiTheme.AMBER
	add_child(_bar)
	resized.connect(_lay)
	_lay()


func _lay() -> void:
	_num.position = Vector2(0, 0)
	_num.size = Vector2(size.x, 44)
	_word.position = Vector2(0, 42)
	_word.size = Vector2(size.x, 24)
	_bar.position = Vector2(size.x - 120.0, 70)
	_bar.size = Vector2(120.0, 3)


func best_chain() -> int:
	return _best


func _process(delta: float) -> void:
	var k := GameState.kills
	if _last_kills < 0 or k < _last_kills:
		_last_kills = k
	if k > _last_kills:
		var add := k - _last_kills
		_last_kills = k
		_on_kills(add)
	if _chain > 0:
		_left -= delta
		if _left <= 0.0:
			_chain = 0
	var want := 1.0 if _chain >= SHOW_AT else 0.0
	modulate.a = move_toward(modulate.a, want, delta * (8.0 if want > 0.0 else 2.5))
	visible = modulate.a > 0.01
	if visible and _chain > 0:
		_bar.size.x = 120.0 * clampf(_left / CHAIN_WINDOW, 0.0, 1.0)
		_bar.position.x = size.x - _bar.size.x


func _on_kills(add: int) -> void:
	var before := _chain
	_chain += add
	_left = CHAIN_WINDOW
	_best = maxi(_best, _chain)
	GameState.run_best_chain = maxi(GameState.run_best_chain, _chain)
	if _chain < SHOW_AT:
		return
	_num.text = "x%d" % _chain
	var heat: Color = HEAT[clampi(int(log(float(_chain) / float(SHOW_AT)) / log(2.0) + 0.5), 0, HEAT.size() - 1)]
	_num.add_theme_color_override("font_color", heat)
	_bar.color = heat
	## Punch: bigger for milestones.
	var hit := ""
	for m in MILESTONES.keys():
		if before < int(m) and _chain >= int(m):
			hit = str(MILESTONES[m])
	_num.pivot_offset = Vector2(size.x, 22)
	_num.scale = Vector2.ONE * (1.6 if hit != "" else 1.25)
	var tw := _num.create_tween()
	tw.tween_property(_num, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hit != "":
		_word.text = hit
		_word.add_theme_color_override("font_color", heat)
		Juice.shake(0.18)
		Juice.haptic(Juice.HAPTIC_HIT)
		Juice.sfx("threat_up", -6.0)
	elif before < SHOW_AT:
		_word.text = "KILL CHAIN"
		_word.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
