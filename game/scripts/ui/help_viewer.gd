extends VBoxContainer

## Paged "How to play" card with prev/next and page dots. Each page shows a
## piece of game art (hero, pet, pads, caps...) above the text.

signal finished

const HelpPagesScript = preload("res://scripts/data/help_pages.gd")

var _pages: Array[Dictionary] = []
var _index: int = 0
var _art_box: CenterContainer
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
	_card.add_theme_stylebox_override("panel", UiTheme.plate("panel", 26.0))
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_card.add_child(v)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UiTheme.plate("inset", 8.0))
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(stage)
	_art_box = CenterContainer.new()
	_art_box.custom_minimum_size = Vector2(0, 256)
	stage.add_child(_art_box)
	_title = UiTheme.title_label("", 34, UiTheme.AMBER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(_title)
	_body = UiTheme.body_label("", 20)
	v.add_child(_body)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 14)
	add_child(nav)
	_prev = UiTheme.big_button("‹ BACK", UiTheme.LINE, 62, 20)
	_prev.custom_minimum_size.x = 170
	_prev.pressed.connect(func() -> void: _go(_index - 1))
	nav.add_child(_prev)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.add_theme_constant_override("separation", 6)
	nav.add_child(_dots)
	for i in range(_pages.size()):
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(8, 8)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(d)
	_next = UiTheme.big_button("NEXT ›", UiTheme.AMBER, 62, 20)
	_next.custom_minimum_size.x = 170
	_next.pressed.connect(func() -> void:
		if _index >= _pages.size() - 1:
			finished.emit()
		else:
			_go(_index + 1)
	)
	nav.add_child(_next)
	_go(0)


func _art_for(p: Dictionary) -> Control:
	var art := str(p.get("art", ""))
	var hid := GameState.selected_character_id
	var path := art
	var strip := false
	match art:
		"hero":
			path = "res://assets/sprites/characters/%s/%s_idle.png" % [hid, hid]
			strip = true
		"pet":
			path = str(PetDefs.get_pet(GameState.selected_pet_id).get("sprite", ""))
			strip = true
		"ability":
			path = CharacterDefs.ability_icon_path(hid)
	if art.begins_with("strip:"):
		path = art.substr(6)
		strip = true
	if path == "" or not ResourceLoader.exists(path):
		var l := UiTheme.title_label(str(p.get("icon", "")), 88, UiTheme.AMBER)
		return l
	if strip:
		return StripAnim.make(path, 256, 8.0)
	var t := TextureRect.new()
	t.texture = load(path)
	t.custom_minimum_size = Vector2(256, 256)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t


func _go(i: int) -> void:
	_index = clampi(i, 0, _pages.size() - 1)
	var p: Dictionary = _pages[_index]
	for ch in _art_box.get_children():
		ch.queue_free()
	var art := _art_for(p)
	_art_box.add_child(art)
	_title.text = str(p["title"])
	_body.text = str(p["body"])
	_prev.disabled = _index == 0
	_next.text = "DONE ✓" if _index == _pages.size() - 1 else "NEXT ›"
	for j in range(_dots.get_child_count()):
		var d := _dots.get_child(j) as ColorRect
		d.color = UiTheme.AMBER if j == _index else Color(0.35, 0.28, 0.2)
		d.custom_minimum_size = Vector2(16 if j == _index else 8, 8)
	_card.modulate.a = 0.0
	_card.create_tween().tween_property(_card, "modulate:a", 1.0, 0.18)
	art.pivot_offset = art.custom_minimum_size * 0.5
	art.scale = Vector2(0.85, 0.85)
	art.create_tween().tween_property(art, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
