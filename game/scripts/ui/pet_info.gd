class_name PetInfo
extends RefCounted

const PetGear = preload("res://scripts/data/pet_gear_defs.gd")

## What each pet does, at a glance and in full. Shared by pet select, the
## Kennel and the Workshop:
##   role_line(id)      "Noel · Guard — rampages at enemies that hit you"
##   summary(id, host)  role line + 2-3 key stats with icons + gear + perks
##                      + DETAILS (opens open_details on `host`)
##   open_details(host, id)  full ability text, numbers, cooldown, how to
##                      earn it (mechs) and every bond perk option.
## Everything wraps: nothing here may push a card past a 375-pt screen.

const ROLE := {
	"noel": "rampages at enemies that hit you",
	"bentley": "barks to mark foes, digs up finds",
	"lillie": "rams crowds, stuns and knocks back",
	"mech_hound": "pounces and arcs shock to nearby foes",
	"drone_bat": "strafes from the air and marks foes",
	"rust_mule": "+2 pack room, mortars the thickest crowd",
	"drone_hawk": "strafes from range, marks everything it crosses",
}

## Ability cooldown key per ability id (seconds).
const COOLDOWN_KEY := {
	"talker_finder": "bark_cooldown",
	"ram_headbutt": "ram_cooldown",
	"shock_pounce": "ram_cooldown",
	"strafe_run": "strafe_cooldown",
	"mortar_back": "mortar_cooldown",
}

## Numbers shown in the details panel: [key, label, format].
const DETAIL_ROWS := [
	["bite_damage", "Bite damage", "%d"],
	["bite_cooldown", "Bite every", "%.2fs"],
	["rampage_aoe_damage", "Rampage hit (AoE)", "%d"],
	["rampage_aoe_radius", "Rampage radius", "%d"],
	["rampage_tick", "Rampage hits every", "%.2fs"],
	["rampage_speed_mult", "Rampage speed", "x%.2f"],
	["bark_radius", "Bark radius", "%d"],
	["bark_mark_mult", "Marked foes take", "pct"],
	["bark_mark_time", "Mark lasts", "%.1fs"],
	["bark_distract_sec", "Distract", "%.1fs"],
	["find_cooldown", "Digs up a find every", "%.0fs"],
	["ram_impact_damage", "Impact damage", "%d"],
	["ram_impact_radius", "Impact radius", "%d"],
	["ram_wake_damage", "Charge trail damage", "%d"],
	["ram_range", "Charge range", "%d"],
	["ram_stun", "Stun", "%.2fs"],
	["shock_damage", "Shock arc damage", "%d"],
	["shock_chain", "Shock jumps", "%d"],
	["shock_range", "Shock range", "%d"],
	["strafe_damage", "Shot damage", "%d"],
	["strafe_shots", "Shots per run", "%d"],
	["strafe_range", "Strafe range", "%d"],
	["strafe_mark_mult", "Marked foes take", "pct"],
	["strafe_mark_time", "Mark lasts", "%.1fs"],
	["pack_bonus", "Backpack room", "+%d"],
	["mortar_damage", "Mortar damage (AoE)", "%d"],
	["mortar_radius", "Mortar radius", "%d"],
	["mortar_range", "Mortar range", "%d"],
	["follow_speed", "Move speed", "%d"],
]


static func role_line(id: String) -> String:
	var d := PetDefs.get_pet(id)
	return "%s · %s — %s" % [str(d.get("name", id)), str(d.get("branch", "Pet")),
		str(ROLE.get(id, str(d.get("ability_name", ""))))]


static func cooldown(id: String) -> float:
	var d := PetDefs.get_pet(id)
	var k := str(COOLDOWN_KEY.get(str(d.get("ability_id", "")), ""))
	return float(d.get(k, 0.0)) if k != "" else 0.0


static func _pct(mult: float) -> String:
	return "+%d%%" % int(round((mult - 1.0) * 100.0))


