class_name GearDefs
extends RefCounted

## Gear and weapons (brief Part 7) + elite / boss rewards (Part 3).
## Items are plain JSON-safe dictionaries kept in GameState.stash:
##   {uid, kind: armor|accessory|weapon|mod, slot, rarity, name, icon,
##    stats: {stat: value}, set: "", hero: "", variant: "", legendary: "",
##    mod: "", coat: "", needs_heart: bool, charged: bool}
## Every tuning number lives here.

const RARITIES: Array = ["common", "rare", "epic", "legendary"]
const RARITY_NAME := {"common": "Common", "rare": "Rare", "epic": "Epic", "legendary": "Legendary"}
const RARITY_COLOR := {
	"common": Color(0.78, 0.78, 0.74), "rare": Color(0.38, 0.68, 1.0),
	"epic": Color(0.72, 0.45, 1.0), "legendary": Color(1.0, 0.72, 0.25),
}
## Stat strength per rarity (× the base values below).
const RARITY_MULT := {"common": 1.0, "rare": 1.6, "epic": 2.2, "legendary": 2.8}
## Number of rolled stats per rarity (Legendary adds a small extra one).
const RARITY_STATS := {"common": 1, "rare": 2, "epic": 2, "legendary": 3}
## Scrap you get for salvaging an item.
const SALVAGE := {"common": 12, "rare": 35, "epic": 90, "legendary": 220}

const ARMOR_SLOTS: Array = ["head", "chest", "shoulders", "legs", "hands", "boots"]
const ACCESSORY_SLOTS: Array = ["charm", "vial", "patch"]
## Every loadout slot (per survivor) in screen order.
const LOADOUT_SLOTS: Array = ["weapon", "mod1", "mod2", "head", "chest", "shoulders", "legs", "hands", "boots", "charm", "vial", "patch"]
const SLOT_NAME := {
	"weapon": "Weapon", "mod1": "Mod", "mod2": "Mod", "head": "Head", "chest": "Chest",
	"shoulders": "Shoulders", "legs": "Legs", "hands": "Hands", "boots": "Boots",
	"charm": "Charm", "vial": "Vial", "patch": "Patch",
}
const SLOT_ICON := {
	"head": "res://assets/sprites/icons/gear/icon_slot_head.png",
	"chest": "res://assets/sprites/icons/gear/icon_slot_chest.png",
	"shoulders": "res://assets/sprites/icons/gear/icon_slot_shoulders.png",
	"legs": "res://assets/sprites/icons/gear/icon_slot_legs.png",
	"hands": "res://assets/sprites/icons/gear/icon_slot_hands.png",
	"boots": "res://assets/sprites/icons/gear/icon_slot_boots.png",
	"charm": "res://assets/sprites/icons/gear/icon_acc_charm.png",
	"vial": "res://assets/sprites/icons/gear/icon_acc_vial.png",
	"patch": "res://assets/sprites/icons/gear/icon_acc_patch.png",
}
const SLOT_NOUN := {
	"head": ["Hood", "Visor", "Cap"], "chest": ["Vest", "Coat", "Plate"],
	"shoulders": ["Pauldrons", "Mantle", "Spaulders"], "legs": ["Greaves", "Trousers", "Leggings"],
	"hands": ["Gloves", "Grips", "Wraps"], "boots": ["Boots", "Treads", "Striders"],
	"charm": ["Rabbit's Foot", "Lucky Bottle Cap", "Dog Tags"],
	"vial": ["Tonic Vial", "Dust Draught", "Plague Ward"],
	"patch": ["Squad Patch", "Hospital Cross", "Scrap Union Badge"],
}
const RARITY_ADJ := {"common": ["Worn", "Patched", "Plain"], "rare": ["Sturdy", "Reinforced", "Fine"],
	"epic": ["Masterwork", "Wasteland", "Veteran's"], "legendary": ["Mythic", "Storied", "Last-Light"]}

## Stats: base value at Common (× RARITY_MULT). What each means:
##   max_hp +HP · damage +% damage · resist % less damage taken · move +% speed
##   dash_cd % shorter dash cooldown · crit +crit chance · firerate +% attack rate
##   regen HP/s · luck better drops + level-up choices · scrap +% scrap · pickup px
const STAT_BASE := {
	"max_hp": 6.0, "damage": 0.03, "resist": 0.025, "move": 0.025, "dash_cd": 0.04,
	"crit": 0.02, "firerate": 0.03, "regen": 0.35, "luck": 0.06, "scrap": 0.04, "pickup": 6.0,
}
const STAT_LABEL := {
	"max_hp": "+%d HP", "damage": "+%d%% damage", "resist": "-%d%% damage taken", "move": "+%d%% move speed",
	"dash_cd": "-%d%% dash cooldown", "crit": "+%d%% crit", "firerate": "+%d%% attack speed",
	"regen": "+%.1f HP/s", "luck": "+%d%% luck", "scrap": "+%d%% scrap", "pickup": "+%d pickup reach",
}
## Caps on summed gear stats (so stacking never breaks the game).
const STAT_CAP := {"resist": 0.45, "crit": 0.35, "dash_cd": 0.5, "move": 0.3, "firerate": 0.5, "luck": 1.0}
const SLOT_STATS := {
	"head": ["max_hp", "crit", "resist"], "chest": ["max_hp", "resist", "regen"],
	"shoulders": ["damage", "resist", "max_hp"], "legs": ["move", "max_hp", "resist"],
	"hands": ["damage", "firerate", "crit"], "boots": ["move", "dash_cd", "max_hp"],
	"charm": ["luck", "scrap", "pickup"], "vial": ["regen", "resist", "max_hp"],
	"patch": ["damage", "dash_cd", "firerate", "crit"],
}
## Legendary's small extra stat comes from this pool.
const EXTRA_STATS: Array = ["luck", "scrap", "regen", "crit"]

