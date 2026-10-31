extends RefCounted

## Pet gear (one slot per pet: collar / harness) + bond perks (levels 3, 6, 10).
## Pets never take damage, so gear works through the hero and the pet's
## attacks. Every effect is a "fx" key read by GameState.pet_fx():
##   pet_damage  +% pet damage            thorns    dps to enemies touching the pet
##   dodge       chance to dodge a hit    guard     % less damage taken
##   luck        loot find (gear luck)    reveal    elites announced + marked
##   kill_heal   HP when an enemy dies next to the pet
## dodge / guard / kill_heal only work while the pet is near you (NEAR px).

const NEAR := 260.0
const RARITY_K := {"common": 1.0, "rare": 1.5, "epic": 2.0, "legendary": 2.6}
## Drop odds per kill (Wander only, Pet Gear needs the medicine phase-in).
const DROP := {"": 0.0012, "elite": 0.05, "boss": 0.15}
## Bond respec in the Kennel.
const RESPEC_COST := 150
const PERK_LEVELS: Array = [3, 6, 10]

## type -> name, painted icon reused from the gear / camp sets, fx at common.
const TYPES := {
	"spiked_collar": {"name": "Spiked Collar", "icon": "gear_charm_2", "fx": {"thorns": 6.0, "pet_damage": 0.04},
		"desc": "Enemies touching your pet take %d dps; pet damage +%d%%"},
	"reflective_harness": {"name": "Reflective Harness", "icon": "gear_chest_1", "fx": {"dodge": 0.04},
		"desc": "%d%% chance to dodge a hit while your pet is close"},
	"satchel": {"name": "Scavenger Satchel", "icon": "hud_pack", "fx": {"luck": 0.15},
		"desc": "+%d%% loot find"},
	"armored_vest": {"name": "Armored Vest", "icon": "gear_chest_2", "fx": {"guard": 0.05},
		"desc": "You take %d%% less damage while your pet is close"},
	"radio_collar": {"name": "Radio Collar", "icon": "camp_radio_tower", "fx": {"reveal": 1.0, "pet_damage": 0.02},
		"desc": "Elites are called out and marked when they arrive; pet damage +%d%%"},
	"med_pouch": {"name": "Med Pouch", "icon": "ing_medicine", "fx": {"kill_heal": 1.0},
		"desc": "Heal %.1f HP when an enemy dies next to your pet"},
}
## Starting pieces (bound: never lost, salvaged or auto-salvaged).
const DEFAULTS := {
	"noel": {"type": "spiked_collar", "rarity": "common", "name": "Noel's Worn Collar"},
	"bentley": {"type": "satchel", "rarity": "rare", "name": "Bentley's Satchel"},
	"lillie": {"type": "armored_vest", "rarity": "rare", "name": "Lillie's Armor Patch", "icon": "gear_patch_1"},
}
## Crafter Bench recipes (rare pieces of the pool) + one craft-only piece.
const CRAFT := {
	"spiked_collar": {"scrap": 500, "machine_oil": 6, "dust_shard": 2},
	"reflective_harness": {"scrap": 600, "salvage_core": 4, "dust_shard": 2},
	"satchel": {"scrap": 500, "herb": 6, "plague_gland": 4},
	"armored_vest": {"scrap": 600, "salvage_core": 6, "machine_oil": 4},
	"radio_collar": {"scrap": 500, "salvage_core": 3, "machine_oil": 4},
	"med_pouch": {"scrap": 550, "herb": 8, "plague_gland": 4},
}
const CRAFT_RARITY := "rare"
## War-Dog Rig: craft-only Legendary (bench rank 2): a bit of everything.
const WAR_DOG_RIG := {"name": "War-Dog Rig", "icon": "gear_chest_0", "rarity": "legendary", "bench": 2,
	"fx": {"pet_damage": 0.15, "guard": 0.08, "thorns": 10.0, "dodge": 0.05},
	"cost": {"scrap": 2400, "salvage_core": 12, "dust_shard": 8, "dust_heart": 1},
	"desc": "Helm's last good harness: +15% pet damage, 8% less damage, 5% dodge, thorns 10 dps"}


