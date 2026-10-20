extends CanvasLayer

## Mid-run level-up: pick one of 3 upgrade cards (Phase 4). Pauses the tree.
## Cards are big, stacked for one thumb in portrait: rarity colour, name,
## TAGS, the PATH (current rank → next rank effect) and combo hints.
## 2 rerolls per run (UpgradeDefs.REROLLS_PER_RUN).

signal chosen(upgrade: Dictionary)

## Ignore taps for a moment so the thumb that was steering can't mis-pick.
const TAP_GUARD := 0.35
const CARD_H := 232.0

var _root: Control
var _open: bool = false
var _level: int = 1
var _choices: Array = []
var _guard: float = 0.0
var _cards_box: VBoxContainer
var _reroll_btn: Button

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	if not GameState.run_level_up.is_connected(_on_level_up):
		GameState.run_level_up.connect(_on_level_up)

func _process(delta: float) -> void:
	_guard = maxf(0.0, _guard - delta)

func _on_level_up(new_level: int, choices: Array) -> void:
	open(new_level, choices)

func is_open() -> bool:
	return _open

func get_choices() -> Array:
	return _choices

func rerolls_left() -> int:
	return GameState.run_rerolls_left

func open(new_level: int, choices: Array) -> void:
	if _open:
		return
	if choices.is_empty():
		choices = Progression.roll_run_choices()
	if choices.is_empty():
		## Every upgrade maxed — nothing to pick, don't pause.
		GameState.pending_run_choices.clear()
		GameState.run_level_paused = false
		return
	## Headless / fast-timer bots: auto-pick so the match doesn't stall paused.
	if GameState.fast_timers:
		var first: Dictionary = choices[0]
		GameState.apply_run_upgrade(first)
		chosen.emit(first)
		return
	_open = true
	_level = new_level
	_choices = choices
	_guard = TAP_GUARD
	## Release any held stick / buttons so nothing is "stuck" after the pick.
	TouchInput.clear_sticks()
	get_tree().paused = true
	_root.visible = true
	_build()
	Juice.sfx("level_up")
	Juice.sfx("card_show", -2.0)
	Juice.haptic(35)

func _build() -> void:
	for c in _root.get_children():
		c.queue_free()
	var vp := _root.get_viewport_rect().size
	var w := minf(vp.x - 40.0, 660.0)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.9)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(w, 0)
	center.add_child(v)

	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", UiTheme.plate("panel_hi", 14.0))
	v.add_child(head)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	head.add_child(hv)
	hv.add_child(UiTheme.title_label("LEVEL %d" % _level, 46, UiTheme.AMBER))
	var sub := UiTheme.body_label("Pick one upgrade — this run only", 18, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(sub)

	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 14)
	v.add_child(_cards_box)
	var k := 0
	for u in _choices:
		var cb := _card(u, w)
		_cards_box.add_child(cb)
		## Deal the cards in: staggered drop + fade.
		cb.modulate.a = 0.0
		var tw := cb.create_tween()
		tw.tween_interval(0.06 * k)
		tw.tween_property(cb, "modulate:a", 1.0, 0.16)
		k += 1

	_reroll_btn = Button.new()
	_reroll_btn.focus_mode = Control.FOCUS_NONE
	_reroll_btn.custom_minimum_size = Vector2(w * 0.6, 64)
	_reroll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_btn.add_theme_font_size_override("font_size", 24)
	UiTheme.skin_button(_reroll_btn, UiTheme.AMBER, 16.0)
	_reroll_btn.pressed.connect(reroll)
	v.add_child(_reroll_btn)
	_refresh_reroll()

func _refresh_reroll() -> void:
	if _reroll_btn == null:
		return
	var left := GameState.run_rerolls_left
	_reroll_btn.text = "REROLL  (%d left)" % left if left > 0 else "NO REROLLS LEFT"
	_reroll_btn.disabled = left <= 0