## Vials at Epic+ need a Dust Heart to awaken (stats off until charged).
const HEART_VIAL_RARITIES: Array = ["epic", "legendary"]

## ---------------------------------------------------------------- sets
## General sets: 6 pieces, bonuses at 2 / 4 / 6 (numbers used by the player).
const GENERAL_SETS := {
	"plague_doctor": {"name": "Plague Doctor", "noun": "Plague Doctor's",
		"bonus": ["Resist poison and Dust clouds", "Heals and health pickups 30% stronger", "Kills may drop a small heal"],
		"hazard_resist": 0.5, "heal_mult": 1.3, "kill_heal_chance": 0.08, "kill_heal": 8.0},
	"demolition_crew": {"name": "Demolition Crew", "noun": "Demolition",
		"bonus": ["Less knockback taken", "Dash damages enemies", "Every 10th kill sets off a blast"],
		"knock_taken": 0.5, "dash_damage": 18.0, "dash_radius": 40.0, "blast_every": 10, "blast_damage": 40.0, "blast_radius": 120.0},
	"night_runner": {"name": "Night Runner", "noun": "Night Runner's",
		"bonus": ["Faster movement", "Shorter dash cooldown", "2s after a dash, enemies lose track of you"],
		"move": 0.08, "dash_cd": 0.2, "vanish_time": 2.0, "vanish_radius": 420.0},
	"field_salvager": {"name": "Field Salvager", "noun": "Salvager's",
		"bonus": ["More scrap from kills", "Better odds of rare drops", "Extracting pays a bonus per set piece worn"],
		"scrap": 0.15, "drop_luck": 0.5, "extract_per_piece": 0.05},
}
const GENERAL_THRESHOLDS: Array = [2, 4, 6]

## Survivor sets: 3 pieces on fixed slots; 2 improves the ability, 3 adds one.
const SURVIVOR_SETS := {
	"foremans_kit": {"hero": "ash_rook", "name": "Foreman's Kit", "slots": ["head", "chest", "hands"],
		"bonus": ["Rush recharges 20% faster", "Second Charge: Rush can be used twice before it recharges"],
		"ability_cd": 0.8, "charges": 2},
	"bell_ringers_shroud": {"hero": "vesper_thorn", "name": "Bell Ringer's Shroud", "slots": ["head", "shoulders", "legs"],
		"bonus": ["Vial Shot lasts 50% longer", "Ghost Round: every 5th shot passes through every enemy"],
		"ability_time": 1.5, "ghost_every": 5},
	"quarry_plate": {"hero": "pebble", "name": "Quarry Plate", "slots": ["chest", "shoulders", "legs"],
		"bonus": ["+30 max health", "Stand Fast: below 25% HP, half damage for 5s (once per run)"],
		"max_hp": 30.0, "stand_below": 0.25, "stand_time": 5.0, "stand_mult": 0.5},
	"linemans_rig": {"hero": "bolt_juno", "name": "Lineman's Rig", "slots": ["hands", "chest", "boots"],
		"bonus": ["Overload stuns 50% longer", "Static Field: enemies touching him get shocked"],
		"stun_mult": 1.5, "static_radius": 44.0, "static_damage": 6.0, "static_every": 0.5, "static_stun": 0.25},
	"cathedral_vestments": {"hero": "sister_cinder", "name": "Cathedral Vestments", "slots": ["chest", "head", "legs"],
		"bonus": ["Heal 40% stronger", "Last Rites: first death each run revives at half health"],
		"heal_mult": 1.4, "revive_frac": 0.5},
	"surgeons_coat": {"hero": "quill_marrow", "name": "Surgeon's Coat", "slots": ["chest", "hands", "head"],
		"bonus": ["Bigger weak-spot damage (marks + crits hit harder)", "Autopsy: kills sometimes drop a heal or damage vial"],
		"mark_mult": 1.3, "crit_bonus": 0.5, "autopsy_chance": 0.12, "autopsy_heal": 12.0, "autopsy_buff": 5.0},
	"smugglers_wraps": {"hero": "nyx_caldera", "name": "Smuggler's Wraps", "slots": ["hands", "legs", "boots"],
		"bonus": ["Dash cooldown 25% shorter", "Shadow Step: dash leaves a decoy that enemies chase"],
		"dash_cd": 0.25, "decoy_time": 2.5, "decoy_radius": 360.0},
	"flight_crew_gear": {"hero": "helm_wisp", "name": "Flight Crew Gear", "slots": ["head", "chest", "boots"],
		"bonus": ["Drones shoot 30% faster", "Air Support: drones fire a missile volley every 20s"],
		"drone_rate": 1.3, "volley_every": 20.0, "volley_count": 6, "volley_damage": 30.0, "volley_radius": 60.0},
}

