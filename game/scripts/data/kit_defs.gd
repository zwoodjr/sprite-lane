class_name KitDefs
extends RefCounted

## Depth Update E5 — loadouts. Each survivor keeps their weapon TYPE but picks:
##   * a weapon STYLE (3 per survivor, unlocked at their Hangar station ranks),
##   * an ABILITY version (2; the second unlocks at station rank ABILITY_B_RANK),
##   * a QUIRK (1 of 3 rule-bending perks).
## Chosen on the pre-run Loadout screen (with tonics and gear). All tuning here.
## Style "mul" multiplies weapon keys, "set" overwrites, "melee_mul"/"melee_set"
## edit the melee hitbox, "coat" adds a weapon coating ({coat, val}).

const STYLE_UNLOCK: Array = [0, 1, 2] ## Hangar v5: 3 station ranks (was [0, 2, 4] of 5)
const ABILITY_B_RANK := 2 ## Hangar v5 (was 3 of 5)
const ICON := "res://assets/sprites/depth/icons/style_%s_%s.png"

const STYLES := {
	"ash_rook": [
		{"id": "boom", "name": "Scrap Boom", "desc": "Rockets with a fat blast."},
		{"id": "cluster", "name": "Cluster Pot", "desc": "Each shot splits into three bomblets — smaller blasts, more of them.",
			"mul": {"damage": 0.55, "splash_radius": 0.75}, "set": {"pellets": 2, "spread_deg": 9.0}},
		{"id": "mortar", "name": "Slag Mortar", "desc": "Slow, huge, molten blasts that set the ground on fire.",
			"mul": {"damage": 1.7, "fire_rate": 0.6, "splash_radius": 1.45, "projectile_speed": 0.8}, "set": {"mag_size": 3},
			"coat": {"coat": "fire", "val": 8.0}},
	],
	"vesper_thorn": [
		{"id": "bolt", "name": "Piercing Bolt Rifle", "desc": "Heavy bolts that punch through two enemies.",
			"mul": {"damage": 0.92}, "set": {"pierce": 2}},
		{"id": "semi", "name": "Fast Semi-Auto", "desc": "A quick-firing magazine rifle. Lighter hits, many more of them.",
			"mul": {"damage": 0.5, "fire_rate": 2.3, "reload_time": 0.8}, "set": {"mag_size": 8, "spread_deg": 1.6}},
		{"id": "coater", "name": "Charge-Shot Coater", "desc": "Big charged slugs coated in toxin.",
			"mul": {"damage": 1.6, "fire_rate": 0.7}, "coat": {"coat": "poison", "val": 9.0}},
	],
	"pebble": [
		{"id": "maul", "name": "Scrap Maul", "desc": "The classic: a wide, heavy smash."},
		{"id": "sweep", "name": "Sledge Sweep", "desc": "A huge horizontal sweep that clears space around her.",
			"mul": {"damage": 0.82}, "melee_set": {"arc_deg": 210.0}, "melee_mul": {"radius": 1.12}},
		{"id": "driver", "name": "Pile Driver", "desc": "Slow overhead blows that send enemies flying.",
			"mul": {"damage": 1.55, "fire_rate": 0.72}, "melee_mul": {"knockback": 1.5, "arc_deg": 0.75}},
	],
	"bolt_juno": [
		{"id": "chain", "name": "Chain Gauntlet", "desc": "A long, whipping chain punch."},
		{"id": "whip", "name": "Live Whip", "desc": "Longer, thinner lash that crackles with shock.",
			"melee_mul": {"length": 1.4, "width": 0.8}, "coat": {"coat": "shock", "val": 18.0}},
		{"id": "knuckle", "name": "Knuckle Duster", "desc": "Short, fast hooks in a close arc.",
			"mul": {"damage": 0.72, "fire_rate": 1.6}, "melee_set": {"shape": "arc", "arc_deg": 110.0, "radius": 74.0}},
	],
	"sister_cinder": [
		{"id": "suppressor", "name": "Suppressor AR", "desc": "A steady, quiet stream of rounds."},
		{"id": "burst", "name": "Censer Burst", "desc": "Three-round bursts that hit in a tight fan.",
			"mul": {"fire_rate": 0.45, "damage": 0.9}, "set": {"pellets": 2, "spread_deg": 5.0}},
		{"id": "ember", "name": "Ember Rounds", "desc": "Incendiary rounds — slower, and everything burns.",
			"mul": {"fire_rate": 0.8}, "coat": {"coat": "fire", "val": 6.0}},
	],
	"quill_marrow": [
		{"id": "bayonet", "name": "Bayonet Knife", "desc": "Fast stab-slashes."},
		{"id": "scalpels", "name": "Scalpel Pair", "desc": "Two scalpels, alternating cuts, even faster.",
			"mul": {"damage": 0.78, "fire_rate": 1.4}, "melee_set": {"alternate_deg": 20.0}},
		{"id": "cleaver", "name": "Bonesaw Cleaver", "desc": "Wide, heavy chops that bite deep.",
			"mul": {"damage": 1.45, "fire_rate": 0.7}, "melee_set": {"arc_deg": 145.0}, "melee_mul": {"radius": 1.2}},
	],
	"nyx_caldera": [
		{"id": "dustblades", "name": "Dual Dustblades", "desc": "Two quick blades, alternating."},
		{"id": "long", "name": "Long Knives", "desc": "Longer blades, more reach, a touch slower.",
			"mul": {"fire_rate": 0.82}, "melee_mul": {"radius": 1.32}},
		{"id": "viper", "name": "Viper Fangs", "desc": "Poisoned fangs that keep hurting after the cut.",
			"mul": {"damage": 0.9}, "coat": {"coat": "poison", "val": 7.0}},
	],
	"helm_wisp": [
		{"id": "sidearm", "name": "Pilot Sidearm", "desc": "A reliable pistol, drones do the rest."},
		{"id": "flare", "name": "Flare Pistol", "desc": "Burning flares: slower, harder, sets targets alight.",
			"mul": {"damage": 1.35, "fire_rate": 0.7}, "coat": {"coat": "fire", "val": 7.0}},
		{"id": "machine", "name": "Machine Pistol", "desc": "Sprays fast; twice the magazine.",
			"mul": {"damage": 0.6, "fire_rate": 1.85, "mag_size": 2.0}, "set": {"spread_deg": 6.0}},
	],
}

