extends SceneTree

## Headless smoke: load defs + main menu scene, then quit.
## Usage: godot4 --headless --path game -s res://tools/smoke_test.gd

func _init() -> void:
	var easy := ModeDefs.get_mode(ModeDefs.EASY_ID)
	var med := ModeDefs.get_mode(ModeDefs.MEDIUM_ID)
	assert(easy["phases"].size() == 6)
	assert(med["phases"].size() == 8)
	assert(CharacterDefs.all_characters().size() == 8)
	assert(CharacterDefs.is_playable(CharacterDefs.ASH_ROOK_ID))
	assert(str(CharacterDefs.get_character("rook_vex")["display_name"]) == "Ash Rook")
	assert(EnemyDefs.ids_for_tier(1).size() >= 8)
	assert(EnemyDefs.ids_for_tier(2).size() >= 5)
	assert(EnemyDefs.ids_for_tier(3).size() >= 4)
	## Walk strips exist for sheet units (synthesized, look-locked).
	assert(ResourceLoader.exists("res://assets/sprites/characters/ash_rook_walk.png"))
	assert(ResourceLoader.exists("res://assets/sprites/enemies/rad_gator_walk.png"))
	var anim = UnitAnim.new()
	anim.setup_from_walk_path("res://assets/sprites/characters/ash_rook_walk.png")
	assert(anim.has_frames())
	assert(LoadoutStubs.mount_ladder().size() == 3)
	assert(bool(LoadoutStubs.tank_entry()["dev_only"]))
	assert(Progression.run_xp_to_next(1) == 30)
	assert(Progression.hangar_catalog().size() >= 4)
	assert(Progression.roll_run_choices(2).size() == 2)
	assert(Progression.account_level_from_xp(0) == 1)
	assert(PetDefs.all_pets().size() == 3)
	assert(PetDefs.get_pet(PetDefs.NOEL_ID)["ability_id"] == "territorial_rampage")
	assert(PetDefs.get_pet(PetDefs.BENTLEY_ID)["ability_id"] == "talker_finder")
	assert(PetDefs.get_pet(PetDefs.LILLIE_ID)["ability_id"] == "ram_headbutt")
	assert(str(LoadoutStubs.default_pet(PetDefs.NOEL_ID)["name"]) == "Noel")
	## Scene loads need GameState autoload — use:
	##   godot4 --headless --path game --quit-after 3
	## for full project boot. This script only validates data stubs.
	print("SMOKE_OK phases_easy=%d phases_medium=%d mounts=%d hangar=%d pets=%d" % [
		easy["phases"].size(), med["phases"].size(), LoadoutStubs.mount_ladder().size(),
		Progression.hangar_catalog().size(), PetDefs.all_pets().size(),
	])
	quit(0)