## ---------------------------------------------------------------- weapons
## Variants per survivor: "mul" multiplies weapon fields, "add" adds ("melee.x"
## edits the melee table). element = built-in coating. pattern-changing keys:
## pellets (shots per trigger), pierce (enemies passed through).
const WEAPON_VARIANTS := {
	"ash_rook": [
		{"id": "patched", "name": "Patched Scrap Boom", "rarity": "common", "mul": {}},
		{"id": "long_fuse", "name": "Long-Fuse Boom", "rarity": "rare", "mul": {"damage": 1.12}, "add": {"splash_radius": 12.0}},
		{"id": "cluster", "name": "Cluster Boom", "rarity": "epic", "mul": {"damage": 1.2, "splash_radius": 1.35}, "element": "fire"},
		{"id": "last_shift", "name": "\"Last Shift\"", "rarity": "legendary", "mul": {"damage": 1.3, "splash_radius": 1.2}, "legendary": "last_shift"},
	],
	"vesper_thorn": [
		{"id": "patched", "name": "Patched Vial Rifle", "rarity": "common", "mul": {}},
		{"id": "bell_tuned", "name": "Bell-Tuned Rifle", "rarity": "rare", "mul": {"damage": 1.12, "fire_rate": 1.08}},
		{"id": "hollowpoint", "name": "Hollowpoint Rifle", "rarity": "epic", "mul": {"damage": 1.2}, "add": {"pierce": 1}, "element": "poison"},
		{"id": "bellwether", "name": "\"Bellwether\"", "rarity": "legendary", "mul": {"damage": 1.3}, "add": {"pierce": 1}, "legendary": "bellwether"},
	],
	"pebble": [
		{"id": "patched", "name": "Patched Scrap Maul", "rarity": "common", "mul": {}},
		{"id": "rebar", "name": "Rebar Maul", "rarity": "rare", "mul": {"damage": 1.12, "melee.radius": 1.08}},
		{"id": "quarry", "name": "Quarry Maul", "rarity": "epic", "mul": {"damage": 1.22, "melee.knockback": 1.2}, "element": "shock"},
		{"id": "gravedigger", "name": "\"Gravedigger\"", "rarity": "legendary", "mul": {"damage": 1.3, "melee.radius": 1.1}, "legendary": "gravedigger"},
	],
	"bolt_juno": [
		{"id": "patched", "name": "Patched Chain Gauntlet", "rarity": "common", "mul": {}},
		{"id": "coiled", "name": "Coiled Gauntlet", "rarity": "rare", "mul": {"damage": 1.1, "fire_rate": 1.08}},
		{"id": "arc", "name": "Arc Gauntlet", "rarity": "epic", "mul": {"damage": 1.2, "melee.length": 1.1}, "element": "shock"},
		{"id": "live_line", "name": "\"Live Line\"", "rarity": "legendary", "mul": {"damage": 1.3, "fire_rate": 1.05}, "legendary": "live_line"},
	],
	"sister_cinder": [
		{"id": "patched", "name": "Patched Suppressor AR", "rarity": "common", "mul": {}},
		{"id": "chapel", "name": "Chapel AR", "rarity": "rare", "mul": {"damage": 1.1}, "add": {"mag_size": 6}},
		{"id": "thurible", "name": "Thurible AR", "rarity": "epic", "mul": {"damage": 1.18, "fire_rate": 1.05}, "element": "fire"},
		{"id": "censer", "name": "\"Censer\"", "rarity": "legendary", "mul": {"damage": 1.3}, "add": {"mag_size": 6}, "legendary": "censer"},
	],
	"quill_marrow": [
		{"id": "patched", "name": "Patched Bayonet", "rarity": "common", "mul": {}},
		{"id": "surgical", "name": "Surgical Bayonet", "rarity": "rare", "mul": {"damage": 1.12, "fire_rate": 1.06}},
		{"id": "autopsy", "name": "Autopsy Bayonet", "rarity": "epic", "mul": {"damage": 1.22, "melee.arc_deg": 1.1}, "element": "poison"},
		{"id": "bonesaw", "name": "\"Bonesaw\"", "rarity": "legendary", "mul": {"damage": 1.3, "fire_rate": 1.05}, "legendary": "bonesaw"},
	],
	"nyx_caldera": [
		{"id": "patched", "name": "Patched Dustblades", "rarity": "common", "mul": {}},
		{"id": "night", "name": "Night Blades", "rarity": "rare", "mul": {"damage": 1.1, "fire_rate": 1.06}},
		{"id": "smuggler", "name": "Smuggler's Edges", "rarity": "epic", "mul": {"damage": 1.2, "melee.radius": 1.08}, "element": "frost"},
		{"id": "twin_debts", "name": "\"Twin Debts\"", "rarity": "legendary", "mul": {"damage": 1.3}, "legendary": "twin_debts"},
	],
	"helm_wisp": [
		{"id": "patched", "name": "Patched Pilot Sidearm", "rarity": "common", "mul": {}},
		{"id": "flight", "name": "Flight Sidearm", "rarity": "rare", "mul": {"damage": 1.1}, "add": {"mag_size": 3}},
		{"id": "flare", "name": "Flare Sidearm", "rarity": "epic", "mul": {"damage": 1.2}, "add": {"pellets": 1}, "element": "fire"},
		{"id": "mayday", "name": "\"Mayday\"", "rarity": "legendary", "mul": {"damage": 1.3, "drone_damage": 1.2}, "legendary": "mayday"},
	],
}
const WEAPON_ICON := "res://assets/sprites/icons/weapons/weapon_%s.png"