## 2-3 key stats as [icon id, short text].
static func key_stats(id: String) -> Array:
	var d := PetDefs.get_pet(id)
	var cd := cooldown(id)
	match str(d.get("ability_id", "")):
		"territorial_rampage":
			return [["up_aftershock", "Rampage %d AoE" % int(d["rampage_aoe_damage"])],
				["up_harder_hit", "Bite %d" % int(d["bite_damage"])],
				["up_dust_runner", "x%.1f speed" % float(d["rampage_speed_mult"])]]
		"talker_finder":
			return [["up_marked", "Marks %s dmg" % _pct(float(d["bark_mark_mult"]))],
				["hud_timer", "Bark %.0fs" % cd],
				["hud_loot", "Find %.0fs" % float(d["find_cooldown"])]]
		"ram_headbutt":
			return [["up_harder_hit", "Ram %d" % int(d["ram_impact_damage"])],
				["up_quarry_slam", "Stun %.1fs" % float(d["ram_stun"])],
				["hud_timer", "%.1fs" % cd]]
		"shock_pounce":
			return [["up_harder_hit", "Pounce %d" % int(d["ram_impact_damage"])],
				["up_live_wire", "Shock %d x%d" % [int(d["shock_damage"]), int(d["shock_chain"])]],
				["hud_timer", "%.1fs" % cd]]
		"strafe_run":
			return [["up_harder_hit", "%d x %d shots" % [int(d["strafe_damage"]), int(d["strafe_shots"])]],
				["up_marked", "Marks %s dmg" % _pct(float(d["strafe_mark_mult"]))],
				["hud_timer", "%.1fs" % cd]]
		"mortar_back":
			return [["hud_pack", "+%d pack" % int(d["pack_bonus"])],
				["up_aftershock", "Mortar %d AoE" % int(d["mortar_damage"])],
				["hud_timer", "%.0fs" % cd]]
	return [["up_harder_hit", "Bite %d" % int(d.get("bite_damage", 0))]]


static func gear_line(id: String) -> String:
	var it := GameState.pet_gear_item(id)
	return "Gear: " + (str(it.get("name", "")) if not it.is_empty() else "empty slot")


static func perks_line(id: String) -> String:
	var picks: Dictionary = GameState.pet_perks.get(id, {})
	var tree: Array = PetGear.perks_for(id)
	var names: Array = []
	for i in range(PetGear.PERK_LEVELS.size()):
		var k := str(PetGear.PERK_LEVELS[i])
		if picks.has(k) and i < tree.size():
			names.append(str(tree[i][int(picks[k])]["name"]).capitalize())
	var lv := GameState.bond_level(id)
	if names.is_empty():
		return "Bond Lv %d · perks: none yet%s" % [lv, " (pick one in the Kennel)" if not GameState.pending_perks(id).is_empty() else ""]
	return "Bond Lv %d · perks: %s" % [lv, ", ".join(names)]


## Wrapping row of stat chips.
static func stat_chips(id: String) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 14)
	f.add_theme_constant_override("v_separation", 4)
	f.mouse_filter = Control.MOUSE_FILTER_PASS
	for s in key_stats(id):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(IconSet.rect(str(s[0]), 32))
		var l := UiTheme.body_label(str(s[1]), UiTheme.T_SMALL, UiTheme.TEXT, false)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		f.add_child(h)
	return f


## Compact block for a pet card. `host` gets the details overlay.
static func summary(id: String, host: Control, show_gear: bool = true) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "PetInfo_" + id
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	var rl := UiTheme.body_label(role_line(id), UiTheme.T_SMALL, UiTheme.AMBER)
	rl.name = "RoleLine"
	v.add_child(rl)
	v.add_child(stat_chips(id))
	if show_gear and GameState.pet_available(id):
		var gl := UiTheme.body_label("%s  ·  %s" % [gear_line(id), perks_line(id)], UiTheme.T_SMALL, UiTheme.TEXT_DIM)
		gl.name = "GearPerks"
		v.add_child(gl)
	var b := UiTheme.big_button("DETAILS", UiTheme.LINE, 44, 14)
	b.name = "PetDetails_" + id
	b.custom_minimum_size.x = 0
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.mouse_force_pass_scroll_events = true
	b.pressed.connect(func() -> void:
		Juice.sfx("ui_tap")
		open_details(host, id))
	v.add_child(b)
	return v


