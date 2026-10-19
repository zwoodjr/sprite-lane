class_name MedicineDefs
extends RefCounted

## Depth Update E1 — medicine & plague. Every tuning number lives here.
##   Ingredients drop in runs (kept only on extract) and are brewed into tonics
##   at Cinder's Apothecary (Hangar BREW tab). Tonics in the slots are drunk on
##   deploy and last the whole run.
##   Medicine crates are the richest loot in a run: heavy, they slow you and
##   the plague can smell them. The backpack limits what you carry home.
##   Plague exposure (tier 5+) builds in plague fog and from plague hits.

const ICON_DIR := "res://assets/sprites/depth/icons/"

## --- Ingredients --------------------------------------------------------------
const INGREDIENT_IDS: Array = ["herb", "plague_gland", "dust_shard", "machine_oil"]
const INGREDIENTS := {
	"herb": {"name": "Ashroot", "icon": "herb", "weight": 0, "color": Color(0.55, 0.85, 0.45),
		"desc": "A bitter root that still grows in the cracks."},
	"plague_gland": {"name": "Plague Gland", "icon": "plague_gland", "weight": 0, "color": Color(0.85, 0.55, 0.75),
		"desc": "Cut from plague-twisted things. Cinder knows what to do with it."},
	"dust_shard": {"name": "Dust Shard", "icon": "dust_shard", "weight": 0, "color": Color(1.0, 0.75, 0.35),
		"desc": "Hard amber Dust. Elites and bosses carry the most."},
	"machine_oil": {"name": "Machine Oil", "icon": "machine_oil", "weight": 0, "color": Color(0.7, 0.75, 0.85),
		"desc": "Black oil drained from war machines."},
	"medicine": {"name": "Medicine", "icon": "medicine", "weight": 3, "color": Color(1.0, 0.45, 0.4),
		"desc": "Real medicine. The most valuable thing left."},
}
## Kill drops by faction (chance per kill, per ingredient). Elites / bosses add ROLE_DROP.
const KILL_DROP := {
	"plague": {"plague_gland": 0.10, "herb": 0.04},
	"machine": {"machine_oil": 0.10, "dust_shard": 0.015},
	"raider": {"herb": 0.07, "machine_oil": 0.05},
}
const ROLE_DROP := {"elite": {"dust_shard": 1}, "boss": {"dust_shard": 3, "plague_gland": 2, "machine_oil": 2}}
## Breakable crates sometimes hold a herb.
const CRATE_HERB_CHANCE := 0.3
## Herb Bloom event herbs also go to the pack (one each).

## --- Medicine crates ------------------------------------------------------------
const MEDICINE_WEIGHT := 3
## Extract pays this much bag value per crate (× loot multiplier × tier payout),
## and the crate is banked as 1 medicine (top tonic recipes need it).
const MEDICINE_SCRAP := 60
## Carrying any medicine slows you; each extra crate a bit more, capped.
const CARRY_SLOW := 0.12
const CARRY_SLOW_EXTRA := 0.03
const CARRY_SLOW_CAP := 0.18
## The plague smells it: faster spawns, plague mobs move faster toward you.
const SMELL_SPAWN_MULT := 0.8
const SMELL_PLAGUE_SPEED := 1.15
## Ingredients ride in a weightless pouch (weight 0); only medicine fills the backpack.
## Medicine turns up over the run: a few crates at the drop-in, then one more is
## marked each time an extract window opens, up to the tier's total.
const CRATES_AT_START: Array = [1, 1, 1, 1, 2, 2, 2, 2, 3, 3]
const CRATES_PER_WINDOW := 1
const CRATES_BY_TIER: Array = [3, 4, 4, 5, 5, 6, 6, 7, 7, 8]
const WINDOW_CRATE_DIST := Vector2(520.0, 1000.0)
const CRATE_DIST_MIN := 650.0
const CRATE_DIST_MAX := 1500.0
const CRATE_PICK_R := 36.0
const ELITE_MEDICINE_CHANCE := 0.35
const BOSS_MEDICINE := 1

## --- Backpack -------------------------------------------------------------------
## Three crates fill the base pack (≈ the 2nd–3rd window on Drift); each rank fits one more.
const PACK_BASE := 9
const PACK_PER_RANK := 3
const PACK_PRICES: Array = [200, 450, 800]

