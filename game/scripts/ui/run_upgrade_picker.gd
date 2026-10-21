extends CanvasLayer

## Mid-run level-up: pick one of 3 upgrade cards (Phase 4). Pauses the tree.
## Cards are big, stacked for one thumb in portrait: rarity colour, name,
## TAGS, the PATH (current rank → next rank effect) and combo hints.
## 2 rerolls per run (UpgradeDefs.REROLLS_PER_RUN).

signal chosen(upgrade: Dictionary)

## Ignore taps for a moment so the thumb that was steering can't mis-pick.
const TAP_GUARD := 0.35
const CARD_H := 176.0

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
	## 8-px grid: 24-px screen margins, cards fill the width (656 at 720).
	var w := minf(vp.x - 2.0 * UiTheme.MARGIN - 16.0, 656.0)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UiTheme.INK, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.custom_minimum_size = Vector2(w, 0)
	center.add_child(v)

	## Header: big amber LEVEL n, one short line under it.
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	v.add_child(hv)
	var title := UiTheme.title_label("LEVEL %d" % _level, UiTheme.T_TITLE_XL, UiTheme.AMBER)
	hv.add_child(title)
	var sub := UiTheme.head_label("PICK ONE", UiTheme.T_H3, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(sub)
	title.pivot_offset = Vector2(w * 0.5, 32)
	title.scale = Vector2(1.3, 1.3)
	title.create_tween().tween_property(title, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 16)
	v.add_child(_cards_box)
	var k := 0
	for u in _choices:
		var cb := _card(u, w)
		_cards_box.add_child(cb)
		## Deal the cards in: staggered pop + fade.
		cb.modulate.a = 0.0
		cb.scale = Vector2(0.92, 0.92)
		var tw := cb.create_tween()
		tw.tween_interval(0.07 * k)
		tw.tween_callback(func() -> void: cb.pivot_offset = cb.size * 0.5)
		tw.set_parallel(true)
		tw.tween_property(cb, "modulate:a", 1.0, 0.14)
		tw.tween_property(cb, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		k += 1

	_reroll_btn = Button.new()
	_reroll_btn.focus_mode = Control.FOCUS_NONE
	_reroll_btn.custom_minimum_size = Vector2(320, 64)
	_reroll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_btn.add_theme_font_override("font", UiTheme.font_button)
	_reroll_btn.add_theme_font_size_override("font_size", UiTheme.T_H2)
	_reroll_btn.icon = IconSet.tex("set_reset", false)
	_reroll_btn.expand_icon = false
	UiTheme.skin_button(_reroll_btn, UiTheme.LINE, 16.0)
	_reroll_btn.pressed.connect(reroll)
	v.add_child(_reroll_btn)
	_refresh_reroll()

func _refresh_reroll() -> void:
	if _reroll_btn == null:
		return
	var left := GameState.run_rerolls_left
	_reroll_btn.text = "REROLL  %d" % left if left > 0 else "NO REROLLS"
	_reroll_btn.disabled = left <= 0

## One big tappable icon-led card (style bible §6.5): 128-px icon well on the
## left, rarity tab + rank pips on top, name, one line of effect, tag chips
## and the combo / recipe line in amber.
func _card(u: Dictionary, w: float) -> Button:
	var rarity := str(u.get("rarity", "common"))
	var evo := bool(u.get("evolution", false))
	var rkey := "evolution" if evo else rarity
	var col := IconSet.rarity_color(rkey)
	var id := str(u.get("id", ""))
	var rank := GameState.run_rank(id)
	var max_rank := int(u.get("max_rank", 1))
	var melee := GameState.weapon.has("melee")
	var hero := GameState.selected_character_id

	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, CARD_H)
	var n := UiTheme.plate("panel_hi" if evo else "panel", 0.0)
	var pr := UiTheme.plate("panel_hi", 0.0, Color(1.12, 1.08, 1.0))
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: _try_pick(u))

	## Painted rarity rim stripe on the left edge.
	var rim := ColorRect.new()
	rim.color = col
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(rim)
	rim.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	rim.offset_left = 4
	rim.offset_right = 12
	rim.offset_top = 8
	rim.offset_bottom = -8

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24
	row.offset_right = -24
	row.offset_top = 24
	row.offset_bottom = -24
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var well := UiTheme.icon_well(IconSet.upgrade(u), "legendary" if evo else rarity, 128)
	well.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(well)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vb)

	## Row 1: rarity tab · (class) ········· rank pips
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)
	top.add_child(UiTheme.rarity_tab("EVOLUTION" if evo else rarity, rkey))
	if u.has("hero"):
		top.add_child(UiTheme.chip("CLASS", UiTheme.AMBER))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)
	if not evo:
		if rank == 0:
			top.add_child(UiTheme.head_label("NEW", UiTheme.T_H3, UiTheme.TEAL))
		var pips := UiTheme.rank_pips(rank, max_rank)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(pips)

	## Name
	var nm := _lbl(str(u.get("name", "?")), UiTheme.T_TITLE, UiTheme.TEXT)
	nm.add_theme_font_override("font", UiTheme.font_display)
	nm.add_theme_constant_override("outline_size", 6)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vb.add_child(nm)

	## One line of effect (the next rank).
	var nl := _lbl(UpgradeDefs.rank_text(u, rank + 1, melee, hero), UiTheme.T_BODY, UiTheme.TEXT)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.max_lines_visible = 2
	nl.custom_minimum_size = Vector2(w - 48.0 - 128.0 - 24.0, 0)
	vb.add_child(nl)

	## Tag chips + combo / recipe line.
	var foot := HFlowContainer.new()
	foot.add_theme_constant_override("h_separation", 8)
	foot.add_theme_constant_override("v_separation", 4)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(foot)
	for t in _tags_for(u, melee):
		if t == "Class":
			continue
		foot.add_child(UiTheme.chip(t, UiTheme.TEXT_DIM))
	var hint := _hint(u, id, hero, evo)
	if hint != "":
		var hl := _lbl(hint, UiTheme.T_SMALL, UiTheme.AMBER)
		hl.add_theme_font_override("font", UiTheme.font_body_bold)
		foot.add_child(hl)
	if evo:
		## Gold glow pulse on evolution cards.
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "self_modulate", Color(1.2, 1.12, 0.9), 0.5)
		tw.tween_property(b, "self_modulate", Color.WHITE, 0.5)
	return b

## Short amber line: the recipe this card leads to, else an owned combo.
func _hint(u: Dictionary, id: String, hero: String, evo: bool) -> String:
	if evo:
		var nd: Array = u.get("needs", [])
		if nd.size() >= 2:
			return "%s + %s" % [RecipeDefs.part_name(str(nd[0])), RecipeDefs.part_name(str(nd[1]))]
		return ""
	var rec := _recipe_hint(id, hero)
	if rec != "":
		return rec
	for cid in u.get("combos", []):
		var cd := UpgradeDefs.get_def(str(cid))
		if cd.is_empty() or (cd.has("hero") and str(cd["hero"]) != hero):
			continue
		if GameState.run_rank(str(cid)) > 0:
			return "COMBO: " + str(cd["name"])
	return ""

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
		return "+ %s = %s%s" % [RecipeDefs.part_name(partner), str(c["name"]), "  READY" if have else ""]
	return "%s max = %s" % [RecipeDefs.part_name(str(nd[0])), str(c["name"])]

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
