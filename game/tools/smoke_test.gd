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
	assert(Progression.hangar_catalog().size() >= 16)
	assert(Progression.hangar_catalog_visible().size() >= 15)
	assert(not Progression.LOADOUT_UI_SHIPPED) ## insurance CTA hidden until loadout UI
	assert(Progression.meta_bonus({"crit_chance": 2}, "crit_chance") > 0.0)
	assert(Progression.roll_run_choices(2).size() == 2)
	assert(Progression.account_level_from_xp(0) == 1)
	assert(EventDefs.catalog().size() >= 4)
	assert(not EventDefs.debug_radio_ping().is_empty())
	assert(PetDefs.all_pets().size() == 3)
	assert(PetDefs.get_pet(PetDefs.NOEL_ID)["ability_id"] == "territorial_rampage")
	assert(PetDefs.get_pet(PetDefs.BENTLEY_ID)["ability_id"] == "talker_finder")
	assert(PetDefs.get_pet(PetDefs.LILLIE_ID)["ability_id"] == "ram_headbutt")
	assert(str(LoadoutStubs.default_pet(PetDefs.NOEL_ID)["name"]) == "Noel")
	## Each hero ships a distinct kit — no shared Scrap SMG cadence.
	var rates: Dictionary = {}
	var mags: Dictionary = {}
	for cid in CharacterDefs.PLAYABLE_IDS:
		var w: Dictionary = LoadoutStubs.weapon_for_character(cid)
		assert(not w.is_empty())
		assert(str(w.get("id", "")) != "")
		assert(float(w.get("fire_rate", 0.0)) > 0.0)
		assert(int(w.get("mag_size", 0)) > 0)
		var rk := "%.2f" % float(w["fire_rate"])
		var mk := str(int(w["mag_size"]))
		assert(not rates.has(rk), "duplicate fire_rate %s on %s" % [rk, cid])
		rates[rk] = cid
		assert(not mags.has(mk), "duplicate mag_size %s on %s" % [mk, cid])
		mags[mk] = cid
	var ash := LoadoutStubs.weapon_for_character(CharacterDefs.ASH_ROOK_ID)
	assert(float(ash["fire_rate"]) < 2.5 and int(ash["mag_size"]) <= 6)
	assert(float(ash.get("splash_radius", 0.0)) > 0.0)
	var cinder := LoadoutStubs.weapon_for_character(CharacterDefs.CINDER_ID)
	assert(float(cinder["fire_rate"]) >= 12.0 and int(cinder["mag_size"]) >= 36)
	var vesper := LoadoutStubs.weapon_for_character(CharacterDefs.VESPER_THORN_ID)
	assert(int(vesper["mag_size"]) <= 4 and float(vesper["damage"]) >= 40.0)
	## Scene loads need GameState autoload — use:
	##   godot4 --headless --path game --quit-after 3
	## for full project boot. This script only validates data stubs.
	print("SMOKE_OK phases_easy=%d phases_medium=%d mounts=%d hangar=%d pets=%d" % [
		easy["phases"].size(), med["phases"].size(), LoadoutStubs.mount_ladder().size(),
		Progression.hangar_catalog().size(), PetDefs.all_pets().size(),
	])
	quit(0)
