extends "res://scripts/ui/menu_base.gd"

## Post-extract / wipe results — scrap-first build-up, then Upgrade / Continue.
## In-run levels are shown as flavor; they do not persist.

var _scrap_label: Label
var _continue_row: HBoxContainer


func build(c: VBoxContainer) -> void:
	var won := GameState.extracted
	c.add_theme_constant_override("separation", 10)
	c.add_child(spacer(false, 2))

	var title := UiTheme.title_label("EXTRACTED" if won else "WIPED", 64, Color(0.55, 1.0, 0.6) if won else UiTheme.DANGER)
	c.add_child(title)
	title.pivot_offset = Vector2(360, 40)
	title.scale = Vector2(1.25, 1.25)
	title.create_tween().tween_property(title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	## The hero: idling after a clean extract, down in the dust after a wipe.
	var hid := GameState.selected_character_id
	var hero := StripAnim.make("res://assets/sprites/characters/%s/%s_%s.png" % [hid, hid, "idle" if won else "death"], 170, 8.0 if won else 10.0)
	hero.loop = won
	hero.end_frame = 6
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(hero)
	var sub := UiTheme.body_label(
		"Bank the scrap. Spend it in the Hangar. Run levels reset next deploy." if won
		else "You kept %d%% of your bag. Hangar upgrades stay; run levels are gone." % int(round(float(GameState.get_mode().get("death_keep", 0.1)) * 100.0)),
		17
	)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(sub)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	c.add_child(row)
	if won:
		_tile(row, "SCRAP BANKED", "+%d" % GameState.result_scrap_banked, UiTheme.AMBER)
	else:
		_tile(row, "KEPT", "+%d" % GameState.result_scrap_banked, UiTheme.AMBER)
		_tile(row, "LOST", str(GameState.result_scrap_lost), UiTheme.RUST)
	_tile(row, "RUN LEVEL", "Lv %d" % GameState.result_run_level_reached, UiTheme.TEAL)
	_tile(row, "KILLS", str(GameState.kills), UiTheme.TEXT)
	_tile(row, "LOOT", "×%.1f" % GameState.loot_mult, UiTheme.AMBER)

	## Scrap total readout
	var scrap_card := card(UiTheme.AMBER, Color(0.12, 0.09, 0.065, 0.92))
	c.add_child(scrap_card)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	scrap_card.add_child(sv)
	sv.add_child(UiTheme.body_label("BANKED SCRAP", 14, UiTheme.AMBER, false))
	_scrap_label = UiTheme.title_label("%d" % GameState.result_scrap_before, 48, UiTheme.AMBER)
	sv.add_child(_scrap_label)
	var soft := UiTheme.body_label(
		"Account prestige Lv %d  ·  +%d XP (gates Hangar tiers only)" % [
			GameState.account_level, GameState.account_xp_this_run,
		],
		13, UiTheme.TEXT_DIM
	)
	soft.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(soft)

	## Wipe kept/lost
	var note := ""
	if won:
		note = "In-run loadout picks are gone. Spend scrap on permanent Hangar upgrades."
		if GameState.payout_this_run >= GameState.best_payout and GameState.payout_this_run > 0:
			note = "NEW BEST PAYOUT ·  " + note
	else:
		var kept := "scrap %d, Hangar ranks, Account Lv %d, insured: %s" % [
			GameState.account_scrap,
			GameState.account_level,
			", ".join(GameState.result_kept_keys) if GameState.result_kept_keys.size() else "(none)",
		]
		var lost := "bag scrap %d, run Lv %d picks, uninsured: %s" % [
			GameState.result_scrap_lost,
			GameState.result_run_level_reached,
			", ".join(GameState.result_lost_keys) if GameState.result_lost_keys.size() else "(none)",
		]
		note = "KEPT: %s\nLOST: %s" % [kept, lost]
	var nl := UiTheme.body_label(note, 14, UiTheme.TEXT_DIM)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(nl)

	## Gear: what reached the stash (extract) or was lost (death).
	var gear_list: Array = GameState.result_found if won else GameState.result_lost_items
	if not gear_list.is_empty():
		var gb := VBoxContainer.new()
		gb.add_theme_constant_override("separation", 1)
		c.add_child(gb)
		var head := UiTheme.body_label("GEAR TO STASH" if won else "GEAR LOST", 15, UiTheme.AMBER if won else UiTheme.RUST, false)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gb.add_child(head)
		for i in range(mini(gear_list.size(), 6)):
			var it: Dictionary = gear_list[i]
			var r := str(it.get("rarity", "common"))
			var gl := UiTheme.body_label("%s  (%s)" % [str(it.get("name", "item")), GearDefs.RARITY_NAME.get(r, r)], 14, GearDefs.RARITY_COLOR.get(r, UiTheme.TEXT), false)
			gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gb.add_child(gl)
		if gear_list.size() > 6:
			var more := UiTheme.body_label("+%d more" % (gear_list.size() - 6), 13, UiTheme.TEXT_DIM, false)
			more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gb.add_child(more)
	if won and GameState.result_salvaged > 0:
		var sl := UiTheme.body_label("Stash full — extras salvaged for %d scrap" % GameState.result_salvaged, 13, UiTheme.TEXT_DIM)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(sl)

	if GameState.result_unlocks.size() > 0:
		var ub := VBoxContainer.new()
		ub.add_theme_constant_override("separation", 2)
		c.add_child(ub)
		for u in GameState.result_unlocks:
			var line := UiTheme.body_label("★  " + str(u), 15, UiTheme.TEAL)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ub.add_child(line)

	c.add_child(spacer(true, 4))

	## Actions sit at the bottom, under the thumb.
	var upgrade := UiTheme.big_button("UPGRADE  ·  HANGAR", UiTheme.AMBER, 84, 30)
	upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade.pressed.connect(GameState.go_hangar)
	c.add_child(upgrade)
	_pulse(upgrade)

	if won and not GameState.result_found.is_empty():
		var eqg := UiTheme.big_button("EQUIP NEW GEAR", UiTheme.TEAL, 64, 22)
		eqg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eqg.pressed.connect(func() -> void: GameState.go_loadout("hangar"))
		c.add_child(eqg)

	_continue_row = HBoxContainer.new()
	_continue_row.add_theme_constant_override("separation", 12)
	c.add_child(_continue_row)

	var again := UiTheme.big_button("RUN AGAIN", UiTheme.TEAL, 68, 22)
	again.custom_minimum_size.x = 0
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(GameState.go_match)
	_continue_row.add_child(again)

	var menu := UiTheme.big_button("MENU", UiTheme.LINE, 68, 22)
	menu.custom_minimum_size.x = 0
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.size_flags_stretch_ratio = 0.6
	menu.pressed.connect(GameState.go_main_menu)
	_continue_row.add_child(menu)

	_animate_scrap()


func _animate_scrap() -> void:
	var from_v := GameState.result_scrap_before
	var to_v := GameState.account_scrap
	if to_v <= from_v:
		_scrap_label.text = str(to_v)
		return
	var steps := mini(24, to_v - from_v)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		_scrap_label.text = str(int(lerpf(float(from_v), float(to_v), t)))
		await get_tree().create_timer(0.03).timeout
	_scrap_label.text = str(to_v)


func _tile(parent: Control, k: String, v: String, col: Color) -> void:
	var p := card(UiTheme.LINE, Color(0.12, 0.09, 0.065, 0.9))
	p.custom_minimum_size = Vector2(120, 0)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(vb)
	var val := UiTheme.title_label(v, 28, col)
	vb.add_child(val)
	var key := UiTheme.body_label(k, 11, UiTheme.TEXT_DIM)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(key)
	parent.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_interval(0.05 * parent.get_child_count())
	tw.tween_property(p, "modulate:a", 1.0, 0.18)


func _pulse(b: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(b):
		return
	var tw := b.create_tween().set_loops()
	tw.tween_property(b, "self_modulate", Color(1.12, 1.08, 1.0), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "self_modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)