## Ability versions: "a" is the survivor's own ability; "b" edits it.
const ABILITIES := {
	"ash_rook": {"name": "Short Charge", "desc": "A short, fast charge that ends in a ground slam.",
		"mul": {"duration": 0.4, "speed_mult": 1.35, "cooldown": 0.8}, "set": {"end_slam_radius": 120.0, "end_slam_damage": 40.0}},
	"vesper_thorn": {"name": "Smoke Vial", "desc": "A wider cloud that also slows everything in it.",
		"mul": {"cloud_radius": 1.6, "vial_mult": 0.7}, "set": {"cloud_slow": 0.5}},
	"pebble": {"name": "Quake Stomp", "desc": "No leap — she stomps where she stands: wider, longer stun.",
		"mul": {"radius": 1.4, "stun": 1.5, "damage_mult": 0.8}, "set": {"lunge_range": 0.0, "lunge_time": 0.05}},
	"bolt_juno": {"name": "Static Cage", "desc": "A huge burst around him that stuns far longer, no chain.",
		"mul": {"burst_radius": 2.1, "stun": 1.7, "damage_mult": 0.7}, "set": {"chain": 0}},
	"sister_cinder": {"name": "Smoke Censer", "desc": "A smaller heal that leaves a healing smoke where she stands.",
		"mul": {"heal": 0.6}, "set": {"puddle_radius": 85.0, "puddle_time": 5.0, "puddle_hps": 7.0}},
	"quill_marrow": {"name": "Long Lunge", "desc": "Reaches much further and stabs harder, shorter mark.",
		"mul": {"range": 1.6, "damage_mult": 1.3, "mark_time": 0.6}},
	"nyx_caldera": {"name": "Shadow Slip", "desc": "A longer slip that leaves her unseen for a moment.",
		"mul": {"dash_time": 1.5, "damage_mult": 0.6}, "set": {"hide": 1.2}},
	"helm_wisp": {"name": "Overdrive", "desc": "No extra drone — every drone overclocks harder for longer.",
		"set": {"temp_drones": 0, "overclock": 2.6}, "mul": {"overclock_time": 1.6}},
}

