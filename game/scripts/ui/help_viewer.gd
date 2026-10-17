extends VBoxContainer

## Paged "How to play" card with prev/next and page dots.

signal finished

const HelpPagesScript = preload("res://scripts/data/help_pages.gd")

var _pages: Array[Dictionary] = []
var _index: int = 0
var _icon: Label
var _title: Label
var _body: Label
var _dots: HBoxContainer
var _prev: Button
var _next: Button
var _card: PanelContainer


func _ready() -> void:
	_pages = HelpPagesScript.pages()
	add_theme_constant_override("separation", 14)
	_card = PanelContainer.new()
	_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, UiTheme.LINE, 20, 2, 26))
	add_child(_card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	_card.add_child(h)
	_icon = UiTheme.title_label("◎", 88, UiTheme.AMBER)
	_icon.custom_minimum_size = Vector2(120, 0)
	_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	h.add_child(v)
	_title = UiTheme.title_label("", 32, UiTheme.AMBER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(_title)
	_body = UiTheme.body_label("", 19)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 14)
	add_child(nav)
	_prev = UiTheme.big_button("‹ BACK", UiTheme.LINE, 56, 20)
	_prev.pressed.connect(func() -> void: _go(_index - 1))
	nav.add_child(_prev)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.add_theme_constant_override("separation", 8)
	nav.add_child(_dots)
	for i in range(_pages.size()):
		var d := Label.new()
		d.text = "●"
		d.add_theme_font_size_override("font_size", 14)
		_dots.add_child(d)
	_next = UiTheme.big_button("NEXT ›", UiTheme.AMBER, 56, 20)
	_next.pressed.connect(func() -> void:
		if _index >= _pages.size() - 1:
			finished.emit()
		else:
			_go(_index + 1)
	)
	nav.add_child(_next)
	_go(0)


func _go(i: int) -> void:
	_index = clampi(i, 0, _pages.size() - 1)
	var p: Dictionary = _pages[_index]
	_icon.text = str(p["icon"])
	_title.text = str(p["title"])
	_body.text = str(p["body"])
	_prev.disabled = _index == 0
	_next.text = "DONE ✓" if _index == _pages.size() - 1 else "NEXT ›"
	for j in range(_dots.get_child_count()):
		(_dots.get_child(j) as Label).add_theme_color_override("font_color", UiTheme.AMBER if j == _index else Color(0.4, 0.33, 0.25))
	_card.modulate.a = 0.0
	_card.create_tween().tween_property(_card, "modulate:a", 1.0, 0.18)