## Named Legendaries (one per survivor) and their effect numbers.
const LEGENDARIES := {
	"last_shift": {"hero": "ash_rook", "name": "Last Shift", "desc": "Shots leave burning rubble on the ground for a few seconds.",
		"radius": 34.0, "time": 3.0, "dps": 12.0},
	"bellwether": {"hero": "vesper_thorn", "name": "Bellwether", "desc": "A kill shot rings a bell that slows every enemy on screen for 2s.",
		"slow_time": 2.0, "slow_mult": 0.5, "cooldown": 1.0},
	"gravedigger": {"hero": "pebble", "name": "Gravedigger", "desc": "Every kill adds a damage stack until she takes a hit.",
		"per_stack": 0.04, "max_stacks": 15},
	"live_line": {"hero": "bolt_juno", "name": "Live Line", "desc": "Every third punch arcs lightning to the nearest enemy.",
		"every": 3, "mult": 1.0, "range": 220.0, "stun": 0.3},
	"censer": {"hero": "sister_cinder", "name": "Censer", "desc": "Hits leave a smoke that heals her while she stands in it.",
		"every": 6, "radius": 46.0, "time": 3.0, "hps": 4.0},
	"bonesaw": {"hero": "quill_marrow", "name": "Bonesaw", "desc": "Hits into an enemy's back or a marked weak spot always crit.",
		"cone_deg": 100.0},
	"twin_debts": {"hero": "nyx_caldera", "name": "Twin Debts", "desc": "A kill marks the nearest enemy; her next hit on it crits.",
		"range": 260.0},
	"mayday": {"hero": "helm_wisp", "name": "Mayday", "desc": "At low health her drones shield her for 5s.",
		"below": 0.3, "time": 5.0, "mult": 0.3, "cooldown": 30.0},
}

## ---------------------------------------------------------------- mods
## "kind": ranged | melee | universal. Values at Common (× RARITY_MULT).
const MODS := {
	"scope": {"kind": "ranged", "name": "Scope", "icon": "icon_mod_scope", "desc": "+%d%% range", "key": "trigger_range", "val": 0.06},
	"ext_mag": {"kind": "ranged", "name": "Extended Mag", "icon": "icon_mod_ext_mag", "desc": "+%d%% magazine", "key": "mag_size", "val": 0.15},
	"barrel": {"kind": "ranged", "name": "Barrel", "icon": "icon_mod_barrel", "desc": "-%d%% spread", "key": "spread_deg", "val": 0.15},
	"stock": {"kind": "ranged", "name": "Stock", "icon": "icon_mod_stock", "desc": "-%d%% recoil, +a little fire rate", "key": "recoil", "val": 0.15},
	"weighted_head": {"kind": "melee", "name": "Weighted Head", "icon": "icon_mod_weighted_head", "desc": "+%d%% damage and knockback", "key": "damage", "val": 0.04},
	"grip": {"kind": "melee", "name": "Grip", "icon": "icon_mod_grip", "desc": "+%d%% swing speed", "key": "fire_rate", "val": 0.04},
	"edge": {"kind": "melee", "name": "Edge", "icon": "icon_mod_edge", "desc": "+%d%% wider arc / reach", "key": "reach", "val": 0.05},
	"wraps": {"kind": "melee", "name": "Wraps", "icon": "icon_mod_wraps", "desc": "+%d%% lifesteal on hit", "key": "lifesteal", "val": 0.02},
	"coat_poison": {"kind": "universal", "name": "Poison Coating", "icon": "icon_mod_coat_poison", "desc": "Hits poison (%d dps)", "coat": "poison", "val": 3.0},
	"coat_fire": {"kind": "universal", "name": "Fire Coating", "icon": "icon_mod_coat_fire", "desc": "Hits burn (%d dps)", "coat": "fire", "val": 3.0},
	"coat_shock": {"kind": "universal", "name": "Shock Coating", "icon": "icon_mod_coat_shock", "desc": "Hits may stun (%d%%)", "coat": "shock", "val": 6.0},
	"coat_frost": {"kind": "universal", "name": "Frost Coating", "icon": "icon_mod_coat_frost", "desc": "Hits slow (%d%%)", "coat": "frost", "val": 8.0},
}
## Coating / element effects on hit (weapon element uses the Rare strength).
const COAT_EFFECT := {
	"poison": {"status": "poison", "time": 3.0},
	"fire": {"status": "burn", "time": 2.5},
	"shock": {"status": "stun", "time": 0.35},
	"frost": {"status": "slow", "time": 1.5},
}
const ELEMENT_RARITY := "rare"

## ---------------------------------------------------------------- drops
## Kill / crate drop chance; scaled by Dust tier (1..10).
const KILL_DROP_CHANCE := 0.025
const CRATE_DROP_CHANCE := 0.06
const DROP_TIER_STEP := 0.15
## Rarity weights at tier 1 and the per-tier change.
## Loot v2 ("fewer, better drops"): a random kill / crate drop that rolls
## Common only actually drops this often; Rare+ odds per kill are unchanged,
## so a strong run lands ~8-15 items and each one matters more. Elite / boss
## rewards, events, jobs and bunkers are guaranteed drops and skip this.
const COMMON_KEEP := 0.4
## Past this many items picked up in a run, random kill / crate drop chance is
## multiplied by SOFT_CAP_MULT and elites stop adding their bonus mod (their
## gear piece and boss rewards stay guaranteed). Keeps long runs ~8-15 items.
const RUN_SOFT_CAP := 10
const SOFT_CAP_MULT := 0.35
## Elites: one guaranteed gear piece (Rare+); the bonus mod drops this often.
const ELITE_MOD_CHANCE := 0.35
const RARITY_WEIGHT := {"common": 70.0, "rare": 24.0, "epic": 5.0, "legendary": 1.0}
const RARITY_WEIGHT_STEP := {"common": -4.0, "rare": 1.5, "epic": 1.6, "legendary": 0.6}
## Which kind of item drops.
const KIND_WEIGHT := {"armor": 55.0, "accessory": 20.0, "weapon": 15.0, "mod": 10.0}
## Epic / Legendary armor rolls this often as a set piece (and survivor sets
## this share of those, for the survivor in the run).
const SET_CHANCE := 0.6
const SURVIVOR_SET_SHARE := 0.4

