extends Control

## Boss health bar (audit quick win #5): top-centre, under the extract strip.
## Shows the live boss's name and HP, with phase ticks when the boss defines
## them (EnemyDefs "phases": [0.66, 0.33] style HP fractions). Polls the
## "bosses" group, so every way a boss enters (timed spawn, Warden, events)
## gets the bar without wiring.

const BAR_H := 12.0

var _boss: Node2D = null
var _name: String = ""
var _phases: Array = []
var _shown_ratio: float = 1.0
var _lag_ratio: float = 1.0
var _poll: float = 0.0
var _a: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.25
		_find_boss()
	var alive := _boss != null and is_instance_valid(_boss) and not bool(_boss.get("_dead"))
	if alive:
		var r := clampf(float(_boss.get("hp")) / maxf(float(_boss.get("max_hp")), 1.0), 0.0, 1.0)
		_shown_ratio = r
		_lag_ratio = maxf(r, move_toward(_lag_ratio, r, delta * 0.35))
	_a = move_toward(_a, 1.0 if alive else 0.0, delta * (4.0 if alive else 1.5))
	modulate.a = _a
	visible = _a > 0.01
	if visible:
		queue_redraw()


func _find_boss() -> void:
	if _boss != null and is_instance_valid(_boss) and not bool(_boss.get("_dead")):
		return
	_boss = null
	for b in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(b) and not bool(b.get("_dead")):
			_boss = b
			var k := str(b.get("kind"))
			var def: Dictionary = EnemyDefs.get_kind(k)
			_name = str(def.get("display_name", k)).to_upper()
			_phases = def.get("phases", [])
			_shown_ratio = 1.0
			_lag_ratio = 1.0
			return


func _draw() -> void:
	var w := size.x
	var f: Font = UiTheme.font_display
	var fs := 22
	if f:
		var tw := f.get_string_size(_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2((w - tw) * 0.5, 20)
		draw_string_outline(f, p, _name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.04, 0.02, 0.02, 0.95))
		draw_string(f, p, _name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.5, 0.42))
	var y := 27.0
	var r := Rect2(0, y, w, BAR_H)
	draw_rect(r.grow(2.0), Color(0.03, 0.02, 0.02, 0.92))
	draw_rect(r, Color(0.22, 0.05, 0.05))
	draw_rect(Rect2(r.position, Vector2(w * _lag_ratio, BAR_H)), Color(1.0, 0.85, 0.7))
	draw_rect(Rect2(r.position, Vector2(w * _shown_ratio, BAR_H)), Color(0.88, 0.16, 0.12))
	draw_rect(Rect2(r.position, Vector2(w * _shown_ratio, 3.0)), Color(1.0, 0.45, 0.35))
	for ph in _phases:
		var x := w * float(ph)
		draw_rect(Rect2(x - 1.0, y - 2.0, 2.0, BAR_H + 4.0), Color(1.0, 0.9, 0.75, 0.9))
