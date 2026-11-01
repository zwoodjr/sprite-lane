extends RefCounted

## Scrap sinks for a maxed bunker (Hangar · Stash · Crew):
##   1. OVERDRIVE: uncapped permanent +1% upgrades, geometric prices.
##   2. Workbench: reroll one item's stats or raise its tier (Stash item card).
##   3. Supply crates: fixed price, random gear / pet item / cosmetic, odds shown.
##   4. Next-run supplies: one-run consumables bought before deploying (Crew).
## Pure data + math (no GameState): GameState owns the save side.

## ---------------------------------------------------------------- Overdrive
## cost(level) = base * GROWTH^level, rounded to 10. Tuned so 30k scrap buys
## about 5-6 levels across all six tracks (or ~12 in one): never an end.
const ENDLESS_GROWTH := 1.25
const ENDLESS_COST_CAP := 1000000000000000 ## 1e15: past ~level 115 it stops growing (no int overflow)
const ENDLESS_ORDER: Array = ["damage", "defense", "vitality", "speed", "magnet", "scrap"]
const ENDLESS := {
	"damage": {"name": "Hot Loads", "icon": "up_harder_hit", "per": 0.01, "base": 500, "fmt": "+%d%% damage"},
	"defense": {"name": "Plate Liner", "icon": "up_thick_plate", "per": 0.01, "base": 500, "fmt": "-%d%% damage taken"},
	"vitality": {"name": "Field Rations", "icon": "tonic_menders", "per": 0.01, "base": 400, "fmt": "+%d%% max HP"},
	"speed": {"name": "Light Boots", "icon": "up_dust_runner", "per": 0.01, "base": 400, "fmt": "+%d%% move speed"},
	"magnet": {"name": "Long Reach", "icon": "up_scavengers_eye", "per": 0.01, "base": 300, "fmt": "+%d%% pickup range"},
	"scrap": {"name": "Sharp Eye", "icon": "camp_scrap_press", "per": 0.01, "base": 600, "fmt": "+%d%% scrap found"},
}
## Pickup range is a px bonus in-game: 1% = this many px (about 1% of a magnet).
const MAGNET_PX_PER_LEVEL := 2.0


static func endless_cost(id: String, level: int) -> int:
	var d: Dictionary = ENDLESS.get(id, {})
	if d.is_empty() or level < 0:
		return -1
	var c := float(d["base"]) * pow(ENDLESS_GROWTH, float(level))
	if c >= float(ENDLESS_COST_CAP):
		return ENDLESS_COST_CAP
	return maxi(10, int(round(c / 10.0)) * 10)


## Total paid for levels 0..n-1.
static func endless_total(id: String, n: int) -> int:
	var t := 0
	for i in range(maxi(0, n)):
		t += endless_cost(id, i)
	return t


## Bonus fraction at `level` (+1% per level; defense is applied as 0.99^n).
static func endless_value(id: String, level: int) -> float:
	return float(ENDLESS.get(id, {}).get("per", 0.0)) * float(maxi(0, level))


static func endless_text(id: String, level: int) -> String:
	var d: Dictionary = ENDLESS.get(id, {})
	if d.is_empty():
		return ""
	return str(d["fmt"]) % int(round(endless_value(id, level) * 100.0))


## ---------------------------------------------------------------- Workbench
## Scale with the item's tier (rarity). Upgrade = price to reach the NEXT tier.
const REROLL_COST := {"common": 150, "rare": 400, "epic": 1000, "legendary": 2500}
const UPGRADE_COST := {"common": 600, "rare": 2000, "epic": 6000}
## Pet gear tops out at Epic by upgrade (the Legendary is the crafted War-Dog Rig).
const PET_UPGRADE_MAX := "epic"


static func reroll_cost(rarity: String) -> int:
	return int(REROLL_COST.get(rarity, -1))


static func upgrade_cost(rarity: String) -> int:
	return int(UPGRADE_COST.get(rarity, -1))


static func next_rarity(rarity: String) -> String:
	var r: Array = ["common", "rare", "epic", "legendary"]
	var i := r.find(rarity)
	return str(r[i + 1]) if i >= 0 and i < r.size() - 1 else ""


