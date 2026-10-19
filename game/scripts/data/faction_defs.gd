class_name FactionDefs
extends RefCounted

## Depth Update E2 — factions. Every mob is plague, machine or raider
## (EnemyDefs.faction). All tuning here.
##   * Weaknesses: plague burns (fire), machines short out (shock).
##   * Elite traits per side; elites roll 1 trait at tier 3–6, 2 from tier 7.
##   * Infighting: hostile factions brawl when they get close — lure them together.
##   * Raider crews (tier 3+): a rival crew loots medicine crates, hunts you when
##     you carry medicine or get close, and drops its bag when the carrier dies.

const WEAKNESS := {
	"plague": {"fire": 1.35},
	"machine": {"shock": 1.35},
}
const WEAK_TEXT_CD := 1.2

## Who brawls with whom.
const HOSTILE := {
	"plague": ["machine", "raider"],
	"machine": ["plague", "raider"],
	"raider": ["plague", "machine"],
}
const INFIGHT_RANGE := 120.0      ## pick a foe this close…
const INFIGHT_LEASH := 260.0      ## …and drop it past this
const INFIGHT_CHECK := 0.5
const INFIGHT_HIT_RANGE := 46.0
const INFIGHT_DAMAGE := 0.9       ## × the attacker's damage
const INFIGHT_COOLDOWN := 1.1
const INFIGHT_KNOCK := 150.0
## Never brawl while the hero is right on top of them.
const INFIGHT_IGNORE_HERO_WITHIN := 110.0

## --- Elite traits ------------------------------------------------------------
const TRAITS := {
	"bloated": {"faction": "plague", "name": "Bloated", "color": Color(0.75, 0.9, 0.35),
		"desc": "Bursts on death", "radius": 100.0, "damage": 20.0, "pool_time": 4.0, "pool_dps": 7.0},
	"sporing": {"faction": "plague", "name": "Sporing", "color": Color(0.55, 0.85, 0.4),
		"desc": "Leaves spore clouds", "every": 3.2, "radius": 56.0, "time": 5.0, "dps": 6.0, "exposure": 4.0},
	"regrowing": {"faction": "plague", "name": "Regrowing", "color": Color(0.95, 0.45, 0.55),
		"desc": "Regenerates unless burning", "regen": 0.03},
	"shielded": {"faction": "machine", "name": "Shielded", "color": Color(0.45, 0.75, 1.0),
		"desc": "Frontal shield — hit it from behind", "arc_deg": 110.0, "reduce": 0.7},
	"self_repair": {"faction": "machine", "name": "Self-Repair", "color": Color(0.55, 1.0, 0.75),
		"desc": "Repairs itself when hurt — stun it", "below": 0.5, "heal": 0.3, "time": 2.2, "uses": 2},
	"overclocked": {"faction": "machine", "name": "Overclocked", "color": Color(1.0, 0.55, 0.25),
		"desc": "Fast, then overheats", "speed": 1.35, "cooldown": 0.7, "every": 8.0, "overheat": 2.2,
		"overheat_taken": 1.5},
}
const TRAIT_IDS := {
	"plague": ["bloated", "sporing", "regrowing"],
	"machine": ["shielded", "self_repair", "overclocked"],
	"raider": ["shielded", "regrowing", "overclocked"],
}
const ONE_TRAIT_FROM_TIER := 3
const TWO_TRAITS_FROM_TIER := 7

## Elite kinds per side (alternated so both sides show up).
const ELITE_POOL := {
	"plague": ["scorpion_king", "scav_bear", "geist_alpha"],
	"machine": ["cyber_juggernaut", "mech_wyrm", "fusion_golem"],
}

## --- Raider crews --------------------------------------------------------------
const CREW_FROM_TIER := 3
const CREW_FIRST := 150.0
const CREW_EVERY := 240.0
const CREW_MAX_ALIVE := 1
## Grunts by tier (index tier-1); a brute always; the captain leads from CREW_CAPTAIN_TIER.
const CREW_GRUNTS: Array = [0, 0, 2, 2, 3, 3, 3, 4, 4, 4]
const CREW_BRUTES: Array = [0, 0, 1, 1, 1, 1, 2, 2, 2, 2]
const CREW_CAPTAIN_TIER := 5
const CREW_SPAWN_DIST := 820.0
const CREW_HUNT_RANGE := 520.0
const CREW_SMELL_RANGE := 1100.0    ## hunts you from here if you carry medicine
const CREW_LOOT_R := 46.0
const CREW_SPEED := 0.9             ## × member speed while looting
## The bag: everything they looted + this much bonus.
const BAG_SCRAP := Vector2i(10, 22)
const BAG_INGREDIENTS := 3
const CREW_MAP_COLOR := Color(1.0, 0.6, 0.2)


static func weakness(faction: String, element: String) -> float:
	return float((WEAKNESS.get(faction, {}) as Dictionary).get(element, 1.0))


static func hostile(a: String, b: String) -> bool:
	return b in (HOSTILE.get(a, []) as Array)


static func trait_count(tier: int) -> int:
	if tier >= TWO_TRAITS_FROM_TIER:
		return 2
	if tier >= ONE_TRAIT_FROM_TIER:
		return 1
	return 0


## Roll distinct traits for an elite of this faction.
static func roll_traits(faction: String, tier: int, rng: RandomNumberGenerator = null) -> Array:
	var pool: Array = (TRAIT_IDS.get(faction, TRAIT_IDS["plague"]) as Array).duplicate()
	var out: Array = []
	for i in range(mini(trait_count(tier), pool.size())):
		var k := (rng.randi() if rng else randi()) % pool.size()
		out.append(pool[k])
		pool.remove_at(k)
	return out


static func trait_name(id: String) -> String:
	return str((TRAITS.get(id, {}) as Dictionary).get("name", id))


static func crew_grunts(tier: int) -> int:
	return int(CREW_GRUNTS[clampi(tier, 1, CREW_GRUNTS.size()) - 1])


static func crew_brutes(tier: int) -> int:
	return int(CREW_BRUTES[clampi(tier, 1, CREW_BRUTES.size()) - 1])
