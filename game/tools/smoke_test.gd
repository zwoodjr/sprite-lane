extends SceneTree

## Headless smoke: load defs + main menu scene, then quit.
## Usage: godot4 --headless --path game -s res://tools/smoke_test.gd

const ModeDefs = preload("res://scripts/data/mode_defs.gd")
const CharacterDefs = preload("res://scripts/data/character_defs.gd")
const LoadoutStubs = preload("res://scripts/data/loadout_stubs.gd")
const Progression = preload("res://scripts/data/progression.gd")


func _init() -> void:
	var easy := ModeDefs.get_mode(ModeDefs.EASY_ID)
	var med := ModeDefs.get_mode(ModeDefs.MEDIUM_ID)
	assert(easy["phases"].size() == 6)
	assert(med["phases"].size() == 8)
	assert(CharacterDefs.all_characters().size() == 2)
	assert(LoadoutStubs.mount_ladder().size() == 3)
	assert(bool(LoadoutStubs.tank_entry()["dev_only"]))
	assert(Progression.run_xp_to_next(1) == 30)
	assert(Progression.hangar_catalog().size() >= 4)
	assert(Progression.roll_run_choices(2).size() == 2)
	assert(Progression.account_level_from_xp(0) == 1)
	## Scene loads need GameState autoload — use:
	##   godot4 --headless --path game --quit-after 3
	## for full project boot. This script only validates data stubs.
	print("SMOKE_OK phases_easy=%d phases_medium=%d mounts=%d hangar=%d" % [
		easy["phases"].size(), med["phases"].size(), LoadoutStubs.mount_ladder().size(),
		Progression.hangar_catalog().size(),
	])
	quit(0)