## ---------------------------------------------------------------- Crates
## Every number here is shown on the card (ODDS) and is exactly what rolls.
## "gear" / "pet" / "cosmetic" = what kind of drop; "rarity" = gear and pet item
## rarity odds (pet items stop at Epic: a Legendary roll gives an Epic one).
## A cosmetic you already own (all five) pays back COSMETIC_DUP_REFUND of the price.
const CRATE_ORDER: Array = ["scav", "kennel", "hardened", "relic"]
const CRATES := {
	"scav": {"name": "Scav Crate", "icon": "hud_loot", "price": 1200,
		"kind": {"gear": 80, "pet": 15, "cosmetic": 5},
		"rarity": {"common": 55, "rare": 35, "epic": 9, "legendary": 1}},
	"kennel": {"name": "Kennel Crate", "icon": "tab_kennel", "price": 2500,
		"kind": {"pet": 85, "cosmetic": 15},
		"rarity": {"rare": 70, "epic": 30}},
	"hardened": {"name": "Hardened Crate", "icon": "camp_stash", "price": 3500,
		"kind": {"gear": 75, "pet": 18, "cosmetic": 7},
		"rarity": {"rare": 65, "epic": 30, "legendary": 5}},
	"relic": {"name": "Relic Crate", "icon": "mat_dust_heart", "price": 9000,
		"kind": {"gear": 85, "pet": 7, "cosmetic": 8},
		"rarity": {"epic": 80, "legendary": 20}},
}
const COSMETIC_IDS: Array = ["banner", "flag", "campfire", "toys", "case"]
const COSMETIC_NAME := {"banner": "Bunker Banner", "flag": "Crew Flag", "campfire": "Campfire",
	"toys": "Dog Toys", "case": "Trophy Case"}
const COSMETIC_DUP_REFUND := 0.5


static func crate_price(cid: String) -> int:
	return int(CRATES.get(cid, {}).get("price", -1))


## Weighted pick from an {id: weight} table.
static func pick(table: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in table.keys():
		total += float(table[k])
	var roll := rng.randf() * total
	for k in table.keys():
		roll -= float(table[k])
		if roll < 0.0:
			return str(k)
	return str(table.keys()[table.size() - 1])


## "Gear 80% · Pet 15% · Cosmetic 5%" / "Common 55% · Rare 35% ...".
static func odds_line(table: Dictionary) -> String:
	var total := 0.0
	for k in table.keys():
		total += float(table[k])
	var parts: PackedStringArray = []
	var nm := {"gear": "Gear", "pet": "Pet item", "cosmetic": "Cosmetic", "common": "Common", "rare": "Rare",
		"epic": "Epic", "legendary": "Legendary"}
	for k in table.keys():
		parts.append("%s %s%%" % [str(nm.get(k, k)), _pct(100.0 * float(table[k]) / total)])
	return " · ".join(parts)


static func _pct(v: float) -> String:
	return "%d" % int(round(v)) if absf(v - roundf(v)) < 0.05 else "%.1f" % v


## ---------------------------------------------------------------- Supplies
## Bought before deploying; each one is used up by the next Wander run (Daily
## and Campaign runs leave it armed). One of each per run.
const SUPPLY_ORDER: Array = ["medkit", "plate", "head_start", "charm"]
const SUPPLIES := {
	"medkit": {"name": "Med Kit", "icon": "ing_medicine", "price": 300,
		"desc": "Once per run: heals 50% HP when a hit leaves you under 30%", "heal": 0.5, "below": 0.3},
	"plate": {"name": "Armor Plate", "icon": "gear_chest_2", "price": 400,
		"desc": "Take 15% less damage all run", "taken": 0.85},
	"head_start": {"name": "Head Start", "icon": "cur_level", "price": 500,
		"desc": "Drop in at run level 2: one upgrade pick at once"},
	"charm": {"name": "Scrap Charm", "icon": "gear_charm_1", "price": 450,
		"desc": "+15% scrap found this run", "scrap": 0.15},
}


static func supply_price(sid: String) -> int:
	return int(SUPPLIES.get(sid, {}).get("price", -1))


## Short price for buttons: 950 / 12,400 / 1.2M.
static func short_num(n: int) -> String:
	if n >= 1000000000000:
		return "%.1fT" % (float(n) / 1e12)
	if n >= 1000000000:
		return "%.1fB" % (float(n) / 1e9)
	if n >= 1000000:
		return "%.1fM" % (float(n) / 1e6)
	if n >= 100000:
		return "%dK" % floori(float(n) / 1000.0)
	return "%d" % n