## One big tappable card.
func _card(u: Dictionary, w: float) -> Button:
	var rarity := str(u.get("rarity", "common"))
	var col := UpgradeDefs.rarity_color(rarity)
	var id := str(u.get("id", ""))
	var rank := GameState.run_rank(id)
	var max_rank := int(u.get("max_rank", 1))
	var melee := GameState.weapon.has("melee")
	var hero := GameState.selected_character_id

	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, CARD_H)
	## Riveted plate tinted by rarity; brighter while pressed.
	var tint := Color.WHITE.lerp(col, 0.5)
	b.add_theme_stylebox_override("normal", UiTheme.plate("panel_steel", 0.0, tint))
	b.add_theme_stylebox_override("hover", UiTheme.plate("panel_steel", 0.0, tint.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", UiTheme.plate("panel_hi", 0.0, tint.lightened(0.2)))
	b.add_theme_stylebox_override("hover_pressed", UiTheme.plate("panel_hi", 0.0, tint.lightened(0.2)))
	b.pressed.connect(func() -> void: _try_pick(u))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 22)
	pad.add_theme_constant_override("margin_top", 14)
	pad.add_theme_constant_override("margin_bottom", 12)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pad)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(vb)

	## Row 1: rarity · rank path
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)
	var evo := bool(u.get("evolution", false))
	var rl := _lbl(("EVOLUTION" if evo else rarity.to_upper()) + ("  ·  CLASS" if u.has("hero") else ""), 15, col)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rl)
	var path := "NEW  ·  RANK 1/%d" % max_rank if rank == 0 else "RANK %d → %d / %d" % [rank, rank + 1, max_rank]
	if evo:
		var nd: Array = u.get("needs", [])
		path = "%s MAX + %s" % [RecipeDefs.part_name(str(nd[0])), RecipeDefs.part_name(str(nd[1]))]
	top.add_child(_lbl(path, 15, UiTheme.AMBER if rank > 0 or evo else UiTheme.TEXT_DIM))

	## Name
	var nm := _lbl(str(u.get("name", "?")), 34, Color(1, 0.96, 0.88))
	nm.add_theme_font_override("font", UiTheme.font_display)
	nm.add_theme_constant_override("outline_size", 7)
	vb.add_child(nm)

	## Tags
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 6)
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tags)
	for t in _tags_for(u, melee):
		tags.add_child(_chip(t, col if t == "Class" else UiTheme.TEXT_DIM))

	## Path: next rank effect (big), current effect (small)
	var next_txt := UpgradeDefs.rank_text(u, rank + 1, melee, hero)
	var nl := _lbl(next_txt, 23, UiTheme.TEXT)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(w - 48.0, 0)
	vb.add_child(nl)
	if rank > 0:
		vb.add_child(_lbl("Now: " + UpgradeDefs.rank_text(u, rank, melee, hero), 15, UiTheme.TEXT_DIM))

	## Combos: owned partners first.
	var owned: Array[String] = []
	var others: Array[String] = []
	for cid in u.get("combos", []):
		var cd := UpgradeDefs.get_def(str(cid))
		if cd.is_empty() or (cd.has("hero") and str(cd["hero"]) != hero):
			continue
		if GameState.run_rank(str(cid)) > 0:
			owned.append(str(cd["name"]))
		else:
			others.append(str(cd["name"]))
	## Depth E3: which recipe this card leads toward (beats the combo hint).
	var rec := _recipe_hint(id, hero)
	if rec != "":
		vb.add_child(_lbl(rec, 15, RecipeDefs.COLOR))
	elif not owned.is_empty():
		vb.add_child(_lbl("COMBO with your " + ", ".join(owned), 15, UiTheme.TEAL))
	elif not others.is_empty():
		vb.add_child(_lbl("Pairs with: " + ", ".join(others.slice(0, 2)), 14, UiTheme.TEXT_DIM))
	if evo:
		## Gold glow pulse on evolution cards.
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "self_modulate", Color(1.25, 1.15, 0.85), 0.5)
		tw.tween_property(b, "self_modulate", Color.WHITE, 0.5)
	return b

## "RECIPE → Plague Bloom: max this + Spore Mines (ready)" when the partner is owned.
func _recipe_hint(id: String, hero: String) -> String:
	var recs := RecipeDefs.recipes_for(id, hero)
	if recs.is_empty():
		return ""
	var c: Dictionary = recs[0]
	for rc in recs:
		if GameState.run_rank(str(rc["id"])) <= 0:
			c = rc
			break
	var nd: Array = c["needs"]
	if str(nd[0]) == id:
		var partner := str(nd[1])
		var have := GameState.run_rank(partner) > 0 or (partner.begins_with("ammo:") and bool(GameState.run_ammo_seen.get(partner.substr(5), false)))
		return "RECIPE → %s: max this + %s%s" % [str(c["name"]), RecipeDefs.part_name(partner), "  (ready)" if have else ""]
	return "RECIPE → %s: with %s at max" % [str(c["name"]), RecipeDefs.part_name(str(nd[0]))]

## Shared Bullet/Melee cards show only the tag that applies to this hero.
func _tags_for(u: Dictionary, melee: bool) -> Array[String]:
	var out: Array[String] = []
	var tags: Array = u.get("tags", [])
	for t in tags:
		var ts := str(t)
		if ts == "Bullet" and melee and "Melee" in tags:
			continue
		if ts == "Melee" and not melee and "Bullet" in tags:
			continue
		out.append(ts)
	return out

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _chip(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.plate("inset", 8.0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _lbl(text.to_upper(), 14, color)
	l.add_theme_font_override("font", UiTheme.font_button)
	p.add_child(l)
	return p

func _try_pick(u: Dictionary) -> void:
	if _guard > 0.0:
		return
	_pick(u)

## Bot / test hooks.
func pick_index(i: int) -> void:
	if _open and i >= 0 and i < _choices.size():
		_pick(_choices[i])

func reroll() -> bool:
	if not _open or not GameState.use_reroll():
		return false
	var ids: Array = []
	for u in _choices:
		ids.append(str(u.get("id", "")))
	_choices = Progression.roll_run_choices(UpgradeDefs.CHOICES_PER_LEVEL, ids)
	GameState.pending_run_choices = _choices
	_guard = 0.15
	Juice.sfx("reroll")
	_build()
	return true

func _pick(upgrade: Dictionary) -> void:
	GameState.apply_run_upgrade(upgrade)
	Juice.sfx("card_pick")
	Juice.haptic(25)
	chosen.emit(upgrade)
	close()

func close() -> void:
	_open = false
	_choices = []
	TouchInput.clear_sticks()
	_root.visible = false
	for c in _root.get_children():
		c.queue_free()
	get_tree().paused = false