## Elite / boss rewards (Part 3). Keyed by role.
const ELITE_REWARD := {"min_rarity": "rare", "mod": true, "set_chance": 0.1}
const BOSS_REWARD := {"rarity": "epic", "set": true, "materials": Vector2i(1, 2), "legendary_chance": 0.08}
## Boss-kill material per boss kind; anything else drops Salvage Cores.
const BOSS_MATERIAL := {"dread_naught": "salvage_core", "mutant_overlord": "dust_heart"}
const MATERIAL_NAME := {"salvage_core": "Salvage Core", "dust_heart": "Dust Heart"}
const MATERIAL_ICON := {"salvage_core": "res://assets/sprites/pickups/salvage_core.png", "dust_heart": "res://assets/sprites/pickups/dust_heart.png"}
## Boss kill: added to the run's loot multiplier immediately.
const BOSS_LOOT_BONUS := 0.5
## Boss loot bonus is paid once per run (Blackout / Dustfall bosses every 5 min +
## the Dust Warden used to stack it to ×5 loot).
const BOSS_LOOT_BONUS_CAP := 0.5
## Overflow on extract (stash full): items are salvaged at this fraction.
const OVERFLOW_SALVAGE := 1.0


## =============================================================================

static func is_melee_hero(hero: String) -> bool:
	return LoadoutStubs.weapon_for_character(hero).has("melee")


static func variants(hero: String) -> Array:
	return WEAPON_VARIANTS.get(hero, [])


static func variant(hero: String, vid: String) -> Dictionary:
	for v in variants(hero):
		if str(v["id"]) == vid:
			return v
	return {}


## Weighted rarity roll for a Dust tier; luck > 0 shifts weight to rare+.
static func roll_rarity(tier: int, luck: float, rng: RandomNumberGenerator, min_rarity: String = "common") -> String:
	var t := clampi(tier, 1, 10) - 1
	var weights: Array = []
	var total := 0.0
	var min_i := RARITIES.find(min_rarity)
	for i in range(RARITIES.size()):
		var r: String = RARITIES[i]
		var w := 0.0
		if i >= min_i:
			w = maxf(1.0, float(RARITY_WEIGHT[r]) + float(RARITY_WEIGHT_STEP[r]) * t)
			if i > 0:
				w *= 1.0 + maxf(0.0, luck)
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in range(RARITIES.size()):
		roll -= float(weights[i])
		if roll <= 0.0:
			return RARITIES[i]
	return RARITIES[RARITIES.size() - 1]


static func _pick(arr: Array, rng: RandomNumberGenerator) -> Variant:
	return arr[rng.randi() % arr.size()]