## Tap-for-details overlay (scrolls on short screens). Returns its root.
static func open_details(host: Control, id: String) -> Control:
	var old := host.get_node_or_null("PetDetailsPopup")
	if old:
		old.queue_free()
	var d := PetDefs.get_pet(id)
	var v := GearUi.overlay(host, UiTheme.TEAL)
	var root: Control = v.get_meta("root")
	root.name = "PetDetailsPopup"
	v.add_child(UiTheme.head_label(str(d.get("name", id)).to_upper(), UiTheme.T_H1, UiTheme.AMBER))
	v.add_child(UiTheme.body_label(role_line(id), UiTheme.T_SMALL, UiTheme.TEXT))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, host.get_viewport_rect().size.y * 0.55)
	v.add_child(sc)
	## Right margin keeps the numbers clear of the scroll bar.
	var mg := MarginContainer.new()
	mg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mg.add_theme_constant_override("margin_right", 28)
	sc.add_child(mg)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 8)
	mg.add_child(lv)
	lv.add_child(UiTheme.head_label(str(d.get("ability_name", "")), UiTheme.T_H3, UiTheme.TEAL))
	lv.add_child(UiTheme.body_label(str(d.get("ability_desc", "")), UiTheme.T_SMALL, UiTheme.TEXT))
	var cd := cooldown(id)
	if cd > 0.0:
		lv.add_child(UiTheme.body_label("Cooldown: %.1fs" % cd, UiTheme.T_SMALL, UiTheme.AMBER))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 2)
	lv.add_child(grid)
	for row in DETAIL_ROWS:
		var k := str(row[0])
		if not d.has(k):
			continue
		var val := float(d[k])
		if is_zero_approx(val):
			continue
		var fmt := str(row[2])
		var txt := _pct(val) if fmt == "pct" else (fmt % (int(val) if fmt.contains("%d") else val))
		var kl := UiTheme.body_label(str(row[1]), UiTheme.T_SMALL, UiTheme.TEXT_DIM, true)
		kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(kl)
		grid.add_child(UiTheme.body_label(txt, UiTheme.T_SMALL, UiTheme.TEXT, false))
	if PetDefs.is_mech(id):
		lv.add_child(UiTheme.head_label("HOW TO GET IT", UiTheme.T_H3, UiTheme.TEAL))
		if GameState.pet_available(id):
			lv.add_child(UiTheme.body_label("Built. Equip it on the survivor screen.", UiTheme.T_SMALL, UiTheme.TEXT))
		else:
			var how := "Blueprint: earned." if GameState.has_blueprint(id) else GameState.blueprint_hint(id)
			lv.add_child(UiTheme.body_label(how, UiTheme.T_SMALL, UiTheme.AMBER))
			lv.add_child(UiTheme.body_label("Then build it in the Workshop: %d Salvage Cores + %d scrap (you have %d cores)." % [
				int(d.get("build_cores", 0)), int(d.get("build_scrap", 0)), GameState.salvage_cores()], UiTheme.T_SMALL, UiTheme.TEXT))
	if GameState.pet_available(id):
		lv.add_child(UiTheme.body_label(gear_line(id), UiTheme.T_SMALL, UiTheme.TEXT))
	lv.add_child(UiTheme.head_label("BOND PERKS (Lv %d)" % GameState.bond_level(id), UiTheme.T_H3, UiTheme.TEAL))
	lv.add_child(UiTheme.body_label("Bond grows as the pet runs with you. At each level pick one of two perks in the Kennel.", UiTheme.T_SMALL, UiTheme.TEXT_DIM))
	var picks: Dictionary = GameState.pet_perks.get(id, {})
	var tree: Array = PetGear.perks_for(id)
	for i in range(mini(tree.size(), PetGear.PERK_LEVELS.size())):
		var plv := str(PetGear.PERK_LEVELS[i])
		for c in range(2):
			var pk: Dictionary = tree[i][c]
			var chosen := picks.has(plv) and int(picks[plv]) == c
			var l := UiTheme.body_label("Lv%s  %s%s — %s" % [plv, str(pk["name"]).capitalize(), "  (picked)" if chosen else "", str(pk["desc"])],
				UiTheme.T_SMALL, UiTheme.AMBER if chosen else UiTheme.TEXT)
			lv.add_child(l)
	if str(d.get("note", "")) != "":
		lv.add_child(UiTheme.body_label(str(d["note"]), UiTheme.T_SMALL, UiTheme.TEXT_DIM))
	var cb := UiTheme.big_button("CLOSE", UiTheme.LINE, 56, 16)
	cb.name = "PetDetailsClose"
	cb.pressed.connect(func() -> void: root.queue_free())
	v.add_child(cb)
	return root
