class_name ZoneDefs
extends RefCounted

## Depth Update E7 — tiers 3–10 as a journey outward. Each tier is a zone with
## its own ground (tools/gen_zone_tiles.py), props (tools/gen_depth_art.py e7)
## and a twist; Dustfall stacks every twist. Also: tier-exclusive loot, per-survivor
## tier-clear trophies, Dust Pacts and Helm's plane parts. All tuning lives here.

## Zone per tier (index tier-1). "twists" are run by scripts/match/zone_twists.gd.
## "grade": ground texture set suffix ("" = the original wasteland).
## "props": zone props rolled into each chunk (art in assets/sprites/depth/zone/).
const ZONES: Array = [
	{"id": "haze", "name": "The Haze", "grade": "", "twists": [], "props": []},
	{"id": "drift", "name": "The Drift", "grade": "", "twists": [], "props": []},
	{"id": "smog", "name": "Old Refinery", "grade": "refinery", "twists": ["smog", "bunkers"],
		"props": ["oil_tank", "pipe_rack"], "tint": Color(0.86, 0.84, 0.8)},
	{"id": "pall", "name": "Dead City", "grade": "city", "twists": ["night", "wraith_phase"],
		"props": ["street_lamp", "shop_ruin"], "tint": Color(0.78, 0.8, 0.9)},
	{"id": "blight", "name": "Quarantine Zone", "grade": "quarantine", "twists": ["infected_burst"],
		"props": ["quarantine_tent", "hazard_barrier"], "tint": Color(0.86, 0.92, 0.8)},
	{"id": "shroud", "name": "Raider Territory", "grade": "raider", "twists": ["shroud", "raider_hunt"],
		"props": ["spike_barricade", "raider_totem"], "tint": Color(0.95, 0.84, 0.78)},
	{"id": "choke", "name": "Chemical Plant", "grade": "chemical", "twists": ["toxic_air"],
		"props": ["chem_vat", "pipe_rack"], "tint": Color(0.92, 0.94, 0.74)},
	{"id": "blackout", "name": "Military Base", "grade": "military", "twists": ["power_cells", "machines_enraged"],
		"props": ["tank_wreck", "guard_post"], "tint": Color(0.82, 0.86, 0.84)},
	{"id": "deadfall", "name": "Crater City", "grade": "crater", "twists": ["sinkholes", "rubble_fall", "serpent_ambush", "one_pad", "revive"],
		"props": ["slab_ruin", "shop_ruin"], "tint": Color(0.84, 0.8, 0.78)},
	{"id": "dustfall", "name": "Where the Dust Began", "grade": "dustfall",
		"twists": ["smog", "bunkers", "night", "wraith_phase", "infected_burst", "shroud", "raider_hunt", "toxic_air",
			"power_cells", "machines_enraged", "sinkholes", "rubble_fall", "serpent_ambush", "revive", "dust_storm", "double_boss"],
		"props": ["dust_spire", "slab_ruin", "tank_wreck"], "tint": Color(1.0, 0.86, 0.66)},
]
const PROP_DIR := "res://assets/sprites/depth/zone/%s.png"
## Zone props: [world height px, collision block (0 = walk-through)].
const PROP_INFO := {
	"oil_tank": [150.0, Vector2(96, 26)], "pipe_rack": [110.0, Vector2(0, 0)], "street_lamp": [130.0, Vector2(0, 0)],
	"shop_ruin": [150.0, Vector2(120, 26)], "quarantine_tent": [120.0, Vector2(100, 24)], "hazard_barrier": [70.0, Vector2(90, 16)],
	"spike_barricade": [80.0, Vector2(100, 18)], "raider_totem": [130.0, Vector2(0, 0)], "chem_vat": [130.0, Vector2(70, 24)],
	"tank_wreck": [120.0, Vector2(130, 30)], "guard_post": [150.0, Vector2(64, 22)], "slab_ruin": [110.0, Vector2(110, 24)],
	"dust_spire": [160.0, Vector2(40, 18)],
}
const PROPS_PER_CHUNK := Vector2i(1, 2)

