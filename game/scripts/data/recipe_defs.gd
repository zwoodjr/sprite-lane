class_name RecipeDefs
extends RefCounted

## Depth Update E3 — recipes (evolutions). An upgrade at max rank + its partner
## (any rank) unlock a named evolved upgrade, offered as a gold card. Every
## shared upgrade is in at least one recipe; each survivor has a class recipe.
## Partner "ammo:shock" means: picked up Shock special ammo this run.
## Evolution cards are plain upgrade dicts (rarity "evolution", max_rank 1) so
## GameState.apply_run_upgrade / GameState.up() handle them like any card.

const COLOR := Color(1.0, 0.78, 0.25)
## An eligible evolution always takes one of the level-up slots.
const GUARANTEE_SLOT := true

const RECIPES: Array = [
	{"id": "plague_bloom", "name": "Plague Bloom", "needs": ["dust_rounds", "spore_mines"],
		"desc": "Poisoned foes burst into poison clouds when they die; spore mines hit 50% harder and wider.",
		"ranks": [{"cloud_r": 70.0, "cloud_time": 3.5, "cloud_dps": 14.0, "mine_mult": 1.5}]},
	{"id": "arc_storm", "name": "Arc Storm", "needs": ["ricochet", "ammo:shock"],
		"desc": "Shots bounce twice more and every hit can arc lightning to a nearby enemy (stuns).",
		"ranks": [{"bounces": 2, "chance": 0.45, "range": 170.0, "mult": 0.5, "stun": 0.35}]},
	{"id": "blade_storm", "name": "Blade Storm", "needs": ["orbit_blades", "piercing"],
		"desc": "Twice the orbiting blades, and they fling shards in every direction.",
		"ranks": [{"count_mult": 2, "shard_every": 1.1, "shards": 8, "shard_mult": 0.5}]},
	{"id": "lead_rain", "name": "Lead Rain", "needs": ["split_shot", "quick_mag"],
		"desc": "Every shot is a three-round fan (split shots fire seven). Melee: every swing slashes twice.",
		"ranks": [{"count": 3, "split_count": 7, "fan_deg": 9.0}]},
	{"id": "hellfire_stride", "name": "Hellfire Stride", "needs": ["firewalk", "dust_runner"],
		"desc": "You leave a fire trail wherever you walk; fire burns 50% hotter.",
		"ranks": [{"burn_mult": 1.5}]},
	{"id": "phoenix", "name": "Phoenix Draught", "needs": ["second_wind", "firewalk"],
		"desc": "Every dash heals more and bursts into a fire nova.",
		"ranks": [{"heal": 6.0, "radius": 110.0, "damage": 30.0}]},
	{"id": "bulwark", "name": "Bulwark", "needs": ["thick_plate", "iron_tonic"],
		"desc": "The tonic shield recharges in 4s and a blocked hit blasts everything back.",
		"ranks": [{"recharge": 4.0, "radius": 120.0, "damage": 25.0}]},
	{"id": "deadeye", "name": "Deadeye", "needs": ["harder_hit", "cool_head"],
		"desc": "+20% crit chance and crits hit 75% harder.",
		"ranks": [{"crit": 0.2, "crit_damage": 0.75}]},
	{"id": "hive", "name": "Hive", "needs": ["scrap_drone", "deep_mag"],
		"desc": "One more drone, and every drone fires 50% faster.",
		"ranks": [{"drones": 1, "rate": 0.5}]},
	{"id": "fortune", "name": "Fortune's Favor", "needs": ["scavengers_eye", "lucky_vial"],
		"desc": "+50% scrap and kills sometimes drop special ammo.",
		"ranks": [{"scrap": 0.5, "ammo_chance": 0.05}]},
	## --- Class recipes ---
	{"id": "earthquake", "name": "Earthquake", "hero": "ash_rook", "needs": ["aftershock", "rubble_wall"],
		"desc": "RUSH shakes the ground as you go; the Aftershock hits 50% harder.",
		"ranks": [{"every": 0.25, "radius": 75.0, "damage": 18.0, "aftershock_mult": 1.5}]},
	{"id": "death_knell", "name": "Death Knell", "hero": "vesper_thorn", "needs": ["bell_tower", "marked"],
		"desc": "Marked enemies explode when they die; Bell Tower charges higher.",
		"ranks": [{"radius": 90.0, "damage": 40.0, "bell_cap": 0.5}]},
	{"id": "mountain", "name": "The Mountain", "hero": "pebble", "needs": ["quarry_slam", "unbreakable"],
		"desc": "Quarry Slam every 2nd swing, and each slam halves damage taken for 2s.",
		"ranks": [{"every": 2, "guard": 2.0}]},
	{"id": "thunderhead", "name": "Thunderhead", "hero": "bolt_juno", "needs": ["live_wire", "short_circuit"],
		"desc": "OVERLOAD leaves a storm around you that zaps enemies for 5s.",
		"ranks": [{"time": 5.0, "every": 0.35, "range": 210.0, "mult": 0.6, "stun": 0.3}]},
	{"id": "cathedral_fire", "name": "Cathedral Fire", "hero": "sister_cinder", "needs": ["sanctuary", "burn_it_down"],
		"desc": "Healing puddles also burn every enemy that steps in.",
		"ranks": [{"dps": 18.0}]},
	{"id": "autopsy_table", "name": "Autopsy Table", "hero": "quill_marrow", "needs": ["field_notes", "bayonet"],
		"desc": "Bayonet stabs mark their target; Field Notes cap rises by half.",
		"ranks": [{"mark": 1.3, "mark_time": 3.0, "cap_mult": 1.5}]},
	{"id": "ghost_debt", "name": "Ghost Debt", "hero": "nyx_caldera", "needs": ["double_cross", "back_way_out"],
		"desc": "For 2s after a dash every hit counts as from behind.",
		"ranks": [{"time": 2.0}]},
	{"id": "air_raid", "name": "Air Raid", "hero": "helm_wisp", "needs": ["squadron", "wingman"],
		"desc": "Every 6s each drone fires a missile at the nearest enemy.",
		"ranks": [{"every": 6.0, "radius": 70.0, "damage": 34.0}]},
]


static var _cards: Array = []


## Evolution recipes as upgrade cards.
static func all() -> Array:
	if _cards.is_empty():
		for r in RECIPES:
			var c: Dictionary = (r as Dictionary).duplicate(true)
			c["rarity"] = "evolution"
			c["tags"] = ["Evolution"] + (["Class"] if c.has("hero") else [])
			c["max_rank"] = 1
			c["evolution"] = true
			c["desc"] = [str(r["desc"])]
			_cards.append(c)
	return _cards


static func get_recipe(id: String) -> Dictionary:
	for c in all():
		if str(c["id"]) == id:
			return c
	return {}


static func part_name(id: String) -> String:
	if id == "ammo:shock":
		return "Shock ammo"
	return str(UpgradeDefs.get_def(id).get("name", id))


## Recipes this upgrade leads toward (as base or partner), for this hero.
static func recipes_for(upgrade_id: String, hero: String) -> Array:
	var out: Array = []
	for c in all():
		if c.has("hero") and str(c["hero"]) != hero:
			continue
		if upgrade_id in (c["needs"] as Array):
			out.append(c)
	return out