static func _weighted_key(table: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in table.keys():
		total += float(table[k])
	var roll := rng.randf() * total
	for k in table.keys():
		roll -= float(table[k])
		if roll <= 0.0:
			return str(k)
	return str(table.keys()[0])


static func _roll_stats(slot: String, rarity: String, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = (SLOT_STATS.get(slot, ["max_hp"]) as Array).duplicate()
	var n := mini(int(RARITY_STATS.get(rarity, 1)), pool.size())
	var out := {}
	var mult := float(RARITY_MULT.get(rarity, 1.0))
	for i in range(mini(n, 2)):
		var s: String = pool[rng.randi() % pool.size()]
		pool.erase(s)
		out[s] = _round_stat(s, float(STAT_BASE[s]) * mult * rng.randf_range(0.85, 1.15))
	if rarity == "legendary":
		var ex: String = _pick(EXTRA_STATS, rng)
		out[ex] = _round_stat(ex, float(out.get(ex, 0.0)) + float(STAT_BASE[ex]) * 1.0)
	return out


static func _round_stat(s: String, v: float) -> float:
	if s in ["max_hp", "pickup"]:
		return roundf(v)
	return snappedf(v, 0.001 if v < 1.0 else 0.01)


## A new armor / accessory piece. set_id "" = loose; "general" / "survivor"
## asks for a set piece (only honoured at Epic / Legendary).
static func make_gear(slot: String, rarity: String, rng: RandomNumberGenerator, set_kind: String = "", hero: String = "") -> Dictionary:
	var kind := "accessory" if slot in ACCESSORY_SLOTS else "armor"
	var it := {"kind": kind, "slot": slot, "rarity": rarity, "stats": _roll_stats(slot, rarity, rng),
		"set": "", "hero": "", "icon": str(SLOT_ICON.get(slot, ""))}
	var nouns: Array = SLOT_NOUN.get(slot, ["Piece"])
	var ni := rng.randi() % nouns.size()
	var noun: String = nouns[ni]
	it["noun"] = ni
	it["name"] = "%s %s" % [_pick(RARITY_ADJ[rarity], rng), noun]
	if kind == "armor" and rarity in ["epic", "legendary"] and set_kind != "":
		if set_kind == "survivor" and hero != "":
			var sid := survivor_set_for(hero)
			if sid != "" and slot in (SURVIVOR_SETS[sid]["slots"] as Array):
				it["set"] = sid
				it["hero"] = hero
				it["name"] = "%s %s" % [SURVIVOR_SETS[sid]["name"], SLOT_NAME[slot]]
		if str(it["set"]) == "":
			var gid: String = _pick(GENERAL_SETS.keys(), rng)
			it["set"] = gid
			it["name"] = "%s %s" % [GENERAL_SETS[gid]["noun"], noun]
	if slot == "vial" and rarity in HEART_VIAL_RARITIES:
		it["needs_heart"] = true
		it["charged"] = false
	return it


## Which of the slot's three looks an item has (its noun). Old saves have no
## "noun" key: read it from the name; survivor-set pieces use a look per set.
static func noun_index(it: Dictionary) -> int:
	if it.has("noun"):
		return clampi(int(it["noun"]), 0, 2)
	var nouns: Array = SLOT_NOUN.get(str(it.get("slot", "")), [])
	var nm := str(it.get("name", ""))
	var best := -1
	var best_len := 0
	for i in range(nouns.size()):
		var n := str(nouns[i])
		if nm.ends_with(n) and n.length() > best_len:
			best = i
			best_len = n.length()
	if best >= 0:
		return best
	var sid := str(it.get("set", ""))
	if sid != "":
		return absi(sid.hash()) % 3
	return 0


## ---------------------------------------------------------------- set info
## One colour per set (badge plate behind its emblem icon emb_<set>).
const SET_COLOR := {
	"plague_doctor": Color("2b5a2c"), "demolition_crew": Color("763420"), "night_runner": Color("36424f"),
	"field_salvager": Color("7a5520"), "foremans_kit": Color("a8520f"), "bell_ringers_shroud": Color("5a3254"),
	"quarry_plate": Color("5a4636"), "linemans_rig": Color("1f5a58"), "cathedral_vestments": Color("9a1e26"),
	"surgeons_coat": Color("59563a"), "smugglers_wraps": Color("3a3436"), "flight_crew_gear": Color("5e6d7a"),
}


static func set_color(sid: String) -> Color:
	return SET_COLOR.get(sid, Color("3a3436"))


static func set_total(sid: String) -> int:
	return (SURVIVOR_SETS[sid]["slots"] as Array).size() if SURVIVOR_SETS.has(sid) else ARMOR_SLOTS.size()


static func set_slots(sid: String) -> Array:
	return SURVIVOR_SETS[sid]["slots"] if SURVIVOR_SETS.has(sid) else ARMOR_SLOTS


## Piece counts at which each bonus turns on.
static func set_thresholds(sid: String) -> Array:
	return [2, 3] if SURVIVOR_SETS.has(sid) else GENERAL_THRESHOLDS


static func set_bonuses(sid: String) -> Array:
	if SURVIVOR_SETS.has(sid):
		return SURVIVOR_SETS[sid]["bonus"]
	return GENERAL_SETS.get(sid, {}).get("bonus", [])


static func set_hero(sid: String) -> String:
	return str(SURVIVOR_SETS[sid]["hero"]) if SURVIVOR_SETS.has(sid) else ""


## Salvaging these asks twice (Epic, Legendary and every set piece).
static func needs_salvage_confirm(it: Dictionary) -> bool:
	return str(it.get("rarity", "common")) in ["epic", "legendary"] or str(it.get("set", "")) != ""


## Coarse filter group for the stash: weapon / mod / armor / accessory.
static func kind_of(it: Dictionary) -> String:
	return str(it.get("kind", "armor"))


static func survivor_set_for(hero: String) -> String:
	for sid in SURVIVOR_SETS.keys():
		if str(SURVIVOR_SETS[sid]["hero"]) == hero:
			return str(sid)
	return ""


static func make_weapon(hero: String, rarity: String, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = []
	for v in variants(hero):
		if str(v["rarity"]) == rarity:
			pool.append(v)
	if pool.is_empty():
		pool = variants(hero).slice(0, 1)
	var v: Dictionary = _pick(pool, rng)
	var it := {"kind": "weapon", "slot": "weapon", "rarity": str(v["rarity"]), "hero": hero,
		"variant": str(v["id"]), "name": str(v["name"]), "legendary": str(v.get("legendary", "")),
		"stats": {}, "set": "", "coat": str(v.get("element", ""))}
	it["icon"] = weapon_icon(hero, str(it["legendary"]))
	return it


static func weapon_icon(hero: String, legendary: String) -> String:
	if legendary != "":
		return "res://assets/sprites/icons/legendary/legendary_%s.png" % legendary
	return WEAPON_ICON % hero


static func make_mod(mod_id: String, rarity: String) -> Dictionary:
	var m: Dictionary = MODS.get(mod_id, MODS["scope"])
	return {"kind": "mod", "slot": "mod", "rarity": rarity, "mod": mod_id, "name": "%s %s" % [RARITY_NAME[rarity], m["name"]],
		"stats": {}, "set": "", "hero": "", "mod_kind": str(m["kind"]), "coat": str(m.get("coat", "")),
		"icon": "res://assets/sprites/icons/mods/%s.png" % str(m["icon"])}


static func random_mod_id(melee: Variant, rng: RandomNumberGenerator) -> String:
	var ids: Array = []
	for k in MODS.keys():
		var kind := str(MODS[k]["kind"])
		if kind == "universal" or melee == null or (kind == "melee") == bool(melee):
			ids.append(k)
	return str(_pick(ids, rng))


## Value a mod adds at its rarity (fractions, dps or %).
static func mod_value(item: Dictionary) -> float:
	var m: Dictionary = MODS.get(str(item.get("mod", "")), {})
	return float(m.get("val", 0.0)) * float(RARITY_MULT.get(str(item.get("rarity", "common")), 1.0))


## Can this item go in this loadout slot for this hero?
static func fits(item: Dictionary, slot: String, hero: String) -> bool:
	var kind := str(item.get("kind", ""))
	match slot:
		"weapon":
			return kind == "weapon" and str(item.get("hero", "")) == hero
		"mod1", "mod2":
			if kind != "mod":
				return false
			var mk := str(item.get("mod_kind", "universal"))
			return mk == "universal" or (mk == "melee") == is_melee_hero(hero)
	if str(item.get("slot", "")) != slot:
		return false
	var h := str(item.get("hero", ""))
	return h == "" or h == hero


## One random drop. kind "" = weighted by KIND_WEIGHT.
static func roll_drop(tier: int, hero: String, luck: float, rng: RandomNumberGenerator, kind: String = "", min_rarity: String = "common") -> Dictionary:
	var k := kind if kind != "" else _weighted_key(KIND_WEIGHT, rng)
	var rarity := roll_rarity(tier, luck, rng, min_rarity)
	match k:
		"weapon":
			return make_weapon(hero, rarity, rng)
		"mod":
			return make_mod(random_mod_id(is_melee_hero(hero), rng), rarity)
		"accessory":
			return make_gear(_pick(ACCESSORY_SLOTS, rng), rarity, rng)
	var set_kind := ""
	if rarity in ["epic", "legendary"] and rng.randf() < SET_CHANCE:
		set_kind = "survivor" if rng.randf() < SURVIVOR_SET_SHARE else "general"
	return make_gear(_pick(ARMOR_SLOTS, rng), rarity, rng, set_kind, hero)


## A random kill / crate drop ({} = nothing): Commons thinned by COMMON_KEEP.
static func random_drop(tier: int, hero: String, luck: float, rng: RandomNumberGenerator) -> Dictionary:
	var it := roll_drop(tier, hero, luck, rng)
	if str(it.get("rarity", "common")) == "common" and rng.randf() >= COMMON_KEEP:
		return {}
	return it


## Rough power of an item for same-slot comparisons: armor / accessories sum
## their stats in "base rolls"; weapons by rarity; mods by their value.
static func item_score(it: Dictionary) -> float:
	match str(it.get("kind", "")):
		"weapon":
			return float(RARITIES.find(str(it.get("rarity", "common"))))
		"mod":
			return mod_value(it)
	var sc := 0.0
	var st: Dictionary = it.get("stats", {})
	for k in st.keys():
		sc += float(st[k]) / maxf(0.0001, float(STAT_BASE.get(str(k), 1.0)))
	return sc


## A guaranteed set piece (bosses): survivor set slots for this hero or general.
static func roll_set_piece(rarity: String, hero: String, rng: RandomNumberGenerator) -> Dictionary:
	var survivor := rng.randf() < SURVIVOR_SET_SHARE and survivor_set_for(hero) != ""
	if survivor:
		var sid := survivor_set_for(hero)
		return make_gear(_pick(SURVIVOR_SETS[sid]["slots"], rng), rarity, rng, "survivor", hero)
	return make_gear(_pick(ARMOR_SLOTS, rng), rarity, rng, "general", hero)


## Rewards for an elite / boss kill: {"items": [...], "materials": {id: n}}.
static func roll_role_reward(role: String, kind: String, tier: int, hero: String, luck: float, rng: RandomNumberGenerator, extras: bool = true) -> Dictionary:
	var items: Array = []
	var mats := {}
	if role == "elite":
		var r := roll_rarity(tier, luck, rng, str(ELITE_REWARD["min_rarity"]))
		if rng.randf() < float(ELITE_REWARD["set_chance"]):
			items.append(roll_set_piece("epic" if r in ["common", "rare"] else r, hero, rng))
		else:
			items.append(roll_drop(tier, hero, luck, rng, ["armor", "accessory", "weapon"][rng.randi() % 3], str(ELITE_REWARD["min_rarity"])))
		if extras and rng.randf() < ELITE_MOD_CHANCE:
			items.append(make_mod(random_mod_id(is_melee_hero(hero), rng), roll_rarity(tier, luck, rng, "rare")))
	elif role == "boss":
		items.append(roll_set_piece(str(BOSS_REWARD["rarity"]), hero, rng))
		var mid := str(BOSS_MATERIAL.get(kind, "salvage_core"))
		var rr: Vector2i = BOSS_REWARD["materials"]
		mats[mid] = rng.randi_range(rr.x, rr.y)
		if rng.randf() < float(BOSS_REWARD["legendary_chance"]):
			items.append(make_weapon(hero, "legendary", rng))
	return {"items": items, "materials": mats}


## Short stat lines for UI.
static func stat_lines(item: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var stats: Dictionary = item.get("stats", {})
	for s in stats.keys():
		var v := float(stats[s])
		var fmt := str(STAT_LABEL.get(s, s + " %s"))
		if s in ["max_hp", "pickup"]:
			out.append(fmt % int(v))
		elif s == "regen":
			out.append(fmt % v)
		else:
			out.append(fmt % int(round(v * 100.0)))
	if str(item.get("kind", "")) == "weapon":
		var hero := str(item.get("hero", ""))
		var v2 := variant(hero, str(item.get("variant", "")))
		var mul: Dictionary = v2.get("mul", {})
		if mul.has("damage"):
			out.append("+%d%% damage" % int(round((float(mul["damage"]) - 1.0) * 100.0)))
		var add: Dictionary = v2.get("add", {})
		if add.has("pierce"):
			out.append("Pierces %d" % int(add["pierce"]))
		if add.has("pellets"):
			out.append("Double tap")
		if str(item.get("coat", "")) != "":
			out.append("%s rounds" % str(item["coat"]).capitalize())
		var leg := str(item.get("legendary", ""))
		if leg != "":
			out.append(str(LEGENDARIES[leg]["desc"]))
		if out.is_empty():
			out.append("Standard issue")
	if str(item.get("kind", "")) == "mod":
		var m: Dictionary = MODS.get(str(item.get("mod", "")), {})
		var mv := mod_value(item)
		var shown := mv if str(m.get("coat", "")) != "" else mv * 100.0
		out.append(str(m.get("desc", "")) % int(round(shown)))
		out.append({"ranged": "Ranged weapons", "melee": "Melee weapons", "universal": "Any weapon"}[str(m.get("kind", "universal"))])
	if str(item.get("set", "")) != "":
		out.append("Set: " + set_name(str(item["set"])))
	if bool(item.get("needs_heart", false)) and not bool(item.get("charged", false)):
		out.append("Inert — awaken with a Dust Heart")
	return out


## (Call this from outside: GearDefs.set_title() resolves to Resource.set_name.)
static func set_title(sid: String) -> String:
	return set_name(sid)


static func set_name(sid: String) -> String:
	if GENERAL_SETS.has(sid):
		return str(GENERAL_SETS[sid]["name"])
	if SURVIVOR_SETS.has(sid):
		return str(SURVIVOR_SETS[sid]["name"])
	return sid


static func salvage_value(item: Dictionary) -> int:
	return int(SALVAGE.get(str(item.get("rarity", "common")), 10))


## Applies a weapon item (variant) and its mods to a hero's base weapon dict.
static func apply_weapon(base: Dictionary, item: Dictionary, mods: Array) -> Dictionary:
	var w := base.duplicate(true)
	if not item.is_empty():
		var v := variant(str(item.get("hero", "")), str(item.get("variant", "")))
		var mul: Dictionary = v.get("mul", {})
		for k in mul.keys():
			_edit(w, str(k), float(mul[k]), true)
		var add: Dictionary = v.get("add", {})
		for k in add.keys():
			_edit(w, str(k), float(add[k]), false)
		w["name"] = str(item.get("name", w.get("name", "")))
		w["legendary"] = str(item.get("legendary", ""))
		w["rarity"] = str(item.get("rarity", "common"))
	var coats: Array = []
	if not item.is_empty() and str(item.get("coat", "")) != "":
		coats.append({"coat": str(item["coat"]), "val": float(MODS["coat_" + str(item["coat"])]["val"]) * float(RARITY_MULT[ELEMENT_RARITY])})
	var melee := w.has("melee")
	for m in mods:
		if not (m is Dictionary):
			continue
		var md: Dictionary = MODS.get(str(m.get("mod", "")), {})
		if md.is_empty():
			continue
		var kind := str(md["kind"])
		if kind != "universal" and (kind == "melee") != melee:
			continue
		var val := mod_value(m)
		match str(m.get("mod", "")):
			"scope":
				_edit(w, "trigger_range", 1.0 + val, true)
			"ext_mag":
				w["mag_size"] = int(ceil(float(w.get("mag_size", 0)) * (1.0 + val)))
			"barrel":
				_edit(w, "spread_deg", maxf(0.2, 1.0 - val), true)
			"stock":
				_edit(w, "recoil", maxf(0.2, 1.0 - val), true)
				_edit(w, "shake", maxf(0.2, 1.0 - val), true)
				_edit(w, "fire_rate", 1.0 + val * 0.2, true)
			"weighted_head":
				_edit(w, "damage", 1.0 + val, true)
				_edit(w, "melee.knockback", 1.0 + val * 2.0, true)
			"grip":
				_edit(w, "fire_rate", 1.0 + val, true)
			"edge":
				_edit(w, "melee.radius", 1.0 + val, true)
				_edit(w, "melee.arc_deg", 1.0 + val, true)
				_edit(w, "melee.length", 1.0 + val, true)
			"wraps":
				_edit(w, "melee.lifesteal", val, false)
			_:
				if str(md.get("coat", "")) != "":
					coats.append({"coat": str(md["coat"]), "val": val})
	w["coats"] = coats
	return w


static func _edit(w: Dictionary, key: String, v: float, mul: bool) -> void:
	var d := w
	var k := key
	if key.begins_with("melee."):
		if not w.has("melee"):
			return
		d = w["melee"]
		k = key.substr(6)
	if not d.has(k):
		if mul:
			return
		d[k] = 0.0
	var cur: Variant = d[k]
	var out := float(cur) * v if mul else float(cur) + v
	d[k] = int(round(out)) if cur is int else out
