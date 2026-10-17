extends Control

const CharacterDefs = preload("res://scripts/data/character_defs.gd")
const LoadoutStubs = preload("res://scripts/data/loadout_stubs.gd")

@onready var rook_btn: Button = %RookButton
@onready var cinder_btn: Button = %CinderButton
@onready var details: RichTextLabel = %Details
@onready var loadout_label: Label = %LoadoutLabel


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	var c := GameState.get_character()
	var perk_lines := ""
	for p in c["perks"]:
		perk_lines += "• [b]%s[/b] — %s\n" % [p["name"], p["desc"]]
	details.clear()
	details.append_text("[b]%s[/b]\n%s\n\n%s\nStat tweaks: move ×%.2f · dmg ×%.2f · HP +%d" % [
		c["display_name"],
		c["fantasy"],
		perk_lines,
		float(c["move_speed_mult"]),
		float(c["damage_mult"]),
		int(c["max_hp_bonus"]),
	])
	rook_btn.text = "Rook Vex" + (" ✓" if GameState.selected_character_id == CharacterDefs.ROOK_ID else "")
	cinder_btn.text = "Sister Cinder" + (" ✓" if GameState.selected_character_id == CharacterDefs.CINDER_ID else "")
	var mount := LoadoutStubs.default_mount(GameState.mount_unlock_tier)
	var tank := LoadoutStubs.tank_entry()
	loadout_label.text = "Loadout stubs → Armor: %s · Weapon: %s · Pet: %s · Mount: %s (usable)\nTank: %s (hidden from players; flag=%s)" % [
		GameState.armor.get("set_name", "—") if not GameState.armor.is_empty() else LoadoutStubs.default_armor()["set_name"],
		LoadoutStubs.default_weapon()["name"],
		LoadoutStubs.default_pet()["name"],
		mount["name"],
		tank["name"],
		str(GameState.tank_dev_flag),
	]


func _on_rook_pressed() -> void:
	GameState.selected_character_id = CharacterDefs.ROOK_ID
	_refresh()


func _on_cinder_pressed() -> void:
	GameState.selected_character_id = CharacterDefs.CINDER_ID
	_refresh()


func _on_deploy_pressed() -> void:
	GameState.go_match()


func _on_back_pressed() -> void:
	GameState.go_mode_select()