## Quirks: rule-bending perks (fx keys read by the player / GameState).
const QUIRKS := {
	"no_reload": {"name": "Hot Barrel", "desc": "No reloads — but fire 3s straight and it overheats for 2s.", "ranged": true,
		"fx": {"no_reload": 1.0, "heat_max": 3.0, "overheat": 2.0}},
	"pack_leader": {"name": "Pack Leader", "desc": "+20% damage while your dog is close.", "fx": {"pet_damage": 0.2, "pet_range": 220.0}},
	"glass_cannon": {"name": "Glass Cannon", "desc": "+30% damage, −30% max HP.", "fx": {"damage": 0.3, "max_hp_mult": 0.7}},
	"bloodthirst": {"name": "Bloodthirst", "desc": "Kills heal 2 HP, but no other regeneration.", "fx": {"kill_heal": 2.0, "no_regen": 1.0}},
	"scavenger": {"name": "Scavenger", "desc": "+40% scrap from kills, −15% damage.", "fx": {"scrap": 0.4, "damage": -0.15}},
	"berserker": {"name": "Berserker", "desc": "Below half HP: +35% damage and attack speed.", "fx": {"below": 0.5, "rage": 0.35}},
	"steady": {"name": "Steady Hands", "desc": "+25% damage while standing still, −10% move speed.", "fx": {"still_damage": 0.25, "move": -0.1}},
	"dust_eater": {"name": "Dust Eater", "desc": "Plague builds 50% faster; each plague stage gives +12% damage.", "fx": {"exposure_mult": 1.5, "stage_damage": 0.12}},
	"packrat": {"name": "Packrat", "desc": "+3 backpack room, −8% move speed.", "fx": {"pack": 3.0, "move": -0.08}},
}
const HERO_QUIRKS := {
	"ash_rook": ["no_reload", "glass_cannon", "packrat"],
	"vesper_thorn": ["steady", "no_reload", "pack_leader"],
	"pebble": ["berserker", "packrat", "bloodthirst"],
	"bolt_juno": ["berserker", "glass_cannon", "dust_eater"],
	"sister_cinder": ["pack_leader", "no_reload", "dust_eater"],
	"quill_marrow": ["bloodthirst", "berserker", "scavenger"],
	"nyx_caldera": ["glass_cannon", "scavenger", "berserker"],
	"helm_wisp": ["pack_leader", "no_reload", "steady"],
}


static func styles(hero: String) -> Array:
	return STYLES.get(hero, [])


static func style(hero: String, sid: String) -> Dictionary:
	for s in styles(hero):
		if str(s["id"]) == sid:
			return s
	return styles(hero)[0] if not styles(hero).is_empty() else {}


static func style_index(hero: String, sid: String) -> int:
	var arr := styles(hero)
	for i in range(arr.size()):
		if str(arr[i]["id"]) == sid:
			return i
	return 0


static func style_unlocked(hero: String, sid: String, station_rank: int) -> bool:
	return station_rank >= int(STYLE_UNLOCK[clampi(style_index(hero, sid), 0, STYLE_UNLOCK.size() - 1)])


static func icon_path(hero: String, sid: String) -> String:
	return ICON % [hero, sid]


static func _edit(d: Dictionary, mul: Dictionary, setv: Dictionary) -> void:
	for k in mul.keys():
		if d.has(k):
			var v: Variant = d[k]
			if v is int:
				d[k] = maxi(1, int(round(float(v) * float(mul[k]))))
			else:
				d[k] = float(v) * float(mul[k])
	for k in setv.keys():
		d[k] = setv[k]


## Weapon dict with a style applied (keeps the survivor's weapon type).
static func apply_style(weapon: Dictionary, hero: String, sid: String) -> Dictionary:
	var w := weapon.duplicate(true)
	var st := style(hero, sid)
	if st.is_empty():
		return w
	_edit(w, st.get("mul", {}), st.get("set", {}))
	if w.has("melee"):
		var m: Dictionary = (w["melee"] as Dictionary).duplicate()
		_edit(m, st.get("melee_mul", {}), st.get("melee_set", {}))
		w["melee"] = m
	if st.has("coat"):
		var coats: Array = (w.get("coats", []) as Array).duplicate()
		coats.append((st["coat"] as Dictionary).duplicate())
		w["coats"] = coats
	w["style"] = str(st["id"])
	w["style_name"] = str(st["name"])
	return w


## Ability dict with the chosen version ("a" = as is, "b" = edited).
static func apply_ability(ability: Dictionary, hero: String, version: String) -> Dictionary:
	var a := ability.duplicate(true)
	if version != "b" or not ABILITIES.has(hero):
		return a
	var b: Dictionary = ABILITIES[hero]
	_edit(a, b.get("mul", {}), b.get("set", {}))
	a["name"] = str(b["name"])
	a["desc"] = str(b["desc"])
	a["version"] = "b"
	return a


static func quirks(hero: String) -> Array:
	return HERO_QUIRKS.get(hero, [])


static func quirk(id: String) -> Dictionary:
	return QUIRKS.get(id, {})
