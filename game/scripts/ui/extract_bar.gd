extends Control

## Slim horizontal run-schedule tick bar under the extract timer (visual tier;
## replaces the big vertical bar on the left edge). One tick per phase, sized by
## its duration: sealed / lockout ticks are dark and fill amber as they pass,
## extract windows are green (pulsing while open), the last chance is red.
## A white notch marks now.

const GAP := 3.0

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
	if _phases.is_empty():
		return
	var w := size.x - GAP * float(_phases.size() - 1)
	var h := minf(size.y, 6.0)
	var x := 0.0
	var acc := 0.0
	var now_x := 0.0
	for p in _phases:
		var d := float(p["duration"])
		var pw := maxf(4.0, w * d / _total)
		var open := bool(p.get("extract_open", false))
		var last := bool(p.get("is_last", false))
		var live := _clock >= acc and _clock < acc + d
		var done := _clock >= acc + d
		var r := Rect2(x, 0, pw, h)
		draw_rect(r.grow(1.0), Color(0.03, 0.02, 0.015, 0.85))
		if open:
			var col := UiTheme.DANGER if last else Color(0.36, 0.86, 0.48)
			var a := (0.7 + 0.3 * sin(_t * 7.0)) if live else (0.45 if done else 0.95)
			draw_rect(r, Color(col.r, col.g, col.b, a))
		else:
			draw_rect(r, Color(0.22, 0.17, 0.11, 0.9))
			var k := clampf((_clock - acc) / maxf(d, 0.01), 0.0, 1.0)
			if k > 0.0:
				draw_rect(Rect2(x, 0, pw * k, h), Color(UiTheme.AMBER.r, UiTheme.AMBER.g, UiTheme.AMBER.b, 0.75))
		if live:
			now_x = x + pw * clampf((_clock - acc) / maxf(d, 0.01), 0.0, 1.0)
		x += pw + GAP
		acc += d
	draw_rect(Rect2(now_x - 1.0, -2.0, 2.0, h + 4.0), Color(1, 1, 1, 0.95))
