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
	var sub := UiTheme.body_label(
		"Bank the scrap. Spend it in the Hangar. Run levels reset next deploy." if won
		else "Permanent scrap & Hangar stay. Bag loot and run levels are gone.",
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
		_tile(row, "BAG SCRAP LOST", str(GameState.result_scrap_lost), UiTheme.RUST)
	_tile(row, "RUN LEVEL", "Lv %d" % GameState.result_run_level_reached, UiTheme.TEAL)
	_tile(row, "KILLS", str(GameState.kills), UiTheme.TEXT)
	_tile(row, "THREAT", str(GameState.threat_level), UiTheme.RUST)

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

	if GameState.result_unlocks.size() > 0:
		var ub := VBoxContainer.new()
		ub.add_theme_constant_override("separation", 2)
		c.add_child(ub)
		for u in GameState.result_unlocks:
			var line := UiTheme.body_label("★  " + str(u), 15, UiTheme.TEAL)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ub.add_child(line)

	c.add_child(spacer(false, 4))

	_continue_row = HBoxContainer.new()
	_continue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_continue_row.add_theme_constant_override("separation", 12)
	c.add_child(_continue_row)

	var upgrade := UiTheme.big_button("UPGRADE  ·  Hangar", UiTheme.AMBER, 78, 24)
	upgrade.custom_minimum_size.x = 300
	upgrade.pressed.connect(GameState.go_hangar)
	_continue_row.add_child(upgrade)
	_pulse(upgrade)

	var again := UiTheme.big_button("RUN AGAIN", UiTheme.TEAL, 78, 20)
	again.custom_minimum_size.x = 200
	again.pressed.connect(GameState.go_match)
	_continue_row.add_child(again)

	var menu := UiTheme.big_button("MENU", UiTheme.LINE, 78, 18)
	menu.custom_minimum_size.x = 140
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
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween().set_loops()
	tw.tween_property(b, "scale", Vector2(1.03, 1.03), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