## --- Tonics ---------------------------------------------------------------------
## fx keys: regen (HP/s), max_hp, move, exposure_mult, plague_resist (damage taken
## from plague mobs), vs_plague / vs_machine (damage dealt), channel_mult
## (extract channel time), carry_free (medicine doesn't slow / isn't smelled).
const TONIC_IDS: Array = ["menders", "iron", "ward", "firebrand", "spark", "quickstep", "saints"]
const TONICS := {
	"menders": {"name": "Mender's Draught", "recipe": {"herb": 3}, "fx": {"regen": 1.2},
		"desc": "Regenerate 1.2 HP every second all run."},
	"iron": {"name": "Iron Draught", "recipe": {"herb": 2, "dust_shard": 1}, "fx": {"max_hp": 20.0},
		"desc": "+20 max HP for the run."},
	"ward": {"name": "Plague Ward", "recipe": {"herb": 2, "plague_gland": 2}, "fx": {"exposure_mult": 0.5, "plague_resist": 0.15},
		"desc": "Plague exposure builds half as fast; plague hits 15% weaker."},
	"firebrand": {"name": "Firebrand", "recipe": {"plague_gland": 3, "machine_oil": 1}, "fx": {"vs_plague": 0.25},
		"desc": "+25% damage against plague creatures."},
	"spark": {"name": "Spark Tonic", "recipe": {"machine_oil": 3, "dust_shard": 1}, "fx": {"vs_machine": 0.25},
		"desc": "+25% damage against war machines."},
	"quickstep": {"name": "Quickstep", "recipe": {"herb": 2, "machine_oil": 2}, "fx": {"channel_mult": 0.6, "move": 0.06},
		"desc": "Extract channel 40% faster, +6% move speed."},
	"saints": {"name": "Saint's Tincture", "recipe": {"dust_shard": 2, "plague_gland": 1, "medicine": 1},
		"fx": {"carry_free": 1.0, "exposure_mult": 0.75},
		"desc": "Medicine weighs nothing and the plague can't smell it; exposure −25%."},
}
## Tonic slots: 1, +1 once Cinder's Medicine Table reaches rank 2. Rank 4 brews two.
const TONIC_SLOTS_BASE := 1
const TONIC_SLOT_RANK := 2
const DOUBLE_BREW_RANK := 4

## --- Plague exposure (tier 5+) --------------------------------------------------
const EXPOSURE_FROM_TIER := 5
const EXPOSURE_MAX := 100.0
const ZONE_RATE := 9.0        ## per second inside plague fog
const HIT_GAIN := 6.0         ## per hit from a plague creature
const DECAY := 1.2            ## per second outside fog
const STAGES: Array = [
	{"at": 40.0, "name": "Feverish", "move": -0.08, "firerate": -0.10, "dps": 0.0},
	{"at": 70.0, "name": "Sick", "move": -0.14, "firerate": -0.18, "dps": 1.5},
	{"at": 100.0, "name": "Plague-struck", "move": -0.2, "firerate": -0.25, "dps": 5.0},
]
## Cinder resists it; her heal cleanses; health tonics cleanse a little.
const CINDER_EXPOSURE_MULT := 0.75
const CINDER_HEAL_CLEANSE := 35.0
const TONIC_PICKUP_CLEANSE := 8.0
## Gear resist (Vials, Plague Doctor) also slows exposure 1:1, capped.
const GEAR_RESIST_CAP := 0.5
## Plague fog patches: how many per minute, radius, life, max alive.
const ZONES_PER_MIN := 1.6
const ZONE_RADIUS := Vector2(110.0, 170.0)
const ZONE_LIFE := 45.0
const ZONES_MAX := 3
const ZONE_DIST := Vector2(260.0, 620.0)


static func icon_path(id: String) -> String:
	var d: Dictionary = INGREDIENTS.get(id, {})
	if d.is_empty():
		if TONICS.has(id):
			return ICON_DIR + "tonic_%s.png" % id
		return ICON_DIR + id + ".png"
	return ICON_DIR + str(d["icon"]) + ".png"


static func item_name(id: String) -> String:
	if INGREDIENTS.has(id):
		return str(INGREDIENTS[id]["name"])
	if TONICS.has(id):
		return str(TONICS[id]["name"])
	return id


static func weight(id: String) -> int:
	return int((INGREDIENTS.get(id, {}) as Dictionary).get("weight", 0))


static func pack_capacity(rank: int) -> int:
	return PACK_BASE + PACK_PER_RANK * clampi(rank, 0, PACK_PRICES.size())


static func tonic_slots(cinder_rank: int) -> int:
	return TONIC_SLOTS_BASE + (1 if cinder_rank >= TONIC_SLOT_RANK else 0)


static func brew_yield(cinder_rank: int) -> int:
	return 2 if cinder_rank >= DOUBLE_BREW_RANK else 1


static func crates_for_tier(tier: int) -> int:
	return int(CRATES_BY_TIER[clampi(tier, 1, CRATES_BY_TIER.size()) - 1])


static func crates_at_start(tier: int) -> int:
	return int(CRATES_AT_START[clampi(tier, 1, CRATES_AT_START.size()) - 1])


## Pouch items (weightless ingredients).
static func is_pouch(id: String) -> bool:
	return weight(id) == 0


## Speed multiplier while carrying `n` medicine crates.
static func carry_mult(n: int) -> float:
	if n <= 0:
		return 1.0
	return 1.0 - minf(CARRY_SLOW + CARRY_SLOW_EXTRA * float(n - 1), CARRY_SLOW_CAP)


## Exposure stage index for a value (-1 = none).
static func stage_of(v: float) -> int:
	var s := -1
	for i in range(STAGES.size()):
		if v >= float(STAGES[i]["at"]):
			s = i
	return s


static func recipe_text(tid: String) -> String:
	var parts: PackedStringArray = []
	var r: Dictionary = (TONICS.get(tid, {}) as Dictionary).get("recipe", {})
	for k in r.keys():
		parts.append("%d %s" % [int(r[k]), item_name(str(k))])
	return " + ".join(parts)
