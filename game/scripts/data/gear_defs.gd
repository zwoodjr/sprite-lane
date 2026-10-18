class_name GearDefs
extends RefCounted

## Stash / gear catalog stubs (Master Brief Part 7). Shared across survivors.


const RARITIES := ["common", "rare", "epic", "legendary"]
const ARMOR_SLOTS := ["head", "chest", "shoulders", "legs", "hands", "boots"]
const ACCESSORY_SLOTS := ["charm", "vial", "patch"]

const GENERAL_SETS := {
	"plague_doctor": {
		"name": "Plague Doctor",
		"bonuses": {
			2: "resist_poison",
			4: "heal_pickup_boost",
			6: "kill_heal_chance",
		},
	},
	"demolition_crew": {
		"name": "Demolition Crew",
		"bonuses": {2: "knockback_resist", 4: "dash_damage", 6: "kill_blast"},
	},
	"night_runner": {
		"name": "Night Runner",
		"bonuses": {2: "move_speed", 4: "dash_cd", 6: "dash_stealth"},
	},
	"field_salvager": {
		"name": "Field Salvager",
		"bonuses": {2: "scrap_find", 4: "rare_odds", 6: "extract_set_bonus"},
	},
}

const SURVIVOR_SETS := {
	"ash_rook": {"name": "Foreman's Kit", "bonuses": {2: "rush_cd", 3: "second_charge"}},
	"vesper_thorn": {"name": "Bell Ringer's Shroud", "bonuses": {2: "vial_duration", 3: "ghost_round"}},
	"pebble": {"name": "Quarry Plate", "bonuses": {2: "max_hp", 3: "stand_fast"}},
	"bolt_juno": {"name": "Lineman's Rig", "bonuses": {2: "overload_stun", 3: "static_field"}},
	"sister_cinder": {"name": "Cathedral Vestments", "bonuses": {2: "heal_power", 3: "last_rites"}},
	"quill_marrow": {"name": "Surgeon's Coat", "bonuses": {2: "weak_spot", 3: "autopsy"}},
	"nyx_caldera": {"name": "Smuggler's Wraps", "bonuses": {2: "dash_cd", 3: "shadow_step"}},
	"helm_wisp": {"name": "Flight Crew Gear", "bonuses": {2: "drone_firerate", 3: "air_support"}},
}

const LEGENDARY_WEAPONS := {
	"ash_rook": {"id": "last_shift", "name": "Last Shift", "type": "scrap_launcher", "desc": "Shots leave burning rubble."},
	"vesper_thorn": {"id": "bellwether", "name": "Bellwether", "type": "rifle", "desc": "Kill shot slows every on-screen enemy 2s."},
	"pebble": {"id": "gravedigger", "name": "Gravedigger", "type": "maul", "desc": "Kills stack damage until you take a hit."},
	"bolt_juno": {"id": "live_line", "name": "Live Line", "type": "gauntlet", "desc": "Every third punch arcs lightning."},
	"sister_cinder": {"id": "censer", "name": "Censer", "type": "rifle", "desc": "Hits leave healing smoke."},
	"quill_marrow": {"id": "bonesaw", "name": "Bonesaw", "type": "bayonet_smg", "desc": "Back / weak-spot shots never miss."},
	"nyx_caldera": {"id": "twin_debts", "name": "Twin Debts", "type": "blades", "desc": "Kill marks nearest foe for a crit."},
	"helm_wisp": {"id": "mayday", "name": "Mayday", "type": "sidearm", "desc": "Low HP: drone shields you 5s."},
}

const WEAPON_MODS := {
	"ranged": [
		{"id": "scope", "name": "Scope", "desc": "More range"},
		{"id": "extended_mag", "name": "Extended Mag", "desc": "More shots per reload"},
		{"id": "barrel", "name": "Barrel", "desc": "Tighter spread"},
		{"id": "stock", "name": "Stock", "desc": "Less recoil"},
	],
	"melee": [
		{"id": "weighted_head", "name": "Weighted Head", "desc": "More damage and knockback"},
		{"id": "grip", "name": "Grip", "desc": "Faster swings"},
		{"id": "edge", "name": "Edge", "desc": "Wider arc"},
		{"id": "wraps", "name": "Wraps", "desc": "Lifesteal on hit"},
	],
	"universal": [
		{"id": "coat_poison", "name": "Poison Coat", "desc": "Poison coating"},
		{"id": "coat_fire", "name": "Fire Coat", "desc": "Fire coating"},
		{"id": "coat_shock", "name": "Shock Coat", "desc": "Shock coating"},
		{"id": "coat_frost", "name": "Frost Coat", "desc": "Frost coating"},
	],
}


static func stash_slot_costs() -> Array[int]:
	## Start 20; +10 for 300, then 600, then 1000.
	return [300, 600, 1000]


static func make_loose_armor(slot: String, rarity: String) -> Dictionary:
	var idx := RARITIES.find(rarity)
	if idx < 0:
		idx = 0
	return {
		"kind": "armor",
		"slot": slot,
		"rarity": rarity,
		"name": "%s %s" % [rarity.capitalize(), slot.capitalize()],
		"set": "",
		"stats": {"armor": 2 + idx * 3, "hp": idx * 5},
	}


static func elite_reward_bundle() -> Dictionary:
	## Cyber Juggernaut: Rare-or-better gear + weapon mod; 10% set piece.
	var rarity := "rare" if randf() > 0.35 else ("epic" if randf() > 0.5 else "legendary")
	var slot: String = ARMOR_SLOTS[randi() % ARMOR_SLOTS.size()]
	var piece := make_loose_armor(slot, rarity)
	if rarity in ["epic", "legendary"] and randf() < 0.10:
		piece["set"] = "field_salvager"
		piece["name"] = "Salvager %s" % slot.capitalize()
	return {
		"gear": [piece],
		"mods": [{"id": "scope", "name": "Scope", "rarity": rarity}],
		"materials": {},
	}


static func boss_reward_bundle(boss_id: String) -> Dictionary:
	var piece := make_loose_armor(ARMOR_SLOTS[randi() % ARMOR_SLOTS.size()], "epic")
	piece["set"] = "plague_doctor" if boss_id == "mutant_overlord" else "demolition_crew"
	var mats := {}
	if boss_id == "dread_naught":
		mats["salvage_cores"] = 1
	elif boss_id == "mutant_overlord":
		mats["dust_hearts"] = 1
	var legendary := {}
	if randf() < 0.08:
		legendary = LEGENDARY_WEAPONS.values()[randi() % LEGENDARY_WEAPONS.size()]
	return {"gear": [piece], "mods": [], "materials": mats, "legendary": legendary}
