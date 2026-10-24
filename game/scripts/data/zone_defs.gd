class_name ZoneDefs
extends RefCounted

## Depth Update E7 — tiers 3–10 as a journey outward. Each tier is a zone with
## its own ground (tools/gen_zone_tiles.py), props (tools/gen_depth_art.py e7)
## and a twist; Dustfall stacks every twist. Also: tier-exclusive loot, per-survivor
## tier-clear trophies, Dust Pacts and Helm's plane parts. All tuning lives here.

## Zone per tier (index tier-1). "twists" are run by scripts/match/zone_twists.gd.
## "grade": ground texture + decal set suffix (style bible zone sub-palette).
## "props": zone props rolled into each chunk (art in assets/sprites/depth/zone/).
const ZONES: Array = [
	{"id": "haze", "name": "The Haze", "grade": "haze", "twists": [], "props": ["power_pole", "wreck_pile"]},
	{"id": "drift", "name": "The Drift", "grade": "drift", "twists": [], "props": ["beast_ribs", "buried_wreck"]},
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
## Style bible 2.2 zone ground colours (crack, base, mid, speck) per grade.
## Source of truth: tools/art_world/pal.py; the ground shader steps down this ramp.
const GROUND := {
	"haze": [Color("#433428"), Color("#5b4a3b"), Color("#685645"), Color("#7e6953")],
	"drift": [Color("#433424"), Color("#5d4a36"), Color("#6a5640"), Color("#7e6a50")],
	"refinery": [Color("#3a3633"), Color("#524d46"), Color("#5f5951"), Color("#746c60")],
	"city": [Color("#34363f"), Color("#494e5a"), Color("#54596a"), Color("#676d7b")],
	"quarantine": [Color("#36382f"), Color("#4d4f43"), Color("#585b4d"), Color("#6b6f5f")],
	"raider": [Color("#4a3028"), Color("#67453a"), Color("#755244"), Color("#896555")],
	"chemical": [Color("#37372d"), Color("#4e4e3c"), Color("#5a5a46"), Color("#6d6e56")],
	"military": [Color("#323834"), Color("#474f4b"), Color("#535b56"), Color("#676f69")],
	"crater": [Color("#3a3634"), Color("#534c49"), Color("#5f5854"), Color("#726c67")],
	"dustfall": [Color("#502f1b"), Color("#6b452e"), Color("#775038"), Color("#8a6549")],
}
## Zone props: [legacy world height, legacy block]. The art is native size now and
## footprints come from PropMeta (tools/art_world/build.py); kept as the zone prop list.
const PROP_INFO := {
	"oil_tank": [150.0, Vector2(96, 26)], "pipe_rack": [110.0, Vector2(0, 0)], "street_lamp": [130.0, Vector2(0, 0)],
	"shop_ruin": [150.0, Vector2(120, 26)], "quarantine_tent": [120.0, Vector2(100, 24)], "hazard_barrier": [70.0, Vector2(90, 16)],
	"spike_barricade": [80.0, Vector2(100, 18)], "raider_totem": [130.0, Vector2(0, 0)], "chem_vat": [130.0, Vector2(70, 24)],
	"tank_wreck": [120.0, Vector2(130, 30)], "guard_post": [150.0, Vector2(64, 22)], "slab_ruin": [110.0, Vector2(110, 24)],
	"dust_spire": [160.0, Vector2(40, 18)], "power_pole": [0.0, Vector2.ZERO], "wreck_pile": [0.0, Vector2.ZERO],
	"beast_ribs": [0.0, Vector2.ZERO], "buried_wreck": [0.0, Vector2.ZERO],
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
## THE one plane-part list (Wander and Campaign share it; GameState.plane_parts
## holds {part id: true}). Each part can come home either way: `tier` = first
## clear of that Wander tier, `level` = first clear of that campaign level.
## `layer` = the hangar art layer it lights (0 = none). `optional` parts are
## extras that never count towards the plane being whole (the Dust Heart only
## comes home on the "power the plane" ending).
const PLANE_PARTS := {
	"fuselage": {"name": "Airframe", "tier": 3, "level": "p0_mayday", "layer": 1, "icon": "tab_camp"},
	"wings": {"name": "Wings", "tier": 4, "layer": 2, "icon": "tab_camp"},
	"tail": {"name": "Tail Fin", "tier": 5, "layer": 3, "icon": "tab_camp"},
	"engine": {"name": "Engine", "tier": 6, "level": "l08_dead_signal", "layer": 4, "icon": "mat_salvage_core"},
	"propeller": {"name": "Propeller", "tier": 7, "layer": 5, "icon": "tab_camp"},
	"gear": {"name": "Landing Gear", "tier": 8, "layer": 6, "icon": "tab_camp"},
	"canopy": {"name": "Cockpit Canopy", "tier": 9, "layer": 7, "icon": "tab_camp"},
	"fuel": {"name": "Fuel Tanks", "tier": 10, "level": "l06_smugglers_road", "layer": 8, "icon": "camp_ammo_bench"},
	"battery": {"name": "Battery", "level": "l03_lights_out", "icon": "camp_generator"},
	"heart": {"name": "Dust Heart", "level": "l12_dustfall", "icon": "mat_dust_heart", "optional": true},
}
## Old save ids -> unified ids (Wander saved tiers "3".."10", the campaign
## saved its own ids).
const PLANE_LEGACY := {"3": "fuselage", "4": "wings", "5": "tail", "6": "engine", "7": "propeller",
	"8": "gear", "9": "canopy", "10": "fuel", "frame": "fuselage"}
const PLANE_LAYERS := 8
const PLANE_LAYER := "res://assets/sprites/depth/plane/plane_%d.png"
## Where the plane layers sit on the hangar's 1200x750 painted canvas (outside the door).
const PLANE_RECT := Rect2(490, 330, 222, 118)
## Trophies: per survivor, each tier cleared from Smog up.
const TROPHY_FROM_TIER := 3


static func ground_colors(grade: String) -> Array:
	return GROUND.get(grade, GROUND["haze"])


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


## The part a Wander tier's first clear sends home ({} if none; has "id").
static func plane_part(tier: int) -> Dictionary:
	for k in PLANE_PARTS.keys():
		if int(PLANE_PARTS[k].get("tier", 0)) == tier:
			var d: Dictionary = PLANE_PARTS[k].duplicate()
			d["id"] = str(k)
			return d
	return {}


## Unified id for a saved key (new id, old tier number or old campaign id), "" if unknown.
static func plane_part_id(key: String) -> String:
	if PLANE_PARTS.has(key):
		return key
	return str(PLANE_LEGACY.get(key, ""))


## Parts that count towards a whole plane (everything not optional).
static func plane_required() -> Array:
	var out: Array = []
	for k in PLANE_PARTS.keys():
		if not bool(PLANE_PARTS[k].get("optional", false)):
			out.append(str(k))
	return out


## Part shown by hangar art layer i (1..PLANE_LAYERS), "" if none.
static func plane_part_for_layer(i: int) -> String:
	for k in PLANE_PARTS.keys():
		if int(PLANE_PARTS[k].get("layer", 0)) == i:
			return str(k)
	return ""
