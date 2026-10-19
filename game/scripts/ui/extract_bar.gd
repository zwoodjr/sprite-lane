extends Control

## Vertical run-schedule bar on the left screen edge (bottom = drop-in,
## top = Dust storm). Green bands = extract windows, red band = last chance,
## amber fill = time elapsed, white tick = now.

var _phases: Array = []
var _total: float = 1.0
var _clock: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_schedule(phases: Array) -> void:
	_phases = phases
	_total = 0.0
	for p in phases:
		_total += float(p["duration"])
	_total = maxf(_total, 0.01)


func set_clock(elapsed: float) -> void:
	_clock = elapsed


## Legacy no-ops (older HUD calls).
func set_open(_is_open: bool) -> void:
	pass


func set_state(_phase: Dictionary, _time_left: float) -> void:
	pass


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := 12.0
	var x := (size.x - w) * 0.5
	var h := size.y
	var frame := Rect2(x - 3.0, -3.0, w + 6.0, h + 6.0)
	draw_rect(frame, Color(0.06, 0.045, 0.03, 0.85), true)
	## Elapsed fill (from the bottom).
	var k := clampf(_clock / _total, 0.0, 1.0)
	draw_rect(Rect2(x, h * (1.0 - k), w, h * k), Color(UiTheme.AMBER.r, UiTheme.AMBER.g, UiTheme.AMBER.b, 0.55), true)
	## Window bands.
	var acc := 0.0
	for p in _phases:
		var d := float(p["duration"])
		if bool(p.get("extract_open", false)):
			var y0 := h * (1.0 - (acc + d) / _total)
			var y1 := h * (1.0 - acc / _total)
			var last := bool(p.get("is_last", false))
			var col := UiTheme.DANGER if last else Color(0.45, 0.95, 0.55)
			var live := _clock >= acc and _clock < acc + d
			var a := (0.75 + 0.25 * sin(_t * 6.0)) if live else 0.85
			draw_rect(Rect2(x - 2.0, y0, w + 4.0, maxf(3.0, y1 - y0)), Color(col.r, col.g, col.b, a), true)
			if last:
				## Last-chance marker: a red notch sticking out to the right.
				var my := (y0 + y1) * 0.5
				draw_colored_polygon(PackedVector2Array([
					Vector2(x + w + 3.0, my - 6.0), Vector2(x + w + 11.0, my), Vector2(x + w + 3.0, my + 6.0),
				]), UiTheme.DANGER)
		acc += d
	draw_rect(frame, Color(0.45, 0.34, 0.2, 0.95), false, 2.0)
	## Now tick.
	var ny := h * (1.0 - k)
	draw_rect(Rect2(x - 5.0, ny - 1.5, w + 10.0, 3.0), Color(1, 1, 1, 0.95), true)