## --- Twist tuning -------------------------------------------------------------
## Smog (Old Refinery): drifting smog patches hide enemies inside them.
const SMOG := {"patches": 4, "radius": Vector2(150.0, 230.0), "dist": Vector2(250.0, 900.0), "reveal": 110.0, "life": 60.0}
## Locked bunkers + keys (elites drop keys; one key in a crate).
const BUNKERS := {"count": 2, "dist": Vector2(700.0, 1300.0), "key_elite_chance": 1.0, "open_r": 46.0,
	"scrap": Vector2i(40, 70), "exclusive_chance": 0.3}
## Night (Dead City): light radius around the hero; flares widen it.
const NIGHT := {"radius": 230.0, "flare_radius": 420.0, "flare_time": 25.0, "flares": 3, "flare_dist": Vector2(300.0, 900.0),
	"dark": 0.86, "dustfall_radius": 320.0}
## Ash-Wraiths phase out (untouchable, faded) for `on` s every `every` s.
const WRAITH_PHASE := {"every": 4.0, "on": 1.2, "kinds": ["ash_wraiths", "apocalypse_wraith", "ash_singer"]}
## Quarantine Zone: infected (plague) mobs sometimes burst into spores on death.
## A smaller pop than the elite "Bloated" trait (no lingering pool worth standing in).
const INFECTED_BURST := {"chance": 0.2, "radius": 70.0, "damage": 8.0, "pool_time": 1.5, "pool_dps": 3.0}
## Shroud (Raider Territory): enemies are unseen beyond `hide` px unless marked.
const SHROUD := {"hide": 300.0, "fade": 90.0, "reveal_time": 4.0}
## A rival raider crew drops in hunting you shortly after the start.
const RAIDER_HUNT_AT := 45.0
## Chemical Plant: the air filter drains; filters (loot) refill it; empty = damage.
## A fresh filter turns up every `respawn` s (up to `max_out` lying around).
const TOXIC_AIR := {"drain": 0.9, "refill": 40.0, "hurt": 5.0, "filters": 3, "filter_dist": Vector2(250.0, 700.0),
	"respawn": 35.0, "max_out": 4}
## Military Base: pads stay dead until you bring a power cell (one appears each window).
const POWER_CELL := {"dist": Vector2(350.0, 650.0)}
const MACHINES_ENRAGED := {"speed": 1.2, "damage": 1.2}
## Crater City.
const SINKHOLES := {"count": 6, "radius": Vector2(60.0, 95.0), "dist": Vector2(250.0, 1400.0), "damage": 0.12, "fling": 160.0, "cd": 1.0}
const RUBBLE_FALL := {"every": 7.0, "count": 2, "radius": 70.0, "delay": 1.0, "damage": 18.0, "near": 220.0}
const SERPENT_AMBUSH := {"first": 60.0, "every": 75.0, "dist": 170.0, "kind": "dune_serpent"}
const REVIVE := {"chance": 0.5, "time": 2.6, "hp": 0.4}
## Dustfall: the storm wall closes in on the drop point over the run.
## Dustfall stacks every twist; each one runs at this strength there (1.0 elsewhere).
const STACK_STRENGTH := 0.6
const DUST_STORM := {"start": 2600.0, "end": 650.0, "hurt": 7.0, "warn": 160.0}

