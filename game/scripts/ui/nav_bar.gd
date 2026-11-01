class_name NavBar
extends RefCounted

## The one bottom tab bar on every out-of-run screen:
##   STASH · HANGAR · [ PLAY ] · KENNEL · CREW
## STASH / HANGAR / KENNEL / CREW open the Hangar on that tab (or switch tabs
## in place when the Hangar is already open); PLAY is one tap into a run:
## the first run on a fresh save, otherwise the last hero / pet / tier.

const MenuFlow = preload("res://scripts/ui/menu_flow.gd")
const ITEMS := [
	["stash", "STASH", "tab_stash"],
	["camp", "HANGAR", "tab_camp"],
	["play", "PLAY", ""],
	["kennel", "KENNEL", "tab_kennel"],
	["survivors", "CREW", "tab_crew"],
]
const HEIGHT := 96.0


## `active` = "play" (lobby), a hangar tab id, or "" (none lit). `hangar` is
## the open Hangar screen, if any (tabs switch in place).
static func make(active: String = "", hangar: Node = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.name = "NavBar"
	h.add_theme_constant_override("separation", 6)
	for it in ITEMS:
		var id := str(it[0])
		var b: Button
		if id == "play":
			b = UiTheme.big_button("PLAY", UiTheme.AMBER, HEIGHT, 30)
			b.size_flags_stretch_ratio = 1.5
			b.pressed.connect(play)
		else:
			var on := active == id or (active == "brew" and id == "camp")
			b = UiTheme.big_button(str(it[1]), UiTheme.AMBER if on else UiTheme.LINE, HEIGHT, 14)
			b.icon = IconSet.tex(str(it[2]), true)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.expand_icon = false
			b.clip_text = true
			if hangar != null and hangar.has_method("show_tab"):
				b.pressed.connect(func() -> void: hangar.call("show_tab", id))
			else:
				b.pressed.connect(open_tab.bind(id))
		b.name = "Nav_" + id
		b.custom_minimum_size.x = 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	return h


## Hangar on a tab, from anywhere.
static func open_tab(tab: String) -> void:
	GameState.hangar_tab = tab
	GameState.go_hangar()


## One tap into a run.
static func play() -> void:
	if MenuFlow.is_first_wander():
		MenuFlow.first_run_deploy()
	elif MenuFlow.can_quick_deploy():
		MenuFlow.quick_deploy()
	else:
		GameState.go_mode_choice()


## Lit tab for a Hangar tab id.
static func set_active(bar: Node, tab: String) -> void:
	if bar == null:
		return
	for it in ITEMS:
		var id := str(it[0])
		if id == "play":
			continue
		var b := bar.get_node_or_null("Nav_" + id) as Button
		if b:
			var on := tab == id or (tab == "brew" and id == "camp")
			UiTheme.skin_button(b, UiTheme.AMBER if on else UiTheme.LINE, 12.0)
