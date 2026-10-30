extends RefCounted

## Crafter Bench (Hangar): craft-only 6-piece armor sets that never drop.
## Difficulty ~6/10: the bench opens after a Blight extract, each later set needs
## a bench rank (Shroud / Blackout extracts), and a full set is roughly 15-25
## focused runs of the materials below (bot yields per extract at T6-T8, ~200
## kills: ~10 Plague Gland, ~10 Machine Oil, ~7 Dust Shard, ~7 Salvage Core,
## ~0.6 Dust Heart from Mutant Overlords). Scrap costs sit inside the Bunker v6
## economy (a piece is ~1 run of scrap at the tier you farm it on).

const BENCH_ID := "crafter"
## Bench rank n unlocks SETS with "bench" n. Prices + the tier you must have
## extracted from before buying that rank.
const BENCH_PRICES: Array = [1200, 2800, 5000]
const BENCH_GATE: Array = [5, 6, 8]

## Materials crafting reads (pouch ingredients + banked boss materials), with
## where each one drops for the recipe screen.
const SOURCES := {
	"salvage_core": "War machines (any tier); machine elites carry 1, machine bosses 3; Dread-Naught.",
	"machine_oil": "War machines (any tier); bosses carry 2.",
	"dust_shard": "Every elite (1) and boss (3); machines now and then.",
	"plague_gland": "Plague creatures (any tier); bosses carry 2.",
	"herb": "Plague creatures and broken crates (Ashroot).",
	"dust_heart": "Mutant Overlord, the zone boss from Blight up.",
}

const SETS := {
	"rustwright": {
		"name": "Rustwright's Harness", "noun": "Rustwright", "bench": 1, "color": Color("4d6b73"),
		"lore": "Juno's rig for working on live war machines: insulated plates bolted from the things that tried to kill her.",
		"bonus": ["+12% damage", "Machines take 25% more from you and hit you 20% softer",
			"Overcharge: every 12th kill sends out a shock nova that stuns"],
		"damage": 0.12, "machine_dealt": 1.25, "machine_taken": 0.8,
		"nova_every": 12, "nova_radius": 140.0, "nova_damage": 28.0, "nova_stun": 0.8,
		"cost": {"scrap": 900, "salvage_core": 16, "machine_oil": 10, "dust_shard": 4},
	},
	"ashwalker": {
		"name": "Ashwalker's Shroud", "noun": "Ashwalker", "bench": 2, "color": Color("5e4a3a"),
		"lore": "Cinder's mourners walked the plague pits in this. It drinks the sickness so you don't have to.",
		"bonus": ["Regenerate 1 HP every 2s", "Plague creatures hit you 30% softer",
			"Ash Bloom: kills leave a poison cloud for 3s"],
		"regen": 1.0, "regen_every": 2.0, "plague_taken": 0.7,
		"bloom_radius": 70.0, "bloom_time": 3.0, "bloom_dps": 10.0,
		"cost": {"scrap": 1300, "plague_gland": 16, "herb": 6, "dust_shard": 6, "dust_heart": 1},
	},
	"dustborn": {
		"name": "Dustborn Regalia", "noun": "Dustborn", "bench": 3, "color": Color("8a6a2a"),
		"lore": "Cut from Dust that hardened around something old. Whoever wore it last walked out of the storm.",
		"bonus": ["+25 max HP", "+10% crit chance", "Dust Ward: once every 30s, a hit worth a quarter of your HP is blocked"],
		"max_hp": 25.0, "crit": 0.1, "ward_cd": 30.0, "ward_frac": 0.25,
		"cost": {"scrap": 2000, "dust_shard": 12, "salvage_core": 10, "plague_gland": 10, "dust_heart": 2},
	},
}
const ORDER: Array = ["rustwright", "ashwalker", "dustborn"]


static func is_craft_set(sid: String) -> bool:
	return SETS.has(sid)


static func cost(sid: String) -> Dictionary:
	return (SETS.get(sid, {}) as Dictionary).get("cost", {})


## Full-set totals (6 pieces) for the report / recipe screen.
static func set_total_cost(sid: String) -> Dictionary:
	var out := {}
	var c := cost(sid)
	for k in c.keys():
		out[k] = int(c[k]) * 6
	return out