## --- Tier-exclusive loot ---------------------------------------------------------
## One legendary item per tier, only found there (bosses / elites / bunkers).
## "slot" picks the base piece; "stats" are added on top of its rolled stats.
const EXCLUSIVE := {
	3: {"id": "refinery_gasmask", "name": "Refinery Gas Mask", "slot": "head", "stats": {"resist": 0.08, "regen": 0.6}},
	4: {"id": "lamplighter_coat", "name": "Lamplighter's Coat", "slot": "chest", "stats": {"crit": 0.06, "move": 0.05}},
	5: {"id": "quarantine_seal", "name": "Quarantine Seal", "slot": "charm", "stats": {"resist": 0.1, "luck": 0.2}},
	6: {"id": "raider_kingsguard", "name": "Raider Kingsguard Pauldrons", "slot": "shoulders", "stats": {"resist": 0.08, "crit": 0.05}},
	7: {"id": "chem_filter_vial", "name": "Chem-Filter Vial", "slot": "vial", "stats": {"regen": 1.0, "luck": 0.15}},
	8: {"id": "officer_gauntlets", "name": "Officer's Gauntlets", "slot": "hands", "stats": {"firerate": 0.1, "crit": 0.05}},
	9: {"id": "crater_treads", "name": "Crater Treads", "slot": "boots", "stats": {"move": 0.1, "dash_cd": 0.12}},
	10: {"id": "dust_heart_relic", "name": "Dust Heart Relic", "slot": "patch", "stats": {"crit": 0.08, "luck": 0.3, "regen": 0.8}},
}
const EXCLUSIVE_ELITE_CHANCE := 0.06
const EXCLUSIVE_BOSS_CHANCE := 0.3

## --- Dust Pacts (Hades-heat style; stack for a bigger loot multiplier) ---------
## Unlock after the first Smog clear. "loot": added to the extract payout multiplier.
const PACTS_FROM_TIER := 3
const PACTS := {
	"thick_dust": {"name": "Thick Dust", "desc": "Enemies have +25% HP.", "loot": 0.15, "fx": {"enemy_hp": 1.25}},
	"hungry_dark": {"name": "Hungry Dark", "desc": "+25% more enemies.", "loot": 0.15, "fx": {"spawn": 1.25}},
	"sharp_teeth": {"name": "Sharp Teeth", "desc": "Enemies hit 20% harder.", "loot": 0.2, "fx": {"enemy_damage": 1.2}},
	"narrow_windows": {"name": "Narrow Windows", "desc": "Extract windows close 3 s sooner.", "loot": 0.15, "fx": {"window": -3.0}},
	"brittle_bones": {"name": "Brittle Bones", "desc": "-25% max HP.", "loot": 0.25, "fx": {"max_hp": 0.75}},
	"no_mercy": {"name": "No Mercy", "desc": "Enemies drop no healing tonics.", "loot": 0.2, "fx": {"no_tonics": 1.0}},
	"hunted": {"name": "Hunted", "desc": "An elite joins every window.", "loot": 0.25, "fx": {"window_elite": 1.0}},
}

## --- Helm's plane ------------------------------------------------------------------
## First clear of each tier from Smog returns a part; all 8 = the plane flies.
const PLANE_PARTS := {
	3: {"id": "fuselage", "name": "Fuselage"}, 4: {"id": "wings", "name": "Wings"},
	5: {"id": "tail", "name": "Tail Fin"}, 6: {"id": "engine", "name": "Engine"},
	7: {"id": "propeller", "name": "Propeller"}, 8: {"id": "gear", "name": "Landing Gear"},
	9: {"id": "canopy", "name": "Cockpit Canopy"}, 10: {"id": "paint", "name": "Fuel + Paint"},
}
const PLANE_LAYER := "res://assets/sprites/depth/plane/plane_%d.png"
## Where the plane layers sit on the hangar's 1200x750 painted canvas (outside the door).
const PLANE_RECT := Rect2(490, 330, 222, 118)
## Trophies: per survivor, each tier cleared from Smog up.
const TROPHY_FROM_TIER := 3


static func zone(tier: int) -> Dictionary:
	return ZONES[clampi(tier, 1, ZONES.size()) - 1]


## How hard twists hit on this tier (Dustfall softens its full stack).
static func strength(tier: int) -> float:
	return STACK_STRENGTH if tier >= 10 else 1.0


static func has_twist(tier: int, twist: String) -> bool:
	return twist in (zone(tier)["twists"] as Array)


static func exclusive(tier: int) -> Dictionary:
	return EXCLUSIVE.get(tier, {})


static func pact(id: String) -> Dictionary:
	return PACTS.get(id, {})


static func plane_part(tier: int) -> Dictionary:
	return PLANE_PARTS.get(tier, {})