static func make(type: String, rarity: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var d: Dictionary = TYPES.get(type, TYPES["spiked_collar"])
	var k := float(RARITY_K.get(rarity, 1.0))
	var fx := {}
	for key in (d["fx"] as Dictionary).keys():
		fx[key] = 1.0 if key == "reveal" else snappedf(float(d["fx"][key]) * k, 0.001)
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	return {"kind": "petgear", "slot": "pet", "pet_type": type, "rarity": rarity, "fx": fx,
		"name": "%s %s" % [_adj(rarity, r), str(d["name"])], "icon_id": str(d["icon"]), "stats": {}, "set": "", "hero": ""}


static func make_default(pet_id: String) -> Dictionary:
	var d: Dictionary = DEFAULTS[pet_id]
	var it := make(str(d["type"]), str(d["rarity"]))
	it["name"] = str(d["name"])
	it["bound"] = pet_id
	it["locked"] = true
	if d.has("icon"):
		it["icon_id"] = str(d["icon"])
	return it


static func make_war_dog_rig() -> Dictionary:
	return {"kind": "petgear", "slot": "pet", "pet_type": "war_dog_rig", "rarity": "legendary",
		"fx": WAR_DOG_RIG["fx"].duplicate(), "name": str(WAR_DOG_RIG["name"]), "icon_id": str(WAR_DOG_RIG["icon"]),
		"stats": {}, "set": "", "hero": "", "craft": "war_dog_rig"}


static func roll_drop(rng: RandomNumberGenerator, tier: int) -> Dictionary:
	var types := TYPES.keys()
	var t := str(types[rng.randi() % types.size()])
	var r := "common"
	var x := rng.randf()
	var up := 0.03 * float(clampi(tier, 1, 10))
	if x < 0.04 + up * 0.4:
		r = "epic"
	elif x < 0.3 + up:
		r = "rare"
	return make(t, r, rng)


static func _adj(rarity: String, rng: RandomNumberGenerator) -> String:
	var a: Dictionary = {"common": ["Frayed", "Patched"], "rare": ["Sturdy", "Stitched"], "epic": ["Veteran's", "Riveted"], "legendary": ["Legendary"]}
	var opts: Array = a.get(rarity, ["Worn"])
	return str(opts[rng.randi() % opts.size()])


## Short lines for the item card / kennel.
static func lines(it: Dictionary) -> Array:
	var fx: Dictionary = it.get("fx", {})
	var out: Array = []
	if str(it.get("pet_type", "")) == "war_dog_rig":
		return [str(WAR_DOG_RIG["desc"])]
	var d: Dictionary = TYPES.get(str(it.get("pet_type", "")), {})
	match str(it.get("pet_type", "")):
		"spiked_collar":
			out.append(str(d["desc"]) % [int(fx.get("thorns", 0)), int(round(float(fx.get("pet_damage", 0)) * 100))])
		"reflective_harness":
			out.append(str(d["desc"]) % int(round(float(fx.get("dodge", 0)) * 100)))
		"satchel":
			out.append(str(d["desc"]) % int(round(float(fx.get("luck", 0)) * 100)))
		"armored_vest":
			out.append(str(d["desc"]) % int(round(float(fx.get("guard", 0)) * 100)))
		"radio_collar":
			out.append(str(d["desc"]) % int(round(float(fx.get("pet_damage", 0)) * 100)))
		"med_pouch":
			out.append(str(d["desc"]) % float(fx.get("kill_heal", 0)))
	if it.has("bound"):
		out.append("Signature piece: never lost or salvaged")
	return out


## ---------------------------------------------------------------- bond perks
## Per pet: 3 levels x 2 choices. "mul"/"add" change the pet's ability numbers,
## "fx" adds to the same keys pet gear uses.
const PERKS := {
	"noel": [
		[{"id": "bodyguard", "name": "Bodyguard", "desc": "6% less damage near Noel", "fx": {"guard": 0.06}},
		 {"id": "bloodhound", "name": "Bloodhound", "desc": "Rampage hits 25% harder", "mul": {"rampage_aoe_damage": 1.25}}],
		[{"id": "long_grudge", "name": "Long Grudge", "desc": "Rampage lingers 1.5s longer", "add": {"rampage_linger": 1.5}},
		 {"id": "fast_feet", "name": "Fast Feet", "desc": "Rampage and follow speed +15%", "mul": {"rampage_speed_mult": 1.15, "follow_speed": 1.15}}],
		[{"id": "pack_leader", "name": "Pack Leader", "desc": "Rampage chains to 2 more", "add": {"rampage_chain": 2}},
		 {"id": "last_line", "name": "Last Line", "desc": "10% less damage near Noel", "fx": {"guard": 0.1}}],
	],
	"bentley": [
		[{"id": "keen_nose", "name": "Keen Nose", "desc": "Good and great finds 40% likelier", "mul": {"gift_good": 1.4, "gift_great": 1.4}},
		 {"id": "loud_mouth", "name": "Loud Mouth", "desc": "Bark reaches 30% farther", "mul": {"bark_radius": 1.3}}],
		[{"id": "lucky_find", "name": "Lucky Find", "desc": "+30% loot find", "fx": {"luck": 0.3}},
		 {"id": "harrier", "name": "Harrier", "desc": "Barked foes +10% damage, distracted longer", "add": {"bark_mark_mult": 0.1, "bark_distract_sec": 0.6}}],
		[{"id": "treasure_hound", "name": "Treasure Hound", "desc": "Finds come 35% faster", "mul": {"find_cooldown": 0.65}},
		 {"id": "spotter", "name": "Spotter", "desc": "Calls out elites, 5% dodge", "fx": {"reveal": 1.0, "dodge": 0.05}}],
	],
	"lillie": [
		[{"id": "thick_skull", "name": "Thick Skull", "desc": "Headbutt hits 25% harder", "mul": {"ram_impact_damage": 1.25}},
		 {"id": "bulwark", "name": "Bulwark", "desc": "6% less damage near Lillie", "fx": {"guard": 0.06}}],
		[{"id": "battering_ram", "name": "Battering Ram", "desc": "Headbutt every 20% sooner", "mul": {"ram_cooldown": 0.8}},
		 {"id": "big_stun", "name": "Big Stun", "desc": "Headbutt stuns 0.4s longer", "add": {"ram_stun": 0.4}}],
		[{"id": "stampede", "name": "Stampede", "desc": "Blast 35% wider, knocks harder", "mul": {"ram_impact_radius": 1.35, "ram_knock": 1.3}},
		 {"id": "iron_hide", "name": "Iron Hide", "desc": "10% less damage, thorns 10", "fx": {"guard": 0.1, "thorns": 10.0}}],
	],
	"mech_hound": [
		[{"id": "overcharged", "name": "Overcharged Cells", "desc": "Shock arcs hit 30% harder", "mul": {"shock_damage": 1.3}},
		 {"id": "hydraulics", "name": "Hydraulic Legs", "desc": "Pounce every 20% sooner", "mul": {"ram_cooldown": 0.8}}],
		[{"id": "arc_relay", "name": "Arc Relay", "desc": "Shock chains to 2 more", "add": {"shock_chain": 2}},
		 {"id": "plated_frame", "name": "Plated Frame", "desc": "6% less damage near it", "fx": {"guard": 0.06}}],
		[{"id": "tesla_bite", "name": "Tesla Bite", "desc": "Bites +30%, thorns 12 dps", "mul": {"bite_damage": 1.3}, "fx": {"thorns": 12.0}},
		 {"id": "servo_overdrive", "name": "Servo Overdrive", "desc": "Pounce impact +40%", "mul": {"ram_impact_damage": 1.4}}],
	],
	"drone_bat": [
		[{"id": "extended_mag", "name": "Extended Mag", "desc": "+2 shots per strafe", "add": {"strafe_shots": 2}},
		 {"id": "targeting_lens", "name": "Targeting Lens", "desc": "Marks +8% damage taken", "add": {"strafe_mark_mult": 0.08}}],
		[{"id": "afterburner", "name": "Afterburner", "desc": "Strafes 25% sooner", "mul": {"strafe_cooldown": 0.75}},
		 {"id": "scanner_array", "name": "Scanner Array", "desc": "Elites called out, +15% loot find", "fx": {"reveal": 1.0, "luck": 0.15}}],
		[{"id": "hellfire", "name": "Hellfire Rounds", "desc": "Strafe damage +50%", "mul": {"strafe_damage": 1.5}},
		 {"id": "aerial_cover", "name": "Aerial Cover", "desc": "8% dodge near the drone", "fx": {"dodge": 0.08}}],
	],
	"rust_mule": [
		[{"id": "heavy_shells", "name": "Heavy Shells", "desc": "Mortar +30% damage", "mul": {"mortar_damage": 1.3}},
		 {"id": "cargo_rack", "name": "Cargo Rack", "desc": "+1 backpack room", "add": {"pack_bonus": 1}}],
		[{"id": "quick_loader", "name": "Quick Loader", "desc": "Mortar every 25% sooner", "mul": {"mortar_cooldown": 0.75}},
		 {"id": "wide_bore", "name": "Wide Bore", "desc": "Mortar blast 25% wider", "mul": {"mortar_radius": 1.25}}],
		[{"id": "twin_tubes", "name": "Twin Tubes", "desc": "Mortar +50% damage", "mul": {"mortar_damage": 1.5}},
		 {"id": "pack_mule", "name": "Pack Mule", "desc": "+2 pack room, 5% less damage", "add": {"pack_bonus": 2}, "fx": {"guard": 0.05}}],
	],
}


static func perks_for(pet_id: String) -> Array:
	if PERKS.has(pet_id):
		return PERKS[pet_id]
	if pet_id == "drone_hawk":
		return PERKS["drone_bat"]
	return PERKS["noel"]


## Picked perk dicts for a pet given {"3": 0|1, ...}.
static func picked(pet_id: String, picks: Dictionary) -> Array:
	var out: Array = []
	var tree := perks_for(pet_id)
	for i in range(PERK_LEVELS.size()):
		var key := str(PERK_LEVELS[i])
		if picks.has(key):
			out.append(tree[i][clampi(int(picks[key]), 0, 1)])
	return out


## Pet def with the picked perks' mul / add applied.
static func apply_perks(pet: Dictionary, pet_id: String, picks: Dictionary) -> Dictionary:
	var p := pet.duplicate(true)
	for pk in picked(pet_id, picks):
		var mul: Dictionary = pk.get("mul", {})
		for k in mul.keys():
			if p.has(k):
				p[k] = float(p[k]) * float(mul[k])
		var add: Dictionary = pk.get("add", {})
		for k in add.keys():
			if p.has(k):
				p[k] = (int(p[k]) + int(add[k])) if typeof(p[k]) == TYPE_INT else float(p[k]) + float(add[k])
	return p
