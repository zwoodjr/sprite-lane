extends RefCounted

## Front-door routing (P2, mobile review items 4 and 14):
##  - First launch on a brand-new profile goes straight into the campaign
##    prologue (Mayday) instead of the menu. Once routed, or on any save that
##    already has progress, the normal menu shows from then on.
##  - Quick Deploy: one tap from the menu / hangar into a Wander run with the
##    last-used hero, gear loadout, pet and tier.
## Persisted through GameState.settings so no save-format change is needed.

const OPENING_LEVEL := "p0_mayday"
const SEEN_KEY := "opening_seen"

## Only the boot instance of the main menu may route (tests and tools build
## the menu themselves and must never be thrown into a level).
static var _boot_checked: bool = false


## True when the profile has never played anything (no runs, no story, no XP).
static func is_fresh_profile() -> bool:
	var done: Dictionary = GameState.campaign.get("done", {})
	return GameState.total_runs == 0 and GameState.successful_extracts == 0 \
		and GameState.account_xp == 0 and not GameState.tutorial_done and done.is_empty()


## Where a launch should land: the opening level id, or "" for the menu.
## Marks the opening as seen either way, so it can only ever happen once and
## existing saves are never re-routed.
static func first_launch_target() -> String:
	if bool(GameState.settings.get(SEEN_KEY, false)):
		return ""
	var fresh := is_fresh_profile()
	GameState.set_setting(SEEN_KEY, true)
	if fresh and CampaignDefs.is_playable(OPENING_LEVEL):
		return OPENING_LEVEL
	return ""


## Called by the main menu as it opens. Returns true when it sent the player
## into the opening (the menu should not build).
static func route_boot(menu: Node) -> bool:
	if _boot_checked:
		return false
	_boot_checked = true
	if menu.get_tree().current_scene != menu:
		return false
	var target := first_launch_target()
	if target == "":
		return false
	GameState.go_campaign_level.call_deferred(target)
	return true


## Quick Deploy is offered once the player has deployed at least once.
static func can_quick_deploy() -> bool:
	return GameState.total_runs > 0


## The tier a Quick Deploy would use (the last one picked, if still unlocked).
static func quick_mode_id() -> String:
	var m: Dictionary = GameState.get_mode()
	if not GameState.is_tier_unlocked(int(m.get("tier", 1))):
		return ModeDefs.HAZE_ID
	return str(m.get("id", ModeDefs.HAZE_ID))


## "ROOK · NOEL · HAZE" for the button's sub-line.
static func quick_summary() -> String:
	var hero := str(GameState.get_character().get("display_name", "")).to_upper()
	var pet_id := GameState.selected_pet_id if GameState.pet_available(GameState.selected_pet_id) else PetDefs.default_id()
	var pet := str(PetDefs.get_pet(pet_id).get("name", "")).to_upper()
	var mode := str(ModeDefs.get_mode(quick_mode_id()).get("display_name", "")).to_upper()
	var parts: Array[String] = []
	for p in [hero, pet, mode]:
		if p != "":
			parts.append(p)
	return " · ".join(parts)


## Everything a run needs, without changing scene (tests call this alone).
static func prepare_quick_deploy() -> void:
	GameState.leave_campaign_run()
	GameState.play_mode = "wander"
	GameState.selected_mode_id = quick_mode_id()
	if not GameState.dev_tools:
		GameState.fast_timers = false
	if not GameState.pet_available(GameState.selected_pet_id):
		GameState.selected_pet_id = PetDefs.default_id()
	## Loadout (gear, kit, tonics) is per hero and already saved; re-copy it.
	GameState.reset_loadout_to_defaults()


## Fresh save: the very first PLAY skips mode / hero / loadout and drops the
## default survivor into Haze (the tutorial runs in the match).
static func is_first_wander() -> bool:
	return GameState.total_runs == 0 and GameState.successful_extracts == 0


static func first_run_deploy() -> void:
	GameState.leave_campaign_run()
	GameState.play_mode = "wander"
	GameState.selected_mode_id = ModeDefs.HAZE_ID
	if not GameState.dev_tools:
		GameState.fast_timers = false
	if not GameState.pet_available(GameState.selected_pet_id):
		GameState.selected_pet_id = PetDefs.default_id()
	GameState.reset_loadout_to_defaults()
	GameState.go_match()


static func quick_deploy() -> void:
	prepare_quick_deploy()
	GameState.go_match()


## Painted QUICK DEPLOY button: title plus the hero · pet · tier it will use.
static func quick_button(height: float = UiTheme.MIN_TOUCH) -> Button:
	var b := UiTheme.big_button("", UiTheme.TEAL, height, 24)
	b.name = "QuickDeploy"
	b.custom_minimum_size.x = 0
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var t := UiTheme.head_label("QUICK DEPLOY", UiTheme.T_H2, UiTheme.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UiTheme.head_label(quick_summary(), UiTheme.T_H3, Color(0.85, 1.0, 0.92))
	s.name = "Summary"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.clip_text = true
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(s)
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 96.0 * UiTheme.text_scale)
	b.pressed.connect(quick_deploy)
	return b


## Main-menu headline goal: the cheapest Hangar upgrade still to buy among the
## shared camp upgrades, the backpack and this survivor's station.
## Returns {} when everything there is maxed.
static func headline_goal() -> Dictionary:
	var best := {}
	var ids: Array = HangarDefs.ids_for("shared") + ["backpack", HangarDefs.station_id(GameState.selected_character_id)]
	for id in ids:
		var cost := GameState.camp_cost(str(id))
		if cost < 0:
			continue
		if best.is_empty() or cost < int(best["cost"]):
			var rk := GameState.camp_rank(str(id))
			best = {"id": str(id), "cost": cost, "rank": rk + 1, "name": HangarDefs.display_name(str(id)),
				"text": HangarDefs.rank_text(str(id), rk + 1)}
	return best


## Tappable NEXT UPGRADE card: name + effect, scrap bar toward its price.
static func goal_card() -> Control:
	var g := headline_goal()
	if g.is_empty():
		return null
	var b := Button.new()
	b.name = "GoalCard"
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 88)
	var pl := UiTheme.plate("inset", 12.0)
	b.add_theme_stylebox_override("normal", pl)
	b.add_theme_stylebox_override("hover", pl)
	b.add_theme_stylebox_override("pressed", UiTheme.plate("inset", 12.0, Color(1.15, 1.1, 1.0)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(GameState.go_hangar)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14
	h.offset_top = 8
	h.offset_bottom = -8
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var id := str(g["id"])
	var icon_id := "camp_" + id if not id.begins_with("station_") else IconSet.ability(GameState.selected_character_id, "a")
	h.add_child(IconSet.rect(icon_id, 64))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var have := GameState.account_scrap
	var cost := int(g["cost"])
	var ready := have >= cost
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var t := UiTheme.head_label(("READY: " if ready else "NEXT: ") + str(g["name"]).to_upper(), UiTheme.T_H3, UiTheme.AMBER if ready else UiTheme.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(t)
	var n := UiTheme.pixel_label("%d/%d" % [mini(have, cost), cost], UiTheme.PX_S, UiTheme.AMBER)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(n)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(float(have) / maxf(float(cost), 1.0), 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.skin_bar(bar, UiTheme.AMBER if ready else UiTheme.TEAL)
	v.add_child(bar)
	var d := UiTheme.body_label(str(g["text"]), UiTheme.T_SMALL, UiTheme.TEXT_DIM, false)
	d.clip_text = true
	d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	return b
