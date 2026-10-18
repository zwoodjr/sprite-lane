class_name QuestDefs
extends RefCounted

## Hangar logbook stubs (Master Brief Part 8): dailies, survivor stories, camp milestones.


static func daily_pool() -> Array[Dictionary]:
	return [
		{"id": "daily_extract_haze", "name": "Clear the Haze", "desc": "Extract on Haze", "type": "extract_tier", "tier": 1, "reward_scrap": 40},
		{"id": "daily_extract_drift", "name": "Ride the Drift", "desc": "Extract on Drift", "type": "extract_tier", "tier": 2, "reward_scrap": 60},
		{"id": "daily_extract_smog", "name": "Through the Smog", "desc": "Extract on Smog", "type": "extract_tier", "tier": 3, "reward_scrap": 90},
		{"id": "daily_kills_50", "name": "Dust Sweep", "desc": "Kill 50 enemies in one run", "type": "kills_run", "count": 50, "reward_scrap": 50},
		{"id": "daily_wraiths", "name": "Ash Sweep", "desc": "Kill 20 Ash Wraiths (any run)", "type": "kill_kind", "kind": "ash_wraiths", "count": 20, "reward_scrap": 55},
		{"id": "daily_scrap_200", "name": "Magnet Run", "desc": "Bank 200 bag scrap in one extract", "type": "bag_scrap", "count": 200, "reward_scrap": 45},
	]


static func roll_dailies(count: int = 3, seed_key: int = 0) -> Array[Dictionary]:
	var pool := daily_pool()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_key if seed_key != 0 else int(Time.get_unix_time_from_system() / 86400.0)
	pool.shuffle()
	## Deterministic shuffle via rng
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array[Dictionary] = []
	for i in range(mini(count, pool.size())):
		out.append(pool[i].duplicate(true))
	return out


static func survivor_story(char_id: String) -> Dictionary:
	var names := {
		"ash_rook": "Ash Rook",
		"vesper_thorn": "Vesper Thorn",
		"pebble": "Pebble",
		"bolt_juno": "Bolt Juno",
		"sister_cinder": "Sister Cinder",
		"quill_marrow": "Quill Marrow",
		"nyx_caldera": "Nyx Caldera",
		"helm_wisp": "Helm Wisp",
	}
	var legendary: Dictionary = {}
	var raw: Variant = GearDefs.LEGENDARY_WEAPONS.get(char_id, {})
	if typeof(raw) == TYPE_DICTIONARY:
		legendary = raw
	var steps: Array[Dictionary] = []
	for i in range(5):
		steps.append({
			"step": i + 1,
			"desc": "%s story %d/5" % [names.get(char_id, char_id), i + 1],
			"done": false,
		})
	return {
		"id": "story_%s" % char_id,
		"survivor": char_id,
		"name": "%s's Story" % names.get(char_id, char_id),
		"steps": steps,
		"reward_weapon": legendary,
	}


static func all_survivor_stories() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in CharacterDefs.PLAYABLE_IDS:
		out.append(survivor_story(id))
	return out


static func camp_milestones() -> Array[Dictionary]:
	return [
		{"id": "max_generator", "name": "Lights On", "desc": "Max the Generator", "type": "meta_rank", "meta_id": "generator", "rank": 5, "reward": "hangar_lights"},
		{"id": "first_dread", "name": "Naught Buster", "desc": "First Dread Naught kill", "type": "boss_kill", "boss": "dread_naught", "reward": "trophy_dread"},
		{"id": "first_overlord", "name": "Overlord Down", "desc": "First Mutant Overlord kill", "type": "boss_kill", "boss": "mutant_overlord", "reward": "trophy_overlord"},
		{"id": "extract_blackout", "name": "Through Blackout", "desc": "Extract on Blackout", "type": "extract_tier", "tier": 8, "reward": "trophy_blackout"},
	]
