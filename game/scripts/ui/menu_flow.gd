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
